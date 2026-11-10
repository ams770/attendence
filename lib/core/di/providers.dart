import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../crypto/encryption_service.dart';
import '../database/app_database.dart';
import '../utils/clock.dart';
import '../utils/random_source.dart';
import '../../features/camera/data/camera_service_impl.dart';
import '../../features/camera/domain/camera_service.dart';
import '../../features/detection/data/mlkit_face_detector.dart';
import '../../features/detection/domain/face_aligner.dart';
import '../../features/detection/domain/face_detector.dart';
import '../../features/detection/domain/quality_gate.dart';
import '../../features/device/domain/device_benchmark.dart';
import '../../features/device/domain/device_tier.dart';
import '../../features/employees/data/drift_employee_repository.dart';
import '../../features/employees/domain/employee_repository.dart';
import '../../features/employees/domain/enrollment_session.dart';
import '../../features/liveness/data/onnx_passive_liveness_engine.dart';
import '../../features/liveness/domain/challenge_selector.dart';
import '../../features/liveness/domain/flash_config.dart';
import '../../features/liveness/domain/flash_evaluator.dart';
import '../../features/liveness/domain/liveness_session.dart';
import '../../features/liveness/domain/liveness_session_worker.dart';
import '../../features/liveness/domain/passive_aggregator.dart';
import '../../features/liveness/domain/passive_cropper.dart';
import '../../features/liveness/domain/passive_liveness_engine.dart';
import '../../features/liveness/domain/passive_monitor.dart';
import '../../features/liveness/domain/passive_scheduler.dart';
import '../../features/liveness/domain/session_lockout_storage.dart';
import '../../features/liveness/domain/session_lockout_tracker.dart';
import '../../features/liveness/domain/temporal_analyzer.dart';
import '../../features/liveness/domain/temporal_config.dart';
import '../../features/ml/data/onnx_inference_engine.dart';
import '../../features/ml/domain/inference_engine.dart';
import '../../features/ml/domain/model_self_check.dart';
import '../../features/ml/sampler/pixel_sampler.dart';
import '../../features/ml/worker/ml_worker.dart';
import '../../features/recognition/data/sface_recognizer_impl.dart';
import '../../features/recognition/domain/face_matcher.dart';
import '../../features/recognition/domain/face_recognizer.dart';

/// Provider for app configuration values.
final Provider<AppConfig> appConfigProvider = Provider<AppConfig>(
  (Ref ref) => const AppConfig(),
);

/// Provider for system clock abstraction.
final Provider<Clock> clockProvider = Provider<Clock>(
  (Ref ref) => const SystemClock(),
);

/// Provider for random source abstraction.
final Provider<RandomSource> randomSourceProvider = Provider<RandomSource>(
  (Ref ref) => SecureRandomSource(),
);

/// Provider for the ONNX inference engine on the main thread (used for self-check).
final Provider<InferenceEngine> inferenceEngineProvider =
    Provider<InferenceEngine>((Ref ref) {
      final OnnxInferenceEngine engine = OnnxInferenceEngine();
      ref.onDispose(engine.dispose);
      return engine;
    });

/// Provider for the startup model self-check runner.
final Provider<ModelSelfCheck> modelSelfCheckProvider =
    Provider<ModelSelfCheck>((Ref ref) {
      final InferenceEngine engine = ref.watch(inferenceEngineProvider);
      return ModelSelfCheck(engine: engine);
    });

/// State notifier managing the startup model self-check.
class SelfCheckNotifier extends AsyncNotifier<SelfCheckReport> {
  @override
  Future<SelfCheckReport> build() async {
    final ModelSelfCheck checker = ref.watch(modelSelfCheckProvider);
    return checker.runCheck();
  }

  /// Retries the self-check process.
  Future<void> retry() async {
    state = const AsyncValue<SelfCheckReport>.loading();
    state = await AsyncValue.guard(() async {
      final ModelSelfCheck checker = ref.read(modelSelfCheckProvider);
      return checker.runCheck();
    });
  }
}

/// Provider managing self-check execution and retry lifecycle.
final AsyncNotifierProvider<SelfCheckNotifier, SelfCheckReport>
selfCheckProvider = AsyncNotifierProvider<SelfCheckNotifier, SelfCheckReport>(
  SelfCheckNotifier.new,
);

/// Provider for pure Dart pixel sampler.
final Provider<PixelSampler> pixelSamplerProvider = Provider<PixelSampler>(
  (Ref ref) => const PixelSampler(),
);

/// Provider for the long-lived background ML worker isolate.
final Provider<MlWorker> mlWorkerProvider = Provider<MlWorker>((Ref ref) {
  final MlWorker worker = MlWorker();
  ref.onDispose(worker.dispose);
  return worker;
});

/// Provider for device benchmark and tier classification.
final Provider<DeviceBenchmark> deviceBenchmarkProvider =
    Provider<DeviceBenchmark>((Ref ref) {
      final MlWorker worker = ref.watch(mlWorkerProvider);
      return DeviceBenchmark(worker: worker);
    });

/// Provider for current effective hardware tier.
final FutureProvider<DeviceTier> effectiveTierProvider =
    FutureProvider<DeviceTier>((Ref ref) async {
      final DeviceBenchmark benchmark = ref.watch(deviceBenchmarkProvider);
      return benchmark.getEffectiveTier();
    });

/// Provider for tier-adjusted execution profile.
final FutureProvider<TierProfile> tierProfileProvider =
    FutureProvider<TierProfile>((Ref ref) async {
      final DeviceTier tier = await ref.watch(effectiveTierProvider.future);
      final DeviceBenchmark benchmark = ref.watch(deviceBenchmarkProvider);
      final bool hasInt8 = await benchmark.hasInt8Model();
      return TierProfile.fromTier(tier, hasInt8Model: hasInt8);
    });

/// Provider for device camera hardware and streaming service.
final Provider<CameraService> cameraServiceProvider = Provider<CameraService>((
  Ref ref,
) {
  final CameraServiceImpl service = CameraServiceImpl();
  ref.onDispose(service.dispose);
  return service;
});

/// Provider for face detection via Google ML Kit.
final Provider<FaceDetector> faceDetectorProvider = Provider<FaceDetector>((
  Ref ref,
) {
  final MlKitFaceDetector detector = MlKitFaceDetector();
  ref.onDispose(detector.dispose);
  return detector;
});

/// Provider for quality gate evaluation.
final Provider<QualityGate> qualityGateProvider = Provider<QualityGate>((
  Ref ref,
) {
  return const QualityGate();
});

/// Provider for face alignment transform.
final Provider<FaceAligner> faceAlignerProvider = Provider<FaceAligner>((
  Ref ref,
) {
  return const FaceAligner();
});

/// Provider for passive face cropper.
final Provider<PassiveCropper> passiveCropperProvider =
    Provider<PassiveCropper>((Ref ref) {
      final PixelSampler sampler = ref.watch(pixelSamplerProvider);
      return PassiveCropper(sampler: sampler);
    });

/// Provider for passive anti-spoofing liveness engine.
final Provider<PassiveLivenessEngine> passiveLivenessEngineProvider =
    Provider<PassiveLivenessEngine>((Ref ref) {
      final MlWorker worker = ref.watch(mlWorkerProvider);
      final AppConfig config = ref.watch(appConfigProvider);
      return OnnxPassiveLivenessEngine(worker: worker, config: config);
    });

/// Provider for passive liveness aggregator.
final Provider<PassiveAggregator> passiveAggregatorProvider =
    Provider<PassiveAggregator>((Ref ref) {
      final AppConfig config = ref.watch(appConfigProvider);
      return PassiveAggregator(
        passiveThreshold: config.passiveThreshold,
        passingFrameRatio: config.passivePassingFrameRatio,
      );
    });

/// Provider for passive frame sampling scheduler.
final Provider<PassiveScheduler>
passiveSchedulerProvider = Provider<PassiveScheduler>((Ref ref) {
  // Default to 8 target samples; tier-specific sessions configure dynamically.
  return PassiveScheduler(targetTotalSamples: 8);
});

/// Provider for passive hard floor monitor.
final Provider<PassiveMonitor> passiveMonitorProvider =
    Provider<PassiveMonitor>((Ref ref) {
      final AppConfig config = ref.watch(appConfigProvider);
      return PassiveMonitor(hardFloor: config.passiveHardFloor);
    });

/// Provider for randomized active challenge selection.
final Provider<ChallengeSelector> challengeSelectorProvider =
    Provider<ChallengeSelector>((Ref ref) {
      final RandomSource random = ref.watch(randomSourceProvider);
      return ChallengeSelector(randomSource: random);
    });

/// Provider for multi-signal temporal motion and consistency analyzer.
final Provider<TemporalAnalyzer> temporalAnalyzerProvider =
    Provider<TemporalAnalyzer>((Ref ref) {
      final AppConfig config = ref.watch(appConfigProvider);
      return TemporalAnalyzer(config: TemporalConfig.fromAppConfig(config));
    });

/// Provider for screen-color-flash reflection evaluator.
final Provider<FlashEvaluator> flashEvaluatorProvider =
    Provider<FlashEvaluator>((Ref ref) {
      final AppConfig config = ref.watch(appConfigProvider);
      return FlashEvaluator(config: FlashConfig.fromAppConfig(config));
    });

/// Provider for persistent session lockout storage.
final Provider<SessionLockoutStorage> sessionLockoutStorageProvider =
    Provider<SessionLockoutStorage>((Ref ref) {
      return SharedPrefsSessionLockoutStorage();
    });

/// Provider for verification attempt lockout management.
final Provider<SessionLockoutTracker> sessionLockoutTrackerProvider =
    Provider<SessionLockoutTracker>((Ref ref) {
      final Clock clock = ref.watch(clockProvider);
      final SessionLockoutStorage storage = ref.watch(
        sessionLockoutStorageProvider,
      );
      final AppConfig config = ref.watch(appConfigProvider);
      return SessionLockoutTracker(
        clock: clock,
        storage: storage,
        config: config,
      );
    });

/// Provider for worker operations adapter used by liveness verification.
final Provider<LivenessSessionWorker> livenessSessionWorkerProvider =
    Provider<LivenessSessionWorker>((Ref ref) {
      final MlWorker worker = ref.watch(mlWorkerProvider);
      return MlWorkerLivenessAdapter(worker: worker);
    });

/// Provider for multi-layer liveness verification session orchestrator.
final Provider<LivenessSession> livenessSessionProvider =
    Provider<LivenessSession>((Ref ref) {
      final Clock clock = ref.watch(clockProvider);
      final RandomSource random = ref.watch(randomSourceProvider);
      final FaceDetector detector = ref.watch(faceDetectorProvider);
      final LivenessSessionWorker worker = ref.watch(
        livenessSessionWorkerProvider,
      );
      final PassiveLivenessEngine passiveEngine = ref.watch(
        passiveLivenessEngineProvider,
      );
      final FaceAligner faceAligner = ref.watch(faceAlignerProvider);
      final QualityGate qualityGate = ref.watch(qualityGateProvider);
      final SessionLockoutTracker lockoutTracker = ref.watch(
        sessionLockoutTrackerProvider,
      );
      final AppConfig config = ref.watch(appConfigProvider);

      final LivenessSession session = LivenessSession(
        clock: clock,
        randomSource: random,
        faceDetector: detector,
        worker: worker,
        passiveEngine: passiveEngine,
        faceAligner: faceAligner,
        qualityGate: qualityGate,
        lockoutTracker: lockoutTracker,
        config: config,
      );
      ref.onDispose(session.dispose);
      return session;
    });

/// Provider for Drift SQLite database instance.
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((
  Ref ref,
) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Provider for AES-GCM 256-bit encryption service.
final Provider<EncryptionService> encryptionServiceProvider =
    Provider<EncryptionService>((Ref ref) {
      final RandomSource random = ref.watch(randomSourceProvider);
      return AesGcmEncryptionService(randomSource: random);
    });

/// Provider for employee profile and biometric embedding repository.
final Provider<EmployeeRepository> employeeRepositoryProvider =
    Provider<EmployeeRepository>((Ref ref) {
      final AppDatabase db = ref.watch(appDatabaseProvider);
      final EncryptionService crypto = ref.watch(encryptionServiceProvider);
      final Clock clock = ref.watch(clockProvider);
      return DriftEmployeeRepository(
        db: db,
        encryptionService: crypto,
        clock: clock,
      );
    });

/// Provider for SFace face recognizer.
final Provider<FaceRecognizer> faceRecognizerProvider =
    Provider<FaceRecognizer>((Ref ref) {
      final MlWorker worker = ref.watch(mlWorkerProvider);
      final TierProfile profile =
          ref.watch(tierProfileProvider).value ??
          TierProfile.fromTier(DeviceTier.mid);
      return SFaceRecognizerImpl(mlWorker: worker, tierProfile: profile);
    });

/// Provider for 1:N face matcher.
final Provider<FaceMatcher> faceMatcherProvider = Provider<FaceMatcher>((
  Ref ref,
) {
  final EmployeeRepository repo = ref.watch(employeeRepositoryProvider);
  final AppConfig config = ref.watch(appConfigProvider);
  final Clock clock = ref.watch(clockProvider);
  return FaceMatcher(repository: repo, config: config, clock: clock);
});

/// Notifier for simple admin authentication guard.
class AdminAuthNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setAuthenticated(bool value) => state = value;
}

/// State provider for simple admin authentication guard.
final NotifierProvider<AdminAuthNotifier, bool> adminAuthProvider =
    NotifierProvider<AdminAuthNotifier, bool>(AdminAuthNotifier.new);

/// Provider for structured 5-pose employee enrollment orchestrator.
final Provider<EnrollmentSession> enrollmentSessionProvider =
    Provider<EnrollmentSession>((Ref ref) {
      final FaceRecognizer recognizer = ref.watch(faceRecognizerProvider);
      final FaceMatcher matcher = ref.watch(faceMatcherProvider);
      final AppConfig config = ref.watch(appConfigProvider);
      final Clock clock = ref.watch(clockProvider);
      return EnrollmentSession(
        recognizer: recognizer,
        matcher: matcher,
        config: config,
        clock: clock,
      );
    });