/// Defines verification stringency and active challenge sequence depth.
enum SessionPolicy {
  /// Full verification pipeline with neutral calibration and active challenges.
  attendance,

  /// Liveness verification for enrollment with passive layers and one active challenge.
  enrollment,
}
