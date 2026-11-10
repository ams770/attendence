import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/utils/affine_matrix.dart';
import '../../../core/utils/bmp_helper.dart';
import '../../../l10n/app_localizations.dart';
import '../../camera/domain/camera_service.dart';
import '../../camera/domain/frame_data.dart';
import '../../camera/domain/frame_geometry.dart';
import '../../camera/domain/frame_throttler.dart';
import '../../ml/worker/ml_worker.dart';
import '../../ml/worker/worker_protocol.dart';
import '../domain/detected_face.dart';
import '../domain/face_aligner.dart';
import '../domain/face_detector.dart';
import '../domain/oval_guide.dart';
import '../domain/preview_mapper.dart';
import '../domain/quality_gate.dart';

/// Developer verification screen for face detection, quality gate, and alignment.
class DetectionDevScreen extends ConsumerStatefulWidget {
  const DetectionDevScreen({super.key});

  @override
  ConsumerState<DetectionDevScreen> createState() => _DetectionDevScreenState();
}

class _DetectionDevScreenState extends ConsumerState<DetectionDevScreen>
    with WidgetsBindingObserver {
  late CameraService _cameraService;
  late FaceDetector _faceDetector;
  late QualityGate _qualityGate;
  late FaceAligner _faceAligner;
  late MlWorker _mlWorker;
  late FrameThrottler _throttler;

  bool _isProcessing = false;
  CameraPermissionStatus _permissionStatus = CameraPermissionStatus.unknown;
  String? _errorMessage;

  List<DetectedFace> _detectedFaces = <DetectedFace>[];
  QualityResult? _qualityResult;
  Uint8List? _alignedThumbnailBmp;
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
    _faceAligner = ref.read(faceAlignerProvider);
    _mlWorker = ref.read(mlWorkerProvider);

    if (!_mlWorker.isAlive) {
      _mlWorker.start().catchError((_) {});
    }

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
    if (_isProcessing || !mounted) return;

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

  Future<void> _processFrame(FrameData frame) async {
    final Stopwatch sw = Stopwatch()..start();
    try {
      final List<DetectedFace> faces = await _faceDetector.detect(frame);

      FaceStats? faceStats;
      Uint8List? alignedBmp;

      if (faces.length == 1) {
        final DetectedFace face = faces.first;
        final TransferableFrameData transferable = frame.toTransferable();

        // 1. Face quality statistics on worker isolate
        faceStats = await _mlWorker.getFaceStats(
          transferable,
          face.boundingBox,
        );

        // 2. Aligned crop if 5 landmarks are present
        if (face.hasAllLandmarks) {
          final AffineMatrix? transform = _faceAligner
              .computeSimilarityTransform(face.landmarks!);
          if (transform != null) {
            final AlignedCropData cropData = await _mlWorker.getAlignedCrop(
              frame.toTransferable(),
              transform,
            );
            alignedBmp = BmpHelper.createBmpFromRgb(
              cropData.rgbBytes,
              cropData.width,
              cropData.height,
            );
          }
        }
      }

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
      final Rect oval = defaultOvalRect(previewSize);
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

      final AppConfig config = ref.read(appConfigProvider);
      final QualityResult quality = _qualityGate.evaluate(
        faces: faces,
        previewSize: previewSize,
        ovalRect: oval,
        previewMapper: mapper,
        config: config,
        faceStats: faceStats,
      );

      setState(() {
        _detectedFaces = faces;
        _qualityResult = quality;
        _lastImageSize = imageSize;
        if (alignedBmp != null) {
          _alignedThumbnailBmp = alignedBmp;
        }
      });
    } catch (_) {
      // Ignore transient frame pipeline errors
    } finally {
      sw.stop();
      _throttler.onFrameCompleted(sw.elapsed);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraService.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraService.stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      _startCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.stopImageStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Size screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.devDetectionTitle),
        backgroundColor: Colors.black38,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(context, l10n, screenSize),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    Size screenSize,
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
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (_permissionStatus ==
                      CameraPermissionStatus.permanentlyDenied) {
                    await _cameraService.openSettings();
                  } else {
                    final CameraPermissionStatus status = await _cameraService
                        .requestPermission();
                    setState(() => _permissionStatus = status);
                    if (status == CameraPermissionStatus.granted) {
                      await _startCamera();
                    }
                  }
                },
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
            _errorMessage!,
            style: const TextStyle(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final CameraController? controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final Rect oval = defaultOvalRect(screenSize);
    final Size imageSize = _lastImageSize ?? const Size(720, 1280);
    final bool isFrontCam =
        _cameraService.currentCamera?.lensDirection != CameraLensDirection.back;
    final PreviewMapper mapper = PreviewMapper.forDevice(
      imageSize: imageSize,
      previewSize: screenSize,
      isFrontCamera: isFrontCam,
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // 1. Live camera preview scaled to cover screen matching imageSize
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

        // 2. Overlay painter with oval cutout, bounding box, landmarks
        Positioned.fill(
          child: CustomPaint(
            painter: _FaceOverlayPainter(
              ovalRect: oval,
              faces: _detectedFaces,
              previewMapper: mapper,
              isPass: _qualityResult?.isPass ?? false,
            ),
          ),
        ),

        // 3. Telemetry and metrics panel
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: _buildMetricsPanel(context, l10n),
        ),

        // 4. Aligned 112x112 thumbnail in top-right corner
        if (_alignedThumbnailBmp != null)
          Positioned(top: 16, right: 16, child: _buildThumbnailCard(l10n)),
      ],
    );
  }

  Widget _buildMetricsPanel(BuildContext context, AppLocalizations l10n) {
    final DetectedFace? face = _detectedFaces.isNotEmpty
        ? _detectedFaces.first
        : null;
    final FaceStats? stats = _qualityResult?.faceStats;
    final bool isPass = _qualityResult?.isPass ?? false;

    return Card(
      color: Colors.black.withAlpha(200),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Quality status header
            Row(
              children: <Widget>[
                Icon(
                  isPass ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: isPass ? Colors.greenAccent : Colors.amberAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isPass
                        ? l10n.devDetectionQualityPass
                        : (_qualityResult != null &&
                                  _qualityResult!.issues.isNotEmpty
                              ? _localizeQualityIssue(
                                  _qualityResult!.issues.first,
                                  l10n,
                                )
                              : l10n.devDetectionQualityIssues),
                    style: TextStyle(
                      color: isPass ? Colors.greenAccent : Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (face != null && face.trackingId != null)
                  Text(
                    '${l10n.devDetectionTrackingId}: #${face.trackingId}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
            const Divider(color: Colors.white24, height: 16),

            // Pose Euler Angles
            if (face != null) ...<Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    l10n.devDetectionEulerAngles,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    'Y: ${face.yaw?.toStringAsFixed(1) ?? "--"}°  '
                    'P: ${face.pitch?.toStringAsFixed(1) ?? "--"}°  '
                    'R: ${face.roll?.toStringAsFixed(1) ?? "--"}°',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Eyes & Smile
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    l10n.devDetectionEyeOpen,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    'L: ${((face.leftEyeOpenProbability ?? 0) * 100).toStringAsFixed(0)}%  '
                    'R: ${((face.rightEyeOpenProbability ?? 0) * 100).toStringAsFixed(0)}%  |  '
                    '${l10n.devDetectionSmiling}: ${((face.smilingProbability ?? 0) * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],

            // Photometric stats
            if (stats != null) ...<Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    l10n.devDetectionFaceStats,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    'S: ${stats.sharpness.toStringAsFixed(0)}  '
                    'B: ${stats.meanBrightness.toStringAsFixed(0)}  '
                    'G: ${(stats.nearSaturatedRatio * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailCard(AppLocalizations l10n) {
    return Card(
      color: Colors.black.withAlpha(200),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.devDetectionAlignedThumbnail,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                _alignedThumbnailBmp!,
                width: 112,
                height: 112,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ],
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
}

class _FaceOverlayPainter extends CustomPainter {
  const _FaceOverlayPainter({
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

    // 2. Draw faces
    final Paint boxPaint = Paint()
      ..color = isPass ? Colors.greenAccent : Colors.amberAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Paint landmarkPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;

    for (final DetectedFace face in faces) {
      final Rect previewBox = previewMapper.mapRect(face.boundingBox);
      canvas.drawRect(previewBox, boxPaint);

      if (face.landmarks != null) {
        for (final Offset pt in face.landmarks!.asList) {
          final Offset mappedPt = previewMapper.mapPoint(pt);
          canvas.drawCircle(mappedPt, 4.0, landmarkPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FaceOverlayPainter oldDelegate) {
    return oldDelegate.ovalRect != ovalRect ||
        oldDelegate.faces != faces ||
        oldDelegate.previewMapper != previewMapper ||
        oldDelegate.isPass != isPass;
  }
}
