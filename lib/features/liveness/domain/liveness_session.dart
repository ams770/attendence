import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/affine_matrix.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/random_source.dart';
import '../../camera/domain/frame_data.dart';
import '../../detection/domain/detected_face.dart';
import '../../detection/domain/face_aligner.dart';
import '../../detection/domain/face_detector.dart';
import '../../detection/domain/oval_guide.dart';
import '../../detection/domain/preview_mapper.dart';
import '../../detection/domain/quality_gate.dart';
import '../../device/domain/device_tier.dart';
import '../../ml/worker/worker_protocol.dart';
import 'attempt_log.dart';
import 'challenge_config.dart';
import 'challenge_selector.dart';
import 'challenge_state_machine.dart';
import 'challenge_type.dart';
import 'flash_color.dart';
import 'flash_config.dart';
import 'flash_evaluator.dart';
import 'flash_sample.dart';
import 'liveness_session_worker.dart';
import 'passive_aggregator.dart';
import 'passive_liveness_engine.dart';
import 'passive_monitor.dart';
import 'passive_sample.dart';
import 'passive_scheduler.dart';
import 'session_lockout_tracker.dart';
import 'session_policy.dart';
import 'temporal_analyzer.dart';
import 'temporal_config.dart';
import 'temporal_sample.dart';

part 'live_session_result.dart';
part 'session_state.dart';
part 'verified_live_faces.dart';

/// Central state machine orchestrating multi-layer liveness verification.
///
/// Implemented entirely in pure Dart with zero Flutter UI imports. Injects
/// [Clock], [RandomSource], [FaceDetector], [LivenessSessionWorker], and [PassiveLivenessEngine]
/// for deterministic testing and clean architecture compliance.
class LivenessSession {
  LivenessSession({
    required this.clock,
    required this.randomSource,
    required this.faceDetector,
    required this.worker,
    required this.passiveEngine,
    this.faceAligner = const FaceAligner(),
    this.qualityGate = const QualityGate(),
    required this.lockoutTracker,
    this.config = const AppConfig(),
    this.deviceTier = DeviceTier.mid,
    TierProfile? tierProfile,
  }) : tierProfile =
           tierProfile ?? TierProfile.fromTier(deviceTier, hasInt8Model: false);

  final Clock clock;
  final RandomSource randomSource;
  final FaceDetector faceDetector;
  final LivenessSessionWorker worker;
  final PassiveLivenessEngine passiveEngine;
  final FaceAligner faceAligner;
  final QualityGate qualityGate;
  final SessionLockoutTracker lockoutTracker;
  final AppConfig config;
  final DeviceTier deviceTier;
  final TierProfile tierProfile;

  // Session lifecycle controllers and streams
  final StreamController<LivenessSessionState> _stateController =
      StreamController<LivenessSessionState>.broadcast();
  final StreamController<Duration> _totalRemainingController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _challengeRemainingController =
      StreamController<Duration>.broadcast();
  final StreamController<QualityIssue?> _guidanceController =
      StreamController<QualityIssue?>.broadcast();

  LivenessSessionState _state = const SessionStateIdle();
  QualityIssue? _currentGuidance;
  SessionPolicy _policy = SessionPolicy.attendance;

  // Timers and timestamps
  DateTime? _sessionStartTime;
  DateTime? _challengeStartTime;
  DateTime? _lastFaceSeenTime;
  DateTime? _lastQualityPauseStart;
  Duration _challengePausedDuration = Duration.zero;

  // Tracking and face continuity
  int? _sessionTrackingId;

  // Subsystem instances per session attempt
  late ChallengeStateMachine _challengeStateMachine;
  late TemporalAnalyzer _temporalAnalyzer;
  late PassiveScheduler _passiveScheduler;
  late PassiveAggregator _passiveAggregator;
  late PassiveMonitor _passiveMonitor;
  late FlashEvaluator _flashEvaluator;

  final List<ChallengeType> _selectedChallenges = <ChallengeType>[];
  final List<ChallengeRecord> _challengeRecords = <ChallengeRecord>[];
  final List<FlashStepRecord> _flashStepRecords = <FlashStepRecord>[];
  final List<VerifiedLiveFaceCrop> _candidateCrops = <VerifiedLiveFaceCrop>[];
  SkinColorSample? _flashBaseline;

  Size? _previewSize;
  Rect? _ovalRect;
  PreviewMapper? _previewMapper;

  int _currentChallengeIndex = 0;
  bool _isDisposed = false;
  String _currentSessionId = '';

  // Stale request tracking
  int _frameSeq = 0;

  /// Current session execution state.
  LivenessSessionState get state => _state;

  /// Reactive stream of session lifecycle states.
  Stream<LivenessSessionState> get stateStream => _stateController.stream;

  /// Reactive stream of remaining total session time.
  Stream<Duration> get totalRemainingTimeStream =>
      _totalRemainingController.stream;

  /// Reactive stream of remaining per-challenge time.
  Stream<Duration> get challengeRemainingTimeStream =>
      _challengeRemainingController.stream;

  /// Reactive stream of real-time quality gate guidance issues.
  Stream<QualityIssue?> get guidanceStream => _guidanceController.stream;

  /// Most recent quality guidance issue, if present.
  QualityIssue? get currentGuidance => _currentGuidance;

  /// Active verification policy.
  SessionPolicy get policy => _policy;

  /// Configured total session timeout.
  Duration get totalRemainingTime {
    if (_sessionStartTime == null) return config.sessionTimeout;
    final Duration elapsed = clock.now().difference(_sessionStartTime!);
    final Duration rem = config.sessionTimeout - elapsed;
    return rem.isNegative ? Duration.zero : rem;
  }

  /// Configured challenge timeout remaining for active step.
  Duration get challengeRemainingTime {
    if (_challengeStartTime == null) return config.perChallengeTimeout;
    final Duration activeElapsed =
        clock.now().difference(_challengeStartTime!) - _challengePausedDuration;
    final Duration rem = config.perChallengeTimeout - activeElapsed;
    return rem.isNegative ? Duration.zero : rem;
  }

  /// Initiates a new verification session.
  Future<void> start({
    SessionPolicy policy = SessionPolicy.attendance,
    Size? previewSize,
    Rect? ovalRect,
    PreviewMapper? previewMapper,
  }) async {
    _policy = policy;
    _previewSize = previewSize;
    _ovalRect = ovalRect;
    _previewMapper = previewMapper;

    // Check if system is currently locked out
    final bool locked = await lockoutTracker.isLocked();
    if (locked) {
      final DateTime? until = await lockoutTracker.getLockoutUntil();
      final int remSec = await lockoutTracker.getRemainingLockoutSeconds();
      _setState(
        SessionStateLocked(
          lockedUntil: until ?? clock.now(),
          remainingSeconds: remSec,
        ),
      );
      return;
    }

    _currentSessionId =
        'session-${clock.now().microsecondsSinceEpoch}-${randomSource.nextInt(100000)}';
    _sessionStartTime = clock.now();
    _challengeStartTime = null;
    _lastFaceSeenTime = null;
    _lastQualityPauseStart = null;
    _challengePausedDuration = Duration.zero;
    _sessionTrackingId = null;
    _currentChallengeIndex = 0;
    _currentGuidance = null;
    _flashBaseline = null;
    _frameSeq = 0;

    _candidateCrops.clear();
    _challengeRecords.clear();
    _flashStepRecords.clear();

    // Select randomized challenges
    final ChallengeSelector selector = ChallengeSelector(
      randomSource: randomSource,
    );
    final int challengeCount = (policy == SessionPolicy.attendance) ? 2 : 1;
    _selectedChallenges
      ..clear()
      ..addAll(selector.selectChallenges(count: challengeCount));

    final ChallengeConfig challengeCfg = ChallengeConfig.fromAppConfig(config);
    _challengeStateMachine = ChallengeStateMachine(
      clock: clock,
      challenges: _selectedChallenges,
      config: challengeCfg,
    );

    _temporalAnalyzer = TemporalAnalyzer(
      config: TemporalConfig.fromAppConfig(config),
    );

    _passiveScheduler = PassiveScheduler(
      targetTotalSamples: tierProfile.passiveFrameCount,
    );

    _passiveAggregator = PassiveAggregator(
      passiveThreshold: config.passiveThreshold,
      passingFrameRatio: config.passivePassingFrameRatio,
    );

    _passiveMonitor = PassiveMonitor(hardFloor: config.passiveHardFloor);

    _flashEvaluator = FlashEvaluator(config: FlashConfig.fromAppConfig(config));

    _setState(const SessionStatePositioning());
    _emitTimers();
  }

  /// Processes an incoming camera frame and optional detected face.
  Future<void> onFrame(FrameData frame, [DetectedFace? face]) async {
    if (_isDisposed) return;
    if (_state is! SessionStatePositioning &&
        _state is! SessionStateNeutral &&
        _state is! SessionStateChallenge &&
        _state is! SessionStateFlash &&
        _state is! SessionStateFinalizing) {
      return;
    }

    _frameSeq++;
    final int currentSeq = _frameSeq;
    final DateTime now = clock.now();

    // 1. Enforce total session timeout
    if (_sessionStartTime != null) {
      final Duration totalElapsed = now.difference(_sessionStartTime!);
      if (totalElapsed >= config.sessionTimeout) {
        await _fail(SessionFailureReason.timeout);
        return;
      }
    }

    // 2. Face detection if not provided
    DetectedFace? detected = face;
    if (detected == null) {
      final List<DetectedFace> detectedFaces = await faceDetector.detect(frame);
      if (detectedFaces.length > 1) {
        _setGuidance(QualityIssue.multipleFaces);
        _handleQualityPause(now);
        _emitTimers();
        return;
      } else if (detectedFaces.isNotEmpty) {
        detected = detectedFaces.first;
      }
    }

    // 3. Handle absence of face
    if (detected == null) {
      if (_state is SessionStatePositioning) {
        _setGuidance(QualityIssue.noFace);
      } else {
        // Active phase: verify face loss grace period
        if (_lastFaceSeenTime != null &&
            now.difference(_lastFaceSeenTime!) > config.faceLostGracePeriod) {
          await _fail(SessionFailureReason.faceLost);
          return;
        }
        _setGuidance(QualityIssue.noFace);
        _handleQualityPause(now);
      }
      _emitTimers();
      return;
    }

    // 4. Face tracking continuity check
    _lastFaceSeenTime = now;
    if (_sessionTrackingId == null) {
      _sessionTrackingId ??= detected.trackingId;
    } else if (detected.trackingId != null &&
        detected.trackingId != _sessionTrackingId) {
      await _fail(SessionFailureReason.trackingChanged);
      return;
    }

    // 5. Evaluate quality gate
    final Size effPreviewSize =
        _previewSize ??
        Size(frame.uprightWidth.toDouble(), frame.uprightHeight.toDouble());
    final Rect effOvalRect = _ovalRect ?? defaultOvalRect(effPreviewSize);
    final PreviewMapper effMapper =
        _previewMapper ??
        PreviewMapper.forDevice(
          imageSize: Size(
            frame.uprightWidth.toDouble(),
            frame.uprightHeight.toDouble(),
          ),
          previewSize: effPreviewSize,
          isFrontCamera: true,
        );

    final QualityResult qResult = qualityGate.evaluate(
      faces: <DetectedFace>[detected],
      previewSize: effPreviewSize,
      ovalRect: effOvalRect,
      previewMapper: effMapper,
      config: config,
    );

    // During head turn challenges, allow yaw deviation in the requested direction
    bool isTurnChallenge = false;
    if (_state is SessionStateChallenge) {
      final SessionStateChallenge chState = _state as SessionStateChallenge;
      isTurnChallenge =
          chState.type == ChallengeType.turnLeft ||
          chState.type == ChallengeType.turnRight;
    }

    final List<QualityIssue> filteredIssues = qResult.issues.where((
      QualityIssue issue,
    ) {
      if (isTurnChallenge && issue == QualityIssue.poseOutOfRange) {
        return false;
      }
      return true;
    }).toList();

    if (filteredIssues.isNotEmpty) {
      _setGuidance(filteredIssues.first);
      _handleQualityPause(now);
      _emitTimers();
      return;
    }

    // Quality passed: resume challenge timer if it was paused
    _clearQualityPause(now);
    _setGuidance(null);

    // Feed temporal analyzer
    final TemporalFrameSample? tSample = detected.toTemporalSample(now);
    if (tSample != null) {
      _temporalAnalyzer.addSample(tSample);
    }

    // 6. State-specific progression
    if (_state is SessionStatePositioning) {
      _sessionTrackingId ??= detected.trackingId;
      _challengeStartTime = now;
      _challengePausedDuration = Duration.zero;
      _setState(const SessionStateNeutral());
    }

    if (_state is SessionStateNeutral) {
      await _processNeutralPhase(frame, detected, now, currentSeq);
      return;
    }

    if (_state is SessionStateChallenge) {
      await _processChallengePhase(frame, detected, now, currentSeq);
      return;
    }

    if (_state is SessionStateFlash) {
      await _processFlashPhase(frame, detected, now, currentSeq);
      return;
    }

    if (_state is SessionStateFinalizing) {
      await _processFinalizingPhase(frame, detected, now, currentSeq);
      return;
    }
  }

  Future<void> _processNeutralPhase(
    FrameData frame,
    DetectedFace face,
    DateTime now,
    int currentSeq,
  ) async {
    // Schedule passive evaluation
    await _maybeSamplePassive(frame, face, SessionPhase.neutral, currentSeq);
    if (_frameSeq != currentSeq || _state is! SessionStateNeutral) return;

    // Challenge timeout check
    if (_isChallengeTimedOut(now)) {
      await _fail(SessionFailureReason.timeout);
      return;
    }

    final ChallengeStepResult stepResult = _challengeStateMachine.update(face);
    if (stepResult.isFailed) {
      await _fail(_mapChallengeFailure(stepResult.failureReason));
      return;
    }

    // Neutral step completed in state machine
    if (stepResult.challengeIndex > 0 || stepResult.isPassed) {
      _recordChallengeRecord(ChallengeType.lookStraight, true);
      _advanceToNextChallenge(now);
    } else {
      _emitTimers();
    }
  }

  Future<void> _processChallengePhase(
    FrameData frame,
    DetectedFace face,
    DateTime now,
    int currentSeq,
  ) async {
    await _maybeSamplePassive(frame, face, SessionPhase.challenge, currentSeq);
    if (_frameSeq != currentSeq || _state is! SessionStateChallenge) return;

    if (_isChallengeTimedOut(now)) {
      await _fail(SessionFailureReason.timeout);
      return;
    }

    final ChallengeStepResult stepResult = _challengeStateMachine.update(face);
    if (stepResult.isFailed) {
      await _fail(_mapChallengeFailure(stepResult.failureReason));
      return;
    }

    final SessionStateChallenge curr = _state as SessionStateChallenge;

    if (stepResult.isPassed ||
        stepResult.challengeIndex > _currentChallengeIndex + 1) {
      _recordChallengeRecord(curr.type, true);
      _currentChallengeIndex++;

      final int activeCount = _selectedChallenges.length - 1;
      if (_currentChallengeIndex < activeCount) {
        _challengeStartTime = now;
        _challengePausedDuration = Duration.zero;
        final ChallengeType nextType =
            _selectedChallenges[_currentChallengeIndex + 1];
        _setState(
          SessionStateChallenge(
            index: _currentChallengeIndex,
            type: nextType,
            totalChallenges: activeCount,
            progress: 0.0,
          ),
        );
      } else {
        // All active challenges passed!
        _transitionAfterChallenges(now);
      }
    } else {
      _setState(
        SessionStateChallenge(
          index: curr.index,
          type: curr.type,
          totalChallenges: curr.totalChallenges,
          progress: stepResult.stepProgress,
        ),
      );
      _emitTimers();
    }
  }

  void _transitionAfterChallenges(DateTime now) {
    if (config.flashChallengeEnabled && tierProfile.flashChallengeDefault) {
      _challengeStartTime = now;
      _challengePausedDuration = Duration.zero;
      _flashBaseline = null;
      _setState(
        SessionStateFlash(
          color: FlashColor.red,
          dwellRemainingMs: config.flashColorDwellDuration.inMilliseconds,
        ),
      );
    } else {
      _challengeStartTime = now;
      _challengePausedDuration = Duration.zero;
      _setState(const SessionStateFinalizing());
    }
    _emitTimers();
  }

  Future<void> _processFlashPhase(
    FrameData frame,
    DetectedFace face,
    DateTime now,
    int currentSeq,
  ) async {
    if (_flashBaseline == null) {
      final SkinColorSampleData baseData = await worker.getSkinColorSample(
        frame.toTransferable(),
        <Rect>[face.boundingBox],
      );
      if (_frameSeq != currentSeq) return;
      _flashBaseline = SkinColorSample(
        meanR: baseData.meanR,
        meanG: baseData.meanG,
        meanB: baseData.meanB,
        brightness: baseData.brightness,
        timestamp: now,
      );
    }

    final SessionStateFlash flashState = _state as SessionStateFlash;
    final Duration dwellElapsed = now.difference(_challengeStartTime!);
    final int remMs =
        config.flashColorDwellDuration.inMilliseconds -
        dwellElapsed.inMilliseconds;

    if (remMs <= 0) {
      // Record color step
      final SkinColorSampleData skinData = await worker.getSkinColorSample(
        frame.toTransferable(),
        <Rect>[face.boundingBox],
      );
      if (_frameSeq != currentSeq) return;

      _flashStepRecords.add(
        FlashStepRecord(
          color: flashState.color,
          sample: SkinColorSample(
            meanR: skinData.meanR,
            meanG: skinData.meanG,
            meanB: skinData.meanB,
            brightness: skinData.brightness,
            timestamp: now,
          ),
        ),
      );

      // Advance color or evaluate
      final int nextIndex = flashState.color.index + 1;
      if (nextIndex < FlashColor.values.length) {
        _challengeStartTime = now;
        _setState(
          SessionStateFlash(
            color: FlashColor.values[nextIndex],
            dwellRemainingMs: config.flashColorDwellDuration.inMilliseconds,
          ),
        );
      } else {
        // Complete flash challenge evaluation
        final FlashEvaluationResult flashResult = _flashEvaluator.evaluate(
          baseline:
              _flashBaseline ??
              SkinColorSample(
                meanR: 128.0,
                meanG: 128.0,
                meanB: 128.0,
                brightness: 128.0,
                timestamp: now,
              ),
          steps: _flashStepRecords,
        );

        if (!flashResult.verdict.isPassed && !flashResult.verdict.isSkipped) {
          await _fail(SessionFailureReason.flashFailed);
          return;
        }

        _challengeStartTime = now;
        _challengePausedDuration = Duration.zero;
        _setState(const SessionStateFinalizing());
      }
    } else {
      _setState(
        SessionStateFlash(
          color: flashState.color,
          dwellRemainingMs: math.max(0, remMs),
        ),
      );
    }
    _emitTimers();
  }

  Future<void> _processFinalizingPhase(
    FrameData frame,
    DetectedFace face,
    DateTime now,
    int currentSeq,
  ) async {
    // 1. Continue passive sampling in final phase (guarantees samples after challenges)
    await _maybeSamplePassive(frame, face, SessionPhase.finalPhase, currentSeq);
    if (_frameSeq != currentSeq || _state is! SessionStateFinalizing) return;

    // 2. Pose check for candidate recognition crop: near frontal
    final double yawAbs = (face.yaw ?? 0.0).abs();
    final double pitchAbs = (face.pitch ?? 0.0).abs();
    final double rollAbs = (face.roll ?? 0.0).abs();

    final bool isNearFrontal =
        yawAbs <= config.challengeNeutralMaxYaw &&
        pitchAbs <= config.challengeNeutralMaxPitch &&
        rollAbs <= config.challengeNeutralMaxRoll;

    if (isNearFrontal && face.hasAllLandmarks) {
      final AffineMatrix? transform = faceAligner.computeSimilarityTransform(
        face.landmarks!,
      );
      if (transform != null) {
        final AlignedCropData cropData = await worker.getAlignedCrop(
          frame.toTransferable(),
          transform,
        );
        final FaceStats stats = await worker.getFaceStats(
          frame.toTransferable(),
          face.boundingBox,
        );
        if (_frameSeq != currentSeq) return;

        _candidateCrops.add(
          VerifiedLiveFaceCrop(
            rgbBytes: cropData.rgbBytes,
            sharpness: stats.sharpness,
            width: cropData.width,
            height: cropData.height,
            trackingId: face.trackingId ?? _sessionTrackingId ?? 0,
            timestamp: now,
            yaw: face.yaw ?? 0.0,
            pitch: face.pitch ?? 0.0,
            roll: face.roll ?? 0.0,
          ),
        );

        _setState(
          SessionStateFinalizing(
            collectedCrops: _candidateCrops.length,
            targetCrops: 3,
          ),
        );
      }
    }

    // 3. Complete session once 3 candidate crops are collected and passive final phase has sample
    final bool hasFinalPassive =
        _passiveScheduler.sampleCountForPhase(SessionPhase.finalPhase) >= 1;

    if (_candidateCrops.length >= 3 && hasFinalPassive) {
      await _evaluateFinalVerdict(now);
    } else {
      _emitTimers();
    }
  }

  Future<void> _evaluateFinalVerdict(DateTime now) async {
    // Check continuous hard floor violation
    if (_passiveMonitor.isCompromised) {
      await _fail(SessionFailureReason.passiveHardFloorViolation);
      return;
    }

    // Check passive aggregate verdict
    final PassiveAggregatedResult passiveRes = _passiveAggregator.result;
    if (passiveRes.verdict != PassiveVerdict.passed) {
      await _fail(SessionFailureReason.passiveFailed);
      return;
    }

    // Check temporal motion confidence
    final TemporalAnalysisResult tempRes = _temporalAnalyzer.evaluate();
    if (tempRes.combinedConfidence < config.temporalConfidenceThreshold) {
      await _fail(SessionFailureReason.temporalFailed);
      return;
    }

    // Check flash evaluation if enabled
    FlashEvaluationResult? flashRes;
    if (config.flashChallengeEnabled && _flashStepRecords.isNotEmpty) {
      flashRes = _flashEvaluator.evaluate(
        baseline:
            _flashBaseline ??
            SkinColorSample(
              meanR: 128.0,
              meanG: 128.0,
              meanB: 128.0,
              brightness: 128.0,
              timestamp: now,
            ),
        steps: _flashStepRecords,
      );
      if (!flashRes.verdict.isPassed && !flashRes.verdict.isSkipped) {
        await _fail(SessionFailureReason.flashFailed);
        return;
      }
    }

    // Sort candidate crops by sharpness descending and keep top 3
    _candidateCrops.sort(
      (VerifiedLiveFaceCrop a, VerifiedLiveFaceCrop b) =>
          b.sharpness.compareTo(a.sharpness),
    );
    final List<VerifiedLiveFaceCrop> topCrops = _candidateCrops
        .take(3)
        .toList(growable: false);

    final VerifiedLiveFaces verifiedFaces = VerifiedLiveFaces._(
      crops: topCrops,
      trackingId: _sessionTrackingId ?? 0,
      sessionId: _currentSessionId,
      verifiedAt: now,
    );

    final Duration totalDuration = now.difference(_sessionStartTime ?? now);

    final Map<String, double> perModelScores = _computePerModelScores();
    final int passingFrames = _passiveAggregator.samples
        .where((PassiveSample s) => s.meanScore >= config.passiveThreshold)
        .length;

    final AttemptLog log = _buildAttemptLog(
      passed: true,
      reason: null,
      duration: totalDuration,
      now: now,
      flashRes: flashRes,
      passiveRes: passiveRes,
      tempRes: tempRes,
      perModelScores: perModelScores,
    );

    final LiveSessionResult result = LiveSessionResult(
      passed: true,
      meanPassiveScore: passiveRes.meanScore,
      framesAboveThreshold: passingFrames,
      totalPassiveSamples: passiveRes.sampleCount,
      perModelScores: perModelScores,
      challengeResults: List<ChallengeRecord>.unmodifiable(_challengeRecords),
      temporalConfidence: tempRes.combinedConfidence,
      flashResult: flashRes,
      trackingId: _sessionTrackingId,
      deviceTier: deviceTier,
      verifiedFaces: verifiedFaces,
      duration: totalDuration,
      startedAt: _sessionStartTime ?? now,
      completedAt: now,
      attemptLog: log,
    );

    await lockoutTracker.recordSuccess();
    _setState(SessionStateSucceeded(result: result));
  }

  Future<void> _maybeSamplePassive(
    FrameData frame,
    DetectedFace face,
    SessionPhase phase,
    int currentSeq,
  ) async {
    final DateTime now = clock.now();
    final Duration totalElapsed = now.difference(_sessionStartTime ?? now);
    final Duration phaseElapsed = now.difference(_challengeStartTime ?? now);

    if (_passiveScheduler.shouldSample(
      phase: phase,
      phaseElapsed: phaseElapsed,
      totalElapsed: totalElapsed,
    )) {
      _passiveScheduler.recordSample(phase: phase, totalElapsed: totalElapsed);

      final PassiveFrameResult result = await passiveEngine.evaluateFrame(
        frame: frame.toTransferable(),
        faceRect: face.boundingBox,
        modelNames: tierProfile.modelsUsed,
        preprocessConfig: config.passivePreprocessConfig,
      );

      if (_frameSeq != currentSeq) return;

      _passiveAggregator.addSample(
        PassiveSample(
          timestamp: now,
          meanScore: result.meanRealProbability,
          modelScores: result.modelResults.map(
            (String k, PassiveModelResult v) =>
                MapEntry<String, double>(k, v.realProbability),
          ),
          latencyMs: result.totalLatencyMs,
        ),
      );

      _passiveMonitor.addSample(result.meanRealProbability);

      // Immediate hard floor violation check
      if (_passiveMonitor.isCompromised) {
        await _fail(SessionFailureReason.passiveHardFloorViolation);
      }
    }
  }

  void _advanceToNextChallenge(DateTime now) {
    _currentChallengeIndex = 0;
    _challengeStartTime = now;
    _challengePausedDuration = Duration.zero;

    final int activeCount = _selectedChallenges.length - 1;
    final ChallengeType firstActive = _selectedChallenges[1];

    _setState(
      SessionStateChallenge(
        index: 0,
        type: firstActive,
        totalChallenges: activeCount,
        progress: 0.0,
      ),
    );
    _emitTimers();
  }

  void _recordChallengeRecord(ChallengeType type, bool passed) {
    _challengeRecords.add(
      ChallengeRecord(
        type: type,
        startedAt: _challengeStartTime ?? clock.now(),
        completedAt: clock.now(),
        passed: passed,
        framesObserved: 3,
      ),
    );
  }

  bool _isChallengeTimedOut(DateTime now) {
    if (_challengeStartTime == null) return false;
    final Duration elapsed =
        now.difference(_challengeStartTime!) - _challengePausedDuration;
    return elapsed >= config.perChallengeTimeout;
  }

  void _handleQualityPause(DateTime now) {
    _lastQualityPauseStart ??= now;
  }

  void _clearQualityPause(DateTime now) {
    if (_lastQualityPauseStart != null) {
      _challengePausedDuration += now.difference(_lastQualityPauseStart!);
      _lastQualityPauseStart = null;
    }
  }

  SessionFailureReason _mapChallengeFailure(ChallengeFailureReason reason) {
    switch (reason) {
      case ChallengeFailureReason.timeout:
        return SessionFailureReason.timeout;
      case ChallengeFailureReason.trackingLost:
        return SessionFailureReason.faceLost;
      case ChallengeFailureReason.trackingChanged:
        return SessionFailureReason.trackingChanged;
      case ChallengeFailureReason.wrongDirection:
      case ChallengeFailureReason.none:
      case ChallengeFailureReason.cancelled:
        return SessionFailureReason.challengeFailed;
    }
  }

  Future<void> _fail(SessionFailureReason reason) async {
    final DateTime now = clock.now();
    final Duration totalDuration = now.difference(_sessionStartTime ?? now);

    final PassiveAggregatedResult passiveRes = _passiveAggregator.result;
    final TemporalAnalysisResult tempRes = _temporalAnalyzer.evaluate();
    final Map<String, double> perModelScores = _computePerModelScores();
    final int passingFrames = _passiveAggregator.samples
        .where((PassiveSample s) => s.meanScore >= config.passiveThreshold)
        .length;

    final AttemptLog log = _buildAttemptLog(
      passed: false,
      reason: reason.name,
      duration: totalDuration,
      now: now,
      flashRes: null,
      passiveRes: passiveRes,
      tempRes: tempRes,
      perModelScores: perModelScores,
    );

    final LiveSessionResult result = LiveSessionResult(
      passed: false,
      failureReason: reason,
      meanPassiveScore: passiveRes.meanScore,
      framesAboveThreshold: passingFrames,
      totalPassiveSamples: passiveRes.sampleCount,
      perModelScores: perModelScores,
      challengeResults: List<ChallengeRecord>.unmodifiable(_challengeRecords),
      temporalConfidence: tempRes.combinedConfidence,
      trackingId: _sessionTrackingId,
      deviceTier: deviceTier,
      duration: totalDuration,
      startedAt: _sessionStartTime ?? now,
      completedAt: now,
      attemptLog: log,
    );

    if (reason != SessionFailureReason.cancelled) {
      final bool locked = await lockoutTracker.recordFailure();
      if (locked) {
        final DateTime? until = await lockoutTracker.getLockoutUntil();
        final int remSec = await lockoutTracker.getRemainingLockoutSeconds();
        _setState(
          SessionStateLocked(
            lockedUntil: until ?? now,
            remainingSeconds: remSec,
          ),
        );
        return;
      }
    }

    _setState(SessionStateFailed(reason: reason, result: result));
  }

  Map<String, double> _computePerModelScores() {
    final Map<String, List<double>> modelScores = <String, List<double>>{};
    for (final PassiveSample s in _passiveAggregator.samples) {
      s.modelScores.forEach((String m, double score) {
        modelScores.putIfAbsent(m, () => <double>[]).add(score);
      });
    }
    return modelScores.map((String m, List<double> scores) {
      final double avg =
          scores.reduce((double a, double b) => a + b) / scores.length;
      return MapEntry<String, double>(m, avg);
    });
  }

  AttemptLog _buildAttemptLog({
    required bool passed,
    required String? reason,
    required Duration duration,
    required DateTime now,
    required FlashEvaluationResult? flashRes,
    required PassiveAggregatedResult passiveRes,
    required TemporalAnalysisResult tempRes,
    required Map<String, double> perModelScores,
  }) {
    return AttemptLog(
      attemptId: _currentSessionId,
      timestamp: _sessionStartTime ?? now,
      policy: _policy.name,
      passed: passed,
      failureReason: reason,
      durationMs: duration.inMilliseconds,
      meanPassiveScore: passiveRes.meanScore,
      passiveSamplesCount: passiveRes.sampleCount,
      passivePassingRatio: passiveRes.passingRatio,
      perModelScores: perModelScores,
      temporalConfidence: tempRes.combinedConfidence,
      microMotionScore: tempRes.microMotionScore,
      loopScore: tempRes.loopScore,
      rigidityScore: tempRes.rigidityScore,
      flashPassed: flashRes?.verdict.isPassed,
      flashCorrelation: flashRes?.correlation,
      deviceTier: deviceTier.name,
      challengesCompleted: _challengeRecords
          .where((ChallengeRecord r) => r.passed)
          .map((ChallengeRecord r) => r.type.name)
          .toList(),
      trackingId: _sessionTrackingId,
    );
  }

  void _setState(LivenessSessionState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  void _setGuidance(QualityIssue? issue) {
    _currentGuidance = issue;
    if (!_guidanceController.isClosed) {
      _guidanceController.add(issue);
    }
  }

  void _emitTimers() {
    if (!_totalRemainingController.isClosed) {
      _totalRemainingController.add(totalRemainingTime);
    }
    if (!_challengeRemainingController.isClosed) {
      _challengeRemainingController.add(challengeRemainingTime);
    }
  }

  /// Cancels the ongoing session attempt cleanly.
  Future<void> cancel() async {
    if (_state is! SessionStateSucceeded &&
        _state is! SessionStateFailed &&
        _state is! SessionStateLocked) {
      await _fail(SessionFailureReason.cancelled);
    }
  }

  /// Releases stream controllers and internal resources.
  void dispose() {
    _isDisposed = true;
    _stateController.close();
    _totalRemainingController.close();
    _challengeRemainingController.close();
    _guidanceController.close();
  }
}
