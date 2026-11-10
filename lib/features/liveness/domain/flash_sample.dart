import 'flash_color.dart';

/// Mean color measurement sampled from facial skin regions in a camera frame.
class SkinColorSample {
  const SkinColorSample({
    required this.meanR,
    required this.meanG,
    required this.meanB,
    required this.brightness,
    required this.timestamp,
  });

  final double meanR;
  final double meanG;
  final double meanB;
  final double brightness;
  final DateTime timestamp;
}

/// Record pairing a displayed screen flash color with measured skin reflection.
class FlashStepRecord {
  const FlashStepRecord({required this.color, required this.sample});

  final FlashColor color;
  final SkinColorSample sample;
}
