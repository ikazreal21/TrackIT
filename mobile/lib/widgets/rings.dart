import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Concentric progress rings (sleep / strain / recovery composition).
class Rings extends StatelessWidget {
  const Rings({
    super.key,
    required this.values,
    this.size = 150,
    this.stroke = 11,
  });

  /// (0.0–1.0 or null, color) from outermost to innermost.
  final List<(double?, Color)> values;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _RingsPainter(values, stroke),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.values, this.stroke);
  final List<(double?, Color)> values;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final gap = stroke + 7;
    var radius = size.width / 2 - stroke / 2 - 2;
    for (final (value, color) in values) {
      final track = Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, track);
      if (value != null) {
        final progress = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -math.pi / 2,
          math.pi * 2 * value.clamp(0.0, 1.0),
          false,
          progress,
        );
      }
      radius -= gap;
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.values != values;
}
