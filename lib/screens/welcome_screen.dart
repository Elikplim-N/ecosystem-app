import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'auth_gate.dart';
import 'auth_screen.dart';
import 'ui_helpers.dart';

/// Onboarding / landing page for the login flow.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.entry = AppEntry.app});

  /// Which side of BoaMe the person chose, carried through sign-in so the
  /// account lands on the surface they expect.
  final AppEntry entry;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  /// Onboarding clip art shown at the top of the welcome page.
  ///
  /// Native size is 627 x 350 (RGBA, transparent background).
  static const String illustration = 'assets/onboarding1.png';

  /// Native aspect ratio of [illustration].
  static const double _illustrationRatio = 627 / 350;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  Animation<double> _in(
    double begin,
    double end, {
    Curve curve = Curves.easeOutCubic,
  }) {
    return CurvedAnimation(
      parent: _intro,
      curve: Interval(begin, end, curve: curve),
    );
  }

  void _openAuth(AuthMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AuthScreen(initialMode: mode)),
    ).then((_) {
      // Signing in pops back here, so hand the routing decision to the gate
      // again now that there is a session to look at.
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => AuthGate(entry: widget.entry),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _BackdropPainter()),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sized off the width rather than leftover height, so the
                      // gap under the clip art never stretches on tall screens.
                      FractionallySizedBox(
                        widthFactor: 0.92,
                        child: FadeTransition(
                          opacity: _in(0.0, 0.60),
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.88, end: 1.0).animate(
                              _in(0.0, 0.70, curve: Curves.easeOutBack),
                            ),
                            child: _EcoInfographic(controller: _loop),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FadeTransition(
                        opacity: _in(0.20, 0.70),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.18),
                            end: Offset.zero,
                          ).animate(_in(0.20, 0.70)),
                          child: const Text(
                            'Recycle.\nEarn. Repeat.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 42,
                              height: 1.08,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: kPrimaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FadeTransition(
                        opacity: _in(0.38, 0.85),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'Deposit your bottles at any kiosk, collect points, and '
                            'redeem rewards that keep the planet greener.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: kTextMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeTransition(
                        opacity: _in(0.52, 1.0),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.25),
                            end: Offset.zero,
                          ).animate(_in(0.52, 1.0)),
                          child: PrimaryButton(
                            label: 'Login',
                            icon: Icons.login_rounded,
                            onPressed: () => _openAuth(AuthMode.login),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeTransition(
                        opacity: _in(0.64, 1.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'New to BoaMe?',
                              style: TextStyle(color: kTextMuted, fontSize: 14),
                            ),
                            TextButton(
                              onPressed: () => _openAuth(AuthMode.signUp),
                              child: const Text(
                                'Create an account',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gently floating clip-art illustration.
class _EcoInfographic extends StatelessWidget {
  const _EcoInfographic({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return Transform.translate(
          offset: Offset(0, -math.sin(controller.value * math.pi) * 8),
          child: child,
        );
      },
      child: Center(
        child: AspectRatio(
          aspectRatio: _WelcomeScreenState._illustrationRatio,
          child: Image.asset(
            _WelcomeScreenState.illustration,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

/// Soft beige backdrop wash for the welcome page.
class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), kBeige],
          stops: [0.0, 0.9],
        ).createShader(Offset.zero & size),
    );

    canvas.drawCircle(
      Offset(size.width * 1.02, size.height * 0.06),
      size.width * 0.45,
      Paint()..color = kAccentTeal.withValues(alpha: 0.12),
    );

    canvas.drawCircle(
      Offset(-size.width * 0.12, size.height * 0.82),
      size.width * 0.42,
      Paint()..color = kAccentOrange.withValues(alpha: 0.10),
    );
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) => false;
}
