import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/reward_model.dart';
import 'ui_helpers.dart';

class AdminManageRewardsScreen extends StatefulWidget {
  const AdminManageRewardsScreen({super.key});

  @override
  State<AdminManageRewardsScreen> createState() => _AdminManageRewardsScreenState();
}

class _AdminManageRewardsScreenState extends State<AdminManageRewardsScreen> {
  late Future<List<RewardModel>> _rewardsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _rewardsFuture = ApiService().getRewards();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Manage Rewards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddRewardDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<RewardModel>>(
        future: _rewardsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final rewards = snapshot.data ?? [];

          if (rewards.isEmpty) {
            return const Center(child: Text('No rewards yet. Tap + to add one.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rewards.length,
            itemBuilder: (context, index) {
              final reward = rewards[index];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: kCardDecoration(),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reward.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${reward.pointsCost} points • ${reward.category}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: reward.isActive,
                      activeColor: kPrimaryColor,
                      onChanged: (value) async {
                        await ApiService().adminToggleReward(reward.id, value);
                        _refresh();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        await ApiService().adminDeleteReward(reward.id);
                        _refresh();
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddRewardDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final costController = TextEditingController();
    final partnerController = TextEditingController();
    String category = 'airtime';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Reward'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                    TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
                    TextField(
                      controller: costController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Points Cost'),
                    ),
                    TextField(controller: partnerController, decoration: const InputDecoration(labelText: 'Partner Name (Optional)')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const [
                        DropdownMenuItem(value: 'airtime', child: Text('Airtime Recharge')),
                        DropdownMenuItem(value: 'momo', child: Text('Mobile Money')),
                        DropdownMenuItem(value: 'merchandise', child: Text('BoaMe Merchandise')),
                        DropdownMenuItem(value: 'discount', child: Text('Partner Discount')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => category = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final desc = descController.text.trim();
                    final cost = int.tryParse(costController.text.trim()) ?? 0;
                    final partner = partnerController.text.trim();

                    if (title.isNotEmpty && cost > 0) {
                      await ApiService().adminAddReward(
                        title: title,
                        description: desc,
                        pointsCost: cost,
                        category: category,
                        partnerName: partner.isNotEmpty ? partner : null,
                      );
                      if (mounted) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        _refresh();
                      }
                    }
                  },
                  child: const Text('ADD'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}