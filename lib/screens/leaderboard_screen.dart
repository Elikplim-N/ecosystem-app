import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import 'badge_helper.dart';
import 'ui_helpers.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<UserModel>> _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _leaderboardFuture = ApiService().getLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ApiService().currentUser?.id;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<UserModel>>(
        future: _leaderboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return const Center(child: Text('No rankings yet.'));
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final nickname = user.nickname.isNotEmpty ? user.nickname : user.name;
                final points = user.points;
                final avatarIcon = user.avatarIcon;
                final badge = getBadgeForPoints(points);
                final isMe = user.id == currentUserId;
                final rank = index + 1;

                Color rankColor = Colors.grey[700]!;
                if (rank == 1) rankColor = const Color(0xFFFFB800);
                if (rank == 2) rankColor = const Color(0xFFC0C0C0);
                if (rank == 3) rankColor = const Color(0xFFCD7F32);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isMe ? kPrimaryColor.withOpacity(0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: isMe ? Border.all(color: kPrimaryColor, width: 1.5) : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          '#$rank',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: rankColor,
                          ),
                        ),
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
                            Text(
                              nickname,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(badge.icon, size: 14, color: badge.color),
                                const SizedBox(width: 4),
                                Text(
                                  badge.label,
                                  style: TextStyle(fontSize: 12, color: badge.color),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$points pts',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: kPrimaryDark,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}