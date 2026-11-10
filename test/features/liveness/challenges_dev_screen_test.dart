import 'package:attendence/core/di/providers.dart';
import 'package:attendence/features/camera/domain/camera_service.dart';
import 'package:attendence/features/camera/domain/frame_data.dart';
import 'package:attendence/features/detection/domain/detected_face.dart';
import 'package:attendence/features/detection/domain/face_detector.dart';
import 'package:attendence/features/liveness/domain/challenge_type.dart';
import 'package:attendence/features/liveness/presentation/challenges_dev_screen.dart';
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
  Future<void> dispose() async {
    isStreaming = false;
    isInitialized = false;
  }
}

class _FakeFaceDetector implements FaceDetector {
  List<DetectedFace> nextFaces = <DetectedFace>[];

  @override
  Future<List<DetectedFace>> detect(FrameData frame) async => nextFaces;

  @override
  Future<void> dispose() async {}
}

void main() {
  group('ChallengesDevScreen', () {
    late _FakeCameraService fakeCamera;
    late _FakeFaceDetector fakeDetector;

    setUp(() {
      fakeCamera = _FakeCameraService();
      fakeDetector = _FakeFaceDetector();
    });

    Widget createTestApp({
      Locale locale = const Locale('en'),
      ChallengeStepResult? initialStepResult,
    }) {
      return ProviderScope(
        overrides: [
          cameraServiceProvider.overrideWithValue(fakeCamera),
          faceDetectorProvider.overrideWithValue(fakeDetector),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
          home: ChallengesDevScreen(
            initialStepResultForTesting: initialStepResult,
          ),
        ),
      );
    }

    testWidgets('renders screen controls, app bar, and telemetry panel', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(find.byType(ChallengesDevScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.shuffle), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.flash_on), findsOneWidget);
    });

    testWidgets('reset button restarts current challenges', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      expect(find.byType(ChallengesDevScreen), findsOneWidget);
    });

    testWidgets('shuffle button generates new random challenges', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.shuffle));
      await tester.pump();

      expect(find.byType(ChallengesDevScreen), findsOneWidget);
    });

    testWidgets(
      'when challenge fails, displays Failed reason, hides numbers, and shows retry button',
      (WidgetTester tester) async {
        const ChallengeStepResult failedResult = ChallengeStepResult(
          status: ChallengeMachineStatus.failed,
          currentChallenge: null,
          challengeIndex: 1,
          totalChallenges: 3,
          stepProgress: 0.0,
          overallProgress: 0.33,
          failureReason: ChallengeFailureReason.trackingLost,
        );

        await tester.pumpWidget(createTestApp(initialStepResult: failedResult));
        await tester.pump();

        // 1. Verify it says Failed and NEVER says Passed
        expect(find.text('Failed (Face lost)'), findsOneWidget);
        expect(find.text('Passed'), findsNothing);

        // 2. Verify numbers panel (temporal and face telemetry) is hidden
        expect(find.text('Temporal Confidence'), findsNothing);
        expect(find.text('Micro-motion'), findsNothing);
        expect(find.text('Loop Detection'), findsNothing);
        expect(find.text('Yaw / Base'), findsNothing);
        expect(find.text('Pitch'), findsNothing);

        // 3. Verify retry button is shown
        final Finder retryButtonFinder = find.byKey(
          const Key('dev_challenges_retry_button'),
        );
        expect(retryButtonFinder, findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        // 4. Tap retry button -> resets state and numbers panel reappears
        await tester.tap(retryButtonFinder);
        await tester.pump();

        expect(
          find.byKey(const Key('dev_challenges_retry_button')),
          findsNothing,
        );
        expect(find.text('Temporal Confidence'), findsOneWidget);
      },
    );

    testWidgets(
      'when challenge fails in Arabic, displays localized failure text without Passed',
      (WidgetTester tester) async {
        const ChallengeStepResult failedResult = ChallengeStepResult(
          status: ChallengeMachineStatus.failed,
          currentChallenge: null,
          challengeIndex: 1,
          totalChallenges: 3,
          stepProgress: 0.0,
          overallProgress: 0.33,
          failureReason: ChallengeFailureReason.trackingLost,
        );

        await tester.pumpWidget(
          createTestApp(
            locale: const Locale('ar'),
            initialStepResult: failedResult,
          ),
        );
        await tester.pump();

        // Displays localized failure text and does not say ناجح (Passed)
        expect(find.text('فاشل (فُقد الوجه)'), findsOneWidget);
        expect(find.text('ناجح'), findsNothing);

        // Shows Arabic retry button
        expect(find.text('إعادة المحاولة'), findsOneWidget);
      },
    );
  });
}
