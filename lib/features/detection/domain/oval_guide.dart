import 'package:flutter/material.dart';

/// Checks whether an axis-aligned [faceBox] is comfortably enclosed within an ellipse
/// defined by [ovalRect] in preview coordinates.
///
/// An axis-aligned rectangular bounding box of an oval human face naturally has
/// empty corners. [cornerTolerance] allows the 4 corners of the rectangular
/// bounding box to reach up to [cornerTolerance] (default 1.25) of normalized
/// ellipse distance. [cardinalTolerance] allows cardinal extents (top, bottom,
/// left, right) a slight natural margin (default 1.08) so natural chin/hair
/// borders do not trigger false boundary rejections.
bool isFaceInsideOval(
  Rect faceBox,
  Rect ovalRect, {
  double cornerTolerance = 1.25,
  double cardinalTolerance = 1.08,
}) {
  if (faceBox.isEmpty || ovalRect.isEmpty) return false;

  final double cx = ovalRect.center.dx;
  final double cy = ovalRect.center.dy;
  final double rx = ovalRect.width / 2.0;
  final double ry = ovalRect.height / 2.0;

  if (rx <= 0 || ry <= 0) return false;

  final double rx2 = rx * rx;
  final double ry2 = ry * ry;

  // 1. Center of the face must be inside the oval
  final double centerDx = faceBox.center.dx - cx;
  final double centerDy = faceBox.center.dy - cy;
  if ((centerDx * centerDx) / rx2 + (centerDy * centerDy) / ry2 > 1.0) {
    return false;
  }

  // 2. Cardinal extents (top center, bottom center, left center, right center)
  // must be within the oval guide (within cardinalTolerance)
  final double topDy = faceBox.top - cy;
  final double bottomDy = faceBox.bottom - cy;
  final double leftDx = faceBox.left - cx;
  final double rightDx = faceBox.right - cx;

  final double cardTol2 = cardinalTolerance * cardinalTolerance;
  if ((topDy * topDy) / ry2 > cardTol2 ||
      (bottomDy * bottomDy) / ry2 > cardTol2) {
    return false;
  }
  if ((leftDx * leftDx) / rx2 > cardTol2 ||
      (rightDx * rightDx) / rx2 > cardTol2) {
    return false;
  }

  // 3. Rectangular corners check with tolerance
  final List<Offset> corners = <Offset>[
    Offset(faceBox.left, faceBox.top),
    Offset(faceBox.right, faceBox.top),
    Offset(faceBox.left, faceBox.bottom),
    Offset(faceBox.right, faceBox.bottom),
  ];

  for (final Offset c in corners) {
    final double dx = c.dx - cx;
    final double dy = c.dy - cy;
    final double normDist = (dx * dx) / rx2 + (dy * dy) / ry2;
    if (normDist > cornerTolerance) {
      return false;
    }
  }

  return true;
}

/// Computes the default oval guide bounding rectangle for a given [previewSize].
Rect defaultOvalRect(Size previewSize) {
  final double ovalWidth = previewSize.width * 0.70;
  final double ovalHeight = previewSize.height * 0.50;
  final Offset center = Offset(
    previewSize.width / 2.0,
    previewSize.height * 0.45,
  );
  return Rect.fromCenter(center: center, width: ovalWidth, height: ovalHeight);
}

/// CustomPainter that renders a dimmed overlay with a transparent oval cut-out
/// and a colored guideline border.
class OvalGuidePainter extends CustomPainter {
  const OvalGuidePainter({
    required this.ovalRect,
    required this.borderColor,
    this.overlayColor = const Color(0x88000000),
    this.strokeWidth = 3.0,
  });

  final Rect ovalRect;
  final Color borderColor;
  final Color overlayColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
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

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawOval(ovalRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant OvalGuidePainter oldDelegate) {
    return oldDelegate.ovalRect != ovalRect ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.overlayColor != overlayColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
