import 'dart:typed_data';
import 'dart:ui';

import 'package:attendence/core/config/app_config.dart';
import 'package:attendence/core/utils/clock.dart';
import 'package:attendence/features/detection/domain/detected_face.dart';
import 'package:attendence/features/detection/domain/quality_gate.dart';
import 'package:attendence/features/employees/data/fake_employee_repository.dart';
import 'package:attendence/features/employees/domain/enrollment_pose.dart';
import 'package:attendence/features/employees/domain/enrollment_session.dart';
import 'package:attendence/features/liveness/domain/liveness_session.dart';
import 'package:attendence/features/recognition/domain/face_matcher.dart';
import 'package:attendence/features/recognition/domain/face_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFaceRecognizer implements FaceRecognizer {
  _FakeFaceRecognizer({required this.embeddingToReturn});

  List<double> embeddingToReturn;

  @override
  String get modelId => 'sface';

  @override
  int get dimension => 128;

  @override
  Future<List<double>> embedSingleCrop(Uint8List alignedRgb) async =>
      embeddingToReturn;

  @override
  Future<List<double>> embedVerifiedFaces(VerifiedLiveFaces liveFaces) async =>
      embeddingToReturn;
}

void main() {
  group('EnrollmentSession Orchestrator', () {
    late FakeClock clock;
    late FakeEmployeeRepository repo;
    late _FakeFaceRecognizer recognizer;
    late FaceMatcher matcher;
    late EnrollmentSession session;

    final Uint8List dummyCrop = Uint8List(112 * 112 * 3);

    setUp(() {
      clock = FakeClock(DateTime(2026, 11, 7, 12, 0, 0));
      repo = FakeEmployeeRepository(clock: clock);
      recognizer = _FakeFaceRecognizer(
        embeddingToReturn: List<double>.filled(128, 0.1),
      );
      matcher = FaceMatcher(
        repository: repo,
        config: const AppConfig(),
        clock: clock,
      );
      session = EnrollmentSession(
        recognizer: recognizer,
        matcher: matcher,
        config: const AppConfig(),
        clock: clock,
        requiredHoldFrames: 3,
      );
    });

    DetectedFace createFace({
      int trackingId = 1,
      double yaw = 0.0,
      double pitch = 0.0,
    }) {
      return DetectedFace(
        trackingId: trackingId,
        boundingBox: const Rect.fromLTWH(50, 50, 100, 100),
        landmarks: const FiveLandmarks(
          leftEye: Offset(60, 60),
          rightEye: Offset(80, 60),
          noseBase: Offset(70, 75),
          leftMouth: Offset(65, 90),
          rightMouth: Offset(75, 90),
        ),
        headEulerAngleY: yaw,
        headEulerAngleX: pitch,
      );
    }

    test('initial state is idle and starts cleanly', () {
      expect(session.state.status, EnrollmentStatus.idle);
      expect(session.state.currentPose, EnrollmentPose.front);
      expect(session.state.capturedCount, 0);

      session.start();
      expect(session.state.status, EnrollmentStatus.capturing);
    });

    test(
      'progresses through all 5 poses requiring 3-frame hold for each',
      () async {
        session.start();

        // Pose 1: Front (yaw ~ 0, pitch ~ 0)
        for (int i = 0; i < 3; i++) {
          final EnrollmentSessionState state = await session.onFrame(
            face: createFace(yaw: 0.0, pitch: 0.0),
            quality: const QualityResult(issues: <QualityIssue>[]),
            alignedRgb112: dummyCrop,
          );
          if (i < 2) {
            expect(state.currentPose, EnrollmentPose.front);
            expect(state.capturedCount, 0);
            expect(state.holdProgress, closeTo((i + 1) / 3, 0.01));
          } else {
            // Pose 1 completed, advances to Pose 2: Slight Left
            expect(state.currentPose, EnrollmentPose.slightLeft);
            expect(state.capturedCount, 1);
            expect(state.holdProgress, 0.0);
          }
        }

        // Pose 2: Slight Left (yaw >= 10.0)
        for (int i = 0; i < 3; i++) {
          final EnrollmentSessionState state = await session.onFrame(
            face: createFace(yaw: 15.0, pitch: 0.0),
            quality: const QualityResult(issues: <QualityIssue>[]),
            alignedRgb112: dummyCrop,
          );
          if (i < 2) {
            expect(state.currentPose, EnrollmentPose.slightLeft);
          } else {
            expect(state.currentPose, EnrollmentPose.slightRight);
            expect(state.capturedCount, 2);
          }
        }

        // Pose 3: Slight Right (yaw <= -10.0)
        for (int i = 0; i < 3; i++) {
          final EnrollmentSessionState state = await session.onFrame(
            face: createFace(yaw: -15.0, pitch: 0.0),
            quality: const QualityResult(issues: <QualityIssue>[]),
            alignedRgb112: dummyCrop,
          );
          if (i < 2) {
            expect(state.currentPose, EnrollmentPose.slightRight);
          } else {
            expect(state.currentPose, EnrollmentPose.slightUp);
            expect(state.capturedCount, 3);
          }
        }

        // Pose 4: Slight Up (pitch >= 8.0)
        for (int i = 0; i < 3; i++) {
          final EnrollmentSessionState state = await session.onFrame(
            face: createFace(yaw: 0.0, pitch: 10.0),
            quality: const QualityResult(issues: <QualityIssue>[]),
            alignedRgb112: dummyCrop,
          );
          if (i < 2) {
            expect(state.currentPose, EnrollmentPose.slightUp);
          } else {
            expect(state.currentPose, EnrollmentPose.slightDown);
            expect(state.capturedCount, 4);
          }
        }

        // Pose 5: Slight Down (pitch <= -8.0)
        for (int i = 0; i < 3; i++) {
          final EnrollmentSessionState state = await session.onFrame(
            face: createFace(yaw: 0.0, pitch: -10.0),
            quality: const QualityResult(issues: <QualityIssue>[]),
            alignedRgb112: dummyCrop,
          );
          if (i == 2) {
            // All 5 completed
            expect(state.status, EnrollmentStatus.completed);
            expect(state.capturedCount, 5);
            expect(session.computedEmbeddings, isNotNull);
            expect(session.computedEmbeddings!.length, 5);
          }
        }
      },
    );

    test('fails immediately if tracking ID changes mid-enrollment', () async {
      session.start();

      await session.onFrame(
        face: createFace(trackingId: 100),
        quality: const QualityResult(issues: <QualityIssue>[]),
        alignedRgb112: dummyCrop,
      );

      final EnrollmentSessionState state = await session.onFrame(
        face: createFace(trackingId: 200), // Switched person / tracking ID
        quality: const QualityResult(issues: <QualityIssue>[]),
        alignedRgb112: dummyCrop,
      );

      expect(state.status, EnrollmentStatus.failed);
      expect(state.failureMessage, isNotNull);
    });

    test(
      'resets hold progress and surfaces guidance on quality issues',
      () async {
        session.start();

        // Frame 1 valid
        await session.onFrame(
          face: createFace(),
          quality: const QualityResult(issues: <QualityIssue>[]),
          alignedRgb112: dummyCrop,
        );
        expect(session.state.holdProgress, closeTo(1 / 3, 0.01));

        // Frame 2 has quality issue (too dark)
        final EnrollmentSessionState state = await session.onFrame(
          face: createFace(),
          quality: const QualityResult(
            issues: <QualityIssue>[QualityIssue.tooDark],
          ),
          alignedRgb112: dummyCrop,
        );

        // Hold progress resets to 0 and guidance issue is set
        expect(state.holdProgress, 0.0);
        expect(state.guidanceIssue, QualityIssue.tooDark);
      },
    );

    test('warns and blocks with duplicate warning if matching an existing employee', () async {
      // 1. Enroll existing employee in repository
      final List<double> existingVec = List<double>.filled(128, 0.5);
      await repo.createEmployee(
        code: 'EXISTING_EMP',
        name: 'Existing Person',
        embeddings: <List<double>>[existingVec],
        modelId: 'sface',
        dimension: 128,
      );

      // 2. Configure recognizer to return the same vector
      recognizer.embeddingToReturn = existingVec;

      session.start();

      // Complete all 5 poses
      for (int p = 0; p < 5; p++) {
        final double yaw = p == 1 ? 15.0 : (p == 2 ? -15.0 : 0.0);
        final double pitch = p == 3 ? 10.0 : (p == 4 ? -10.0 : 0.0);
        for (int f = 0; f < 3; f++) {
          await session.onFrame(
            face: createFace(yaw: yaw, pitch: pitch),
            quality: const QualityResult(issues: <QualityIssue>[]),
            alignedRgb112: dummyCrop,
          );
        }
      }

      // Check state is duplicateDetected with warning
      expect(session.state.status, EnrollmentStatus.duplicateDetected);
      expect(session.state.duplicateWarning, isNotNull);
      expect(
        session.state.duplicateWarning!.matchedEmployee.code,
        'EXISTING_EMP',
      );
      expect(
        session.state.duplicateWarning!.similarityScore,
        closeTo(1.0, 1e-4),
      );
    });
  });
}
