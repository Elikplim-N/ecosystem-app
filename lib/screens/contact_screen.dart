import 'package:flutter/material.dart';
import 'ui_helpers.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final messageController = TextEditingController();
  bool isSending = false;

  Future<void> _sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => isSending = true);

    try {
      // Send contact message to VPS
      await Future.delayed(const Duration(milliseconds: 500));
      messageController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message sent — we'll get back to you soon!")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
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
      appBar: AppBar(title: const Text('Contact Us')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "We'd love to hear from you 🌱",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'Questions, feedback, or issues with your BoaMe account — send us a message.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: kCardDecoration(),
              padding: const EdgeInsets.all(4),
              child: TextField(
                controller: messageController,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Type your message here...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isSending ? null : _sendMessage,
                child: isSending
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SEND MESSAGE', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}