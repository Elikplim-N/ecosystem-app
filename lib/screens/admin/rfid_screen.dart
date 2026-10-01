import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/user_repository.dart';
import '../../data/rfid_utils.dart';
import '../../models/app_role.dart';
import '../../models/member.dart';
import '../../screens/design_system.dart';

/// Registry for the physical RFID cards.
///
/// Card UIDs differ by reader, so the input normalises whatever the
/// reader emits (hex, decimal, colon-separated) into a single canonical
/// form before it is stored. That keeps one card from existing twice
/// because it was scanned two different ways.
class RfidScreen extends StatefulWidget {
  const RfidScreen({super.key});

  @override
  State<RfidScreen> createState() => _RfidScreenState();
}

class _RfidScreenState extends State<RfidScreen> {
  final _repo = UserRepository();
  final _searchController = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final created = await showDialog<_CardDraft>(
      context: context,
      builder: (context) => const _RegisterCardDialog(),
    );
    if (created == null) return;
    try {
      await _repo.registerCard(tag: created.tag);
      if (mounted) showToast(context, '${created.tag} registered');
    } catch (e) {
      if (mounted) showToast(context, 'Could not register: $e');
    }
  }

  Future<void> _assign(RfidCard card) async {
    final member = await showModalBottomSheet<Member>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PickMemberSheet(excludeRfids: {card.tag}),
    );
    if (member == null) return;

    try {
      await _repo.assignCard(
        cardId: card.id,
        uid: member.uid,
        name: member.displayName,
        role: member.role.id,
      );
      if (mounted) showToast(context, 'Card linked to ${member.displayName}');
    } catch (e) {
      if (mounted) showToast(context, 'Could not link the card: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'RFID cards',
      backgroundColor: kAdminBackground,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _register,
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add_card_rounded, size: 20),
        label: const Text('Register card'),
      ),
      body: StreamBuilder<List<RfidCard>>(
        stream: _repo.watchCards(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) return ErrorView(message: '${snapshot.error}');

          final all = snapshot.data ?? const <RfidCard>[];
          final query = _searchController.text.trim();

          final visible = all.where((card) {
            final stateMatches = switch (_filter) {
              'available' => card.state == RfidState.available,
              'linked' => card.state == RfidState.linked,
              'lost' => card.state == RfidState.lost,
              _ => true,
            };
            if (!stateMatches) return false;
            if (query.isEmpty) return true;
            final q = query.toLowerCase();
            return card.tag.toLowerCase().contains(q) ||
                (card.assignedName ?? '').toLowerCase().contains(q) ||
                card.cardType.toLowerCase().contains(q);
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatPill(
                      value: '${all.length}',
                      label: 'Registered',
                      icon: Icons.credit_card_rounded,
                      accent: kPrimaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatPill(
                      value: '${all.where((c) => c.isLinked).length}',
                      label: 'Linked',
                      icon: Icons.link_rounded,
                      accent: kColouredBottle,
                      tint: kPastelBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatPill(
                      value: '${all.where((c) => c.state == RfidState.available).length}',
                      label: 'Spare',
                      icon: Icons.inventory_2_rounded,
                      accent: kAccentOrange,
                      tint: const Color(0xFFFBEFD9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SearchField(
                hint: 'Search tag or holder',
                controller: _searchController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              FilterRow(
                options: const [
                  FilterOption('all', 'All'),
                  FilterOption('linked', 'Linked'),
                  FilterOption('available', 'Spare'),
                  FilterOption('lost', 'Lost'),
                ],
                selected: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 18),
              if (visible.isEmpty)
                EmptyState(
                  icon: Icons.credit_card_off_rounded,
                  title: all.isEmpty ? 'No cards registered' : 'Nothing matches',
                  message: all.isEmpty
                      ? 'Scan or type a card UID to register it, then link it '
                          'to a member.'
                      : 'Try another filter or search term.',
                  action: all.isEmpty
                      ? ElevatedButton.icon(
                          onPressed: _register,
                          icon: const Icon(Icons.add_card_rounded, size: 18),
                          label: const Text('REGISTER CARD'),
                        )
                      : null,
                )
              else
                ...visible.map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _CardTile(
                      card: card,
                      onAssign: () => _assign(card),
                      onUnlink: card.isLinked
                          ? () async {
                              await _repo.unlinkCard(card.id);
                              if (context.mounted) {
                                showToast(context, 'Card unlinked');
                              }
                            }
                          : null,
                      onMarkLost: card.state != RfidState.lost
                          ? () async {
                              await _repo.setCardState(card.id, RfidState.lost);
                              if (context.mounted) {
                                showToast(context, 'Marked as lost');
                              }
                            }
                          : null,
                      onRestore: card.state == RfidState.lost
                          ? () async {
                              await _repo.setCardState(
                                card.id,
                                card.isLinked ? RfidState.linked : RfidState.available,
                              );
                              if (context.mounted) {
                                showToast(context, 'Card restored');
                              }
                            }
                          : null,
                      onDelete: () async {
                        final ok = await confirmDialog(
                          context,
                          title: 'Delete this card?',
                          message:
                              'The card record for ${card.tag} is removed from '
                              'the registry. Any linked member will show as '
                              'having no card.',
                          confirmLabel: 'DELETE',
                        );
                        if (!ok) return;
                        await _repo.deleteCard(card.id);
                        if (context.mounted) showToast(context, 'Card deleted');
                      },
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

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.card,
    required this.onAssign,
    required this.onUnlink,
    required this.onMarkLost,
    required this.onRestore,
    required this.onDelete,
  });

  final RfidCard card;
  final VoidCallback onAssign;
  final VoidCallback? onUnlink;
  final VoidCallback? onMarkLost;
  final VoidCallback? onRestore;
  final VoidCallback onDelete;

  Color get _stateColor {
    switch (card.state) {
      case RfidState.linked:
        return kColouredBottle;
      case RfidState.available:
        return kPrimaryColor;
      case RfidState.lost:
        return kClearBottle;
      case RfidState.revoked:
        return kTextMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = card.holderRole == null ? null : AppRole.fromString(card.holderRole!);
    final accent = _stateColor;

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      radius: 22,
      border: accent.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TagGraphic(tag: card.tag, color: accent, dimmed: card.state == RfidState.lost),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.assignedName ?? 'Unassigned',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.tag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 9),
                    if (role != null)
                      RolePill(label: role.label, color: role.solidColor, icon: role.icon)
                    else
                      const Text(
                        'No member linked yet',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kTextMuted,
                        ),
                      ),
                  ],
                ),
              ),
              StatusChip(label: card.state.label, color: accent, dense: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniAction(
                  icon: card.isLinked ? Icons.person_off_rounded : Icons.link_rounded,
                  label: card.isLinked ? 'Unlink' : 'Link',
                  onTap: card.isLinked ? onUnlink! : onAssign,
                  tint: kMetricTeal,
                  primary: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniAction(
                  icon: onRestore != null ? Icons.restore_rounded : Icons.report_problem_rounded,
                  label: onRestore != null ? 'Restore' : 'Lost',
                  onTap: onRestore ?? onMarkLost!,
                  tint: kMetricAmber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  onTap: onDelete,
                  tint: kDanger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact action used in the three-button row of a card.
class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint = kPrimaryColor,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color tint;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: primary ? tint : tint.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: primary ? tint : tint.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: primary ? Colors.white : tint),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: primary ? Colors.white : tint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stylised card face showing the tag the way it is printed.
class _TagGraphic extends StatelessWidget {
  const _TagGraphic({required this.tag, required this.color, this.dimmed = false});

  final String tag;
  final Color color;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dimmed
              ? [kBeigeDeep, kBeige]
              : [color, Color.lerp(color, kPrimaryDark, 0.45)!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Icon(
              Icons.contactless_rounded,
              size: 20,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Icon(
              Icons.memory_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                tag.split('').take(5).join(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.white.withValues(alpha: dimmed ? 0.85 : 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Member picker used when linking a card.
class _PickMemberSheet extends StatefulWidget {
  const _PickMemberSheet({required this.excludeRfids});

  final Set<String> excludeRfids;

  @override
  State<_PickMemberSheet> createState() => _PickMemberSheetState();
}

class _PickMemberSheetState extends State<_PickMemberSheet> {
  final _repo = UserRepository();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetPanel(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Link card to a member',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: kTextDark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Pick who this card belongs to',
                          style: TextStyle(fontSize: 12.5, color: kTextMuted),
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
              const SizedBox(height: 14),
              SearchField(
                hint: 'Search name, phone or RFID',
                controller: _controller,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: StreamBuilder<List<Member>>(
                  stream: _repo.watchMembers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LoadingView();
                    }
                    final all = snapshot.data ?? const <Member>[];
                    final matches = all
                        .where((m) =>
                            m.matches(_controller.text) &&
                            !widget.excludeRfids.contains((m.rfidUid ?? '').trim()))
                        .toList();

                    if (matches.isEmpty) {
                      return const EmptyState(
                        icon: Icons.person_search_rounded,
                        title: 'No matching member',
                        message: 'Try a different name or phone number.',
                      );
                    }

                    return ListView.separated(
                      itemCount: matches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final member = matches[index];
                        return SoftCard(
                          onTap: () => Navigator.pop(context, member),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          radius: 16,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 21,
                                backgroundColor: member.tint,
                                child: Text(
                                  member.avatarIcon,
                                  style: const TextStyle(fontSize: 19),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            member.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              color: kTextDark,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        StatusChip(
                                          label: member.role.label,
                                          color: member.role.solidColor,
                                          icon: member.role.icon,
                                          dense: true,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      member.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: kTextMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: kTextMuted,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardDraft {
  const _CardDraft(this.tag);
  final String tag;
}

/// Registration dialog with live UID normalisation.
class _RegisterCardDialog extends StatefulWidget {
  const _RegisterCardDialog();

  @override
  State<_RegisterCardDialog> createState() => _RegisterCardDialogState();
}

class _RegisterCardDialogState extends State<_RegisterCardDialog> {
  final _tag = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _tag.dispose();
    super.dispose();
  }

  /// Strips separators, keeps hex characters only and groups in fours.
  static String normalise(String raw) => normaliseRfidTag(raw);

  static int _hexLength(String raw) => hexLength(raw);

  String get _hint => describeRfidLength(_hexLength(_tag.text));

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _CardDraft(normalise(_tag.text)));
  }

  @override
  Widget build(BuildContext context) {
    final preview = normalise(_tag.text);
    final length = _hexLength(_tag.text);
    final valid = length >= 8;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      title: Row(
        children: [
          const IconChip(icon: Icons.add_card_rounded, size: 38, iconSize: 19, radius: 12),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Register an RFID card',
              style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w900, color: kTextDark),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the UID exactly as the reader shows it. Separators and '
                'case are cleaned up automatically.',
                style: TextStyle(fontSize: 13, color: kTextMuted, height: 1.45),
              ),
              const SizedBox(height: 16),
              const _DialogLabel('Card UID'),
              TextFormField(
                controller: _tag,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: kTextDark,
                ),
                decoration: InputDecoration(
                  hintText: 'A3F9 21C0',
                  hintStyle: const TextStyle(
                    fontSize: 16,
                    letterSpacing: 1.6,
                    color: kBeigeDeep,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.backspace_outlined, size: 19),
                    onPressed: () {
                      _tag.clear();
                      setState(() {});
                    },
                  ),
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
                    borderSide: BorderSide(
                      color: valid ? kPrimaryColor.withValues(alpha: 0.5) : kBeige,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: kPrimaryColor, width: 1.6),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F: \-]')),
                  LengthLimitingTextInputFormatter(32),
                ],
                validator: (v) => _hexLength(v ?? '') < 8
                    ? 'A UID is at least 8 hex characters'
                    : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    valid ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    size: 15,
                    color: valid ? kPrimaryColor : kTextMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _hint,
                      style: TextStyle(
                        fontSize: 12,
                        color: valid ? kPrimaryColor : kTextMuted,
                      ),
                    ),
                  ),
                ],
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kPastelMint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Will be saved as', color: kPrimaryColor, fontSize: 9.5),
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: kPrimaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: kTextMuted),
          child: const Text('CANCEL'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('REGISTER'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
        ),
      ],
    );
  }
}

class _DialogLabel extends StatelessWidget {
  const _DialogLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        color: kTextMuted,
        letterSpacing: 0.3,
      ),
    );
  }
}
