import 'package:flutter/material.dart';
import 'dart:async';

// ============================================================
// KIOSK MOCKUP — screensaver + scan/phone/anonymous flow
// Pure UI mockup: no Firebase, no real backend calls.
// ============================================================

class KioskMockupScreen extends StatefulWidget {
  const KioskMockupScreen({super.key});

  @override
  State<KioskMockupScreen> createState() => _KioskMockupScreenState();
}

enum KioskStage { idle, chooseMethod, phoneEntry, processing, success }

class _KioskMockupScreenState extends State<KioskMockupScreen> {
  KioskStage stage = KioskStage.idle;
  String? selectedMethod;
  Timer? idleTimer;

  final phoneController = TextEditingController();

  void _wake() {
    if (stage == KioskStage.idle) {
      setState(() {
        stage = KioskStage.chooseMethod;
      });
      _resetIdleTimer();
    }
  }

  void _resetIdleTimer() {
    idleTimer?.cancel();
    idleTimer = Timer(const Duration(seconds: 20), () {
      if (mounted) {
        setState(() {
          stage = KioskStage.idle;
          selectedMethod = null;
          phoneController.clear();
        });
      }
    });
  }

  void _selectMethod(String method) {
    setState(() {
      selectedMethod = method;
    });
    _resetIdleTimer();

    if (method == 'phone') {
      setState(() {
        stage = KioskStage.phoneEntry;
      });
      return;
    }

    // RFID or Anonymous — simulate a short "processing" delay
    setState(() {
      stage = KioskStage.processing;
    });

    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          stage = KioskStage.success;
        });

        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              stage = KioskStage.idle;
              selectedMethod = null;
            });
          }
        });
      }
    });
  }

  void _submitPhone() {
    if (phoneController.text.trim().isEmpty) return;

    setState(() {
      stage = KioskStage.processing;
    });
    _resetIdleTimer();

    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          stage = KioskStage.success;
        });

        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              stage = KioskStage.idle;
              selectedMethod = null;
              phoneController.clear();
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    idleTimer?.cancel();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _wake,
        behavior: HitTestBehavior.opaque,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildStage(),
        ),
      ),
    );
  }

  Widget _buildStage() {
    switch (stage) {
      case KioskStage.idle:
        return _idleScreen();
      case KioskStage.chooseMethod:
        return _chooseMethodScreen();
      case KioskStage.phoneEntry:
        return _phoneEntryScreen();
      case KioskStage.processing:
        return _processingScreen();
      case KioskStage.success:
        return _successScreen();
    }
  }

  // ------------------------------------------------------------
  // IDLE / SCREENSAVER
  // ------------------------------------------------------------
  Widget _idleScreen() {
    return Container(
      key: const ValueKey('idle'),
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00C896), Color(0xFF00875A)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.recycling,
                size: 90,
                color: Color(0xFF00875A),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'ECOSYSTEM',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Recycle. Earn. Make a Difference.',
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
            const SizedBox(height: 60),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1.0),
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: child,
                );
              },
              child: const Text(
                'TOUCH SCREEN TO BEGIN',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // CHOOSE METHOD
  // ------------------------------------------------------------
  Widget _chooseMethodScreen() {
    return Container(
      key: const ValueKey('choose'),
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF4F7F6),
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.recycling, size: 70, color: Color(0xFF00875A)),
          const SizedBox(height: 20),
          const Text(
            'How would you like to recycle?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B4332),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'Choose an option below to continue',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 45),

          _methodButton(
            icon: Icons.contactless,
            label: 'SCAN YOUR CARD',
            subtitle: 'Tap your registered RFID card',
            color: const Color(0xFF00C896),
            onTap: () => _selectMethod('rfid'),
          ),
          const SizedBox(height: 18),

          _methodButton(
            icon: Icons.phone_iphone,
            label: 'ENTER PHONE NUMBER',
            subtitle: 'Use your registered phone number',
            color: const Color(0xFF5B8DEF),
            onTap: () => _selectMethod('phone'),
          ),
          const SizedBox(height: 18),

          _methodButton(
            icon: Icons.person_off_outlined,
            label: 'CONTINUE ANONYMOUSLY',
            subtitle: 'No account needed — just recycle',
            color: const Color(0xFF9AA5B1),
            onTap: () => _selectMethod('anonymous'),
          ),
        ],
      ),
    );
  }

  Widget _methodButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B4332),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // PHONE ENTRY
  // ------------------------------------------------------------
  Widget _phoneEntryScreen() {
    return Container(
      key: const ValueKey('phone'),
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF4F7F6),
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.phone_iphone, size: 60, color: Color(0xFF5B8DEF)),
          const SizedBox(height: 20),
          const Text(
            'Enter Your Phone Number',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B4332),
            ),
          ),
          const SizedBox(height: 30),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22),
            decoration: InputDecoration(
              hintText: '0XX XXX XXXX',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _submitPhone,
              child: const Text(
                'CONTINUE',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () {
              setState(() {
                stage = KioskStage.chooseMethod;
                phoneController.clear();
              });
            },
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // PROCESSING
  // ------------------------------------------------------------
  Widget _processingScreen() {
    return Container(
      key: const ValueKey('processing'),
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF4F7F6),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF00875A)),
            SizedBox(height: 20),
            Text(
              'Please insert your bottle...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B4332),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SUCCESS
  // ------------------------------------------------------------
  Widget _successScreen() {
    final isAnonymous = selectedMethod == 'anonymous';

    return Container(
      key: const ValueKey('success'),
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF4F7F6),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF00C896),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              'Thank You for Recycling! 🎉',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B4332),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isAnonymous
                  ? 'Your bottle has been recorded.'
                  : '+10 points added to your account.',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}