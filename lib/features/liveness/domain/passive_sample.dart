import 'package:flutter/foundation.dart';

/// Predefined evaluation scenario labels for diagnostic capture.
enum EvalScenario {
  liveFace('live_face', 'Live Face'),
  videoOnPhoneFullframe(
    'video_on_phone_fullframe',
    'Video on Phone (Full Frame)',
  ),
  videoOnPhoneBezelVisible(
    'video_on_phone_bezel_visible',
    'Video on Phone (Bezel Visible)',
  ),
  photoOnPhone('photo_on_phone', 'Photo on Phone'),
  printedPhoto('printed_photo', 'Printed Photo'),
  other('other', 'Other');

  const EvalScenario(this.id, this.displayName);

  final String id;
  final String displayName;
}

/// Recorded passive liveness score sample for a single camera frame.
@immutable
class PassiveSample {
  const PassiveSample({
    required this.timestamp,
    required this.meanScore,
    required this.modelScores,
    required this.latencyMs,
    this.scenarioLabel,
    this.boxExpansion,
    this.preprocessVariant,
    this.boxWidthRatio,
    this.boxHeightRatio,
    this.modelLogits,
    this.modelSoftmaxProbs,
    this.modelLatencies,
  });

  /// Precise wall-clock timestamp when the sample was recorded.
  final DateTime timestamp;

  /// Mean real probability score across models evaluated for this frame.
  final double meanScore;

  /// Individual real probability scores per model name.
  final Map<String, double> modelScores;

  /// Combined inference latency in milliseconds.
  final double latencyMs;

  /// Scenario label assigned during evaluation (e.g. live_face, video_on_phone_fullframe).
  final String? scenarioLabel;

  /// Face box expansion factor applied for this sample (e.g. 1.0).
  final double? boxExpansion;

  /// Preprocessing variant applied (e.g. bgr_raw_255).
  final String? preprocessVariant;

  /// Face bounding box width relative to upright image width.
  final double? boxWidthRatio;

  /// Face bounding box height relative to upright image height.
  final double? boxHeightRatio;

  /// Raw model logits per model name.
  final Map<String, List<double>>? modelLogits;

  /// Full softmax probability distributions per model name.
  final Map<String, List<double>>? modelSoftmaxProbs;

  /// Individual model execution latency in milliseconds.
  final Map<String, double>? modelLatencies;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PassiveSample &&
        other.timestamp == timestamp &&
        other.meanScore == meanScore &&
        mapEquals(other.modelScores, modelScores) &&
        other.latencyMs == latencyMs &&
        other.scenarioLabel == scenarioLabel &&
        other.boxExpansion == boxExpansion &&
        other.preprocessVariant == preprocessVariant;
  }

  @override
  int get hashCode => Object.hash(
    timestamp,
    meanScore,
    Object.hashAll(modelScores.entries),
    latencyMs,
    scenarioLabel,
    boxExpansion,
    preprocessVariant,
  );
}
