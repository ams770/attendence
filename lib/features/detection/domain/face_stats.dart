import 'package:flutter/foundation.dart';

/// Face image quality statistics computed on a grayscale face crop.
@immutable
class FaceStats {
  const FaceStats({
    required this.sharpness,
    required this.meanBrightness,
    required this.nearSaturatedRatio,
  });

  /// Laplacian variance measuring image sharpness / blur. Higher means sharper.
  final double sharpness;

  /// Mean grayscale luminance (0 to 255).
  final double meanBrightness;

  /// Fraction of pixels with luminance >= 250 (glare / overexposure). Range 0.0 to 1.0.
  final double nearSaturatedRatio;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FaceStats &&
        other.sharpness == sharpness &&
        other.meanBrightness == meanBrightness &&
        other.nearSaturatedRatio == nearSaturatedRatio;
  }

  @override
  int get hashCode =>
      Object.hash(sharpness, meanBrightness, nearSaturatedRatio);

  @override
  String toString() =>
      'FaceStats(sharpness: ${sharpness.toStringAsFixed(1)}, brightness: ${meanBrightness.toStringAsFixed(1)}, glare: ${(nearSaturatedRatio * 100).toStringAsFixed(1)}%)';
}
