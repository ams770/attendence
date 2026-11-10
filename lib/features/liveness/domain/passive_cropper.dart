import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../../core/utils/affine_matrix.dart';
import '../../camera/domain/frame_data.dart';
import '../../camera/domain/frame_geometry.dart';
import '../../ml/sampler/pixel_sampler.dart';

/// Implements scaled facial cropping with scale reduction and boundary shifting
/// matching the Silent-Face-Anti-Spoofing reference methodology.
class PassiveCropper {
  const PassiveCropper({this.sampler = const PixelSampler()});

  final PixelSampler sampler;

  /// Computes the bounding rectangle for a passive liveness crop in upright coordinates.
  ///
  /// Expands [faceBox] by [boxExpansion] (default 1.0).
  /// Scales the box by [cropScale] (e.g. 2.7 for V2, 4.0 for V1SE).
  /// If the scaled box would exceed [srcW] x [srcH], scale is reduced to fit.
  /// Shifts the box inside the image boundaries without stretching or altering aspect ratio.
  Rect computeCropRect({
    required Rect faceBox,
    required int srcW,
    required int srcH,
    required double cropScale,
    double boxExpansion = 1.0,
  }) {
    final Rect box = boxExpansion != 1.0
        ? Rect.fromCenter(
            center: faceBox.center,
            width: faceBox.width * boxExpansion,
            height: faceBox.height * boxExpansion,
          )
        : faceBox;

    final double boxW = box.width <= 0 ? 1.0 : box.width;
    final double boxH = box.height <= 0 ? 1.0 : box.height;

    final double maxW = srcW > 1 ? (srcW - 1).toDouble() : 1.0;
    final double maxH = srcH > 1 ? (srcH - 1).toDouble() : 1.0;

    final double maxScaleX = maxW / boxW;
    final double maxScaleY = maxH / boxH;
    final double effectiveScale = math.min(
      cropScale,
      math.min(maxScaleX, maxScaleY),
    );

    final double newW = boxW * effectiveScale;
    final double newH = boxH * effectiveScale;
    final double centerX = box.left + boxW / 2.0;
    final double centerY = box.top + boxH / 2.0;

    double left = centerX - newW / 2.0;
    double top = centerY - newH / 2.0;
    double right = centerX + newW / 2.0;
    double bottom = centerY + newH / 2.0;

    // Shift inside boundaries without stretching
    if (left < 0) {
      right -= left;
      left = 0.0;
    }
    if (top < 0) {
      bottom -= top;
      top = 0.0;
    }
    if (right > maxW) {
      left -= (right - maxW);
      right = maxW;
    }
    if (bottom > maxH) {
      top -= (bottom - maxH);
      bottom = maxH;
    }

    // Secondary clamp if image dimensions are smaller than scaled box
    if (left < 0) left = 0.0;
    if (top < 0) top = 0.0;
    if (right > maxW) right = maxW;
    if (bottom > maxH) bottom = maxH;

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Produces an affine matrix mapping upright coordinates inside [cropRect]
  /// to output coordinates [0, outW] x [0, outH].
  AffineMatrix computeUprightToCropTransform({
    required Rect cropRect,
    int outW = 80,
    int outH = 80,
  }) {
    final double w = cropRect.width <= 0 ? 1.0 : cropRect.width;
    final double h = cropRect.height <= 0 ? 1.0 : cropRect.height;
    final double scaleX = outW / w;
    final double scaleY = outH / h;

    return AffineMatrix(
      a: scaleX,
      b: 0.0,
      c: 0.0,
      d: scaleY,
      tx: -cropRect.left * scaleX,
      ty: -cropRect.top * scaleY,
    );
  }

  /// Extracts an 80x80 RGB crop directly from [frame] using [computeCropRect]
  /// and [PixelSampler.warpAffine].
  Uint8List cropRgb({
    required FrameData frame,
    required Rect faceBox,
    required double cropScale,
    double boxExpansion = 1.0,
    int outW = 80,
    int outH = 80,
    Uint8List? outBuffer,
  }) {
    final FrameGeometry geometry = FrameGeometry(
      rawWidth: frame.width,
      rawHeight: frame.height,
      rotation: frame.sensorRotation,
    );
    final int uprightW = geometry.uprightWidth;
    final int uprightH = geometry.uprightHeight;

    final Rect cropRect = computeCropRect(
      faceBox: faceBox,
      srcW: uprightW,
      srcH: uprightH,
      cropScale: cropScale,
      boxExpansion: boxExpansion,
    );

    final AffineMatrix transform = computeUprightToCropTransform(
      cropRect: cropRect,
      outW: outW,
      outH: outH,
    );

    return sampler.warpAffine(
      frame,
      transform,
      outW,
      outH,
      outBuffer: outBuffer,
    );
  }
}
