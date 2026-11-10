/// Active challenge types evaluated during liveness verification.
enum ChallengeType {
  /// Baseline neutral pose looking straight into the camera.
  lookStraight,

  /// Eye blink with natural open-closed-open hysteresis.
  blink,

  /// Head turn toward user's physical left.
  turnLeft,

  /// Head turn toward user's physical right.
  turnRight,

  /// Facial smile reaching required threshold.
  smile;

  /// Whether this challenge is the initial neutral calibration step.
  bool get isNeutral => this == ChallengeType.lookStraight;
}

/// Specific failure reasons for challenge state machine transitions.
enum ChallengeFailureReason {
  none,

  /// Face disappeared for longer than the permitted grace period.
  trackingLost,

  /// Detected face tracking ID changed during an active session.
  trackingChanged,

  /// Challenge was not completed within the allotted timeout window.
  timeout,

  /// User performed an action in the opposing direction (e.g. turned right when asked left).
  wrongDirection,

  /// Challenge was explicitly cancelled.
  cancelled,
}

/// Overall execution status of the active challenge state machine.
enum ChallengeMachineStatus {
  /// Machine has not yet started or is awaiting first face.
  idle,

  /// Actively processing frames and verifying challenge steps.
  inProgress,

  /// All required challenges in the sequence have passed.
  passed,

  /// Session failed due to timeout, tracking loss, or violation.
  failed,
}

/// Abstraction for face telemetry consumed by the challenge state machine.
///
/// Decouples challenge logic from platform-specific or Flutter framework models.
abstract interface class FaceSample {
  /// Unique tracking identifier assigned to the face.
  int? get trackingId;

  /// Head yaw rotation in degrees (left / right).
  double? get yaw;

  /// Head pitch rotation in degrees (up / down).
  double? get pitch;

  /// Head roll rotation in degrees (tilt sideways).
  double? get roll;

  /// Estimated probability that the left eye is open (0.0 to 1.0).
  double? get leftEyeOpenProbability;

  /// Estimated probability that the right eye is open (0.0 to 1.0).
  double? get rightEyeOpenProbability;

  /// Estimated probability that the face is smiling (0.0 to 1.0).
  double? get smilingProbability;
}

/// Detailed historical record of a single challenge execution.
class ChallengeRecord {
  const ChallengeRecord({
    required this.type,
    required this.startedAt,
    this.completedAt,
    required this.passed,
    required this.framesObserved,
    this.details,
  });

  final ChallengeType type;
  final DateTime startedAt;
  final DateTime? completedAt;
  final bool passed;
  final int framesObserved;
  final String? details;

  Duration? get duration => completedAt?.difference(startedAt);
}

/// Immediate result returned by [ChallengeStateMachine.update] per evaluated frame.
class ChallengeStepResult {
  const ChallengeStepResult({
    required this.status,
    this.currentChallenge,
    this.challengeIndex = 0,
    this.totalChallenges = 0,
    this.stepProgress = 0.0,
    this.overallProgress = 0.0,
    this.failureReason = ChallengeFailureReason.none,
    this.message,
  });

  final ChallengeMachineStatus status;
  final ChallengeType? currentChallenge;
  final int challengeIndex;
  final int totalChallenges;
  final double stepProgress;
  final double overallProgress;
  final ChallengeFailureReason failureReason;
  final String? message;

  bool get isPassed => status == ChallengeMachineStatus.passed;
  bool get isFailed => status == ChallengeMachineStatus.failed;
  bool get isInProgress => status == ChallengeMachineStatus.inProgress;
}
