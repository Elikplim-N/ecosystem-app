import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'history_screen.dart';
import 'rewards_screen.dart';
import 'profile_screen.dart';
import 'leaderboard_screen.dart';
import 'contact_screen.dart';
import 'notifications_screen.dart';
import 'ui_helpers.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('No user is logged in')));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text('User data not found')));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final name = data['nickname'] ?? data['name'] ?? 'User';
        final points = data['points'] ?? 0;
        final bottles = data['bottles'] ?? 0;
        final weight = data['weight'] ?? 0.0;

        return Scaffold(
          backgroundColor: kBackground,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('ECOSYSTEM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                kGradientHeader(
                  context: context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hello, $name 👋', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      const Text('Ready to make a difference today?', style: TextStyle(fontSize: 15, color: Colors.white70)),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: kCardDecoration(radius: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('YOUR POINTS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kPrimaryDark, letterSpacing: 1)),
                            const SizedBox(height: 6),
                            Text('$points', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: kTextDark)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(child: _miniStat(Icons.recycling, '$bottles', 'Bottles')),
                                Expanded(child: _miniStat(Icons.scale_outlined, '$weight kg', 'Weight')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextDark)),
                      const SizedBox(height: 14),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.95,
                        children: [
                          _actionCard(
                            icon: Icons.history,
                            title: 'History',
                            color: kPrimaryColor,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen())),
                          ),
                          _actionCard(
                            icon: Icons.card_giftcard,
                            title: 'Rewards',
                            color: const Color(0xFFFFB020),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RewardsScreen())),
                          ),
                          _actionCard(
                            icon: Icons.leaderboard,
                            title: 'Leaderboard',
                            color: const Color(0xFFE86A6A),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardScreen())),
                          ),
                          _actionCard(
                            icon: Icons.person_outline,
                            title: 'Profile',
                            color: const Color(0xFF5B8DEF),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                          ),
                          _actionCard(
                            icon: Icons.support_agent,
                            title: 'Contact Us',
                            color: const Color(0xFF9B7EDE),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ContactScreen())),
                          ),
                          _actionCard(
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            color: const Color(0xFF00A6A6),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      const Text('Recent Activity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextDark)),
                      const SizedBox(height: 14),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('deposits')
                            .orderBy('timestamp', descending: true)
                            .limit(5)
                            .snapshots(),
                        builder: (context, depositSnapshot) {
                          if (depositSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (depositSnapshot.hasError) {
                            return const Text('Unable to load recent activity.');
                          }

                          final deposits = depositSnapshot.data?.docs ?? [];

                          if (deposits.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(25),
                              decoration: kCardDecoration(),
                              child: const Column(
                                children: [
                                  Icon(Icons.recycling, size: 50, color: kPrimaryColor),
                                  SizedBox(height: 10),
                                  Text('No recycling activity yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  SizedBox(height: 5),
                                  Text('Drop a bottle at any kiosk — your points will update here automatically.', textAlign: TextAlign.center),
                                ],
                              ),
                            );
                          }

                          return Column(
                            children: deposits.map((deposit) {
                              final depositData = deposit.data() as Map<String, dynamic>;
                              final depositPoints = depositData['points'] ?? 0;
                              final depositWeight = depositData['weight'] ?? 0.0;

                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: kCardDecoration(radius: 16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.recycling, color: kPrimaryDark),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Bottle Deposited', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 3),
                                          Text('$depositWeight kg', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                        ],
                                      ),
                                    ),
                                    Text('+$depositPoints pts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimaryDark)),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: kPrimaryDark,
            unselectedItemColor: Colors.grey,
            onTap: (index) {
              switch (index) {
                case 1:
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const RewardsScreen()));
                  break;
                case 2:
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                  break;
              }
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Rewards'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
            ],
          ),
        );
      },
    );
  }

  static Widget _miniStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 18, color: kPrimaryDark),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  static Widget _actionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: kCardDecoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}