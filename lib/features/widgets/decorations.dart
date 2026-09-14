import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Small abstract blob used as a corner decoration on hero/panel surfaces.
/// A superellipse-ish organic shape drawn from two arcs — subtle, never loud.
class CornerBlob extends StatelessWidget {
  final Color color;
  final double size;
  final Alignment alignment;

  const CornerBlob({
    super.key,
    required this.color,
    this.size = 160,
    this.alignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _BlobPainter(color)),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final Color color;
  _BlobPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width * 0.25, 0)
      ..quadraticBezierTo(size.width, 0, size.width, size.height * 0.72)
      ..quadraticBezierTo(size.width * 0.94, size.height * 0.25, size.width * 0.55, size.height * 0.3)
      ..quadraticBezierTo(size.width * 0.2, size.height * 0.34, size.width * 0.25, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A tiny 4-point sparkle, used around AI features and empty states.
class SparkleIcon extends StatelessWidget {
  final Color color;
  final double size;

  const SparkleIcon({super.key, required this.color, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SparklePainter(color)),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Color color;
  _SparklePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final path = Path()
      ..moveTo(cx, 0)
      ..quadraticBezierTo(cx + r * 0.12, cy - r * 0.12, cx + r, cy)
      ..quadraticBezierTo(cx + r * 0.12, cy + r * 0.12, cx, cy + r)
      ..quadraticBezierTo(cx - r * 0.12, cy + r * 0.12, cx - r, cy)
      ..quadraticBezierTo(cx - r * 0.12, cy - r * 0.12, cx, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Soft, gentle shadow — DocuMind's cards float instead of sitting flat.
class SoftShadow extends StatelessWidget {
  final Widget child;
  final Color color;
  final double blur;
  final Offset offset;

  const SoftShadow({
    super.key,
    required this.child,
    required this.color,
    this.blur = 18,
    this.offset = const Offset(0, 6),
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: blur,
            offset: offset,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Warm gradient wash used behind hero sections (ivory → soft peach).
class WarmWash extends StatelessWidget {
  final Widget? child;
  final double height;

  const WarmWash({super.key, this.child, this.height = 220});

  @override
  Widget build(BuildContext context) {
    final c = context.docColors;
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.coralSoft.withValues(alpha: 0.55),
            c.surface,
            c.lavenderSoft.withValues(alpha: 0.45),
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: child,
    );
  }
}

/// Rounded-square icon container used across list tiles and settings rows.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: background,
      ),
      child: Icon(icon, size: size, color: color),
    );
  }
}

/// Deterministic scatter of tiny dots/circles for empty states.
class DotScatter extends StatelessWidget {
  final Color color;
  final double size;

  const DotScatter({super.key, required this.color, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _DotScatterPainter(color)),
    );
  }
}

class _DotScatterPainter extends CustomPainter {
  final Color color;
  _DotScatterPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.35);
    final rng = math.Random(7); // stable layout
    for (var i = 0; i < 14; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final r = 1.5 + rng.nextDouble() * 2.5;
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DotScatterPainter oldDelegate) =>
      oldDelegate.color != color;
}
