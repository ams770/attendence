import 'package:attendence/features/camera/domain/camera_service.dart';
import 'package:attendence/features/camera/domain/frame_data.dart';
import 'package:attendence/features/detection/domain/detected_face.dart';
import 'package:attendence/features/detection/domain/face_detector.dart';
import 'package:attendence/features/device/domain/device_tier.dart';
import 'package:attendence/features/liveness/domain/attempt_log.dart';
import 'package:attendence/features/liveness/domain/challenge_type.dart';
import 'package:attendence/features/liveness/domain/liveness_session.dart';
import 'package:attendence/features/liveness/domain/session_policy.dart';
import 'package:attendence/features/liveness/presentation/result_screen.dart';
import 'package:attendence/features/liveness/presentation/verification_screen.dart';
import 'package:attendence/l10n/app_localizations.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCameraService implements CameraService {
  @override
  CameraPermissionStatus permissionStatus = CameraPermissionStatus.granted;

  @override
  bool isInitialized = false;

  @override
  bool isStreaming = false;

  @override
  CameraController? controller;

  @override
  CameraDescription? currentCamera = const CameraDescription(
    name: 'front',
    lensDirection: CameraLensDirection.front,
    sensorOrientation: 0,
  );

  @override
  Future<CameraPermissionStatus> checkPermission() async => permissionStatus;

  @override
  Future<CameraPermissionStatus> requestPermission() async => permissionStatus;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<void> initialize({
    required ResolutionPreset resolutionPreset,
    CameraLensDirection lensDirection = CameraLensDirection.front,
  }) async {
    isInitialized = true;
  }

  @override
  Future<void> startImageStream(
    void Function(CameraImage image) onFrame,
  ) async {
    isStreaming = true;
  }

  @override
  Future<void> stopImageStream() async {
    isStreaming = false;
  }

  @override
  Future<void> pausePreview() async {}

  @override
  Future<void> resumePreview() async {}

  @override
  Future<void> lockExposure() async {}

  @override
  Future<void> unlockExposure() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeFaceDetector implements FaceDetector {
  @override
  Future<List<DetectedFace>> detect(FrameData frame) async => <DetectedFace>[];

  @override
  Future<void> dispose() async {}
}

Widget createTestApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  group('VerificationScreen and ResultScreen UI', () {
    late _FakeCameraService fakeCamera;
    late _FakeFaceDetector fakeDetector;

    setUp(() {
      fakeCamera = _FakeCameraService();
      fakeDetector = _FakeFaceDetector();
    });

    testWidgets(
      'VerificationScreen renders preview, title, timer countdown, and cancel button',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestApp(
            VerificationScreen(
              policy: SessionPolicy.attendance,
              cameraServiceOverride: fakeCamera,
              faceDetectorOverride: fakeDetector,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Face Verification'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);
        expect(find.textContaining('30s remaining'), findsOneWidget);
        expect(find.text('Position your face inside the oval'), findsOneWidget);
      },
    );

    testWidgets(
      'VerificationScreen shows permission required UI when camera is denied',
      (WidgetTester tester) async {
        fakeCamera.permissionStatus = CameraPermissionStatus.denied;

        await tester.pumpWidget(
          createTestApp(
            VerificationScreen(
              cameraServiceOverride: fakeCamera,
              faceDetectorOverride: fakeDetector,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Grant Permission'), findsOneWidget);
        expect(
          find.text(
            'Camera permission is required to stream and verify frames.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ResultScreen renders passed state with metrics and Done button',
      (WidgetTester tester) async {
        final DateTime now = DateTime(2026, 11, 7, 12, 0, 0);
        final AttemptLog log = AttemptLog(
          attemptId: 'test-1',
          timestamp: now,
          policy: 'attendance',
          passed: true,
          durationMs: 4200,
          meanPassiveScore: 0.942,
          passiveSamplesCount: 8,
          passivePassingRatio: 1.0,
          perModelScores: const <String, double>{'MiniFASNetV2': 0.942},
          temporalConfidence: 0.88,
          microMotionScore: 0.90,
          loopScore: 0.85,
          rigidityScore: 0.89,
          deviceTier: 'high',
          challengesCompleted: const <String>['lookStraight', 'blink'],
        );

        final LiveSessionResult passedResult = LiveSessionResult(
          passed: true,
          meanPassiveScore: 0.942,
          framesAboveThreshold: 8,
          totalPassiveSamples: 8,
          perModelScores: const <String, double>{'MiniFASNetV2': 0.942},
          challengeResults: <ChallengeRecord>[
            ChallengeRecord(
              type: ChallengeType.lookStraight,
              startedAt: now,
              completedAt: now,
              passed: true,
              framesObserved: 3,
            ),
          ],
          temporalConfidence: 0.88,
          deviceTier: DeviceTier.high,
          duration: const Duration(milliseconds: 4200),
          startedAt: now,
          completedAt: now.add(const Duration(milliseconds: 4200)),
          attemptLog: log,
        );

        await tester.pumpWidget(
          createTestApp(ResultScreen(result: passedResult)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Liveness Verified'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
        expect(find.text('Duration: 4200 ms'), findsOneWidget);
        expect(find.text('Mean Passive Score: 0.942'), findsOneWidget);
        expect(find.text('Temporal Confidence: 0.880'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Try Again'), findsNothing);
      },
    );

    testWidgets(
      'ResultScreen renders failed state with reason and Try Again button',
      (WidgetTester tester) async {
        final DateTime now = DateTime(2026, 11, 7, 12, 0, 0);
        final AttemptLog log = AttemptLog(
          attemptId: 'test-2',
          timestamp: now,
          policy: 'attendance',
          passed: false,
          failureReason: 'timeout',
          durationMs: 30000,
          meanPassiveScore: 0.80,
          passiveSamplesCount: 2,
          passivePassingRatio: 0.5,
          perModelScores: const <String, double>{'MiniFASNetV2': 0.80},
          temporalConfidence: 0.40,
          microMotionScore: 0.40,
          loopScore: 0.40,
          rigidityScore: 0.40,
          deviceTier: 'mid',
          challengesCompleted: const <String>[],
        );

        final LiveSessionResult failedResult = LiveSessionResult(
          passed: false,
          failureReason: SessionFailureReason.timeout,
          meanPassiveScore: 0.80,
          framesAboveThreshold: 1,
          totalPassiveSamples: 2,
          perModelScores: const <String, double>{'MiniFASNetV2': 0.80},
          challengeResults: const <ChallengeRecord>[],
          temporalConfidence: 0.40,
          deviceTier: DeviceTier.mid,
          duration: const Duration(seconds: 30),
          startedAt: now,
          completedAt: now.add(const Duration(seconds: 30)),
          attemptLog: log,
        );

        await tester.pumpWidget(
          createTestApp(ResultScreen(result: failedResult)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Verification Failed'), findsWidgets);
        expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
        expect(find.text('Session timed out'), findsOneWidget);
        expect(find.text('Try Again'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      },
    );
  });
}
