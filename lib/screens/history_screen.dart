import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ui_helpers.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('No user is logged in')));
    }

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(title: const Text('Recycling History')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('deposits')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading history: ${snapshot.error}'));
          }

          final deposits = snapshot.data?.docs ?? [];

          if (deposits.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.recycling, size: 70, color: kPrimaryColor),
                    SizedBox(height: 15),
                    Text('No recycling history yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Your bottle deposits will appear here.', textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: deposits.length,
            itemBuilder: (context, index) {
              final deposit = deposits[index];
              final data = deposit.data() as Map<String, dynamic>;
              final points = data['points'] ?? 0;
              final weight = data['weight'] ?? 0.0;
              final timestamp = data['timestamp'] as Timestamp?;

              String dateText = 'Date unavailable';
              if (timestamp != null) {
                final date = timestamp.toDate();
                dateText = '${date.day}/${date.month}/${date.year} '
                    '${date.hour.toString().padLeft(2, '0')}:'
                    '${date.minute.toString().padLeft(2, '0')}';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(18),
                decoration: kCardDecoration(),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.recycling, size: 30, color: kPrimaryDark),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bottle Deposited', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('$weight kg', style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(dateText, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    Text('+$points pts', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kPrimaryDark)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}