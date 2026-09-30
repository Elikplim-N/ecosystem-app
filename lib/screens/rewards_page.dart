import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'demo_data.dart';
import 'design_system.dart';
import 'ui_helpers.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('No user is logged in'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Rewards'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (userSnapshot.hasError) {
            return Center(
              child: Text('Error loading user data:\n${userSnapshot.error}'),
            );
          }

          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: Text('User data not found'));
          }

          final userData =
              userSnapshot.data!.data() as Map<String, dynamic>;

          // Review mode: a mid-range balance so both the affordable and the
          // locked card states are visible before real data exists.
          final int points = kDemoMode && (userData['points'] ?? 0) == 0
              ? 850
              : (userData['points'] ?? 0) as int;

          return Column(
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
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('rewards')
                      .where('active', isEqualTo: true)
                      .orderBy('costPoints')
                      .snapshots(),
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

                    final List<QueryDocumentSnapshot> live =
                        rewardSnapshot.data?.docs ?? [];

                    final bool usingDemo = live.isEmpty && kDemoMode;

                    if (live.isEmpty && !kDemoMode) {
                      return const Center(
                        child: Text('No rewards available right now.'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      itemCount:
                          usingDemo ? demoRewards.length : live.length,
                      itemBuilder: (context, index) {
                        final QueryDocumentSnapshot? reward =
                            usingDemo ? null : live[index];

                        final Map<String, dynamic> data = usingDemo
                            ? <String, dynamic>{
                                'title': demoRewards[index].title,
                                'costPoints': demoRewards[index].costPoints,
                                'type': demoRewards[index].type,
                              }
                            : reward!.data() as Map<String, dynamic>;

                        final String title = '${data['title'] ?? 'Reward'}';
                        final num costPoints =
                            (data['costPoints'] ?? 0) as num;
                        final String type = '${data['type'] ?? 'standard'}';
                        final bool canAfford = points >= costPoints;

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
                                  color: (canAfford
                                          ? kPrimaryColor
                                          : kTextMuted)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  type == 'partner'
                                      ? Icons.handshake_rounded
                                      : Icons.card_giftcard_rounded,
                                  size: 24,
                                  color: canAfford
                                      ? kPrimaryColor
                                      : kTextMuted,
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Reward name, with the point cost beneath it.
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
                                      '$costPoints points',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: canAfford
                                            ? kPrimaryColor
                                            : kTextMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: canAfford
                                    ? () => _confirmRedeem(
                                          context,
                                          user.uid,
                                          reward?.id ?? 'demo',
                                          title,
                                          costPoints,
                                          userData,
                                        )
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimaryColor,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: kBeigeDeep,
                                  disabledForegroundColor: kTextMuted,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                child: const Text(
                                  'REDEEM',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
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
          );
        },
      ),
    );
  }

  // ==========================================================
  // CONFIRM REDEMPTION
  // ==========================================================

  static void _confirmRedeem(
    BuildContext context,
    String uid,
    String rewardId,
    String title,
    num costPoints,
    Map<String, dynamic> userData,
  ) {
    final phoneNumber =
        userData['phone'] ?? userData['phoneNumber'] ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Redemption'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Redeem "$title" for $costPoints points?'),
              const SizedBox(height: 12),
              if (phoneNumber.toString().isNotEmpty)
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
              onPressed: phoneNumber.toString().isEmpty
                  ? null
                  : () {
                      Navigator.pop(context);
                      _redeem(
                        context,
                        uid,
                        rewardId,
                        title,
                        costPoints,
                        phoneNumber.toString(),
                      );
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

  static Future<void> _redeem(
    BuildContext context,
    String uid,
    String rewardId,
    String title,
    num costPoints,
    String phoneNumber,
  ) async {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid);

    try {
      await FirebaseFirestore.instance
          .runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);

        if (!snapshot.exists) {
          throw Exception('User account not found.');
        }

        final userData = snapshot.data()!;
        final currentPoints = (userData['points'] ?? 0) as num;

        if (currentPoints < costPoints) {
          throw Exception('Not enough points.');
        }

        final redemptionRef = userRef
            .collection('redemptions')
            .doc();

        transaction.update(
          userRef,
          {'points': currentPoints - costPoints},
        );

        transaction.set(
          redemptionRef,
          {
            'rewardId': rewardId,
            'title': title,
            'costPoints': costPoints,
            'phoneNumber': phoneNumber,
            'status': 'pending',
            'timestamp': FieldValue.serverTimestamp(),
          },
        );
      });

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Redemption Submitted 🎉'),
            content: Text(
              '"$title" has been submitted successfully.\n\n'
              'Your reward is currently being processed.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('DONE'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Redemption failed: $e')),
      );
    }
  }
}
