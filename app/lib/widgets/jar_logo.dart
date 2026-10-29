import 'package:flutter/material.dart';

import '../theme/jamjot_theme.dart';

/// The JamJot jar with the (nameless) note mascot inside, drawn in code as
/// the placeholder until Erika's own art replaces it
/// (drop-in slot: assets/mascot/jar_hero.svg — see ART_MANIFEST.md).
class JarLogo extends StatelessWidget {
  const JarLogo({super.key, this.size = 200});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 1.18),
      painter: _JarPainter(),
    );
  }
}

class _JarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ink = Paint()..color = JamJotColors.ink;
    final inkStroke = Paint()
      ..color = JamJotColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round;

    // Lid
    final lid = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(w / 2, h * 0.09), width: w * 0.44, height: h * 0.09),
      Radius.circular(w * 0.05),
    );
    canvas.drawRRect(lid, ink);

    // Jar body
    final jar = Path()
      ..moveTo(w * 0.26, h * 0.15)
      ..cubicTo(w * 0.18, h * 0.32, w * 0.16, h * 0.52, w * 0.16, h * 0.62)
      ..cubicTo(w * 0.16, h * 0.88, w * 0.32, h * 0.98, w * 0.5, h * 0.98)
      ..cubicTo(w * 0.68, h * 0.98, w * 0.84, h * 0.88, w * 0.84, h * 0.62)
      ..cubicTo(w * 0.84, h * 0.52, w * 0.82, h * 0.32, w * 0.74, h * 0.15)
      ..close();
    canvas.drawPath(jar, Paint()..color = Colors.white);
    canvas.drawPath(jar, inkStroke);

    // Glow inside
    canvas.drawPath(
        jar,
        Paint()
          ..color = JamJotColors.marigold.withValues(alpha: 0.25)
          ..blendMode = BlendMode.srcATop);

    // Sparks (collected practice-light)
    final spark = Paint()..color = JamJotColors.marigold;
    for (final (dx, dy, r) in [
      (0.34, 0.42, 0.022),
      (0.62, 0.38, 0.018),
      (0.56, 0.76, 0.022),
      (0.36, 0.70, 0.017),
      (0.66, 0.58, 0.019),
    ]) {
      canvas.drawCircle(Offset(w * dx, h * dy), w * r, spark);
    }

    // The note mascot
    final cx = w * 0.47, cy = h * 0.62;
    final head = Paint()..color = JamJotColors.ink;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, cy), width: w * 0.26, height: h * 0.18),
        head);
    // Stem + flag
    canvas.drawLine(Offset(cx + w * 0.115, cy - h * 0.01),
        Offset(cx + w * 0.115, cy - h * 0.30), inkStroke..strokeWidth = w * 0.045);
    final flag = Path()
      ..moveTo(cx + w * 0.115, cy - h * 0.30)
      ..quadraticBezierTo(
          cx + w * 0.16, cy - h * 0.345, cx + w * 0.21, cy - h * 0.315);
    canvas.drawPath(flag, inkStroke);
    // Face
    final eye = Paint()..color = JamJotColors.cream;
    canvas.drawCircle(Offset(cx - w * 0.045, cy - h * 0.018), w * 0.016, eye);
    canvas.drawCircle(Offset(cx + w * 0.035, cy - h * 0.018), w * 0.016, eye);
    final smile = Path()
      ..moveTo(cx - w * 0.04, cy + h * 0.02)
      ..quadraticBezierTo(cx, cy + h * 0.045, cx + w * 0.04, cy + h * 0.02);
    canvas.drawPath(
        smile,
        Paint()
          ..color = JamJotColors.cream
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.014
          ..strokeCap = StrokeCap.round);
    // Cheeks
    final cheek = Paint()..color = JamJotColors.marigold;
    canvas.drawCircle(Offset(cx - w * 0.095, cy + h * 0.012), w * 0.016, cheek);
    canvas.drawCircle(Offset(cx + w * 0.085, cy + h * 0.012), w * 0.016, cheek);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
