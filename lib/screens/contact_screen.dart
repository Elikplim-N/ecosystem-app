import 'package:flutter/material.dart';
import '../data/activity_repository.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'ui_helpers.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final messageController = TextEditingController();
  final ContactRepository _contact = ContactRepository();
  bool isSending = false;

  Future<void> _sendMessage() async {
    final message = messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => isSending = true);

    // Prefilled from the session when there is one, so a signed-in person
    // does not have to retype their details. The server fills these in too
    // when they are left out, and works without a session at all.
    final member = auth.currentMember;

    try {
      await _contact.send(
        message,
        name: member?.name,
        email: member?.email,
        phone: member?.phone,
      );

      messageController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Message sent — we'll get back to you soon!"),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.isUserFacing ? e.message : 'Could not send that. Try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(title: const Text('Contact Us'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kPrimaryColor, kPrimaryDark],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: kPrimaryColor.withValues(alpha: 0.26),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/contact (2).png',
                      height: 132,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "We'd love to hear from you",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Questions, feedback, or issues with your account — send us a message and we will get back to you.',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: kCardDecoration(radius: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: messageController,
                    maxLines: 6,
                    minLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'Type your message here...',
                      hintStyle: TextStyle(color: kTextMuted),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: messageController,
                    builder:
                        (
                          BuildContext context,
                          TextEditingValue value,
                          Widget? child,
                        ) {
                          return Text(
                            '${value.text.trim().length} characters',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: kTextMuted,
                            ),
                          );
                        },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: messageController,
              builder:
                  (
                    BuildContext context,
                    TextEditingValue value,
                    Widget? child,
                  ) {
                    final bool canSend = value.text.trim().isNotEmpty;

                    return PrimaryButton(
                      label: 'Send Message',
                      icon: Icons.send_rounded,
                      isLoading: isSending,
                      onPressed: canSend ? _sendMessage : null,
                    );
                  },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kPastelMint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 20, color: kPrimaryColor),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'We usually reply within one working day.',
                      style: TextStyle(fontSize: 13, color: kTextDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
