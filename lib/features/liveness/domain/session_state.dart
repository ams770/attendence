part of 'liveness_session.dart';

/// Specific reasons why a verification session failed.
enum SessionFailureReason {
  /// Session or challenge exceeded its maximum allotted duration.
  timeout,

  /// Face tracking was lost for longer than the grace period.
  faceLost,

  /// Face tracking ID changed during an active session attempt.
  trackingChanged,

  /// User failed to complete an active challenge correctly or moved in the wrong direction.
  challengeFailed,

  /// Aggregated passive anti-spoofing score or passing ratio fell below required thresholds.
  passiveFailed,

  /// Rolling passive score dropped below hard floor during session (anti-substitution violation).
  passiveHardFloorViolation,

  /// Temporal consistency checks detected a static photograph or periodic video loop.
  temporalFailed,

  /// Screen color flash reflection did not exhibit expected chrominance shifts.
  flashFailed,

  /// Session was explicitly cancelled by the user.
  cancelled,

  /// Consecutive failure limit exceeded, triggering lockout.
  tooManyAttempts,
}

/// Base sealed class for all states in the liveness verification session lifecycle.
sealed class LivenessSessionState {
  const LivenessSessionState();

  /// Whether the session is currently in an active interactive state.
  bool get isActive =>
      this is SessionStatePositioning ||
      this is SessionStateNeutral ||
      this is SessionStateChallenge ||
      this is SessionStateFlash ||
      this is SessionStateFinalizing;

  /// Whether the session has concluded (succeeded, failed, or locked).
  bool get isCompleted =>
      this is SessionStateSucceeded ||
      this is SessionStateFailed ||
      this is SessionStateLocked;
}

/// The session has not yet started or has been reset.
class SessionStateIdle extends LivenessSessionState {
  const SessionStateIdle();
}

/// Initial phase: awaiting face detection, alignment within oval guide, and quality validation.
class SessionStatePositioning extends LivenessSessionState {
  const SessionStatePositioning();
}

/// Neutral calibration phase: verifying steady forward pose and non-smiling expression.
class SessionStateNeutral extends LivenessSessionState {
  const SessionStateNeutral();
}

/// Active challenge interaction phase: prompting user for an action (e.g. blink, turn, smile).
class SessionStateChallenge extends LivenessSessionState {
  const SessionStateChallenge({
    required this.index,
    required this.type,
    required this.totalChallenges,
    this.progress = 0.0,
  });

  /// Index of the current challenge in the active sequence (0-based).
  final int index;

  /// Type of active challenge currently requested.
  final ChallengeType type;

  /// Total number of active challenges in this session.
  final int totalChallenges;

  /// Estimated progress toward satisfying this challenge (0.0 to 1.0).
  final double progress;
}

/// Optional screen-color-flash reflection challenge phase.
class SessionStateFlash extends LivenessSessionState {
  const SessionStateFlash({
    required this.color,
    required this.dwellRemainingMs,
  });

  /// Active screen flash color currently displayed.
  final FlashColor color;

  /// Remaining display duration in milliseconds for this color.
  final int dwellRemainingMs;
}

/// Final phase: capturing candidate frontal crops and confirming passive stability.
class SessionStateFinalizing extends LivenessSessionState {
  const SessionStateFinalizing({this.collectedCrops = 0, this.targetCrops = 3});

  /// Number of valid candidate crops collected so far.
  final int collectedCrops;

  /// Target number of candidate crops required (default 3).
  final int targetCrops;
}

/// Verification succeeded: all liveness layers passed and crops are bound.
class SessionStateSucceeded extends LivenessSessionState {
  const SessionStateSucceeded({required this.result});

  /// Final session result containing metrics and verified live face crops.
  final LiveSessionResult result;
}

/// Verification failed: an error, timeout, or security violation occurred.
class SessionStateFailed extends LivenessSessionState {
  const SessionStateFailed({required this.reason, this.result});

  /// Specific failure reason.
  final SessionFailureReason reason;

  /// Detailed result telemetry if available.
  final LiveSessionResult? result;
}

/// Screen locked after exceeding consecutive failure limit.
class SessionStateLocked extends LivenessSessionState {
  const SessionStateLocked({
    required this.lockedUntil,
    required this.remainingSeconds,
  });

  /// Timestamp when lockout ends.
  final DateTime lockedUntil;

  /// Remaining lockout time in whole seconds.
  final int remainingSeconds;
}
