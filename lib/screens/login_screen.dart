import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'auth_gate.dart';
import 'kiosk_screen.dart';
import 'ui_helpers.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final identifierController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  Future<void> loginUser() async {
    final identifier = identifierController.text.trim();
    final password = passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number or email and password')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await ApiService().login(identifier: identifier, password: password);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthGate()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset('assets/images/logo_boame.png', fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Welcome Back 👋', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kTextDark)),
              const SizedBox(height: 6),
              const Text('Log in to view your recycling rewards and balance', style: TextStyle(fontSize: 15, color: Colors.grey)),
              const SizedBox(height: 32),

              TextFormField(
                controller: identifierController,
                keyboardType: TextInputType.text,
                decoration: kInputDecoration(
                  label: 'Phone Number or Email',
                  hint: '024 123 4567 or user@mail.com',
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: kInputDecoration(
                  label: 'Password',
                  icon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen())),
                  child: const Text('Forgot Password?', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : loginUser,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('LOG IN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                  child: const Text("Don't have an account? Sign Up", style: TextStyle(color: kPrimaryDark, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),

              // Quick Launch Kiosk Mode
              const Divider(color: Colors.black12),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const KioskScreen())),
                icon: const Icon(Icons.point_of_sale),
                label: const Text('LAUNCH REVERSE VENDING MACHINE (KIOSK MODE)'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: Color(0xFF00C896), width: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}