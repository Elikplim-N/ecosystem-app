import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'badge_helper.dart';
import 'ui_helpers.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(title: const Text('Leaderboard')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('points', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allDocs = snapshot.data?.docs ?? [];

          // Filter out admin accounts client-side — avoids needing a composite index.
          final users = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['role'] ?? 'user') != 'admin';
          }).take(50).toList();

          if (users.isEmpty) {
            return const Center(child: Text('No rankings yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final doc = users[index];
              final data = doc.data() as Map<String, dynamic>;

              final nickname = data['nickname'] ?? data['name'] ?? 'User';
              final points = (data['points'] ?? 0) as num;
              final avatarIcon = data['avatarIcon'] ?? '🙂';
              final badge = getBadgeForPoints(points);
              final isMe = doc.id == currentUid;
              final rank = index + 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isMe ? kPrimaryColor.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: isMe ? Border.all(color: kPrimaryColor, width: 1.5) : null,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text('#$rank', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: kPrimaryColor.withOpacity(0.15),
                      child: Text(avatarIcon, style: const TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nickname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Row(
                            children: [
                              Icon(badge.icon, size: 14, color: badge.color),
                              const SizedBox(width: 4),
                              Text(badge.label, style: TextStyle(fontSize: 12, color: badge.color)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text('$points pts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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