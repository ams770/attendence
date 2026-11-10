import 'package:flutter/foundation.dart';

import '../../liveness/domain/passive_preprocess_config.dart';

/// Preprocessing configuration for face recognition embedding models (e.g. SFace).
@immutable
class RecognizerPreprocessConfig {
  const RecognizerPreprocessConfig({
    this.channelOrder = ChannelOrder.rgb,
    this.scale = 1.0,
    this.mean = const <double>[0.0, 0.0, 0.0],
    this.std = const <double>[1.0, 1.0, 1.0],
  });

  /// Channel ordering expected by the model input tensor (RGB by default for SFace).
  final ChannelOrder channelOrder;

  /// Multiplier applied to raw byte pixel values (1.0 for raw [0, 255] range).
  final double scale;

  /// Per-channel mean subtracted from scaled pixels: `(pixel * scale - mean) / std`.
  final List<double> mean;

  /// Per-channel standard deviation divisor.
  final List<double> std;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecognizerPreprocessConfig &&
        other.channelOrder == channelOrder &&
        other.scale == scale &&
        listEquals(other.mean, mean) &&
        listEquals(other.std, std);
  }

  @override
  int get hashCode => Object.hash(
    channelOrder,
    scale,
    Object.hashAll(mean),
    Object.hashAll(std),
  );
}
