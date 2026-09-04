import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Arc gauge like the reference design: 270° sweep with a gap at the
/// bottom, rounded caps, dim track underneath the progress arc.
class ScoreGauge extends StatelessWidget {
  const ScoreGauge({
    super.key,
    required this.value01,
    required this.color,
    this.size = 190,
    this.stroke = 13,
    this.child,
  });

  /// 0.0–1.0, or null to render only the empty track.
  final double? value01;
  final Color color;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _GaugePainter(value01, color, stroke),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.value01, this.color, this.stroke);
  final double? value01;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;
    final rect = Offset.zero & size;
    final deflate = stroke / 2 + 2;

    final track = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(deflate), start, sweep, false, track);

    if (value01 != null) {
      final progress = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect.deflate(deflate), start,
          sweep * value01!.clamp(0.0, 1.0), false, progress);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value01 != value01 || old.color != color;
}
