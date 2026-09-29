import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'badge_helper.dart';
import 'ui_helpers.dart';

const _avatarOptions = ['🙂', '😎', '🌱', '♻️', '🐢', '🌍', '🦊', '🐼', '🌻', '🚀'];

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('No user is logged in')));
    }

    return Scaffold(
      backgroundColor: kBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Colors.white),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('User data not found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = data['name'] ?? 'User';
          final nickname = data['nickname'] ?? name;
          final avatarIcon = data['avatarIcon'] ?? '🙂';
          final phone = data['phone'] ?? 'Not set';
          final rfidUid = data['rfidUid'];
          final points = (data['points'] ?? 0) as num;
          final bottles = data['bottles'] ?? 0;
          final weight = data['weight'] ?? 0.0;
          final badge = getBadgeForPoints(points);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                kGradientHeader(
                  context: context,
                  topPadding: 60,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _showAvatarPicker(context, user.uid, avatarIcon),
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
                        onTap: () => _showNicknameDialog(context, user.uid, nickname),
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
                      const SizedBox(height: 30),
                      const Text('Account Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: kCardDecoration(),
                        child: Column(
                          children: [
                            _infoRow(Icons.phone, 'Phone', phone),
                            _infoRow(Icons.credit_card, 'RFID Card', rfidUid != null ? 'Linked' : 'Not linked'),
                            _infoRow(Icons.email_outlined, 'Email', user.email ?? 'Not set'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () => _showChangePhoneDialog(context, user.uid, phone),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('CHANGE PHONE NUMBER'),
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('LOG OUT', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static void _showAvatarPicker(BuildContext context, String uid, String current) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose an Avatar'),
          content: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _avatarOptions.map((emoji) {
              return GestureDetector(
                onTap: () async {
                  await FirebaseFirestore.instance.collection('users').doc(uid).update({'avatarIcon': emoji});
                  if (context.mounted) Navigator.pop(context);
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

  static void _showNicknameDialog(BuildContext context, String uid, String current) {
    final controller = TextEditingController(text: current);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Nickname'),
          content: TextField(controller: controller, decoration: const InputDecoration(border: OutlineInputBorder())),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () async {
                final newNickname = controller.text.trim();
                if (newNickname.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('users').doc(uid).update({'nickname': newNickname});
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }

  static void _showChangePhoneDialog(BuildContext context, String uid, String currentPhone) {
    final newPhoneController = TextEditingController();
    final currentPasswordController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change Phone Number'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Current: $currentPhone', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'New Phone Number', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Current Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newPhone = newPhoneController.text.trim();
                          final password = currentPasswordController.text;

                          if (newPhone.isEmpty || password.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill in both fields')),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);

                          try {
                            final user = FirebaseAuth.instance.currentUser!;

                            final credential = EmailAuthProvider.credential(
                              email: user.email!,
                              password: password,
                            );
                            await user.reauthenticateWithCredential(credential);

                            await FirebaseFirestore.instance.collection('users').doc(uid).update({
                              'phone': newPhone,
                            });

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Phone number updated successfully.')),
                              );
                            }
                          } on FirebaseAuthException catch (e) {
                            setDialogState(() => isSaving = false);
                            String message = 'Failed to update phone number';
                            if (e.code == 'wrong-password') {
                              message = 'Incorrect password';
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          }
                        },
                  child: isSaving ? const CircularProgressIndicator() : const Text('SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Widget _statTile(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: kCardDecoration(radius: 14),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  static Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: kPrimaryDark),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}