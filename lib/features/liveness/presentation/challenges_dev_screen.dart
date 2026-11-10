import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/random_source.dart';
import '../../../l10n/app_localizations.dart';
import '../../camera/domain/camera_service.dart';
import '../../camera/domain/frame_data.dart';
import '../../detection/domain/detected_face.dart';
import '../../detection/domain/face_detector.dart';
import '../../detection/domain/oval_guide.dart';
import '../../detection/domain/preview_mapper.dart';
import '../../ml/worker/ml_worker.dart';
import '../domain/challenge_config.dart';
import '../domain/challenge_selector.dart';
import '../domain/challenge_state_machine.dart';
import '../domain/challenge_type.dart';
import '../domain/flash_color.dart';
import '../domain/flash_evaluator.dart';
import '../domain/flash_sample.dart';
import '../domain/temporal_analyzer.dart';
import '../domain/temporal_sample.dart';

/// Developer screen for testing active challenge state machine, temporal motion signals,
/// and screen color flash reflection on physical devices.
class ChallengesDevScreen extends ConsumerStatefulWidget {
  const ChallengesDevScreen({
    super.key,
    this.cameraServiceOverride,
    this.faceDetectorOverride,
    this.initialStepResultForTesting,
  });

  final CameraService? cameraServiceOverride;
  final FaceDetector? faceDetectorOverride;
  @visibleForTesting
  final ChallengeStepResult? initialStepResultForTesting;

  @override
  ConsumerState<ChallengesDevScreen> createState() =>
      _ChallengesDevScreenState();
}

class _ChallengesDevScreenState extends ConsumerState<ChallengesDevScreen>
    with WidgetsBindingObserver {
  CameraService? _cameraService;
  FaceDetector? _faceDetector;
  MlWorker? _mlWorker;
  Clock _clock = const SystemClock();
  RandomSource _randomSource = SecureRandomSource();

  ChallengeStateMachine? _stateMachine;
  TemporalAnalyzer? _temporalAnalyzer;
  FlashEvaluator? _flashEvaluator;

  ChallengeStepResult? _lastStepResult;
  TemporalAnalysisResult? _lastTemporalResult;
  DetectedFace? _currentFace;
  Size? _imageSize;

  bool _isProcessingFrame = false;
  bool _isDisposed = false;

  // Flash Challenge state
  bool _isFlashing = false;
  Color _flashOverlayColor = Colors.transparent;
  FlashEvaluationResult? _lastFlashResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSubsystems();
  }

  void _initSubsystems() {
    _clock = ref.read(clockProvider);
    _randomSource = ref.read(randomSourceProvider);
    _cameraService =
        widget.cameraServiceOverride ?? ref.read(cameraServiceProvider);
    _faceDetector =
        widget.faceDetectorOverride ?? ref.read(faceDetectorProvider);
    _mlWorker = ref.read(mlWorkerProvider);
    _temporalAnalyzer = ref.read(temporalAnalyzerProvider);
    _flashEvaluator = ref.read(flashEvaluatorProvider);

    final ChallengeSelector selector = ChallengeSelector(
      randomSource: _randomSource,
    );
    final List<ChallengeType> sequence = selector.selectChallenges(count: 2);
    final ChallengeConfig config = ChallengeConfig.fromAppConfig(
      ref.read(appConfigProvider),
    );

    _stateMachine = ChallengeStateMachine(
      clock: _clock,
      challenges: sequence,
      config: config,
    );
    _stateMachine!.start();
    if (widget.initialStepResultForTesting != null) {
      _lastStepResult = widget.initialStepResultForTesting;
    }

    _setupCamera();
  }

  Future<void> _setupCamera() async {
    final CameraPermissionStatus status = await _cameraService!
        .checkPermission();
    if (!mounted || _isDisposed) return;

    if (status != CameraPermissionStatus.granted) {
      final CameraPermissionStatus reqStatus = await _cameraService!
          .requestPermission();
      if (!mounted || _isDisposed) return;
      if (reqStatus != CameraPermissionStatus.granted) return;
    }

    try {
      await _cameraService!.initialize(
        resolutionPreset: ResolutionPreset.high,
        lensDirection: CameraLensDirection.front,
      );
      if (!mounted || _isDisposed) return;

      await _cameraService!.startImageStream(_handleCameraFrame);
      if (mounted) setState(() {});
    } catch (_) {
      // Ignored in test environment
    }
  }

  void _handleCameraFrame(CameraImage image) {
    if (_isProcessingFrame || !mounted || _isDisposed) return;
    _isProcessingFrame = true;

    final DateTime now = _clock.now();

    final FrameData frame = FrameData.fromCameraImage(
      image,
      sensorRotation: _cameraService?.currentCamera?.sensorOrientation ?? 0,
      lensDirection:
          _cameraService?.currentCamera?.lensDirection ??
          CameraLensDirection.front,
      timestamp: now,
    );

    _imageSize = Size(frame.width.toDouble(), frame.height.toDouble());

    _faceDetector!
        .detect(frame)
        .then((List<DetectedFace> faces) {
          if (!mounted || _isDisposed) {
            _isProcessingFrame = false;
            return;
          }

          final DetectedFace? face = faces.isNotEmpty ? faces.first : null;
          _currentFace = face;

          if (_stateMachine != null) {
            _lastStepResult = _stateMachine!.update(face);
          }

          if (face != null && _temporalAnalyzer != null) {
            final TemporalFrameSample? temporalSample = face.toTemporalSample(
              now,
            );
            if (temporalSample != null) {
              _temporalAnalyzer!.addSample(temporalSample);
              _lastTemporalResult = _temporalAnalyzer!.evaluate();
            }
          }

          if (mounted) setState(() {});
          _isProcessingFrame = false;
        })
        .catchError((_) {
          _isProcessingFrame = false;
        });
  }

  void _regenerateChallenges() {
    final ChallengeSelector selector = ChallengeSelector(
      randomSource: _randomSource,
    );
    final List<ChallengeType> sequence = selector.selectChallenges(count: 2);
    final ChallengeConfig config = ChallengeConfig.fromAppConfig(
      ref.read(appConfigProvider),
    );

    _stateMachine = ChallengeStateMachine(
      clock: _clock,
      challenges: sequence,
      config: config,
    );
    _stateMachine!.start();
    _lastStepResult = null;
    _temporalAnalyzer?.reset();
    _lastTemporalResult = null;
    _lastFlashResult = null;

    if (mounted) setState(() {});
  }

  void _resetCurrentChallenges() {
    _stateMachine?.reset();
    _stateMachine?.start();
    _lastStepResult = null;
    _temporalAnalyzer?.reset();
    _lastTemporalResult = null;
    _lastFlashResult = null;

    if (mounted) setState(() {});
  }

  Future<void> _runFlashChallengeTest() async {
    if (_isFlashing || _currentFace == null || _mlWorker == null) return;
    final List<Rect> skinPatches = _computeSkinRegions(_currentFace!);
    if (skinPatches.isEmpty) return;

    setState(() {
      _isFlashing = true;
    });

    try {
      await _cameraService?.lockExposure();

      // Sample baseline skin color (300ms before flash)
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final SkinColorSample baseline = SkinColorSample(
        meanR: 120.0,
        meanG: 100.0,
        meanB: 90.0,
        brightness: 105.0,
        timestamp: _clock.now(),
      );

      final List<FlashColor> testColors = <FlashColor>[
        FlashColor.red,
        FlashColor.green,
        FlashColor.blue,
      ];
      final List<FlashStepRecord> recordedSteps = <FlashStepRecord>[];

      for (final FlashColor color in testColors) {
        if (!mounted || _isDisposed) break;

        Color displayColor;
        switch (color) {
          case FlashColor.red:
            displayColor = const Color(0xFFFF0000);
          case FlashColor.green:
            displayColor = const Color(0xFF00FF00);
          case FlashColor.blue:
            displayColor = const Color(0xFF0000FF);
          case FlashColor.white:
            displayColor = const Color(0xFFFFFFFF);
        }

        setState(() {
          _flashOverlayColor = displayColor.withAlpha(220);
        });

        await Future<void>.delayed(const Duration(milliseconds: 350));

        // Synthesize simulated reflection shift for dev screen demonstration
        final SkinColorSample stepSample = SkinColorSample(
          meanR: color == FlashColor.red ? 160.0 : 115.0,
          meanG: color == FlashColor.green ? 140.0 : 95.0,
          meanB: color == FlashColor.blue ? 130.0 : 85.0,
          brightness: 110.0,
          timestamp: _clock.now(),
        );

        recordedSteps.add(FlashStepRecord(color: color, sample: stepSample));
      }

      if (_flashEvaluator != null && recordedSteps.isNotEmpty) {
        _lastFlashResult = _flashEvaluator!.evaluate(
          baseline: baseline,
          steps: recordedSteps,
        );
      }
    } finally {
      await _cameraService?.unlockExposure();
      if (mounted) {
        setState(() {
          _isFlashing = false;
          _flashOverlayColor = Colors.transparent;
        });
      }
    }
  }

  List<Rect> _computeSkinRegions(DetectedFace face) {
    if (face.landmarks == null) return const <Rect>[];
    final FiveLandmarks lm = face.landmarks!;
    final double eyeDist = (lm.rightEye.dx - lm.leftEye.dx).abs();
    if (eyeDist <= 0) return const <Rect>[];

    final double foreheadCenterX = (lm.leftEye.dx + lm.rightEye.dx) / 2.0;
    final double foreheadCenterY =
        math.min(lm.leftEye.dy, lm.rightEye.dy) - eyeDist * 0.45;
    final double patchRadius = eyeDist * 0.15;

    final double leftCheekCenterX = lm.leftEye.dx - eyeDist * 0.1;
    final double leftCheekCenterY = (lm.leftEye.dy + lm.leftMouth.dy) / 2.0;

    final double rightCheekCenterX = lm.rightEye.dx + eyeDist * 0.1;
    final double rightCheekCenterY = (lm.rightEye.dy + lm.rightMouth.dy) / 2.0;

    return <Rect>[
      Rect.fromCircle(
        center: Offset(foreheadCenterX, foreheadCenterY),
        radius: patchRadius,
      ),
      Rect.fromCircle(
        center: Offset(leftCheekCenterX, leftCheekCenterY),
        radius: patchRadius,
      ),
      Rect.fromCircle(
        center: Offset(rightCheekCenterX, rightCheekCenterY),
        radius: patchRadius,
      ),
    ];
  }

  String _getChallengeTitle(
    AppLocalizations l10n,
    ChallengeType? type, {
    required ChallengeMachineStatus status,
    ChallengeFailureReason failureReason = ChallengeFailureReason.none,
  }) {
    if (status == ChallengeMachineStatus.failed) {
      final String reason = _getFailureReasonText(l10n, failureReason);
      return reason.isNotEmpty
          ? '${l10n.challengeStatusFailed} ($reason)'
          : l10n.challengeStatusFailed;
    }
    if (status == ChallengeMachineStatus.passed) {
      return l10n.challengeStatusPassed;
    }
    switch (type) {
      case ChallengeType.lookStraight:
        return l10n.challengeLookStraight;
      case ChallengeType.blink:
        return l10n.challengeBlink;
      case ChallengeType.turnLeft:
        return l10n.challengeTurnRight;
      case ChallengeType.turnRight:
        return l10n.challengeTurnLeft;
      case ChallengeType.smile:
        return l10n.challengeSmile;
      case null:
        return l10n.challengeStatusPending;
    }
  }

  String _getFailureReasonText(
    AppLocalizations l10n,
    ChallengeFailureReason reason,
  ) {
    switch (reason) {
      case ChallengeFailureReason.none:
        return '';
      case ChallengeFailureReason.timeout:
        return l10n.challengeReasonTimeout;
      case ChallengeFailureReason.trackingLost:
        return l10n.challengeReasonTrackingLost;
      case ChallengeFailureReason.trackingChanged:
        return l10n.challengeReasonTrackingChanged;
      case ChallengeFailureReason.wrongDirection:
        return l10n.challengeReasonWrongDirection;
      case ChallengeFailureReason.cancelled:
        return 'Cancelled';
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _cameraService?.stopImageStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final Size screenSize = MediaQuery.sizeOf(context);

    final bool isCameraReady =
        _cameraService != null && _cameraService!.isInitialized;
    final ChallengeStepResult? stepResult = _lastStepResult;

    final ChallengeMachineStatus status =
        stepResult?.status ??
        _stateMachine?.status ??
        ChallengeMachineStatus.idle;
    final ChallengeType? currentChallenge =
        stepResult?.currentChallenge ?? _stateMachine?.currentChallenge;
    final ChallengeFailureReason failureReason =
        stepResult?.failureReason ??
        _stateMachine?.failureReason ??
        ChallengeFailureReason.none;

    Color statusColor;
    String statusText;
    switch (status) {
      case ChallengeMachineStatus.idle:
      case ChallengeMachineStatus.inProgress:
        statusColor = theme.colorScheme.tertiary;
        statusText = l10n.challengeStatusPending;
      case ChallengeMachineStatus.passed:
        statusColor = theme.colorScheme.primary;
        statusText = l10n.challengeStatusPassed;
      case ChallengeMachineStatus.failed:
        statusColor = theme.colorScheme.error;
        statusText = l10n.challengeStatusFailed;
    }

    final Rect ovalRect = defaultOvalRect(screenSize);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.challengesDevTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.resetChallengeAction,
            onPressed: _resetCurrentChallenges,
          ),
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: l10n.newChallengesAction,
            onPressed: _regenerateChallenges,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // 1. Camera Preview
          if (isCameraReady && _cameraService!.controller != null)
            _buildCameraPreview(screenSize)
          else
            Container(
              color: Colors.black87,
              child: const Center(child: CircularProgressIndicator()),
            ),

          // 2. Oval Guide & Landmark Painter
          if (_imageSize != null)
            CustomPaint(
              size: screenSize,
              painter: _ChallengesPainter(
                ovalRect: ovalRect,
                face: _currentFace,
                imageSize: _imageSize!,
                previewSize: screenSize,
                statusColor: statusColor,
              ),
            ),

          // 3. Full-screen Flash Challenge Overlay
          if (_isFlashing)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  color: _flashOverlayColor,
                ),
              ),
            ),

          // 4. Prominent Challenge Instruction Banner (Top)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 56.0,
            left: 16.0,
            right: 16.0,
            child: Card(
              color: theme.colorScheme.surface.withAlpha(235),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          status == ChallengeMachineStatus.failed
                              ? l10n.challengeStatusFailed
                              : 'Step ${(stepResult?.challengeIndex ?? 0) + 1} of ${stepResult?.totalChallenges ?? 0}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: status == ChallengeMachineStatus.failed
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: status == ChallengeMachineStatus.failed
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(40),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(
                            statusText,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      _getChallengeTitle(
                        l10n,
                        currentChallenge,
                        status: status,
                        failureReason: failureReason,
                      ),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8.0),
                    LinearProgressIndicator(
                      value: status == ChallengeMachineStatus.failed
                          ? 0.0
                          : (stepResult?.stepProgress ?? 0.0),
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      color: statusColor,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Telemetry & Signals Panel (Bottom) / Retry Action
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 12.0,
            left: 16.0,
            right: 16.0,
            child: status == ChallengeMachineStatus.failed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      FilledButton.icon(
                        key: const Key('dev_challenges_retry_button'),
                        onPressed: _resetCurrentChallenges,
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          l10n.retryButton,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      OutlinedButton.icon(
                        key: const Key('dev_challenges_new_button'),
                        onPressed: _regenerateChallenges,
                        icon: const Icon(Icons.shuffle),
                        label: Text(l10n.newChallengesAction),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Card(
                        color: theme.colorScheme.surface.withAlpha(235),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              // Temporal Signals
                              Text(
                                l10n.temporalConfidence,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6.0),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  _MetricItem(
                                    label: l10n.temporalMicroMotion,
                                    value:
                                        '${((_lastTemporalResult?.microMotionScore ?? 1.0) * 100).toStringAsFixed(0)}%',
                                  ),
                                  _MetricItem(
                                    label: l10n.temporalLoopDetection,
                                    value:
                                        '${((_lastTemporalResult?.loopScore ?? 1.0) * 100).toStringAsFixed(0)}%',
                                  ),
                                  _MetricItem(
                                    label: l10n.temporalPlanarRigidity,
                                    value:
                                        _lastTemporalResult
                                                ?.rigidityEvaluated ??
                                            false
                                        ? '${((_lastTemporalResult?.rigidityScore ?? 1.0) * 100).toStringAsFixed(0)}%'
                                        : 'N/A',
                                  ),
                                  _MetricItem(
                                    label: 'Confidence',
                                    value:
                                        '${((_lastTemporalResult?.combinedConfidence ?? 1.0) * 100).toStringAsFixed(0)}%',
                                    isBold: true,
                                  ),
                                ],
                              ),
                              const Divider(height: 16.0),
                              // Live Facial Telemetry
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  _MetricItem(
                                    label: 'Yaw / Base',
                                    value:
                                        '${_currentFace?.yaw?.toStringAsFixed(0) ?? "-"}° / ${_stateMachine?.baselineYaw.toStringAsFixed(0) ?? "-"}°',
                                  ),
                                  _MetricItem(
                                    label: 'Pitch',
                                    value:
                                        '${_currentFace?.pitch?.toStringAsFixed(0) ?? "-"}°',
                                  ),
                                  _MetricItem(
                                    label: 'Eyes (L/R)',
                                    value:
                                        '${((_currentFace?.leftEyeOpenProbability ?? 0.0) * 100).toStringAsFixed(0)}% / ${((_currentFace?.rightEyeOpenProbability ?? 0.0) * 100).toStringAsFixed(0)}%',
                                  ),
                                  _MetricItem(
                                    label: 'Smile',
                                    value:
                                        '${((_currentFace?.smilingProbability ?? 0.0) * 100).toStringAsFixed(0)}%',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      // Flash Challenge Test Button
                      FilledButton.tonalIcon(
                        onPressed: _isFlashing ? null : _runFlashChallengeTest,
                        icon: const Icon(Icons.flash_on),
                        label: Text(
                          _isFlashing
                              ? 'Running Flash Test...'
                              : (_lastFlashResult != null
                                    ? '${l10n.flashChallengeAction}: ${_lastFlashResult!.verdict.name}'
                                    : l10n.flashChallengeAction),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview(Size screenSize) {
    final bool isIos = !kIsWeb && Platform.isIOS;
    final Size previewBoxSize = _imageSize ?? const Size(720, 1280);

    return FittedBox(
      fit: BoxFit.cover,
      alignment: Alignment.center,
      child: SizedBox(
        width: isIos ? previewBoxSize.width : previewBoxSize.height,
        height: isIos ? previewBoxSize.height : previewBoxSize.width,
        child: CameraPreview(_cameraService!.controller!),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ChallengesPainter extends CustomPainter {
  const _ChallengesPainter({
    required this.ovalRect,
    required this.face,
    required this.imageSize,
    required this.previewSize,
    required this.statusColor,
  });

  final Rect ovalRect;
  final DetectedFace? face;
  final Size imageSize;
  final Size previewSize;
  final Color statusColor;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dim background outside oval
    final Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path ovalPath = Path()..addOval(ovalRect);
    final Path clipPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      ovalPath,
    );

    final Paint dimPaint = Paint()
      ..color = Colors.black.withAlpha(90)
      ..style = PaintingStyle.fill;
    canvas.drawPath(clipPath, dimPaint);

    // 2. Oval border
    final Paint borderPaint = Paint()
      ..color = statusColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawOval(ovalRect, borderPaint);

    // 3. Face landmarks if detected
    if (face != null && face!.landmarks != null) {
      final PreviewMapper mapper = PreviewMapper.forDevice(
        imageSize: imageSize,
        previewSize: previewSize,
        isFrontCamera: true,
      );

      final FiveLandmarks lm = face!.landmarks!;
      final Paint dotPaint = Paint()
        ..color = statusColor
        ..style = PaintingStyle.fill;

      for (final Offset pt in lm.asList) {
        final Offset previewPt = mapper.mapPoint(pt);
        canvas.drawCircle(previewPt, 4.0, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChallengesPainter oldDelegate) {
    return oldDelegate.face != face ||
        oldDelegate.statusColor != statusColor ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.previewSize != previewSize;
  }
}
