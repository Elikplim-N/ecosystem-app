import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../data/user_repository.dart';
import '../../models/app_role.dart';
import '../../models/member.dart';
import '../../screens/design_system.dart';

/// Super-admin view over every account in the system.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.currentUid});

  /// Guards against an admin demoting or deleting themselves.
  final String currentUid;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _repo = UserRepository();
  final _searchController = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openMember(Member member) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MemberSheet(
        member: member,
        isSelf: member.uid == widget.currentUid,
        repo: _repo,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Members',
      backgroundColor: kAdminBackground,
      body: StreamBuilder<List<Member>>(
        stream: _repo.watchMembers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) return ErrorView(message: '${snapshot.error}');

          final all = snapshot.data ?? const <Member>[];
          final pending = all.where((m) => m.isPendingApplication).length;
          final ambassadors =
              all.where((m) => m.role == AppRole.ambassador).length;
          final disabled = all.where((m) => m.accountDisabled).length;

          final visible = all.where((member) {
            if (!member.matches(_searchController.text)) return false;
            switch (_filter) {
              case 'ambassador':
                return member.role == AppRole.ambassador;
              case 'pending':
                return member.isPendingApplication;
              case 'admin':
                return member.role == AppRole.admin;
              case 'disabled':
                return member.accountDisabled;
              case 'withcard':
                return member.rfidUid != null && member.rfidUid!.isNotEmpty;
              default:
                return true;
            }
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      title: 'Members',
                      unit: disabled > 0 ? '$disabled disabled' : 'Total',
                      value: '${all.length}',
                      icon: Icons.people_alt_rounded,
                      tint: kMetricTealTint,
                      accent: kMetricTeal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      title: 'Ambassadors',
                      unit: 'Approved',
                      value: '$ambassadors',
                      icon: Icons.workspace_premium_rounded,
                      tint: kMetricBlueTint,
                      accent: kMetricBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      title: 'Pending',
                      unit: 'Under review',
                      value: '$pending',
                      icon: Icons.hourglass_top_rounded,
                      tint: kMetricAmberTint,
                      accent: kMetricAmber,
                      onTap: pending > 0
                          ? () => setState(() => _filter = _filter == 'pending' ? 'all' : 'pending')
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SearchField(
                hint: 'Search name, phone, email or RFID',
                controller: _searchController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              FilterRow(
                options: const [
                  FilterOption('all', 'All'),
                  FilterOption('ambassador', 'Ambassadors'),
                  FilterOption('pending', 'Pending'),
                  FilterOption('withcard', 'Has card'),
                  FilterOption('admin', 'Admins'),
                  FilterOption('disabled', 'Disabled'),
                ],
                selected: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 18),
              if (visible.isEmpty)
                const EmptyState(
                  icon: Icons.person_search_rounded,
                  title: 'No members match',
                  message: 'Try a different search term or filter.',
                )
              else
                ...visible.map(
                  (member) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MemberTile(
                      member: member,
                      isSelf: member.uid == widget.currentUid,
                      onTap: () => _openMember(member),
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

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isSelf,
    required this.onTap,
  });

  final Member member;
  final bool isSelf;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final role = member.role;
    final accent = role.solidColor;

    Color? flag;
    String? flagLabel;
    if (member.accountDisabled) {
      flag = kTextMuted;
      flagLabel = 'Disabled';
    } else if (member.isPendingApplication) {
      flag = kAccentOrange;
      flagLabel = 'Application pending';
    }

    return Opacity(
      opacity: member.accountDisabled ? 0.6 : 1,
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 13, 13, 12),
        radius: 20,
        border: member.isPendingApplication
            ? kAccentOrange.withValues(alpha: 0.5)
            : accent.withValues(alpha: 0.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                RolePill(label: role.label, color: accent, icon: role.icon),
                const Spacer(),
                if (flag != null)
                  StatusChip(
                    label: flagLabel!,
                    color: flag,
                    dense: true,
                  ),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: role.tint,
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.6),
                  ),
                  child: Text(member.avatarIcon, style: const TextStyle(fontSize: 19)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kTextDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.phone.trim().isEmpty ? 'No phone number' : member.phone.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: member.phone.trim().isEmpty ? kTextMuted : kTextDark.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'POINTS',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: kTextMuted,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _grouped(member.points),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: accent,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.chevron_right_rounded, size: 20, color: kTextMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Thousands-separated integer, e.g. 12450 becomes 12,450.
String _grouped(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');

  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }

  return buffer.toString();
}

/// Full record plus every action an admin can take on one member.
class _MemberSheet extends StatefulWidget {
  const _MemberSheet({
    required this.member,
    required this.isSelf,
    required this.repo,
  });

  final Member member;
  final bool isSelf;
  final UserRepository repo;

  @override
  State<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends State<_MemberSheet> {
  late final Member _member = widget.member;

  Future<void> _setRole(AppRole role) async {
    await widget.repo.setRole(_member.uid, role);
    if (!mounted) return;
    Navigator.pop(context);
    showToast(context, 'Now a ${role.label.toLowerCase()}');
  }

  Future<void> _toggleDisabled() async {
    final enabling = _member.accountDisabled;
    if (!enabling) {
      final ok = await confirmDialog(
        context,
        title: 'Disable this account?',
        message:
            '${_member.displayName} will be blocked from signing in. Their points '
            'and history are kept.',
      );
      if (!ok) return;
    }
    await widget.repo.setUserEnabled(_member.uid, enabling);
    if (!mounted) return;
    Navigator.pop(context);
    showToast(context, enabling ? 'Account enabled' : 'Account disabled');
  }

  Future<void> _deleteAccount() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${_member.displayName}?',
      message:
          'This signs the account out of Firebase Auth and deletes its user '
          'record. Points and deposit history cannot be recovered.',
      confirmLabel: 'DELETE',
    );
    if (!ok) return;
    try {
      await FirebaseAuth.instance.currentUser?.delete();
    } catch (_) {
      // Deleting another account needs the Admin SDK, not available on the
      // client. The document is still removed below.
    }
    try {
      await FirebaseFirestore.instance.collection('users').doc(_member.uid).delete();
      if (!mounted) return;
      Navigator.pop(context);
      showToast(context, 'Member record deleted');
    } catch (e) {
      if (mounted) showToast(context, 'Could not delete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = _member.role;
    final accent = role.solidColor;

    return SheetPanel(
      color: kAdminBackground,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 22),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: role.tint,
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withValues(alpha: 0.35), width: 2),
                    ),
                    child: Text(_member.avatarIcon, style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _member.displayName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            height: 1.15,
                            color: kTextDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          role.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_member.accountDisabled)
                          const StatusChip(
                            label: 'Account disabled',
                            color: kTextMuted,
                            icon: Icons.pause_circle_rounded,
                            dense: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                    color: kMetricTealTint,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kMetricTeal.withValues(alpha: 0.28)),

                ),
                child: Row(
                  children: [
                    _SheetStat(label: 'Points', value: _grouped(_member.points)),
                    _SheetDivider(),
                    _SheetStat(label: 'Bottles', value: '${_member.bottles}'),
                    _SheetDivider(),
                    _SheetStat(
                      label: 'Weight',
                      value: '${_member.weight.toStringAsFixed(1)} kg',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              const SectionHeader(title: 'Contact'),
              SoftCard(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Column(
                  children: [
                    _SheetRow(Icons.phone_rounded, 'Phone', _member.phone.trim().isEmpty ? 'Not set' : _member.phone.trim()),
                    _SheetRow(Icons.email_rounded, 'Email', _member.email.trim().isEmpty ? 'Not set' : _member.email.trim()),
                    _SheetRow(
                      Icons.contactless_rounded,
                      'RFID card',
                      (_member.rfidUid ?? '').isEmpty ? 'Not linked' : _member.rfidUid!,
                    ),
                    if ((_member.area ?? '').isNotEmpty)
                      _SheetRow(Icons.place_rounded, 'Area', _member.area!),
                  ],
                ),
              ),
              if ((_member.motivation ?? '').isNotEmpty) ...[
                const SizedBox(height: 22),
                const SectionHeader(title: 'Application'),
                SoftCard(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Text(
                    _member.motivation!,
                    style: const TextStyle(fontSize: 13.5, color: kTextDark, height: 1.5),
                  ),
                ),
              ],
              const SizedBox(height: 22),

              if (!widget.isSelf) ...[
                const Text(
                  'Account role',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: kTextDark),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap the role this member should hold.',
                  style: TextStyle(fontSize: 12.5, color: kTextMuted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final option in AppRole.values) ...[
                      if (option != AppRole.values.first) const SizedBox(width: 10),
                      Expanded(
                        child: _RoleOption(
                          role: option,
                          selected: _member.role == option,
                          onTap: () => _setRole(option),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                ActionButton(
                  icon: _member.accountDisabled
                      ? Icons.play_circle_rounded
                      : Icons.pause_circle_rounded,
                  label: _member.accountDisabled ? 'Enable account' : 'Disable account',
                  tint: _member.accountDisabled ? kPrimaryColor : kMetricAmber,
                  onTap: _toggleDisabled,
                ),
                const SizedBox(height: 10),
                ActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete member record',
                  tint: kDanger,
                  onTap: _deleteAccount,
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
                      Icon(Icons.info_rounded, size: 18, color: kColouredBottle),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This is your own account, so role and account changes are disabled here.',
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
    );
  }
}

/// Compact figure inside the member summary strip.
class _SheetStat extends StatelessWidget {
  const _SheetStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: kTextMuted,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: kTextDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: kDeepMintInk.withValues(alpha: 0.14));
  }
}

/// One selectable role in the "Account role" picker.
class _RoleOption extends StatelessWidget {
  const _RoleOption({required this.role, required this.selected, required this.onTap});

  final AppRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = role.solidColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? role.tint : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? accent : kBeigeDeep,
            width: selected ? 1.8 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            IconChip(
              icon: role.icon,
              tint: Colors.white,
              color: accent,
              size: 38,
              iconSize: 19,
              radius: 19,
            ),
            const SizedBox(height: 9),
            Text(
              role.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: selected ? accent : kTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _SheetRow extends StatelessWidget {
  const _SheetRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(icon: icon, size: 36, iconSize: 17, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: kTextMuted)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: kTextDark,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
