import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/utils/affine_matrix.dart';
import '../../../l10n/app_localizations.dart';
import '../../camera/domain/camera_service.dart';
import '../../camera/domain/frame_data.dart';
import '../../camera/domain/frame_throttler.dart';
import '../../detection/domain/detected_face.dart';
import '../../detection/domain/face_aligner.dart';
import '../../detection/domain/face_detector.dart';
import '../../detection/domain/oval_guide.dart';
import '../../detection/domain/preview_mapper.dart';
import '../../detection/domain/quality_gate.dart';
import '../../ml/domain/model_registry.dart';
import '../../ml/sampler/pixel_sampler.dart';
import '../domain/employee_repository.dart';
import '../domain/enrollment_pose.dart';
import '../domain/enrollment_session.dart';

/// Screen managing employee registration and 5-pose face biometric capture.
class EnrollmentScreen extends ConsumerStatefulWidget {
  const EnrollmentScreen({
    super.key,
    this.employeeId,
    this.initialName,
    this.initialCode,
    this.cameraServiceOverride,
    this.faceDetectorOverride,
  });

  final int? employeeId;
  final String? initialName;
  final String? initialCode;
  final CameraService? cameraServiceOverride;
  final FaceDetector? faceDetectorOverride;

  bool get isReEnrollment => employeeId != null;

  @override
  ConsumerState<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends ConsumerState<EnrollmentScreen>
    with WidgetsBindingObserver {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;

  bool _isCameraPhase = false;
  bool _isCameraInitializing = false;
  bool _isProcessingFrame = false;
  bool _isDisposed = false;

  CameraService? _cameraService;
  FaceDetector? _faceDetector;
  FaceAligner? _faceAligner;
  QualityGate? _qualityGate;
  EnrollmentSession? _session;
  late FrameThrottler _throttler;

  Size? _imageSize;
  EnrollmentSessionState? _sessionState;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _codeController = TextEditingController(text: widget.initialCode ?? '');

    if (widget.isReEnrollment) {
      _isCameraPhase = true;
      _initCameraAndSubsystems();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _cameraService?.stopImageStream().catchError((_) {});
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _initCameraAndSubsystems() {
    _cameraService =
        widget.cameraServiceOverride ?? ref.read(cameraServiceProvider);
    _faceDetector =
        widget.faceDetectorOverride ?? ref.read(faceDetectorProvider);
    _faceAligner = ref.read(faceAlignerProvider);
    _qualityGate = ref.read(qualityGateProvider);
    _session = ref.read(enrollmentSessionProvider);

    _session!.onStateChanged = (EnrollmentSessionState state) {
      if (!mounted) return;
      setState(() => _sessionState = state);
      if (state.status == EnrollmentStatus.processing ||
          state.status == EnrollmentStatus.duplicateDetected ||
          state.status == EnrollmentStatus.completed) {
        _cameraService?.stopImageStream().catchError((_) {});
      }
    };

    _throttler = FrameThrottler(clock: ref.read(clockProvider), targetFps: 15);

    _session!.start();
    _sessionState = _session!.state;

    // Eagerly warm up SFace recognition model in worker isolate while camera is starting
    ref
        .read(mlWorkerProvider)
        .ensureInitialized(models: <ModelSpec>[ModelRegistry.sFace])
        .catchError((_) {});

    _startCamera();
  }

  Future<void> _startCamera() async {
    setState(() => _isCameraInitializing = true);

    final CameraPermissionStatus perm = await _cameraService!.checkPermission();
    if (perm != CameraPermissionStatus.granted) {
      final CameraPermissionStatus req = await _cameraService!
          .requestPermission();
      if (req != CameraPermissionStatus.granted) {
        if (mounted) setState(() => _isCameraInitializing = false);
        return;
      }
    }

    try {
      await _cameraService!.initialize(
        resolutionPreset: ResolutionPreset.high,
        lensDirection: CameraLensDirection.front,
      );

      if (!mounted || _isDisposed) return;
      await _cameraService!.startImageStream(_handleCameraFrame);

      if (mounted) {
        setState(() => _isCameraInitializing = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isCameraInitializing = false);
    }
  }

  void _handleCameraFrame(CameraImage image) {
    if (_isProcessingFrame || !mounted || _isDisposed) return;
    if (!_throttler.shouldProcess()) return;
    _throttler.onFrameStarted();
    _isProcessingFrame = true;

    final Stopwatch sw = Stopwatch()..start();
    final DateTime now = ref.read(clockProvider).now();
    final FrameData frame = FrameData.fromCameraImage(
      image,
      sensorRotation: _cameraService?.currentCamera?.sensorOrientation ?? 0,
      lensDirection:
          _cameraService?.currentCamera?.lensDirection ??
          CameraLensDirection.front,
      timestamp: now,
    );

    _imageSize = Size(
      frame.uprightWidth.toDouble(),
      frame.uprightHeight.toDouble(),
    );

    _faceDetector!
        .detect(frame)
        .then((List<DetectedFace> faces) async {
          if (!mounted || _isDisposed) {
            return;
          }

          if (faces.isEmpty) {
            if (mounted) {
              setState(() {
                _sessionState = _sessionState?.copyWith(
                  guidanceIssue: QualityIssue.noFace,
                  holdProgress: 0.0,
                );
              });
            }
            return;
          }

          final DetectedFace face = faces.first;
          final Size screenSize = MediaQuery.sizeOf(context);
          final Rect oval = defaultOvalRect(screenSize);

          final PreviewMapper mapper = PreviewMapper.forDevice(
            imageSize: _imageSize!,
            previewSize: screenSize,
            isFrontCamera: true,
          );

          final QualityResult quality = _qualityGate!.evaluate(
            faces: faces,
            previewSize: screenSize,
            ovalRect: oval,
            previewMapper: mapper,
            config: ref.read(appConfigProvider),
            checkPose: false,
            cardinalTolerance: 1.15,
            cornerTolerance: 1.45,
          );

          Uint8List? alignedCrop;
          if (face.landmarks != null) {
            final AffineMatrix? transform = _faceAligner!
                .computeSimilarityTransform(face.landmarks!);
            if (transform != null) {
              const PixelSampler sampler = PixelSampler();
              alignedCrop = sampler.warpAffine(frame, transform, 112, 112);
            }
          }

          final EnrollmentSessionState newState = await _session!.onFrame(
            face: face,
            quality: quality,
            alignedRgb112: alignedCrop,
          );

          if (mounted) {
            setState(() => _sessionState = newState);
            _handleStateTransition(newState);
          }
        })
        .catchError((_) {})
        .whenComplete(() {
          _throttler.onFrameCompleted(sw.elapsed);
          _isProcessingFrame = false;
        });
  }

  Future<void> _handleStateTransition(EnrollmentSessionState state) async {
    if (state.status == EnrollmentStatus.duplicateDetected &&
        state.duplicateWarning != null) {
      await _cameraService?.stopImageStream().catchError((_) {});
      await _showDuplicateWarningDialog(state.duplicateWarning!);
    } else if (state.status == EnrollmentStatus.completed) {
      await _cameraService?.stopImageStream().catchError((_) {});
      await _saveEnrollment();
    } else if (state.status == EnrollmentStatus.failed) {
      await _cameraService?.stopImageStream().catchError((_) {});
      if (mounted) {
        final AppLocalizations l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.failureMessage ?? l10n.statusFailed)),
        );
        setState(() => _isCameraPhase = false);
      }
    }
  }

  Future<void> _showDuplicateWarningDialog(DuplicateFaceWarning warning) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool? proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(l10n.duplicateWarningTitle),
          content: Text(
            l10n.duplicateWarningMessage(
              warning.matchedEmployee.name,
              warning.matchedEmployee.code,
              (warning.similarityScore * 100).toStringAsFixed(1),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancelAction),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.confirmEnrollmentAction),
            ),
          ],
        );
      },
    );

    if (proceed == true) {
      _session!.acknowledgeDuplicateAndComplete();
      await _saveEnrollment();
    } else {
      _session!.reset();
      setState(() => _isCameraPhase = false);
    }
  }

  Future<void> _saveEnrollment() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    await _cameraService?.stopImageStream().catchError((_) {});

    final List<List<double>>? embeddings = _session!.computedEmbeddings;
    if (embeddings == null || embeddings.length < 5) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    final EmployeeRepository repo = ref.read(employeeRepositoryProvider);
    final String name = _nameController.text.trim();
    final String code = _codeController.text.trim();

    try {
      if (widget.isReEnrollment) {
        await repo.reEnrollEmployee(
          employeeId: widget.employeeId!,
          embeddings: embeddings,
          modelId: ModelRegistry.sFace.id,
          dimension: ModelRegistry.sFace.expectedOutputSize,
        );
      } else {
        await repo.createEmployee(
          code: code,
          name: name,
          embeddings: embeddings,
          modelId: ModelRegistry.sFace.id,
          dimension: ModelRegistry.sFace.expectedOutputSize,
        );
      }

      ref.read(faceMatcherProvider).clearCache();

      if (mounted) {
        final AppLocalizations l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.enrollmentSuccess)));
        context.pop();
      }
    } catch (e, stack) {
      debugPrint(
        '[ENROLLMENT_SAVE_ERROR] Failed to save enrollment: $e\n$stack',
      );
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isCameraPhase = false;
        });
        final AppLocalizations l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.statusFailed}: ${e.toString().split('\n').first}',
            ),
          ),
        );
      }
    }
  }

  String _getPoseInstruction(AppLocalizations l10n, EnrollmentPose pose) {
    switch (pose) {
      case EnrollmentPose.front:
        return l10n.poseFront;
      case EnrollmentPose.slightLeft:
        return l10n.poseSlightLeft;
      case EnrollmentPose.slightRight:
        return l10n.poseSlightRight;
      case EnrollmentPose.slightUp:
        return l10n.poseSlightUp;
      case EnrollmentPose.slightDown:
        return l10n.poseSlightDown;
    }
  }

  String? _getGuidanceText(AppLocalizations l10n, QualityIssue? issue) {
    if (issue == null) return null;
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _isCameraPhase ? Colors.black : null,
      extendBodyBehindAppBar: _isCameraPhase,
      appBar: AppBar(
        backgroundColor: _isCameraPhase ? Colors.transparent : null,
        elevation: _isCameraPhase ? 0 : null,
        iconTheme: _isCameraPhase
            ? const IconThemeData(color: Colors.white)
            : null,
        titleTextStyle: _isCameraPhase
            ? const TextStyle(
                color: Colors.white,
                fontSize: 20.0,
                fontWeight: FontWeight.w600,
              )
            : null,
        title: Text(
          widget.isReEnrollment ? l10n.reEnrollEmployee : l10n.enrollmentTitle,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isCameraPhase && !widget.isReEnrollment) {
              _cameraService?.stopImageStream().catchError((_) {});
              setState(() => _isCameraPhase = false);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: PopScope(
        canPop: !_isCameraPhase || widget.isReEnrollment,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (!didPop && _isCameraPhase && !widget.isReEnrollment) {
            _cameraService?.stopImageStream().catchError((_) {});
            setState(() => _isCameraPhase = false);
          }
        },
        child: !_isCameraPhase
            ? _buildFormView(l10n, theme)
            : _buildCameraCaptureView(l10n, theme),
      ),
    );
  }

  Widget _buildFormView(AppLocalizations l10n, ThemeData theme) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.enrollmentFormHeader,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.employeeName,
                  hintText: l10n.employeeNameHint,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (String? val) {
                  if (val == null || val.trim().isEmpty) {
                    return l10n.employeeNameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: l10n.employeeCode,
                  hintText: l10n.employeeCodeHint,
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
                validator: (String? val) {
                  if (val == null || val.trim().isEmpty) {
                    return l10n.employeeCodeRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32.0),
              FilledButton.icon(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final String code = _codeController.text.trim();
                  final EmployeeRepository repo = ref.read(
                    employeeRepositoryProvider,
                  );
                  final bool isTaken = await repo.isCodeTaken(
                    code,
                    excludeId: widget.employeeId,
                  );
                  if (isTaken) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.employeeCodeExists)),
                      );
                    }
                    return;
                  }

                  setState(() => _isCameraPhase = true);
                  _initCameraAndSubsystems();
                },
                icon: const Icon(Icons.camera_alt),
                label: Text(l10n.enrollmentStartCapture),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraCaptureView(AppLocalizations l10n, ThemeData theme) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final Rect oval = defaultOvalRect(screenSize);
    final EnrollmentSessionState state =
        _sessionState ??
        const EnrollmentSessionState(
          status: EnrollmentStatus.capturing,
          currentPoseIndex: 0,
          currentPose: EnrollmentPose.front,
          capturedCount: 0,
          holdProgress: 0.0,
        );

    final Size previewBoxSize = _imageSize ?? screenSize;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // 1. Camera Preview
        if (!_isCameraInitializing &&
            _cameraService != null &&
            _cameraService!.isInitialized &&
            _cameraService!.controller != null)
          FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.center,
            child: SizedBox(
              width: previewBoxSize.width,
              height: previewBoxSize.height,
              child: CameraPreview(_cameraService!.controller!),
            ),
          )
        else
          Container(
            color: Colors.black87,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),

        // 2. Oval Guide Painter
        CustomPaint(
          size: screenSize,
          painter: _EnrollmentOvalPainter(
            ovalRect: oval,
            isHolding: state.holdProgress > 0.0,
            holdProgress: state.holdProgress,
          ),
        ),

        // 3. Pose Instructions & Progress Overlay
        SafeArea(
          child: Column(
            children: <Widget>[
              const SizedBox(height: 16.0),

              // Sample counter badge (e.g. Sample 1 of 5)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 6.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  l10n.enrollmentSampleCount(
                    state.capturedCount + 1 > 5 ? 5 : state.capturedCount + 1,
                    5,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 12.0),

              // 5-dot step indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(5, (int i) {
                  final bool isPassed = i < state.capturedCount;
                  final bool isCurrent = i == state.currentPoseIndex;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    width: isCurrent ? 24.0 : 10.0,
                    height: 10.0,
                    decoration: BoxDecoration(
                      color: isPassed
                          ? Colors.greenAccent
                          : isCurrent
                          ? theme.colorScheme.primary
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                  );
                }),
              ),

              const Spacer(),

              // Hold progress bar
              if (state.holdProgress > 0.0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48.0),
                  child: LinearProgressIndicator(
                    value: state.holdProgress,
                    backgroundColor: Colors.white24,
                    color: Colors.greenAccent,
                    minHeight: 6.0,
                  ),
                ),

              const SizedBox(height: 16.0),

              // Instruction card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Card(
                  color: Colors.black87,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _getPoseInstruction(l10n, state.currentPose),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_getGuidanceText(l10n, state.guidanceIssue) !=
                            null) ...<Widget>[
                          const SizedBox(height: 8.0),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10.0,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Text(
                              _getGuidanceText(l10n, state.guidanceIssue)!,
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 13.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24.0),
            ],
          ),
        ),

        // 4. Processing & Saving Overlay
        if (state.status == EnrollmentStatus.processing || _isSaving)
          Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 20.0),
                  Text(
                    l10n.enrollmentProcessing,
                    style: const TextStyle(color: Colors.white, fontSize: 16.0),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _EnrollmentOvalPainter extends CustomPainter {
  const _EnrollmentOvalPainter({
    required this.ovalRect,
    required this.isHolding,
    required this.holdProgress,
  });

  final Rect ovalRect;
  final bool isHolding;
  final double holdProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path ovalPath = Path()..addOval(ovalRect);
    final Path clipPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      ovalPath,
    );

    final Paint dimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    canvas.drawPath(clipPath, dimPaint);

    final Color borderColor = isHolding
        ? Color.lerp(Colors.white, Colors.greenAccent, holdProgress)!
        : Colors.white70;

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHolding ? 4.0 : 2.5;
    canvas.drawOval(ovalRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _EnrollmentOvalPainter oldDelegate) {
    return oldDelegate.isHolding != isHolding ||
        oldDelegate.holdProgress != holdProgress ||
        oldDelegate.ovalRect != ovalRect;
  }
}
