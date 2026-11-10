import 'dart:math' as math;

import 'package:flutter/material.dart';

/// CustomPainter rendering a dimmed background with transparent oval cut-out,
/// a state-dependent guideline border, and an elliptical/circular progress indicator
/// tracing the remaining session time.
class SessionOvalPainter extends CustomPainter {
  const SessionOvalPainter({
    required this.ovalRect,
    required this.borderColor,
    this.totalProgress = 1.0,
    this.overlayColor = const Color(0x99000000),
    this.strokeWidth = 3.5,
  });

  /// The bounding rectangle of the face guide ellipse in preview coordinates.
  final Rect ovalRect;

  /// Dynamic color representing current session state.
  final Color borderColor;

  /// Fraction of total session time remaining (1.0 down to 0.0).
  final double totalProgress;

  /// Color used for the dimmed screen overlay.
  final Color overlayColor;

  /// Stroke width for the guide border and progress arc.
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (ovalRect.isEmpty) return;

    // 1. Draw dimmed overlay with transparent oval cutout
    final Path screenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path ovalPath = Path()..addOval(ovalRect);
    final Path overlayPath = Path.combine(
      PathOperation.difference,
      screenPath,
      ovalPath,
    );

    final Paint overlayPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(overlayPath, overlayPaint);

    // 2. Draw subtle background track for the oval guide
    final Paint trackPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawOval(ovalRect, trackPaint);

    // 3. Draw progress arc around the oval guide if progress is active
    if (totalProgress > 0.0 && totalProgress <= 1.0) {
      final Paint progressPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth + 1.0;

      // Draw clockwise sweep arc starting from top center (-pi/2)
      final double sweepAngle = 2.0 * math.pi * totalProgress.clamp(0.0, 1.0);
      canvas.drawArc(
        ovalRect,
        -math.pi / 2.0,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SessionOvalPainter oldDelegate) {
    return oldDelegate.ovalRect != ovalRect ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.totalProgress != totalProgress ||
        oldDelegate.overlayColor != overlayColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
