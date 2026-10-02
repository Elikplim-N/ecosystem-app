import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../data/bins_repository.dart';
import '../models/bin.dart';
import '../screens/design_system.dart';

/// The categories a bin can collect. Drives the `collects` field.
const kWasteCategories = <String>[
  'Plastic',
  'Paper',
  'Glass',
  'Metal',
  'E-Waste',
];

/// Opens the add / edit bin sheet.
///
/// One sheet for both admin and ambassadors so the two roles can never
/// drift apart in what they are able to record. Only four things are
/// recorded: what it collects, its code, its name and where it stands.
Future<Bin?> showBinFormSheet(
  BuildContext context, {
  Bin? existing,
  required String uid,
  required String role,
  required String authorName,
  required String suggestedCode,
}) async {
  return showModalBottomSheet<Bin>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _BinFormSheet(
      existing: existing,
      uid: uid,
      role: role,
      authorName: authorName,
      suggestedCode: suggestedCode,
    ),
  );
}

class _BinFormSheet extends StatefulWidget {
  const _BinFormSheet({
    required this.existing,
    required this.uid,
    required this.role,
    required this.authorName,
    required this.suggestedCode,
  });

  final Bin? existing;
  final String uid;
  final String role;
  final String authorName;
  final String suggestedCode;

  @override
  State<_BinFormSheet> createState() => _BinFormSheetState();
}

class _BinFormSheetState extends State<_BinFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _address;

  late String _collects;

  /// Coordinates are set by the geolocator or the map picker instead of
  /// being typed, so they are held as state rather than form fields.
  double? _latitude;
  double? _longitude;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final bin = widget.existing;
    _code = TextEditingController(text: bin?.code ?? widget.suggestedCode);
    _name = TextEditingController(text: bin?.name ?? '');
    _address = TextEditingController(text: bin?.address ?? '');
    _collects = bin?.collects ?? kWasteCategories.first;
    _latitude = bin?.latitude;
    _longitude = bin?.longitude;
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  bool get _hasPoint => _latitude != null && _longitude != null;

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          showToast(context, 'Location permission was refused');
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _address.text = _address.text.trim().isEmpty
            ? 'Current location'
            : _address.text.trim();
      });
    } catch (e) {
      if (mounted) showToast(context, 'Could not get your location');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickOnMap() async {
    final picked = await showBinMapPicker(
      context,
      latitude: _latitude,
      longitude: _longitude,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _latitude = picked.$1;
      _longitude = picked.$2;
      if (_address.text.trim().isEmpty) {
        _address.text = 'Pinned location';
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final latitude = _latitude;
    final longitude = _longitude;
    if (latitude == null || longitude == null) {
      showToast(context, 'Pick the spot on the map or use your location');
      return;
    }

    final repo = BinsRepository();
    final existing = widget.existing;

    final bin = Bin(
      id: existing?.id ?? '',
      code: _code.text.trim(),
      name: _name.text.trim(),
      status: existing?.status ?? BinStatus.available,
      fillLevel: existing?.fillLevel ?? 0,
      rejectedFillLevel: existing?.rejectedFillLevel ?? 0,
      collects: _collects,
      latitude: latitude,
      longitude: longitude,
      address: _address.text.trim(),
      // Sensors report on their own, so they are never typed in here.
      sensorId: existing?.sensorId,
      hasSensor: existing?.hasSensor ?? false,
      capacityKg: existing?.capacityKg ?? 50,
      lastCollected: existing?.lastCollected,
      updatedAt: DateTime.now(),
      createdById: existing?.createdById ?? widget.uid,
      createdByRole: existing?.createdByRole ?? widget.role,
      createdByName: existing?.createdByName ?? widget.authorName,
    );

    try {
      if (existing == null) {
        await repo.create(
          code: bin.code,
          name: bin.name,
          collects: bin.collects,
          latitude: bin.latitude,
          longitude: bin.longitude,
          address: bin.address,
          createdById: widget.uid,
          createdByRole: widget.role,
          createdByName: widget.authorName,
        );
      } else {
        await repo.update(bin, previous: existing);
      }
      if (mounted) {
        Navigator.pop(context, bin);
        showToast(context, existing == null ? 'Bin added' : 'Bin updated');
      }
    } catch (e) {
      if (mounted) showToast(context, 'Could not save the bin: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return SheetPanel(
      color: kAdminBackground,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit bin' : 'Add a bin',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              color: kTextDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEditing
                                ? 'Update what this bin collects and where it stands'
                                : 'Four details are all a new bin needs',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: kTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: kTextMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                _FieldLabel('Collects'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kWasteCategories.map((category) {
                    return GestureDetector(
                      onTap: () => setState(() => _collects = category),
                      child: StatusChip(
                        label: category,
                        color: _collects == category ? kMetricTeal : kTextMuted,
                        icon: _collects == category
                            ? Icons.check_rounded
                            : null,
                        solid: _collects == category,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                _FieldLabel('Bin code'),
                TextFormField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _decoration(
                    hint: 'BIN-001',
                    helper: 'Printed on the bin and shown on the map',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Give the bin a code'
                      : null,
                ),
                const SizedBox(height: 18),

                _FieldLabel('Name'),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration(hint: 'Campus Main Gate'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Give the bin a name'
                      : null,
                ),
                const SizedBox(height: 18),

                _FieldLabel('Location'),
                TextFormField(
                  controller: _address,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration(hint: 'Main Gate, University Road'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Describe where the bin stands'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _LocationButton(
                        icon: Icons.my_location_rounded,
                        label: _locating ? 'Locating...' : 'My location',
                        tint: kMetricBlue,
                        busy: _locating,
                        onTap: _useCurrentLocation,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _LocationButton(
                        icon: Icons.map_rounded,
                        label: 'Pick on map',
                        tint: kMetricTeal,
                        onTap: _pickOnMap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      _hasPoint
                          ? Icons.check_circle_rounded
                          : Icons.info_rounded,
                      size: 15,
                      color: _hasPoint ? kMetricTeal : kTextMuted,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _hasPoint
                            ? 'Map position saved for this bin'
                            : 'Tap "Pick on map" to drop the pin',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _hasPoint ? kMetricTeal : kTextMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _locating ? null : _save,
                    icon: Icon(
                      isEditing ? Icons.save_rounded : Icons.add_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(isEditing ? 'SAVE CHANGES' : 'ADD BIN'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: kPrimaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({String? hint, String? helper}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: kTextMuted),
      helperText: helper,
      helperStyle: const TextStyle(fontSize: 11.5, color: kTextMuted),
      filled: true,
      fillColor: kBackground,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBeige),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBeige),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kPrimaryColor, width: 1.6),
      ),
    );
  }
}

/// One of the two ways of setting the map position.
class _LocationButton extends StatelessWidget {
  const _LocationButton({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tint.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2, color: tint),
              )
            else
              Icon(icon, size: 17, color: tint),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: tint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Drops a pin on an OpenStreetMap sheet and returns `(lat, lng)`.
Future<(double, double)?> showBinMapPicker(
  BuildContext context, {
  double? latitude,
  double? longitude,
}) {
  final initial = latitude != null && longitude != null
      ? LatLng(latitude, longitude)
      : const LatLng(5.6037, -0.1870);

  return showModalBottomSheet<(double, double)>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SheetPanel(
      color: kAdminBackground,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Where does the bin stand?',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      color: kTextDark,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: kTextMuted,
                  ),
                ),
              ],
            ),
            const Text(
              'Tap the map to move the pin.',
              style: TextStyle(fontSize: 12.5, color: kTextMuted),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: initial,
                    initialZoom: 15,
                    onTap: (_, point) => Navigator.pop(context, (
                      point.latitude,
                      point.longitude,
                    )),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.boame.ecosystem',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: initial,
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.location_on_rounded,
                            size: 42,
                            color: kPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Map data © OpenStreetMap contributors',
              style: TextStyle(fontSize: 10.5, color: kTextMuted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: kTextMuted,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
