import '../../../core/utils/clock.dart';
import 'challenge_config.dart';
import 'challenge_type.dart';

enum _BlinkPhase { awaitingInitialOpen, awaitingClosed, awaitingReopen }

enum _TurnPhase { awaitingCenter, turning }

enum _SmilePhase { awaitingNeutral, smiling }

/// Strict, event-driven active challenge state machine.
///
/// Evaluates sequential facial movement challenges using timestamps and
/// telemetry from an injected [Clock] and [ChallengeConfig].
/// Implemented entirely in pure Dart without Flutter UI dependencies.
class ChallengeStateMachine {
  ChallengeStateMachine({
    required this.clock,
    required List<ChallengeType> challenges,
    this.config = const ChallengeConfig(),
  }) : _challenges = List<ChallengeType>.unmodifiable(challenges) {
    if (_challenges.isEmpty) {
      throw ArgumentError.value(
        challenges,
        'challenges',
        'Challenge sequence cannot be empty',
      );
    }
  }

  /// System clock abstraction used for deterministic timing.
  final Clock clock;

  /// Active challenge configuration parameters.
  final ChallengeConfig config;

  final List<ChallengeType> _challenges;

  ChallengeMachineStatus _status = ChallengeMachineStatus.idle;
  ChallengeFailureReason _failureReason = ChallengeFailureReason.none;

  int _currentIndex = 0;
  DateTime? _sessionStartTime;
  DateTime? _challengeStartTime;
  DateTime? _lostSince;
  int? _initialTrackingId;

  double _baselineYaw = 0.0;
  int _consecutiveFrames = 0;
  int _framesObservedInCurrent = 0;

  _BlinkPhase _blinkPhase = _BlinkPhase.awaitingInitialOpen;
  _TurnPhase _turnPhase = _TurnPhase.awaitingCenter;
  _SmilePhase _smilePhase = _SmilePhase.awaitingNeutral;

  final List<ChallengeRecord> _completedChallenges = <ChallengeRecord>[];

  /// Current overall execution status.
  ChallengeMachineStatus get status => _status;

  /// Specific failure reason if [status] is [ChallengeMachineStatus.failed].
  ChallengeFailureReason get failureReason => _failureReason;

  /// Complete sequence of challenges assigned to this session.
  List<ChallengeType> get challenges => _challenges;

  /// Index of the current challenge being evaluated.
  int get currentChallengeIndex => _currentIndex;

  /// The active challenge currently being evaluated, or null if finished.
  ChallengeType? get currentChallenge =>
      _status == ChallengeMachineStatus.inProgress &&
          _currentIndex < _challenges.length
      ? _challenges[_currentIndex]
      : null;

  /// List of completed challenge records with execution timestamps.
  List<ChallengeRecord> get completedChallenges =>
      List<ChallengeRecord>.unmodifiable(_completedChallenges);

  /// Established neutral baseline yaw angle in degrees.
  double get baselineYaw => _baselineYaw;

  /// Number of consecutive valid frames held in current sub-phase.
  int get consecutiveFrames => _consecutiveFrames;

  /// Time elapsed since the current challenge started.
  Duration get currentChallengeElapsed {
    if (_challengeStartTime == null) return Duration.zero;
    return clock.now().difference(_challengeStartTime!);
  }

  /// Whether the current challenge has exceeded [ChallengeConfig.perChallengeTimeout].
  bool get isCurrentChallengeTimedOut {
    if (_status != ChallengeMachineStatus.inProgress) return false;
    return currentChallengeElapsed > config.perChallengeTimeout;
  }

  /// Starts the state machine into active evaluation.
  void start() {
    _status = ChallengeMachineStatus.inProgress;
    _failureReason = ChallengeFailureReason.none;
    _currentIndex = 0;
    _sessionStartTime = clock.now();
    _challengeStartTime = _sessionStartTime;
    _lostSince = null;
    _initialTrackingId = null;
    _consecutiveFrames = 0;
    _framesObservedInCurrent = 0;
    _completedChallenges.clear();
    _resetSubPhases();
  }

  /// Resets the state machine to idle state.
  void reset() {
    _status = ChallengeMachineStatus.idle;
    _failureReason = ChallengeFailureReason.none;
    _currentIndex = 0;
    _sessionStartTime = null;
    _challengeStartTime = null;
    _lostSince = null;
    _initialTrackingId = null;
    _consecutiveFrames = 0;
    _framesObservedInCurrent = 0;
    _completedChallenges.clear();
    _resetSubPhases();
  }

  /// Updates state with a new frame telemetry sample.
  ChallengeStepResult update(FaceSample? face) {
    if (_status == ChallengeMachineStatus.idle) {
      start();
    }

    if (_status == ChallengeMachineStatus.passed ||
        _status == ChallengeMachineStatus.failed) {
      return _buildResult();
    }

    final DateTime now = clock.now();

    // 1. Timeout Check
    if (_challengeStartTime != null &&
        now.difference(_challengeStartTime!) > config.perChallengeTimeout) {
      _fail(ChallengeFailureReason.timeout, 'Challenge timed out');
      return _buildResult();
    }

    // 2. Face Presence & Tracking ID Continuity Check
    if (face == null) {
      _lostSince ??= now;
      if (now.difference(_lostSince!) > config.faceLostGracePeriod) {
        _fail(
          ChallengeFailureReason.trackingLost,
          'Face lost longer than grace period',
        );
      }
      return _buildResult();
    }

    _lostSince = null;

    if (face.trackingId != null) {
      if (_initialTrackingId == null) {
        _initialTrackingId = face.trackingId;
      } else if (face.trackingId != _initialTrackingId) {
        _fail(
          ChallengeFailureReason.trackingChanged,
          'Face tracking ID changed',
        );
        return _buildResult();
      }
    }

    _framesObservedInCurrent++;

    // 3. Process current challenge
    final ChallengeType current = _challenges[_currentIndex];
    switch (current) {
      case ChallengeType.lookStraight:
        _processLookStraight(face);
      case ChallengeType.blink:
        _processBlink(face);
      case ChallengeType.turnLeft:
      case ChallengeType.turnRight:
        _processTurn(face, current);
      case ChallengeType.smile:
        _processSmile(face);
    }

    return _buildResult();
  }

  void _processLookStraight(FaceSample face) {
    final double yaw = face.yaw ?? 0.0;
    final double pitch = face.pitch ?? 0.0;
    final double roll = face.roll ?? 0.0;

    final bool isYawValid = yaw.abs() <= config.neutralMaxYaw;
    final bool isPitchValid = pitch.abs() <= config.neutralMaxPitch;
    final bool isRollValid = roll.abs() <= config.neutralMaxRoll;
    final bool isEyesOpen =
        (face.leftEyeOpenProbability ?? 1.0) >=
            config.neutralEyeOpenThreshold &&
        (face.rightEyeOpenProbability ?? 1.0) >= config.neutralEyeOpenThreshold;
    final bool isNotSmiling =
        (face.smilingProbability ?? 0.0) <= config.neutralSmileFloorThreshold;

    if (isYawValid &&
        isPitchValid &&
        isRollValid &&
        isEyesOpen &&
        isNotSmiling) {
      _consecutiveFrames++;
      if (_consecutiveFrames >= config.neutralMinFrames) {
        _baselineYaw = yaw;
        _advanceChallenge();
      }
    } else {
      _consecutiveFrames = 0;
    }
  }

  void _processBlink(FaceSample face) {
    final double leftEye = face.leftEyeOpenProbability ?? 1.0;
    final double rightEye = face.rightEyeOpenProbability ?? 1.0;
    final bool isOpen =
        leftEye >= config.blinkEyeOpenThreshold &&
        rightEye >= config.blinkEyeOpenThreshold;
    final bool isClosed =
        leftEye <= config.blinkEyeClosedThreshold &&
        rightEye <= config.blinkEyeClosedThreshold;

    switch (_blinkPhase) {
      case _BlinkPhase.awaitingInitialOpen:
        if (isOpen) {
          _consecutiveFrames++;
          if (_consecutiveFrames >= config.blinkMinOpenFrames) {
            _blinkPhase = _BlinkPhase.awaitingClosed;
            _consecutiveFrames = 0;
          }
        } else {
          _consecutiveFrames = 0;
        }

      case _BlinkPhase.awaitingClosed:
        if (isClosed) {
          _consecutiveFrames++;
          if (_consecutiveFrames >= config.blinkMinClosedFrames) {
            _blinkPhase = _BlinkPhase.awaitingReopen;
            _consecutiveFrames = 0;
          }
        } else if (isOpen) {
          // Reset if eyes stay open
          _consecutiveFrames = 0;
        }

      case _BlinkPhase.awaitingReopen:
        if (isOpen) {
          _consecutiveFrames++;
          if (_consecutiveFrames >= config.blinkMinOpenFrames) {
            _advanceChallenge();
          }
        } else if (isClosed) {
          _consecutiveFrames = 0;
        }
    }
  }

  void _processTurn(FaceSample face, ChallengeType turnType) {
    final double yaw = face.yaw ?? 0.0;
    final double relYaw = (yaw - _baselineYaw) * config.yawSignForUserLeft;

    switch (_turnPhase) {
      case _TurnPhase.awaitingCenter:
        if ((yaw - _baselineYaw).abs() <= config.turnStartMaxYaw) {
          _turnPhase = _TurnPhase.turning;
          _consecutiveFrames = 0;
        }

      case _TurnPhase.turning:
        final bool isTurnLeft = turnType == ChallengeType.turnLeft;

        // Check opposing wrong direction: if asked left and turning heavily right, reset
        if (isTurnLeft && relYaw <= -15.0) {
          _consecutiveFrames = 0;
          return;
        } else if (!isTurnLeft && relYaw >= 15.0) {
          _consecutiveFrames = 0;
          return;
        }

        final double targetThreshold = _consecutiveFrames > 0
            ? (config.turnYawThreshold - config.turnHysteresis)
            : config.turnYawThreshold;

        final bool isSatisfied = isTurnLeft
            ? (relYaw >= targetThreshold)
            : (relYaw <= -targetThreshold);

        if (isSatisfied) {
          _consecutiveFrames++;
          if (_consecutiveFrames >= config.turnMinFrames) {
            _advanceChallenge();
          }
        } else {
          _consecutiveFrames = 0;
        }
    }
  }

  void _processSmile(FaceSample face) {
    final double smileProb = face.smilingProbability ?? 0.0;

    switch (_smilePhase) {
      case _SmilePhase.awaitingNeutral:
        if (smileProb <= config.smileFloorThreshold) {
          _smilePhase = _SmilePhase.smiling;
          _consecutiveFrames = 0;
        }

      case _SmilePhase.smiling:
        if (smileProb >= config.smileThreshold) {
          _consecutiveFrames++;
          if (_consecutiveFrames >= config.smileMinFrames) {
            _advanceChallenge();
          }
        } else {
          _consecutiveFrames = 0;
        }
    }
  }

  void _advanceChallenge() {
    final ChallengeType completedType = _challenges[_currentIndex];
    final DateTime now = clock.now();

    _completedChallenges.add(
      ChallengeRecord(
        type: completedType,
        startedAt: _challengeStartTime!,
        completedAt: now,
        passed: true,
        framesObserved: _framesObservedInCurrent,
      ),
    );

    _currentIndex++;
    _consecutiveFrames = 0;
    _framesObservedInCurrent = 0;
    _challengeStartTime = now;
    _resetSubPhases();

    if (_currentIndex >= _challenges.length) {
      _status = ChallengeMachineStatus.passed;
    }
  }

  void _fail(ChallengeFailureReason reason, String message) {
    _status = ChallengeMachineStatus.failed;
    _failureReason = reason;

    if (_currentIndex < _challenges.length && _challengeStartTime != null) {
      _completedChallenges.add(
        ChallengeRecord(
          type: _challenges[_currentIndex],
          startedAt: _challengeStartTime!,
          completedAt: clock.now(),
          passed: false,
          framesObserved: _framesObservedInCurrent,
          details: message,
        ),
      );
    }
  }

  void _resetSubPhases() {
    _blinkPhase = _BlinkPhase.awaitingInitialOpen;
    _turnPhase = _TurnPhase.awaitingCenter;
    _smilePhase = _SmilePhase.awaitingNeutral;
  }

  double _calculateStepProgress() {
    if (_status == ChallengeMachineStatus.passed) return 1.0;
    if (_status != ChallengeMachineStatus.inProgress) return 0.0;
    if (_currentIndex >= _challenges.length) return 1.0;

    final ChallengeType current = _challenges[_currentIndex];
    switch (current) {
      case ChallengeType.lookStraight:
        return (_consecutiveFrames / config.neutralMinFrames).clamp(0.0, 1.0);

      case ChallengeType.blink:
        switch (_blinkPhase) {
          case _BlinkPhase.awaitingInitialOpen:
            return 0.1;
          case _BlinkPhase.awaitingClosed:
            final double p = (_consecutiveFrames / config.blinkMinClosedFrames)
                .clamp(0.0, 1.0);
            return 0.2 + 0.4 * p;
          case _BlinkPhase.awaitingReopen:
            final double p = (_consecutiveFrames / config.blinkMinOpenFrames)
                .clamp(0.0, 1.0);
            return 0.6 + 0.4 * p;
        }

      case ChallengeType.turnLeft:
      case ChallengeType.turnRight:
        switch (_turnPhase) {
          case _TurnPhase.awaitingCenter:
            return 0.1;
          case _TurnPhase.turning:
            final double p = (_consecutiveFrames / config.turnMinFrames).clamp(
              0.0,
              1.0,
            );
            return 0.2 + 0.8 * p;
        }

      case ChallengeType.smile:
        switch (_smilePhase) {
          case _SmilePhase.awaitingNeutral:
            return 0.1;
          case _SmilePhase.smiling:
            final double p = (_consecutiveFrames / config.smileMinFrames).clamp(
              0.0,
              1.0,
            );
            return 0.2 + 0.8 * p;
        }
    }
  }

  ChallengeStepResult _buildResult() {
    final double stepProgress = _calculateStepProgress();
    final double overallProgress = _challenges.isNotEmpty
        ? ((_currentIndex + stepProgress) / _challenges.length).clamp(0.0, 1.0)
        : 0.0;

    return ChallengeStepResult(
      status: _status,
      currentChallenge: currentChallenge,
      challengeIndex: _currentIndex,
      totalChallenges: _challenges.length,
      stepProgress: stepProgress,
      overallProgress: _status == ChallengeMachineStatus.passed
          ? 1.0
          : overallProgress,
      failureReason: _failureReason,
    );
  }
}
