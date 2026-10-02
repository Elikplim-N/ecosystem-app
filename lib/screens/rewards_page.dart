import 'package:flutter/material.dart';

import '../data/rewards_repository.dart';
import '../models/member.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'demo_data.dart';
import 'design_system.dart';
import 'ui_helpers.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final RewardsRepository rewards = RewardsRepository();
    return StreamBuilder<MemberSession>(
      stream: auth.sessions,
      builder: (context, session) {
        final member = session.data?.member;

        if (!session.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!session.data!.signedIn || member == null) {
          return const Scaffold(
            body: Center(child: Text('No user is logged in')),
          );
        }

        // Review mode: a mid-range balance so both the affordable and the
        // locked card states are visible before real data exists.
        final int points = kDemoMode && member.points == 0
            ? 850
            : member.points;

        return Scaffold(
          backgroundColor: kBackground,
          appBar: AppBar(title: const Text('Rewards'), centerTitle: true),
          body: Column(
            children: [
              // =========================
              // AVAILABLE POINTS
              // =========================
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [kPrimaryColor, kPrimaryDark],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimaryColor.withValues(alpha: 0.28),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AVAILABLE POINTS',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$points',
                      style: const TextStyle(
                        fontSize: 42,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
              // =========================
              // REWARDS LIST
              // =========================
              Expanded(
                child: StreamBuilder<List<Reward>>(
                  stream: rewards.watchRewards(),
                  builder: (context, rewardSnapshot) {
                    if (rewardSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (rewardSnapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Error loading rewards:\n${rewardSnapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final List<Reward> live = rewardSnapshot.data ?? const [];

                    final bool usingDemo = live.isEmpty && kDemoMode;

                    if (live.isEmpty && !kDemoMode) {
                      return const Center(
                        child: Text('No rewards available right now.'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      itemCount: usingDemo ? demoRewards.length : live.length,
                      itemBuilder: (context, index) {
                        if (usingDemo) {
                          final demo = demoRewards[index];
                          return _card(
                            context,
                            title: demo.title,
                            costPoints: demo.costPoints,
                            type: demo.type,
                            canAfford: points >= demo.costPoints,
                            onRedeem: null,
                          );
                        }

                        final Reward reward = live[index];

                        return _card(
                          context,
                          title: reward.title,
                          costPoints: reward.costPoints,
                          type: reward.category,
                          // The server decides this, from the same row it
                          // will check when the points are actually taken.
                          canAfford: reward.affordable && !reward.outOfStock,
                          subtitle: reward.outOfStock
                              ? 'Out of stock'
                              : reward.description,
                          onRedeem: () =>
                              _confirmRedeem(context, member, reward),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // ONE REWARD ROW
  // ==========================================================

  /// Extracted so the demo and live rows are literally the same widget. The
  /// two used to be built separately, which is how they drifted apart.
  static Widget _card(
    BuildContext context, {
    required String title,
    required int costPoints,
    required String type,
    required bool canAfford,
    required VoidCallback? onRedeem,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBeigeDeep),
        boxShadow: [
          BoxShadow(
            color: kPrimaryDark.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (canAfford ? kPrimaryColor : kTextMuted).withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              type == 'partner'
                  ? Icons.handshake_rounded
                  : Icons.card_giftcard_rounded,
              size: 24,
              color: canAfford ? kPrimaryColor : kTextMuted,
            ),
          ),
          const SizedBox(width: 14),
          // Reward name, with the point cost beneath it.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle != null && subtitle.isNotEmpty
                      ? subtitle
                      : '$costPoints points',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: canAfford ? kPrimaryColor : kTextMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: canAfford ? onRedeem : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: kBeigeDeep,
              disabledForegroundColor: kTextMuted,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text(
              'REDEEM',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // CONFIRM REDEMPTION
  // ==========================================================

  static void _confirmRedeem(
    BuildContext context,
    Member member,
    Reward reward,
  ) {
    final phoneNumber = member.phone;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Redemption'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Redeem "${reward.title}" for ${reward.costPoints} points?'),
              const SizedBox(height: 12),
              if (phoneNumber.isNotEmpty)
                Text(
                  'Reward will be processed for:\n$phoneNumber',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )
              else
                const Text(
                  'No phone number is saved on your account.',
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: phoneNumber.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context);
                      _redeem(context, reward);
                    },
              child: const Text('CONFIRM'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // REDEEM REWARD
  // ==========================================================

  /// Posts the redemption and lets the server take the points.
  ///
  /// The previous version opened a Firestore transaction on the client that
  /// read the balance, subtracted the cost and wrote a redemption document.
  /// Anything that interrupted that — the app closing, the network dropping,
  /// a rule rejection — either cost the points without recording the request
  /// or recorded the request without taking the points. The API does the same
  /// thing in one database transaction, so it cannot land half-done.
  static Future<void> _redeem(BuildContext context, Reward reward) async {
    try {
      final result = await RewardsRepository().redeem(reward.id);

      // The balance moved server-side, so the session member is now stale.
      // Refreshing it is what updates the points card behind this screen.
      await auth.refreshCurrentMember();

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Redemption Submitted 🎉'),
          content: Text(
            '"${result.rewardTitle}" has been submitted successfully.\n\n'
            'You have ${result.pointsLeft} points left. '
            'Your reward is currently being processed.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('DONE'),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.isUserFacing ? e.message : 'Redemption failed. Try again.',
          ),
        ),
      );
    }
  }
}
