import 'package:camera/camera.dart';
import 'package:attendence/core/di/providers.dart';
import 'package:attendence/features/camera/domain/camera_service.dart';
import 'package:attendence/features/camera/domain/frame_data.dart';
import 'package:attendence/features/detection/domain/detected_face.dart';
import 'package:attendence/features/detection/domain/face_detector.dart';
import 'package:attendence/features/detection/presentation/detection_dev_screen.dart';
import 'package:attendence/l10n/app_localizations.dart';
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
  CameraDescription? currentCamera;

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

void main() {
  group('DetectionDevScreen', () {
    late _FakeCameraService fakeCamera;
    late _FakeFaceDetector fakeDetector;

    setUp(() {
      fakeCamera = _FakeCameraService();
      fakeDetector = _FakeFaceDetector();
    });

    Widget createTestApp() {
      return ProviderScope(
        overrides: [
          cameraServiceProvider.overrideWithValue(fakeCamera),
          faceDetectorProvider.overrideWithValue(fakeDetector),
        ],
        child: const MaterialApp(
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: <Locale>[Locale('en'), Locale('ar')],
          home: DetectionDevScreen(),
        ),
      );
    }

    testWidgets('shows permission required UI when permission is denied', (
      WidgetTester tester,
    ) async {
      fakeCamera.permissionStatus = CameraPermissionStatus.denied;

      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('shows loading or preview when permission is granted', (
      WidgetTester tester,
    ) async {
      fakeCamera.permissionStatus = CameraPermissionStatus.granted;

      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(find.byType(DetectionDevScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}
