import 'package:flutter/foundation.dart';

/// Supported channel ordering formats for neural network image inputs.
enum ChannelOrder { bgr, rgb }

/// Supported preprocessing variants for diagnostic evaluation.
enum PreprocessVariant {
  bgrRaw255('bgr_raw_255', 'BGR raw 0-255'),
  bgr01('bgr_0_1', 'BGR 0-1'),
  rgbRaw255('rgb_raw_255', 'RGB raw 0-255'),
  rgb01('rgb_0_1', 'RGB 0-1'),
  rgbImageNet('rgb_imagenet', 'RGB ImageNet mean/std');

  const PreprocessVariant(this.id, this.displayName);

  final String id;
  final String displayName;

  PassivePreprocessConfig applyTo(PassivePreprocessConfig base) {
    switch (this) {
      case PreprocessVariant.bgrRaw255:
        return base.copyWith(
          channelOrder: ChannelOrder.bgr,
          scale: 1.0,
          mean: const <double>[0.0, 0.0, 0.0],
          std: const <double>[1.0, 1.0, 1.0],
        );
      case PreprocessVariant.bgr01:
        return base.copyWith(
          channelOrder: ChannelOrder.bgr,
          scale: 1.0 / 255.0,
          mean: const <double>[0.0, 0.0, 0.0],
          std: const <double>[1.0, 1.0, 1.0],
        );
      case PreprocessVariant.rgbRaw255:
        return base.copyWith(
          channelOrder: ChannelOrder.rgb,
          scale: 1.0,
          mean: const <double>[0.0, 0.0, 0.0],
          std: const <double>[1.0, 1.0, 1.0],
        );
      case PreprocessVariant.rgb01:
        return base.copyWith(
          channelOrder: ChannelOrder.rgb,
          scale: 1.0 / 255.0,
          mean: const <double>[0.0, 0.0, 0.0],
          std: const <double>[1.0, 1.0, 1.0],
        );
      case PreprocessVariant.rgbImageNet:
        return base.copyWith(
          channelOrder: ChannelOrder.rgb,
          scale: 1.0 / 255.0,
          mean: const <double>[0.485, 0.456, 0.406],
          std: const <double>[0.229, 0.224, 0.225],
        );
    }
  }
}

/// Immutable configuration controlling how face crops are preprocessed and
/// mapped to input tensors for passive anti-spoofing models (MiniFASNet).
@immutable
class PassivePreprocessConfig {
  const PassivePreprocessConfig({
    this.channelOrder = ChannelOrder.bgr,
    this.scale = 1.0,
    this.mean = const <double>[0.0, 0.0, 0.0],
    this.std = const <double>[1.0, 1.0, 1.0],
    this.realClassIndex = 1,
    this.applySoftmax = true,
    this.v2CropScale = 2.7,
    this.v1SeCropScale = 4.0,
    this.boxExpansion = 1.0,
    this.inputWidth = 80,
    this.inputHeight = 80,
  });

  /// Channel ordering fed to the model: BGR (original Silent-Face) or RGB.
  final ChannelOrder channelOrder;

  /// Multiplier applied to raw [0, 255] byte pixels (e.g. 1.0 or 1.0 / 255.0).
  final double scale;

  /// Per-channel mean subtracted after scaling: (pixel * scale - mean) / std.
  final List<double> mean;

  /// Per-channel standard deviation divisor: (pixel * scale - mean) / std.
  final List<double> std;

  /// Index of the real / live class in the model output (original Silent-Face: 1).
  final int realClassIndex;

  /// Whether the raw model outputs are logits requiring softmax activation.
  final bool applySoftmax;

  /// Face bounding box crop scale for MiniFASNetV2 (original: 2.7).
  final double v2CropScale;

  /// Face bounding box crop scale for MiniFASNetV1SE (original: 4.0).
  final double v1SeCropScale;

  /// Detector box expansion multiplier applied before scaling (default: 1.0).
  final double boxExpansion;

  /// Width of the input tensor required by the model.
  final int inputWidth;

  /// Height of the input tensor required by the model.
  final int inputHeight;

  PassivePreprocessConfig copyWith({
    ChannelOrder? channelOrder,
    double? scale,
    List<double>? mean,
    List<double>? std,
    int? realClassIndex,
    bool? applySoftmax,
    double? v2CropScale,
    double? v1SeCropScale,
    double? boxExpansion,
    int? inputWidth,
    int? inputHeight,
  }) {
    return PassivePreprocessConfig(
      channelOrder: channelOrder ?? this.channelOrder,
      scale: scale ?? this.scale,
      mean: mean ?? this.mean,
      std: std ?? this.std,
      realClassIndex: realClassIndex ?? this.realClassIndex,
      applySoftmax: applySoftmax ?? this.applySoftmax,
      v2CropScale: v2CropScale ?? this.v2CropScale,
      v1SeCropScale: v1SeCropScale ?? this.v1SeCropScale,
      boxExpansion: boxExpansion ?? this.boxExpansion,
      inputWidth: inputWidth ?? this.inputWidth,
      inputHeight: inputHeight ?? this.inputHeight,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PassivePreprocessConfig &&
        other.channelOrder == channelOrder &&
        other.scale == scale &&
        listEquals(other.mean, mean) &&
        listEquals(other.std, std) &&
        other.realClassIndex == realClassIndex &&
        other.applySoftmax == applySoftmax &&
        other.v2CropScale == v2CropScale &&
        other.v1SeCropScale == v1SeCropScale &&
        other.boxExpansion == boxExpansion &&
        other.inputWidth == inputWidth &&
        other.inputHeight == inputHeight;
  }

  @override
  int get hashCode => Object.hash(
    channelOrder,
    scale,
    Object.hashAll(mean),
    Object.hashAll(std),
    realClassIndex,
    applySoftmax,
    v2CropScale,
    v1SeCropScale,
    boxExpansion,
    inputWidth,
    inputHeight,
  );
}
