# Step 01 - Foundation

Read `prompts/00_CONTEXT.md` first and follow its global rules.

## Goal

Prepare the existing empty project: dependencies, platform configuration, folder structure, configuration constants, theme, localization, app shell, and a startup model self-check. Do not recreate the project; inspect the current `pubspec.yaml`, `android/`, `ios/`, and `lib/` and build on them.

## Tasks

1. Dependencies. Add with `flutter pub add` (never hand-write versions from memory) and keep the resulting versions:
   - Runtime: `flutter_riverpod`, `go_router`, `camera`, `google_mlkit_face_detection`, `onnxruntime` (ONNX Runtime for Flutter, FFI based), `drift` with `sqlite3_flutter_libs` and `path_provider`/`path`, `flutter_secure_storage`, `cryptography`, `shared_preferences`, `permission_handler`, `device_info_plus`, `package_info_plus`, `intl`, `csv`, `share_plus`, `flutter_localizations` (sdk).
   - Dev: `drift_dev`, `build_runner`, `flutter_lints`, `mocktail`.
   - If `onnxruntime` does not work on current Flutter, evaluate `flutter_onnxruntime` and document the decision. The inference layer must stay behind an interface.
2. Assets: declare `assets/ai/` in `pubspec.yaml`. Do not rename the model files.
3. Android: set `minSdk` to the highest value required by the chosen plugins, add camera permission, lock to portrait, and make sure release builds do not strip native libraries needed by ONNX Runtime or ML Kit (add the required R8/ProGuard rules only if the build needs them).
4. iOS: set the minimum iOS version required by the plugins in `Podfile` and the Xcode project, add `NSCameraUsageDescription` with a clear localized-friendly message, lock to portrait. Run `pod install` and fix issues.
5. `lib/core/config/app_config.dart`: one immutable config class holding every tunable value with defaults and doc comments: session timeout (30 s), per-challenge timeout (6 s), failure limit (3), lockout duration (60 s), passive threshold, passive passing-frame ratio (0.75), hard floor, recognition threshold (0.363 as a placeholder that must be calibrated), recognition margin, attendance cooldown (60 s), quality gate limits (min face width ratio 0.25, max yaw/pitch/roll, sharpness range, brightness range), challenge thresholds, face-lost grace period. Persisted overrides will be added in a later step; design the class with `copyWith` and a repository interface now.
6. `lib/core/utils`: `Clock` and `RandomSource` abstractions (system implementations use a cryptographically secure random), plus small math helpers.
7. Theme: Material 3, light and dark, no decorative elements.
8. Localization: ARB files for Arabic and English, generated localizations, locale provider that defaults to the device language, RTL working. Add the strings needed for this step only.
9. Model self-check:
   - `InferenceEngine` and `InferenceSession` interfaces (load from bytes, input and output names, run with float32 tensors), and an ONNX Runtime implementation.
   - `ModelRegistry` listing the three models with expected input shape and expected output size.
   - `ModelSelfCheck` that loads each asset, creates a session, runs one dummy inference with a zero tensor, and verifies the output size (3 for MiniFAS models, 128 for SFace) and input names. It must return a structured result per model.
   - Note: loading a large model from asset bytes uses memory; create the session from the buffer and release the buffer afterwards.
10. App shell with `go_router`: Home placeholder screen is NOT allowed to be fake; make a real minimal Home that shows the app title and the self-check status, and a full-screen Error screen listing every failed model with the reason and the exact expected file path.

## Acceptance criteria

- `flutter analyze` and `flutter test` are clean.
- The app starts on an Android emulator or device and an iOS simulator or device, runs the self-check, and shows either Home or the Error screen.
- Temporarily renaming one model file produces the Error screen naming that file.
- Unit tests: `AppConfig.copyWith`, `ModelSelfCheck` logic using a fake `InferenceEngine`.
- `prompts/PROGRESS.md` created with the step 01 entry and a list of manual checks for the developer.

## Do not

- Do not implement camera, detection, or liveness here.
- Do not hardcode strings in widgets.
