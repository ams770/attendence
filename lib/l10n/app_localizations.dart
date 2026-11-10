import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get appTitle;

  /// Message shown while startup model self check is running
  ///
  /// In en, this message translates to:
  /// **'Checking AI models and system resources...'**
  String get selfCheckInProgress;

  /// Message shown when all models are verified
  ///
  /// In en, this message translates to:
  /// **'All models initialized and verified successfully.'**
  String get selfCheckPassed;

  /// Title on error screen when self check fails
  ///
  /// In en, this message translates to:
  /// **'Startup Check Failed'**
  String get selfCheckFailedTitle;

  /// Description on error screen when self check fails
  ///
  /// In en, this message translates to:
  /// **'The application cannot start because one or more AI models failed initialization.'**
  String get selfCheckFailedDescription;

  /// Header for failed models list
  ///
  /// In en, this message translates to:
  /// **'Failed Models'**
  String get failedModelsHeader;

  /// Header for verified models list
  ///
  /// In en, this message translates to:
  /// **'Verified Models'**
  String get verifiedModelsHeader;

  /// Label for model name
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get modelNameLabel;

  /// Label for model file path
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get expectedPathLabel;

  /// Label for error reason
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reasonLabel;

  /// Label for status
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// Status text for passed check
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get statusPassed;

  /// Status text for failed check
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// Status text on home screen when system is ready
  ///
  /// In en, this message translates to:
  /// **'System is ready for attendance.'**
  String get homeStatusReady;

  /// Button to open camera developer test screen
  ///
  /// In en, this message translates to:
  /// **'Camera & Pipeline Dev Screen'**
  String get homeDevCameraAction;

  /// Title for camera development screen
  ///
  /// In en, this message translates to:
  /// **'Camera & Pipeline Dev'**
  String get devCameraTitle;

  /// Message shown when camera permission is not granted
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required to stream and verify frames.'**
  String get devCameraPermissionRequired;

  /// Button to request camera permission
  ///
  /// In en, this message translates to:
  /// **'Grant Permission'**
  String get devCameraGrantPermission;

  /// Button to open app settings when permission is permanently denied
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get devCameraOpenSettings;

  /// Label for FPS meter
  ///
  /// In en, this message translates to:
  /// **'FPS'**
  String get devCameraFpsLabel;

  /// Label for latency meter
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get devCameraLatencyLabel;

  /// Label for hardware tier badge
  ///
  /// In en, this message translates to:
  /// **'Tier'**
  String get devCameraTierLabel;

  /// Label for dropped frames count
  ///
  /// In en, this message translates to:
  /// **'Dropped'**
  String get devCameraDroppedFrames;

  /// Label for processed frames count
  ///
  /// In en, this message translates to:
  /// **'Processed'**
  String get devCameraProcessedFrames;

  /// Title above the upright pixel sampler thumbnail
  ///
  /// In en, this message translates to:
  /// **'PixelSampler Upright RGB (Un-mirrored)'**
  String get devCameraThumbnailTitle;

  /// Label for tier override dropdown
  ///
  /// In en, this message translates to:
  /// **'Hardware Tier Override'**
  String get devCameraTierOverrideLabel;

  /// Button to re-run inference latency benchmark
  ///
  /// In en, this message translates to:
  /// **'Re-run Benchmark'**
  String get devCameraRerunBenchmark;

  /// Status text while benchmark is executing
  ///
  /// In en, this message translates to:
  /// **'Benchmarking...'**
  String get devCameraBenchmarking;

  /// Automatic tier selection
  ///
  /// In en, this message translates to:
  /// **'Automatic (Benchmarked)'**
  String get devCameraTierAuto;

  /// Low tier label
  ///
  /// In en, this message translates to:
  /// **'Low Tier'**
  String get devCameraTierLow;

  /// Mid tier label
  ///
  /// In en, this message translates to:
  /// **'Mid Tier'**
  String get devCameraTierMid;

  /// High tier label
  ///
  /// In en, this message translates to:
  /// **'High Tier'**
  String get devCameraTierHigh;

  /// Button to open detection and alignment dev screen
  ///
  /// In en, this message translates to:
  /// **'Face Detection & Alignment Dev Screen'**
  String get homeDevDetectionAction;

  /// Title for detection dev screen
  ///
  /// In en, this message translates to:
  /// **'Detection & Alignment Dev'**
  String get devDetectionTitle;

  /// Label for face tracking ID
  ///
  /// In en, this message translates to:
  /// **'Tracking ID'**
  String get devDetectionTrackingId;

  /// Label for head pose angles
  ///
  /// In en, this message translates to:
  /// **'Pose (Yaw / Pitch / Roll)'**
  String get devDetectionEulerAngles;

  /// Label for eye open probabilities
  ///
  /// In en, this message translates to:
  /// **'Eyes Open (L / R)'**
  String get devDetectionEyeOpen;

  /// Label for smiling probability
  ///
  /// In en, this message translates to:
  /// **'Smiling'**
  String get devDetectionSmiling;

  /// Label for quality issues status
  ///
  /// In en, this message translates to:
  /// **'Quality Status'**
  String get devDetectionQualityIssues;

  /// Text displayed when quality gate passes
  ///
  /// In en, this message translates to:
  /// **'Quality Passed'**
  String get devDetectionQualityPass;

  /// Title above aligned face thumbnail
  ///
  /// In en, this message translates to:
  /// **'Aligned 112x112 Face Crop'**
  String get devDetectionAlignedThumbnail;

  /// Label for face crop statistics
  ///
  /// In en, this message translates to:
  /// **'Sharpness / Brightness / Glare'**
  String get devDetectionFaceStats;

  /// Quality guidance when no face is in frame
  ///
  /// In en, this message translates to:
  /// **'No face detected'**
  String get qualityIssueNoFace;

  /// Quality guidance when multiple faces are detected
  ///
  /// In en, this message translates to:
  /// **'Only one person allowed'**
  String get qualityIssueMultipleFaces;

  /// Quality guidance when face is too far
  ///
  /// In en, this message translates to:
  /// **'Move closer'**
  String get qualityIssueTooSmall;

  /// Quality guidance when face is outside oval guide
  ///
  /// In en, this message translates to:
  /// **'Position face inside oval'**
  String get qualityIssueNotInsideGuide;

  /// Quality guidance when head is turned or tilted
  ///
  /// In en, this message translates to:
  /// **'Look straight at camera'**
  String get qualityIssuePoseOutOfRange;

  /// Quality guidance when facial landmarks are missing
  ///
  /// In en, this message translates to:
  /// **'Ensure face is clearly visible'**
  String get qualityIssueLandmarksMissing;

  /// Quality guidance when face image is blurry
  ///
  /// In en, this message translates to:
  /// **'Hold still'**
  String get qualityIssueTooBlurry;

  /// Quality guidance when lighting is too dim
  ///
  /// In en, this message translates to:
  /// **'Move to a brighter area'**
  String get qualityIssueTooDark;

  /// Quality guidance when lighting is too bright
  ///
  /// In en, this message translates to:
  /// **'Reduce lighting'**
  String get qualityIssueTooBright;

  /// Quality guidance when specular glare is detected on face
  ///
  /// In en, this message translates to:
  /// **'Remove glare from face'**
  String get qualityIssueGlare;

  /// Button to open passive liveness developer screen
  ///
  /// In en, this message translates to:
  /// **'Passive Liveness Dev Screen'**
  String get homeDevPassiveAction;

  /// Title for passive liveness developer screen
  ///
  /// In en, this message translates to:
  /// **'Passive Liveness Dev'**
  String get devPassiveTitle;

  /// Label for MiniFASNetV2 model
  ///
  /// In en, this message translates to:
  /// **'MiniFASNetV2'**
  String get devPassiveModelV2Label;

  /// Label for MiniFASNetV1SE model
  ///
  /// In en, this message translates to:
  /// **'MiniFASNetV1SE'**
  String get devPassiveModelV1SeLabel;

  /// Label for mean passive score
  ///
  /// In en, this message translates to:
  /// **'Mean Score'**
  String get devPassiveMeanScore;

  /// Label for aggregated verdict
  ///
  /// In en, this message translates to:
  /// **'Aggregated Verdict'**
  String get devPassiveVerdict;

  /// Verdict status when pending samples
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get devPassiveVerdictPending;

  /// Verdict status when liveness check passed
  ///
  /// In en, this message translates to:
  /// **'Passed (Real)'**
  String get devPassiveVerdictPassed;

  /// Verdict status when liveness check failed
  ///
  /// In en, this message translates to:
  /// **'Failed (Spoof)'**
  String get devPassiveVerdictFailed;

  /// Label for samples count
  ///
  /// In en, this message translates to:
  /// **'Samples'**
  String get devPassiveSamplesCount;

  /// Label for passing ratio
  ///
  /// In en, this message translates to:
  /// **'Passing Ratio'**
  String get devPassivePassingRatio;

  /// Button to export samples as CSV
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get devPassiveExportCsv;

  /// Button to reset current passive liveness session
  ///
  /// In en, this message translates to:
  /// **'Reset Session'**
  String get devPassiveResetSession;

  /// Button to start sampling session
  ///
  /// In en, this message translates to:
  /// **'Start Session'**
  String get devPassiveStartSession;

  /// Button to stop sampling session
  ///
  /// In en, this message translates to:
  /// **'Stop Session'**
  String get devPassiveStopSession;

  /// Label for model selection dropdown
  ///
  /// In en, this message translates to:
  /// **'Models to Run'**
  String get devPassiveModelsToRun;

  /// Option to run both models
  ///
  /// In en, this message translates to:
  /// **'Both V2 & V1SE'**
  String get devPassiveModelOptionBoth;

  /// Option to run V2 only
  ///
  /// In en, this message translates to:
  /// **'V2 Only (Low Tier)'**
  String get devPassiveModelOptionV2Only;

  /// Option to run V1SE only
  ///
  /// In en, this message translates to:
  /// **'V1SE Only'**
  String get devPassiveModelOptionV1SeOnly;

  /// Message when CSV export has no samples
  ///
  /// In en, this message translates to:
  /// **'No samples recorded to export.'**
  String get devPassiveCsvExportEmpty;

  /// Message when CSV export completes
  ///
  /// In en, this message translates to:
  /// **'CSV exported successfully.'**
  String get devPassiveCsvExportSuccess;

  /// Button to navigate to active challenges developer screen
  ///
  /// In en, this message translates to:
  /// **'Active Challenges Dev Screen'**
  String get homeDevChallengesAction;

  /// Title of active challenges dev screen
  ///
  /// In en, this message translates to:
  /// **'Active Challenges & Temporal'**
  String get challengesDevTitle;

  /// Instruction for neutral pose challenge
  ///
  /// In en, this message translates to:
  /// **'Look straight at the camera'**
  String get challengeLookStraight;

  /// Instruction for eye blink challenge
  ///
  /// In en, this message translates to:
  /// **'Blink your eyes'**
  String get challengeBlink;

  /// Instruction to turn head left
  ///
  /// In en, this message translates to:
  /// **'Turn your head left'**
  String get challengeTurnLeft;

  /// Instruction to turn head right
  ///
  /// In en, this message translates to:
  /// **'Turn your head right'**
  String get challengeTurnRight;

  /// Instruction to smile
  ///
  /// In en, this message translates to:
  /// **'Smile'**
  String get challengeSmile;

  /// Challenge pending state
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get challengeStatusPending;

  /// Challenge passed state
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get challengeStatusPassed;

  /// Challenge failed state
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get challengeStatusFailed;

  /// Failure reason when challenge times out
  ///
  /// In en, this message translates to:
  /// **'Challenge timed out'**
  String get challengeReasonTimeout;

  /// Failure reason when face tracking is lost
  ///
  /// In en, this message translates to:
  /// **'Face lost'**
  String get challengeReasonTrackingLost;

  /// Failure reason when face tracking ID changes
  ///
  /// In en, this message translates to:
  /// **'Face changed'**
  String get challengeReasonTrackingChanged;

  /// Failure reason when head turned in wrong direction
  ///
  /// In en, this message translates to:
  /// **'Turned in wrong direction'**
  String get challengeReasonWrongDirection;

  /// Button to generate new random active challenges
  ///
  /// In en, this message translates to:
  /// **'New Random Challenges'**
  String get newChallengesAction;

  /// Button to reset active challenge state machine
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetChallengeAction;

  /// Label for facial micro-motion score
  ///
  /// In en, this message translates to:
  /// **'Micro-motion'**
  String get temporalMicroMotion;

  /// Label for video loop detection score
  ///
  /// In en, this message translates to:
  /// **'Loop Detection'**
  String get temporalLoopDetection;

  /// Label for 3D depth parallax rigidity score
  ///
  /// In en, this message translates to:
  /// **'3D Rigidity'**
  String get temporalPlanarRigidity;

  /// Label for combined temporal confidence score
  ///
  /// In en, this message translates to:
  /// **'Temporal Confidence'**
  String get temporalConfidence;

  /// Button to trigger full-screen color flash test
  ///
  /// In en, this message translates to:
  /// **'Test Flash Challenge'**
  String get flashChallengeAction;

  /// Label for flash evaluation status
  ///
  /// In en, this message translates to:
  /// **'Flash Reflection'**
  String get flashStatus;

  /// Status text when flash correlation passes
  ///
  /// In en, this message translates to:
  /// **'Flash Passed'**
  String get flashVerdictPassed;

  /// Status text when flash correlation fails
  ///
  /// In en, this message translates to:
  /// **'Flash Failed'**
  String get flashVerdictFailed;

  /// Status text when flash correlation is inconclusive
  ///
  /// In en, this message translates to:
  /// **'Inconclusive'**
  String get flashVerdictInconclusive;

  /// Status text when flash challenge is skipped due to ambient light
  ///
  /// In en, this message translates to:
  /// **'Skipped (Lighting)'**
  String get flashVerdictSkipped;

  /// Button to launch the attendance verification flow
  ///
  /// In en, this message translates to:
  /// **'Start Attendance Verification'**
  String get startVerification;

  /// Title of the verification screen
  ///
  /// In en, this message translates to:
  /// **'Face Verification'**
  String get verificationTitle;

  /// Instruction during initial face positioning phase
  ///
  /// In en, this message translates to:
  /// **'Position your face inside the oval'**
  String get statePositioning;

  /// Instruction during neutral face calibration phase
  ///
  /// In en, this message translates to:
  /// **'Look straight at the camera'**
  String get stateNeutral;

  /// Instruction during finalizing crop collection phase
  ///
  /// In en, this message translates to:
  /// **'Verifying liveness... Please hold still'**
  String get stateFinalizing;

  /// Status text when verification succeeds
  ///
  /// In en, this message translates to:
  /// **'Verification Succeeded'**
  String get stateSucceeded;

  /// Status text when verification fails
  ///
  /// In en, this message translates to:
  /// **'Verification Failed'**
  String get stateFailed;

  /// Status text when screen is locked due to consecutive failures
  ///
  /// In en, this message translates to:
  /// **'Verification Locked'**
  String get stateLocked;

  /// Lockout message showing remaining seconds
  ///
  /// In en, this message translates to:
  /// **'Locked out due to repeated failures. Try again in {seconds} seconds.'**
  String lockoutCountdown(int seconds);

  /// Total session timer countdown text
  ///
  /// In en, this message translates to:
  /// **'{seconds}s remaining'**
  String totalTimeRemaining(int seconds);

  /// Failure reason when session or step times out
  ///
  /// In en, this message translates to:
  /// **'Session timed out'**
  String get reasonTimeout;

  /// Failure reason when face tracking is lost beyond grace period
  ///
  /// In en, this message translates to:
  /// **'Face tracking lost'**
  String get reasonFaceLost;

  /// Failure reason when tracking ID changes during active session
  ///
  /// In en, this message translates to:
  /// **'Different face detected'**
  String get reasonTrackingChanged;

  /// Failure reason when user fails active challenge
  ///
  /// In en, this message translates to:
  /// **'Active challenge failed'**
  String get reasonChallengeFailed;

  /// Failure reason when passive anti-spoofing score is below threshold
  ///
  /// In en, this message translates to:
  /// **'Passive liveness check failed'**
  String get reasonPassiveFailed;

  /// Failure reason when passive score drops below hard floor
  ///
  /// In en, this message translates to:
  /// **'Security violation: potential photo substitute detected'**
  String get reasonPassiveHardFloorViolation;

  /// Failure reason when temporal motion analysis fails
  ///
  /// In en, this message translates to:
  /// **'Natural facial motion check failed'**
  String get reasonTemporalFailed;

  /// Failure reason when flash reflection does not correlate
  ///
  /// In en, this message translates to:
  /// **'Screen flash reflection test failed'**
  String get reasonFlashFailed;

  /// Failure reason when session was cancelled
  ///
  /// In en, this message translates to:
  /// **'Session cancelled'**
  String get reasonCancelled;

  /// Failure reason when consecutive failure limit is exceeded
  ///
  /// In en, this message translates to:
  /// **'Too many consecutive failed attempts'**
  String get reasonTooManyAttempts;

  /// Button to cancel session
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Button to retry verification after failure
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get actionRetry;

  /// Button to finish or return home
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// Title of verification result screen
  ///
  /// In en, this message translates to:
  /// **'Verification Result'**
  String get resultTitle;

  /// Headline when verification passes
  ///
  /// In en, this message translates to:
  /// **'Liveness Verified'**
  String get resultPassedTitle;

  /// Headline when verification fails
  ///
  /// In en, this message translates to:
  /// **'Verification Failed'**
  String get resultFailedTitle;

  /// Session duration metric
  ///
  /// In en, this message translates to:
  /// **'Duration: {duration} ms'**
  String resultDuration(int duration);

  /// Mean passive score metric
  ///
  /// In en, this message translates to:
  /// **'Mean Passive Score: {score}'**
  String resultPassiveScore(String score);

  /// Temporal confidence metric
  ///
  /// In en, this message translates to:
  /// **'Temporal Confidence: {score}'**
  String resultTemporalScore(String score);

  /// Number of completed challenges
  ///
  /// In en, this message translates to:
  /// **'Completed Challenges: {count}'**
  String resultChallengesCompleted(int count);

  /// Number of aligned face crops captured
  ///
  /// In en, this message translates to:
  /// **'Aligned Crops Captured: {count}'**
  String resultCropsCount(int count);

  /// Title of employees management screen
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get employeesTitle;

  /// Button to enroll new employee
  ///
  /// In en, this message translates to:
  /// **'Enroll Employee'**
  String get enrollEmployee;

  /// Button to re-enroll existing employee face
  ///
  /// In en, this message translates to:
  /// **'Re-enroll Face'**
  String get reEnrollEmployee;

  /// Label for employee name
  ///
  /// In en, this message translates to:
  /// **'Employee Name'**
  String get employeeName;

  /// Label for employee code
  ///
  /// In en, this message translates to:
  /// **'Employee Code'**
  String get employeeCode;

  /// Hint for employee name
  ///
  /// In en, this message translates to:
  /// **'e.g. John Doe'**
  String get employeeNameHint;

  /// Hint for employee code
  ///
  /// In en, this message translates to:
  /// **'e.g. EMP-101'**
  String get employeeCodeHint;

  /// Validation error when code is duplicated
  ///
  /// In en, this message translates to:
  /// **'Employee code already exists'**
  String get employeeCodeExists;

  /// Validation error when name is empty
  ///
  /// In en, this message translates to:
  /// **'Employee name is required'**
  String get employeeNameRequired;

  /// Validation error when code is empty
  ///
  /// In en, this message translates to:
  /// **'Employee code is required'**
  String get employeeCodeRequired;

  /// Empty state when no employees are enrolled
  ///
  /// In en, this message translates to:
  /// **'No employees registered yet.'**
  String get noEmployeesFound;

  /// Search field hint
  ///
  /// In en, this message translates to:
  /// **'Search employees by name or code'**
  String get searchEmployees;

  /// Title for delete confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete Employee'**
  String get deleteEmployeeTitle;

  /// Confirmation message before deleting an employee
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name}? All associated biometric data will be permanently removed.'**
  String deleteEmployeeConfirm(String name);

  /// Delete button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// Save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAction;

  /// Dialog title for editing employee
  ///
  /// In en, this message translates to:
  /// **'Edit Employee'**
  String get editEmployee;

  /// Status text for active employee
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// Status text for inactive employee
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get statusInactive;

  /// Badge shown when embeddings mismatch current model
  ///
  /// In en, this message translates to:
  /// **'Needs Re-enrollment'**
  String get needsReEnrollmentBadge;

  /// Title of enrollment screen
  ///
  /// In en, this message translates to:
  /// **'Employee Enrollment'**
  String get enrollmentTitle;

  /// Header for employee form in enrollment
  ///
  /// In en, this message translates to:
  /// **'Employee Information'**
  String get enrollmentFormHeader;

  /// Button to advance from form to camera capture
  ///
  /// In en, this message translates to:
  /// **'Start Face Capture'**
  String get enrollmentStartCapture;

  /// Progress of enrollment sample captures
  ///
  /// In en, this message translates to:
  /// **'Sample {current} of {total}'**
  String enrollmentSampleCount(int current, int total);

  /// Instruction for frontal pose
  ///
  /// In en, this message translates to:
  /// **'Look straight at the camera'**
  String get poseFront;

  /// Instruction for slight left pose
  ///
  /// In en, this message translates to:
  /// **'Turn your head slightly left'**
  String get poseSlightLeft;

  /// Instruction for slight right pose
  ///
  /// In en, this message translates to:
  /// **'Turn your head slightly right'**
  String get poseSlightRight;

  /// Instruction for slight up pose
  ///
  /// In en, this message translates to:
  /// **'Tilt your head slightly up'**
  String get poseSlightUp;

  /// Instruction for slight down pose
  ///
  /// In en, this message translates to:
  /// **'Tilt your head slightly down'**
  String get poseSlightDown;

  /// Status text while processing enrollment samples
  ///
  /// In en, this message translates to:
  /// **'Processing and encrypting biometric templates...'**
  String get enrollmentProcessing;

  /// Title for duplicate face warning dialog
  ///
  /// In en, this message translates to:
  /// **'Duplicate Face Warning'**
  String get duplicateWarningTitle;

  /// Warning message when newly enrolled face matches an existing employee
  ///
  /// In en, this message translates to:
  /// **'This face closely matches active employee {name} ({code}) with similarity {score}. Do you want to proceed with enrollment anyway?'**
  String duplicateWarningMessage(String name, String code, String score);

  /// Button to confirm enrollment despite duplicate match
  ///
  /// In en, this message translates to:
  /// **'Proceed Anyway'**
  String get confirmEnrollmentAction;

  /// Success message after enrollment
  ///
  /// In en, this message translates to:
  /// **'Employee enrolled successfully'**
  String get enrollmentSuccess;

  /// Header for identification section
  ///
  /// In en, this message translates to:
  /// **'Employee Identification'**
  String get identificationTitle;

  /// Badge for successfully identified employee
  ///
  /// In en, this message translates to:
  /// **'Identified Employee'**
  String get identifiedEmployee;

  /// Display score for face match
  ///
  /// In en, this message translates to:
  /// **'Match: {percent}% (Cosine: {score})'**
  String matchScore(String percent, String score);

  /// Title when face is not recognized
  ///
  /// In en, this message translates to:
  /// **'Face Not Recognized'**
  String get noMatchFound;

  /// Description when no match is found
  ///
  /// In en, this message translates to:
  /// **'No enrolled employee matched this face above the recognition threshold.'**
  String get noMatchDescription;

  /// Title when recognition margin is too low
  ///
  /// In en, this message translates to:
  /// **'Recognition Ambiguous'**
  String get ambiguousMatch;

  /// Description for ambiguous match
  ///
  /// In en, this message translates to:
  /// **'Similarity was too close between {name1} and {name2}. Please retry verification.'**
  String ambiguousDescription(String name1, String name2);

  /// Title when database has no employees
  ///
  /// In en, this message translates to:
  /// **'No Enrolled Employees'**
  String get noEnrolledEmployees;

  /// Description when database has no employees
  ///
  /// In en, this message translates to:
  /// **'Please enroll employees before verifying attendance.'**
  String get noEnrolledDescription;

  /// Home screen button to navigate to employees list
  ///
  /// In en, this message translates to:
  /// **'Employees & Enrollment'**
  String get homeEmployeesAction;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
