import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import '../models/deposit_model.dart';
import 'history_screen.dart';
import 'rewards_screen.dart';
import 'profile_screen.dart';
import 'leaderboard_screen.dart';
import 'contact_screen.dart';
import 'notifications_screen.dart';
import 'kiosk_screen.dart';
import 'ui_helpers.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiService();

    return StreamBuilder<UserModel?>(
      stream: api.userStream,
      initialData: api.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data ?? api.currentUser;

        if (user == null) {
          return const Scaffold(body: Center(child: Text('No user is logged in')));
        }

        final name = user.nickname.isNotEmpty ? user.nickname : user.name;
        final points = user.points;
        final bottles = user.bottles;
        final weight = user.weight;

        return Scaffold(
          backgroundColor: kBackground,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('BOAME ECOSYSTEM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            actions: [
              IconButton(
                icon: const Icon(Icons.point_of_sale, color: Colors.white),
                tooltip: 'Open Kiosk RVM',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const KioskScreen()));
                },
              ),
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
                      const Text('Ready to recycle and earn rewards today?', style: TextStyle(fontSize: 15, color: Colors.white70)),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: kCardDecoration(radius: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('YOUR RECYCLING POINTS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kPrimaryDark, letterSpacing: 1)),
                            const SizedBox(height: 6),
                            Text('$points', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: kTextDark)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(child: _miniStat(Icons.recycling, '$bottles', 'Bottles')),
                                Expanded(child: _miniStat(Icons.scale_outlined, '${weight.toStringAsFixed(2)} kg', 'Weight')),
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
                      // Kiosk Quick Launcher Banner
                      InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const KioskScreen())),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F241D), Color(0xFF1B382F)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF00C896), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C896).withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.touch_app, color: Color(0xFF00C896), size: 28),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Reverse Vending Machine Kiosk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                    SizedBox(height: 2),
                                    Text('Deposit bottles via RFID, Phone or Anonymous', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, color: Color(0xFF00C896), size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

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
                            title: 'Profile & RFID',
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

                      FutureBuilder<List<DepositModel>>(
                        future: api.getDeposits(),
                        builder: (context, depositSnapshot) {
                          if (depositSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final deposits = depositSnapshot.data ?? [];

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
                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: kCardDecoration(radius: 16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.12), shape: BoxShape.circle),
                                      child: const Icon(Icons.recycling, color: kPrimaryColor, size: 24),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(deposit.bottleType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextDark)),
                                          Text('${deposit.bottles} bottle(s) · ${deposit.weight.toStringAsFixed(2)} kg', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    Text('+${deposit.points} pts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPrimaryColor)),
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
        );
      },
    );
  }

  static Widget _miniStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 18, color: kPrimaryColor),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextDark)),
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
        decoration: kCardDecoration(radius: 18),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextDark)),
          ],
        ),
      ),
    );
  }
}