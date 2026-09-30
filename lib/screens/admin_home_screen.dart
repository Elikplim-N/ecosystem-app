import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'admin_register_screen.dart';
import 'admin_manage_rewards_screen.dart';
import 'auth_gate.dart';
import 'ui_helpers.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await ApiService().logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthGate()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          kGradientHeader(
            context: context,
            child: const Text('Welcome, Admin 👋', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _adminTile(
                    icon: Icons.person_add,
                    title: 'Register New User',
                    subtitle: 'In-person registration and card issuing',
                    color: kPrimaryColor,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminRegisterScreen())),
                  ),
                  const SizedBox(height: 14),
                  _adminTile(
                    icon: Icons.card_giftcard,
                    title: 'Manage Rewards',
                    subtitle: 'Add, activate, or remove reward catalog items',
                    color: const Color(0xFFFFB020),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminManageRewardsScreen())),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _adminTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: kCardDecoration(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextDark)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}