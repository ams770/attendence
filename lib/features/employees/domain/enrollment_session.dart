import 'dart:typed_data';

import '../../../core/config/app_config.dart';
import '../../../core/utils/clock.dart';
import '../../detection/domain/detected_face.dart';
import '../../detection/domain/quality_gate.dart';
import '../../recognition/domain/face_matcher.dart';
import '../../recognition/domain/face_recognizer.dart';
import '../../recognition/domain/match_result.dart';
import '../domain/employee.dart';
import 'enrollment_pose.dart';

/// Warning emitted when a newly enrolled face closely matches an existing active employee.
class DuplicateFaceWarning {
  const DuplicateFaceWarning({
    required this.matchedEmployee,
    required this.similarityScore,
  });

  final Employee matchedEmployee;
  final double similarityScore;
}

/// Execution status of the 5-pose employee enrollment session.
enum EnrollmentStatus {
  idle,
  capturing,
  processing,
  duplicateDetected,
  completed,
  failed,
}

/// State of an active enrollment session.
class EnrollmentSessionState {
  const EnrollmentSessionState({
    required this.status,
    required this.currentPoseIndex,
    required this.currentPose,
    required this.capturedCount,
    required this.holdProgress,
    this.guidanceIssue,
    this.failureMessage,
    this.duplicateWarning,
  });

  final EnrollmentStatus status;
  final int currentPoseIndex;
  final EnrollmentPose currentPose;
  final int capturedCount;
  final double holdProgress;
  final QualityIssue? guidanceIssue;
  final String? failureMessage;
  final DuplicateFaceWarning? duplicateWarning;

  EnrollmentSessionState copyWith({
    EnrollmentStatus? status,
    int? currentPoseIndex,
    EnrollmentPose? currentPose,
    int? capturedCount,
    double? holdProgress,
    QualityIssue? guidanceIssue,
    String? failureMessage,
    DuplicateFaceWarning? duplicateWarning,
  }) {
    return EnrollmentSessionState(
      status: status ?? this.status,
      currentPoseIndex: currentPoseIndex ?? this.currentPoseIndex,
      currentPose: currentPose ?? this.currentPose,
      capturedCount: capturedCount ?? this.capturedCount,
      holdProgress: holdProgress ?? this.holdProgress,
      guidanceIssue: guidanceIssue,
      failureMessage: failureMessage ?? this.failureMessage,
      duplicateWarning: duplicateWarning ?? this.duplicateWarning,
    );
  }
}

/// Domain orchestrator managing the 5-sample structured head pose enrollment flow.
class EnrollmentSession {
  EnrollmentSession({
    required this.recognizer,
    required this.matcher,
    required this.config,
    this.clock = const SystemClock(),
    this.requiredHoldFrames = 3,
    this.onStateChanged,
  });

  final FaceRecognizer recognizer;
  final FaceMatcher matcher;
  final AppConfig config;
  final Clock clock;
  final int requiredHoldFrames;
  void Function(EnrollmentSessionState)? onStateChanged;

  EnrollmentSessionState _state = const EnrollmentSessionState(
    status: EnrollmentStatus.idle,
    currentPoseIndex: 0,
    currentPose: EnrollmentPose.front,
    capturedCount: 0,
    holdProgress: 0.0,
  );

  int? _boundTrackingId;
  int _consecutiveValidFrames = 0;
  final List<Uint8List> _capturedCrops = <Uint8List>[];
  List<List<double>>? _computedEmbeddings;

  EnrollmentSessionState get state => _state;
  List<Uint8List> get capturedCrops =>
      List<Uint8List>.unmodifiable(_capturedCrops);
  List<List<double>>? get computedEmbeddings => _computedEmbeddings;

  void start() {
    _boundTrackingId = null;
    _consecutiveValidFrames = 0;
    _capturedCrops.clear();
    _computedEmbeddings = null;

    _state = const EnrollmentSessionState(
      status: EnrollmentStatus.capturing,
      currentPoseIndex: 0,
      currentPose: EnrollmentPose.front,
      capturedCount: 0,
      holdProgress: 0.0,
    );
  }

  /// Processes a single frame telemetry and aligned crop.
  Future<EnrollmentSessionState> onFrame({
    required DetectedFace face,
    required QualityResult quality,
    Uint8List? alignedRgb112,
  }) async {
    if (_state.status != EnrollmentStatus.capturing) {
      return _state;
    }

    // 1. Anti-substitution: bind tracking ID to the first sample
    if (_boundTrackingId == null) {
      _boundTrackingId = face.trackingId;
    } else if (face.trackingId != _boundTrackingId) {
      _state = _state.copyWith(
        status: EnrollmentStatus.failed,
        failureMessage: 'Face tracking ID changed during enrollment',
      );
      return _state;
    }

    // 2. Quality check
    if (!quality.isPass) {
      _consecutiveValidFrames = 0;
      _state = _state.copyWith(
        holdProgress: 0.0,
        guidanceIssue: quality.issues.first,
      );
      return _state;
    }

    // 3. Pose angle check
    final EnrollmentPose targetPose =
        EnrollmentPose.ordered[_state.currentPoseIndex];
    final bool isPoseValid = _isPoseSatisfied(face, targetPose);

    if (!isPoseValid) {
      _consecutiveValidFrames = 0;
      _state = _state.copyWith(
        holdProgress: 0.0,
        guidanceIssue: QualityIssue.poseOutOfRange,
      );
      return _state;
    }

    if (alignedRgb112 == null) {
      _consecutiveValidFrames = 0;
      _state = _state.copyWith(
        holdProgress: 0.0,
        guidanceIssue: QualityIssue.landmarksMissing,
      );
      return _state;
    }

    _consecutiveValidFrames++;
    final double holdProgress = (_consecutiveValidFrames / requiredHoldFrames)
        .clamp(0.0, 1.0);

    if (_consecutiveValidFrames >= requiredHoldFrames) {
      // Sample acquired!
      _capturedCrops.add(alignedRgb112);
      _consecutiveValidFrames = 0;

      final int nextIndex = _state.currentPoseIndex + 1;
      if (nextIndex >= EnrollmentPose.ordered.length) {
        // All 5 poses captured -> notify processing state immediately and finalize
        _state = _state.copyWith(
          status: EnrollmentStatus.processing,
          capturedCount: _capturedCrops.length,
          holdProgress: 1.0,
          guidanceIssue: null,
        );
        onStateChanged?.call(_state);
        return _finalizeEnrollment();
      } else {
        _state = _state.copyWith(
          currentPoseIndex: nextIndex,
          currentPose: EnrollmentPose.ordered[nextIndex],
          capturedCount: _capturedCrops.length,
          holdProgress: 0.0,
          guidanceIssue: null,
        );
      }
    } else {
      _state = _state.copyWith(holdProgress: holdProgress, guidanceIssue: null);
    }

    return _state;
  }

  bool _isPoseSatisfied(DetectedFace face, EnrollmentPose target) {
    final double yaw = (face.yaw ?? 0.0) * config.yawSignForUserLeft;
    final double pitch = face.pitch ?? 0.0;
    final double roll = (face.roll ?? 0.0).abs();

    if (roll > 15.0) return false;

    switch (target) {
      case EnrollmentPose.front:
        return yaw.abs() <= 8.0 && pitch.abs() <= 8.0;
      case EnrollmentPose.slightLeft:
        return yaw >= 12.0 && yaw <= 28.0 && pitch.abs() <= 12.0;
      case EnrollmentPose.slightRight:
        return yaw <= -12.0 && yaw >= -28.0 && pitch.abs() <= 12.0;
      case EnrollmentPose.slightUp:
        return pitch >= 10.0 && pitch <= 24.0 && yaw.abs() <= 12.0;
      case EnrollmentPose.slightDown:
        return pitch <= -10.0 && pitch >= -24.0 && yaw.abs() <= 12.0;
    }
  }

  Future<EnrollmentSessionState> _finalizeEnrollment() async {
    try {
      final List<List<double>> embeddings = <List<double>>[];
      for (final Uint8List crop in _capturedCrops) {
        final List<double> emb = await recognizer.embedSingleCrop(crop);
        embeddings.add(emb);
      }
      _computedEmbeddings = embeddings;

      // Check for duplicate face against already enrolled active employees
      for (final List<double> candidate in embeddings) {
        final MatchResult match = await matcher.match(
          candidate,
          thresholdOverride: config.recognitionThreshold,
        );
        if (match is MatchResultMatched) {
          _state = _state.copyWith(
            status: EnrollmentStatus.duplicateDetected,
            duplicateWarning: DuplicateFaceWarning(
              matchedEmployee: match.employee,
              similarityScore: match.rawScore,
            ),
          );
          onStateChanged?.call(_state);
          return _state;
        }
      }

      _state = _state.copyWith(status: EnrollmentStatus.completed);
      onStateChanged?.call(_state);
      return _state;
    } catch (e) {
      _state = _state.copyWith(
        status: EnrollmentStatus.failed,
        failureMessage: e.toString(),
      );
      onStateChanged?.call(_state);
      return _state;
    }
  }

  void acknowledgeDuplicateAndComplete() {
    if (_state.status == EnrollmentStatus.duplicateDetected) {
      _state = _state.copyWith(status: EnrollmentStatus.completed);
    }
  }

  void reset() {
    _state = const EnrollmentSessionState(
      status: EnrollmentStatus.idle,
      currentPoseIndex: 0,
      currentPose: EnrollmentPose.front,
      capturedCount: 0,
      holdProgress: 0.0,
    );
    _boundTrackingId = null;
    _consecutiveValidFrames = 0;
    _capturedCrops.clear();
    _computedEmbeddings = null;
  }
}
