import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Reusable DistrictRingLogo widget.
/// Drawn with CustomPainter: A gold flame inside a white circle with a gold ring,
/// surrounded by a ring of exactly 33 small dots (representing the ~33 Abuakwa districts).
class DistrictRingLogo extends StatelessWidget {
  final double size;
  final Color flameColor;
  final Color ringColor;
  final Color dotColor;
  final Color innerCircleColor;

  const DistrictRingLogo({
    super.key,
    this.size = 110,
    this.flameColor = AppColors.gold,
    this.ringColor = AppColors.gold,
    this.dotColor = AppColors.lightGold,
    this.innerCircleColor = AppColors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DistrictRingLogoPainter(
          flameColor: flameColor,
          ringColor: ringColor,
          dotColor: dotColor,
          innerCircleColor: innerCircleColor,
        ),
      ),
    );
  }
}

class _DistrictRingLogoPainter extends CustomPainter {
  final Color flameColor;
  final Color ringColor;
  final Color dotColor;
  final Color innerCircleColor;

  static const int districtCount = 33;

  _DistrictRingLogoPainter({
    required this.flameColor,
    required this.ringColor,
    required this.dotColor,
    required this.innerCircleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final dotRingRadius = outerRadius - 4.0;
    final innerCircleRadius = outerRadius * 0.72;

    // 1. Draw 33 small dots in a ring around the circle
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    final dotRadius = size.width * 0.024; // Scaled dot size
    for (int i = 0; i < districtCount; i++) {
      final angle = (i * 2 * math.pi / districtCount) - (math.pi / 2);
      final dx = center.dx + dotRingRadius * math.cos(angle);
      final dy = center.dy + dotRingRadius * math.sin(angle);
      canvas.drawCircle(Offset(dx, dy), dotRadius, dotPaint);
    }

    // 2. Draw White Inner Circle Background
    final innerBgPaint = Paint()
      ..color = innerCircleColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerCircleRadius, innerBgPaint);

    // 3. Draw Gold Ring Border around White Circle
    final ringBorderPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.032;
    canvas.drawCircle(center, innerCircleRadius, ringBorderPaint);

    // 4. Draw Gold Flame inside the circle
    _drawFlame(canvas, center, innerCircleRadius * 0.85);
  }

  void _drawFlame(Canvas canvas, Offset center, double flameScaleRadius) {
    final flamePaint = Paint()
      ..color = flameColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final h = flameScaleRadius * 1.5;
    final w = flameScaleRadius * 1.1;
    final topY = center.dy - h * 0.52;
    final bottomY = center.dy + h * 0.48;

    // Smooth stylized Pentecost flame
    path.moveTo(center.dx, topY);

    // Right curve down
    path.cubicTo(
      center.dx + w * 0.65,
      center.dy - h * 0.15,
      center.dx + w * 0.65,
      center.dy + h * 0.25,
      center.dx + w * 0.25,
      bottomY,
    );

    // Bottom base curve
    path.cubicTo(
      center.dx + w * 0.1,
      bottomY + h * 0.04,
      center.dx - w * 0.1,
      bottomY + h * 0.04,
      center.dx - w * 0.25,
      bottomY,
    );

    // Left curve up
    path.cubicTo(
      center.dx - w * 0.65,
      center.dy + h * 0.25,
      center.dx - w * 0.65,
      center.dy - h * 0.15,
      center.dx,
      topY,
    );

    path.close();

    // Inner flame cutout / inner flame highlight for depth
    final innerPath = Path();
    final inH = h * 0.52;
    final inW = w * 0.48;
    final inTopY = center.dy - inH * 0.1;
    final inBottomY = center.dy + h * 0.42;

    innerPath.moveTo(center.dx, inTopY);
    innerPath.cubicTo(
      center.dx + inW * 0.6,
      center.dy + inH * 0.2,
      center.dx + inW * 0.4,
      inBottomY,
      center.dx,
      inBottomY,
    );
    innerPath.cubicTo(
      center.dx - inW * 0.4,
      inBottomY,
      center.dx - inW * 0.6,
      center.dy + inH * 0.2,
      center.dx,
      inTopY,
    );
    innerPath.close();

    canvas.drawPath(path, flamePaint);

    final innerFlamePaint = Paint()
      ..color = innerCircleColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawPath(innerPath, innerFlamePaint);
  }

  @override
  bool shouldRepaint(covariant _DistrictRingLogoPainter oldDelegate) {
    return oldDelegate.flameColor != flameColor ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.innerCircleColor != innerCircleColor;
  }
}
