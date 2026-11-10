import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../camera/domain/camera_service.dart';
import '../../camera/domain/frame_data.dart';
import '../../camera/domain/frame_throttler.dart';
import '../../detection/domain/detected_face.dart';
import '../../detection/domain/face_detector.dart';
import '../../detection/domain/oval_guide.dart';
import '../../detection/domain/quality_gate.dart';
import '../../device/domain/device_tier.dart';
import '../../ml/domain/model_registry.dart';
import '../domain/challenge_type.dart';
import '../domain/flash_color.dart';
import '../domain/liveness_session.dart';
import '../domain/session_policy.dart';
import 'widgets/session_oval_painter.dart';

/// Interactive face liveness verification screen.
///
/// Features live front camera preview, elliptical face guide with circular
/// timer progress ring, active challenge instructions, real-time quality gate
/// guidance, full-screen color flash reflection overlay, and lockout protection.
class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({
    super.key,
    this.policy = SessionPolicy.attendance,
    this.sessionOverride,
    this.cameraServiceOverride,
    this.faceDetectorOverride,
  });

  final SessionPolicy policy;
  final LivenessSession? sessionOverride;
  final CameraService? cameraServiceOverride;
  final FaceDetector? faceDetectorOverride;

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen>
    with WidgetsBindingObserver {
  late LivenessSession _session;
  late CameraService _cameraService;
  late FaceDetector _faceDetector;
  late FrameThrottler _throttler;

  StreamSubscription<LivenessSessionState>? _stateSub;
  StreamSubscription<Duration>? _totalTimeSub;
  StreamSubscription<Duration>? _challengeTimeSub;
  StreamSubscription<QualityIssue?>? _guidanceSub;

  LivenessSessionState _currentState = const SessionStateIdle();
  Duration _totalRemaining = const Duration(seconds: 30);
  Duration _challengeRemaining = const Duration(seconds: 6);
  QualityIssue? _guidanceIssue;

  bool _isCameraInitializing = true;
  bool _isProcessingFrame = false;
  bool _isDisposed = false;
  CameraPermissionStatus _permissionStatus = CameraPermissionStatus.unknown;

  Size? _imageSize;
  Timer? _lockoutTicker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSubsystems();
  }

  void _initSubsystems() {
    _session = widget.sessionOverride ?? ref.read(livenessSessionProvider);
    _cameraService =
        widget.cameraServiceOverride ?? ref.read(cameraServiceProvider);
    _faceDetector =
        widget.faceDetectorOverride ?? ref.read(faceDetectorProvider);

    _throttler = FrameThrottler(
      clock: ref.read(clockProvider),
      targetFps: _session.tierProfile.analysisFps,
    );

    _stateSub = _session.stateStream.listen(_onSessionStateChanged);
    _totalTimeSub = _session.totalRemainingTimeStream.listen((Duration d) {
      if (mounted) setState(() => _totalRemaining = d);
    });
    _challengeTimeSub = _session.challengeRemainingTimeStream.listen((
      Duration d,
    ) {
      if (mounted) setState(() => _challengeRemaining = d);
    });
    _guidanceSub = _session.guidanceStream.listen((QualityIssue? issue) {
      if (mounted) setState(() => _guidanceIssue = issue);
    });

    _startCameraAndSession();
  }

  Future<void> _startCameraAndSession() async {
    setState(() => _isCameraInitializing = true);

    final CameraPermissionStatus perm = await _cameraService.checkPermission();
    if (perm != CameraPermissionStatus.granted) {
      final CameraPermissionStatus req = await _cameraService
          .requestPermission();
      if (req != CameraPermissionStatus.granted) {
        if (mounted) {
          setState(() {
            _permissionStatus = req;
            _isCameraInitializing = false;
          });
        }
        return;
      }
    }

    _permissionStatus = CameraPermissionStatus.granted;

    try {
      final TierProfile profile = _session.tierProfile;
      await _cameraService.initialize(
        resolutionPreset: profile.cameraPreset,
        lensDirection: CameraLensDirection.front,
      );

      if (!mounted || _isDisposed) return;

      await _session.start(policy: widget.policy);

      // Pre-warm recognition model while verification session is starting
      ref
          .read(mlWorkerProvider)
          .ensureInitialized(models: <ModelSpec>[ModelRegistry.sFace])
          .catchError((_) {});

      await _cameraService.startImageStream(_handleCameraFrame);

      if (mounted) {
        setState(() => _isCameraInitializing = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCameraInitializing = false);
      }
    }
  }

  void _handleCameraFrame(CameraImage image) {
    if (_isDisposed || !mounted || _isProcessingFrame) return;

    if (!_throttler.shouldProcess()) return;
    _throttler.onFrameStarted();
    _isProcessingFrame = true;

    final Stopwatch sw = Stopwatch()..start();
    final DateTime now = ref.read(clockProvider).now();

    final FrameData frame = FrameData.fromCameraImage(
      image,
      sensorRotation: _cameraService.currentCamera?.sensorOrientation ?? 0,
      lensDirection:
          _cameraService.currentCamera?.lensDirection ??
          CameraLensDirection.front,
      timestamp: now,
    );

    _imageSize = Size(
      frame.uprightWidth.toDouble(),
      frame.uprightHeight.toDouble(),
    );

    _faceDetector
        .detect(frame)
        .then((List<DetectedFace> faces) async {
          if (!mounted || _isDisposed) {
            _isProcessingFrame = false;
            return;
          }

          final DetectedFace? face = faces.length == 1 ? faces.first : null;
          await _session.onFrame(frame, face);
        })
        .catchError((_) {})
        .whenComplete(() {
          _throttler.onFrameCompleted(sw.elapsed);
          _isProcessingFrame = false;
        });
  }

  void _onSessionStateChanged(LivenessSessionState newState) {
    if (!mounted) return;
    setState(() => _currentState = newState);

    if (newState is SessionStateLocked) {
      _startLockoutTimer();
    } else if (newState is SessionStateSucceeded) {
      _navigateToResult(newState.result);
    } else if (newState is SessionStateFailed) {
      if (newState.result != null) {
        _navigateToResult(newState.result!);
      }
    }
  }

  void _startLockoutTimer() {
    _lockoutTicker?.cancel();
    _lockoutTicker = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted || _currentState is! SessionStateLocked) {
        t.cancel();
        return;
      }
      final SessionStateLocked locked = _currentState as SessionStateLocked;
      final int rem = ref
          .read(clockProvider)
          .now()
          .difference(locked.lockedUntil)
          .inSeconds
          .abs();
      if (rem <= 0) {
        t.cancel();
        _session.start(policy: widget.policy);
      } else {
        setState(() {
          _currentState = SessionStateLocked(
            lockedUntil: locked.lockedUntil,
            remainingSeconds: rem,
          );
        });
      }
    });
  }

  void _navigateToResult(LiveSessionResult result) {
    _cameraService.stopImageStream().catchError((_) {});
    context.pushReplacement('/result', extra: result);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraService.stopImageStream().catchError((_) {});
      _session.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startCameraAndSession();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _lockoutTicker?.cancel();
    _stateSub?.cancel();
    _totalTimeSub?.cancel();
    _challengeTimeSub?.cancel();
    _guidanceSub?.cancel();
    _cameraService.stopImageStream().catchError((_) {});
    super.dispose();
  }

  Color _getStateColor() {
    switch (_currentState) {
      case SessionStateIdle():
      case SessionStatePositioning():
        return Colors.amber;
      case SessionStateNeutral():
        return Colors.cyanAccent;
      case SessionStateChallenge():
        return Colors.lightBlueAccent;
      case SessionStateFlash(color: final FlashColor c):
        return Color.fromARGB(255, c.r, c.g, c.b);
      case SessionStateFinalizing():
        return Colors.tealAccent;
      case SessionStateSucceeded():
        return Colors.green;
      case SessionStateFailed():
      case SessionStateLocked():
        return Colors.redAccent;
    }
  }

  String _getInstructionText(AppLocalizations l10n) {
    switch (_currentState) {
      case SessionStateIdle():
      case SessionStatePositioning():
        return l10n.statePositioning;
      case SessionStateNeutral():
        return l10n.stateNeutral;
      case SessionStateChallenge(type: final ChallengeType type):
        switch (type) {
          case ChallengeType.lookStraight:
            return l10n.challengeLookStraight;
          case ChallengeType.blink:
            return l10n.challengeBlink;
          case ChallengeType.turnLeft:
            return l10n.challengeTurnLeft;
          case ChallengeType.turnRight:
            return l10n.challengeTurnRight;
          case ChallengeType.smile:
            return l10n.challengeSmile;
        }
      case SessionStateFlash():
        return l10n.flashStatus;
      case SessionStateFinalizing():
        return l10n.stateFinalizing;
      case SessionStateSucceeded():
        return l10n.stateSucceeded;
      case SessionStateFailed():
        return l10n.stateFailed;
      case SessionStateLocked():
        return l10n.stateLocked;
    }
  }

  String? _getGuidanceText(AppLocalizations l10n) {
    if (_guidanceIssue == null) return null;
    switch (_guidanceIssue!) {
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
    final Size screenSize = MediaQuery.sizeOf(context);

    // Permission handling UI
    if (_permissionStatus == CameraPermissionStatus.denied ||
        _permissionStatus == CameraPermissionStatus.permanentlyDenied) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.verificationTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  l10n.devCameraPermissionRequired,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                if (_permissionStatus ==
                    CameraPermissionStatus.permanentlyDenied)
                  FilledButton(
                    onPressed: _cameraService.openSettings,
                    child: Text(l10n.devCameraOpenSettings),
                  )
                else
                  FilledButton(
                    onPressed: _startCameraAndSession,
                    child: Text(l10n.devCameraGrantPermission),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final Rect oval = defaultOvalRect(screenSize);
    final double totalProgress =
        _totalRemaining.inMilliseconds /
        _session.config.sessionTimeout.inMilliseconds;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          tooltip: l10n.actionCancel,
          onPressed: () {
            _session.cancel();
            context.pop();
          },
        ),
        title: Text(
          l10n.verificationTitle,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // 1. Camera Preview
          if (!_isCameraInitializing &&
              _cameraService.isInitialized &&
              _cameraService.controller != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _imageSize?.width ?? screenSize.width,
                height: _imageSize?.height ?? screenSize.height,
                child: CameraPreview(_cameraService.controller!),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // 2. Oval Guide and Total Session Timer Ring
          CustomPaint(
            size: screenSize,
            painter: SessionOvalPainter(
              ovalRect: oval,
              borderColor: _getStateColor(),
              totalProgress: totalProgress,
            ),
          ),

          // 3. Screen Flash Overlay (when active)
          if (_currentState is SessionStateFlash)
            Container(
              color: Color.fromARGB(
                230,
                (_currentState as SessionStateFlash).color.r,
                (_currentState as SessionStateFlash).color.g,
                (_currentState as SessionStateFlash).color.b,
              ),
            ),

          // 4. Instructions and Guidance Overlay
          SafeArea(
            child: Column(
              children: <Widget>[
                const SizedBox(height: 16),

                // Total timer countdown pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _getStateColor().withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    l10n.totalTimeRemaining(_totalRemaining.inSeconds),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                // Challenge progress indicator (if in challenge state)
                if (_currentState is SessionStateChallenge) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48.0),
                    child: Column(
                      children: <Widget>[
                        LinearProgressIndicator(
                          value:
                              (_currentState as SessionStateChallenge).progress,
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getStateColor(),
                          ),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.totalTimeRemaining(
                            _challengeRemaining.inSeconds,
                          ),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Prominent Instruction Banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStateColor(), width: 1.5),
                    ),
                    child: Text(
                      _getInstructionText(l10n),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Quality Guidance message (if present)
                if (_getGuidanceText(l10n) != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getGuidanceText(l10n)!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // 5. Fullscreen Lockout Overlay (when locked)
          if (_currentState is SessionStateLocked)
            Container(
              color: Colors.black.withValues(alpha: 0.92),
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.lock_clock,
                      color: Colors.redAccent,
                      size: 64,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.stateLocked,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.lockoutCountdown(
                        (_currentState as SessionStateLocked).remainingSeconds,
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 28),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                      ),
                      onPressed: () => context.pop(),
                      child: Text(l10n.actionDone),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
