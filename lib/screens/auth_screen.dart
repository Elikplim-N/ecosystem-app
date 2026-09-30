import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_gate.dart';
import 'forgot_password_screen.dart';
import 'ui_helpers.dart';

enum AuthMode { login, signUp }

/// Glossy-branded auth screen with a bottom sheet and a login / sign up pill.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initialMode = AuthMode.login});

  final AuthMode initialMode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  /// Onboarding clip art shown at the top of the screen.
  static const String clipArt = 'assets/onboarding1.png';

  /// Brand logo shown in the chip at the top left.
  static const String logo = 'assets/icon/logo_boame.png';

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  late AuthMode mode = widget.initialMode;

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _leaveLoading() {
    if (mounted) setState(() => isLoading = false);
  }

  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  Future<void> _login() async {
    final String phone = phoneController.text.trim();

    if (phone.isEmpty || passwordController.text.isEmpty) {
      _toast('Please enter your phone number and password');
      return;
    }

    setState(() => isLoading = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        if (!mounted) return;
        _toast('No account found with that phone number');
        setState(() => isLoading = false);
        return;
      }

      final userData = query.docs.first.data();
      // Fallback for accounts created before real emails were required.
      final email = userData['email'] ?? '$phone@ecosytem.app';

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: passwordController.text,
      );

      if (!mounted) return;
      _goHome();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-credential':
          _toast('Phone number or password is incorrect');
        case 'wrong-password':
          _toast('Incorrect password');
        default:
          _toast('Firebase error: ${e.code}');
      }
    } catch (e) {
      if (!mounted) return;
      _toast('Error: $e');
    } finally {
      _leaveLoading();
    }
  }

  Future<void> _signUp() async {
    if (nameController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      _toast('Please fill in all fields');
      return;
    }

    if (!emailController.text.contains('@')) {
      _toast('Please enter a valid email address');
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      _toast('Passwords do not match');
      return;
    }

    if (passwordController.text.length < 6) {
      _toast('Password must be at least 6 characters');
      return;
    }

    setState(() => isLoading = true);

    try {
      final String email = emailController.text.trim();

      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: passwordController.text,
      );

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': nameController.text.trim(),
          'phone': phoneController.text.trim(),
          'email': email,
          'nickname': nameController.text.trim(),
          'avatarIcon': '🙂',
          'role': 'user',
          'points': 0,
          'bottles': 0,
          'weight': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      _goHome();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'email-already-in-use':
          _toast('This email is already registered');
        case 'weak-password':
          _toast('The password is too weak');
        case 'invalid-email':
          _toast('Invalid email address');
        default:
          _toast('Firebase error: ${e.code}');
      }
    } catch (e) {
      if (!mounted) return;
      _toast('Error: $e');
    } finally {
      _leaveLoading();
    }
  }

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: kFieldDecoration('Phone Number', Icons.phone_outlined),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          decoration: kFieldDecoration(
            'Password',
            Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => obscurePassword = !obscurePassword),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
              );
            },
            child: const Text(
              'Forgot Password?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 8),
        PrimaryButton(
          label: 'Login',
          isLoading: isLoading,
          onPressed: _login,
        ),
      ],
    );
  }

  Widget _buildSignUpForm() {
    return Column(
      key: const ValueKey('signup'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: kFieldDecoration('Full Name', Icons.person_outline),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: kFieldDecoration('Phone Number', Icons.phone_outlined),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: kFieldDecoration('Email Address', Icons.email_outlined),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          decoration: kFieldDecoration(
            'Password',
            Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => obscurePassword = !obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: confirmPasswordController,
          obscureText: obscureConfirmPassword,
          decoration: kFieldDecoration(
            'Confirm Password',
            Icons.lock_reset_outlined,
            suffixIcon: IconButton(
              icon: Icon(obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword),
            ),
          ),
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: 'Create Account',
          isLoading: isLoading,
          onPressed: _signUp,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;

    // Everything is measured against the height left after the keyboard,
    // so topHeight + sheetHeight always fills the body exactly.
    final double bodyHeight = screenHeight - keyboard;
    final double sheetHeight =
        math.min(bodyHeight * 0.63, math.max(340.0, bodyHeight - 140.0));
    final double topHeight = bodyHeight - sheetHeight;

    final bool isLogin = mode == AuthMode.login;

    return Scaffold(
      backgroundColor: kPrimaryDark,
      resizeToAvoidBottomInset: false,
      body: AnimatedPadding(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboard),
        child: GlossyBackdrop(
          child: Column(
            children: [
              SizedBox(height: topHeight, child: _buildTopArea(context)),
              SizedBox(height: sheetHeight, child: _buildSheet(context, isLogin)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopArea(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 8, 20, 0),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _LogoChip(),
                _GlassIconButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 128,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 627 / 350,
                  child: Image.asset(
                    _AuthScreenState.clipArt,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                mode == AuthMode.login ? 'Welcome back' : 'Join the loop',
                key: ValueKey(mode),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                mode == AuthMode.login
                    ? 'Log in to keep earning points'
                    : 'Create your account in under a minute',
                key: ValueKey(mode),
                style: const TextStyle(color: Colors.white70, fontSize: 13.5),
              ),
            ),
            const SizedBox(height: 34),
          ],
        ),
      ),
    );
  }

  Widget _buildSheet(BuildContext context, bool isLogin) {
    return SheetPanel(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 20),
              PillToggle(
                index: isLogin ? 0 : 1,
                labels: const ['Login', 'Sign Up'],
                onChanged: (int index) => setState(() {
                  mode = index == 0 ? AuthMode.login : AuthMode.signUp;
                }),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOut,
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.06),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: isLogin ? _buildLoginForm() : _buildSignUpForm(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(color: kTextMuted, fontSize: 12.5, height: 1.4),
                    children: [
                      const TextSpan(text: 'By continuing you agree to our\n'),
                      TextSpan(
                        text: 'Terms of Service',
                        style: const TextStyle(
                          color: kPrimaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: const TextStyle(
                          color: kPrimaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _LogoChip extends StatelessWidget {
  const _LogoChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Image.asset(
        _AuthScreenState.logo,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}