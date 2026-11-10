/// The 5 structured head poses captured during biometric enrollment.
enum EnrollmentPose {
  /// Looking straight at the camera.
  front,

  /// Head turned slightly to the subject's left (~15 degrees).
  slightLeft,

  /// Head turned slightly to the subject's right (~15 degrees).
  slightRight,

  /// Head tilted slightly upward (~12 degrees).
  slightUp,

  /// Head tilted slightly downward (~12 degrees).
  slightDown;

  /// Ordered list of poses captured sequentially during enrollment.
  static const List<EnrollmentPose> ordered = <EnrollmentPose>[
    EnrollmentPose.front,
    EnrollmentPose.slightLeft,
    EnrollmentPose.slightRight,
    EnrollmentPose.slightUp,
    EnrollmentPose.slightDown,
  ];
}
