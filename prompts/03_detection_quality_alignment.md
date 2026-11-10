# Step 03 - Face Detection, Quality Gate, Alignment

Read `prompts/00_CONTEXT.md` and `prompts/PROGRESS.md` first. Steps 01 and 02 must be finished.

## Goal

Detect the face with ML Kit, convert results into a clean domain model, gate frames by quality, and implement the 5-point alignment to the 112x112 template with a manually written similarity transform.

## Tasks

1. `FaceDetector` interface and `MlKitFaceDetector` implementation (accurate mode, landmarks on, classification on, tracking on, contours off, a sensible minimum face size). Build the `InputImage` from `FrameData` correctly per platform (nv21 bytes on Android, bgra8888 on iOS) with the right rotation metadata for the portrait lock. ML Kit runs on the main isolate.
2. `DetectedFace` domain model in upright image coordinates: tracking id, bounding box, yaw, pitch, roll, left and right eye open probabilities, smiling probability, and the five landmarks (two eyes, nose base, two mouth corners) with a flag for missing landmarks. Reject faces with missing landmarks for recognition purposes.
3. Multiple faces: the pipeline accepts exactly one face. If more than one is present, report `multipleFaces` and do not pick one silently.
4. `PreviewMapper`: map upright image coordinates to preview widget coordinates, handling `BoxFit.cover` scaling, cropping, and front-camera mirroring for display. Unit-test it.
5. Oval guide: a `CustomPainter` oval and a function that tests whether the face box is fully inside the oval region in preview coordinates.
6. `QualityGate`, driven by `AppConfig`, returning a `QualityResult` with a list of issues (enum): `noFace`, `multipleFaces`, `tooSmall`, `notInsideGuide`, `poseOutOfRange`, `tooBlurry`, `tooDark`, `tooBright`, `glare`, `landmarksMissing`. Face width must be at least 25 percent of the preview width. Sharpness (Laplacian variance), mean brightness, and the near-saturated pixel ratio are computed in the worker isolate on a small grayscale crop of the face (add a `faceStats` worker command that uses `PixelSampler`). Each issue maps to a localized guidance string (move closer, more light, hold still, remove glare, look straight, only one person).
7. `FaceAligner`:
   - Sort the landmarks so left and right are by image x position (do not trust the ML Kit left/right naming under mirroring).
   - Implement the Umeyama least-squares similarity transform (scale, rotation, translation) from the five detected points to the template in `00_CONTEXT.md`. No external math package for the core transform.
   - Return the 2x3 matrix, and a worker command `alignedCrop` that uses `PixelSampler.warpAffine` to produce the 112x112 RGB crop directly from the raw frame buffer.
   - Unit tests against known point sets: identity, pure scale, pure rotation, pure translation, combined, and noisy points; also assert the reflection case is rejected or handled.
8. Dev screen update (`/dev/detection`): live preview with oval, bounding box, landmarks, yaw, pitch, roll, eye and smile probabilities, tracking id, quality issues as text, and a thumbnail of the aligned 112x112 crop.

## Acceptance criteria

- `flutter analyze` and `flutter test` are clean.
- On a real device: landmarks overlay lines up with the face on both platforms, the aligned thumbnail shows an upright, centered, un-mirrored face, and the quality gate reacts correctly to covering the camera, dim light, and moving fast.
- Record in `prompts/PROGRESS.md` the measured sign convention of yaw (which physical head turn gives a positive `headEulerAngleY`) for front camera on each platform tested; later steps need it.

## Do not

- Do not implement challenges or liveness models here.
- Do not mirror frame data.
