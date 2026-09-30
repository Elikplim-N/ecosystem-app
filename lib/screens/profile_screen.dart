import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import 'badge_helper.dart';
import 'ui_helpers.dart';

const _avatarOptions = ['🙂', '😎', '🌱', '♻️', '🐢', '🌍', '🦊', '🐼', '🌻', '🚀'];

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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

        final nickname = user.nickname;
        final avatarIcon = user.avatarIcon;
        final phone = user.phone.isNotEmpty ? user.phone : 'Not set';
        final rfidUid = user.rfidUid;
        final points = user.points;
        final bottles = user.bottles;
        final weight = user.weight;
        final badge = getBadgeForPoints(points);

        return Scaffold(
          backgroundColor: kBackground,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
            title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                kGradientHeader(
                  context: context,
                  topPadding: 60,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _showAvatarPicker(context, avatarIcon),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 45,
                              backgroundColor: Colors.white,
                              child: Text(avatarIcon, style: const TextStyle(fontSize: 40)),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: kPrimaryDark, shape: BoxShape.circle),
                                child: const Icon(Icons.edit, size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _showNicknameDialog(context, nickname),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(nickname, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(width: 6),
                            const Icon(Icons.edit, size: 16, color: Colors.white70),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(phone, style: const TextStyle(fontSize: 14, color: Colors.white70)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badge.icon, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(badge.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      Row(
                        children: [
                          Expanded(child: _statTile('$points', 'Points')),
                          const SizedBox(width: 12),
                          Expanded(child: _statTile('$bottles', 'Bottles')),
                          const SizedBox(width: 12),
                          Expanded(child: _statTile('$weight kg', 'Weight')),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Text('Account & Hardware Links', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: kCardDecoration(),
                        child: Column(
                          children: [
                            _infoRow(Icons.phone, 'Mobile Number', phone),
                            _infoRow(
                              Icons.credit_card,
                              'RFID Card UID',
                              rfidUid != null && rfidUid.isNotEmpty ? rfidUid : 'Not linked',
                              trailing: TextButton(
                                onPressed: () => _showLinkRfidDialog(context, rfidUid),
                                child: Text(rfidUid != null && rfidUid.isNotEmpty ? 'CHANGE' : 'PAIR CARD'),
                              ),
                            ),
                            _infoRow(Icons.email_outlined, 'Email', user.email.isNotEmpty ? user.email : 'Not set'),
                            _infoRow(
                              Icons.dns_outlined,
                              'Server Backend',
                              api.baseUrl.contains('localhost') ? 'Local / Offline Demo' : api.baseUrl,
                              trailing: IconButton(
                                icon: const Icon(Icons.settings, size: 18, color: kPrimaryColor),
                                onPressed: () => _showVpsConfigDialog(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () => _showLinkRfidDialog(context, rfidUid),
                          icon: const Icon(Icons.nfc),
                          label: Text(rfidUid != null ? 'UPDATE RFID CARD' : 'LINK RFID REWARD CARD'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF00C896), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () => _showChangePhoneDialog(context, phone),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('CHANGE PHONE NUMBER'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await api.logout();
                            if (context.mounted) {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                          },
                          icon: const Icon(Icons.logout, color: Colors.redAccent),
                          label: const Text('LOG OUT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                        ),
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

  static Widget _statTile(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: kCardDecoration(radius: 16),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimaryDark)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  static Widget _infoRow(IconData icon, String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 22, color: kPrimaryColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextDark)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  static void _showLinkRfidDialog(BuildContext context, String? currentUid) {
    final controller = TextEditingController(text: currentUid ?? '');
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.nfc, color: kPrimaryColor),
              SizedBox(width: 8),
              Text('Link RFID Card'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter the RFID UID of your recycling card/fob (e.g. A3 F1 82 4B):'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'e.g. A3 F1 82 4B',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_card),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isNotEmpty) {
                  await ApiService().linkRfidCard(controller.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('RFID Card Linked Successfully!')));
                  }
                }
              },
              child: const Text('Save Card'),
            ),
          ],
        );
      },
    );
  }

  static void _showVpsConfigDialog(BuildContext context) {
    final api = ApiService();
    final controller = TextEditingController(text: api.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('VPS Backend URL'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Set your custom VPS API URL (or keep default for offline demo):'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'http://your-vps-ip:3000/api',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await api.setBaseUrl(controller.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server URL updated!')));
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  static void _showAvatarPicker(BuildContext context, String current) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Choose an Avatar'),
          content: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _avatarOptions.map((emoji) {
              return GestureDetector(
                onTap: () async {
                  await ApiService().updateProfile(avatarIcon: emoji);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: emoji == current ? kPrimaryColor.withOpacity(0.3) : Colors.grey.withOpacity(0.15),
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  static void _showNicknameDialog(BuildContext context, String current) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Change Nickname'),
          content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Nickname')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isNotEmpty) {
                  await ApiService().updateProfile(nickname: controller.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  static void _showChangePhoneDialog(BuildContext context, String current) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Change Phone Number'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Mobile Number'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isNotEmpty) {
                  await ApiService().updateProfile(phone: controller.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}