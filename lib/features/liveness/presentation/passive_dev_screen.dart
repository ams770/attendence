import 'dart:io';

import 'package:camera/camera.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/utils/bmp_helper.dart';
import '../../../l10n/app_localizations.dart';
import '../../camera/domain/camera_service.dart';
import '../../camera/domain/frame_data.dart';
import '../../camera/domain/frame_geometry.dart';
import '../../camera/domain/frame_throttler.dart';
import '../../detection/domain/detected_face.dart';
import '../../detection/domain/face_detector.dart';
import '../../detection/domain/oval_guide.dart';
import '../../detection/domain/preview_mapper.dart';
import '../../detection/domain/quality_gate.dart';
import '../../ml/domain/model_registry.dart';
import '../../ml/worker/ml_worker.dart';
import '../../ml/worker/worker_protocol.dart';
import '../domain/passive_aggregator.dart';
import '../domain/passive_liveness_engine.dart';
import '../domain/passive_monitor.dart';
import '../domain/passive_sample.dart';

/// Selection of models to execute during evaluation.
enum PassiveModelSelection { both, v2Only, v1SeOnly }

/// Developer verification screen for passive liveness (MiniFASNet).
class PassiveDevScreen extends ConsumerStatefulWidget {
  const PassiveDevScreen({super.key});

  @override
  ConsumerState<PassiveDevScreen> createState() => _PassiveDevScreenState();
}

class _PassiveDevScreenState extends ConsumerState<PassiveDevScreen>
    with WidgetsBindingObserver {
  late CameraService _cameraService;
  late FaceDetector _faceDetector;
  late QualityGate _qualityGate;
  late PassiveLivenessEngine _passiveEngine;
  late MlWorker _mlWorker;
  late FrameThrottler _throttler;
  late AppConfig _config;

  late PassiveAggregator _aggregator;
  late PassiveMonitor _monitor;

  final Stopwatch _sessionStopwatch = Stopwatch();
  final List<PassiveSample> _sessionSamples = <PassiveSample>[];

  bool _isProcessing = false;
  bool _sessionActive = true;
  PassiveModelSelection _selectedModels = PassiveModelSelection.both;
  CameraPermissionStatus _permissionStatus = CameraPermissionStatus.unknown;
  String? _errorMessage;

  // Diagnostic overrides (Task B)
  double _boxExpansion = 1.0;
  PreprocessVariant _preprocessVariant = PreprocessVariant.bgrRaw255;

  // Evaluation capture mode (Task C)
  EvalScenario _selectedScenario = EvalScenario.liveFace;
  bool _isRecording = false;
  int _recordedFrameCount = 0;
  String _currentAttemptId = '';
  int _captureFrameIndex = 0;

  List<DetectedFace> _latestFaces = <DetectedFace>[];
  PassiveFrameResult? _latestFrameResult;
  QualityResult? _latestQualityResult;
  Size? _lastImageSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _throttler = FrameThrottler(clock: ref.read(clockProvider), targetFps: 15);
    _initServices();
  }

  Future<void> _initServices() async {
    _cameraService = ref.read(cameraServiceProvider);
    _faceDetector = ref.read(faceDetectorProvider);
    _qualityGate = ref.read(qualityGateProvider);
    _passiveEngine = ref.read(passiveLivenessEngineProvider);
    _mlWorker = ref.read(mlWorkerProvider);
    _config = ref.read(appConfigProvider);

    _mlWorker.ensureInitialized().catchError((_) {});

    _aggregator = PassiveAggregator(
      passiveThreshold: _config.passiveThreshold,
      passingFrameRatio: _config.passivePassingFrameRatio,
    );
    _monitor = PassiveMonitor(hardFloor: _config.passiveHardFloor);

    _sessionStopwatch.start();
    await _checkPermissionAndStart();
  }

  Future<void> _checkPermissionAndStart() async {
    final CameraPermissionStatus status = await _cameraService
        .checkPermission();
    if (!mounted) return;
    setState(() => _permissionStatus = status);

    if (status == CameraPermissionStatus.granted) {
      await _startCamera();
    }
  }

  Future<void> _startCamera() async {
    try {
      await _cameraService.initialize(
        resolutionPreset: ResolutionPreset.high,
        lensDirection: CameraLensDirection.front,
      );
      if (!mounted) return;
      setState(() => _errorMessage = null);

      await _cameraService.startImageStream(_handleCameraFrame);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    }
  }

  void _handleCameraFrame(CameraImage image) {
    if (_isProcessing || !_sessionActive || !mounted) return;

    final CameraDescription? currentCam = _cameraService.currentCamera;
    final int sensorRotation = currentCam?.sensorOrientation ?? 270;
    final CameraLensDirection lensDirection =
        currentCam?.lensDirection ?? CameraLensDirection.front;

    final FrameData frame = FrameData.fromCameraImage(
      image,
      sensorRotation: sensorRotation,
      lensDirection: lensDirection,
      timestamp: DateTime.now(),
    );

    if (!_throttler.shouldProcess()) return;

    _throttler.onFrameStarted();
    _isProcessing = true;
    _processFrame(frame).whenComplete(() {
      _isProcessing = false;
    });
  }

  List<String> _resolveModelNames() {
    switch (_selectedModels) {
      case PassiveModelSelection.both:
        return <String>[
          ModelRegistry.miniFASNetV2.name,
          ModelRegistry.miniFASNetV1SE.name,
        ];
      case PassiveModelSelection.v2Only:
        return <String>[ModelRegistry.miniFASNetV2.name];
      case PassiveModelSelection.v1SeOnly:
        return <String>[ModelRegistry.miniFASNetV1SE.name];
    }
  }

  Future<void> _processFrame(FrameData frame) async {
    final Stopwatch sw = Stopwatch()..start();
    try {
      final List<DetectedFace> faces = await _faceDetector.detect(frame);
      if (!mounted) return;

      final FrameGeometry geometry = FrameGeometry(
        rawWidth: frame.width,
        rawHeight: frame.height,
        rotation: frame.sensorRotation,
      );
      final Size imageSize = Size(
        geometry.uprightWidth.toDouble(),
        geometry.uprightHeight.toDouble(),
      );

      final Size previewSize = MediaQuery.sizeOf(context);
      final Rect ovalRect = defaultOvalRect(previewSize);

      final bool isFrontCam = frame.lensDirection == CameraLensDirection.front;
      final PreviewMapper mapper = PreviewMapper.forDevice(
        imageSize: imageSize,
        previewSize: previewSize,
        isFrontCamera: isFrontCam,
      );

      if (faces.isNotEmpty) {
        final DetectedFace f = faces.first;
        final Rect previewBox = mapper.mapRect(f.boundingBox);
        debugPrint(
          '[DEV_BOX_DEBUG] rawFrame=(${frame.width}x${frame.height}), '
          'rotation=${frame.sensorRotation}, '
          'mlkitSize=(${imageSize.width}x${imageSize.height}), '
          'uprightBox=${f.boundingBox}, '
          'previewBox=$previewBox, '
          'screenSize=(${previewSize.width}x${previewSize.height})',
        );
      }

      final QualityResult quality = _qualityGate.evaluate(
        faces: faces,
        previewSize: previewSize,
        ovalRect: ovalRect,
        previewMapper: mapper,
        config: _config,
      );

      if (!mounted) return;
      setState(() {
        _latestFaces = faces;
        _latestQualityResult = quality;
        _lastImageSize = imageSize;
      });

      if (!quality.isPass || faces.isEmpty) {
        return;
      }

      final DetectedFace targetFace = faces.first;
      final TransferableFrameData transferable = frame.toTransferable();
      final List<String> modelNames = _resolveModelNames();

      final PassivePreprocessConfig baseConfig =
          _config.passivePreprocessConfig;
      final PassivePreprocessConfig effectiveConfig = _preprocessVariant
          .applyTo(baseConfig)
          .copyWith(boxExpansion: _boxExpansion);

      final PassiveFrameResult result = await _passiveEngine.evaluateFrame(
        frame: transferable,
        faceRect: targetFace.boundingBox,
        modelNames: modelNames,
        preprocessConfig: effectiveConfig,
      );

      if (!mounted) return;

      if (_isRecording) {
        _captureFrameIndex++;
        _saveEvalCrops(
          attemptId: _currentAttemptId,
          frameIndex: _captureFrameIndex,
          scenario: _selectedScenario.id,
          result: result,
        );
      }

      final Map<String, double> modelScores = <String, double>{};
      final Map<String, List<double>> modelLogits = <String, List<double>>{};
      final Map<String, List<double>> modelSoftmax = <String, List<double>>{};
      final Map<String, double> modelLatencies = <String, double>{};

      for (final MapEntry<String, PassiveModelResult> entry
          in result.modelResults.entries) {
        modelScores[entry.key] = entry.value.realProbability;
        modelLogits[entry.key] = entry.value.rawScores;
        modelSoftmax[entry.key] = entry.value.softmaxProbabilities;
        modelLatencies[entry.key] = entry.value.latencyMs;
      }

      final PassiveSample sample = PassiveSample(
        timestamp: DateTime.now(),
        meanScore: result.meanRealProbability,
        modelScores: modelScores,
        latencyMs: result.totalLatencyMs,
        scenarioLabel: _selectedScenario.id,
        boxExpansion: _boxExpansion,
        preprocessVariant: _preprocessVariant.id,
        boxWidthRatio: targetFace.boundingBox.width / imageSize.width,
        boxHeightRatio: targetFace.boundingBox.height / imageSize.height,
        modelLogits: modelLogits,
        modelSoftmaxProbs: modelSoftmax,
        modelLatencies: modelLatencies,
      );

      _aggregator.addSample(sample);
      _monitor.addSample(result.meanRealProbability);
      _sessionSamples.add(sample);

      setState(() {
        _latestFrameResult = result;
        if (_isRecording) {
          _recordedFrameCount = _captureFrameIndex;
        }
      });
    } catch (_) {
      // Ignore transient frame pipeline errors so camera preview is not interrupted.
    } finally {
      sw.stop();
      _throttler.onFrameCompleted(sw.elapsed);
    }
  }

  Future<void> _saveEvalCrops({
    required String attemptId,
    required int frameIndex,
    required String scenario,
    required PassiveFrameResult result,
  }) async {
    try {
      final Directory docsDir = await getApplicationDocumentsDirectory();
      final Directory targetDir = Directory(
        '${docsDir.path}/eval_crops/$scenario',
      );
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final PassiveModelResult? v2Res =
          result.modelResults[ModelRegistry.miniFASNetV2.name];
      if (v2Res != null && v2Res.cropRgbBytes != null) {
        final Uint8List bmpBytes = BmpHelper.createBmpFromRgb(
          v2Res.cropRgbBytes!,
          80,
          80,
        );
        final File v2File = File(
          '${targetDir.path}/${attemptId}_${frameIndex}_v2.bmp',
        );
        await v2File.writeAsBytes(bmpBytes, flush: true);
      }

      final PassiveModelResult? v1SeRes =
          result.modelResults[ModelRegistry.miniFASNetV1SE.name];
      if (v1SeRes != null && v1SeRes.cropRgbBytes != null) {
        final Uint8List bmpBytes = BmpHelper.createBmpFromRgb(
          v1SeRes.cropRgbBytes!,
          80,
          80,
        );
        final File v1SeFile = File(
          '${targetDir.path}/${attemptId}_${frameIndex}_v1se.bmp',
        );
        await v1SeFile.writeAsBytes(bmpBytes, flush: true);
      }
    } catch (_) {
      // Diagnostic write error ignored in background
    }
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) {
        _currentAttemptId =
            'att_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
        _captureFrameIndex = 0;
        _recordedFrameCount = 0;
      }
    });
  }

  Future<void> _deleteAllCrops() async {
    try {
      final Directory docsDir = await getApplicationDocumentsDirectory();
      final Directory evalDir = Directory('${docsDir.path}/eval_crops');
      if (await evalDir.exists()) {
        await evalDir.delete(recursive: true);
      }
      if (!mounted) return;
      setState(() {
        _recordedFrameCount = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All captured evaluation crops deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to delete crops: $e')));
    }
  }

  void _resetSession() {
    setState(() {
      _aggregator.reset();
      _monitor.reset();
      _sessionSamples.clear();
      _latestFrameResult = null;
      _sessionStopwatch.reset();
      _sessionStopwatch.start();
    });
  }

  List<List<dynamic>> _generateCsvRows() {
    final List<List<dynamic>> rows = <List<dynamic>>[
      <dynamic>[
        'timestamp_iso',
        'sample_index',
        'scenario_label',
        'box_expansion',
        'preprocess_variant',
        'box_width_ratio',
        'box_height_ratio',
        'model_v2_logits',
        'model_v2_softmax',
        'model_v2_score',
        'model_v2_latency_ms',
        'model_v1se_logits',
        'model_v1se_softmax',
        'model_v1se_score',
        'model_v1se_latency_ms',
        'mean_score',
        'total_latency_ms',
      ],
    ];

    final String v2Name = ModelRegistry.miniFASNetV2.name;
    final String v1SeName = ModelRegistry.miniFASNetV1SE.name;

    for (int i = 0; i < _sessionSamples.length; i++) {
      final PassiveSample s = _sessionSamples[i];
      final double? v2Score = s.modelScores[v2Name];
      final double? v1SeScore = s.modelScores[v1SeName];

      rows.add(<dynamic>[
        s.timestamp.toIso8601String(),
        i + 1,
        s.scenarioLabel ?? '',
        s.boxExpansion?.toStringAsFixed(2) ?? '',
        s.preprocessVariant ?? '',
        s.boxWidthRatio?.toStringAsFixed(4) ?? '',
        s.boxHeightRatio?.toStringAsFixed(4) ?? '',
        s.modelLogits?[v2Name]
                ?.map((double v) => v.toStringAsFixed(4))
                .toList()
                .toString() ??
            '',
        s.modelSoftmaxProbs?[v2Name]
                ?.map((double v) => v.toStringAsFixed(4))
                .toList()
                .toString() ??
            '',
        v2Score?.toStringAsFixed(4) ?? '',
        s.modelLatencies?[v2Name]?.toStringAsFixed(2) ?? '',
        s.modelLogits?[v1SeName]
                ?.map((double v) => v.toStringAsFixed(4))
                .toList()
                .toString() ??
            '',
        s.modelSoftmaxProbs?[v1SeName]
                ?.map((double v) => v.toStringAsFixed(4))
                .toList()
                .toString() ??
            '',
        v1SeScore?.toStringAsFixed(4) ?? '',
        s.modelLatencies?[v1SeName]?.toStringAsFixed(2) ?? '',
        s.meanScore.toStringAsFixed(4),
        s.latencyMs.toStringAsFixed(2),
      ]);
    }

    return rows;
  }

  Future<void> _shareEvalSession() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<List<dynamic>> rows = _generateCsvRows();

    final Directory docsDir = await getApplicationDocumentsDirectory();
    final List<XFile> filesToShare = <XFile>[];

    if (rows.length > 1) {
      final String csvContent = const CsvEncoder().convert(rows);
      final File csvFile = File(
        '${docsDir.path}/passive_eval_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await csvFile.writeAsString(csvContent);
      filesToShare.add(XFile(csvFile.path));
    }

    final Directory evalDir = Directory('${docsDir.path}/eval_crops');
    if (await evalDir.exists()) {
      final List<FileSystemEntity> entities = await evalDir
          .list(recursive: true)
          .toList();
      for (final FileSystemEntity entity in entities) {
        if (entity is File && entity.path.endsWith('.bmp')) {
          filesToShare.add(XFile(entity.path));
        }
      }
    }

    if (filesToShare.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.devPassiveCsvExportEmpty)));
      }
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: filesToShare,
          subject: 'Passive Liveness Evaluation Data',
          text:
              'Passive liveness evaluation data (${_sessionSamples.length} samples, ${filesToShare.length - (rows.length > 1 ? 1 : 0)} crops).',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Share error: $e')));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _cameraService.pausePreview();
    } else if (state == AppLifecycleState.resumed) {
      _cameraService.resumePreview();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.dispose();
    _sessionStopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.devPassiveTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: <Widget>[
          IconButton(
            icon: Icon(_sessionActive ? Icons.pause : Icons.play_arrow),
            tooltip: _sessionActive
                ? l10n.devPassiveStopSession
                : l10n.devPassiveStartSession,
            onPressed: () {
              setState(() => _sessionActive = !_sessionActive);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.devPassiveResetSession,
            onPressed: _resetSession,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Evaluation Data',
            onPressed: _shareEvalSession,
          ),
        ],
      ),
      body: _buildBody(context, l10n, theme),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    if (_permissionStatus == CameraPermissionStatus.denied ||
        _permissionStatus == CameraPermissionStatus.permanentlyDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                l10n.devCameraPermissionRequired,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed:
                    _permissionStatus ==
                        CameraPermissionStatus.permanentlyDenied
                    ? _cameraService.openSettings
                    : _checkPermissionAndStart,
                child: Text(
                  _permissionStatus == CameraPermissionStatus.permanentlyDenied
                      ? l10n.devCameraOpenSettings
                      : l10n.devCameraGrantPermission,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Error: $_errorMessage',
            style: TextStyle(color: theme.colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final CameraController? controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final Size screenSize = MediaQuery.sizeOf(context);
    final Rect ovalRect = defaultOvalRect(screenSize);
    final Size imageSize = _lastImageSize ?? const Size(720, 1280);

    final bool isFrontCam =
        _cameraService.currentCamera?.lensDirection ==
        CameraLensDirection.front;
    final PreviewMapper mapper = PreviewMapper.forDevice(
      imageSize: imageSize,
      previewSize: screenSize,
      isFrontCamera: isFrontCam,
    );
    final bool isGuidanceOk = _latestQualityResult?.isPass ?? false;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Camera preview scaled identically with imageSize
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: imageSize.width,
              height: imageSize.height,
              child: CameraPreview(controller),
            ),
          ),
        ),

        // Oval guide & face bounding box overlay
        Positioned.fill(
          child: CustomPaint(
            size: screenSize,
            painter: _PassiveFaceOverlayPainter(
              ovalRect: ovalRect,
              faces: _latestFaces,
              previewMapper: mapper,
              isPass: isGuidanceOk,
            ),
          ),
        ),

        // Quality guidance alert if issue detected
        if (_latestQualityResult != null && !isGuidanceOk)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 56,
            left: 16,
            right: 16,
            child: _buildGuidanceBanner(
              context,
              _latestQualityResult!,
              l10n,
              theme,
            ),
          ),

        // Telemetry & Control Panel at the bottom (scrollable within max height)
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: screenSize.height * 0.48),
            child: _buildTelemetryCard(context, l10n, theme),
          ),
        ),
      ],
    );
  }

  Widget _buildGuidanceBanner(
    BuildContext context,
    QualityResult quality,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final String issueText = quality.primaryIssue != null
        ? _localizeQualityIssue(quality.primaryIssue!, l10n)
        : l10n.devDetectionQualityIssues;

    return Card(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.92),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          issueText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onErrorContainer,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String _localizeQualityIssue(QualityIssue issue, AppLocalizations l10n) {
    switch (issue) {
      case QualityIssue.noFace:
        return l10n.qualityIssueNoFace;
      case QualityIssue.multipleFaces:
        return l10n.qualityIssueMultipleFaces;
      case QualityIssue.tooSmall:
        return l10n.qualityIssueTooSmall;
      case QualityIssue.notInsideGuide:
        return l10n.qualityIssueNotInsideGuide;
      case QualityIssue.poseOutOfRange:
        return l10n.qualityIssuePoseOutOfRange;
      case QualityIssue.landmarksMissing:
        return l10n.qualityIssueLandmarksMissing;
      case QualityIssue.tooBlurry:
        return l10n.qualityIssueTooBlurry;
      case QualityIssue.tooDark:
        return l10n.qualityIssueTooDark;
      case QualityIssue.tooBright:
        return l10n.qualityIssueTooBright;
      case QualityIssue.glare:
        return l10n.qualityIssueGlare;
    }
  }

  Widget _buildTelemetryCard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final PassiveAggregatedResult agg = _aggregator.result;

    final Color verdictColor;
    final String verdictText;
    switch (agg.verdict) {
      case PassiveVerdict.passed:
        verdictColor = Colors.green;
        verdictText = l10n.devPassiveVerdictPassed;
        break;
      case PassiveVerdict.failed:
        verdictColor = theme.colorScheme.error;
        verdictText = l10n.devPassiveVerdictFailed;
        break;
      case PassiveVerdict.pending:
        verdictColor = Colors.orange;
        verdictText = l10n.devPassiveVerdictPending;
        break;
    }

    final PassiveModelResult? v2Result =
        _latestFrameResult?.modelResults[ModelRegistry.miniFASNetV2.name];
    final PassiveModelResult? v1SeResult =
        _latestFrameResult?.modelResults[ModelRegistry.miniFASNetV1SE.name];

    return Card(
      color: theme.colorScheme.surface.withValues(alpha: 0.94),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Row 1: Model selector, Box Expansion, Preprocessing Variant
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                DropdownButton<PassiveModelSelection>(
                  value: _selectedModels,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  style: theme.textTheme.bodySmall,
                  items: <DropdownMenuItem<PassiveModelSelection>>[
                    DropdownMenuItem<PassiveModelSelection>(
                      value: PassiveModelSelection.both,
                      child: Text(l10n.devPassiveModelOptionBoth),
                    ),
                    DropdownMenuItem<PassiveModelSelection>(
                      value: PassiveModelSelection.v2Only,
                      child: Text(l10n.devPassiveModelOptionV2Only),
                    ),
                    DropdownMenuItem<PassiveModelSelection>(
                      value: PassiveModelSelection.v1SeOnly,
                      child: Text(l10n.devPassiveModelOptionV1SeOnly),
                    ),
                  ],
                  onChanged: (PassiveModelSelection? val) {
                    if (val != null) {
                      setState(() => _selectedModels = val);
                    }
                  },
                ),
                DropdownButton<double>(
                  value: _boxExpansion,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  style: theme.textTheme.bodySmall,
                  items: const <double>[0.8, 0.9, 1.0, 1.1, 1.2]
                      .map(
                        (double v) => DropdownMenuItem<double>(
                          value: v,
                          child: Text('Exp: ${v.toStringAsFixed(1)}x'),
                        ),
                      )
                      .toList(),
                  onChanged: (double? val) {
                    if (val != null) {
                      setState(() => _boxExpansion = val);
                    }
                  },
                ),
                DropdownButton<PreprocessVariant>(
                  value: _preprocessVariant,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  style: theme.textTheme.bodySmall,
                  items: PreprocessVariant.values
                      .map(
                        (PreprocessVariant v) =>
                            DropdownMenuItem<PreprocessVariant>(
                              value: v,
                              child: Text(v.displayName),
                            ),
                      )
                      .toList(),
                  onChanged: (PreprocessVariant? val) {
                    if (val != null) {
                      setState(() => _preprocessVariant = val);
                    }
                  },
                ),
              ],
            ),
            const Divider(height: 10),

            // Row 2: Evaluation Capture Controls (Task C)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                DropdownButton<EvalScenario>(
                  value: _selectedScenario,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  style: theme.textTheme.bodySmall,
                  items: EvalScenario.values
                      .map(
                        (EvalScenario s) => DropdownMenuItem<EvalScenario>(
                          value: s,
                          child: Text(s.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (EvalScenario? val) {
                    if (val != null) {
                      setState(() => _selectedScenario = val);
                    }
                  },
                ),
                ElevatedButton.icon(
                  onPressed: _toggleRecording,
                  icon: Icon(
                    _isRecording ? Icons.stop : Icons.fiber_manual_record,
                    size: 14,
                    color: _isRecording ? Colors.white : Colors.red,
                  ),
                  label: Text(
                    _isRecording
                        ? 'Stop ($_recordedFrameCount)'
                        : 'Record Crops',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    backgroundColor: _isRecording ? Colors.red : null,
                  ),
                ),
                OutlinedButton(
                  onPressed: _deleteAllCrops,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  child: const Text(
                    'Delete Crops',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            const Divider(height: 10),

            // Row 3: Inspectable 80x80 Crops & Logits (Task B1 & B2)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (v2Result != null)
                  Expanded(
                    child: _buildModelInspectionCard(
                      label: 'V2',
                      result: v2Result,
                      realClassIndex:
                          _config.passivePreprocessConfig.realClassIndex,
                      theme: theme,
                    ),
                  ),
                if (v2Result != null && v1SeResult != null)
                  const SizedBox(width: 8),
                if (v1SeResult != null)
                  Expanded(
                    child: _buildModelInspectionCard(
                      label: 'V1SE',
                      result: v1SeResult,
                      realClassIndex:
                          _config.passivePreprocessConfig.realClassIndex,
                      theme: theme,
                    ),
                  ),
              ],
            ),
            const Divider(height: 10),

            // Row 4: Per-model real probabilities and latency
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _buildScoreColumn(
                  label: l10n.devPassiveModelV2Label,
                  score: v2Result?.realProbability,
                  latencyMs: v2Result?.latencyMs,
                  theme: theme,
                ),
                _buildScoreColumn(
                  label: l10n.devPassiveModelV1SeLabel,
                  score: v1SeResult?.realProbability,
                  latencyMs: v1SeResult?.latencyMs,
                  theme: theme,
                ),
                _buildScoreColumn(
                  label: l10n.devPassiveMeanScore,
                  score: _latestFrameResult?.meanRealProbability,
                  latencyMs: _latestFrameResult?.totalLatencyMs,
                  theme: theme,
                  isHighlighted: true,
                ),
              ],
            ),
            const Divider(height: 10),

            // Row 5: Aggregator summary row
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.devPassiveVerdict,
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: <Widget>[
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: verdictColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            verdictText,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: verdictColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '${l10n.devPassiveSamplesCount}: ${agg.sampleCount}',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      '${l10n.devPassivePassingRatio}: ${(agg.passingRatio * 100).toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (_monitor.isCompromised)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  'Hard floor violation: rolling avg ${_monitor.rollingAverage?.toStringAsFixed(3)} < ${_config.passiveHardFloor}',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Notice: Biometric crops notice
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'Diagnostic Notice: Crops are biometric data saved locally on device only for diagnostic evaluation. Never logged or transmitted without explicit export.',
                style: TextStyle(fontSize: 9, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelInspectionCard({
    required String label,
    required PassiveModelResult result,
    required int realClassIndex,
    required ThemeData theme,
  }) {
    final Uint8List? cropBytes = result.cropRgbBytes;
    final Uint8List? bmpBytes = cropBytes != null
        ? BmpHelper.createBmpFromRgb(cropBytes, 80, 80)
        : null;

    final String logitsStr = result.rawScores
        .map((double v) => v.toStringAsFixed(2))
        .join(', ');
    final String probsStr = result.softmaxProbabilities
        .map((double v) => v.toStringAsFixed(2))
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (bmpBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                bmpBytes,
                width: 48,
                height: 48,
                gaplessPlayback: true,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 48,
              height: 48,
              color: Colors.black26,
              child: const Icon(Icons.image_not_supported, size: 20),
            ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Class $realClassIndex',
                        style: const TextStyle(fontSize: 8),
                      ),
                    ),
                  ],
                ),
                Text(
                  'L: [$logitsStr]',
                  style: const TextStyle(fontSize: 9, fontFamily: 'monospace'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'P: [$probsStr]',
                  style: const TextStyle(fontSize: 9, fontFamily: 'monospace'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreColumn({
    required String label,
    required double? score,
    required double? latencyMs,
    required ThemeData theme,
    bool isHighlighted = false,
  }) {
    final String scoreStr = score != null ? score.toStringAsFixed(3) : '--';
    final String latencyStr = latencyMs != null
        ? '${latencyMs.toStringAsFixed(0)}ms'
        : '--';

    final Color textColor = isHighlighted
        ? (score != null && score >= _config.passiveThreshold
              ? Colors.green
              : (score != null
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface))
        : theme.colorScheme.onSurface;

    return Column(
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          scoreStr,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        Text(
          latencyStr,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _PassiveFaceOverlayPainter extends CustomPainter {
  const _PassiveFaceOverlayPainter({
    required this.ovalRect,
    required this.faces,
    required this.previewMapper,
    required this.isPass,
  });

  final Rect ovalRect;
  final List<DetectedFace> faces;
  final PreviewMapper previewMapper;
  final bool isPass;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Oval cutout overlay
    final Path screenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path ovalPath = Path()..addOval(ovalRect);
    final Path overlayPath = Path.combine(
      PathOperation.difference,
      screenPath,
      ovalPath,
    );

    final Paint overlayPaint = Paint()
      ..color = const Color(0x66000000)
      ..style = PaintingStyle.fill;
    canvas.drawPath(overlayPath, overlayPaint);

    final Paint ovalBorderPaint = Paint()
      ..color = isPass
          ? Colors.greenAccent
          : (faces.isEmpty ? Colors.white70 : Colors.amberAccent)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawOval(ovalRect, ovalBorderPaint);

    // 2. Draw face bounding box if present
    final Paint boxPaint = Paint()
      ..color = isPass ? Colors.greenAccent : Colors.amberAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final DetectedFace face in faces) {
      final Rect previewBox = previewMapper.mapRect(face.boundingBox);
      canvas.drawRect(previewBox, boxPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PassiveFaceOverlayPainter oldDelegate) {
    return oldDelegate.ovalRect != ovalRect ||
        oldDelegate.faces != faces ||
        oldDelegate.previewMapper != previewMapper ||
        oldDelegate.isPass != isPass;
  }
}
