# Step 07 - Recognition, Encrypted Storage, Enrollment, Identification

Read `prompts/00_CONTEXT.md` and `prompts/PROGRESS.md` first. Steps 01 to 06 must be finished.

## Goal

Add face embeddings with SFace, encrypted storage, employee enrollment with 5 samples, and 1:N identification with threshold and margin logic.

## Tasks

1. `FaceRecognizer` interface and the SFace ONNX implementation (worker command `embed`):
   - Input is the 112x112 aligned RGB crop from `VerifiedLiveFaces` only.
   - Preprocessing is a `RecognizerPreprocessConfig` (channel order, scale, mean, std). Default per `00_CONTEXT.md`: RGB, raw 0 to 255, mean 0, std 1. Read the input size and the output dimension from the model, never hardcode 112 or 128 in the inference code.
   - L2-normalize the output. Average the embeddings of the 3 selected crops and normalize again.
   - Support an optional int8 SFace file by tier if present (see step 02).
2. `tools/verify_recognition.py`: Python script using onnxruntime and OpenCV that computes embeddings for folders of images (aligned or alignable) and prints cosine similarities for same-person and different-person pairs, so the developer can check that the app's preprocessing matches. Include usage notes at the top and in `docs/MODELS.md`.
3. Storage with Drift:
   - Tables: `employees` (id, employee code, name, active flag, created at), `embeddings` (id, employee id, ciphertext, nonce, mac, model id, dimension, created at), `attendance_records` (created in step 08, define the schema now so migrations are clean), `attempt_logs` (for step 08 evaluation export).
   - Encrypt every embedding with AES-GCM (256-bit) using the `cryptography` package. Generate the key once with the secure random source and keep it in `flutter_secure_storage` (Keystore on Android, Keychain on iOS). Store the model id and dimension with each embedding; if the recognizer model or dimension changes, flag affected employees as needing re-enrollment instead of silently comparing incompatible vectors.
   - Never store face photos in this step. Never log embeddings.
   - Repository interfaces in the domain layer, Drift implementations in the data layer, and in-memory fakes for tests.
4. `FaceMatcher`:
   - Cosine similarity of normalized vectors.
   - For each employee, the score is the maximum similarity across that employee's stored embeddings.
   - Accept only if the best score is at least the threshold AND the best employee's score exceeds the second-best employee's score by at least the margin. Return a typed result: `matched(employee, rawScore, margin)`, `ambiguous`, `noMatch`, or `noEnrolledEmployees`.
   - The accept or reject decision uses the raw cosine score only. The displayed "match percent" is a calibrated sigmoid around the threshold used for display only; add a code comment explaining that it is not a probability.
   - Threshold and margin come from `AppConfig`. The threshold default is a placeholder and the UI and docs must state it has to be calibrated on real employees.
   - Cache decrypted embeddings in memory only for the duration of an identification, or use a small time-limited cache that is cleared on app pause.
5. Enrollment flow (admin area, protected by the PIN added in step 08; for now guard the route with a simple provider that step 08 completes):
   - Form: employee name and code with validation and duplicate-code detection.
   - Capture 5 samples at slightly different poses (front, slight left, slight right, slight up, slight down), each must pass the quality gate. The enrollment session policy requires the passive layers continuously plus one active challenge for the whole enrollment, with the same tracking id binding for all samples of that enrollment run. Show per-sample progress and guidance.
   - Duplicate face check: before saving, compare the new embeddings against existing employees. If they match another employee above the threshold, warn and block unless the admin confirms.
   - Save the 5 embeddings, not the images.
6. Employees screen: list, edit name and code, deactivate, delete (with confirmation, removing embeddings), re-enroll.
7. Identification flow: after a succeeded `LivenessSession` in attendance mode, compute the embedding from the bound crops and run the matcher. Provide the outcome to the attendance layer (step 08).
8. Tests: cosine similarity, matcher threshold and margin edge cases (exactly at threshold, tied top two, single employee, empty database), crypto round trip, tamper detection (modified ciphertext must fail), model-id mismatch handling, repository behavior with the fake and with an in-memory Drift database, enrollment sample validation logic.

## Acceptance criteria

- `flutter analyze` and `flutter test` are clean.
- On a real device: enroll two people, then verify each. Record in `PROGRESS.md` the observed same-person and different-person cosine scores (even if rough) and whether the placeholder threshold looks reasonable.
- Inspecting the database file shows no readable embeddings.

## Do not

- Do not store images or log biometric values.
- Do not compare vectors from different models or dimensions.
