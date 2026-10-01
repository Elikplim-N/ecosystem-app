import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/bin.dart';
import '../design_system.dart';

/// Real OpenStreetMap view of Ghana, with every bin plotted at its actual
/// coordinate. Defaults to the whole country and zooms to the Accra
/// cluster on request.
class GhanaBinMap extends StatefulWidget {
  const GhanaBinMap({super.key, required this.bins, this.height = 300});

  final List<Bin> bins;
  final double height;

  @override
  State<GhanaBinMap> createState() => _GhanaBinMapState();
}

class _GhanaBinMapState extends State<GhanaBinMap> {
  final MapController _map = MapController();
  Bin? _active;
  bool _accraView = false;

  static const _ghanaCentre = LatLng(7.94, -1.02);
  static const _accraCentre = LatLng(5.6037, -0.1870);

  @override
  void didUpdateWidget(covariant GhanaBinMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_active != null && !widget.bins.any((b) => b.id == _active!.id)) {
      _active = null;
    }
  }

  void _focusGhana() {
    setState(() {
      _accraView = false;
      _active = null;
    });
    _map.move(_ghanaCentre, 6.1);
  }

  void _focusAccra() {
    setState(() => _accraView = true);
    _map.move(_accraCentre, 13.0);
  }

  void _select(Bin bin) {
    setState(() => _active = _active?.id == bin.id ? null : bin);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Bin network',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kTextDark),
              ),
            ),
            _ScopePill(label: 'Ghana', selected: !_accraView, onTap: _focusGhana),
            const SizedBox(width: 6),
            _ScopePill(label: 'Accra', selected: _accraView, onTap: _focusAccra),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: widget.height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    FlutterMap(
                      mapController: _map,
                      options: MapOptions(
                        initialCenter: _ghanaCentre,
                        initialZoom: 6.1,
                        minZoom: 4.5,
                        maxZoom: 17,
                        backgroundColor: const Color(0xFFE7E3DA),
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                        onTap: (_, _) => setState(() => _active = null),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.boame.ecosystem',
                          maxNativeZoom: 19,
                        ),
                        MarkerLayer(
                          markers: [
                            for (final bin in widget.bins)
                              Marker(
                                point: LatLng(bin.latitude, bin.longitude),
                                width: 46,
                                height: 46,
                                child: _BinPin(
                                  bin: bin,
                                  active: _active?.id == bin.id,
                                  onTap: () => _select(bin),
                                  onHover: (hovering) {
                                    if (hovering) {
                                      if (_active?.id != bin.id) setState(() => _active = bin);
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    if (_active != null)
                      Positioned(
                        left: 12,
                        top: 12,
                        right: 12,
                        child: _BinInfoCard(bin: _active!, onClose: () => setState(() => _active = null)),
                      ),
                    Positioned(
                      right: 8,
                      bottom: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(
                            '(c) OpenStreetMap',
                            style: TextStyle(fontSize: 9.5, color: kTextMuted),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        const _MapLegend(),
      ],
    );
  }
}

class _ScopePill extends StatelessWidget {
  const _ScopePill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? kPrimaryColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? kPrimaryColor : kBeigeDeep),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : kTextMuted,
          ),
        ),
      ),
    );
  }
}

/// Green for bins running normally, red once full, grey when disabled.
Color binPinColor(BinStatus status) {
  switch (status) {
    case BinStatus.available:
    case BinStatus.filling:
      return const Color(0xFF17A34A);
    case BinStatus.full:
      return const Color(0xFFD92B2B);
    case BinStatus.disabled:
      return const Color(0xFF8E9A99);
  }
}

class _BinPin extends StatelessWidget {
  const _BinPin({
    required this.bin,
    required this.active,
    required this.onTap,
    required this.onHover,
  });

  final Bin bin;
  final bool active;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final color = binPinColor(bin.status);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(true),
      onExit: (_) {},
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: active ? 38 : 30,
          height: active ? 38 : 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: active ? 0.55 : 0.35),
                blurRadius: active ? 14 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(Icons.delete_outline_rounded, size: active ? 19 : 15, color: Colors.white),
        ),
      ),
    );
  }
}

class _BinInfoCard extends StatelessWidget {
  const _BinInfoCard({required this.bin, required this.onClose});

  final Bin bin;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final color = binPinColor(bin.status);

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: kPrimaryDark.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bin.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kTextDark),
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close_rounded, size: 17, color: kTextMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            bin.code,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: kTextMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place_rounded, size: 14, color: kTextMuted),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  bin.locationLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextDark,
                    height: 1.35,
                  ),
                ),
              ),
              if (bin.acceptedFull || bin.rejectedFull) ...[
                const SizedBox(width: 10),
                const RolePill(label: 'Full', color: kMetricAmber),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    const entries = <(String, Color)>[
      ('Running normally', Color(0xFF17A34A)),
      ('Needs collection', Color(0xFFD92B2B)),
      ('Disabled', Color(0xFF8E9A99)),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (label, color) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: kTextMuted),
              ),
            ],
          ),
      ],
    );
  }
}
