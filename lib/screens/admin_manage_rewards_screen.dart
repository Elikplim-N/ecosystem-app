import 'package:flutter/material.dart';

import '../data/rewards_repository.dart';
import '../services/api_client.dart';
import 'design_system.dart' show confirmDialog;
import 'ui_helpers.dart';

class AdminManageRewardsScreen extends StatefulWidget {
  const AdminManageRewardsScreen({super.key});

  @override
  State<AdminManageRewardsScreen> createState() =>
      _AdminManageRewardsScreenState();
}

class _AdminManageRewardsScreenState extends State<AdminManageRewardsScreen> {
  final RewardsRepository _rewards = RewardsRepository();

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Turns an API failure into something a staff member can act on.
  String _describe(ApiException e) {
    if (e.isUserFacing) return e.message;
    if (e.code == 'conflict') return e.message;
    if (e.code == 'forbidden') return 'Only admins can change rewards.';
    return 'That change could not be saved.';
  }

  Future<void> _toggleActive(Reward reward, bool active) async {
    try {
      await _rewards.editReward(reward.id, active: active);
    } on ApiException catch (e) {
      _toast(_describe(e));
    }
  }

  Future<void> _delete(Reward reward) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete "${reward.title}"?',
      message: reward.costPoints > 0
          ? 'Members who already redeemed this keep their redemption history. '
                'Deactivate it instead if you only want to hide it.'
          : 'This cannot be undone.',
      confirmLabel: 'DELETE',
    );
    if (!ok) return;

    try {
      await _rewards.deleteReward(reward.id);
      _toast('Reward deleted');
    } on ApiException catch (e) {
      // The API refuses to delete anything with redemptions against it, and
      // says so; that is the hint to deactivate rather than delete.
      _toast(_describe(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAdminBackground,
      appBar: AppBar(
        title: const Text('Manage Rewards'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddRewardDialog(context),
          ),
        ],
      ),
      // The admin endpoint, not the member one: this includes deactivated
      // rewards so they can be switched back on.
      body: StreamBuilder<List<Reward>>(
        stream: _rewards.watchAllRewards(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load rewards:\n${snapshot.error}'),
            );
          }

          final rewards = snapshot.data ?? const <Reward>[];

          if (rewards.isEmpty) {
            return const Center(
              child: Text('No rewards yet. Tap + to add one.'),
            );
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
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              // Deactivated rewards stay listed but visibly
                              // dimmed, so staff can tell "hidden" from "gone".
                              color: reward.active ? null : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${reward.costPoints} points • ${reward.category}'
                            '${reward.stock == null ? '' : ' • ${reward.stock} left'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: reward.active,
                      activeThumbColor: kPrimaryColor,
                      onChanged: (value) => _toggleActive(reward, value),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _delete(reward),
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
    final stockController = TextEditingController();
    String category = 'standard';
    bool saving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Reward'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: costController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cost (points)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock (blank = unlimited)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      items: const [
                        DropdownMenuItem(
                          value: 'standard',
                          child: Text('Standard'),
                        ),
                        DropdownMenuItem(
                          value: 'partner',
                          child: Text('Partner'),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => category = value ?? 'standard'),
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    if (category == 'partner') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: partnerController,
                        decoration: const InputDecoration(
                          labelText: 'Partner Name',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final cost =
                              int.tryParse(costController.text.trim()) ?? 0;
                          final stock = int.tryParse(
                            stockController.text.trim(),
                          );

                          if (title.isEmpty || cost <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Title and a valid point cost are required',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => saving = true);

                          try {
                            await _rewards.addReward(
                              title: title,
                              costPoints: cost,
                              description: descController.text.trim(),
                              category: category,
                              partnerName: category == 'partner'
                                  ? partnerController.text.trim()
                                  : null,
                              stock: stock,
                            );
                            if (context.mounted) Navigator.pop(context);
                            _toast('Reward added');
                          } on ApiException catch (e) {
                            setDialogState(() => saving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(_describe(e))),
                              );
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ADD'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
