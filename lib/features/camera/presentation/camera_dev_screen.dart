import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/utils/affine_matrix.dart';
import '../../../core/utils/bmp_helper.dart';
import '../../../l10n/app_localizations.dart';
import '../../device/domain/device_benchmark.dart';
import '../../device/domain/device_tier.dart';
import '../../ml/sampler/pixel_sampler.dart';
import '../domain/camera_service.dart';
import '../domain/frame_data.dart';
import '../domain/frame_geometry.dart';
import '../domain/frame_throttler.dart';

/// Developer screen for verifying camera stream, live FPS, per-frame latency,
/// upright un-mirrored pixel sampling, and hardware tier classification.
class CameraDevScreen extends ConsumerStatefulWidget {
  const CameraDevScreen({super.key});

  @override
  ConsumerState<CameraDevScreen> createState() => _CameraDevScreenState();
}

class _CameraDevScreenState extends ConsumerState<CameraDevScreen>
    with WidgetsBindingObserver {
  static const int _thumbW = 120;
  static const int _thumbH = 160;

  CameraService? _cameraService;
  FrameThrottler? _throttler;
  Uint8List? _reusableThumbBuffer;
  Uint8List? _thumbnailBmpBytes;

  bool _isInitializing = true;
  bool _isBenchmarking = false;
  String? _errorMessage;

  double _measuredFps = 0.0;
  int _fpsFrameCount = 0;
  DateTime _fpsWindowStart = DateTime.now();

  double _lastFrameLatencyMs = 0.0;
  int _droppedCount = 0;
  int _processedCount = 0;

  DeviceTier? _manualOverride;
  DeviceTier _currentTier = DeviceTier.mid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reusableThumbBuffer = Uint8List(_thumbW * _thumbH * 3);
    _initCameraPipeline();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService?.stopImageStream();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraService == null || !_cameraService!.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraService?.pausePreview();
    } else if (state == AppLifecycleState.resumed) {
      _cameraService?.resumePreview();
    }
  }

  Future<void> _initCameraPipeline() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      final DeviceBenchmark benchmark = ref.read(deviceBenchmarkProvider);
      _manualOverride = await benchmark.getManualOverride();
      _currentTier = await benchmark.getEffectiveTier();

      final TierProfile profile = TierProfile.fromTier(
        _currentTier,
        hasInt8Model: await benchmark.hasInt8Model(),
      );

      _throttler = FrameThrottler(
        clock: ref.read(clockProvider),
        targetFps: profile.analysisFps,
      );

      _cameraService = ref.read(cameraServiceProvider);
      await _cameraService!.initialize(
        resolutionPreset: profile.cameraPreset,
        lensDirection: CameraLensDirection.front,
      );

      await _cameraService!.startImageStream(_onCameraFrame);

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (!mounted || _throttler == null) return;

    final DateTime now = DateTime.now();
    if (!_throttler!.shouldProcess()) {
      if (mounted) {
        setState(() {
          _droppedCount = _throttler!.framesDropped;
        });
      }
      return;
    }

    _throttler!.onFrameStarted();
    final Stopwatch sw = Stopwatch()..start();

    try {
      final CameraDescription? currentCam = _cameraService?.currentCamera;
      final int rotation = currentCam?.sensorOrientation ?? 0;
      final CameraLensDirection lensDir =
          currentCam?.lensDirection ?? CameraLensDirection.front;

      final FrameData frame = FrameData.fromCameraImage(
        image,
        sensorRotation: rotation,
        lensDirection: lensDir,
        timestamp: now,
      );

      final FrameGeometry geometry = FrameGeometry(
        rawWidth: frame.width,
        rawHeight: frame.height,
        rotation: frame.sensorRotation,
      );

      // Upright to output thumbnail scale matrix
      final double sx = _thumbW / geometry.uprightWidth;
      final double sy = _thumbH / geometry.uprightHeight;
      final AffineMatrix uprightToThumb = AffineMatrix.scale(sx, sy);

      final PixelSampler sampler = ref.read(pixelSamplerProvider);
      sampler.warpAffine(
        frame,
        uprightToThumb,
        _thumbW,
        _thumbH,
        outBuffer: _reusableThumbBuffer,
      );

      // Generate BMP bytes for thumbnail display
      final Uint8List bmp = BmpHelper.createBmpFromRgb(
        _reusableThumbBuffer!,
        _thumbW,
        _thumbH,
      );

      sw.stop();
      final Duration elapsed = sw.elapsed;
      _throttler!.onFrameCompleted(elapsed);

      // Update FPS window
      _fpsFrameCount++;
      final Duration windowElapsed = now.difference(_fpsWindowStart);
      if (windowElapsed.inMilliseconds >= 1000) {
        _measuredFps = (_fpsFrameCount * 1000.0) / windowElapsed.inMilliseconds;
        _fpsFrameCount = 0;
        _fpsWindowStart = now;
      }

      if (mounted) {
        setState(() {
          _thumbnailBmpBytes = bmp;
          _lastFrameLatencyMs = elapsed.inMicroseconds / 1000.0;
          _processedCount = _throttler!.framesProcessed;
          _droppedCount = _throttler!.framesDropped;
        });
      }
    } catch (_) {
      sw.stop();
      _throttler!.onFrameCompleted(sw.elapsed);
    }
  }

  Future<void> _handleOverrideChanged(DeviceTier? newOverride) async {
    final DeviceBenchmark benchmark = ref.read(deviceBenchmarkProvider);
    await benchmark.setTierOverride(newOverride);
    _manualOverride = newOverride;
    _currentTier = await benchmark.getEffectiveTier();

    // Re-initialize camera and throttler with new tier profile
    await _cameraService?.stopImageStream();
    await _initCameraPipeline();
  }

  Future<void> _handleRerunBenchmark() async {
    setState(() {
      _isBenchmarking = true;
    });

    try {
      final DeviceBenchmark benchmark = ref.read(deviceBenchmarkProvider);
      final BenchmarkReport report = await benchmark.runBenchmark();
      _currentTier = report.effectiveTier;
      _manualOverride = report.overrideTier;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Benchmark failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBenchmarking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devCameraTitle)),
      body: SafeArea(
        child: _isInitializing
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _buildErrorView(l10n, theme)
            : _buildDevContent(l10n, theme),
      ),
    );
  }

  Widget _buildErrorView(AppLocalizations l10n, ThemeData theme) {
    final bool isPermanentlyDenied =
        _cameraService?.permissionStatus ==
        CameraPermissionStatus.permanentlyDenied;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(
            Icons.camera_alt_outlined,
            size: 64.0,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16.0),
          Text(
            l10n.devCameraPermissionRequired,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8.0),
          Text(
            _errorMessage ?? '',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24.0),
          FilledButton(
            onPressed: isPermanentlyDenied
                ? () => _cameraService?.openSettings()
                : _initCameraPipeline,
            child: Text(
              isPermanentlyDenied
                  ? l10n.devCameraOpenSettings
                  : l10n.devCameraGrantPermission,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevContent(AppLocalizations l10n, ThemeData theme) {
    final CameraController? controller = _cameraService?.controller;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Real-time telemetry cards
          _buildMetricsBar(l10n, theme),
          const SizedBox(height: 16.0),

          // Live Camera Preview
          if (controller != null && controller.value.isInitialized)
            AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: CameraPreview(controller),
              ),
            ),
          const SizedBox(height: 16.0),

          // PixelSampler thumbnail and inspection card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.devCameraThumbnailTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Row(
                    children: <Widget>[
                      Container(
                        width: _thumbW.toDouble(),
                        height: _thumbH.toDouble(),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: _thumbnailBmpBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.memory(
                                  _thumbnailBmpBytes!,
                                  width: _thumbW.toDouble(),
                                  height: _thumbH.toDouble(),
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                              )
                            : const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                ),
                              ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${l10n.devCameraProcessedFrames}: $_processedCount',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              '${l10n.devCameraDroppedFrames}: $_droppedCount',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              '${l10n.devCameraLatencyLabel}: ${_lastFrameLatencyMs.toStringAsFixed(1)} ms',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),

          // Controls: Manual tier override and re-run benchmark
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.devCameraTierOverrideLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  DropdownButtonFormField<DeviceTier?>(
                    initialValue: _manualOverride,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8.0,
                      ),
                    ),
                    items: <DropdownMenuItem<DeviceTier?>>[
                      DropdownMenuItem<DeviceTier?>(
                        value: null,
                        child: Text(l10n.devCameraTierAuto),
                      ),
                      DropdownMenuItem<DeviceTier?>(
                        value: DeviceTier.low,
                        child: Text(l10n.devCameraTierLow),
                      ),
                      DropdownMenuItem<DeviceTier?>(
                        value: DeviceTier.mid,
                        child: Text(l10n.devCameraTierMid),
                      ),
                      DropdownMenuItem<DeviceTier?>(
                        value: DeviceTier.high,
                        child: Text(l10n.devCameraTierHigh),
                      ),
                    ],
                    onChanged: _handleOverrideChanged,
                  ),
                  const SizedBox(height: 16.0),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isBenchmarking ? null : _handleRerunBenchmark,
                      child: _isBenchmarking
                          ? Text(l10n.devCameraBenchmarking)
                          : Text(l10n.devCameraRerunBenchmark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsBar(AppLocalizations l10n, ThemeData theme) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: <Widget>[
                  Text(
                    l10n.devCameraFpsLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    _measuredFps.toStringAsFixed(1),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: Card(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: <Widget>[
                  Text(
                    l10n.devCameraLatencyLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    '${_lastFrameLatencyMs.toStringAsFixed(1)} ms',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: Card(
            color: theme.colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: <Widget>[
                  Text(
                    l10n.devCameraTierLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    _currentTier.name.toUpperCase(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
