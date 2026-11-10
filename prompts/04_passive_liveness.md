# Step 04 - Passive Liveness (MiniFASNet)

Read `prompts/00_CONTEXT.md` and `prompts/PROGRESS.md` first. Steps 01 to 03 must be finished.

## Goal

Run MiniFASNetV2 and MiniFASNetV1SE on face crops, aggregate scores across frames, and keep the preprocessing verifiable and configurable.

## Background you must respect

- The original project crops the face with a scale factor around the detector box (2.7 for V2, 4.0 for V1SE), resizes to 80x80, and feeds raw 0 to 255 BGR values. When the scaled box leaves the image, the original code reduces the scale to fit and shifts the box inside the image; it does not stretch. Reproduce that behavior, because the models were trained on it.
- The original face box came from a different detector than ML Kit. ML Kit boxes can be tighter or looser, which shifts scores. Make the box expansion a config value (default 1.0) and document this limitation in `docs/ASSUMPTIONS.md`.
- ONNX exports from third-party repositories may differ in normalization, channel order, or whether softmax is already applied. Never assume. Make all of it a `PassivePreprocessConfig`: channel order, value scale, mean, std, real-class index, apply-softmax flag, per-model crop scale.

## Tasks

1. `tools/verify_passive.py`: a Python script (onnxruntime, numpy, opencv-python) that takes a folder of labeled sample images (`real/`, `spoof/`), runs both models with several preprocessing variants (BGR vs RGB, scale 1 vs 1/255), and prints the 3 outputs and the probability of each class per image and per variant, plus a summary table, so the developer can pick the variant that separates real from spoof. Include clear usage instructions at the top of the file and in `docs/MODELS.md`.
2. `PassiveCropper`: implements the scaled crop with scale reduction and shifting as described, producing the 80x80 sample through `PixelSampler.warpAffine`. Unit-test with boxes near every image border and with boxes larger than the image.
3. Worker command `runPassive`: input frame, face box, geometry, which models to run (tier controlled; low tier may run V2 only). Output per-model real probability and latency. Apply softmax in Dart only if the config says the output is logits. Reuse tensors and buffers.
4. `PassiveLivenessEngine` interface plus the ONNX implementation, so the model can be replaced.
5. `PassiveAggregator`:
   - Collects per-frame scores (average of the models that ran).
   - Verdict passes only if BOTH the mean score is above `passiveThreshold` AND at least 75 percent of frames are above it. One good frame never passes; one bad frame never decides alone.
   - Frames must be spread across the session: provide a `PassiveScheduler` that decides, from the session phase and elapsed time, when a frame should be sampled so that samples cover the neutral step, each challenge, and the final phase (not the first N consecutive frames).
   - `PassiveMonitor` for continuous checking during challenges: fails when the rolling average over the last K sampled frames drops below a hard floor, so swapping a photo in after the challenge is caught.
6. Temporary dev screen `/dev/passive`: shows per-model scores, aggregated verdict, latency per model, and lets the developer export the per-frame scores to CSV (for the evaluation protocol later).
7. Tests: cropper math, softmax, aggregator rules (single good frame not enough, single bad frame not decisive, ratio rule, mean rule), monitor floor logic, scheduler distribution.

## Acceptance criteria

- `flutter analyze` and `flutter test` are clean.
- With the developer's verification result, set the default `PassivePreprocessConfig` and record exactly which variant was chosen and why in `docs/ASSUMPTIONS.md`. If the developer has not run `verify_passive.py` yet, ship the original-repo defaults, state clearly that they are unverified, and say so in `PROGRESS.md`.
- On a real device the dev screen shows clearly higher scores for a live face than for a face on another phone screen and a printed photo. State honestly in `PROGRESS.md` what was observed, including failures.

## Do not

- Do not hardcode thresholds outside `AppConfig`.
- Do not claim the thresholds are calibrated.
