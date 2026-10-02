import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'ui_helpers.dart';

/// Asks for a password reset link and then takes the token.
///
/// Two steps in one screen because the token is a single-use value the person
/// has to act on quickly. The old version looked the phone number up in
/// Firestore and emailed a Firebase link, which told anyone using it whether an
/// account existed; this asks the API, which answers the same way either way.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final phoneController = TextEditingController();
  final tokenController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  final PasswordResetRepository _reset = PasswordResetRepository();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;

  /// True once a link has been sent; the form then switches to step two.
  bool sent = false;

  /// Set outside production, so the flow can be finished without a mail
  /// provider. Null in production, where the token only ever arrives by email.
  String? _debugToken;

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendLink() async {
    final phone = phoneController.text.trim();

    if (phone.isEmpty) {
      _toast('Please enter your phone number');
      return;
    }

    setState(() => isLoading = true);

    try {
      final debugToken = await _reset.requestReset(phone);
      if (!mounted) return;

      setState(() {
        _debugToken = debugToken;
        sent = true;
        tokenController.text = debugToken ?? '';
      });

      if (debugToken == null) {
        _toast('If that account exists, a reset link is on its way.');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(
        e.isUserFacing
            ? e.message
            : 'Could not send the reset link. Try again.',
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _completeReset() async {
    final token = tokenController.text.trim();
    final password = passwordController.text;

    if (token.isEmpty) {
      _toast('Paste the code from your reset email');
      return;
    }

    if (password.length < 8) {
      _toast('Password must be at least 8 characters');
      return;
    }

    if (password != confirmController.text) {
      _toast('Passwords do not match');
      return;
    }

    setState(() => isLoading = true);

    try {
      await _reset.reset(token: token, password: password);
      if (!mounted) return;

      // Every existing session was revoked server-side, so whatever this
      // device had cached is dead. Clear it before returning to the login
      // screen so it does not try to use a token that no longer works.
      await auth.signOut();

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Password updated'),
          content: const Text(
            'Your password has been changed and other devices have been '
            'signed out. Sign in again with the new one.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.isUserFacing ? e.message : 'Could not change the password.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    phoneController.dispose();
    tokenController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(sent ? 'Choose a new password' : 'Forgot Password'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: sent ? _buildStepTwo() : _buildStepOne(),
      ),
    );
  }

  Widget _buildStepOne() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reset your password',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: kTextDark,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Enter your registered phone number and we'll send you a reset link.",
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.emailAddress,
          decoration: kFieldDecoration(
            'Phone number or email',
            Icons.person_outline,
            hintText: '024 123 4567, +233..., or email',
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: isLoading ? null : _sendLink,
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'SEND RESET LINK',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }

  Widget _buildStepTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_debugToken != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kMetricBlueTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Development only: the API returned the token instead of '
              'emailing it, because no mail provider is configured yet.\n\n'
              '$_debugToken',
              style: const TextStyle(fontSize: 12.5, color: kMetricBlue),
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: tokenController,
          decoration: kFieldDecoration('Reset code', Icons.vpn_key_outlined),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          decoration: kFieldDecoration(
            'New password',
            Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => obscurePassword = !obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: confirmController,
          obscureText: obscureConfirm,
          decoration: kFieldDecoration(
            'Confirm new password',
            Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                obscureConfirm ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: isLoading ? null : _completeReset,
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'SAVE NEW PASSWORD',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => setState(() => sent = false),
            child: const Text('Use a different number'),
          ),
        ),
      ],
    );
  }
}
