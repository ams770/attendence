# Step 05 - Active Challenges, Temporal Checks, Optional Flash

Read `prompts/00_CONTEXT.md` and `prompts/PROGRESS.md` first. Steps 01 to 04 must be finished. Use the yaw sign convention recorded in `PROGRESS.md` from step 03.

## Goal

Implement the active random challenge state machine, the temporal and motion consistency signals, and the optional screen-color-flash challenge. All of this is pure Dart logic with injected `Clock` and `RandomSource`, fully unit-tested, independent of Flutter widgets.

## Tasks

1. Challenge selection: pick 2 different challenges per session from `blink`, `turnLeft`, `turnRight`, `smile` using the secure `RandomSource`. A neutral "look straight" step always comes first.
2. `ChallengeStateMachine`, strict and event driven by `DetectedFace` samples with timestamps:
   - Neutral step: yaw within +/- 10 degrees, pitch within +/- 12, eyes open, not smiling, for a minimum number of consecutive frames. This step also establishes the baseline yaw.
   - Blink: must observe open, then closed, then open (with hysteresis thresholds, for example open above 0.6 and closed below 0.25). "Eyes closed" alone never passes. The minimum consecutive closed frames must be configurable and tier aware, because at low analysis FPS a blink can be visible in only one frame.
   - Turn left or right: start from near-zero yaw, cross the configured threshold (default 20 degrees) in the requested direction using the verified sign convention (a config value `yawSignForUserLeft`), hold for a minimum number of frames. A turn in the wrong direction does not pass and does not count as progress.
   - Smile: start from not smiling (below 0.3), then reach above 0.8 for the minimum number of frames.
   - Per-challenge timeout (default 6 s) and the overall session timeout are enforced by the orchestrator in step 06; the state machine exposes `elapsed` and a `timedOut` check against the injected clock.
   - Tracking id continuity: the id must stay the same for the whole session. If the face is lost longer than the grace period (default 700 ms) or the id changes, return a `failed(trackingLost)` or `failed(trackingChanged)` result.
   - Outputs: current state, progress, result per challenge with timestamps, failure reason enum.
3. `TemporalAnalyzer` (configurable weighted signals, each returning a value from 0 to 1, combined into a confidence that can fail the session below a configurable threshold):
   - Micro-motion: normalized landmark positions (relative to face box size) must show non-zero natural variance over time, and not be perfectly frozen.
   - Loop detection: detect near-identical repeating landmark sequences (a replayed short video) using a simple autocorrelation or sequence-distance method.
   - Planar rigidity: during a head turn, fit the best 2D affine transform between landmark sets from the neutral frame to the turned frame and measure the residual. A flat photo rotated in front of the camera tends to have a small residual; a real 3D face rotating tends to show parallax (nose relative to eyes and mouth) and a larger residual.
   - Document every signal's limits honestly in comments and in `docs/LIMITATIONS.md` (for example, a close-up wide-angle effect, a very small yaw, or a cleverly moved photo can fool it). These are supporting signals, not proof.
4. `FlashChallenge` (feature flag in config, default on only for the high tier):
   - A random sequence of 3 to 4 colors from red, green, blue, white, with a fixed dwell time, shown as a full-screen overlay while frames are captured.
   - Worker command `skinColorSample` returns the mean color of a fixed skin region derived from the landmarks (cheeks and forehead patches, never eyes or mouth) per frame.
   - Lock exposure and white balance during the flash if the camera plugin supports it, to stop auto-compensation from erasing the signal.
   - Compute the correlation between the displayed color sequence and the measured chrominance change. Hard fail only if the correlation is clearly absent (configurable) in a sufficiently lit environment; otherwise lower the confidence. Skip with a recorded reason if ambient light is too high or too low for the test to be meaningful.
   - Document that it depends on ambient light and can be disabled in Settings.
5. Unit tests, all deterministic:
   - Blink: closed-only fails, open-closed-open passes, noisy flicker around the threshold does not pass, single-frame blink at low FPS passes when the tier setting allows it.
   - Turn: starting at an already-turned yaw fails, wrong direction fails, correct direction passes, jitter handled by hysteresis.
   - Smile and neutral edge cases.
   - Tracking loss within the grace period passes, beyond it fails, id change fails.
   - Challenge selection never repeats a challenge in one session and uses the injected random source.
   - Temporal analyzer on synthetic sequences: frozen, looped, natural, rigid planar rotation, 3D-like rotation.
   - Flash correlation on synthetic signals: correlated, uncorrelated, saturated.

## Acceptance criteria

- `flutter analyze` and `flutter test` are clean, and the pure-logic classes have no Flutter imports.
- Add a temporary dev screen `/dev/challenges` that runs a random challenge sequence and shows the machine state live, so each challenge can be tried on a real device on both platforms.
- Record observed behavior and any threshold tuning in `PROGRESS.md`.

## Do not

- Do not wire the final session flow or timers here (step 06).
- Do not treat the temporal signals or the flash result as proof of liveness; they are weighted evidence.
