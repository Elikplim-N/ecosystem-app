import 'package:flutter/material.dart';
import '../data/activity_repository.dart';
import '../data/bins_repository.dart';
import '../data/user_repository.dart';
import '../services/auth_service.dart';
import '../models/app_role.dart';
import '../models/bin.dart';
import '../models/member.dart';
import 'admin/ambassador_screens.dart';
import 'admin/bins_screen.dart';
import 'admin/ghana_bin_map.dart';
import 'admin/rfid_screen.dart';
import 'admin/users_screen.dart';
import 'admin_manage_rewards_screen.dart';
import 'demo_data.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'home_screen.dart';
import 'design_system.dart';

/// Super-admin home. Every management area hangs off this screen.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _users = UserRepository();
  final _bins = BinsRepository();

  String get _uid => auth.currentUid;

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAdminBackground,
      body: StreamBuilder<List<Member>>(
        stream: _users.watchMembers(),
        builder: (context, userSnapshot) {
          return StreamBuilder<List<Bin>>(
            stream: _bins.watch(),
            builder: (context, binSnapshot) {
              final members = userSnapshot.data ?? const <Member>[];
              final bins = binSnapshot.data ?? const <Bin>[];
              final binSummary = BinsRepository.summarise(bins);
              final pending = members
                  .where((m) => m.isPendingApplication)
                  .length;

              final loading =
                  userSnapshot.connectionState == ConnectionState.waiting ||
                  binSnapshot.connectionState == ConnectionState.waiting;

              final carded = members
                  .where((m) => (m.rfidUid ?? '').isNotEmpty)
                  .length;
              final memberRing = members.isEmpty
                  ? 0.0
                  : carded / members.length;
              final activeRing = binSummary.total == 0
                  ? 0.0
                  : binSummary.active / binSummary.total;
              final fullRing = binSummary.total == 0
                  ? 0.0
                  : binSummary.full / binSummary.total;
              final pendingRing = members.isEmpty
                  ? 0.0
                  : pending / members.length;

              return ListView(
                padding: const EdgeInsets.only(bottom: 44),
                children: [
                  const _AdminTopBar(),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Good day, Admin',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                            color: kTextDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Everything happening across the recycling network today.',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: kTextMuted,
                            height: 1.4,
                          ),
                        ),
                        StreamBuilder<MemberSession>(
                          stream: auth.sessions,
                          builder: (context, snap) {
                            final m = snap.data?.member;
                            if (m == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: SoftCard(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const HomeScreen(role: AppRole.admin),
                                  ),
                                ),
                                color: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: kPastelMint,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.recycling_rounded,
                                        color: kPrimaryColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Your Personal Recycling Tracking',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: kTextMuted,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${m.points} pts  •  ${m.bottles} bottles  •  ${m.weight.toStringAsFixed(1)} kg',
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: kTextDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: kMetricTealTint,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Open',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: kMetricTeal,
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            size: 14,
                                            color: kMetricTeal,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        _MetricGrid(
                          loading: loading,
                          members: members.length,
                          carded: carded,
                          memberRing: memberRing,
                          totalBins: binSummary.total,
                          activeBins: binSummary.active,
                          activeRing: activeRing,
                          fullBins: binSummary.full,
                          fullRing: fullRing,
                          pending: pending,
                          pendingRing: pendingRing,
                          onOpenPending: () =>
                              _push(const AmbassadorApplicationsScreen()),
                          onOpenFull: () => _push(
                            BinsScreen(
                              uid: _uid,
                              role: AppRole.admin,
                              displayName: 'Admin',
                              title: 'Manage bins',
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        GhanaBinMap(bins: bins),
                      ],
                    ),
                  ),
                  if (pending > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: SoftCard(
                        onTap: () =>
                            _push(const AmbassadorApplicationsScreen()),
                        color: const Color(0xFFFBEFD9),
                        shadow: false,
                        border: kAccentOrange.withValues(alpha: 0.4),
                        child: Row(
                          children: [
                            const IconChip(
                              icon: Icons.hourglass_top_rounded,
                              tint: Colors.white,
                              color: kAccentOrange,
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ambassador requests',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: kTextDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$pending waiting for your review',
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
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Column(
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: SectionHeader(title: 'Manage'),
                        ),
                        _AdminTile(
                          icon: Icons.people_alt_rounded,
                          title: 'All members',
                          subtitle: 'Roles, points, access and RFID links',
                          tint: kPastelMint,
                          accent: kPrimaryColor,
                          onTap: () => _push(UsersScreen(currentUid: _uid)),
                        ),
                        const SizedBox(height: 12),
                        _AdminTile(
                          icon: Icons.credit_card_rounded,
                          title: 'RFID cards',
                          subtitle: 'Register, link, unlink and void cards',
                          tint: kPastelBlue,
                          accent: kColouredBottle,
                          onTap: () => _push(const RfidScreen()),
                        ),
                        const SizedBox(height: 12),
                        _AdminTile(
                          icon: Icons.delete_outline_rounded,
                          title: 'Bins',
                          subtitle: 'Add, locate, fill and disable bins',
                          tint: kPastelMint,
                          accent: kPrimaryColor,
                          badge: loading ? null : '${binSummary.full} full',
                          badgeColor: kClearBottle,
                          onTap: () => _push(
                            BinsScreen(
                              uid: _uid,
                              role: AppRole.admin,
                              displayName: 'Admin',
                              title: 'Manage bins',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _AdminTile(
                          icon: Icons.volunteer_activism_rounded,
                          title: 'Ambassador requests',
                          subtitle: 'Approve or reject applications',
                          tint: const Color(0xFFFBEFD9),
                          accent: kAccentOrange,
                          badge: pending > 0 ? '$pending' : null,
                          badgeColor: kAccentOrange,
                          onTap: () =>
                              _push(const AmbassadorApplicationsScreen()),
                        ),
                        const SizedBox(height: 12),
                        _AdminTile(
                          icon: Icons.card_giftcard_rounded,
                          title: 'Rewards catalogue',
                          subtitle: 'Add, activate or remove rewards',
                          tint: kMetricBlueTint,
                          accent: kMetricBlue,
                          onTap: () => _push(const AdminManageRewardsScreen()),
                        ),
                        const SizedBox(height: 24),
                        const SectionHeader(title: 'Analytics'),
                        _BinDistributionCard(bins: bins),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// 2x2 grid of metric cards. Every ratio is computed from the live
/// collections by the caller, so nothing here is illustrative data.
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.loading,
    required this.members,
    required this.carded,
    required this.memberRing,
    required this.totalBins,
    required this.activeBins,
    required this.activeRing,
    required this.fullBins,
    required this.fullRing,
    required this.pending,
    required this.pendingRing,
    required this.onOpenPending,
    required this.onOpenFull,
  });

  final bool loading;
  final int members;
  final int carded;
  final double memberRing;
  final int totalBins;
  final int activeBins;
  final double activeRing;
  final int fullBins;
  final double fullRing;
  final int pending;
  final double pendingRing;
  final VoidCallback onOpenPending;
  final VoidCallback onOpenFull;

  String get _dash => loading ? '--' : '0';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Members',
                  unit: 'Total',
                  value: loading ? _dash : '$members',
                  icon: Icons.people_alt_rounded,
                  tint: kMetricTealTint,
                  accent: kMetricTeal,
                  visualiser: MiniRing(
                    progress: memberRing,
                    color: kMetricTeal,
                    label: '${(memberRing * 100).round()}%',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  title: 'Bins',
                  unit: '$activeBins active',
                  value: loading ? _dash : '$totalBins',
                  icon: Icons.delete_outline_rounded,
                  tint: kMetricBlueTint,
                  accent: kMetricBlue,
                  visualiser: MiniRing(
                    progress: activeRing,
                    color: kMetricBlue,
                    label: '${(activeRing * 100).round()}%',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Bins Full',
                  unit: 'Needs collection',
                  value: loading ? _dash : '$fullBins',
                  icon: Icons.error_rounded,
                  tint: kMetricAmberTint,
                  accent: kMetricAmber,
                  onTap: onOpenFull,
                  visualiser: MiniRing(
                    progress: fullRing,
                    color: kMetricAmber,
                    label: '${(fullRing * 100).round()}%',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  title: 'Requests',
                  unit: 'Awaiting review',
                  value: loading ? _dash : '$pending',
                  icon: Icons.workspace_premium_rounded,
                  tint: kMetricRoseTint,
                  accent: kMetricRose,
                  onTap: onOpenPending,
                  visualiser: MiniRing(
                    progress: pendingRing,
                    color: kMetricRose,
                    label: '${(pendingRing * 100).round()}%',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Admin top bar. Mirrors the member home bar: logo left, unread
/// notifications and the profile on the right.
class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar();

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    if (!auth.isSignedIn) {
      return AppTopBar(
        onNotifications: () => _open(context, const NotificationsScreen()),
        onProfile: () => _open(context, const ProfileScreen()),
      );
    }

    return StreamBuilder<NotificationFeed>(
      stream: NotificationsRepository().watchFeed(),
      builder: (BuildContext context, AsyncSnapshot<NotificationFeed> snapshot) {
        int count = snapshot.data?.unread ?? 0;

        // Review mode — fall back to the sample unread items so the dot shows.
        if (count == 0 && kDemoMode) {
          count = demoNotifications
              .where((DemoNotification n) => !n.read)
              .length;
        }

        return AppTopBar(
          notificationCount: count,
          action: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const HomeScreen(role: AppRole.admin),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kMetricTealTint,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kMetricTeal.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.recycling_rounded, size: 16, color: kMetricTeal),
                  SizedBox(width: 4),
                  Text(
                    'Member View',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kMetricTeal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          onNotifications: () => _open(context, const NotificationsScreen()),
          onProfile: () => _open(context, const ProfileScreen()),
        );
      },
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.accent,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final Color accent;
  final VoidCallback onTap;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          IconChip(
            icon: icon,
            tint: tint,
            color: accent,
            size: 48,
            iconSize: 23,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: kTextMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            StatusChip(label: badge!, color: badgeColor ?? accent, dense: true),
          ],
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: accent.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

/// At-a-glance network health.
/// Where the deployed bins currently sit, derived straight from the live
/// list so the chart can never drift from the data behind it.
class _BinDistributionCard extends StatelessWidget {
  const _BinDistributionCard({required this.bins});

  final List<Bin> bins;

  @override
  Widget build(BuildContext context) {
    if (bins.isEmpty) {
      return SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: const Row(
          children: [
            Icon(Icons.insights_rounded, size: 18, color: kTextMuted),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Add a bin to start seeing where the network is filling up.',
                style: TextStyle(fontSize: 13, color: kTextMuted, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    final rows = <_ChartRow>[
      _ChartRow(
        'Empty enough to use',
        bins.where((b) => b.status == BinStatus.available).length,
        kMetricTeal,
      ),
      _ChartRow(
        'Filling up',
        bins.where((b) => b.status == BinStatus.filling).length,
        kMetricAmber,
      ),
      _ChartRow(
        'Full, needs pickup',
        bins.where((b) => b.status == BinStatus.full).length,
        kMetricRose,
      ),
      _ChartRow(
        'Out of service',
        bins.where((b) => b.status == BinStatus.disabled).length,
        kTextMuted,
      ),
    ];
    final peak = rows.fold<int>(
      1,
      (max, row) => row.value > max ? row.value : max,
    );
    final fullCount = rows[2].value;

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Bin fill levels',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                    color: kTextDark,
                  ),
                ),
              ),
              Text(
                '${bins.length} bins',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: kTextMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            fullCount > 0
                ? '$fullCount bin${fullCount == 1 ? '' : 's'} waiting for a pickup'
                : 'Every active bin is within capacity',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: fullCount > 0 ? kMetricAmber : kMetricTeal,
            ),
          ),
          const SizedBox(height: 18),
          for (final row in rows) ...[
            _BarRow(
              label: row.label,
              value: row.value,
              peak: peak,
              color: row.color,
            ),
            const SizedBox(height: 11),
          ],
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: kBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.block_rounded, size: 16, color: kTextMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    bins.where((b) => b.rejectedFillLevel > 0).isEmpty
                        ? 'No rejected waste reported'
                        : '${bins.where((b) => b.rejectedFillLevel > 0).length} bin${bins.where((b) => b.rejectedFillLevel > 0).length == 1 ? '' : 's'} holding rejected waste',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kTextDark,
                    ),
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

class _ChartRow {
  const _ChartRow(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;
}

/// One labelled horizontal bar.
class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.peak,
    required this.color,
  });

  final String label;
  final int value;
  final int peak;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kTextDark,
                ),
              ),
            ),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: kTextDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LevelBar(
          value: value / peak,
          color: color,
          track: color.withValues(alpha: 0.12),
          height: 8,
        ),
      ],
    );
  }
}
