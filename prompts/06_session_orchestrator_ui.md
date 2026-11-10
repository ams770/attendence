# Step 06 - Verification Session, Timers, and Verification UI

Read `prompts/00_CONTEXT.md` and `prompts/PROGRESS.md` first. Steps 01 to 05 must be finished.

## Goal

Combine every layer into one testable session state machine driven by camera frames and timers, then build the verification screen. Recognition itself comes in step 07; here the session ends with a verified-live result and the selected face crops.

## Tasks

1. `LivenessSession` controller (pure Dart, no Flutter imports, injected `Clock`, `RandomSource`, detector, worker client, passive engine). States:
   `idle`, `positioning`, `neutral`, `challenge(index)`, `flash` (only if enabled), `finalizing`, `succeeded`, `failed(reason)`, `locked`.
   Passive collection is not a separate blocking state; it runs continuously on a schedule across `neutral`, each challenge, and `finalizing` through `PassiveScheduler`. At least some passive frames must be collected after the last challenge.
2. Session rules:
   - Total session timer (default 30 s) and per-challenge timer (default 6 s), both from `AppConfig`, both exposed as streams of remaining time for the UI.
   - Every frame first passes the quality gate. While quality fails, the session stays in `positioning` or pauses the current step without consuming the challenge timer more than the config allows, and shows guidance.
   - All layers must pass: quality, passive aggregate verdict and continuous monitor, challenges, temporal confidence, flash (if enabled).
   - Same tracking id for the whole session (reuse the step 05 rules).
   - On timeout, face loss, challenge failure, or liveness failure: stop and report a typed failure reason; the UI offers retry.
   - After 3 consecutive failures, lock the attempt screen for 60 s (both values from config). The lock end time must be persisted so restarting the app does not bypass it, and it uses the injected clock in tests.
3. Session policy: `SessionPolicy.attendance` (full pipeline) and `SessionPolicy.enrollment` (passive layers plus one active challenge; the enrollment flow in step 07 reuses one session for several samples).
4. Finalizing and binding:
   - After liveness passes, the session collects candidate frames only while the same tracking id is present and the pose is near frontal.
   - For each candidate, the worker returns the 112x112 aligned crop and its sharpness. Keep the 3 sharpest crops. Recognition may only use crops produced by a succeeded session; make this impossible to bypass through the types (for example, `VerifiedLiveFaces` can only be constructed by the session).
5. `LiveSessionResult`: passed flag, failure reason, mean passive score, frames above threshold, per-model scores, challenge results, temporal confidence, flash result, tracking id, device tier, and the `VerifiedLiveFaces`. Add an `AttemptLog` entry (without images or embeddings) for the debug screen and evaluation export (step 08 shows it).
6. Frame pipeline wiring (Riverpod): camera stream, throttler, ML Kit detection, then `session.onFrame(frame, face)`; worker requests are issued without blocking the frame loop and stale results are discarded safely. Exactly one frame in flight at any time.
7. `VerificationScreen`:
   - Front camera preview (mirrored for display only), oval guide with a circular progress ring for the total timer plus the remaining seconds as text, a per-challenge timer, large clear instruction text per state, real-time guidance messages from the quality gate, and state-dependent oval color. No emojis.
   - Cancel button, retry on failure, lock screen with a countdown.
   - Flash overlay when that challenge is active.
   - Handles pause and resume, camera permission denial, and a back button during a session (cancels cleanly and releases the camera).
8. `ResultScreen` for this step shows the pass or fail outcome with a localized reason. Recognition and attendance result details are added in steps 07 and 08.
9. Tests with fakes for the clock, random source, detector, and worker:
   - Success path.
   - Total timeout, challenge timeout.
   - Face lost beyond grace, tracking id change.
   - Passive failure after the last challenge (simulated photo swap).
   - Single good passive frame does not pass.
   - Three failures cause a lock, lock persists across a simulated restart, and expires correctly.
   - `VerifiedLiveFaces` cannot be created outside the session.

## Acceptance criteria

- `flutter analyze` and `flutter test` are clean.
- On real devices (one weak, one strong if available) a live person completes the flow end to end in a reasonable time. A photo on another phone and a replayed video are rejected. Record the observed pass and fail results honestly in `PROGRESS.md`, including false rejects of the real user.

## Do not

- Do not run recognition on any face that did not pass the session.
- Do not hardcode durations or thresholds in the UI.
