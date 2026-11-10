import 'package:attendence/core/di/providers.dart';
import 'package:attendence/features/camera/domain/camera_service.dart';
import 'package:attendence/features/camera/domain/frame_data.dart';
import 'package:attendence/features/detection/domain/detected_face.dart';
import 'package:attendence/features/detection/domain/face_detector.dart';
import 'package:attendence/features/liveness/domain/passive_liveness_engine.dart';
import 'package:attendence/features/liveness/presentation/passive_dev_screen.dart';
import 'package:attendence/features/ml/worker/worker_protocol.dart';
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
  List<DetectedFace> mockFaces = <DetectedFace>[];

  @override
  Future<List<DetectedFace>> detect(FrameData frame) async => mockFaces;

  @override
  Future<void> dispose() async {}
}

class _FakePassiveEngine implements PassiveLivenessEngine {
  @override
  Future<PassiveFrameResult> evaluateFrame({
    required TransferableFrameData frame,
    required Rect faceRect,
    required List<String> modelNames,
    PassivePreprocessConfig? preprocessConfig,
  }) async {
    final Map<String, PassiveModelResult> results =
        <String, PassiveModelResult>{};
    for (final String m in modelNames) {
      results[m] = PassiveModelResult(
        modelName: m,
        realProbability: 0.95,
        rawScores: const <double>[0.02, 0.95, 0.03],
        latencyMs: 22.0,
      );
    }
    return PassiveFrameResult(
      modelResults: results,
      meanRealProbability: 0.95,
      totalLatencyMs: 22.0 * modelNames.length,
    );
  }
}

void main() {
  group('PassiveDevScreen', () {
    late _FakeCameraService fakeCamera;
    late _FakeFaceDetector fakeDetector;
    late _FakePassiveEngine fakeEngine;

    setUp(() {
      fakeCamera = _FakeCameraService();
      fakeDetector = _FakeFaceDetector();
      fakeEngine = _FakePassiveEngine();
    });

    Widget createTestApp() {
      return ProviderScope(
        overrides: [
          cameraServiceProvider.overrideWithValue(fakeCamera),
          faceDetectorProvider.overrideWithValue(fakeDetector),
          passiveLivenessEngineProvider.overrideWithValue(fakeEngine),
        ],
        child: const MaterialApp(
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: <Locale>[Locale('en'), Locale('ar')],
          home: PassiveDevScreen(),
        ),
      );
    }

    testWidgets(
      'shows permission required UI when camera permission is denied',
      (WidgetTester tester) async {
        fakeCamera.permissionStatus = CameraPermissionStatus.denied;

        await tester.pumpWidget(createTestApp());
        await tester.pump();

        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      },
    );

    testWidgets(
      'renders screen controls and app bar when permission is granted',
      (WidgetTester tester) async {
        fakeCamera.permissionStatus = CameraPermissionStatus.granted;

        await tester.pumpWidget(createTestApp());
        await tester.pump();

        expect(find.byType(PassiveDevScreen), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsOneWidget);
        expect(find.byIcon(Icons.share), findsOneWidget);
      },
    );
  });
}
