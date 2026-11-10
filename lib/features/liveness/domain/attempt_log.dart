/// Detailed, non-biometric audit log entry of a verification session attempt.
///
/// Contains zero biometric templates, embeddings, or face images to protect user privacy.
class AttemptLog {
  const AttemptLog({
    required this.attemptId,
    required this.timestamp,
    required this.policy,
    required this.passed,
    this.failureReason,
    required this.durationMs,
    required this.meanPassiveScore,
    required this.passiveSamplesCount,
    required this.passivePassingRatio,
    required this.perModelScores,
    required this.temporalConfidence,
    required this.microMotionScore,
    required this.loopScore,
    required this.rigidityScore,
    this.flashPassed,
    this.flashCorrelation,
    required this.deviceTier,
    required this.challengesCompleted,
    this.trackingId,
  });

  /// Unique identifier for this verification attempt.
  final String attemptId;

  /// Start timestamp of the session attempt.
  final DateTime timestamp;

  /// Verification policy used ('attendance' or 'enrollment').
  final String policy;

  /// Whether the session successfully verified liveness.
  final bool passed;

  /// Failure reason identifier if the session did not succeed.
  final String? failureReason;

  /// Total duration of the session attempt in milliseconds.
  final int durationMs;

  /// Mean probability score across all passive anti-spoofing evaluations.
  final double meanPassiveScore;

  /// Total number of passive frames evaluated.
  final int passiveSamplesCount;

  /// Ratio of passive frames that met or exceeded the passive threshold.
  final double passivePassingRatio;

  /// Mean scores per individual passive model.
  final Map<String, double> perModelScores;

  /// Combined temporal confidence score (0.0 to 1.0).
  final double temporalConfidence;

  /// Micro-motion consistency score.
  final double microMotionScore;

  /// Video loop detection score.
  final double loopScore;

  /// 3D planar depth parallax rigidity score.
  final double rigidityScore;

  /// Whether the optional screen flash reflection test passed (null if skipped/disabled).
  final bool? flashPassed;

  /// Measured Pearson correlation coefficient for screen flash reflection.
  final double? flashCorrelation;

  /// Effective hardware tier during execution ('low', 'mid', 'high').
  final String deviceTier;

  /// Names of active challenges successfully completed during the session.
  final List<String> challengesCompleted;

  /// Transient face tracking identifier assigned during the session.
  final int? trackingId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'attemptId': attemptId,
    'timestamp': timestamp.toIso8601String(),
    'policy': policy,
    'passed': passed,
    'failureReason': failureReason,
    'durationMs': durationMs,
    'meanPassiveScore': meanPassiveScore,
    'passiveSamplesCount': passiveSamplesCount,
    'passivePassingRatio': passivePassingRatio,
    'perModelScores': perModelScores,
    'temporalConfidence': temporalConfidence,
    'microMotionScore': microMotionScore,
    'loopScore': loopScore,
    'rigidityScore': rigidityScore,
    'flashPassed': flashPassed,
    'flashCorrelation': flashCorrelation,
    'deviceTier': deviceTier,
    'challengesCompleted': challengesCompleted,
    'trackingId': trackingId,
  };
}
