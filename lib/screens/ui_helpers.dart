import 'dart:math' as math;

import 'package:flutter/material.dart';

// ============================================================
// BRAND PALETTE — colours sourced from the BoaMe logo
// ============================================================

/// Main brand green.
const kPrimaryColor = Color(0xFF006158);

/// Deeper shade of the main green, used for gradient depth.
const kPrimaryDark = Color(0xFF00332F);

/// Mid green between the two — still firmly on-brand, used to give large
/// gradients a little more movement without drifting toward the light teal.
const kPrimaryMid = Color(0xFF004C46);

/// Secondary brand green. Accent only — never the dominant surface colour.
const kAccentTeal = Color(0xFF3FC4B3);

/// Accent orange.
const kAccentOrange = Color(0xFFDD901C);

/// Warm beige — the second main colour.
const kBeige = Color(0xFFE8E3D0);

/// Deeper beige, for borders and pressed states.
const kBeigeDeep = Color(0xFFD8D0B6);

/// Heading / body text colour, pulled slightly toward the brand green.
const kTextDark = Color(0xFF12312D);

/// Secondary text colour.
const kTextMuted = Color(0xFF6F807C);

/// App canvas colour — a very light tint of the beige.
const kBackground = Color(0xFFFBF8F3);

/// Brand logo, shown top-left on every home screen.
const kLogoAsset = 'assets/icon/logo_boame.png';

/// Soft pastel surface tints.
const kPastelMint = Color(0xFFE8F5F2);
const kPastelBlue = Color(0xFFE7EEFB);
const kPastelPink = Color(0xFFFCE9EF);

/// Deeper pastel tints for surfaces that need to carry weight — metric
/// cards and other blocks that used to sit on the dark header gradient.
const kDeepMint = Color(0xFFD7EFE8);
const kDeepBlue = Color(0xFFD9E4FB);
const kDeepPeach = Color(0xFFFBE7C6);
const kDeepRose = Color(0xFFFBDCE6);

/// Deep ink colours that sit legibly on top of the deeper pastels.
const kDeepMintInk = Color(0xFF00534B);
const kDeepBlueInk = Color(0xFF2F63C8);
const kDeepPeachInk = Color(0xFF9A5B04);
const kDeepRoseInk = Color(0xFFC23A66);

// ============================================================
// METRIC PALETTE
// Four hues, used in the same order everywhere so a stat card always
// means the same thing. Never invent a fifth colour for a new card.
// ============================================================

/// Card 1 — people and healthy totals.
const kMetricTeal = Color(0xFF00A88F);
const kMetricTealTint = Color(0xFFDEF6F2);

/// Card 2 — deployed infrastructure.
const kMetricBlue = Color(0xFF2F6FED);
const kMetricBlueTint = Color(0xFFE3ECFD);

/// Card 3 — attention needed.
const kMetricAmber = Color(0xFFE8930C);
const kMetricAmberTint = Color(0xFFFDF0D8);

/// Card 4 — blocked or rejected.
const kMetricRose = Color(0xFFD92B4B);
const kMetricRoseTint = Color(0xFFFCE7EC);

/// Canvas for the admin area. White keeps dense data tables and the map
/// crisp, where the warm beige reads as a tint over every card.
const kAdminBackground = Colors.white;

/// Danger tone, reserved for destructive actions only.
const kDanger = Color(0xFFC0392B);

// Bottle accents — blue for coloured plastic, pink for clear.
const kColouredBottle = Color(0xFF4F86F7);
const kClearBottle = Color(0xFFF2769B);

// ============================================================
// EXISTING SHARED HELPERS
// ============================================================

BoxDecoration kCardDecoration({double radius = 18}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: kPrimaryDark.withValues(alpha: 0.08),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

Widget kGradientHeader({
  required BuildContext context,
  required Widget child,
  double topPadding = 70,
}) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + topPadding, 20, 30),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [kPrimaryColor, kPrimaryDark],
      ),
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
    ),
    child: child,
  );
}

OutlineInputBorder _fieldBorder(Color color, {double width = 1.2}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color, width: width),
  );
}

InputDecoration kFieldDecoration(String label, IconData icon, {Widget? suffixIcon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w500),
    floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w600),
    prefixIcon: Icon(icon, size: 20, color: kPrimaryColor),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
    border: _fieldBorder(kBeigeDeep),
    enabledBorder: _fieldBorder(kBeigeDeep),
    focusedBorder: _fieldBorder(kPrimaryColor, width: 1.6),
    errorBorder: _fieldBorder(kAccentOrange, width: 1.4),
    focusedErrorBorder: _fieldBorder(kAccentOrange, width: 1.6),
  );
}

// ============================================================
// SHARED AUTH WIDGETS
// ============================================================

/// Fully rounded brand button with a teal-to-green gradient.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !isLoading;

    final Widget label_ = isLoading
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 19, color: Colors.white),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: Colors.white,
                ),
              ),
            ],
          );

    final Widget button = Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kPrimaryColor, kPrimaryDark]),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: kPrimaryColor.withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 58,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: label_,
            ),
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Sliding pill used to switch between two auth modes.
class PillToggle extends StatelessWidget {
  const PillToggle({
    super.key,
    required this.index,
    required this.labels,
    required this.onChanged,
    this.height = 54,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: kBeige, borderRadius: BorderRadius.circular(999)),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double slot = constraints.maxWidth / labels.length;

          return Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                alignment: index == 0 ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: slot,
                  height: height - 10,
                  decoration: BoxDecoration(
                    color: kPrimaryColor,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryColor.withValues(alpha: 0.30),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (int i = 0; i < labels.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(i),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: i == index ? Colors.white : kTextMuted,
                            ),
                            child: Text(labels[i]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Full-bleed glossy brand backdrop for the auth screen.
class GlossyBackdrop extends StatelessWidget {
  const GlossyBackdrop({super.key, required this.child, this.colors});

  final Widget child;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors ??
              const [
                Color(0xFF0A7C6E),
                kPrimaryColor,
                kPrimaryDark,
              ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _GlossPainter()),
          child,
        ],
      ),
    );
  }
}

class _GlossPainter extends CustomPainter {
  const _GlossPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Soft light source in the upper right.
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.10),
      size.width * 0.55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.26),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.86, size.height * 0.10),
            radius: size.width * 0.55,
          ),
        ),
    );

    // Wide diagonal gloss sweep across the middle.
    final Path sweep = Path()
      ..moveTo(-size.width * 0.2, size.height * 0.52)
      ..lineTo(size.width * 0.7, -size.height * 0.05)
      ..lineTo(size.width * 1.05, -size.height * 0.05)
      ..lineTo(size.width * 0.15, size.height * 0.62)
      ..close();
    canvas.drawPath(sweep, Paint()..color = Colors.white.withValues(alpha: 0.07));

    // Faint tinted blobs for depth.
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.30),
      size.width * 0.34,
      Paint()..color = kAccentTeal.withValues(alpha: 0.20),
    );
    canvas.drawCircle(
      Offset(size.width * 0.95, size.height * 0.38),
      size.width * 0.26,
      Paint()..color = kAccentOrange.withValues(alpha: 0.16),
    );
  }

  @override
  bool shouldRepaint(covariant _GlossPainter oldDelegate) => false;
}

/// Rounded floating panel used as the auth sheet.
class SheetPanel extends StatelessWidget {
  const SheetPanel({
    super.key,
    required this.child,
    this.radius = 34,
    this.elevation = 26,
    this.color = kBackground,
    this.gutter = 20,
  });

  final Widget child;
  final double radius;
  final double elevation;
  final Color color;

  /// Horizontal breathing room. Sheets round their top corners, so
  /// content without a gutter gets visually clipped by the curve.
  final double gutter;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        boxShadow: [
          BoxShadow(
            color: kPrimaryDark.withValues(alpha: 0.28),
            blurRadius: elevation,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        child: child,
      ),
    );
  }
}

/// Small grab handle shown at the top of the auth sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 46,
        height: 5,
        decoration: BoxDecoration(
          color: kBeigeDeep,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

// ============================================================
// RECYCLE GLYPH — shared vector mark
// ============================================================

/// Paints the three-arrow recycle mark centred on [center].
void paintRecycleMark(
  Canvas canvas,
  Offset center,
  double radius, {
  Color color = kPrimaryColor,
  double strokeScale = 1,
}) {
  final double width = radius * 0.30 * strokeScale;

  for (int i = 0; i < 3; i++) {
    final double start = -math.pi / 2 + i * (math.pi * 2 / 3);
    final double sweep = math.pi * 0.52;
    final double end = start + sweep;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = color,
    );

    // Arrow head sitting on the arc end, pointing along the tangent.
    final Offset tip = Offset(
      center.dx + math.cos(end) * radius,
      center.dy + math.sin(end) * radius,
    );
    final Offset dir = Offset(-math.sin(end), math.cos(end));
    final Offset nrm = Offset(-dir.dy, dir.dx);
    final double head = radius * 0.34 * strokeScale;
    final double half = radius * 0.24 * strokeScale;

    canvas.drawPath(
      Path()
        ..moveTo(tip.dx + dir.dx * head, tip.dy + dir.dy * head)
        ..lineTo(tip.dx + nrm.dx * half, tip.dy + nrm.dy * half)
        ..lineTo(tip.dx - nrm.dx * half, tip.dy - nrm.dy * half)
        ..close(),
      Paint()..color = color,
    );
  }
}

/// Leaf shape used in the onboarding infographic.
Path buildLeafPath(double length, double width) {
  return Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(length * 0.5, -width, length, 0)
    ..quadraticBezierTo(length * 0.5, width, 0, 0)
    ..close();
}