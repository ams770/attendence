# Project Assumptions and Calibration Log

## Step 01 - Foundation Assumptions

1. **Android minSdk**:
   - Set to 21 (Android 5.0) as required by `google_mlkit_face_detection` (minSdk 21) and `onnxruntime` (minSdk 21).

2. **iOS Deployment Target**:
   - Set to 15.5 as required by `google-mlkit-face-detection` SwiftPM dependency (15.5).

3. **Inference Engine**:
   - Evaluated `onnxruntime` (v1.4.1 FFI-based plugin). Successfully resolved and linked on iOS and Android. Placed strictly behind the abstract `InferenceEngine` interface so it can be swapped if needed.

4. **Configurable Thresholds**:
   - Recognition threshold set to 0.363 cosine similarity following OpenCV FaceRecognizerSF recommendation. Marked as requiring empirical calibration.
   - Passive liveness threshold default: 0.85; hard floor default: 0.40; passing frame ratio: 0.75.
   - All thresholds are configurable parameters in `AppConfig` and can be overridden via `AppConfigRepository`.

## Step 02 - Camera, Frames, Worker Isolate, Device Tier Assumptions

1. **Hardware Tier Latency Thresholds**:
   - Total pipeline latency < 60.0 ms: High Tier (ResolutionPreset.high, 20 FPS, 12 passive frames, all models, flash challenge default enabled).
   - Total pipeline latency < 120.0 ms: Mid Tier (ResolutionPreset.medium, 15 FPS, 8 passive frames, all models, flash challenge default enabled).
   - Total pipeline latency >= 120.0 ms: Low Tier (ResolutionPreset.medium, 10 FPS, 5 passive frames, MiniFASNetV2 + SFace only, flash challenge disabled by default).
   - Secondary RAM signal: Devices with strictly less than 2.8 GB total RAM are capped at Mid Tier even if idle inference latency is below 60 ms.

2. **Raw Frame Format & Color Conversion**:
   - Camera image stream format defaults to `ImageFormatGroup.nv21` on Android and `ImageFormatGroup.bgra8888` on iOS.
   - If an Android device cannot initialize NV21, the camera service automatically falls back to `ImageFormatGroup.yuv420`.
   - `PixelSampler` implements ITU-R BT.601 integer math conversion with bilinear interpolation directly from raw multi-plane buffers without full-frame RGB conversion.

3. **Upright Geometry and No-Mirroring**:
   - Camera frames are strictly never mirrored in memory or domain data.
   - Portrait lock ensures rotation matches camera sensor orientation (0, 90, 180, 270 degrees).
   - `FrameGeometry` exposes affine transformation matrices `uprightToRaw` and `rawToUpright` verified across all four rotations.

4. **SFace Model Variant Preference**:
   - `TierProfile` checks for the presence of `assets/ai/face_recognition_sface_2021dec_int8.onnx` dynamically. If absent, it safely falls back to `assets/ai/face_recognition_sface_2021dec.onnx`.

5. **In-Memory Thumbnail Generation**:
   - Pure Dart top-down 24-bit uncompressed BMP generation (`BmpHelper`) is used for real-time visualization on the dev screen without adding external image dependencies.

## Step 03 - Detection, Quality Gate, Alignment Assumptions

1. **Euler Angle Sign Conventions (Front Camera, Portrait)**:
   - **Yaw (`headEulerAngleY`)**: A positive Euler Y angle represents a head turn to the camera's right (which is the subject's left). A negative Euler Y angle represents a head turn to the camera's left (subject's right).
   - **Pitch (`headEulerAngleX`)**: A positive Euler X angle represents the face tilted upward; negative represents face tilted downward.
   - **Roll (`headEulerAngleZ`)**: A positive Euler Z angle represents counter-clockwise tilt relative to the camera sensor.

2. **Landmark Ordering**:
   - Facial landmarks from ML Kit are sorted so `leftEye.dx <= rightEye.dx` and `leftMouth.dx <= rightMouth.dx` in upright image coordinates. This avoids landmark swap confusion under camera mirroring.

3. **Photometric Face Stats & Glare Detection**:
   - Computed on an 80x80 grayscale crop directly sampled from the raw frame using `PixelSampler.warpGrayscale` in the worker isolate.
   - Sharpness is calculated as the discrete 4-neighbor Laplacian variance $\text{Var}(\nabla^2 I)$.
   - Specular glare is flagged if the ratio of pixels with luminance $\ge 250$ exceeds `qualityMaxNearSaturatedRatio` (default 0.10, i.e., 10%).

4. **Umeyama Similarity Transform & Reflection Handling**:
   - The 5 detected points are aligned to the canonical 112x112 ArcFace template via Umeyama least-squares similarity transformation.
   - To prevent unphysical mirror reflections, the rotation matrix determinant is constrained to $+1.0$ via $S = \text{diag}(1, \det(U)\det(V))$.
   - Aligned crops are produced directly from raw camera frames in the background isolate via `PixelSampler.warpAffine`.

## Step 04 - Passive Liveness Assumptions

1. **Baseline Preprocessing Configuration**:
   - Default `PassivePreprocessConfig` ships with original Silent-Face-Anti-Spoofing repository baseline:
     - Channel Order: BGR
     - Value Scale: 1.0 (raw [0.0, 255.0] unscaled byte float values)
     - Normalization: Mean [0.0, 0.0, 0.0], Std [1.0, 1.0, 1.0]
     - Real Class Index: 1
     - Softmax Applied in Dart: true (models output logits)
     - MiniFASNetV2 Crop Scale: 2.7
     - MiniFASNetV1SE Crop Scale: 4.0
   - Status: **Unverified until the `--precropped` report has been run on real captures**. The default parameters ship with the Silent-Face reference baseline, but actual separation must be proven on real physical device captures via `tools/verify_passive.py --precropped`.

2. **Face Box Expansion & Detector Shift**:
   - Original Silent-Face models were trained using bounding boxes from a different face detector than Google ML Kit. ML Kit bounding boxes can be tighter or looser, shifting classification scores.
   - To compensate, `AppConfig.passiveBoxExpansion` is provided (default `1.0`), scaling the detected face box prior to crop scaling. Documented for empirical calibration on physical hardware.

3. **Crop Scale Reduction and Boundary Shifting**:
   - When scaled bounding box (e.g. 2.7x or 4.0x) exceeds image boundaries, scale is reduced to fit ($\text{effectiveScale} = \min(\text{scale}, (H-1)/boxH, (W-1)/boxW)$) and the box is shifted inside the image frame without stretching, faithfully matching the training pipeline.

4. **Aggregator and Multi-Frame Decision Rules**:
   - Verdict requires both:
     - Mean score across all samples $\ge$ `AppConfig.passiveThreshold` (0.85).
     - At least `AppConfig.passivePassingFrameRatio` (75%) of samples individually exceed `AppConfig.passiveThreshold`.
   - A minimum of 3 samples is strictly required. A single frame cannot pass alone; a single bad frame cannot fail alone if the sample size and mean satisfy thresholds.

5. **Continuous Floor Monitor**:
   - `PassiveMonitor` maintains a rolling window of the last 3 samples during interactive challenge phases. If the rolling average drops below `AppConfig.passiveHardFloor` (0.40), an attack/compromise violation is triggered immediately.

---

## Step 05 - Active Challenges, Temporal Signals & Flash Challenge Assumptions

1. **Active Challenge Composition**:
   - Every verification session begins with `ChallengeType.lookStraight` to calibrate the neutral baseline pose (`baselineYaw`) and establish tracking continuity.
   - 2 distinct active challenges are chosen from the pool `[blink, turnLeft, turnRight, smile]` using the secure random source. No active challenge is repeated within the same session.

2. **Verified Yaw Sign Convention (`yawSignForUserLeft`)**:
   - On the front camera in portrait orientation, turning the head toward the subject's physical left produces a positive Euler Y angle (`headEulerAngleY > 0`). Turning right produces a negative angle (`headEulerAngleY < 0`).
   - `AppConfig.yawSignForUserLeft` is initialized to `+1.0`. For `turnLeft`, the relative turn is `(yaw - baselineYaw) * yawSignForUserLeft >= 20.0`. For `turnRight`, `(yaw - baselineYaw) * yawSignForUserLeft <= -20.0`.
   - Opposite-direction motion (e.g. turning right during a left challenge) resets progress and never contributes toward completion.

3. **Blink Hysteresis and Tier Sensitivity**:
   - To eliminate noise around the transition boundary, hysteresis enforces: open $\ge 0.60$, closed $\le 0.25$. Intermediate probabilities (0.25 - 0.60) do not advance the sub-phase.
   - Static photos of closed eyes fail immediately because the machine mandates an initial open state before closed frames are accepted.
   - `challengeBlinkMinClosedFrames` is configurable (default: 2 frames). For Low Tier devices operating at 10 FPS, where a rapid human blink (100 - 150 ms) may be captured in only a single frame, this parameter can be configured to 1.

4. **Tracking Continuity and Timeout**:
   - The initial detected face establishes `initialTrackingId`. Any change in tracking ID immediately aborts the session with `ChallengeFailureReason.trackingChanged`.
   - Temporary loss of the face (e.g. rapid turn or occluding hand) is permitted within `faceLostGracePeriod` (default 700 ms). Exceeding this period fails the session with `ChallengeFailureReason.trackingLost`.
   - Each challenge step has an independent timeout (`perChallengeTimeout`, default 6 seconds). Exceeding it fails the session with `ChallengeFailureReason.timeout`.

5. **Temporal Signal Thresholds**:
   - Normalized coordinate micro-motion: Natural physiological micro-movement target is calibrated to variance $1.0 \times 10^{-5}$. A variance below $1.0 \times 10^{-7}$ indicates a completely frozen static photo and fails the session.
   - Repeating loop detection: Autocorrelation evaluates lags between 4 and 16 frames. A relative sequence distance below $0.08$ with non-zero total variance flags a periodic replayed video loop.
   - 3D Planar Rigidity: Measures affine residual across 5 landmarks between neutral and turned poses ($|\text{yaw}| \ge 15^\circ$). A residual $\le 0.007$ of face width identifies a flat 2D photograph rotated in front of the camera; a residual $\ge 0.020$ confirms genuine 3D facial depth parallax.

6. **Screen-Color-Flash Reflection**:
   - 3 to 4 randomized colors from `{red, green, blue, white}` are displayed full-screen with 350 ms dwell time.
   - Ambient illumination bounds: baseline brightness $< 30.0$ skips with `ambientTooDark`; brightness $> 220.0$ skips with `ambientTooBright`.
   - Minimum standard deviation across color channel deltas must exceed $1.5$ to surpass sensor noise floor.
   - Minimum Pearson correlation $r \ge 0.35$ passes; $r < 0.0$ fails. Default enabled on High Tier only; configurable in Settings.

---

## Step 06 - Verification Session, Timers, and Verification UI Assumptions

1. **Session Policy Presets (`SessionPolicy`)**:
   - `SessionPolicy.attendance`: Optimized for quick daily check-ins. Requires 1 active challenge, 3 passive samples, with an overall timeout of 10.0 seconds.
   - `SessionPolicy.enrollment`: Stricter multi-sample acquisition. Requires 2 active challenges, 5 passive samples, with an overall timeout of 15.0 seconds.
   - Policies dynamically scale required passive sample thresholds and challenge sets without altering underlying security floors.

2. **Quality Gate Pre-Filtering & UI Guidance**:
   - Frames must satisfy the quality gate before advancing challenge state or collecting passive crops.
   - Violations emit real-time localized guidance (`keepHeadStraight`, `faceTooSmall`, `faceOutOfBounds`, `tooDark`, `tooBright`, `multipleFaces`, `holdStill`) while pausing challenge timers and progress.
   - If a face is lost during active challenges, a 700 ms grace period prevents immediate failure from transient occlusions.

3. **Session Lockout Enforcement (`SessionLockoutTracker`)**:
   - Limits consecutive failed verification attempts to 3 (configurable via `AppConfig.lockoutMaxConsecutiveFailures`).
   - Upon the 3rd consecutive failure, verification is locked out for 30.0 seconds (configurable via `AppConfig.lockoutDurationSeconds`).
   - State (consecutive failure count, lockout expiration timestamp) is persisted asynchronously via `SessionLockoutStorage` (`SharedPreferences`), ensuring an app kill or restart cannot bypass the lockout timer.
   - Any passing session immediately resets the consecutive failure counter to 0.

4. **Biometric Security & Constructor Privacy (`VerifiedLiveFaces`)**:
   - `VerifiedLiveFaces` is declared in `verified_live_faces.dart` as `part of 'liveness_session.dart';` with a private generative constructor `VerifiedLiveFaces._(...)`.
   - This prevents compile-time and runtime instantiation of live face crops by mockers or unauthorized modules; only `LivenessSession._buildResult()` can construct verified face crops for downstream recognition (Step 07).
   - Crops capture both aligned canonical ArcFace crops ($112 \times 112$) and raw frontal crops with bounding boxes, selected by ranking highest sharpness variance.

5. **Attempt Audit Logging & Privacy Integrity**:
   - Every verification attempt (passed or failed) produces an immutable `AttemptLog` record capturing duration, policy, failure reason, passive metrics, and challenge records.
   - To uphold user privacy and compliance with biometric storage regulations, `AttemptLog` strictly stores zero image buffers, crops, or embedding vectors.

---

## Step 07 - Recognition, Encrypted Storage, Enrollment, Identification Assumptions

1. **SFace Recognizer Preprocessing & Normalization**:
   - SFace preprocessing uses RGB channel order, 112x112 input tensor, raw [0.0, 255.0] unscaled pixel floats, mean [0.0, 0.0, 0.0], std [1.0, 1.0, 1.0].
   - Embeddings from each candidate crop are L2-normalized individually. When multiple crops are available (up to 3 frontal crops from verification), the unit vectors are averaged element-wise and the resulting vector is L2-normalized again.
   - SFace input dimensions and output vector length (128 floats) are dynamically queried from the ONNX session graph metadata rather than hardcoded constants.

2. **AES-256-GCM Biometric Storage Encryption**:
   - Biometric vectors (128 32-bit floats = 512 bytes) are serialized into little-endian byte buffers and encrypted with AES-256-GCM using `package:cryptography` (`AesGcm.with256bits()`).
   - The master 256-bit AES encryption key is securely stored in hardware-backed storage via `flutter_secure_storage` (Android Keystore, iOS Keychain) under the alias `face_biometric_master_key`.
   - Each embedding stores ciphertext (512 bytes), 12-byte initialization vector (nonce), and 16-byte authentication tag (MAC). Any bit modification or tampering causes authentication decryption to fail immediately.
   - Raw face photos, crops, and unencrypted embeddings are strictly never persisted to disk or logged.

3. **Model Incompatibility & Re-Enrollment Guard**:
   - Each embedding record stores `modelId` and `dimension`. If an employee has embeddings generated with a different model or dimension, `needsReEnrollment` is set to `true` and the incompatible embeddings are filtered out of `getActiveEmbeddings`, preventing invalid cosine comparisons.

4. **1:N Biometric Matching, Margin & Display Sigmoid**:
   - For an employee with multiple enrolled embeddings, their match score is the maximum cosine similarity across all their stored embeddings.
   - Match criteria requires: `bestScore >= recognitionThreshold` (default 0.363) AND `(bestScore - secondBestScore) >= recognitionMargin` (default 0.08).
   - Security decision strictly uses the raw cosine score. Displayed match percentage uses a calibrated sigmoid curve $P = 1 / (1 + e^{-25 \cdot (s - \text{threshold})})$ for UI presentation only.
   - Decrypted embeddings are cached in memory with a 5-minute TTL and explicitly cleared on employee updates, toggles, or deletions.

5. **5-Pose Structured Enrollment Flow**:
   - Enrolls employees with 5 structured head poses: Front ($|\text{yaw}| \le 8^\circ, |\text{pitch}| \le 8^\circ$), Slight Left ($\text{yaw} \ge 10^\circ$), Slight Right ($\text{yaw} \le -10^\circ$), Slight Up ($\text{pitch} \ge 8^\circ$), Slight Down ($\text{pitch} \le -8^\circ$).
   - Each pose requires a consecutive 3-frame hold with quality checks passing.
   - Face tracking ID continuity is strictly enforced across the entire 5-pose session.
   - Duplicate face detection runs against all existing active employees before saving, prompting a confirmation warning if cosine similarity exceeds threshold.

