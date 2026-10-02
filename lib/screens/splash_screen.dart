import 'package:flutter/material.dart';
import 'auth_gate.dart';
import 'ui_helpers.dart';

/// First screen the app opens on.
///
/// Shows the BoaMe mark while the splash animation plays, then hands over
/// to the entry chooser.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.startupError});

  /// Set when the saved session could not be read; shown instead of hanging.
  final Object? startupError;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _pulse;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoLift;
  late final Animation<double> _wordFade;
  late final Animation<double> _wordLift;
  late final Animation<double> _tagFade;
  late final Animation<double> _breath;

  @override
  void initState() {
    super.initState();

    // Entrance: mark scales in, wordmark and tagline follow it up.
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _logoScale = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.72, curve: Curves.easeOutBack),
    );
    _logoFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
    );
    _logoLift = Tween<double>(begin: 26, end: 0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.0, 0.72, curve: Curves.easeOutCubic),
      ),
    );
    _wordFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.34, 0.78, curve: Curves.easeIn),
    );
    _wordLift = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.34, 0.86, curve: Curves.easeOutCubic),
      ),
    );
    _tagFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.58, 1.0, curve: Curves.easeIn),
    );

    // A slow breath on the mark keeps the screen alive while it waits.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );
    _breath = Tween<double>(
      begin: 1.0,
      end: 1.045,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    if (widget.startupError != null) {
      // Nothing to animate on the error screen, and a running ticker there
      // would never settle.
      _intro.value = 1;
      return;
    }

    _pulse.repeat(reverse: true);
    _intro.forward();

    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthGate()),
        );
      }
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.startupError != null) {
      return const _DataServiceUnavailable();
    }

    return Scaffold(
      backgroundColor: kPrimaryDark,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kPrimaryColor, kPrimaryDark],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: _GlowOrbs()),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_intro, _pulse]),
                    builder: (context, _) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: _logoFade.value,
                            child: Transform.translate(
                              offset: Offset(0, _logoLift.value),
                              child: Transform.scale(
                                scale: _logoScale.value * _breath.value,
                                child: const _LogoPlate(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          Opacity(
                            opacity: _wordFade.value,
                            child: Transform.translate(
                              offset: Offset(0, _wordLift.value),
                              child: const _Wordmark(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Opacity(
                            opacity: _tagFade.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.22),
                                ),
                              ),
                              child: const Text(
                                'Recycle. Earn. Make a difference.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The BoaMe mark on a white plate so it reads on any background.
class _LogoPlate extends StatelessWidget {
  const _LogoPlate();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 34,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.22),
            blurRadius: 2,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Image.asset(
        kLogoAsset,
        width: 132,
        height: 132,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// 'BoaMe' wordmark with the brand accent on the trailing stroke.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'BoaMe',
          style: TextStyle(
            fontSize: 46,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            height: 1,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 52,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

/// Soft background movement so the gradient is not static.
class _GlowOrbs extends StatefulWidget {
  const _GlowOrbs();

  @override
  State<_GlowOrbs> createState() => _GlowOrbsState();
}

class _GlowOrbsState extends State<_GlowOrbs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Stack(
          children: [
            Positioned(
              top: -90 + 24 * t,
              left: -70 + 20 * t,
              child: _orb(230, 0.10),
            ),
            Positioned(
              bottom: -110 + 26 * (1 - t),
              right: -60 + 18 * (1 - t),
              child: _orb(280, 0.08),
            ),
          ],
        );
      },
    );
  }

  Widget _orb(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: opacity),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// Shown instead of the splash when the saved session could not be read.
class _DataServiceUnavailable extends StatelessWidget {
  const _DataServiceUnavailable();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _LogoPlate(),
              const SizedBox(height: 24),
              const Text(
                'BoaMe',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  color: kTextDark,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'The data service could not start.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kTextDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Check your connection and make sure the BoaMe server address '
                'is right, then reload.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: kTextMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                    builder: (_) => const AuthGate(),
                  ),
                  (route) => false,
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('CONTINUE ANYWAY'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
