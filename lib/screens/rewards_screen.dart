import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/reward_model.dart';
import '../models/user_model.dart';
import 'ui_helpers.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  late Future<List<RewardModel>> _rewardsFuture;
  bool _isRedeeming = false;

  @override
  void initState() {
    super.initState();
    _loadRewards();
  }

  void _loadRewards() {
    setState(() {
      _rewardsFuture = ApiService().getRewards();
    });
  }

  void _confirmRedeem(RewardModel reward, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Redemption'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Redeem "${reward.title}" for ${reward.pointsCost} points?'),
            const SizedBox(height: 12),
            Text(
              'Reward will be sent to:\n${user.phone.isNotEmpty ? user.phone : user.email}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isRedeeming = true);
              try {
                final success = await ApiService().redeemReward(reward.id);
                if (!mounted) return;
                if (success) {
                  showDialog(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Success! 🎉'),
                      content: Text(
                        'Your redemption of "${reward.title}" has been placed. You will receive an SMS confirmation shortly.',
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: const Text('GREAT'),
                        ),
                      ],
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to redeem reward')),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              } finally {
                if (mounted) setState(() => _isRedeeming = false);
              }
            },
            child: const Text('REDEEM NOW'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: ApiService().userStream,
      initialData: ApiService().currentUser,
      builder: (context, userSnapshot) {
        final user = userSnapshot.data ?? ApiService().currentUser;
        final points = user?.points ?? 0;

        return Scaffold(
          backgroundColor: kBackground,
          appBar: AppBar(
            title: const Text('Rewards Catalog'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadRewards,
              ),
            ],
          ),
          body: _isRedeeming
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Available Points Banner
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(18),
                      padding: const EdgeInsets.all(22),
                      decoration: kCardDecoration(color: kPrimaryColor),
                      child: Column(
                        children: [
                          const Text(
                            'AVAILABLE REWARD POINTS',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$points',
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Recycle bottles at any BoaMe RVM to earn more!',
                            style: TextStyle(fontSize: 13, color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // Rewards List
                    Expanded(
                      child: FutureBuilder<List<RewardModel>>(
                        future: _rewardsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error loading rewards: ${snapshot.error}'),
                            );
                          }

                          final rewards = snapshot.data ?? [];

                          if (rewards.isEmpty) {
                            return const Center(
                              child: Text('No rewards available right now.'),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            itemCount: rewards.length,
                            itemBuilder: (context, index) {
                              final reward = rewards[index];
                              final canAfford = points >= reward.pointsCost;

                              IconData iconData = Icons.card_giftcard;
                              if (reward.category == 'airtime') iconData = Icons.phone_android;
                              if (reward.category == 'momo') iconData = Icons.account_balance_wallet;
                              if (reward.category == 'merchandise') iconData = Icons.shopping_bag;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(16),
                                decoration: kCardDecoration(),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: kPrimaryColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(iconData, size: 30, color: kPrimaryDark),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            reward.title,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: kTextDark,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            reward.description,
                                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: kPrimaryColor.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '${reward.pointsCost} pts',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: kPrimaryDark,
                                                  ),
                                                ),
                                              ),
                                              if (reward.partnerName != null) ...[
                                                const SizedBox(width: 6),
                                                Text(
                                                  reward.partnerName!,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[500],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: (canAfford && user != null)
                                          ? () => _confirmRedeem(reward, user)
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        backgroundColor: canAfford ? kPrimaryColor : Colors.grey[300],
                                      ),
                                      child: Text(
                                        canAfford ? 'REDEEM' : 'LOCKED',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: canAfford ? Colors.white : Colors.grey[600],
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
                ),
        );
      },
    );
  }
}