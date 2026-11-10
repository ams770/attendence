// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Attendance';

  @override
  String get selfCheckInProgress =>
      'Checking AI models and system resources...';

  @override
  String get selfCheckPassed =>
      'All models initialized and verified successfully.';

  @override
  String get selfCheckFailedTitle => 'Startup Check Failed';

  @override
  String get selfCheckFailedDescription =>
      'The application cannot start because one or more AI models failed initialization.';

  @override
  String get failedModelsHeader => 'Failed Models';

  @override
  String get verifiedModelsHeader => 'Verified Models';

  @override
  String get modelNameLabel => 'Model';

  @override
  String get expectedPathLabel => 'Path';

  @override
  String get reasonLabel => 'Reason';

  @override
  String get statusLabel => 'Status';

  @override
  String get statusPassed => 'Passed';

  @override
  String get statusFailed => 'Failed';

  @override
  String get retryButton => 'Retry';

  @override
  String get homeStatusReady => 'System is ready for attendance.';

  @override
  String get homeDevCameraAction => 'Camera & Pipeline Dev Screen';

  @override
  String get devCameraTitle => 'Camera & Pipeline Dev';

  @override
  String get devCameraPermissionRequired =>
      'Camera permission is required to stream and verify frames.';

  @override
  String get devCameraGrantPermission => 'Grant Permission';

  @override
  String get devCameraOpenSettings => 'Open Settings';

  @override
  String get devCameraFpsLabel => 'FPS';

  @override
  String get devCameraLatencyLabel => 'Latency';

  @override
  String get devCameraTierLabel => 'Tier';

  @override
  String get devCameraDroppedFrames => 'Dropped';

  @override
  String get devCameraProcessedFrames => 'Processed';

  @override
  String get devCameraThumbnailTitle =>
      'PixelSampler Upright RGB (Un-mirrored)';

  @override
  String get devCameraTierOverrideLabel => 'Hardware Tier Override';

  @override
  String get devCameraRerunBenchmark => 'Re-run Benchmark';

  @override
  String get devCameraBenchmarking => 'Benchmarking...';

  @override
  String get devCameraTierAuto => 'Automatic (Benchmarked)';

  @override
  String get devCameraTierLow => 'Low Tier';

  @override
  String get devCameraTierMid => 'Mid Tier';

  @override
  String get devCameraTierHigh => 'High Tier';

  @override
  String get homeDevDetectionAction => 'Face Detection & Alignment Dev Screen';

  @override
  String get devDetectionTitle => 'Detection & Alignment Dev';

  @override
  String get devDetectionTrackingId => 'Tracking ID';

  @override
  String get devDetectionEulerAngles => 'Pose (Yaw / Pitch / Roll)';

  @override
  String get devDetectionEyeOpen => 'Eyes Open (L / R)';

  @override
  String get devDetectionSmiling => 'Smiling';

  @override
  String get devDetectionQualityIssues => 'Quality Status';

  @override
  String get devDetectionQualityPass => 'Quality Passed';

  @override
  String get devDetectionAlignedThumbnail => 'Aligned 112x112 Face Crop';

  @override
  String get devDetectionFaceStats => 'Sharpness / Brightness / Glare';

  @override
  String get qualityIssueNoFace => 'No face detected';

  @override
  String get qualityIssueMultipleFaces => 'Only one person allowed';

  @override
  String get qualityIssueTooSmall => 'Move closer';

  @override
  String get qualityIssueNotInsideGuide => 'Position face inside oval';

  @override
  String get qualityIssuePoseOutOfRange => 'Look straight at camera';

  @override
  String get qualityIssueLandmarksMissing => 'Ensure face is clearly visible';

  @override
  String get qualityIssueTooBlurry => 'Hold still';

  @override
  String get qualityIssueTooDark => 'Move to a brighter area';

  @override
  String get qualityIssueTooBright => 'Reduce lighting';

  @override
  String get qualityIssueGlare => 'Remove glare from face';

  @override
  String get homeDevPassiveAction => 'Passive Liveness Dev Screen';

  @override
  String get devPassiveTitle => 'Passive Liveness Dev';

  @override
  String get devPassiveModelV2Label => 'MiniFASNetV2';

  @override
  String get devPassiveModelV1SeLabel => 'MiniFASNetV1SE';

  @override
  String get devPassiveMeanScore => 'Mean Score';

  @override
  String get devPassiveVerdict => 'Aggregated Verdict';

  @override
  String get devPassiveVerdictPending => 'Pending';

  @override
  String get devPassiveVerdictPassed => 'Passed (Real)';

  @override
  String get devPassiveVerdictFailed => 'Failed (Spoof)';

  @override
  String get devPassiveSamplesCount => 'Samples';

  @override
  String get devPassivePassingRatio => 'Passing Ratio';

  @override
  String get devPassiveExportCsv => 'Export CSV';

  @override
  String get devPassiveResetSession => 'Reset Session';

  @override
  String get devPassiveStartSession => 'Start Session';

  @override
  String get devPassiveStopSession => 'Stop Session';

  @override
  String get devPassiveModelsToRun => 'Models to Run';

  @override
  String get devPassiveModelOptionBoth => 'Both V2 & V1SE';

  @override
  String get devPassiveModelOptionV2Only => 'V2 Only (Low Tier)';

  @override
  String get devPassiveModelOptionV1SeOnly => 'V1SE Only';

  @override
  String get devPassiveCsvExportEmpty => 'No samples recorded to export.';

  @override
  String get devPassiveCsvExportSuccess => 'CSV exported successfully.';

  @override
  String get homeDevChallengesAction => 'Active Challenges Dev Screen';

  @override
  String get challengesDevTitle => 'Active Challenges & Temporal';

  @override
  String get challengeLookStraight => 'Look straight at the camera';

  @override
  String get challengeBlink => 'Blink your eyes';

  @override
  String get challengeTurnLeft => 'Turn your head left';

  @override
  String get challengeTurnRight => 'Turn your head right';

  @override
  String get challengeSmile => 'Smile';

  @override
  String get challengeStatusPending => 'Pending';

  @override
  String get challengeStatusPassed => 'Passed';

  @override
  String get challengeStatusFailed => 'Failed';

  @override
  String get challengeReasonTimeout => 'Challenge timed out';

  @override
  String get challengeReasonTrackingLost => 'Face lost';

  @override
  String get challengeReasonTrackingChanged => 'Face changed';

  @override
  String get challengeReasonWrongDirection => 'Turned in wrong direction';

  @override
  String get newChallengesAction => 'New Random Challenges';

  @override
  String get resetChallengeAction => 'Reset';

  @override
  String get temporalMicroMotion => 'Micro-motion';

  @override
  String get temporalLoopDetection => 'Loop Detection';

  @override
  String get temporalPlanarRigidity => '3D Rigidity';

  @override
  String get temporalConfidence => 'Temporal Confidence';

  @override
  String get flashChallengeAction => 'Test Flash Challenge';

  @override
  String get flashStatus => 'Flash Reflection';

  @override
  String get flashVerdictPassed => 'Flash Passed';

  @override
  String get flashVerdictFailed => 'Flash Failed';

  @override
  String get flashVerdictInconclusive => 'Inconclusive';

  @override
  String get flashVerdictSkipped => 'Skipped (Lighting)';

  @override
  String get startVerification => 'Start Attendance Verification';

  @override
  String get verificationTitle => 'Face Verification';

  @override
  String get statePositioning => 'Position your face inside the oval';

  @override
  String get stateNeutral => 'Look straight at the camera';

  @override
  String get stateFinalizing => 'Verifying liveness... Please hold still';

  @override
  String get stateSucceeded => 'Verification Succeeded';

  @override
  String get stateFailed => 'Verification Failed';

  @override
  String get stateLocked => 'Verification Locked';

  @override
  String lockoutCountdown(int seconds) {
    return 'Locked out due to repeated failures. Try again in $seconds seconds.';
  }

  @override
  String totalTimeRemaining(int seconds) {
    return '${seconds}s remaining';
  }

  @override
  String get reasonTimeout => 'Session timed out';

  @override
  String get reasonFaceLost => 'Face tracking lost';

  @override
  String get reasonTrackingChanged => 'Different face detected';

  @override
  String get reasonChallengeFailed => 'Active challenge failed';

  @override
  String get reasonPassiveFailed => 'Passive liveness check failed';

  @override
  String get reasonPassiveHardFloorViolation =>
      'Security violation: potential photo substitute detected';

  @override
  String get reasonTemporalFailed => 'Natural facial motion check failed';

  @override
  String get reasonFlashFailed => 'Screen flash reflection test failed';

  @override
  String get reasonCancelled => 'Session cancelled';

  @override
  String get reasonTooManyAttempts => 'Too many consecutive failed attempts';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionRetry => 'Try Again';

  @override
  String get actionDone => 'Done';

  @override
  String get resultTitle => 'Verification Result';

  @override
  String get resultPassedTitle => 'Liveness Verified';

  @override
  String get resultFailedTitle => 'Verification Failed';

  @override
  String resultDuration(int duration) {
    return 'Duration: $duration ms';
  }

  @override
  String resultPassiveScore(String score) {
    return 'Mean Passive Score: $score';
  }

  @override
  String resultTemporalScore(String score) {
    return 'Temporal Confidence: $score';
  }

  @override
  String resultChallengesCompleted(int count) {
    return 'Completed Challenges: $count';
  }

  @override
  String resultCropsCount(int count) {
    return 'Aligned Crops Captured: $count';
  }

  @override
  String get employeesTitle => 'Employees';

  @override
  String get enrollEmployee => 'Enroll Employee';

  @override
  String get reEnrollEmployee => 'Re-enroll Face';

  @override
  String get employeeName => 'Employee Name';

  @override
  String get employeeCode => 'Employee Code';

  @override
  String get employeeNameHint => 'e.g. John Doe';

  @override
  String get employeeCodeHint => 'e.g. EMP-101';

  @override
  String get employeeCodeExists => 'Employee code already exists';

  @override
  String get employeeNameRequired => 'Employee name is required';

  @override
  String get employeeCodeRequired => 'Employee code is required';

  @override
  String get noEmployeesFound => 'No employees registered yet.';

  @override
  String get searchEmployees => 'Search employees by name or code';

  @override
  String get deleteEmployeeTitle => 'Delete Employee';

  @override
  String deleteEmployeeConfirm(String name) {
    return 'Are you sure you want to delete $name? All associated biometric data will be permanently removed.';
  }

  @override
  String get deleteAction => 'Delete';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get saveAction => 'Save';

  @override
  String get editEmployee => 'Edit Employee';

  @override
  String get statusActive => 'Active';

  @override
  String get statusInactive => 'Inactive';

  @override
  String get needsReEnrollmentBadge => 'Needs Re-enrollment';

  @override
  String get enrollmentTitle => 'Employee Enrollment';

  @override
  String get enrollmentFormHeader => 'Employee Information';

  @override
  String get enrollmentStartCapture => 'Start Face Capture';

  @override
  String enrollmentSampleCount(int current, int total) {
    return 'Sample $current of $total';
  }

  @override
  String get poseFront => 'Look straight at the camera';

  @override
  String get poseSlightLeft => 'Turn your head slightly left';

  @override
  String get poseSlightRight => 'Turn your head slightly right';

  @override
  String get poseSlightUp => 'Tilt your head slightly up';

  @override
  String get poseSlightDown => 'Tilt your head slightly down';

  @override
  String get enrollmentProcessing =>
      'Processing and encrypting biometric templates...';

  @override
  String get duplicateWarningTitle => 'Duplicate Face Warning';

  @override
  String duplicateWarningMessage(String name, String code, String score) {
    return 'This face closely matches active employee $name ($code) with similarity $score. Do you want to proceed with enrollment anyway?';
  }

  @override
  String get confirmEnrollmentAction => 'Proceed Anyway';

  @override
  String get enrollmentSuccess => 'Employee enrolled successfully';

  @override
  String get identificationTitle => 'Employee Identification';

  @override
  String get identifiedEmployee => 'Identified Employee';

  @override
  String matchScore(String percent, String score) {
    return 'Match: $percent% (Cosine: $score)';
  }

  @override
  String get noMatchFound => 'Face Not Recognized';

  @override
  String get noMatchDescription =>
      'No enrolled employee matched this face above the recognition threshold.';

  @override
  String get ambiguousMatch => 'Recognition Ambiguous';

  @override
  String ambiguousDescription(String name1, String name2) {
    return 'Similarity was too close between $name1 and $name2. Please retry verification.';
  }

  @override
  String get noEnrolledEmployees => 'No Enrolled Employees';

  @override
  String get noEnrolledDescription =>
      'Please enroll employees before verifying attendance.';

  @override
  String get homeEmployeesAction => 'Employees & Enrollment';
}
