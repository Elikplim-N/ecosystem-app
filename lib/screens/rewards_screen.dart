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
        title: const Text('Rewards'),
        centerTitle: true,
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),

        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (userSnapshot.hasError) {
            return Center(
              child: Text(
                'Error loading user data:\n${userSnapshot.error}',
              ),
            );
          }

          if (!userSnapshot.hasData ||
              !userSnapshot.data!.exists) {
            return const Center(
              child: Text('User data not found'),
            );
          }

          final userData =
              userSnapshot.data!.data() as Map<String, dynamic>;

          final points =
              (userData['points'] ?? 0) as num;

          return Column(
            children: [
              // =========================
              // AVAILABLE POINTS
              // =========================
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      '$points',
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    const Text(
                      'Keep recycling to earn more rewards!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                      ),
                    ),
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
                      .where(
                        'active',
                        isEqualTo: true,
                      )
                      .orderBy('costPoints')
                      .snapshots(),

                  builder: (context, rewardSnapshot) {
                    if (rewardSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (rewardSnapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Error loading rewards:\n'
                            '${rewardSnapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final rewards =
                        rewardSnapshot.data?.docs ?? [];

                    if (rewards.isEmpty) {
                      return const Center(
                        child: Text(
                          'No rewards available right now.',
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),

                      itemCount: rewards.length,

                      itemBuilder: (context, index) {
                        final reward = rewards[index];

                        final data =
                            reward.data()
                                as Map<String, dynamic>;

                        final title =
                            data['title'] ?? 'Reward';

                        final description =
                            data['description'] ?? '';

                        final costPoints =
                            (data['costPoints'] ?? 0) as num;

                        final type =
                            data['type'] ?? 'standard';

                        final partnerName =
                            data['partnerName'];

                        final canAfford =
                            points >= costPoints;

                        return Container(
                          margin: const EdgeInsets.only(
                            bottom: 14,
                          ),

                          padding: const EdgeInsets.all(18),

                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(16),
                            border: Border.all(),
                          ),

                          child: Row(
                            children: [
                              // =========================
                              // REWARD ICON
                              // =========================
                              Icon(
                                type == 'partner'
                                    ? Icons.handshake
                                    : Icons.card_giftcard,

                                size: 36,

                                color: type == 'partner'
                                    ? const Color(
                                        0xFFFFB020,
                                      )
                                    : null,
                              ),

                              const SizedBox(width: 15),

                              // =========================
                              // REWARD INFORMATION
                              // =========================
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,

                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            title,
                                            style:
                                                const TextStyle(
                                              fontSize: 16,
                                              fontWeight:
                                                  FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        if (type ==
                                                'partner' &&
                                            partnerName != null) ...[
                                          const SizedBox(
                                            width: 8,
                                          ),

                                          Container(
                                            padding:
                                                const EdgeInsets
                                                    .symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),

                                            decoration:
                                                BoxDecoration(
                                              color:
                                                  const Color(
                                                0xFFFFB020,
                                              ).withOpacity(0.15),

                                              borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                8,
                                              ),
                                            ),

                                            child: Text(
                                              partnerName
                                                  .toString(),

                                              style:
                                                  const TextStyle(
                                                fontSize: 10,
                                                fontWeight:
                                                    FontWeight
                                                        .bold,
                                                color: Color(
                                                  0xFFB07800,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      description,
                                      style:
                                          const TextStyle(
                                        fontSize: 13,
                                      ),
                                    ),

                                    const SizedBox(height: 6),

                                    Text(
                                      '$costPoints points',
                                      style:
                                          const TextStyle(
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),

                                    if (!canAfford) ...[
                                      const SizedBox(height: 4),

                                      Text(
                                        'You need '
                                        '${costPoints - points} '
                                        'more points',
                                        style:
                                            const TextStyle(
                                          fontSize: 11,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(width: 10),

                              // =========================
                              // REDEEM BUTTON
                              // =========================
                              ElevatedButton(
                                onPressed: canAfford
                                    ? () {
                                        _confirmRedeem(
                                          context,
                                          user.uid,
                                          reward.id,
                                          title.toString(),
                                          costPoints,
                                          userData,
                                        );
                                      }
                                    : null,

                                child:
                                    const Text('REDEEM'),
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
        userData['phone'] ??
        userData['phoneNumber'] ??
        '';

    showDialog(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Confirm Redemption',
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Text(
                'Redeem "$title" for '
                '$costPoints points?',
              ),

              const SizedBox(height: 12),

              if (phoneNumber.toString().isNotEmpty)
                Text(
                  'Reward will be processed for:\n'
                  '$phoneNumber',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                const Text(
                  'No phone number is saved '
                  'on your account.',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child: const Text('CANCEL'),
            ),

            ElevatedButton(
              onPressed:
                  phoneNumber.toString().isEmpty
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
        // Get current user data
        final snapshot =
            await transaction.get(userRef);

        if (!snapshot.exists) {
          throw Exception(
            'User account not found.',
          );
        }

        final userData = snapshot.data()!;

        final currentPoints =
            (userData['points'] ?? 0) as num;

        // Check points
        if (currentPoints < costPoints) {
          throw Exception(
            'Not enough points.',
          );
        }

        // Create redemption document
        final redemptionRef = userRef
            .collection('redemptions')
            .doc();

        // Deduct points
        transaction.update(
          userRef,
          {
            'points':
                currentPoints - costPoints,
          },
        );

        // Save redemption
        transaction.set(
          redemptionRef,
          {
            'rewardId': rewardId,
            'title': title,
            'costPoints': costPoints,
            'phoneNumber': phoneNumber,

            // This means the redemption
            // still needs to be processed.
            'status': 'pending',

            'timestamp':
                FieldValue.serverTimestamp(),
          },
        );
      });

      if (!context.mounted) return;

      // Success message
      showDialog(
        context: context,

        builder: (context) {
          return AlertDialog(
            title: const Text(
              'Redemption Submitted 🎉',
            ),

            content: Text(
              '"$title" has been submitted '
              'successfully.\n\n'
              'Your reward is currently '
              'being processed.',
            ),

            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },

                child: const Text('DONE'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Redemption failed: $e',
          ),
        ),
      );
    }
  }
}