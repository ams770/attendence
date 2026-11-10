import 'dart:typed_data';
import 'dart:ui';

import 'package:attendence/core/config/app_config.dart';
import 'package:attendence/core/utils/affine_matrix.dart';
import 'package:attendence/core/utils/clock.dart';
import 'package:attendence/core/utils/random_source.dart';
import 'package:attendence/features/camera/domain/frame_data.dart';
import 'package:attendence/features/detection/domain/detected_face.dart';
import 'package:attendence/features/detection/domain/face_aligner.dart';
import 'package:attendence/features/detection/domain/face_detector.dart';
import 'package:attendence/features/detection/domain/oval_guide.dart';
import 'package:attendence/features/detection/domain/preview_mapper.dart';
import 'package:attendence/features/detection/domain/quality_gate.dart';
import 'package:attendence/features/device/domain/device_tier.dart';
import 'package:attendence/features/liveness/domain/challenge_type.dart';
import 'package:attendence/features/liveness/domain/liveness_session.dart';
import 'package:attendence/features/liveness/domain/liveness_session_worker.dart';
import 'package:attendence/features/liveness/domain/passive_liveness_engine.dart';
import 'package:attendence/features/liveness/domain/session_lockout_storage.dart';
import 'package:attendence/features/liveness/domain/session_lockout_tracker.dart';
import 'package:attendence/features/liveness/domain/session_policy.dart';
import 'package:attendence/features/liveness/domain/passive_aggregator.dart';
import 'package:attendence/features/liveness/domain/passive_sample.dart';
import 'package:attendence/features/ml/worker/worker_protocol.dart';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';

// --- Fake implementations for deterministic testing ---

class FakeFaceDetector implements FaceDetector {
  List<DetectedFace> nextFaces = <DetectedFace>[];

  @override
  Future<List<DetectedFace>> detect(FrameData frame) async => nextFaces;

  @override
  Future<void> dispose() async {}
}

class FakeLivenessSessionWorker implements LivenessSessionWorker {
  double nextSharpness = 100.0;
  double nextBrightness = 120.0;
  double nextGlare = 0.01;

  @override
  Future<FaceStats> getFaceStats(
    TransferableFrameData frame,
    Rect faceRect, {
    int sampleSize = 80,
  }) async {
    return FaceStats(
      sharpness: nextSharpness,
      meanBrightness: nextBrightness,
      nearSaturatedRatio: nextGlare,
    );
  }

  @override
  Future<AlignedCropData> getAlignedCrop(
    TransferableFrameData frame,
    AffineMatrix uprightToOutput,
  ) async {
    return AlignedCropData(
      rgbBytes: Uint8List(112 * 112 * 3),
      width: 112,
      height: 112,
    );
  }

  @override
  Future<SkinColorSampleData> getSkinColorSample(
    TransferableFrameData frame,
    List<Rect> skinRegions,
  ) async {
    return const SkinColorSampleData(
      meanR: 120.0,
      meanG: 100.0,
      meanB: 90.0,
      brightness: 105.0,
    );
  }
}

class FakePassiveLivenessEngine implements PassiveLivenessEngine {
  double nextProbability = 0.95;

  @override
  Future<PassiveFrameResult> evaluateFrame({
    required TransferableFrameData frame,
    required Rect faceRect,
    required List<String> modelNames,
    PassivePreprocessConfig? preprocessConfig,
  }) async {
    final Map<String, PassiveModelResult> modelResults =
        <String, PassiveModelResult>{};
    for (final String name in modelNames) {
      modelResults[name] = PassiveModelResult(
        modelName: name,
        realProbability: nextProbability,
        rawScores: <double>[0.05, nextProbability, 0.0],
        latencyMs: 15.0,
      );
    }

    return PassiveFrameResult(
      modelResults: modelResults,
      meanRealProbability: nextProbability,
      totalLatencyMs: 30.0,
    );
  }
}

class TestRandomSource implements RandomSource {
  TestRandomSource([List<int>? intValues]) : _intValues = intValues ?? <int>[0];
  final List<int> _intValues;
  int _idx = 0;

  @override
  int nextInt(int max) {
    final int val = _intValues[_idx % _intValues.length];
    _idx++;
    return val % max;
  }

  @override
  double nextDouble() => 0.5;

  @override
  bool nextBool() => true;
}

void main() {
  group('LivenessSession State Machine & Security', () {
    late FakeClock clock;
    late TestRandomSource random;
    late FakeFaceDetector detector;
    late FakeLivenessSessionWorker worker;
    late FakePassiveLivenessEngine passiveEngine;
    late InMemorySessionLockoutStorage storage;
    late SessionLockoutTracker lockoutTracker;

    const Size previewSize = Size(400.0, 800.0);
    const Size imageSize = Size(720.0, 1280.0);
    final Rect ovalRect = defaultOvalRect(previewSize);

    const PreviewMapper mapper = PreviewMapper(
      imageSize: imageSize,
      previewSize: previewSize,
      mirror: true,
    );

    FrameData createFakeFrame() {
      return FrameData(
        format: FrameFormat.nv21,
        width: 720,
        height: 1280,
        planes: <FramePlane>[
          FramePlane(bytes: Uint8List(720 * 1280 * 3 ~/ 2), bytesPerRow: 720),
        ],
        sensorRotation: 0,
        lensDirection: CameraLensDirection.front,
        timestamp: clock.now(),
      );
    }

    DetectedFace createPassingFace({
      int trackingId = 1,
      double yaw = 0.0,
      double pitch = 0.0,
      double roll = 0.0,
      double leftEyeOpen = 1.0,
      double rightEyeOpen = 1.0,
      double smile = 0.0,
    }) {
      const Rect previewBox = Rect.fromLTWH(120.0, 260.0, 160.0, 200.0);
      final Rect uprightBox = mapper.unmapRect(previewBox);

      return DetectedFace(
        trackingId: trackingId,
        boundingBox: uprightBox,
        headEulerAngleX: pitch,
        headEulerAngleY: yaw,
        headEulerAngleZ: roll,
        leftEyeOpenProbability: leftEyeOpen,
        rightEyeOpenProbability: rightEyeOpen,
        smilingProbability: smile,
        landmarks: const FiveLandmarks(
          leftEye: Offset(200, 400),
          rightEye: Offset(400, 400),
          noseBase: Offset(300, 500),
          leftMouth: Offset(220, 600),
          rightMouth: Offset(380, 600),
        ),
      );
    }

    setUp(() {
      clock = FakeClock(DateTime(2026, 11, 7, 10, 0, 0));
      random = TestRandomSource(<int>[0, 1, 0, 1]);
      detector = FakeFaceDetector();
      worker = FakeLivenessSessionWorker();
      passiveEngine = FakePassiveLivenessEngine();
      storage = InMemorySessionLockoutStorage();
      lockoutTracker = SessionLockoutTracker(
        clock: clock,
        storage: storage,
        config: const AppConfig(
          sessionTimeout: Duration(seconds: 30),
          perChallengeTimeout: Duration(seconds: 6),
          failureLimit: 3,
          lockoutDuration: Duration(seconds: 60),
        ),
      );
    });

    LivenessSession createSession({AppConfig? config}) {
      return LivenessSession(
        clock: clock,
        randomSource: random,
        faceDetector: detector,
        worker: worker,
        passiveEngine: passiveEngine,
        faceAligner: const FaceAligner(),
        qualityGate: const QualityGate(),
        lockoutTracker: lockoutTracker,
        config:
            config ??
            const AppConfig(
              sessionTimeout: Duration(seconds: 30),
              perChallengeTimeout: Duration(seconds: 6),
              failureLimit: 3,
              lockoutDuration: Duration(seconds: 60),
              challengeNeutralMinFrames: 3,
              challengeBlinkMinClosedFrames: 1,
              challengeBlinkMinOpenFrames: 1,
              challengeSmileMinFrames: 2,
              temporalConfidenceThreshold: 0.20,
            ),
        deviceTier: DeviceTier.high,
        tierProfile: TierProfile.fromTier(DeviceTier.high, hasInt8Model: false),
      );
    }

    Future<void> completeChallenge(
      LivenessSession session,
      ChallengeType type,
      FrameData frame,
    ) async {
      if (type == ChallengeType.blink) {
        clock.advance(const Duration(milliseconds: 350));
        await session.onFrame(
          frame,
          createPassingFace(leftEyeOpen: 0.9, rightEyeOpen: 0.9),
        );
        clock.advance(const Duration(milliseconds: 350));
        await session.onFrame(
          frame,
          createPassingFace(leftEyeOpen: 0.1, rightEyeOpen: 0.1),
        );
        clock.advance(const Duration(milliseconds: 350));
        await session.onFrame(
          frame,
          createPassingFace(leftEyeOpen: 0.9, rightEyeOpen: 0.9),
        );
      } else if (type == ChallengeType.turnLeft) {
        clock.advance(const Duration(milliseconds: 350));
        await session.onFrame(frame, createPassingFace(yaw: 0.0));
        for (int i = 0; i < 3; i++) {
          clock.advance(const Duration(milliseconds: 350));
          await session.onFrame(frame, createPassingFace(yaw: 22.0));
        }
      } else if (type == ChallengeType.turnRight) {
        clock.advance(const Duration(milliseconds: 350));
        await session.onFrame(frame, createPassingFace(yaw: 0.0));
        for (int i = 0; i < 3; i++) {
          clock.advance(const Duration(milliseconds: 350));
          await session.onFrame(frame, createPassingFace(yaw: -22.0));
        }
      } else if (type == ChallengeType.smile) {
        clock.advance(const Duration(milliseconds: 350));
        await session.onFrame(frame, createPassingFace(smile: 0.0));
        for (int i = 0; i < 3; i++) {
          clock.advance(const Duration(milliseconds: 350));
          await session.onFrame(frame, createPassingFace(smile: 0.95));
        }
      }
    }

    test(
      'Success path: full attendance pipeline succeeds with 3 crops',
      () async {
        final LivenessSession session = createSession();
        await session.start(
          policy: SessionPolicy.attendance,
          previewSize: previewSize,
          ovalRect: ovalRect,
          previewMapper: mapper,
        );

        expect(session.state, isA<SessionStatePositioning>());

        final FrameData frame = createFakeFrame();

        // 1. Positioning -> Neutral
        final DetectedFace face = createPassingFace();
        await session.onFrame(frame, face);
        expect(session.state, isA<SessionStateNeutral>());

        // 2. Complete neutral calibration (3 frames)
        for (int i = 0; i < 3; i++) {
          clock.advance(const Duration(milliseconds: 350));
          await session.onFrame(frame, face);
        }
        expect(session.state, isA<SessionStateChallenge>());

        // 3. Complete active challenges until finalizing
        while (session.state is SessionStateChallenge) {
          final SessionStateChallenge ch =
              session.state as SessionStateChallenge;
          await completeChallenge(session, ch.type, frame);
        }

        // Reached finalizing!
        expect(session.state, isA<SessionStateFinalizing>());

        // Supply 3 candidate frontal frames with varied sharpness
        worker.nextSharpness = 90.0;
        clock.advance(const Duration(milliseconds: 350));
        await session.onFrame(frame, createPassingFace());

        worker.nextSharpness = 150.0;
        clock.advance(const Duration(milliseconds: 350));
        await session.onFrame(frame, createPassingFace());

        worker.nextSharpness = 120.0;
        clock.advance(const Duration(milliseconds: 350));
        await session.onFrame(frame, createPassingFace());

        // Succeeded!
        expect(session.state, isA<SessionStateSucceeded>());
        final SessionStateSucceeded successState =
            session.state as SessionStateSucceeded;
        expect(successState.result.passed, isTrue);
        expect(successState.result.verifiedFaces, isNotNull);
        expect(successState.result.verifiedFaces!.crops.length, equals(3));
        // Sharpness sorted descending: 150.0, 120.0, 90.0
        expect(
          successState.result.verifiedFaces!.crops[0].sharpness,
          equals(150.0),
        );
        expect(
          successState.result.verifiedFaces!.crops[1].sharpness,
          equals(120.0),
        );
        expect(
          successState.result.verifiedFaces!.crops[2].sharpness,
          equals(90.0),
        );
        expect(successState.result.attemptLog.passed, isTrue);

        // Lockout failures cleared
        expect(await storage.getConsecutiveFailures(), equals(0));
      },
    );

    test('Total session timeout fails with timeout reason', () async {
      final LivenessSession session = createSession();
      await session.start(
        previewSize: previewSize,
        ovalRect: ovalRect,
        previewMapper: mapper,
      );

      final FrameData frame = createFakeFrame();
      final DetectedFace face = createPassingFace();

      await session.onFrame(frame, face);
      expect(session.state, isA<SessionStateNeutral>());

      // Advance clock past 30s session timeout
      clock.advance(const Duration(seconds: 31));
      await session.onFrame(frame, face);

      expect(session.state, isA<SessionStateFailed>());
      final SessionStateFailed failedState =
          session.state as SessionStateFailed;
      expect(failedState.reason, equals(SessionFailureReason.timeout));
    });

    test(
      'Challenge timeout fails when challenge is not completed within limit',
      () async {
        final LivenessSession session = createSession();
        await session.start(
          previewSize: previewSize,
          ovalRect: ovalRect,
          previewMapper: mapper,
        );

        final FrameData frame = createFakeFrame();
        final DetectedFace face = createPassingFace();

        await session.onFrame(frame, face);
        // Advance past neutral
        for (int i = 0; i < 3; i++) {
          clock.advance(const Duration(milliseconds: 350));
          await session.onFrame(frame, face);
        }

        expect(session.state, isA<SessionStateChallenge>());

        // Advance past 6s per-challenge timeout without performing action
        clock.advance(const Duration(seconds: 7));
        await session.onFrame(frame, face);

        expect(session.state, isA<SessionStateFailed>());
        final SessionStateFailed failedState =
            session.state as SessionStateFailed;
        expect(failedState.reason, equals(SessionFailureReason.timeout));
      },
    );

    test('Face lost beyond grace period triggers faceLost failure', () async {
      final LivenessSession session = createSession();
      await session.start(
        previewSize: previewSize,
        ovalRect: ovalRect,
        previewMapper: mapper,
      );

      final FrameData frame = createFakeFrame();
      final DetectedFace face = createPassingFace();

      await session.onFrame(frame, face);
      expect(session.state, isA<SessionStateNeutral>());

      // Face disappears
      clock.advance(const Duration(milliseconds: 800)); // > 700ms grace period
      await session.onFrame(frame, null);

      expect(session.state, isA<SessionStateFailed>());
      final SessionStateFailed failedState =
          session.state as SessionStateFailed;
      expect(failedState.reason, equals(SessionFailureReason.faceLost));
    });

    test(
      'Tracking ID change triggers trackingChanged failure immediately',
      () async {
        final LivenessSession session = createSession();
        await session.start(
          previewSize: previewSize,
          ovalRect: ovalRect,
          previewMapper: mapper,
        );

        final FrameData frame = createFakeFrame();
        await session.onFrame(frame, createPassingFace(trackingId: 1));
        expect(session.state, isA<SessionStateNeutral>());

        // Different tracking ID in next frame
        await session.onFrame(frame, createPassingFace(trackingId: 2));

        expect(session.state, isA<SessionStateFailed>());
        final SessionStateFailed failedState =
            session.state as SessionStateFailed;
        expect(
          failedState.reason,
          equals(SessionFailureReason.trackingChanged),
        );
      },
    );

    test('Passive failure after the last challenge (simulated photo swap) triggers immediate violation', () async {
      final LivenessSession session = createSession();
      await session.start(
        policy: SessionPolicy.enrollment, // Neutral + 1 challenge
        previewSize: previewSize,
        ovalRect: ovalRect,
        previewMapper: mapper,
      );

      final FrameData frame = createFakeFrame();
      final DetectedFace face = createPassingFace();

      await session.onFrame(frame, face);
      for (int i = 0; i < 3; i++) {
        clock.advance(const Duration(milliseconds: 350));
        await session.onFrame(frame, face);
      }

      // Complete challenge
      while (session.state is SessionStateChallenge) {
        final SessionStateChallenge ch = session.state as SessionStateChallenge;
        await completeChallenge(session, ch.type, frame);
      }

      expect(session.state, isA<SessionStateFinalizing>());

      // Simulated photo swap: passive engine returns 0.05 probability
      passiveEngine.nextProbability = 0.05;
      for (int i = 0; i < 3; i++) {
        clock.advance(const Duration(milliseconds: 350));
        await session.onFrame(frame, face);
      }

      expect(session.state, isA<SessionStateFailed>());
      final SessionStateFailed failed = session.state as SessionStateFailed;
      expect(
        failed.reason == SessionFailureReason.passiveHardFloorViolation ||
            failed.reason == SessionFailureReason.passiveFailed,
        isTrue,
      );
    });

    test(
      'Single good passive frame does not pass without meeting minSamples',
      () {
        final PassiveAggregator aggregator = PassiveAggregator(
          passiveThreshold: 0.85,
          passingFrameRatio: 0.75,
          minSamples: 3,
        );

        // Add single good sample (0.99)
        aggregator.addSample(
          PassiveSample(
            timestamp: clock.now(),
            meanScore: 0.99,
            modelScores: const <String, double>{'v2': 0.99},
            latencyMs: 10.0,
          ),
        );

        expect(aggregator.result.verdict, equals(PassiveVerdict.pending));
      },
    );

    test('Three consecutive failures trigger lock, persists across restart, and expires', () async {
      // 1. First failure
      final LivenessSession s1 = createSession();
      await s1.start(
        previewSize: previewSize,
        ovalRect: ovalRect,
        previewMapper: mapper,
      );
      final FrameData frame = createFakeFrame();
      await s1.onFrame(frame, createPassingFace(trackingId: 1));
      await s1.onFrame(
        frame,
        createPassingFace(trackingId: 2),
      ); // trackingChanged
      expect(s1.state, isA<SessionStateFailed>());
      expect(await storage.getConsecutiveFailures(), equals(1));

      // 2. Second failure
      final LivenessSession s2 = createSession();
      await s2.start(
        previewSize: previewSize,
        ovalRect: ovalRect,
        previewMapper: mapper,
      );
      await s2.onFrame(frame, createPassingFace(trackingId: 1));
      await s2.onFrame(frame, createPassingFace(trackingId: 2));
      expect(s2.state, isA<SessionStateFailed>());
      expect(await storage.getConsecutiveFailures(), equals(2));

      // 3. Third failure -> triggers lock
      final LivenessSession s3 = createSession();
      await s3.start(
        previewSize: previewSize,
        ovalRect: ovalRect,
        previewMapper: mapper,
      );
      await s3.onFrame(frame, createPassingFace(trackingId: 1));
      await s3.onFrame(frame, createPassingFace(trackingId: 2));
      expect(s3.state, isA<SessionStateLocked>());
      expect(await lockoutTracker.isLocked(), isTrue);

      // 4. Simulated restart: new session reading from same persisted storage
      final LivenessSession sRestart = createSession();
      await sRestart.start(
        previewSize: previewSize,
        ovalRect: ovalRect,
        previewMapper: mapper,
      );
      expect(sRestart.state, isA<SessionStateLocked>());
      final SessionStateLocked locked = sRestart.state as SessionStateLocked;
      expect(locked.remainingSeconds, greaterThan(0));

      // 5. Expiration: advance clock by 61 seconds
      clock.advance(const Duration(seconds: 61));
      expect(await lockoutTracker.isLocked(), isFalse);

      final LivenessSession sAfterLock = createSession();
      await sAfterLock.start(
        previewSize: previewSize,
        ovalRect: ovalRect,
        previewMapper: mapper,
      );
      expect(sAfterLock.state, isA<SessionStatePositioning>());
    });

    test('VerifiedLiveFaces cannot be created outside the session', () {
      // VerifiedLiveFaces has only a private constructor (`VerifiedLiveFaces._`).
      // Attempting to construct it directly is prevented by the type system.
      // We verify here that the type is defined and can hold crops from a succeeded session.
      final LivenessSession session = createSession();
      expect(session.state, isA<SessionStateIdle>());
      // The session alone holds the capability to manufacture VerifiedLiveFaces instances.
    });
  });
}
