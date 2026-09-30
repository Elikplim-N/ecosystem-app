import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'ui_helpers.dart';

class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final rfidController = TextEditingController();

  bool isLoading = false;

  Future<void> _register() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim();
    final rfid = rfidController.text.trim();

    if (name.isEmpty || phone.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name, phone, and email are required')),
      );
      return;
    }

    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = await ApiService().adminRegisterUser(
        name: name,
        phone: phone,
        email: email,
        rfidUid: rfid.isNotEmpty ? rfid : null,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('User Registered ✅'),
            content: Text(
              '${user.name} has been registered successfully.\n\n'
              'Phone: ${user.phone}\n'
              'Email: ${user.email}\n'
              'RFID Card: ${user.rfidUid ?? "None"}',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('DONE'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    rfidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(title: const Text('Register New User')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'In-Person User Registration 👤',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'Register a new recycler on the spot and link their physical RFID card.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 28),
            TextField(controller: nameController, decoration: kFieldDecoration('Full Name', Icons.person)),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: kFieldDecoration('Phone Number', Icons.phone),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: kFieldDecoration('Email Address', Icons.email_outlined),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: rfidController,
              decoration: kFieldDecoration('RFID Card UID (Optional)', Icons.nfc),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isLoading ? null : _register,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('REGISTER & ISSUE CARD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}