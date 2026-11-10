import 'package:camera/camera.dart';
import 'package:attendence/core/di/providers.dart';
import 'package:attendence/features/camera/domain/camera_service.dart';
import 'package:attendence/features/camera/presentation/camera_dev_screen.dart';
import 'package:attendence/features/device/domain/device_benchmark.dart';
import 'package:attendence/features/device/domain/device_tier.dart';
import 'package:attendence/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _FakeBenchmark extends Fake implements DeviceBenchmark {
  @override
  Future<DeviceTier> getEffectiveTier() async => DeviceTier.high;

  @override
  Future<DeviceTier?> getManualOverride() async => null;

  @override
  Future<bool> hasInt8Model() async => false;

  @override
  Future<void> setTierOverride(DeviceTier? override) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('CameraDevScreen renders metrics, thumbnail card and controls', (
    WidgetTester tester,
  ) async {
    final _FakeCameraService fakeCamera = _FakeCameraService();
    final _FakeBenchmark fakeBenchmark = _FakeBenchmark();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cameraServiceProvider.overrideWithValue(fakeCamera),
          deviceBenchmarkProvider.overrideWithValue(fakeBenchmark),
        ],
        child: const MaterialApp(
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: CameraDevScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify title and metrics
    expect(find.text('Camera & Pipeline Dev'), findsOneWidget);
    expect(find.text('FPS'), findsOneWidget);
    expect(find.text('Latency'), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);

    // Verify thumbnail section and controls
    expect(find.text('PixelSampler Upright RGB (Un-mirrored)'), findsOneWidget);
    expect(find.text('Hardware Tier Override'), findsOneWidget);
    expect(find.text('Re-run Benchmark'), findsOneWidget);
  });
}
