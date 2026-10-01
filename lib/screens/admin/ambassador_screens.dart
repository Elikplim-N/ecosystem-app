import 'package:flutter/material.dart';
import '../../data/bins_repository.dart';
import '../../data/user_repository.dart';
import '../../models/app_role.dart';
import '../../models/bin.dart';
import '../../models/member.dart';
import 'ghana_bin_map.dart';
import '../../screens/design_system.dart';

/// Admin queue for people who applied to become ambassadors.
class AmbassadorApplicationsScreen extends StatelessWidget {
  const AmbassadorApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = UserRepository();

    return AppPage(
      title: 'Ambassador requests',
      backgroundColor: kAdminBackground,
      body: StreamBuilder<List<Member>>(
        stream: repo.watchApplications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) return ErrorView(message: '${snapshot.error}');

          final pending = snapshot.data ?? const <Member>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              if (pending.isEmpty)
                const EmptyState(
                  icon: Icons.verified_user_rounded,
                  title: 'Nothing to review',
                  message:
                      'New ambassador applications will appear here for approval.',
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBEFD9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.hourglass_top_rounded,
                        size: 19,
                        color: kAccentOrange,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${pending.length} application${pending.length == 1 ? '' : 's'} waiting on you',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: kTextDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ...pending.map(
                  (member) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _ApplicationCard(
                      member: member,
                      onApprove: () => _review(context, member, true),
                      onReject: () => _review(context, member, false),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _review(
    BuildContext context,
    Member member,
    bool approve,
  ) async {
    final confirmed = await confirmDialog(
      context,
      title: approve ? 'Approve ${member.displayName}?' : 'Reject application?',
      message: approve
          ? 'They immediately gain ambassador tools and can add or update bins.'
          : 'They will be told the application was not approved and can re-apply.',
      confirmLabel: approve ? 'APPROVE' : 'REJECT',
      destructive: !approve,
    );
    if (!confirmed) return;

    try {
      await UserRepository().reviewAmbassadorApplication(
        uid: member.uid,
        approve: approve,
      );
      if (context.mounted) {
        showToast(
          context,
          approve
              ? '${member.displayName} is now an ambassador'
              : 'Application rejected',
        );
      }
    } catch (e) {
      if (context.mounted) showToast(context, 'Could not update: $e');
    }
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.member,
    required this.onApprove,
    required this.onReject,
  });

  final Member member;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  String get _appliedLabel {
    final date = member.appliedAt;
    if (date == null) return 'Recently';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      border: kAccentOrange.withValues(alpha: 0.32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: member.tint,
                child: Text(
                  member.avatarIcon,
                  style: const TextStyle(fontSize: 21),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 3),
                    Text(
                      member.phone.isEmpty ? member.email : member.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: kTextMuted),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: 'Applied $_appliedLabel',
                color: AmbassadorStatus.pending.color,
                dense: true,
              ),
            ],
          ),
          if (member.area != null && member.area!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.place_rounded, size: 15, color: kPrimaryColor),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    member.area!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTextDark,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (member.motivation != null && member.motivation!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: kBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                member.motivation!,
                style: const TextStyle(
                  fontSize: 13,
                  color: kTextMuted,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close_rounded, size: 17),
                  label: const Text('REJECT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC0392B),
                    side: const BorderSide(
                      color: Color(0xFFC0392B),
                      width: 1.4,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_rounded, size: 17),
                  label: const Text('APPROVE AS AMBASSADOR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ambassador home. Deliberately a trimmed view of the admin dashboard:
/// everything an ambassador can actually do, nothing they cannot.
class AmbassadorDashboard extends StatelessWidget {
  const AmbassadorDashboard({
    super.key,
    required this.uid,
    required this.name,
    this.onBrowseBins,
  });

  final String uid;
  final String name;

  /// When null the tiles are hidden and the dashboard is read-only.
  final VoidCallback? onBrowseBins;

  @override
  Widget build(BuildContext context) {
    final repo = BinsRepository();

    return AppPage(
      title: 'Ambassador',
      body: StreamBuilder<List<Bin>>(
        stream: repo.watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) return ErrorView(message: '${snapshot.error}');

          final bins = snapshot.data ?? const <Bin>[];
          final summary = BinsRepository.summarise(bins);
          final mine = bins.where((b) => b.createdById == uid).toList();
          final mineNeeds = mine.where((b) => b.needsCollection).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              GradientCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Ambassador'),
                    const SizedBox(height: 8),
                    Text(
                      'Hello, ${name.split(' ').first}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Keep your bins healthy. Mark them full when you see them '
                      'overflowing, and add new ones in your area.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: StatPill(
                            value: '${mine.length}',
                            label: 'My bins',
                            icon: Icons.delete_outline_rounded,
                            onDark: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatPill(
                            value: '$mineNeeds',
                            label: 'Need pickup',
                            icon: Icons.delete_rounded,
                            accent: kClearBottle,
                            onDark: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatPill(
                            value: '${summary.full}',
                            label: 'Full overall',
                            icon: Icons.warning_amber_rounded,
                            accent: kAccentOrange,
                            onDark: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (onBrowseBins != null)
                SoftCard(
                  onTap: onBrowseBins,
                  child: Row(
                    children: [
                      const IconChip(
                        icon: Icons.manage_search_rounded,
                        size: 48,
                        iconSize: 23,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'My bins',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: kTextDark,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              mine.isEmpty
                                  ? 'Add the first bin in your area'
                                  : 'Update status, add bins, mark them collected',
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
                ),
              if (onBrowseBins != null) const SizedBox(height: 22),
              const SectionHeader(
                title: 'Bins near you',
                subtitle: 'Live status across all areas',
              ),
              GhanaBinMap(bins: bins, height: 280),
              const SizedBox(height: 14),
              if (bins.any((b) => !b.isActive))
                SoftCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.pause_circle_rounded,
                        size: 17,
                        color: kTextMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${summary.disabled} bin${summary.disabled == 1 ? ' is' : 's are'} '
                          'currently disabled.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: kTextMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Read-only bin summary for the ambassador map.
void showBinQuickLook(BuildContext context, Bin bin) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => SheetPanel(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 18),
            Row(
              children: [
                IconChip(
                  icon: bin.status.icon,
                  tint: bin.status.tint,
                  color: bin.status.color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bin.name,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: kTextDark,
                        ),
                      ),
                      Text(
                        '${bin.code}  •  ${bin.locationLabel}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: kTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LevelBar(
              value: bin.fillLevel / 100,
              color: bin.status.color,
              height: 10,
            ),
            const SizedBox(height: 8),
            Text(
              bin.hasSensor
                  ? 'Reported by ${bin.sensorId ?? 'a sensor'}'
                  : 'Set manually by staff',
              style: const TextStyle(fontSize: 12, color: kTextMuted),
            ),
          ],
        ),
      ),
    ),
  );
}
