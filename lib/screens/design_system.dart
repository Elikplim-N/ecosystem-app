import 'package:flutter/material.dart';
import 'ui_helpers.dart';

// Re-exported so a screen only ever needs one import for the whole UI kit.
export 'ui_helpers.dart';

// ============================================================
// DESIGN SYSTEM
// Shared building blocks so every screen (user, ambassador,
// admin) inherits the exact same spacing, colour and shape
// language instead of re-declaring it per file.
// ============================================================

/// Standard page shell: beige background + centred, flat AppBar.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.bottom,
    this.floatingActionButton,
    this.extendBodyBehindAppBar = false,
    this.backgroundColor = kBackground,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottom;
  final Widget? floatingActionButton;
  final bool extendBodyBehindAppBar;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: kTextDark,
          ),
        ),
        iconTheme: const IconThemeData(color: kTextDark),
        actions: actions,
      ),
      body: body,
      bottomNavigationBar: bottom,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Shown when Firebase Auth has no signed-in user.
class SignedOutView extends StatelessWidget {
  const SignedOutView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: EmptyState(
            icon: Icons.person_off_rounded,
            title: 'No user is logged in',
            message: 'Sign in to continue.',
          ),
        ),
      ),
    );
  }
}

/// Neutral card surface used for every grouped block of content.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 20,
    this.color,
    this.border,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;
  final Color? border;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: border != null ? Border.all(color: border!, width: 1.2) : null,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: kPrimaryDark.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

/// Diagonal brand-gradient card.
class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.colors,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final List<Color>? colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors ?? const [kPrimaryColor, kPrimaryDark],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: kPrimaryDark.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

/// Rounded square icon holder.
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.icon,
    this.tint = kPastelMint,
    this.color = kPrimaryColor,
    this.size = 44,
    this.iconSize = 22,
    this.radius = 15,
  });

  final IconData icon;
  final Color tint;
  final Color color;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

/// Section label + optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: kTextDark,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 13, color: kTextMuted),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ?action,
        ],
      ),
    );
  }
}

/// Small uppercase label.
class Eyebrow extends StatelessWidget {
  const Eyebrow(
    this.text, {
    super.key,
    this.color = Colors.white70,
    this.fontSize = 11,
  });

  final String text;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: color,
      ),
    );
  }
}

/// Compact metric tile for dashboard rows.
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.tint = Colors.white,
    this.accent = kPrimaryColor,
    this.onDark = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color tint;
  final Color accent;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final labelColor = onDark ? Colors.white70 : kTextMuted;
    final valueColor = onDark ? Colors.white : kTextDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: onDark
              ? Colors.white.withValues(alpha: 0.18)
              : accent.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: accent),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Home-screen top bar: brand logo on the left, notification bell and
/// profile avatar on the right. Shared so the admin area matches the
/// member area exactly instead of re-declaring its own header.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.onNotifications,
    required this.onProfile,
    this.notificationCount = 0,
    this.avatarIcon = '',
    this.logoHeight = 34,
    this.topPadding = 14,
  });

  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final int notificationCount;
  final String avatarIcon;
  final double logoHeight;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + topPadding,
        20,
        0,
      ),
      child: Row(
        children: [
          SizedBox(
            height: logoHeight,
            child: Image.asset(kLogoAsset, fit: BoxFit.contain),
          ),
          const Spacer(),
          _TopBarAction(
            badgeCount: notificationCount,
            onTap: onNotifications,
            child: const Icon(
              Icons.notifications_rounded,
              size: 23,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          _TopBarAction(
            onTap: onProfile,
            child: avatarIcon.isEmpty
                ? const Icon(
                    Icons.person_rounded,
                    size: 24,
                    color: Colors.white,
                  )
                : Text(avatarIcon, style: const TextStyle(fontSize: 19)),
          ),
        ],
      ),
    );
  }
}

/// Circular brand button inside [AppTopBar], with an optional unread dot.
class _TopBarAction extends StatelessWidget {
  const _TopBarAction({
    required this.onTap,
    required this.child,
    this.badgeCount = 0,
  });

  final VoidCallback onTap;
  final Widget child;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: kPrimaryColor,
              shape: BoxShape.circle,
            ),
            child: child,
          ),
          if (badgeCount > 0)
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: kAccentOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: kBackground, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dashboard metric card: icon in a circular holder plus title, then the
/// unit, the headline number and a mini visualiser on the right.
/// Dashboard metric card.
///
/// Header is the icon sitting inline with the title (no chip behind it),
/// then the headline number with its subtext directly underneath, and an
/// optional mini visualiser on the right.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.unit,
    required this.value,
    required this.icon,
    required this.tint,
    required this.accent,
    this.visualiser,
    this.onTap,
  });

  final String title;
  final String unit;
  final String value;
  final IconData icon;
  final Color tint;
  final Color accent;
  final Widget? visualiser;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 15),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: -1,
                      color: kTextDark,
                    ),
                  ),
                ),
              ),
              if (visualiser != null) ...[
                const SizedBox(width: 8),
                visualiser!,
              ],
            ],
          ),
          const SizedBox(height: 5),
          Text(
            unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: kTextMuted,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: content,
      ),
    );
  }
}

/// Circular progress ring used as a metric visualiser.
class MiniRing extends StatelessWidget {
  const MiniRing({
    super.key,
    required this.progress,
    required this.color,
    required this.label,
    this.size = 44,
  });

  final double progress;
  final Color color;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress.clamp(0, 1)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, animated, _) => CircularProgressIndicator(
              value: animated,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.75),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical bar chart used as a metric visualiser.
class MiniBars extends StatelessWidget {
  const MiniBars({
    super.key,
    required this.values,
    required this.color,
    this.size = 44,
  });

  final List<double> values;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final max = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      width: size,
      height: size * 0.78,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final v in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: FractionallySizedBox(
                  heightFactor: max <= 0 ? 0.06 : (v / max).clamp(0.06, 1),
                  alignment: Alignment.bottomCenter,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.85),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
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

/// Smooth line graph used as a metric visualiser.
class MiniSparkline extends StatelessWidget {
  const MiniSparkline({
    super.key,
    required this.values,
    required this.color,
    this.size = 44,
  });

  final List<double> values;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.78,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) => CustomPaint(
          painter: _SparklinePainter(
            values: values,
            color: color,
            progress: animated,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.values,
    required this.color,
    required this.progress,
  });

  final List<double> values;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    final span = (max - min).abs() < 0.0001 ? 1.0 : max - min;

    final points = <Offset>[
      for (int i = 0; i < values.length; i++)
        Offset(
          size.width * (i / (values.length - 1)),
          size.height -
              ((values[i] - min) / span * (size.height * 0.78)) -
              size.height * 0.11,
        ),
    ];

    final visible = (points.length * progress).ceil().clamp(2, points.length);
    final shown = points.sublist(0, visible);

    final line = Path()..moveTo(shown.first.dx, shown.first.dy);
    for (int i = 0; i < shown.length - 1; i++) {
      final a = shown[i];
      final b = shown[i + 1];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      line.quadraticBezierTo(a.dx, a.dy, mid.dx, mid.dy);
    }
    line.lineTo(shown.last.dx, shown.last.dy);

    final fill = Path.from(line)
      ..lineTo(shown.last.dx, size.height)
      ..lineTo(shown.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.26), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    canvas.drawCircle(shown.last, 2.8, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.values != values;
}

/// Outlined role pill. Bordered rather than filled so a screen full of
/// role pills stays calm, and the colour still reads at a glance.
class RolePill extends StatelessWidget {
  const RolePill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 9 : 12,
        vertical: dense ? 5 : 8,
      ),

      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width action row used by every destructive or state-changing
/// button. Same shape everywhere; only the colour changes.
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint = kPrimaryColor,
    this.description,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color tint;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: tint.withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tint,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: kTextMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: tint.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

/// Coloured status pill (used for bin status, roles, RFID state).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.solid = false,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool solid;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 9 : 11,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: solid ? null : Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: dense ? 12 : 14,
              color: solid ? Colors.white : color,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: solid ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty / zero-state block with optional call to action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.tint = kPastelMint,
    this.accent = kPrimaryColor,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color tint;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kBeige),
      ),
      child: Column(
        children: [
          IconChip(
            icon: icon,
            tint: tint,
            color: accent,
            size: 62,
            iconSize: 30,
            radius: 22,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: kTextDark,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: kTextMuted,
                height: 1.45,
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

/// Centred spinner used wherever a stream is waiting.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: kPrimaryColor,
        ),
      ),
    );
  }
}

/// Rounded search input.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: kTextDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: kTextMuted),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 20,
          color: kTextMuted,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kBeige),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kBeige),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kPrimaryColor, width: 1.6),
        ),
      ),
    );
  }
}

/// Horizontal single-select filter row.
class FilterRow extends StatelessWidget {
  const FilterRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<FilterOption> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = option.value == selected;
          return GestureDetector(
            onTap: () => onChanged(option.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? kPrimaryColor : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: isSelected ? kPrimaryColor : kBeige),
              ),
              child: Text(
                option.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : kTextMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class FilterOption {
  const FilterOption(this.value, this.label);
  final String value;
  final String label;
}

/// Thin progress bar used for bin fill level and leaderboard goals.
class LevelBar extends StatelessWidget {
  const LevelBar({
    super.key,
    required this.value,
    this.color = kPrimaryColor,
    this.track = kBeige,
    this.height = 8,
  });

  final double value;
  final Color color;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) {
          return LinearProgressIndicator(
            value: animated,
            minHeight: height,
            backgroundColor: track,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          );
        },
      ),
    );
  }
}

/// Inline destructive/confirm dialog matching the brand.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'CONFIRM',
  String cancelLabel = 'CANCEL',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: kTextDark,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: kTextMuted, height: 1.45),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: kTextMuted),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: destructive
                  ? const Color(0xFFC0392B)
                  : kPrimaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Toast-style feedback.
void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: kAccentTeal,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
}

/// Full-screen error block for failed stream reads.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Something went wrong',
          message: message,
          tint: kPastelPink,
          accent: const Color(0xFFC0392B),
          action: onRetry == null
              ? null
              : OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('TRY AGAIN'),
                ),
        ),
      ),
    );
  }
}
