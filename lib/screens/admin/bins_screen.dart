import 'package:flutter/material.dart';
import '../../data/bins_repository.dart';
import '../../models/app_role.dart';
import '../../models/bin.dart';
import '../../widgets/bin_form_sheet.dart';
import '../../screens/design_system.dart';

/// Bin management for both admins and ambassadors.
///
/// The screen is identical for both roles; only the permission checks
/// differ, and they all go through [BinsRepository.canEdit].
///
/// Every bin has two containers, so each card shows two compartments: the
/// accepted container as the headline and the rejected one only once it
/// holds anything.
class BinsScreen extends StatefulWidget {
  const BinsScreen({
    super.key,
    required this.uid,
    required this.role,
    required this.displayName,
    this.title = 'Bins',
    this.showOnlyMine = false,
  });

  final String uid;
  final AppRole role;
  final String displayName;
  final String title;

  /// Ambassador default: focus the bins they are responsible for.
  final bool showOnlyMine;

  @override
  State<BinsScreen> createState() => _BinsScreenState();
}

class _BinsScreenState extends State<BinsScreen> {
  final _repo = BinsRepository();
  final _searchController = TextEditingController();

  String _filter = 'all';
  bool _mineOnly = false;

  static const _filters = [
    FilterOption('all', 'All'),
    FilterOption('attention', 'Needs collection'),
    FilterOption('full', 'Full'),
    FilterOption('filling', 'Filling'),
    FilterOption('available', 'Available'),
    FilterOption('disabled', 'Disabled'),
  ];

  @override
  void initState() {
    super.initState();
    _mineOnly = widget.showOnlyMine;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _canEdit(Bin bin) => BinsRepository.canEdit(
        bin,
        uid: widget.uid,
        role: widget.role.id,
      );

  List<Bin> _apply(List<Bin> bins) {
    final query = _searchController.text.trim().toLowerCase();
    return bins.where((bin) {
      if (_mineOnly && bin.createdById != widget.uid) return false;
      if (_filter == 'attention') {
        if (!bin.needsCollection) return false;
      } else if (_filter != 'all' && bin.status.id != _filter) {
        return false;
      }
      if (query.isEmpty) return true;
      return bin.code.toLowerCase().contains(query) ||
          bin.name.toLowerCase().contains(query) ||
          bin.address.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _toggleDisabled(Bin bin) async {
    final enabling = bin.status == BinStatus.disabled;
    if (!enabling) {
      final ok = await confirmDialog(
        context,
        title: 'Disable this bin?',
        message:
            '${bin.name} will stop appearing as collectable. It stays on the map '
            'and can be re-enabled at any time.',
      );
      if (!ok) return;
    }
    await _repo.setStatus(
      bin.id,
      enabling ? BinStatus.available : BinStatus.disabled,
      fillLevel: bin.fillLevel,
    );
    if (mounted) {
      showToast(context, enabling ? 'Bin re-enabled' : 'Bin disabled');
    }
  }

  Future<void> _markCollected(Bin bin) async {
    await _repo.markCollected(bin.id);
    if (mounted) showToast(context, '${bin.code} emptied');
  }

  Future<void> _delete(Bin bin) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${bin.code}?',
      message:
          'This permanently removes the bin and its location. Prefer disabling '
          'it if you only need it off the map.',
      confirmLabel: 'DELETE',
    );
    if (!ok) return;
    await _repo.delete(bin.id);
    if (mounted) showToast(context, 'Bin deleted');
  }

  Future<void> _openEditor(Bin? bin) async {
    final code = bin == null ? await _repo.nextCode() : bin.code;
    if (!mounted) return;
    await showBinFormSheet(
      context,
      existing: bin,
      uid: widget.uid,
      role: widget.role.id,
      authorName: widget.displayName,
      suggestedCode: code,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: widget.title,
      backgroundColor: kAdminBackground,
      floatingActionButton: _AddBinButton(onTap: () => _openEditor(null)),
      body: StreamBuilder<List<Bin>>(
        stream: _repo.watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorView(message: '${snapshot.error}');
          }

          final all = snapshot.data ?? const <Bin>[];
          final summary = BinsRepository.summarise(all);
          final visible = _apply(all);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
            children: [
              _SummaryStrip(summary: summary),
              const SizedBox(height: 18),
              SearchField(
                hint: 'Search by code, name or location',
                controller: _searchController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              FilterRow(
                options: _filters,
                selected: _filter,
                onChanged: (value) => setState(() => _filter = value),
              ),
              if (widget.role == AppRole.ambassador) ...[
                const SizedBox(height: 10),
                _MineToggle(
                  value: _mineOnly,
                  onChanged: (value) => setState(() => _mineOnly = value),
                ),
              ],
              const SizedBox(height: 20),
              if (visible.isEmpty)
                EmptyState(
                  icon: Icons.delete_outline_rounded,
                  tint: kMetricTealTint,
                  accent: kMetricTeal,
                  title: all.isEmpty ? 'No bins yet' : 'Nothing matches',
                  message: all.isEmpty
                      ? 'Register your first bin and it will appear here and on the map.'
                      : 'Try a different filter or search term.',
                  action: all.isEmpty
                      ? ElevatedButton.icon(
                          onPressed: () => _openEditor(null),
                          style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('ADD BIN'),
                        )
                      : null,
                )
              else
                ...visible.map(
                  (bin) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BinCard(
                      bin: bin,
                      canEdit: _canEdit(bin),
                      onTap: () => showBinDetailSheet(
                        context,
                        bin,
                        canEdit: _canEdit(bin),
                        onEdit: () => _openEditor(bin),
                        onToggleDisabled: () => _toggleDisabled(bin),
                        onMarkCollected: () => _markCollected(bin),
                        onDelete: () => _delete(bin),
                      ),
                      onQuickCollect: bin.needsCollection && _canEdit(bin)
                          ? () => _markCollected(bin)
                          : null,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Pill-shaped add button that matches the rest of the admin surfaces.
class _AddBinButton extends StatelessWidget {
  const _AddBinButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: kPrimaryColor,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: kPrimaryColor.withValues(alpha: 0.32),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_location_alt_rounded, size: 20, color: Colors.white),
            SizedBox(width: 9),
            Text(
              'Add bin',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One container of one bin: label, capacity bar and a FULL flag.
class Compartment extends StatelessWidget {
  const Compartment({
    super.key,
    required this.label,
    required this.fill,
    required this.accent,
    this.emphasis = false,
  });

  final String label;
  final double fill;
  final Color accent;

  /// The accepted container is the headline, so it gets more weight.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final full = fill >= 90;

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: emphasis ? 0.10 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: full ? 0.5 : 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                emphasis ? Icons.check_circle_rounded : Icons.cancel_outlined,
                size: 13,
                color: accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: emphasis ? 11.5 : 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: accent,
                  ),
                ),
              ),
              if (full)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'FULL',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: LevelBar(
                  value: fill / 100,
                  color: accent,
                  track: accent.withValues(alpha: 0.13),
                  height: emphasis ? 10 : 7,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${fill.round()}%',
                style: TextStyle(
                  fontSize: emphasis ? 16 : 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: kTextDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Both containers of one bin: accepted (headline) and rejected.
class BinCompartments extends StatelessWidget {
  const BinCompartments({super.key, required this.bin, this.gap = 8});

  final Bin bin;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Compartment(
          label: 'Accepted',
          fill: bin.fillLevel,
          accent: kMetricTeal,
          emphasis: true,
        ),
        if (bin.rejectedFillLevel > 0) ...[
          SizedBox(height: gap),
          Compartment(
            label: 'Rejected',
            fill: bin.rejectedFillLevel,
            accent: kMetricAmber,
          ),
        ],
      ],
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary});

  final BinSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MetricCard(
            title: 'Bins',
            unit: 'Deployed',
            value: '${summary.total}',
            icon: Icons.delete_outline_rounded,
            tint: kMetricTealTint,
            accent: kMetricTeal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MetricCard(
            title: 'Full',
            unit: 'Needs collection',
            value: '${summary.full}',
            icon: Icons.error_rounded,
            tint: kMetricAmberTint,
            accent: kMetricAmber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MetricCard(
            title: 'Rejected',
            unit: 'Compartment full',
            value: '${summary.rejectedFull}',
            icon: Icons.block_rounded,
            tint: kMetricRoseTint,
            accent: kMetricRose,
          ),
        ),
      ],
    );
  }
}

class _MineToggle extends StatelessWidget {
  const _MineToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: () => onChanged(!value),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      border: value ? kPrimaryColor.withValues(alpha: 0.3) : null,
      child: Row(
        children: [
          const Icon(Icons.person_pin_rounded, size: 20, color: kPrimaryColor),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Only bins I added',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: kPrimaryColor,
          ),
        ],
      ),
    );
  }
}

/// One bin in the list: identity on top, both containers underneath.
class _BinCard extends StatelessWidget {
  const _BinCard({
    required this.bin,
    required this.canEdit,
    required this.onTap,
    this.onQuickCollect,
  });

  final Bin bin;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback? onQuickCollect;

  @override
  Widget build(BuildContext context) {
    final disabled = bin.status == BinStatus.disabled;

    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      radius: 22,
      border: bin.needsCollection
          ? kMetricAmber.withValues(alpha: 0.45)
          : disabled
              ? kBeigeDeep
              : kMetricTeal.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bin.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${bin.code}  ${bin.locationLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: kTextMuted),
                    ),
                  ],
                ),
              ),
              if (disabled)
                const RolePill(label: 'Disabled', color: kTextMuted)
              else if (bin.needsCollection)
                RolePill(label: 'Full', color: kMetricAmber),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 20, color: kTextMuted),
            ],
          ),
          const SizedBox(height: 14),
          if (disabled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(
                color: kBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.pause_circle_rounded, size: 16, color: kTextMuted),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'This bin is out of service',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextMuted),
                    ),
                  ),
                ],
              ),
            )
          else
            BinCompartments(bin: bin),
          if (onQuickCollect != null) ...[
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: ActionButton(
                    icon: Icons.local_shipping_rounded,
                    label: 'Mark emptied',
                    tint: kPrimaryColor,
                    onTap: onQuickCollect!,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Full detail sheet for one bin, grouped so nothing competes.
Future<void> showBinDetailSheet(
  BuildContext context,
  Bin bin, {
  required bool canEdit,
  required VoidCallback onEdit,
  required VoidCallback onToggleDisabled,
  required VoidCallback onMarkCollected,
  required VoidCallback onDelete,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SheetPanel(
      color: kAdminBackground,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bin.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            height: 1.15,
                            color: kTextDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${bin.code}  ${bin.locationLabel}',
                          style: const TextStyle(fontSize: 13, color: kTextMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20, color: kTextMuted),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (bin.status == BinStatus.disabled)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.pause_circle_rounded, size: 18, color: kTextMuted),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This bin is out of service',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMuted),
                        ),
                      ),
                    ],
                  ),
                )
              else
                BinCompartments(bin: bin, gap: 10),
              const SizedBox(height: 22),
              const SectionHeader(title: 'Details'),
              SoftCard(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Column(
                  children: [
                    _DetailRow(Icons.place_rounded, 'Location', bin.locationLabel),
                    _DetailRow(Icons.category_rounded, 'Collects', bin.collects),
                    _DetailRow(Icons.person_rounded, 'Added by', bin.createdByName ?? 'Unknown'),
                    if (bin.lastCollected != null)
                      _DetailRow(
                        Icons.local_shipping_rounded,
                        'Last emptied',
                        _friendlyDate(bin.lastCollected!),
                      ),
                  ],
                ),
              ),
              if (canEdit) ...[
                const SizedBox(height: 22),
                const SectionHeader(title: 'Actions'),
                ActionButton(
                  icon: Icons.local_shipping_rounded,
                  label: 'Mark as emptied',
                  description: 'Empties both containers and records the collection',
                  tint: kPrimaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    onMarkCollected();
                  },
                ),
                const SizedBox(height: 10),
                ActionButton(
                  icon: Icons.edit_rounded,
                  label: 'Edit bin',
                  onTap: () {
                    Navigator.pop(context);
                    onEdit();
                  },
                ),
                const SizedBox(height: 10),
                ActionButton(
                  icon: bin.status == BinStatus.disabled
                      ? Icons.play_circle_rounded
                      : Icons.pause_circle_rounded,
                  label: bin.status == BinStatus.disabled ? 'Re-enable bin' : 'Disable bin',
                  tint: bin.status == BinStatus.disabled ? kPrimaryColor : kMetricAmber,
                  onTap: () {
                    Navigator.pop(context);
                    onToggleDisabled();
                  },
                ),
                const SizedBox(height: 10),
                ActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete bin',
                  tint: kDanger,
                  onTap: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kPastelBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 17, color: kColouredBottle),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You can view this bin, but only the admin who added it can change it.',
                          style: TextStyle(fontSize: 12.5, color: kTextDark, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// '12 Mar 2025, 14:05'
String _friendlyDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:$minute';
}

/// Label above value inside the details card.
class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: kTextMuted),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kTextMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kTextDark,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
