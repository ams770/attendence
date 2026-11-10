# Step 09 - Hardening, Performance, Documentation, Release

Read `prompts/00_CONTEXT.md` and `prompts/PROGRESS.md` first. Steps 01 to 08 must be finished.

## Goal

Finish security hardening, run a performance and memory pass, complete the documentation, and make release builds reproducible.

## Tasks

1. Root and jailbreak detection behind an interface and a feature flag. When detected, warn the admin in the UI and write it to the attempt log; do not silently block. Choose a maintained approach, verify it works on current OS versions, and document its limits (it can be bypassed).
2. Virtual or injected camera awareness: document what cannot be detected offline, and add the checks that are feasible (for example, abnormal frame timing patterns, camera metadata inconsistencies) as optional signals that only add evidence, never as the sole reason to fail.
3. Model file protection: evaluate encrypting the model assets at rest and decrypting in memory. If implemented, keep the key handling honest in the docs (an attacker with the device can still extract it). If not implemented, document why.
4. Release build:
   - Android: `flutter build apk --release --obfuscate --split-debug-info=build/symbols` and the app bundle equivalent, R8 settings verified with ONNX Runtime and ML Kit working in release, signing instructions.
   - iOS: the equivalent obfuscated build, App Store notes about camera usage text.
   - Verify that a release build passes the self-check and a full verification on a real device. Fix any release-only failures (stripped native libs, missing rules).
5. Performance and memory pass on one weak and one strong device:
   - Confirm no per-frame allocation growth, buffers reused, interpreters and sessions disposed on screen exit and app pause, and the worker isolate cleanly restarts after a crash.
   - Measure and record per-stage latency (detection, quality stats, passive per model, alignment, embedding), end-to-end session time, peak memory, and thermal behavior over 20 consecutive sessions. Tune tier profiles accordingly and document the final numbers in `docs/MODELS.md`.
6. Documentation (clear, no emojis):
   - `README.md`: setup, supported platforms, how to run, how to build, how to run tests, project architecture diagram in text form.
   - `docs/MODELS.md`: where each model file lives, expected input and output, the exact preprocessing used, how it was verified, licensing notes for each model and its training data (state clearly that code licenses and weight or dataset licenses are different and that the developer must check them for commercial use), and how to swap a model.
   - `docs/EVALUATION.md`: test protocol with genuine users on several phones and lighting conditions, printed photos of different quality, photos on phone, tablet and monitor, replayed video on phone and tablet, and a high-quality mask if available; minimum sample counts; how to compute APCER, BPCER, and ACER from the exported CSV (include a small Python script `tools/compute_pad_metrics.py`); how to choose the recognition threshold from genuine and impostor score distributions at a target false accept rate; and how to choose the passive threshold at a target APCER and BPCER.
   - `docs/ASSUMPTIONS.md`: every unverified assumption made during the build, with its status.
   - `docs/LIMITATIONS.md`: an honest section on what the app can and cannot defend against, including: a rooted or jailbroken device, injected or virtual camera feeds, high-quality 3D masks, deepfakes streamed into a hooked camera, ML Kit box versus training-detector mismatch, children and twins, similar faces, changes in appearance, and the fact that thresholds are only valid after calibration. Include a recommendation to sync records to a server later and use Play Integrity and App Attest for stronger guarantees.
   - Privacy notes: biometric data handling, consent, retention, and deletion.
7. Final audit checklist, executed and reported in `PROGRESS.md`:
   - No emojis anywhere (search the repo).
   - No `TODO`, `FIXME`, or placeholder text.
   - No logging of biometric values (search for print and logger usage).
   - Every threshold and duration lives in `AppConfig`.
   - ARB key parity test passes.
   - `dart format`, `flutter analyze`, and `flutter test` are clean.
   - All dev routes are hidden in release builds.
   - Dependency licenses listed in the README or a `NOTICE` file.

## Acceptance criteria

- A release build installed on real Android and iOS devices passes the self-check and completes enrollment and attendance flows.
- The final `PROGRESS.md` lists everything built, every assumption still open, and a prioritized list of remaining risks.

## Do not

- Do not claim the app is secure against attacks listed as limitations.
- Do not mark an item done in the audit without actually checking it.
