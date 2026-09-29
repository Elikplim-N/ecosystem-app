import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Creates the user on a SEPARATE Firebase app instance so the admin's
  // own login session on the main app is never touched.
  Future<void> _register() async {
    if (nameController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name, phone, and email are required')),
      );
      return;
    }

    if (!emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    setState(() => isLoading = true);

    FirebaseApp? secondaryApp;

    try {
      final phone = phoneController.text.trim();
      final email = emailController.text.trim();

      secondaryApp = await Firebase.initializeApp(
        name: 'AdminRegistrationApp',
        options: Firebase.app().options,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: phone, // default password = phone number
      );

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'name': nameController.text.trim(),
        'phone': phone,
        'email': email,
        'nickname': nameController.text.trim(),
        'avatarIcon': '🙂',
        'role': 'user',
        'points': 0,
        'bottles': 0,
        'weight': 0.0,
        if (rfidController.text.trim().isNotEmpty) 'rfidUid': rfidController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await secondaryAuth.signOut();
      await secondaryApp.delete();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('User Registered ✅'),
            content: Text(
              '${nameController.text.trim()} has been registered.\n\n'
              'Login phone: $phone\n'
              'Login email: $email\n'
              'Default password: $phone',
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

      nameController.clear();
      phoneController.clear();
      emailController.clear();
      rfidController.clear();
    } on FirebaseAuthException catch (e) {
      if (secondaryApp != null) await secondaryApp.delete();
      if (!mounted) return;
      String message = 'Registration failed';
      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered';
      } else if (e.code == 'weak-password') {
        message = 'The password is too weak (phone number used as password)';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      } else {
        message = 'Firebase error: ${e.code}';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (secondaryApp != null) await secondaryApp.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
              'In-person registration',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Default password is the phone number. An email is required for password recovery.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
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
              decoration: kFieldDecoration('RFID Card UID (optional)', Icons.credit_card),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isLoading ? null : _register,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('REGISTER USER', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}