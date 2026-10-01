import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'activity_card.dart';
import 'contact_screen.dart';
import 'demo_data.dart';
import 'history_screen.dart';
import 'leaderboard_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'rewards_page.dart';
import 'design_system.dart';
import '../models/app_role.dart';
import 'admin/ambassador_screens.dart';
import 'admin/bins_screen.dart';
import 'ambassador_application_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.role = AppRole.user});

  /// Ambassador tools only render when this is [AppRole.ambassador].
  final AppRole role;

  /// Brand logo.
  static const String logo = 'assets/icon/logo_boame.png';

  /// Clip art on the points card.
  static const String clipArt = 'assets/dashboardclipart1.png';

  /// Set to false to stop showing the placeholder activity rows.
  static const bool showDemoActivity = true;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SignedOutView();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text('User data not found')));
        }

        final Map<String, dynamic> data = snapshot.data!.data() as Map<String, dynamic>;
        final String name = (data['nickname'] ?? data['name'] ?? 'User') as String;
        final String avatarIcon = (data['avatarIcon'] ?? '') as String;
        final String points = '${data['points'] ?? 0}';
        final String bottles = '${data['bottles'] ?? 0}';
        final String weight = '${data['weight'] ?? 0.0}';
        final AmbassadorStatus ambassadorStatus =
            AmbassadorStatus.fromString(data['ambassadorStatus']);
        final bool isAmbassador = role == AppRole.ambassador;

        return Scaffold(
          backgroundColor: kBackground,
          body: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopBar(avatarIcon: avatarIcon),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hello 👋',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: kTextMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: kTextDark,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _PointsCard(
                        points: points,
                        bottles: bottles,
                        weight: weight,
                      ),
                      const SizedBox(height: 30),
                      const _SectionTitle('Quick Actions'),
                      const SizedBox(height: 14),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.86,
                        children: [
                          _QuickActionCard(
                            title: 'History',
                            icon: Icons.history_rounded,
                            tint: kPrimaryColor,
                            asset: 'assets/history.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const HistoryScreen()),
                            ),
                          ),
                          _QuickActionCard(
                            title: 'Rewards',
                            icon: Icons.card_giftcard_rounded,
                            tint: kAccentOrange,
                            asset: 'assets/rewrads.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RewardsScreen()),
                            ),
                          ),
                          _QuickActionCard(
                            title: 'Leaderboard',
                            icon: Icons.leaderboard_rounded,
                            tint: kColouredBottle,
                            asset: 'assets/leaderbaord.png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                            ),
                          ),
                          _QuickActionCard(
                            title: 'Contact Us',
                            icon: Icons.support_agent_rounded,
                            tint: kClearBottle,
                            asset: 'assets/contact (2).png',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ContactScreen()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      const _SectionTitle('Recent Activity'),
                      const SizedBox(height: 14),
                      _ActivityFeed(uid: user.uid),
                      const SizedBox(height: 30),
                      _AmbassadorSection(
                        uid: user.uid,
                        name: name,
                        isAmbassador: isAmbassador,
                        status: ambassadorStatus,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: kPrimaryColor,
            unselectedItemColor: kTextMuted,
            backgroundColor: Colors.white,
            onTap: (int index) {
              if (index == 1) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsScreen()));
              } else if (index == 2) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
              }
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Rewards'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// TOP BAR
// ============================================================

class _TopBar extends StatelessWidget {
  const _TopBar({required this.avatarIcon});

  final String avatarIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 14, 20, 0),
      child: Row(
        children: [
          SizedBox(
            height: 34,
            child: Image.asset(HomeScreen.logo, fit: BoxFit.contain),
          ),
          const Spacer(),
          const _NotificationBell(),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: kPrimaryColor,
                shape: BoxShape.circle,
              ),
              child: avatarIcon.isEmpty
                  ? const Icon(Icons.person_rounded, size: 24, color: Colors.white)
                  : Text(avatarIcon, style: const TextStyle(fontSize: 19)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .doc(user!.uid)
          .collection('items')
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        int count = snapshot.data?.docs.length ?? 0;

        // Review mode — fall back to the sample unread items so the dot shows.
        if (count == 0 && kDemoMode) {
          count = demoNotifications.where((DemoNotification n) => !n.read).length;
        }

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: kPrimaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_rounded, size: 23, color: Colors.white),
              ),
              if (count > 0)
                Positioned(
                  right: 1,
                  top: 1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: kAccentOrange,
                      shape: BoxShape.circle,
                      border: Border.all(color: kBackground, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: kAccentOrange.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// POINTS CARD
// ============================================================

class _PointsCard extends StatelessWidget {
  const _PointsCard({
    required this.points,
    required this.bottles,
    required this.weight,
  });

  final String points;
  final String bottles;
  final String weight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 14, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kPrimaryColor, kPrimaryDark],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOTAL POINTS',
                  style: TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  points,
                  style: const TextStyle(
                    fontSize: 42,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _PointsChip(icon: Icons.scale_rounded, value: '$weight kg'),
                    const SizedBox(width: 10),
                    _PointsChip(icon: Icons.local_drink_rounded, value: bottles),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 148,
            height: 148,
            child: Image.asset(HomeScreen.clipArt, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class _PointsChip extends StatelessWidget {
  const _PointsChip({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// QUICK ACTIONS
// ============================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: kTextDark,
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.tint,
    required this.asset,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color tint;
  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: kCardDecoration(radius: 22),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Clip art fills the top half.
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                      Icon(icon, size: 34, color: tint),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Label sits under the clip art.
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: kTextDark,
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// RECENT ACTIVITY
// ============================================================

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({required this.uid});

  final String uid;

  /// Placeholder rows so the layout can be reviewed before real data lands.
  static final List<ActivityRow> _demo = [
    ActivityRow(
      kind: 'Coloured',
      weight: '1.4 kg',
      points: '24',
      when: DateTime(2026, 9, 28),
    ),
    ActivityRow(
      kind: 'Clear',
      weight: '0.9 kg',
      points: '16',
      when: DateTime(2026, 9, 26),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('deposits')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        final List<QueryDocumentSnapshot> deposits =
            snapshot.data?.docs ?? [];
        final bool waiting =
            snapshot.connectionState == ConnectionState.waiting;
        final bool showDemo =
            !waiting && deposits.isEmpty && HomeScreen.showDemoActivity;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Recent Activity'),
            const SizedBox(height: 12),
            if (waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (showDemo) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kBeige,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 14,
                      color: kTextMuted,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'PREVIEW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: kTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ..._demo.map((ActivityRow row) => ActivityCard(row: row)),
            ] else if (deposits.isEmpty)
              const _EmptyActivityCard()
            else
              ...deposits.map((QueryDocumentSnapshot doc) {
                final Map<String, dynamic> d =
                    (doc.data() as Map<String, dynamic>?) ??
                        <String, dynamic>{};
                return ActivityCard(row: ActivityRow.fromDocument(d));
              }),
          ],
        );
      },
    );
  }
}

class _EmptyActivityCard extends StatelessWidget {
  const _EmptyActivityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: kPastelMint,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.recycling_rounded,
            size: 42,
            color: kPrimaryColor,
          ),
          const SizedBox(height: 12),
          const Text(
            'No recycling activity yet',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Drop a bottle at any kiosk and your points will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: kTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// AMBASSADOR SECTION
// Role gated: only an approved ambassador sees the tools, and
// everybody else sees the invitation to apply.
// ============================================================

class _AmbassadorSection extends StatelessWidget {
  const _AmbassadorSection({
    required this.uid,
    required this.name,
    required this.isAmbassador,
    required this.status,
  });

  final String uid;
  final String name;
  final bool isAmbassador;
  final AmbassadorStatus status;

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    if (isAmbassador) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Ambassador Tools'),
          const SizedBox(height: 14),
          _AmbassadorTile(
            icon: Icons.volunteer_activism_rounded,
            title: 'Ambassador dashboard',
            subtitle: 'My bins, bin map and live status of every bin',
            tint: kPastelMint,
            accent: kPrimaryColor,
            onTap: () => _push(
              context,
              AmbassadorDashboard(
                uid: uid,
                name: name,
                onBrowseBins: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BinsScreen(
                      uid: uid,
                      role: AppRole.ambassador,
                      displayName: name,
                      title: 'My bins',
                      showOnlyMine: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (status == AmbassadorStatus.pending) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Ambassador'),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFBEFD9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kAccentOrange.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    size: 22,
                    color: kAccentOrange,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Application under review',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: kTextDark,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'An admin will be in touch. Your tools unlock once you are approved.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: kTextMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Not applied (or previously rejected) — invite them.
    final rejected = status == AmbassadorStatus.rejected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Ambassador'),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => _push(context, const AmbassadorApplicationScreen()),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kPrimaryColor,
                  Color.lerp(kPrimaryColor, kPrimaryDark, 0.55)!,
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: kPrimaryDark.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.volunteer_activism_rounded,
                    size: 25,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rejected ? 'Apply again' : 'Become an ambassador',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Look after the bins in your area and flag them when they fill up.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AmbassadorTile extends StatelessWidget {
  const _AmbassadorTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: kPrimaryDark.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, size: 22, color: accent),
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
          Icon(Icons.chevron_right_rounded, size: 20, color: accent.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}
