import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      appBar: AppBar(
        title: const Text(
          'Rewards',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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

          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: Text('User data not found'));
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final points = (userData['points'] ?? 0) as num;

          return Column(
            children: [
              // Points header
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(),
                ),
                child: Column(
                  children: [
                    const Text(
                      'AVAILABLE POINTS',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$points',
                      style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              // Rewards catalog
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
                        child: Text('Error: ${rewardSnapshot.error}'),
                      );
                    }

                    final rewards = rewardSnapshot.data?.docs ?? [];

                    if (rewards.isEmpty) {
                      return const Center(
                        child: Text('No rewards available right now.'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: rewards.length,
                      itemBuilder: (context, index) {
                        final reward = rewards[index];
                        final data = reward.data() as Map<String, dynamic>;

                        final title = data['title'] ?? 'Reward';
                        final description = data['description'] ?? '';
                        final costPoints = (data['costPoints'] ?? 0) as num;
                        final canAfford = points >= costPoints;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.card_giftcard, size: 36),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      description,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '$costPoints points',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
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
                                          reward.id,
                                          title,
                                          costPoints,
                                        )
                                    : null,
                                child: const Text('REDEEM'),
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

  // ----------------------------------------------------------
  // CONFIRM REDEMPTION
  // ----------------------------------------------------------
  static void _confirmRedeem(
    BuildContext context,
    String uid,
    String rewardId,
    String title,
    num costPoints,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Redemption'),
          content: Text(
            'Redeem "$title" for $costPoints points?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _redeem(context, uid, rewardId, title, costPoints);
              },
              child: const Text('CONFIRM'),
            ),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------------
  // REDEEM — deduct points, log redemption
  // ----------------------------------------------------------
  static Future<void> _redeem(
    BuildContext context,
    String uid,
    String rewardId,
    String title,
    num costPoints,
  ) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);

        if (!snapshot.exists) {
          throw Exception('User account not found.');
        }

        final currentPoints = (snapshot.data()!['points'] ?? 0) as num;

        if (currentPoints < costPoints) {
          throw Exception('Not enough points.');
        }

        transaction.update(userRef, {
          'points': currentPoints - costPoints,
        });

        transaction.set(userRef.collection('redemptions').doc(), {
          'rewardId': rewardId,
          'title': title,
          'costPoints': costPoints,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Redeemed 🎉'),
            content: Text('"$title" has been redeemed successfully.'),
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