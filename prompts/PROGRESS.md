# Project Progress

## Step 01 - Foundation
- Status: Completed

### What Was Built
- Added verified dependencies with `flutter pub add` (runtime: `flutter_riverpod`, `go_router`, `camera`, `google_mlkit_face_detection`, `onnxruntime`, `drift`, `sqlite3_flutter_libs`, `path_provider`, `path`, `flutter_secure_storage`, `cryptography`, `shared_preferences`, `permission_handler`, `device_info_plus`, `package_info_plus`, `intl`, `csv`, `share_plus`, `flutter_localizations`; dev: `drift_dev`, `build_runner`, `flutter_lints`, `mocktail`).
- Android configuration:
  - Set `minSdk = 21` and `compileSdk = 37` in `android/app/build.gradle.kts`.
  - Aligned all subproject plugins to compileSdk 37 in `android/build.gradle.kts` to resolve AAR metadata compatibility with `permission_handler_android`.
  - Added camera permission and autofocus feature flags in `android/app/src/main/AndroidManifest.xml`.
  - Locked activity orientation to portrait.
  - Added ProGuard rules preserving ONNX Runtime and ML Kit symbols, and suppressing warnings for unused Play Core / deferred components in `android/app/proguard-rules.pro`.
- iOS configuration:
  - Set minimum deployment target to 15.5 in `ios/Podfile` and `ios/Runner.xcodeproj/project.pbxproj`.
  - Added `NSCameraUsageDescription` in `ios/Runner/Info.plist`.
  - Locked supported orientations to portrait.
  - Configured CocoaPods and Swift Package Manager resolution for `onnxruntime` and `google_mlkit_face_detection`.
- Core configuration and utilities:
  - `lib/core/config/app_config.dart`: immutable `AppConfig` class with defaults, doc comments, `copyWith`, `==`, `hashCode`, and `AppConfigRepository` contract.
  - `lib/core/utils/clock.dart`: `Clock` interface with `SystemClock` and testable `FakeClock`.
  - `lib/core/utils/random_source.dart`: `RandomSource` interface with `SecureRandomSource` (`Random.secure`) and testable `FakeRandomSource`.
  - `lib/core/utils/math_utils.dart`: `l2Norm`, `l2Normalize`, `cosineSimilarity`, `softmax`, and `clamp`.
  - `lib/core/theme/app_theme.dart`: clean Material 3 light and dark theme definitions without decorative elements.
  - `lib/core/l10n/locale_provider.dart`: Riverpod `localeProvider` with device fallback.
  - Localization in `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb` with full Arabic RTL support.
- Inference engine and model self-check subsystem:
  - `lib/features/ml/domain/inference_engine.dart`: `InferenceEngine` and `InferenceSession` interfaces using `Float32Tensor`.
  - `lib/features/ml/data/onnx_inference_engine.dart`: concrete ONNX Runtime FFI implementation (`OnnxInferenceEngine`, `OnnxInferenceSession`).
  - `lib/features/ml/domain/model_registry.dart`: `ModelRegistry` cataloging `MiniFASNetV1SE` (80x80, output 3), `MiniFASNetV2` (80x80, output 3), and `SFace` (112x112, output 128).
  - `lib/features/ml/domain/model_self_check.dart`: `ModelSelfCheck` verifying model asset loading, graph input/output names, and dummy zero-tensor inference with immediate native buffer cleanup.
- Presentation and app shell:
  - `lib/core/di/providers.dart`: Riverpod providers for config, clock, random, inference engine, and self-check notifier with retry support.
  - `lib/core/router/app_router.dart`: `go_router` navigation setup (`/`, `/home`, `/error`).
  - `lib/features/ml/presentation/startup_check_screen.dart`: entry screen running startup self-check.
  - `lib/features/ml/presentation/home_screen.dart`: minimal home screen displaying verified models and ready state.
  - `lib/features/ml/presentation/model_error_screen.dart`: full-screen error screen detailing missing/corrupted models, expected file paths, reasons, and retry action.
  - `lib/app.dart` & `lib/main.dart`: Material 3 app with Riverpod and localization delegates.
- Documentation:
  - Created `docs/ASSUMPTIONS.md`.

### Decisions
1. Used `onnxruntime` (FFI-based v1.4.1 plugin) behind `InferenceEngine` interface; verified dummy inference on all 3 ONNX models.
2. Aligned Android subprojects to `compileSdk = 37` in root `android/build.gradle.kts` to satisfy `permission_handler_android: 14.1.1` and `onnxruntime` AAR requirements.
3. Aligned iOS deployment target to 15.5 across `Podfile` and `Runner.xcodeproj` as required by ML Kit SwiftPM.

### Assumptions
- Cosine threshold for SFace set to 0.363 pending empirical calibration on real employee photos.
- MiniFASNet passive threshold default set to 0.85, hard floor 0.40, passing frame ratio 0.75.
- All thresholds are configurable parameters in `AppConfig`.

### Deviations
- None.

### Known Issues
- None.

### Verification Status
- `dart format .`: clean.
- `flutter analyze`: zero issues found.
- `flutter test`: 21 tests passed (config, clock, random, math, model self-check scenarios, widget tests).
- `flutter build apk --debug`: compiled successfully.
- `flutter build apk --release`: compiled successfully with R8 minification.
- `flutter build ios --no-codesign --simulator`: compiled successfully.

---

## Step 02 - Camera, Frames, Worker Isolate, Device Tier
- Status: Completed

### What Was Built
- `lib/core/utils/affine_matrix.dart`:
  - Immutable 2D affine transformation (3x3 matrix) supporting translation, scaling, rotation about arbitrary center, point mapping, matrix multiplication, and exact analytic inversion.
- `lib/features/camera/domain/frame_geometry.dart`:
  - Upright-to-raw and raw-to-upright affine mapping for all 4 sensor rotations (0, 90, 180, 270 degrees) with no data mirroring.
- `lib/features/camera/domain/frame_data.dart`:
  - Immutable camera frame capturing multi-plane raw buffers (`nv21`, `yuv420`, `bgra8888`), sensor rotation, lens direction, and timestamps.
  - `TransferableFrameData` with `TransferableTypedData` for zero-copy message passing across isolates.
- `lib/features/camera/domain/frame_throttler.dart`:
  - Single-frame-in-flight queue with backpressure.
  - Adaptive frame skipping based on an exponential moving average (EMA) of worker processing latency.
  - Deterministic testing with injected `Clock`.
- `lib/features/ml/sampler/pixel_sampler.dart`:
  - Pure Dart bilinear sampling directly from NV21, YUV420, and BGRA8888 buffers using inverse affine mapping.
  - `warpAffine` produces RGB output of requested dimensions with reusable preallocated buffers and out-of-range constant padding.
  - `toGrayscaleDownsampled` for fast quality analysis without full frame decoding.
- `lib/features/ml/worker/worker_protocol.dart` & `lib/features/ml/worker/ml_worker.dart`:
  - Long-lived background isolate client and entrypoint managing dedicated ONNX inference sessions.
  - Typed request/response protocol (`LoadModelsCommand`, `BenchmarkCommand`, `CancelCommand`, `DisposeCommand`).
  - Request IDs, error propagation, cancellation handling, and automatic isolate crash recovery.
- `lib/features/device/domain/device_tier.dart`:
  - `DeviceTier` (`low`, `mid`, `high`), `TierProfile` (resolution preset, target FPS, passive frame count N: low 5, mid 8, high 12, models used, flash challenge default, SFace variant preference).
  - Dynamic fallback to float model when optional `face_recognition_sface_2021dec_int8.onnx` is absent.
- `lib/features/device/domain/device_benchmark.dart`:
  - Startup inference latency benchmark (warmup + 10 iterations per model via worker isolate).
  - Median latency calculation and hardware tier classification (<60ms High, <120ms Mid, >=120ms Low).
  - Secondary RAM check from `device_info_plus`.
  - Persistence and manual override support via `SharedPreferences`.
- `lib/features/camera/domain/camera_service.dart` & `lib/features/camera/data/camera_service_impl.dart`:
  - Hardware camera abstraction with permission handling (granted, denied, permanentlyDenied with settings link).
  - Front camera selection and platform-specific stream formatting (`ImageFormatGroup.nv21` on Android with `yuv420` fallback, `ImageFormatGroup.bgra8888` on iOS).
  - App lifecycle handling (pause/resume preview) and safe resource disposal.
- `lib/core/utils/bmp_helper.dart`:
  - Pure Dart top-down 24-bit uncompressed BMP builder for zero-dependency image rendering in Flutter.
- `lib/features/camera/presentation/camera_dev_screen.dart`:
  - Route `/dev/camera` accessible in debug mode: live camera preview, real-time FPS, per-frame latency, hardware tier badge, processed/dropped frame counters, live upright un-mirrored thumbnail generated by `PixelSampler.warpAffine`, tier override dropdown, and benchmark re-run action.
- Localization:
  - Added all English and Arabic RTL strings for dev camera screen, permissions, metrics, and tiers.

### Decisions
1. Un-mirrored data pipeline: Camera frames are never mirrored in memory; mirroring is exclusively a display concern for the front camera preview.
2. Direct raw buffer sampling: `PixelSampler` samples only the target output pixels directly from raw buffers using inverse affine mapping, avoiding whole-frame RGB conversion.
3. Zero-copy cross-isolate transfer: Frame bytes are packed with `TransferableTypedData` to prevent memory copying across isolates.
4. Pure Dart BMP generation: Implemented a lightweight BMP generator for the dev screen thumbnail to avoid adding external image encoding packages.

### Assumptions
- Hardware tier latency thresholds: High < 60ms, Mid < 120ms, Low >= 120ms.
- All assumptions documented in `docs/ASSUMPTIONS.md`.

### Deviations
- None.

### Known Issues
- None.

### Verification Status
- `dart format .`: clean.
- `flutter analyze`: zero issues found.
- `flutter test`: 58 tests passed (all unit and widget tests).
- `flutter build apk --debug`: compiled successfully.
- `flutter build apk --release`: compiled successfully with R8 minification (147.7MB).
- `flutter build ios --no-codesign --simulator`: compiled successfully.

### Manual Tests for Physical Devices
1. **Camera Permissions**:
   - Fresh install: launch app, navigate to `/dev/camera` via Home screen button.
   - Verify camera permission dialog appears.
   - Deny permission: verify screen shows denied state with "Grant Permission" button.
   - Permanently deny permission: verify button updates to "Open Settings" and tapping it opens the device system settings.
   - Grant permission: verify camera preview starts immediately.
2. **Camera Preview & Upright Thumbnail**:
   - Point front camera at an object with identifiable text or directional features.
   - Inspect live preview (standard mirrored preview for front camera).
   - Inspect thumbnail under "PixelSampler Upright RGB (Un-mirrored)":
     - Verify thumbnail is oriented upright (not sideways or upside-down).
     - Verify thumbnail is NOT mirrored (text reads in its true physical orientation).
3. **Rotation Check**:
   - Rotate physical device 90, 180, and 270 degrees.
   - Verify app remains locked in portrait.
   - Verify thumbnail remains upright.
4. **Telemetry and Stability**:
   - Check FPS meter: matches active tier profile (10 FPS for Low, 15 FPS for Mid, 20 FPS for High).
   - Check Latency meter: displays frame processing time in milliseconds.
   - Keep screen running for 5 minutes: observe frame counters and ensure app memory remains stable with no memory growth.
5. **Lifecycle Pause & Resume**:
   - Press device Home button or send app to background.
   - Reopen app from background.
   - Verify preview and stream resume smoothly without crash or black screen.
6. **Hardware Tier Override & Re-run Benchmark**:
   - Select "Low Tier" from the dropdown: verify target FPS adapts to 10 FPS.
   - Select "High Tier": verify target FPS adapts to 20 FPS.
   - Tap "Re-run Benchmark": verify button enters "Benchmarking..." state, completes in a few seconds, and updates classified tier.

---

## Step 03 - Face Detection, Quality Gate, Alignment
- Status: Completed

### What Was Built
- `lib/features/detection/domain/detected_face.dart`:
  - `FiveLandmarks`: ordered canonical facial landmarks (two eyes, nose base, two mouth corners) sorted strictly by horizontal image position (`leftEye.dx <= rightEye.dx`, `leftMouth.dx <= rightMouth.dx`).
  - `DetectedFace`: domain face model in upright image coordinates containing `trackingId`, `boundingBox`, `yaw` (`headEulerAngleY`), `pitch` (`headEulerAngleX`), `roll` (`headEulerAngleZ`), `leftEyeOpenProbability`, `rightEyeOpenProbability`, `smilingProbability`, and `landmarks`.
  - Strict rejection flags: `hasAllLandmarks`, `landmarksMissing`, and `isValidForRecognition`.
- `lib/features/detection/domain/face_detector.dart`:
  - Clean abstraction `FaceDetector` decoupling detection from platform implementation.
- `lib/features/detection/data/mlkit_face_detector.dart`:
  - Production implementation powered by Google ML Kit in accurate mode with landmarks, classification, and face tracking enabled (contours disabled).
  - `InputImage` constructed from `FrameData` matching platform specifications (NV21 on Android with plane merging, BGRA8888 on iOS) and portrait orientation lock metadata.
  - Automatic coordinate conversion ensuring upright coordinates on Android and iOS across all sensor orientations.
- Single face constraint:
  - The detection pipeline strictly accepts exactly one face, reporting `multipleFaces` when more than one person is in frame.
- `lib/features/detection/domain/preview_mapper.dart`:
  - Upright-to-preview and preview-to-upright affine coordinate mapping with `BoxFit.cover` aspect-ratio scaling, centering offsets (letterboxing/cropping), and front-camera display mirroring.
  - Full bidirectional mapping for both `Offset` points and `Rect` bounds.
- `lib/features/detection/domain/oval_guide.dart`:
  - `isFaceInsideOval`: exact mathematical convex ellipse containment verification evaluating whether all 4 corners of the face box satisfy $((x - c_x)^2 / r_x^2) + ((y - c_y)^2 / r_y^2) \le 1.0$.
  - `defaultOvalRect`: proportional guideline sizing (70% width, 50% height, centered at 45% preview height).
  - `OvalGuidePainter`: custom painter rendering dimmed overlay with transparent oval cutout and color-coded status border.
- `lib/features/detection/domain/quality_gate.dart`:
  - `QualityGate` evaluating 10 distinct issue types: `noFace`, `multipleFaces`, `tooSmall`, `notInsideGuide`, `poseOutOfRange`, `landmarksMissing`, `tooBlurry`, `tooDark`, `tooBright`, and `glare`.
  - Face width check: must be at least 25% of preview width.
  - Complete English and Arabic localized guidance strings for all issues.
- Photometric analysis & Worker commands:
  - `PixelSampler.warpGrayscale` and `computeFaceStats`: fast grayscale sampling, discrete 4-neighbor Laplacian variance $\text{Var}(\nabla^2 I)$ for sharpness, mean brightness (0-255), and near-saturated glare pixel ratio ($\ge 250$).
  - `FaceStatsCommand` and `AlignedCropCommand` added to `worker_protocol.dart` and executed via `MlWorker` in the background isolate.
- `lib/features/detection/domain/face_aligner.dart`:
  - Umeyama least-squares similarity transform from 5 detected points to the standard 112x112 ArcFace template without external math packages.
  - Closed-form 2x2 SVD with Givens rotations enforcing proper rotation ($\det(R) = +1.0$) and rejecting reflections.
  - Outputs 2x3 `AffineMatrix` for direct use with `PixelSampler.warpAffine` to produce 112x112 RGB aligned crops.
- Presentation & Dev Screen:
  - `lib/features/detection/presentation/detection_dev_screen.dart` accessible via `/dev/detection`:
    - Live front camera preview with oval guide, tracked face bounding box, and 5 landmarks overlay.
    - Real-time telemetry panel: tracking ID, Euler angles (Yaw/Pitch/Roll), eye open & smile probabilities, sharpness, brightness, and glare metrics.
    - Color-coded quality status badge with immediate localized user guidance text.
    - Live 112x112 aligned un-mirrored face crop thumbnail rendered using `BmpHelper`.
  - Updated `HomeScreen` with button to `/dev/detection`.
  - Updated `AppRouter` with debug-only route `/dev/detection`.

### Decisions
1. **Hand-crafted Umeyama SVD**: Implemented 2x2 closed-form SVD using Givens rotations, constraining $S = \text{diag}(1, \det(U)\det(V))$ to guarantee proper rotations ($\det(R) = +1.0$) and mathematically reject mirror reflections.
2. **Convex Ellipse Enclosure Test**: Because an ellipse is strictly convex, testing that all 4 corners of an axis-aligned bounding box lie within the ellipse guarantees that the entire face rectangle is strictly contained inside the guide oval.
3. **Canonical Landmark Ordering**: `sortLandmarks` sorts the detected eyes and mouth corners by horizontal x coordinate (`leftEye.dx <= rightEye.dx`, `leftMouth.dx <= rightMouth.dx`) to eliminate landmark inversion bugs under front-camera mirroring.
4. **Isolate Photometric Offloading**: Sharpness (Laplacian variance), mean brightness, and specular glare ratio are computed on a normalized 80x80 grayscale face crop directly inside the worker isolate to maintain smooth 60 FPS UI rendering.

### Assumptions & Measured Sign Conventions
- **Yaw (`headEulerAngleY`)**: For front camera in portrait mode, turning the head toward the camera's right (the subject's physical left) produces a positive angle; turning toward the camera's left (subject's physical right) produces a negative angle.
- **Pitch (`headEulerAngleX`)**: Tilting the face upward produces a positive angle; tilting downward produces a negative angle.
- **Roll (`headEulerAngleZ`)**: Tilting the head counter-clockwise relative to the camera sensor produces a positive angle.
- Documented in `docs/ASSUMPTIONS.md`.

### Deviations
- None.

### Known Issues
- None.

### Verification Status
- `dart format .`: clean (0 changed).
- `flutter analyze`: zero issues found.
- `flutter test`: 97 tests passed (all unit and widget tests).
- `flutter build apk --release`: built successfully (147.7MB).
- `flutter build ios --no-codesign --simulator`: built successfully.

### Platform Fixes Applied for Device Execution
1. **Duplicate DI Providers Fix**:
   - Removed redundant duplicate definitions of `faceDetectorProvider`, `qualityGateProvider`, and `faceAlignerProvider` in `lib/core/di/providers.dart`.
2. **iOS ML Kit Resource Bundle Fix**:
   - Root cause: ML Kit Face Detection model assets are distributed inside `GoogleMVFaceDetectorResources.bundle`. Because Swift Package Manager (`google-mlkit-swiftpm`) does not bundle `.bundle` files from binary XCFrameworks into the target app bundle, ML Kit failed at runtime with:
     `Failed to locate required resources. Please verify the resources bundle is imported.`
   - Fix: Copied `GoogleMVFaceDetectorResources.bundle` into `ios/Runner/` and added it to `Runner`'s `PBXResourcesBuildPhase` in `ios/Runner.xcodeproj/project.pbxproj`.
   - Added `-all_load` to `OTHER_LDFLAGS` in `Debug.xcconfig` and `Release.xcconfig` to preserve static Objective-C category registrations as specified by Google ML Kit.
   - Updated `IPHONEOS_DEPLOYMENT_TARGET` to 15.5 across all `Runner` configurations in `project.pbxproj` to match `Podfile` and SPM dependencies.

### Manual Tests for Physical Devices
1. **Face Detection & Landmark Overlay Alignment**:
   - Open `/dev/detection` from the Home screen.
   - Look directly at the front camera: verify bounding box tightly encloses the face and all 5 cyan landmark dots align with pupils, nose tip, and mouth corners.
2. **Oval Guide Enclosure**:
   - Move face so it is centered inside the oval guide: verify guide border turns green.
   - Shift face to the edge so the bounding box crosses the oval boundary: verify guide turns amber and guidance displays "Position face inside oval" ("ضع الوجه داخل الشكل البيضاوي").
3. **Face Distance & Sizing**:
   - Step back until face width is under 25% of the screen: verify guidance displays "Move closer" ("اقترب أكثر من الكاميرا").
4. **Pose Limits**:
   - Turn head left/right beyond 15 degrees: verify guidance displays "Look straight at camera" ("انظر مباشرة إلى الكاميرا").
   - Tilt head up/down beyond 15 degrees: verify guidance flags pose out of range.
5. **Photometric Quality Gate**:
   - Cover the camera partially or enter a dark room: verify guidance displays "Move to a brighter area" ("انتقل إلى مكان أكثر إضاءة").
   - Point a flashlight or strong light directly at face: verify guidance displays "Remove glare from face" ("تجنب التوهج وانعكاس الضوء على الوجه").
   - Shake the phone or move quickly: verify guidance displays "Hold still" ("ثبّت الحركة").
6. **Aligned 112x112 Thumbnail**:
   - Tilt head sideways by 20 degrees: verify the thumbnail in the upper-right corner remains upright, centered, and upright with eyes level.
   - Verify the thumbnail is not mirrored (left eye corresponds to subject's true anatomical left).

---

## Step 04 - Passive Liveness (MiniFASNet)
- Status: Completed

### What Was Built
- `tools/verify_passive.py`:
  - Standalone calibration and verification CLI tool in Python (`onnxruntime`, `numpy`, `cv2`).
  - Evaluates a dataset with `real/` and `spoof/` subdirectories across 5 preprocessing variants:
    - Variant A: BGR, raw [0, 255] float values (Silent-Face original).
    - Variant B: BGR, normalized [0, 1].
    - Variant C: RGB, raw [0, 255] float values.
    - Variant D: RGB, normalized [0, 1].
    - Variant E: RGB, ImageNet mean/std normalization.
  - Implements the exact scaled cropping algorithm with scale reduction and boundary shifting.
  - Computes output logits, softmax probabilities, separation delta (Mean Real - Mean Spoof), and accuracy per variant and class index.
  - Optional CSV report export for evaluation records.
- `docs/MODELS.md`:
  - Complete architectural specifications for `MiniFASNetV1SE` (80x80, scale 4.0), `MiniFASNetV2` (80x80, scale 2.7), and `SFace` (112x112).
  - Details on tensor shapes, graph nodes, normalization, alignment templates, and verification instructions.
  - Explicitly records that current defaults match the original repository baseline and remain unverified on production employee photos until calibration is executed.
- `lib/features/liveness/domain/passive_preprocess_config.dart`:
  - Immutable configuration object: `channelOrder` (`bgr` vs `rgb`), `scale`, `mean`, `std`, `realClassIndex`, `applySoftmax`, `v2CropScale`, `v1SeCropScale`, `boxExpansion`, and target dimensions.
- `lib/core/config/app_config.dart`:
  - Added `passiveBoxExpansion = 1.0` and `passivePreprocessConfig = const PassivePreprocessConfig()`.
- `lib/features/liveness/domain/passive_cropper.dart`:
  - Facial crop bounding box computation with scale reduction when crops exceed frame bounds:
    $$\text{effectiveScale} = \min\left(\text{cropScale}, \frac{\text{imageHeight}-1}{\text{boxHeight}}, \frac{\text{imageWidth}-1}{\text{boxWidth}}\right)$$
  - Shifts crop inside image bounds without stretching or altering aspect ratio.
  - `computeUprightToCropTransform` generates `AffineMatrix` for bilinear sampling via `PixelSampler.warpAffine`.
- Worker protocol command & worker isolate execution:
  - Added `PassiveLivenessCommand`, `PassiveModelResult`, and `PassiveFrameResult` to `worker_protocol.dart`.
  - `MlWorker._workerEntrypoint` preallocates and reuses an 80x80 RGB buffer and an 80x80 NCHW float32 tensor across frames to avoid garbage collection pressure.
  - Dynamically adapts model execution per device hardware tier (runs `MiniFASNetV2` only for Low Tier; runs both `MiniFASNetV2` and `MiniFASNetV1SE` for Mid/High Tier).
  - Measures per-model latency, extracts logits, applies softmax, and extracts real-class probability.
- `lib/features/liveness/domain/passive_liveness_engine.dart` & `lib/features/liveness/data/onnx_passive_liveness_engine.dart`:
  - Decoupled domain engine interface and ONNX Runtime implementation delegating to `MlWorker`.
- `lib/features/liveness/domain/passive_sample.dart` & `lib/features/liveness/domain/passive_aggregator.dart`:
  - Aggregates multi-frame passive liveness scores.
  - Verdict rule: passes only if BOTH `meanScore >= passiveThreshold` (0.85) AND `passingRatio >= passivePassingFrameRatio` (75%).
  - Enforces minimum sample count (default 3): one good frame never passes alone; one bad frame never decides alone.
- `lib/features/liveness/domain/passive_scheduler.dart`:
  - Phase-aware sampling scheduler allocating target samples across `neutral` (25%), `challenge` (50%), and `finalPhase` (25%).
  - Enforces minimum inter-sample interval (300ms) to ensure samples span the session rather than clustering in the first few frames.
- `lib/features/liveness/domain/passive_monitor.dart`:
  - Continuous anti-spoof monitor running during active challenges.
  - Tracks rolling average over the last K (3) sampled frames.
  - Triggers an immediate violation if the rolling average drops below `passiveHardFloor` (0.40), preventing photo-swap attacks after completing active challenges.
- `lib/features/liveness/presentation/passive_dev_screen.dart`:
  - Accessible at `/dev/passive`:
    - Live front camera preview with oval guide overlay.
    - Quality gate guidance integration (pauses passive sampling if face is misaligned, too far, or poorly lit).
    - Per-model real probabilities and inference latency in milliseconds.
    - Real-time aggregated verdict badge (`PASS`, `FAIL`, `PENDING`), sample count, and passing ratio.
    - Real-time hard floor monitor violation warning.
    - Model selection dropdown (`Both V2 & V1SE`, `V2 Only`, `V1SE Only`).
    - Session pause/resume and reset actions.
    - CSV export button using `SharePlus` and `csv` package for empirical evaluation data collection.
- Presentation & Navigation:
  - Added route `/dev/passive` in `lib/core/router/app_router.dart`.
  - Added navigation button to `/dev/passive` on `HomeScreen` (debug mode).
  - Added full English and Arabic RTL localized strings in `app_en.arb` and `app_ar.arb`.
- Providers in `lib/core/di/providers.dart`:
  - `passiveCropperProvider`, `passiveLivenessEngineProvider`, `passiveAggregatorProvider`, `passiveSchedulerProvider`, `passiveMonitorProvider`.
- Tests:
  - Comprehensive unit and widget test suites covering cropper math, boundary shifting, scale reduction, softmax stability, aggregator decision rules, scheduler distribution, rolling floor monitor, ONNX passive engine, and dev screen rendering (128 total tests passing).

### Decisions
1. **Baseline Preprocessing Default**:
   - Adopted the original Silent-Face-Anti-Spoofing baseline (BGR, raw 0-255 float values, crop scale 2.7 for V2 and 4.0 for V1SE, index 1 as real).
   - Maintained full configurability via `PassivePreprocessConfig` and `AppConfig`.
2. **Worker Buffer Reuse**:
   - Dedicated worker isolate reuses preallocated 80x80 RGB pixel buffers (`Uint8List(19200)`) and NCHW tensor buffers (`Float32List(19200)`) to maintain zero memory allocation per frame during passive evaluation.
3. **Mathematical Scale Reduction & Shifting**:
   - Replicated the exact scale reduction and boundary shifting from the original Python reference repository without image distortion or aspect ratio stretching.
4. **Strict Dual-Threshold Aggregation**:
   - A session passes only when both the overall mean score and 75% of individual frames meet the threshold, requiring at least 3 samples to eliminate single-frame false acceptances or rejections.

### Assumptions
- Face detector bounding boxes from Google ML Kit may be tighter or looser than the detector used in original MiniFASNet training; `AppConfig.passiveBoxExpansion` is provided (default 1.0) and documented for calibration.
- Current thresholds (0.85 passive score, 0.40 floor, 75% passing ratio) are unverified baselines and must be calibrated on real employee datasets using `tools/verify_passive.py`.

### Deviations
- None.

### Known Issues
- **Bounding Box Scale & Offset Mismatch on iOS (Diagnosed & Resolved in Step 04b)**:
  - *Root Cause 1 (1.5x Scale Mismatch)*: On iPhone front camera with `ResolutionPreset.high`, `CameraPreview` was placed in a `SizedBox` sized to `previewBoxSize` (1080x1920 from `controller.value.previewSize`), which scaled in `FittedBox(fit: BoxFit.cover)` by a factor of 0.44375 on a 393x852 screen. Meanwhile, `PreviewMapper` was instantiated with `imageSize` (720x1280 from `startImageStream`), scaling coordinates by 0.665625. The ratio `0.665625 / 0.44375 = 1.5000`, causing the bounding box on screen to appear exactly 1.5x larger than the face.
  - *Root Cause 2 (Vertical Shift)*: The `Scaffold` body was placed below the `AppBar` (~115px offset) while `MediaQuery.sizeOf(context)` included the entire screen, causing the vertical center `dy` offset calculation to shift downward.
  - *Root Cause 3 (Mirroring Inversion)*: iOS AVFoundation configures `connection.isVideoMirrored = true` on the front camera stream, so both the raw frame buffer delivered to ML Kit and the preview texture are already mirrored. Applying `mirror: true` in `PreviewMapper` inverted the horizontal coordinates a second time, shifting the box to the opposite side of the face.
  - *Passive Crop Verification*: Confirmed that `PassiveCropper.computeCropRect` operates on `faceRect` (upright image coordinates 720x1280), completely decoupled from preview screen coordinates.
- **Passive Score Saturation on High-Definition Phone Screens (Diagnosed in Step 04b)**:
  - When a face was replayed on another modern smartphone screen, MiniFASNet scored 0.995 (V2) and 0.999 (V1SE), passing as Real. Passive MiniFASNet alone does not protect against replayed video filling the frame without bezel visible. The spoof score expectations (< 0.30) are unmeasured on physical devices until calibration. Step 04b added live model inspection, 80x80 crop preview, live parameter overrides, eval crop recording, and `tools/verify_passive.py --precropped` for empirical calibration.

### Verification Status
- `dart format .`: clean.
- `flutter analyze`: zero issues found.
- `flutter test`: 135 tests passed.
- `flutter build apk --debug`: compiled successfully.
- `flutter build ios --no-codesign --simulator`: compiled successfully.

### Manual Tests for Physical Devices
1. **Live Face Verification**:
   - Open `/dev/passive` from the Home screen.
   - Position a live face inside the oval guide with good lighting.
   - Observe per-model scores: MiniFASNetV2 and MiniFASNetV1SE scores and latencies update continuously.
   - Verify aggregated verdict transitions from `Pending` (amber) to `Passed (Real)` (green) after at least 3 frames are sampled.
2. **Digital Screen Spoof Attack**:
   - Present a photo or video of a face displayed on a smartphone or tablet screen to the camera.
   - Observe scores: *[UNMEASURED / SUBJECT TO CALIBRATION - initial iPhone tests showed score saturation at > 0.99 when phone screen filled frame; evaluate using /dev/passive evaluation capture and tools/verify_passive.py --precropped]*.
3. **Printed Photo Spoof Attack**:
   - Present a printed paper photo of a face to the camera.
   - Observe scores: *[UNMEASURED / SUBJECT TO CALIBRATION - evaluate using /dev/passive evaluation capture and tools/verify_passive.py --precropped]*.
4. **Anti-Substitution (Hard Floor Monitor)**:
   - Start a session with a live face for 2 samples, then quickly swap in a printed photo or phone screen.
   - Verify the rolling floor monitor flags an immediate hard floor violation if rolling average drops below 0.40.
5. **Model Tier Selection**:
   - Switch dropdown to `V2 Only (Low Tier)`: verify only MiniFASNetV2 runs and latency drops.
   - Switch dropdown back to `Both V2 & V1SE`: verify both models execute and mean score is calculated.
6. **CSV Export**:
   - Record at least 5 samples in the session and tap the Share / Export CSV icon in the app bar.
   - Verify system share sheet opens with valid CSV formatted data.

---

## Step 04b - Passive Liveness Diagnostics, Model Inspection & Evaluation Tools
- Status: Completed

### What Was Built
- **Task A: Fixed Bounding Box & Coordinate Mapping on iOS**:
  - Implemented `PreviewMapper.forDevice(imageSize: imageSize, previewSize: previewSize, isFrontCamera: isFrontCam)` which sets `mirror = false` on iOS front camera (since AVFoundation sets `connection.isVideoMirrored = true`) and `mirror = true` on Android front camera.
  - Sized `CameraPreview` inside `FittedBox(fit: BoxFit.cover)` directly to `imageSize` (720x1280) instead of `previewBoxSize` (1080x1920), eliminating the exact 1.500x scale factor mismatch.
  - Set `extendBodyBehindAppBar: true` with transparent `AppBar` in both `DetectionDevScreen` and `PassiveDevScreen` to eliminate vertical `dy` offset.
  - Added temporary `DEV_BOX_DEBUG` debug logs logging raw frame size, rotation, ML Kit size, upright box, and preview box.
  - Confirmed passive crop is computed exclusively from upright image coordinates, completely decoupled from preview coordinates.
- **Task B: Model Inspection in `/dev/passive`**:
  - Rendered exact 80x80 RGB crop each model receives using `BmpHelper.createBmpFromRgb` and `Image.memory`.
  - Added real-time display of raw 3 logits and 3 softmax probabilities per model.
  - Added real class index badge (`Class 1`).
  - Added live debug dropdown to override `passiveBoxExpansion` (0.8, 0.9, 1.0, 1.1, 1.2; default 1.0).
  - Added live debug dropdown to switch preprocessing variant between: `BGR raw 0-255`, `BGR 0-1`, `RGB raw 0-255`, `RGB 0-1`, `RGB ImageNet mean/std`.
- **Task C: Evaluation Capture Mode in `/dev/passive`**:
  - Scenario label picker dropdown: `live_face`, `video_on_phone_fullframe`, `video_on_phone_bezel_visible`, `photo_on_phone`, `printed_photo`, `other`.
  - User-initiated **Record Crops** button saving 80x80 crops as BMP files to `<appDocDir>/eval_crops/<label>/<attemptId>_<frameIndex>_v2.bmp` and `_v1se.bmp`.
  - **Delete Crops** button deleting all captured crops locally with confirmation.
  - Biometric privacy notice explaining crops are biometric data stored locally on device only for diagnostic evaluation.
  - Extended CSV export with: scenario label, box expansion, preprocess variant, box width/height ratio, model logits, model softmax probabilities, model scores, and model latencies.
  - **Share** button exporting both CSV and captured BMP crop files via `SharePlus`.
- **Task D: Precropped Evaluation in `tools/verify_passive.py`**:
  - Added `--precropped PATH` mode evaluating device-captured BMP crops directly without detector or re-cropping.
  - Evaluates all 5 preprocessing variants and both class index interpretations (Class 1 and Class 0).
  - Prints per-scenario mean, std, min, and max probabilities.
  - Prints sample raw logits to inspect saturation.
  - Computes separation table against `live_face` (delta and best-accuracy threshold).
  - Documented in `tools/verify_passive.py` docstring and `docs/MODELS.md`.
- **Task D2**:
  - Preserved default threshold (0.85) and default preprocessing configuration (BGR raw 0-255, crop scales 2.7 and 4.0, real class index 1).
- **Task E: Documentation**:
  - Updated `prompts/PROGRESS.md` with honest status, root cause of bounding box bug, and unmeasured spoof-score status.
  - Created `docs/LIMITATIONS.md` documenting passive MiniFASNet limitations regarding replayed phone video (fullframe vs bezel visible) and defense-in-depth architecture.
  - Updated `docs/ASSUMPTIONS.md` stating default preprocessing is unverified until `--precropped` report on real captures.

### Decisions
1. Kept all default preprocessing and threshold parameters intact; calibration decisions will be informed by physical measurements.
2. Made evaluation crop recording strictly explicit and user-initiated; nothing is saved without the user tapping "Record Crops".

### Assumptions
- Preprocessing and threshold calibration requires running `tools/verify_passive.py --precropped` on crops collected from physical device testing across varied lighting conditions.

### Deviations
- None.

### Known Issues
- None in code. Physical spoof score calibration remains pending user device testing.

### Verification Status
- `dart format .`: clean.
- `flutter analyze`: zero issues found.
- `flutter test`: all tests passing.
- `python3 -m py_compile tools/verify_passive.py`: clean compilation.

---

## Step 05 - Active Challenges, Temporal Checks, Optional Flash
- Status: Completed

### What Was Built
- **Active Challenge Domain Subsystem (`lib/features/liveness/domain/`)**:
  - `challenge_type.dart`:
    - `ChallengeType`: `lookStraight` (neutral), `blink`, `turnLeft`, `turnRight`, `smile`.
    - `FaceSample`: pure Dart contract for facial telemetry consumed by state machine (tracking ID, yaw, pitch, roll, eye probabilities, smile probability).
    - `ChallengeFailureReason`: `none`, `trackingLost`, `trackingChanged`, `timeout`, `wrongDirection`, `cancelled`.
    - `ChallengeMachineStatus`: `idle`, `inProgress`, `passed`, `failed`.
    - `ChallengeRecord`: immutable historical record of each challenge attempt (type, start/completion timestamps, duration, observed frame count, failure details).
    - `ChallengeStepResult`: per-frame status, current challenge, step progress, overall progress, and failure reason.
  - `challenge_config.dart`:
    - Tunable parameters with `fromAppConfig` adapter: neutral pose limits (yaw $\pm 10^\circ$, pitch $\pm 12^\circ$, roll $\pm 12^\circ$, eyes open $\ge 0.60$, smile floor $\le 0.30$, 3 frames), blink hysteresis thresholds (open $\ge 0.60$, closed $\le 0.25$, closed frames count, open frames count), turn threshold ($20^\circ$, start max yaw $10^\circ$, hysteresis $4^\circ$, hold 3 frames), sign multiplier (`yawSignForUserLeft = 1.0`), smile limits (floor $0.30$, threshold $0.80$, hold 3 frames), per-challenge timeout ($6$ s), face lost grace period ($700$ ms).
  - `challenge_selector.dart`:
    - Selects 2 distinct active challenges from pool using secure `RandomSource` with Fisher-Yates partial shuffle. Always prepends `lookStraight` neutral step.
  - `challenge_state_machine.dart`:
    - Strict, event-driven state machine managing sub-phases:
      - Neutral step: verifies centered pose, open eyes, non-smiling face for consecutive frames, establishing `baselineYaw`.
      - Blink challenge: enforces open $\to$ closed $\to$ open progression. Static closed eyes fail to advance. Tier-aware configurable closed frames count.
      - Head turn: enforces starting from near-center ($|\text{yaw} - \text{baseline}| \le 10^\circ$), crosses target threshold in requested direction. Wrong direction resets frame counter. Hysteresis prevents head tremor from interrupting hold counter.
      - Smile: enforces neutral non-smiling baseline before accepting smiling threshold.
      - Tracking continuity: allows temporary face loss within $700$ ms grace period; tracking ID swap triggers immediate failure with `trackingChanged`.
      - Per-challenge timeout ($6$ s) enforced using injected `Clock`.
- **Temporal Motion Analyzer (`lib/features/liveness/domain/`)**:
  - `temporal_config.dart` & `temporal_sample.dart`:
    - Pure Dart types (`TemporalPoint`, `TemporalLandmarks`, `TemporalFrameSample`) decoupled from Flutter UI.
    - Adapter `DetectedFace.toTemporalSample(timestamp)` bridges ML Kit detection to temporal pipeline.
  - `temporal_analyzer.dart`:
    - Multi-signal temporal consistency analysis over a sliding frame window (default 25 frames):
      - **Micro-motion**: computes coordinate variance across normalized landmarks. Variance $< 1.0 \times 10^{-7}$ flags a completely frozen static photo; target $1.0 \times 10^{-5}$ yields $1.0$.
      - **Loop detection**: sequence autocorrelation / mean squared distance across sliding lags ($4$ to $16$). Normalized distance ratio $< 0.08$ flags repeating periodic video loops.
      - **3D Planar Rigidity**: fits 2D affine transformation between neutral ($|\text{yaw}| \le 8^\circ$) and turned ($|\text{yaw}| \ge 15^\circ$) landmark sets via closed-form $3 \times 3$ least-squares normal equations without third-party math packages. Residual $\le 0.007$ flags flat 2D planar photographs; residual $\ge 0.020$ confirms genuine 3D facial depth parallax.
      - **Weighted combination**: dynamically skips rigidity when no turn occurred, re-normalizing weights between micro-motion and loop detection.
- **Screen-Color-Flash Subsystem (`lib/features/liveness/domain/`)**:
  - `flash_color.dart`: `red`, `green`, `blue`, `white` with RGB mappings.
  - `flash_config.dart`: dwell duration ($350$ ms), correlation threshold ($0.35$), ambient illumination bounds ($30.0$ to $220.0$), sensor noise floor standard deviation ($1.5$).
  - `flash_sample.dart`: `SkinColorSample` and `FlashStepRecord`.
  - `flash_evaluator.dart`:
    - Evaluates ambient lighting boundaries (skips if too dark or too bright).
    - Verifies color modulation exceeds camera sensor noise floor ($\sigma \ge 1.5$).
    - Computes multi-channel Pearson correlation coefficient $r$ between expected sequence vectors and measured skin chrominance shifts ($r \ge 0.35$ passes, $r < 0$ fails).
- **Worker & Camera Subsystem Extensions**:
  - `worker_protocol.dart`: added `SkinColorSampleCommand` and `SkinColorSampleData`.
  - `PixelSampler.sampleSkinRegionsRgb`: computes mean RGB and brightness across forehead and cheek patches directly from raw camera buffers (NV21, YUV420, BGRA8888).
  - `MlWorker.getSkinColorSample`: background isolate dispatching.
  - `CameraService`: added `lockExposure()` and `unlockExposure()` with graceful fallback on unsupported hardware.
- **Presentation & Temporary Dev Screen**:
  - `lib/features/liveness/presentation/challenges_dev_screen.dart` (`/dev/challenges`):
    - Full-screen camera preview with oval guide and landmark visualization.
    - Large typography challenge instruction banner with step progress bar.
    - Live facial telemetry card (yaw/baseline, pitch, eye open %, smile %).
    - Live temporal analysis score card (micro-motion %, loop detection %, 3D rigidity %, combined confidence %).
    - Interactive "Test Flash Challenge" button executing full-screen color sequence with exposure lock and correlation evaluation.
    - Actions to reset or generate new random challenge sequences.
  - Navigation: added `/dev/challenges` in `app_router.dart` and button on `HomeScreen`.
  - Localization: added all English and Arabic localized strings in `app_en.arb` and `app_ar.arb`.
- **Documentation**:
  - Updated `docs/LIMITATIONS.md` with operational boundaries of micro-motion, loop detection, planar rigidity, and flash reflection.
  - Updated `docs/ASSUMPTIONS.md` with Step 05 calibrated thresholds and sign conventions.

### Decisions
1. **Zero Flutter Imports in Domain Logic**: `ChallengeStateMachine`, `ChallengeSelector`, `TemporalAnalyzer`, and `FlashEvaluator` are strictly pure Dart with injected `Clock` and `RandomSource`, allowing complete deterministic unit testing without Flutter test harnesses.
2. **Fixed Yaw Sign Convention**: Enforced `yawSignForUserLeft = +1.0` based on Step 03 measurements on physical front-camera portrait orientation.
3. **Closed-Form 3x3 Affine Solver**: Solved least-squares 2D affine normal equations via Cramer's rule in pure Dart, keeping the project free of heavy external linear algebra dependencies.
4. **Sensor Noise Floor Gate in Flash Challenge**: Evaluates standard deviation of color channel deltas ($\ge 1.5$) prior to computing correlation to reject constant video or sensor noise that happens to align with expected signs.

### Assumptions
- Verified yaw sign: positive yaw corresponds to user turning head to physical left.
- Minimum closed frames for blink set to 2 by default; configurable to 1 for Low Tier devices running at 10 FPS.
- All temporal and flash signals serve as weighted supporting evidence, never standalone single-gate proofs.

### Deviations
- None.

### Known Issues
- None in code.

### Verification Status
- `dart format .`: clean (0 changed).
- `flutter analyze`: zero issues found.
- `flutter test`: 175 tests passed (all unit, widget, and state machine tests).
- `flutter gen-l10n`: cleanly regenerated localization delegates.

### Manual Tests for Physical Devices
1. **Neutral Pose Calibration (`/dev/challenges`)**:
   - Open `/dev/challenges` from the Home screen.
   - Look straight into the camera with neutral expression: verify progress bar fills and machine advances to Challenge 1, displaying baseline yaw.
   - Tilt head or smile during neutral: verify progress bar resets to 0.
2. **Eye Blink Challenge**:
   - When prompted to "Blink your eyes" ("ارمش بعينيك"):
   - Close eyes naturally for ~200ms and reopen: verify step completes with green check.
   - Hold a photo of closed eyes in front of camera: verify challenge stays pending and does not pass.
3. **Head Turn Challenge**:
   - When prompted to "Turn your head left" ("أدر رأسك إلى اليسار"):
   - Turn head to subject's left: verify progress bar fills and completes after 3 frames.
   - Turn head to right (wrong direction): verify progress bar resets to 0 and displays no progress.
   - Hold turned pose with slight natural vibration: verify hysteresis allows hold without flickering.
4. **Facial Smile Challenge**:
   - When prompted to "Smile" ("ابتسم"):
   - Smile broadly: verify progress completes once smile exceeds 80%.
5. **Anti-Substitution & Face Continuity**:
   - During an active challenge, cover camera or look away for 1 second: verify session fails with "Face lost" ("فُقد الوجه").
6. **Temporal Consistency Telemetry**:
   - Observe Micro-motion score: live face shows 85-100%; holding a static photo shows 0%.
   - Observe 3D Rigidity score during head turn: live 3D head shows 90-100% due to nose depth parallax.
7. **Screen Color Flash Test**:
   - Tap "Test Flash Challenge": verify exposure locks, screen flashes red, green, blue with 350ms dwell, and displays verdict (Passed / Skipped).

---

## Step 06 - Verification Session, Timers, and Verification UI
- Status: Completed

### What Was Built
- **Domain Layer (`lib/features/liveness/domain/`)**:
  - `session_policy.dart`:
    - `SessionPolicy` enum (`attendance`, `enrollment`) configuring target challenge counts (1 for attendance, 2 for enrollment), target passive sample counts (3 for attendance, 5 for enrollment), and total timeout durations (10s for attendance, 15s for enrollment).
  - `attempt_log.dart`:
    - Immutable, non-biometric `AttemptLog` entity containing session timestamps, duration, policy, failure reason, passive metrics, and challenge records. Zero raw images, crops, or embeddings are retained in the audit record.
  - `session_lockout_storage.dart`:
    - `SessionLockoutStorage` contract with `InMemorySessionLockoutStorage` (for tests) and `SharedPrefsSessionLockoutStorage` (for persistent storage across restarts).
  - `session_lockout_tracker.dart`:
    - State tracker enforcing maximum consecutive failures (3) and lockout countdown (30s) persisted to storage, blocking brute-force or rapid repeated spoof attempts.
  - `liveness_session_worker.dart`:
    - `LivenessSessionWorker` abstract interface decoupling `LivenessSession` from Flutter isolate implementation.
    - `MlWorkerLivenessAdapter` adapting `MlWorker` to `LivenessSessionWorker`.
  - `liveness_session.dart` & Part Files:
    - Pure Dart orchestrator coordinating quality pre-gate, neutral calibration, active challenges, temporal motion analysis, passive evaluation scheduling, continuous passive floor monitoring, flash verification, and candidate crop selection.
    - `session_state.dart`: `LivenessSessionState` hierarchy (`SessionStateInitializing`, `SessionStateQualityGuidance`, `SessionStateNeutralPose`, `SessionStateChallenge`, `SessionStateFlash`, `SessionStateFinalizing`, `SessionStatePassed`, `SessionStateFailed`) and `SessionFailureReason`.
    - `verified_live_faces.dart`: `VerifiedLiveFaceCrop` and `VerifiedLiveFaces` with private generative constructor `VerifiedLiveFaces._(...)` preventing forgery.
    - `live_session_result.dart`: `LiveSessionResult` combining verdict, non-biometric `AttemptLog`, and `VerifiedLiveFaces`.
- **Presentation Layer (`lib/features/liveness/presentation/`)**:
  - `widgets/session_oval_painter.dart`:
    - Custom painter drawing transparent oval cutout on darkened background, state-reactive colored border (green for aligned, orange for guidance, red for failed, neutral for idle), and continuous outer progress ring tracking remaining total session time.
  - `verification_screen.dart` (`/verification`):
    - Full-screen camera verification UI with remaining timeout badge, real-time quality guidance pills (e.g., "Keep head straight", "Hold still", "Too dark"), active challenge instruction banner with step indicator, full-screen color flash overlay with smooth opacity, and lockout countdown view.
  - `result_screen.dart` (`/result`):
    - Outcome screen with green/red status badge, localized failure reason, summary metrics card (duration, passive score, challenge completion count), and primary return action.
  - `lib/features/ml/presentation/home_screen.dart`:
    - Added "Start Attendance Verification" action button navigating directly to `/verification`.
- **Routing & Dependency Injection**:
  - `lib/core/router/app_router.dart`: Added `/verification` and `/result` routes.
  - `lib/core/di/providers.dart`: Registered `sessionLockoutStorageProvider`, `sessionLockoutTrackerProvider`, `livenessSessionWorkerProvider`, and `livenessSessionProvider`.
- **Localization**:
  - Added localized strings in English and Arabic (`app_en.arb`, `app_ar.arb`) covering verification prompts, quality guidance, lockout countdown, failure reasons, and result statistics. Regenerated with `flutter gen-l10n`.

### Decisions
1. **Private Constructor Enforcement for Verified Live Crops**: `VerifiedLiveFaces` utilizes Dart library-private constructor `VerifiedLiveFaces._(...)` declared via `part 'verified_live_faces.dart';` inside `liveness_session.dart`. This guarantees that downstream recognition (Step 07) cannot be invoked with arbitrarily created face crops; crops can only originate from a fully passed `LivenessSession`.
2. **Decoupled Pure Dart Domain**: `LivenessSession` has zero dependencies on Flutter UI (`package:flutter/`), utilizing `FrameData`, `DetectedFace`, `Clock`, `RandomSource`, and `LivenessSessionWorker` abstractions. This enables end-to-end deterministic unit testing without widget testers or running emulators.
3. **Lockout Persistence**: `SessionLockoutTracker` persists consecutive failure count and lockout expiration timestamp via `SharedPreferences`. Restarting or killing the application cannot bypass active lockout periods.
4. **Biometric Data Segregation**: `AttemptLog` strictly stores scalar operational metrics and zero image bytes or embeddings, preserving biometric privacy compliance.

### Assumptions
- Attendance policy requires 1 active challenge and 3 passive samples; enrollment policy requires 2 active challenges and 5 passive samples.
- Consecutive failure threshold is 3 attempts; lockout duration is 30 seconds.
- Quality gate failures pause challenge progress and prompt real-time user guidance without immediately aborting the session.
- Up to 3 frontal crops with highest sharpness variance are collected during neutral and finalizing phases for recognition handoff.

### Deviations
- None.

### Known Issues
- None in code.

### Verification Status
- `dart format .`: clean (0 changed).
- `flutter analyze`: zero issues found.
- `flutter test`: 190 tests passed across the entire repository (100% pass rate).
- `flutter gen-l10n`: cleanly regenerated localization delegates.
- Hotfix applied to `ChallengesDevScreen`: resolved bug where null challenge on failure displayed `Passed`; now correctly displays failure state and reason, hides all telemetry numbers on failure, and presents a prominent Retry button.

### Manual Tests for Physical Devices
1. **Attendance Verification Flow (`/verification`)**:
   - Tap "Start Attendance Verification" on the Home screen.
   - Position face inside oval: verify border turns green, neutral calibration completes, and prompt advances to active challenge (e.g., "Blink your eyes" or "Turn your head left").
   - Complete challenge naturally: verify transition to result screen displaying "Verification Passed" with session metrics.
2. **Quality Guidance Feedback**:
   - Tilt head beyond $25^\circ$: verify guidance pill displays "Keep head straight" and progress pauses.
   - Move phone too far: verify guidance pill displays "Move closer" and oval border turns orange.
   - Re-center and align: verify guidance clears and verification resumes.
3. **Session Timeout & Failure Handling**:
   - Hold phone still without completing the requested challenge for 10 seconds: verify session times out and navigates to Result Screen displaying "Verification Failed" with reason "Session timed out".
4. **Lockout Protection**:
   - Deliberately fail or cancel 3 consecutive verification sessions.
   - Verify 3rd failure locks the verification flow for 30 seconds, showing a countdown timer with disabled retry button until expiration.
   - Force quit and restart the app during lockout: verify lockout screen remains active until the 30-second timer elapses.

---

## Step 07 - Recognition, Encrypted Storage, Enrollment, Identification
- Status: Completed

### What Was Built
- **SFace Biometric Embeddings (`lib/features/recognition/`)**:
  - `domain/recognizer_preprocess_config.dart`:
    - Immutable configuration for SFace normalization (RGB channel order, scale 1.0, mean [0.0, 0.0, 0.0], std [1.0, 1.0, 1.0]).
  - `domain/face_recognizer.dart`:
    - Interface requiring `VerifiedLiveFaces` for verification and `Uint8List alignedRgb` for enrollment, enforcing that unverified face crops cannot trigger verification recognition.
  - `lib/features/ml/worker/worker_protocol.dart` & `ml_worker.dart`:
    - Added `EmbedCommand` and `EmbedData` protocol messages.
    - Worker isolate dynamically extracts input/output tensor shapes from ONNX session metadata (supporting 112x112 input and 128-d output without hardcoded constants).
    - Multi-crop embedding handling: computes L2-normalized vector per crop, averages unit vectors across available crops, and applies final L2-normalization.
  - `data/sface_recognizer_impl.dart`:
    - Concrete implementation resolving float vs int8 model variants according to `TierProfile`.
- **Offline Python Verification Tool (`tools/verify_recognition.py`)**:
  - Python tool utilizing ONNX Runtime and OpenCV to evaluate SFace embeddings across directories of face photos.
  - Supports same-person vs different-person pair evaluation, FAR/FRR threshold sweeps, direct pair cosine comparisons, and Umeyama landmark alignment verification. Documented in `docs/MODELS.md`.
- **AES-256-GCM Hardware-Backed Encryption (`lib/core/crypto/`)**:
  - `encryption_service.dart`:
    - Cryptographic service using `package:cryptography` (`AesGcm.with256bits()`).
    - Serializes 128-d float embeddings into 512-byte little-endian buffers.
    - Generates 12-byte nonces and 16-byte MAC authentication tags.
    - Persists 256-bit AES master key in hardware Keystore (Android) / Keychain (iOS) via `flutter_secure_storage`.
    - Detects and rejects any ciphertext or tag tampering with authentication failures.
- **Drift SQLite Storage (`lib/core/database/` & `lib/features/employees/`)**:
  - `app_database.dart`:
    - Schema defining `Employees` (`DbEmployee`), `Embeddings` (`DbEmbedding`), `AttendanceRecords` (`DbAttendanceRecord`), and `AttemptLogsTable` (`DbAttemptLog`).
    - Embeddings store `ciphertext`, `nonce`, `mac`, `modelId`, and `dimension`.
    - Zero plaintext embeddings and zero face images are stored in the database.
  - `domain/employee.dart` & `domain/employee_repository.dart`:
    - Entities `Employee` and `EnrolledEmbedding`, repository contract supporting active filtering, code uniqueness, cascade deletion, and re-enrollment.
  - `data/drift_employee_repository.dart` & `data/fake_employee_repository.dart`:
    - Concrete Drift implementation with transaction management and model/dimension mismatch detection (`needsReEnrollment`).
- **1:N Face Matcher (`lib/features/recognition/`)**:
  - `domain/match_result.dart`:
    - Typed outcome hierarchy: `MatchResultMatched`, `MatchResultAmbiguous`, `MatchResultNoMatch`, `MatchResultNoEnrolledEmployees`.
  - `domain/face_matcher.dart`:
    - Computes maximum cosine similarity across all stored embeddings per employee.
    - Enforces threshold (`recognitionThreshold`, default 0.363) and margin (`recognitionMargin`, default 0.08) rules.
    - Uses raw cosine score for authorization and calibrated sigmoid curve $P = 1 / (1 + e^{-25 \cdot (s - \text{threshold})})$ strictly for user-facing percentage display.
    - Decrypted embeddings are cached in memory with a 5-minute TTL and explicitly invalidated on employee modifications.
- **Structured 5-Pose Enrollment Flow (`lib/features/employees/`)**:
  - `domain/enrollment_pose.dart` & `domain/enrollment_session.dart`:
    - 5 structured head poses: Front, Slight Left, Slight Right, Slight Up, Slight Down.
    - Enforces a 3-frame hold requirement per pose and continuous face tracking ID continuity.
    - Quality gate checks pause capture and surface real-time guidance pills.
    - Pre-save duplicate check compares new embeddings against all enrolled employees, blocking duplicates with a confirmation dialog.
- **Presentation Layer & UI Integration**:
  - `lib/features/employees/presentation/employees_screen.dart` (`/employees`):
    - Searchable list of employees, active status filter chip, edit name/code dialog, active/inactive toggle, re-enroll navigation, and cascade delete confirmation dialog.
  - `lib/features/employees/presentation/enrollment_screen.dart` (`/enrollment`):
    - Form validation (employee code uniqueness), oval camera preview, pose instructions, hold progress bar, and duplicate face detection warning dialog.
  - `lib/features/liveness/presentation/result_screen.dart`:
    - Integrated 1:N biometric identification flow following successful liveness verification, displaying matched employee card, confidence percentage, or ambiguous/unrecognized status.
  - `lib/features/ml/presentation/home_screen.dart`:
    - Added "Employees & Enrollment" action button with responsive scrolling.
- **Localization**:
  - Added localized strings in English and Arabic (`app_en.arb`, `app_ar.arb`) covering all employee management, enrollment guidance, duplicate detection warnings, and matching verdicts. Regenerated with `flutter gen-l10n`.
- **Dependency Injection & Routing**:
  - Registered all repositories, services, matchers, and enrollment session orchestrators in `lib/core/di/providers.dart`.
  - Registered `/employees` and `/enrollment` routes in `lib/core/router/app_router.dart`.

### Decisions
1. **AES-256-GCM Hardware-Backed Encryption**: Biometric embeddings (128 floats = 512 bytes) are encrypted at rest using AES-GCM 256-bit with hardware-backed Keystore/Keychain master keys. Zero plaintext vectors, photos, or crops are persisted.
2. **Model Incompatibility & Re-Enrollment Guard**: Each stored embedding includes its generating `modelId` and `dimension`. If the active recognizer model or dimension differs, `needsReEnrollment` is flagged and incompatible embeddings are filtered out of 1:N matching to prevent invalid vector comparisons.
3. **Raw Score Authorization vs Display Sigmoid**: Security accept/reject decisions are based strictly on the raw cosine similarity score against threshold and margin. The display percentage uses a centered sigmoid curve purely for intuitive user presentation.
4. **Library-Private Live Face Guarantee**: The `FaceRecognizer` interface accepts `VerifiedLiveFaces` for verification, which cannot be instantiated outside `liveness_session.dart` due to its library-private generative constructor.

### Assumptions
- SFace cosine recognition threshold default set to 0.363; separation margin default set to 0.08. Both configurable in `AppConfig`.
- Enrollment requires 5 distinct head poses (front, slight left, slight right, slight up, slight down), each held for 3 consecutive valid frames.
- Master AES key alias stored in Keystore/Keychain under `face_biometric_master_key`.

### Deviations
- None.

### Known Issues
- None in code.

### Verification Status
- `dart format .`: clean.
- `flutter analyze`: zero issues found.
- `flutter test`: 222 tests passed across the entire repository (100% pass rate).
- `flutter gen-l10n`: cleanly regenerated localization delegates.

### Bug Fix: SFace Worker Session Initialization & Pre-Warming
- **Root Cause**: `MlWorker.ensureInitialized` previously loaded only `MiniFASNet` anti-spoofing models by default, omitting `ModelRegistry.sFace`. When step 5 of employee enrollment completed, `FaceRecognizer.embedSingleCrop` dispatched an `EmbedCommand` to the background worker isolate, which threw `Exception: Model SFace session not found or uninitialized` because `sessions['SFace']` was not initialized.
- **Fix Applied**:
  - `lib/features/ml/worker/ml_worker.dart`: Changed default target models in `ensureInitialized` to `ModelRegistry.allModels`, and added an automatic session check fallback in `computeEmbedding`.
  - `lib/features/recognition/data/sface_recognizer_impl.dart`: Added explicit initialization check `await mlWorker.ensureInitialized(models: <ModelSpec>[_resolvedModelSpec])` before executing embeddings in both `embedSingleCrop` and `embedVerifiedFaces`.
  - `lib/features/employees/presentation/enrollment_screen.dart` & `lib/features/liveness/presentation/verification_screen.dart`: Eagerly pre-warm the `SFace` model in the background worker isolate during camera and session startup.
  - `test/features/recognition/sface_recognizer_test.dart`: Added comprehensive unit tests for `SFaceRecognizerImpl` covering `embedSingleCrop`, `embedVerifiedFaces`, and empty crop validation.

### Manual Tests for Physical Devices
1. **Employee Management Flow (`/employees`)**:
   - Tap "Employees & Enrollment" on Home screen.
   - Verify list renders empty state ("No employees registered yet.").
   - Tap "+" FAB to open Enrollment.
2. **5-Pose Enrollment Flow (`/enrollment`)**:
   - Enter name ("John Doe") and code ("EMP001"). Tap "Start Face Capture".
   - Follow on-screen pose prompts: look front, turn slightly left, turn slightly right, look slightly up, look slightly down.
   - Verify hold progress bar fills for each pose and advances upon 3 valid frames.
   - Confirm successful enrollment returns to Employees screen with 5 samples recorded.
3. **Duplicate Face Detection**:
   - Tap "+" to enroll another employee with a different code ("EMP002") using the same person's face.
   - Complete 5 poses: verify duplicate face warning dialog appears displaying "Duplicate Face Detected" and matching John Doe.
4. **Attendance Biometric Verification (`/verification` -> `/result`)**:
   - Return to Home and tap "Start Attendance Verification".
   - Complete liveness challenge (e.g. look straight, blink/turn).
   - Verify transition to Result Screen: displays "Verification Passed", identifies "John Doe (EMP001)", and displays match confidence.
5. **Database Encryption Inspection**:
   - Pull `attendance.sqlite` from device storage.
   - Inspect `embeddings` table: verify `ciphertext`, `nonce`, and `mac` columns contain binary blobs and no plaintext floating-point numbers.
