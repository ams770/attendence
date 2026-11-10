# 00 - Shared Context (read this before every step)

## Project

Flutter app, package name `attendence` (keep this spelling), already created. It is an offline employee attendance (check-in / check-out) app that uses face recognition protected by multi-layer liveness (anti-spoofing). Everything runs on-device with no network. It must work on weak (2 to 3 GB RAM) and strong Android and iOS phones.

Existing files you must use, never rename or move:

```
assets/ai/MiniFASNetV2.onnx
assets/ai/MiniFASNetV1SE.onnx
assets/ai/face_recognition_sface_2021dec.onnx
```

## Global rules (apply to every step)

1. No emojis or decorative characters anywhere: UI strings, code comments, logs, docs, commit messages.
2. Dart null safety, Flutter latest stable, Material 3, clean minimal design.
3. Riverpod for state. Feature-first Clean Architecture (presentation / domain / data). Every model and platform dependency sits behind an interface so it can be swapped (face detector, passive liveness engine, face recognizer, storage, clock, random source).
4. Write complete files. No placeholders, no `TODO`, no stubs that pretend to work. If something cannot be completed in the current step, say so explicitly in `prompts/PROGRESS.md` instead of faking it.
5. Never log or print biometric data (embeddings, face images, raw scores tied to a person).
6. Do not invent package APIs. Before using a package, check its current documentation on pub.dev and use `flutter pub add` so versions are real and compatible. If an API differs from what these prompts assume, adapt the code and note it in `docs/ASSUMPTIONS.md`.
7. If a fact cannot be verified (for example a model preprocessing detail), pick the safest configurable option, record it in `docs/ASSUMPTIONS.md`, and make it a config value, not a hardcoded constant.
8. After every step run: `dart format .`, `flutter analyze`, `flutter test`. Fix everything before reporting. Zero analyzer warnings.
9. Tests must be deterministic: inject a `Clock` and a `RandomSource` abstraction instead of calling `DateTime.now()` or `Random` directly in logic classes.
10. All user-visible strings go through localization (Arabic RTL and English). Add new keys to both ARB files in the step that introduces them.

## Model facts (working assumptions, must be verified in code and documented)

| Model | File | Input | Output |
|---|---|---|---|
| MiniFASNetV2 | MiniFASNetV2.onnx | 80x80, crop scale 2.7 around the face box | 3 values (class scores), real class index to be verified |
| MiniFASNetV1SE | MiniFASNetV1SE.onnx | 80x80, crop scale 4.0 around the face box | 3 values, real class index to be verified |
| SFace | face_recognition_sface_2021dec.onnx | 112x112 aligned face | 128-d embedding |

Original Silent-Face-Anti-Spoofing behavior (reference: github.com/minivision-ai/Silent-Face-Anti-Spoofing): BGR channel order, raw pixel values 0 to 255 without division by 255, softmax over 3 classes, index 1 is the real class. The ONNX exports from other repositories may differ, so the preprocessing is a config object and is verified empirically (see step 04).

SFace preprocessing (reference: OpenCV FaceRecognizerSF): 5-point alignment to the standard 112x112 ArcFace template, RGB order, raw 0 to 255 values, no mean or std, 128-d output, then L2 normalization before cosine similarity. OpenCV's recommended cosine threshold is about 0.363; the app default must be configurable and clearly marked as needing calibration on real employees.

Standard 112x112 alignment template (x, y): left-eye-in-image (38.2946, 51.6963), right-eye-in-image (73.5318, 51.5014), nose (56.0252, 71.7366), left-mouth-in-image (41.5493, 92.3655), right-mouth-in-image (70.7299, 92.2041).

## Threading model

- ML Kit face detection runs on the main isolate (it uses platform channels and already executes natively off the UI thread).
- A single long-lived worker isolate owns the ONNX Runtime sessions and does all pixel work: frame sampling, cropping, warping, normalization, quality statistics, inference. Frame bytes are sent with `TransferableTypedData`.
- At most one camera frame is in flight at any time; other frames are dropped. Frame skipping adapts to measured processing time.
- The app is locked to portrait. Camera frames are never mirrored in data; mirroring is a display-only concern for the front camera preview. Enrollment and verification both use un-mirrored upright images so embeddings are consistent.

## Target folder structure

```
lib/
  main.dart
  app.dart
  core/            config, di, l10n, theme, utils (clock, random, math), errors
  features/
    device/        tier benchmark and profiles
    camera/        camera service, frame model, throttler, geometry
    ml/            worker isolate, ONNX engine, pixel sampler, model self-check
    detection/     face detector interface, ML Kit impl, quality gate, alignment
    liveness/      passive, challenges, temporal, flash, session orchestrator, UI
    recognition/   embedding, matcher
    employees/     enrollment, employee storage
    attendance/    records, check-in/out logic, export
    settings/      settings, admin PIN
    debug/         debug screen, attempt log
docs/              MODELS.md, EVALUATION.md, ASSUMPTIONS.md, LIMITATIONS.md
tools/             verify_passive.py, verify_recognition.py
test/
prompts/           these files, plus PROGRESS.md
```

## Progress file

Maintain `prompts/PROGRESS.md`: for each finished step list what was built, decisions taken, assumptions, deviations from the step prompt, known issues, and the manual tests the developer should run on a real device.
