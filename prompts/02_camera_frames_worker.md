# Step 02 - Camera, Frames, Worker Isolate, Device Tier

Read `prompts/00_CONTEXT.md` and `prompts/PROGRESS.md` first. Step 01 must be finished.

## Goal

Build the real-time frame pipeline: camera stream, frame model, geometry, throttling, a pixel sampler that works directly on raw camera buffers, a long-lived worker isolate, and the device tier benchmark.

## Tasks

1. `FrameData` (immutable): format (`nv21` on Android, `bgra8888` on iOS), width, height, bytes, row stride(s), sensor rotation, lens direction, timestamp. Use `ImageFormatGroup.nv21` on Android and `bgra8888` on iOS with the `camera` package. If nv21 is unavailable on a device, fall back to yuv420 and support it in the sampler.
2. `FrameGeometry`: given raw size and rotation (portrait lock, so rotation equals the sensor orientation), expose the upright size and the affine matrices upright-to-raw and raw-to-upright. No mirroring in data. Unit-test all four rotations.
3. `CameraService` (interface plus implementation): permission handling with a clear denied state (and permanently-denied state that opens settings), front camera selection, resolution preset chosen by the device tier profile, start and stop of the image stream, pause and resume on app lifecycle, safe disposal. Expose a Riverpod provider.
4. `FrameThrottler`: at most one frame in flight, drop the rest, adaptive skipping based on an exponential moving average of processing time, target FPS from the tier profile. Fully unit-tested with the injected `Clock`.
5. `PixelSampler` (pure Dart, in `features/ml`): bilinear sampling from NV21 and BGRA8888 buffers using an inverse affine mapping, producing an RGB `Uint8List` of a requested output size, with reusable output buffers (no allocation per frame). Required functions:
   - `warpAffine(frame, upright-to-output matrix, outW, outH)` (the single primitive used for crops, resizing, and face alignment later).
   - `toGrayscaleDownsampled(...)` for quality statistics.
   Never convert the whole frame to RGB. Out-of-range samples are padded with a configurable constant. Unit-test with synthetic frames for both formats, including stride padding and every rotation.
6. Worker isolate (`features/ml/worker`): long-lived, started once, with a typed request and response protocol (request ids, error propagation, cancellation of stale requests). Frame bytes are transferred with `TransferableTypedData`. The worker loads ONNX sessions itself (it receives model bytes or loads assets through a background-safe path; check what works with the chosen package) and exposes commands: `loadModels`, `benchmark`, `dispose`. Later steps add more commands, so design the command registry to be extensible. Handle worker crash and restart.
7. Device tier:
   - `DeviceTier { low, mid, high }` and `TierProfile` (camera preset, analysis FPS, passive frame count N: low 5, mid 8, high 12, models used, flash challenge default, SFace variant preference).
   - `DeviceBenchmark`: on first launch run a warmup plus about 10 inferences of each model through the worker, compute the median latency, classify the tier, persist the result, allow re-run and a manual override. Use `device_info_plus` data only as a secondary hint (RAM class), not as the main signal.
   - The SFace variant preference must support an optional `face_recognition_sface_2021dec_int8.onnx` file if the developer adds it later; if absent, use the float model.
8. Dev screen at route `/dev/camera` (reachable from Home only in debug builds): live preview, FPS, per-frame latency, tier, and a small thumbnail of the upright image produced by `PixelSampler` so rotation and orientation can be checked visually on a real device.

## Acceptance criteria

- `flutter analyze` and `flutter test` are clean.
- On a real Android device and a real iOS device: the preview shows, the thumbnail is upright and un-mirrored, FPS and latency update, memory stays stable for 5 minutes (no growth), and pause/resume works.
- Benchmark runs once on first launch and persists; manual override works.
- Update `prompts/PROGRESS.md`, including the exact manual checks and the measured latency per model on the test device.

## Do not

- Do not run ML Kit or any liveness logic here.
- Do not use the `image` package for per-frame work.
