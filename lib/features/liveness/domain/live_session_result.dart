part of 'liveness_session.dart';

/// Comprehensive evaluation result produced at the end of a verification session.
class LiveSessionResult {
  const LiveSessionResult({
    required this.passed,
    this.failureReason,
    required this.meanPassiveScore,
    required this.framesAboveThreshold,
    required this.totalPassiveSamples,
    required this.perModelScores,
    required this.challengeResults,
    required this.temporalConfidence,
    this.flashResult,
    this.trackingId,
    required this.deviceTier,
    this.verifiedFaces,
    required this.duration,
    required this.startedAt,
    required this.completedAt,
    required this.attemptLog,
  });

  /// Whether the session passed every required liveness layer.
  final bool passed;

  /// Specific failure reason if [passed] is false.
  final SessionFailureReason? failureReason;

  /// Mean real probability score across all passive evaluations.
  final double meanPassiveScore;

  /// Number of evaluated passive frames meeting or exceeding the passive threshold.
  final int framesAboveThreshold;

  /// Total number of passive frames evaluated.
  final int totalPassiveSamples;

  /// Average scores per individual passive model (e.g. MiniFASNetV2, MiniFASNetV1SE).
  final Map<String, double> perModelScores;

  /// Historical records of active challenges attempted during the session.
  final List<ChallengeRecord> challengeResults;

  /// Combined temporal confidence score (micro-motion, loops, 3D rigidity).
  final double temporalConfidence;

  /// Result of optional screen color flash evaluation (null if disabled or skipped).
  final FlashEvaluationResult? flashResult;

  /// Face tracking identifier validated during the session.
  final int? trackingId;

  /// Device hardware tier classified at session execution.
  final DeviceTier deviceTier;

  /// Verified live face crops produced strictly by a succeeded session.
  final VerifiedLiveFaces? verifiedFaces;

  /// Total elapsed duration of the session.
  final Duration duration;

  /// Timestamp when the session began.
  final DateTime startedAt;

  /// Timestamp when the session completed.
  final DateTime completedAt;

  /// Non-biometric audit log entry summarizing the session attempt.
  final AttemptLog attemptLog;
}
