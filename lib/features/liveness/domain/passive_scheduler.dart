import 'dart:math' as math;

/// Phases of an interactive verification session.
enum SessionPhase {
  /// Initial face alignment and quality stabilization phase.
  neutral,

  /// Active liveness challenge interaction phase.
  challenge,

  /// Final stabilization and recognition phase.
  finalPhase,
}

/// Schedules frame sampling across verification session phases to guarantee that
/// passive liveness evaluation samples are distributed throughout the interaction
/// rather than clustered in the first few frames.
class PassiveScheduler {
  PassiveScheduler({
    required this.targetTotalSamples,
    this.minSampleInterval = const Duration(milliseconds: 300),
    this.neutralRatio = 0.25,
    this.challengeRatio = 0.50,
    this.finalRatio = 0.25,
  }) : assert(targetTotalSamples >= 3, 'targetTotalSamples must be at least 3');

  /// Total target number of passive frame samples for the entire session.
  final int targetTotalSamples;

  /// Minimum time that must elapse between any two sampled frames.
  final Duration minSampleInterval;

  final double neutralRatio;
  final double challengeRatio;
  final double finalRatio;

  final Map<SessionPhase, int> _phaseSampleCounts = <SessionPhase, int>{
    SessionPhase.neutral: 0,
    SessionPhase.challenge: 0,
    SessionPhase.finalPhase: 0,
  };

  Duration? _lastSampleTotalElapsed;
  int _totalSamplesRecorded = 0;

  /// Total number of samples recorded across all phases.
  int get totalSamplesRecorded => _totalSamplesRecorded;

  /// Number of samples recorded for [phase].
  int sampleCountForPhase(SessionPhase phase) => _phaseSampleCounts[phase] ?? 0;

  /// Allocated target sample quota for [phase].
  int targetForPhase(SessionPhase phase) {
    switch (phase) {
      case SessionPhase.neutral:
        return math.max(1, (targetTotalSamples * neutralRatio).round());
      case SessionPhase.finalPhase:
        return math.max(1, (targetTotalSamples * finalRatio).round());
      case SessionPhase.challenge:
        final int n = math.max(1, (targetTotalSamples * neutralRatio).round());
        final int f = math.max(1, (targetTotalSamples * finalRatio).round());
        return math.max(1, targetTotalSamples - n - f);
    }
  }

  /// Determines whether a frame should be sampled given current session progress.
  bool shouldSample({
    required SessionPhase phase,
    required Duration phaseElapsed,
    required Duration totalElapsed,
  }) {
    // Check if the current phase has reached its target quota
    final int phaseCount = _phaseSampleCounts[phase] ?? 0;
    if (phaseCount >= targetForPhase(phase)) {
      return false;
    }

    // Check if total session quota is already met
    if (_totalSamplesRecorded >= targetTotalSamples) {
      return false;
    }

    // Enforce minimum time interval between consecutive samples
    if (_lastSampleTotalElapsed != null) {
      final Duration elapsedSinceLast = totalElapsed - _lastSampleTotalElapsed!;
      if (elapsedSinceLast < minSampleInterval) {
        return false;
      }
    }

    return true;
  }

  /// Records that a sample was successfully taken.
  void recordSample({
    required SessionPhase phase,
    required Duration totalElapsed,
  }) {
    _phaseSampleCounts[phase] = (_phaseSampleCounts[phase] ?? 0) + 1;
    _totalSamplesRecorded++;
    _lastSampleTotalElapsed = totalElapsed;
  }

  /// Resets scheduler state for a new session.
  void reset() {
    _phaseSampleCounts[SessionPhase.neutral] = 0;
    _phaseSampleCounts[SessionPhase.challenge] = 0;
    _phaseSampleCounts[SessionPhase.finalPhase] = 0;
    _totalSamplesRecorded = 0;
    _lastSampleTotalElapsed = null;
  }
}
