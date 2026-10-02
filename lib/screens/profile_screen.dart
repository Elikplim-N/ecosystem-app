import 'package:flutter/material.dart';
import 'badge_helper.dart';
import 'admin_home_screen.dart';
import 'design_system.dart';
import '../data/user_repository.dart';
import '../models/app_role.dart';
import '../models/member.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

const _avatarOptions = [
  '🙂',
  '😎',
  '🌱',
  '♻️',
  '🐢',
  '🌍',
  '🦊',
  '🐼',
  '🌻',
  '🚀',
];

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static final UserRepository _users = UserRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<MemberSession>(
        stream: auth.sessions,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final member = snapshot.data!.member;

          if (!snapshot.data!.signedIn || member == null) {
            return const SignedOutView();
          }

          final nickname = member.nickname;
          final avatarIcon = member.avatarIcon;
          final phone = member.phone.isEmpty ? 'Not set' : member.phone;
          final rfidUid = member.rfidUid;
          final points = member.points;
          final bottles = member.bottles;
          final weight = member.weight;
          final badge = tierForPoints(points);
          final goal = nextTierGoal(points);
          final role = member.role;

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
                        onTap: () => _showAvatarPicker(context, avatarIcon),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 45,
                              backgroundColor: Colors.white,
                              child: Text(
                                avatarIcon,
                                style: const TextStyle(fontSize: 40),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: kPrimaryDark,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: Colors.white,
                                ),
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
                            Text(
                              nickname,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phone,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (badge != null) ...[
                              Icon(badge.icon, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                badge.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ] else ...[
                              const Icon(
                                Icons.trending_up_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                goal == null
                                    ? 'Max tier'
                                    : '${goal.needed} pts to ${goal.tier}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
                          Expanded(
                            child: _statTile(
                              value: '$points',
                              label: 'Points',
                              icon: Icons.stars_rounded,
                              pastel: kPastelMint,
                              accent: kPrimaryColor,
                              asset: 'assets/profile/points.png',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statTile(
                              value: '$bottles',
                              label: 'Bottles',
                              icon: Icons.local_drink_rounded,
                              pastel: kPastelBlue,
                              accent: kPrimaryColor,
                              asset: 'assets/profile/bottles.png',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statTile(
                              value: '$weight kg',
                              label: 'Weight',
                              icon: Icons.scale_rounded,
                              pastel: kPastelPink,
                              accent: kPrimaryColor,
                              asset: 'assets/profile/weight.png',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Account Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: kTextDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: kCardDecoration(radius: 20),
                        child: Column(
                          children: [
                            _infoRow(
                              Icons.phone_rounded,
                              'Phone',
                              phone,
                              iconColor: kColouredBottle,
                              iconTint: kPastelBlue,
                            ),
                            _divider(),
                            _infoRow(
                              Icons.contactless_rounded,
                              'RFID Card',
                              rfidUid != null ? 'Linked' : 'Not linked',
                              iconColor: rfidUid != null
                                  ? kPrimaryColor
                                  : kTextMuted,
                              iconTint: kPastelMint,
                            ),
                            _divider(),
                            _infoRow(
                              Icons.email_rounded,
                              'Email',
                              member.email.isEmpty ? 'Not set' : member.email,
                              iconColor: kClearBottle,
                              iconTint: kPastelPink,
                            ),
                          ],
                        ),
                      ),
                      if (role == AppRole.admin) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: kMetricBlueTint,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: kMetricBlue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.shield_rounded,
                                  color: kMetricBlue,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Admin Console',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14.5,
                                        color: kTextDark,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Manage bins, users, and rewards',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: kTextMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminHomeScreen(),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kMetricBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'OPEN',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 54,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _showChangePhoneDialog(context, phone),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text(
                                  'CHANGE PHONE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: kPrimaryColor,
                                  side: const BorderSide(
                                    color: kPrimaryColor,
                                    width: 1.6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: SizedBox(
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await auth.signOut();
                                  if (context.mounted) {
                                    Navigator.of(
                                      context,
                                    ).popUntil((route) => route.isFirst);
                                  }
                                },
                                icon: const Icon(
                                  Icons.logout_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'LOG OUT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE5484D),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (role != AppRole.user) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(role.icon, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                role.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  /// Saves through the API and pushes the returned member into the session,
  /// so the header, dashboard and admin console all update together.
  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static Future<void> _saveAndRefresh(
    BuildContext context,
    Future<Member> Function() save,
  ) async {
    try {
      final member = await save();
      await auth.updateCachedMember(member);
    } on ApiException catch (e) {
      if (context.mounted) {
        _toast(
          context,
          e.isUserFacing ? e.message : 'Could not save that change.',
        );
      }
    }
  }

  static void _showAvatarPicker(BuildContext context, String current) {
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
                  await _saveAndRefresh(
                    context,
                    () => _users.updateOwnProfile({'avatarIcon': emoji}),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: emoji == current
                      ? kPrimaryColor.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.15),
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
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Nickname'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newNickname = controller.text.trim();
                if (newNickname.isNotEmpty) {
                  await _saveAndRefresh(
                    context,
                    () => _users.updateOwnProfile({'nickname': newNickname}),
                  );
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

  static void _showChangePhoneDialog(
    BuildContext context,
    String currentPhone,
  ) {
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
                  Text(
                    'Current: $currentPhone',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'New Phone Number',
                      hintText: 'e.g. 024 123 4567 or +233...',
                      border: OutlineInputBorder(),
                    ),
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
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newPhone = newPhoneController.text.trim();
                          final password = currentPasswordController.text;

                          if (newPhone.isEmpty || password.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill in both fields'),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);

                          try {
                            // The API checks the current password before
                            // moving the number, because it is also the login
                            // identifier.
                            final member = await _users.changeOwnPhone(
                              phone: newPhone,
                              currentPassword: password,
                            );
                            await auth.updateCachedMember(member);

                            if (context.mounted) {
                              Navigator.pop(context);
                              _toast(
                                context,
                                'Phone number updated successfully.',
                              );
                            }
                          } on ApiException catch (e) {
                            setDialogState(() => isSaving = false);
                            final message = e.code == 'invalid_credentials'
                                ? 'Incorrect password'
                                : (e.isUserFacing
                                      ? e.message
                                      : 'Failed to update phone number');
                            if (context.mounted) _toast(context, message);
                          }
                        },
                  child: isSaving
                      ? const CircularProgressIndicator()
                      : const Text('SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Widget _statTile({
    required String value,
    required String label,
    required IconData icon,
    required Color pastel,
    required Color accent,
    required String asset,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [pastel, Color.lerp(pastel, Colors.white, 0.6)!],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              height: 30,
              width: 30,
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? stack) =>
                        Icon(icon, size: 22, color: accent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: kTextDark,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: accent.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _divider() {
    return const Divider(height: 1, thickness: 1, color: kBeige);
  }

  static Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color iconColor = kPrimaryColor,
    Color iconTint = kPastelMint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconTint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 19, color: iconColor),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(fontSize: 14.5, color: kTextMuted),
          ),
          const Spacer(),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: kBackground,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kTextDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
