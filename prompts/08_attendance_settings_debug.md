# Step 08 - Attendance, Records, Settings, Admin PIN, Debug, Localization

Read `prompts/00_CONTEXT.md` and `prompts/PROGRESS.md` first. Steps 01 to 07 must be finished.

## Goal

Turn verified identification into attendance records and finish all user-facing screens: Home, Result, Records, Settings, Admin PIN, Debug, and a complete Arabic and English localization pass.

## Tasks

1. Attendance logic (`features/attendance/domain`, pure Dart and tested):
   - Automatic type: toggle between check-in and check-out based on the employee's last record of the same local day (first record of the day is check-in). Manual override of the type before or after verification.
   - Cooldown: reject a duplicate record for the same employee within the configured cooldown (default 60 s) with a clear localized message.
   - Record fields: id, employee id, timestamp, type, passive liveness score, match score (raw cosine), device tier, app version, and an optional encrypted snapshot.
   - Snapshot setting (off by default): when enabled, store the aligned face crop as a compressed image encrypted with the same AES-GCM key management; document the privacy implication in the settings description.
   - Handle midnight rollover and timezone changes correctly (use the injected clock and store UTC with local-day computation at read time).
2. Home screen: primary action starting verification with automatic type, a switch or segmented control for manual Check In / Check Out override, and the last records list. Clean Material 3 layout, no emojis.
3. Result screen: employee name, record type, time, and the display match percent; failure outcomes with localized reasons and a retry action. Raw scores appear only when the debug flag is on.
4. Records screen: filter by employee and by date range, list with pagination, and CSV export through `share_plus`. CSV must escape quotes and commas correctly and neutralize spreadsheet formula injection (prefix cells starting with `=`, `+`, `-`, `@` safely). Unit-test the CSV builder.
5. Admin PIN: first-run setup, store only a salted hash with a slow KDF (for example PBKDF2) in secure storage, attempt limit with temporary lockout, change PIN. The PIN guards Employees, Enrollment, Settings, and Records export. Mention in the UI and docs that this is a convenience barrier on an offline device, not strong security.
6. Settings screen (admin only): recognition threshold and margin (with a visible warning that the values must be calibrated on real employees), passive threshold, session and challenge timers, lockout parameters, cooldown, tier display with manual override and re-run benchmark, feature flags (flash challenge, snapshot storage, root detection, debug), language selection (Arabic, English, system), and reset to defaults. Persist overrides through the `AppConfig` repository from step 01 and make sure running sessions read a consistent snapshot of the config.
7. Debug screen (feature flag): live passive score per model, per-frame latency, current tier, FPS, tracking id, challenge state, temporal signals, and an attempt log list. Export per-attempt scores (no images, no embeddings) to CSV for the evaluation protocol: attempt id, timestamp, device model, tier, scenario label chosen by the tester (genuine, printed photo, phone screen photo, tablet screen photo, monitor photo, phone video, tablet video, mask), passive scores, frame ratio, challenge outcomes, temporal confidence, flash result, final decision, and recognition raw score. Add a scenario label picker that appears only when the debug flag is on.
8. Localization sweep: every user-visible string in both ARB files, plurals and placeholders correct, RTL layout verified on every screen (icons that imply direction are mirrored, numbers and times format correctly in Arabic), no hardcoded strings left. Add a test that fails if the two ARB files have different key sets.
9. Tests: toggle logic including day boundaries, cooldown, manual override, CSV builder, PIN hashing and lockout, ARB key parity, settings persistence.

## Acceptance criteria

- `flutter analyze` and `flutter test` are clean.
- A complete flow works on a real device: set PIN, enroll an employee, check in, check out, view records, export CSV, switch language and confirm RTL.
- Update `PROGRESS.md` with the manual checks and results.

## Do not

- Do not keep any screen that depends on `/dev/*` routes in release builds; hide them behind debug-only checks.
- Do not store the PIN in clear text anywhere.
