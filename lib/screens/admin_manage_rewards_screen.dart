import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ui_helpers.dart';

class AdminManageRewardsScreen extends StatefulWidget {
  const AdminManageRewardsScreen({super.key});

  @override
  State<AdminManageRewardsScreen> createState() => _AdminManageRewardsScreenState();
}

class _AdminManageRewardsScreenState extends State<AdminManageRewardsScreen> {
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('rewards').orderBy('costPoints').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rewards = snapshot.data?.docs ?? [];

          if (rewards.isEmpty) {
            return const Center(child: Text('No rewards yet. Tap + to add one.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rewards.length,
            itemBuilder: (context, index) {
              final doc = rewards[index];
              final data = doc.data() as Map<String, dynamic>;
              final active = data['active'] ?? true;

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
                          Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('${data['costPoints'] ?? 0} points • ${data['type'] ?? 'standard'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Switch(
                      value: active,
                      activeThumbColor: kPrimaryColor,
                      onChanged: (value) {
                        FirebaseFirestore.instance.collection('rewards').doc(doc.id).update({'active': value});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        FirebaseFirestore.instance.collection('rewards').doc(doc.id).delete();
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
    String type = 'standard';

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
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                    const SizedBox(height: 10),
                    TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
                    const SizedBox(height: 10),
                    TextField(
                      controller: costController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cost (points)'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      items: const [
                        DropdownMenuItem(value: 'standard', child: Text('Standard')),
                        DropdownMenuItem(value: 'partner', child: Text('Partner')),
                      ],
                      onChanged: (value) => setDialogState(() => type = value ?? 'standard'),
                      decoration: const InputDecoration(labelText: 'Type'),
                    ),
                    if (type == 'partner') ...[
                      const SizedBox(height: 10),
                      TextField(controller: partnerController, decoration: const InputDecoration(labelText: 'Partner Name')),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final cost = int.tryParse(costController.text.trim()) ?? 0;

                    if (title.isEmpty || cost <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Title and a valid point cost are required')),
                      );
                      return;
                    }

                    await FirebaseFirestore.instance.collection('rewards').add({
                      'title': title,
                      'description': descController.text.trim(),
                      'costPoints': cost,
                      'type': type,
                      if (type == 'partner') 'partnerName': partnerController.text.trim(),
                      'active': true,
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    if (context.mounted) Navigator.pop(context);
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