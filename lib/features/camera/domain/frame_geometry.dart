import 'package:flutter/foundation.dart';

import '../../../core/utils/affine_matrix.dart';

/// Geometry calculator for converting between raw camera frame coordinates
/// and upright portrait coordinates.
///
/// In portrait-locked orientation, rotation corresponds directly to the camera
/// sensor orientation (0, 90, 180, or 270 degrees clockwise).
/// Camera frames are never mirrored in data; mirroring is exclusively a display
/// concern for preview rendering.
@immutable
class FrameGeometry {
  const FrameGeometry({
    required this.rawWidth,
    required this.rawHeight,
    required this.rotation,
  }) : assert(rawWidth > 0, 'rawWidth must be positive'),
       assert(rawHeight > 0, 'rawHeight must be positive'),
       assert(
         rotation == 0 || rotation == 90 || rotation == 180 || rotation == 270,
         'rotation must be one of 0, 90, 180, 270 degrees',
       );

  final int rawWidth;
  final int rawHeight;
  final int rotation;

  /// Width of the frame when oriented upright.
  int get uprightWidth =>
      (rotation == 90 || rotation == 270) ? rawHeight : rawWidth;

  /// Height of the frame when oriented upright.
  int get uprightHeight =>
      (rotation == 90 || rotation == 270) ? rawWidth : rawHeight;

  /// Affine transformation mapping upright coordinates to raw buffer coordinates.
  AffineMatrix get uprightToRaw {
    final double w = rawWidth.toDouble();
    final double h = rawHeight.toDouble();
    switch (rotation) {
      case 0:
        return AffineMatrix.identity;
      case 90:
        return AffineMatrix(a: 0.0, b: 1.0, tx: 0.0, c: -1.0, d: 0.0, ty: h);
      case 180:
        return AffineMatrix(a: -1.0, b: 0.0, tx: w, c: 0.0, d: -1.0, ty: h);
      case 270:
        return AffineMatrix(a: 0.0, b: -1.0, tx: w, c: 1.0, d: 0.0, ty: 0.0);
      default:
        return AffineMatrix.identity;
    }
  }

  /// Affine transformation mapping raw buffer coordinates to upright coordinates.
  AffineMatrix get rawToUpright {
    final double w = rawWidth.toDouble();
    final double h = rawHeight.toDouble();
    switch (rotation) {
      case 0:
        return AffineMatrix.identity;
      case 90:
        return AffineMatrix(a: 0.0, b: -1.0, tx: h, c: 1.0, d: 0.0, ty: 0.0);
      case 180:
        return AffineMatrix(a: -1.0, b: 0.0, tx: w, c: 0.0, d: -1.0, ty: h);
      case 270:
        return AffineMatrix(a: 0.0, b: 1.0, tx: 0.0, c: -1.0, d: 0.0, ty: w);
      default:
        return AffineMatrix.identity;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FrameGeometry &&
        other.rawWidth == rawWidth &&
        other.rawHeight == rawHeight &&
        other.rotation == rotation;
  }

  @override
  int get hashCode => Object.hash(rawWidth, rawHeight, rotation);

  @override
  String toString() =>
      'FrameGeometry(raw: ${rawWidth}x$rawHeight, upright: ${uprightWidth}x$uprightHeight, rotation: $rotation)';
}
