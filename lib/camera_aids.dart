import 'dart:math' as math;

import 'package:flutter/material.dart';

class CameraAidPainter extends CustomPainter {
  const CameraAidPainter({
    this.grid = false,
    this.focus,
    this.roll,
    this.exposure = 0,
    this.showExposure = false,
  });
  final bool grid, showExposure;
  final Offset? focus;
  final double? roll;
  final double exposure;
  @override
  void paint(Canvas canvas, Size size) {
    if (grid) {
      final paint = Paint()
        ..color = Colors.white38
        ..strokeWidth = 1;
      for (final fraction in [1 / 3, 2 / 3]) {
        canvas.drawLine(
          Offset(size.width * fraction, 0),
          Offset(size.width * fraction, size.height),
          paint,
        );
        canvas.drawLine(
          Offset(0, size.height * fraction),
          Offset(size.width, size.height * fraction),
          paint,
        );
      }
    }
    if (focus != null) {
      final center = Offset(focus!.dx * size.width, focus!.dy * size.height);
      final paint = Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final box = Rect.fromCenter(center: center, width: 44, height: 44);
      canvas.drawRect(box, paint);
      if (showExposure) {
        final text = TextPainter(
          text: TextSpan(
            text: '☀',
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 12,
              shadows: [Shadow(blurRadius: 3)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(
          canvas,
          Offset(
            (center.dx + 27).clamp(0, math.max(0, size.width - text.width)),
            (center.dy - 8).clamp(0, math.max(0, size.height - text.height)),
          ),
        );
        text.dispose();
      }
    }
    if (roll != null) {
      final center = size.center(Offset.zero);
      final paint = Paint()
        ..strokeWidth = 2
        ..color = roll!.abs() < math.pi / 90
            ? Colors.greenAccent
            : Colors.white;
      canvas.drawLine(
        center - const Offset(44, 0),
        center + const Offset(44, 0),
        Paint()
          ..color = Colors.white38
          ..strokeWidth = 1,
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-roll!);
      canvas.drawLine(const Offset(-30, 0), const Offset(30, 0), paint);
      canvas.drawCircle(Offset.zero, 4, paint..style = PaintingStyle.stroke);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CameraAidPainter oldDelegate) =>
      grid != oldDelegate.grid ||
      focus != oldDelegate.focus ||
      roll != oldDelegate.roll ||
      exposure != oldDelegate.exposure ||
      showExposure != oldDelegate.showExposure;
}
