import 'package:flutter/foundation.dart';

import '../../features/liveness/domain/passive_preprocess_config.dart';

/// Central configuration for the attendance application.
///
/// Contains every tunable parameter with defaults. Overrides can be provided
/// via [AppConfigRepository].
@immutable
class AppConfig {
  const AppConfig({
    this.sessionTimeout = const Duration(seconds: 30),
    this.perChallengeTimeout = const Duration(seconds: 6),
    this.failureLimit = 3,
    this.lockoutDuration = const Duration(seconds: 60),
    this.passiveThreshold = 0.85,
    this.passivePassingFrameRatio = 0.75,
    this.passiveHardFloor = 0.40,
    this.passiveBoxExpansion = 1.0,
    this.passivePreprocessConfig = const PassivePreprocessConfig(),
    this.recognitionThreshold = 0.363,
    this.recognitionMargin = 0.05,
    this.attendanceCooldown = const Duration(seconds: 60),
    this.qualityMinFaceWidthRatio = 0.25,
    this.qualityMaxYaw = 15.0,
    this.qualityMaxPitch = 15.0,
    this.qualityMaxRoll = 15.0,
    this.qualityMinSharpness = 50.0,
    this.qualityMinBrightness = 40.0,
    this.qualityMaxBrightness = 220.0,
    this.qualityMaxNearSaturatedRatio = 0.10,
    this.ovalCornerTolerance = 1.25,
    this.ovalCardinalTolerance = 1.08,
    this.challengeBlinkEyeOpenThreshold = 0.60,
    this.challengeBlinkEyeClosedThreshold = 0.25,
    this.challengeBlinkMinClosedFrames = 2,
    this.challengeBlinkMinOpenFrames = 2,
    this.challengeNeutralMaxYaw = 10.0,
    this.challengeNeutralMaxPitch = 12.0,
    this.challengeNeutralMaxRoll = 12.0,
    this.challengeNeutralMinFrames = 3,
    this.challengeTurnYawThreshold = 20.0,
    this.challengeTurnStartMaxYaw = 10.0,
    this.challengeTurnHysteresis = 4.0,
    this.challengeTurnMinFrames = 3,
    this.yawSignForUserLeft = 1.0,
    this.challengeSmileFloorThreshold = 0.30,
    this.challengeSmileProbabilityThreshold = 0.80,
    this.challengeSmileMinFrames = 3,
    this.challengeNodPitchThreshold = 15.0,
    this.faceLostGracePeriod = const Duration(milliseconds: 700),
    this.temporalConfidenceThreshold = 0.50,
    this.temporalMicroMotionWeight = 0.35,
    this.temporalLoopWeight = 0.35,
    this.temporalRigidityWeight = 0.30,
    this.temporalWindowSize = 25,
    this.flashChallengeEnabled = false,
    this.flashColorDwellDuration = const Duration(milliseconds: 350),
    this.flashCorrelationThreshold = 0.35,
    this.flashMinBrightness = 30.0,
    this.flashMaxBrightness = 220.0,
  });

  /// Maximum time allowed for an entire verification session before failing.
  final Duration sessionTimeout;

  /// Maximum time allowed for a single active liveness challenge.
  final Duration perChallengeTimeout;

  /// Maximum consecutive failed attempts before user lockout.
  final int failureLimit;

  /// Duration for which verification is locked after exceeding [failureLimit].
  final Duration lockoutDuration;

  /// Minimum probability required from MiniFASNet models to consider a frame real.
  final double passiveThreshold;

  /// Ratio of sampled frames that must pass [passiveThreshold] (e.g. 0.75 = 75%).
  final double passivePassingFrameRatio;

  /// Minimum acceptable passive score on any single evaluated frame.
  final double passiveHardFloor;

  /// Multiplier applied to detector face box before scaling (default: 1.0).
  final double passiveBoxExpansion;

  /// Detailed preprocessing and post-processing configuration for MiniFASNet models.
  final PassivePreprocessConfig passivePreprocessConfig;

  /// Recommended OpenCV FaceRecognizerSF cosine threshold for matching.
  ///
  /// Requires empirical calibration on real employee datasets.
  final double recognitionThreshold;

  /// Minimum cosine distance margin between the best match and next candidates.
  final double recognitionMargin;

  /// Cooldown window preventing duplicate check-ins for the same employee.
  final Duration attendanceCooldown;

  /// Minimum ratio of face bounding box width to camera frame width (e.g. 0.25).
  final double qualityMinFaceWidthRatio;

  /// Maximum allowed face yaw angle in degrees.
  final double qualityMaxYaw;

  /// Maximum allowed face pitch angle in degrees.
  final double qualityMaxPitch;

  /// Maximum allowed face roll angle in degrees.
  final double qualityMaxRoll;

  /// Minimum sharpness score required for a frame to pass the quality gate.
  final double qualityMinSharpness;

  /// Minimum average brightness required (0 - 255 scale).
  final double qualityMinBrightness;

  /// Maximum average brightness required (0 - 255 scale).
  final double qualityMaxBrightness;

  /// Maximum fraction of near-saturated pixels (brightness >= 250) allowed before glare is flagged.
  final double qualityMaxNearSaturatedRatio;

  /// Allowed corner distance ratio for face bounding boxes in oval guide check.
  final double ovalCornerTolerance;

  /// Allowed cardinal edge distance ratio for face bounding boxes in oval guide check.
  final double ovalCardinalTolerance;

  /// Eye open probability threshold to consider eyes open during blink hysteresis.
  final double challengeBlinkEyeOpenThreshold;

  /// Eye open probability threshold below which eyes are registered as closed.
  final double challengeBlinkEyeClosedThreshold;

  /// Minimum consecutive frames eyes must remain closed to register a blink.
  final int challengeBlinkMinClosedFrames;

  /// Minimum consecutive frames eyes must remain open to complete a blink.
  final int challengeBlinkMinOpenFrames;

  /// Maximum absolute yaw allowed for neutral look straight step.
  final double challengeNeutralMaxYaw;

  /// Maximum absolute pitch allowed for neutral look straight step.
  final double challengeNeutralMaxPitch;

  /// Maximum absolute roll allowed for neutral look straight step.
  final double challengeNeutralMaxRoll;

  /// Minimum consecutive frames required to establish neutral baseline.
  final int challengeNeutralMinFrames;

  /// Head turn yaw angle threshold in degrees for turn challenge.
  final double challengeTurnYawThreshold;

  /// Maximum starting yaw deviation from baseline to begin a turn challenge.
  final double challengeTurnStartMaxYaw;

  /// Hysteresis angle allowance in degrees to prevent flutter during turn holding.
  final double challengeTurnHysteresis;

  /// Minimum consecutive frames required to hold a turn pose.
  final int challengeTurnMinFrames;

  /// Sign convention multiplier for user turning left (+1.0 for positive yaw, -1.0 if inverted).
  final double yawSignForUserLeft;

  /// Maximum smiling probability allowed to register neutral non-smiling baseline.
  final double challengeSmileFloorThreshold;

  /// Minimum smiling probability to register a valid smile.
  final double challengeSmileProbabilityThreshold;

  /// Minimum consecutive frames required to hold a smile.
  final int challengeSmileMinFrames;

  /// Head nod pitch angle threshold in degrees for nod challenge.
  final double challengeNodPitchThreshold;

  /// Grace period during which a temporarily lost face does not fail the session.
  final Duration faceLostGracePeriod;

  /// Minimum combined temporal confidence score required to pass.
  final double temporalConfidenceThreshold;

  /// Weight assigned to facial micro-motion in temporal analysis.
  final double temporalMicroMotionWeight;

  /// Weight assigned to repeating loop detection in temporal analysis.
  final double temporalLoopWeight;

  /// Weight assigned to 3D planar rigidity test in temporal analysis.
  final double temporalRigidityWeight;

  /// Sliding frame window size for temporal signal analysis.
  final int temporalWindowSize;

  /// Whether the screen color flash challenge is enabled.
  final bool flashChallengeEnabled;

  /// Display duration for each color in the flash challenge.
  final Duration flashColorDwellDuration;

  /// Minimum Pearson correlation required between flash colors and skin chrominance change.
  final double flashCorrelationThreshold;

  /// Minimum ambient brightness required for flash reflection to be meaningful.
  final double flashMinBrightness;

  /// Maximum ambient brightness beyond which screen flash is washed out.
  final double flashMaxBrightness;

  AppConfig copyWith({
    Duration? sessionTimeout,
    Duration? perChallengeTimeout,
    int? failureLimit,
    Duration? lockoutDuration,
    double? passiveThreshold,
    double? passivePassingFrameRatio,
    double? passiveHardFloor,
    double? passiveBoxExpansion,
    PassivePreprocessConfig? passivePreprocessConfig,
    double? recognitionThreshold,
    double? recognitionMargin,
    Duration? attendanceCooldown,
    double? qualityMinFaceWidthRatio,
    double? qualityMaxYaw,
    double? qualityMaxPitch,
    double? qualityMaxRoll,
    double? qualityMinSharpness,
    double? qualityMinBrightness,
    double? qualityMaxBrightness,
    double? qualityMaxNearSaturatedRatio,
    double? ovalCornerTolerance,
    double? ovalCardinalTolerance,
    double? challengeBlinkEyeOpenThreshold,
    double? challengeBlinkEyeClosedThreshold,
    int? challengeBlinkMinClosedFrames,
    int? challengeBlinkMinOpenFrames,
    double? challengeNeutralMaxYaw,
    double? challengeNeutralMaxPitch,
    double? challengeNeutralMaxRoll,
    int? challengeNeutralMinFrames,
    double? challengeTurnYawThreshold,
    double? challengeTurnStartMaxYaw,
    double? challengeTurnHysteresis,
    int? challengeTurnMinFrames,
    double? yawSignForUserLeft,
    double? challengeSmileFloorThreshold,
    double? challengeSmileProbabilityThreshold,
    int? challengeSmileMinFrames,
    double? challengeNodPitchThreshold,
    Duration? faceLostGracePeriod,
    double? temporalConfidenceThreshold,
    double? temporalMicroMotionWeight,
    double? temporalLoopWeight,
    double? temporalRigidityWeight,
    int? temporalWindowSize,
    bool? flashChallengeEnabled,
    Duration? flashColorDwellDuration,
    double? flashCorrelationThreshold,
    double? flashMinBrightness,
    double? flashMaxBrightness,
  }) {
    return AppConfig(
      sessionTimeout: sessionTimeout ?? this.sessionTimeout,
      perChallengeTimeout: perChallengeTimeout ?? this.perChallengeTimeout,
      failureLimit: failureLimit ?? this.failureLimit,
      lockoutDuration: lockoutDuration ?? this.lockoutDuration,
      passiveThreshold: passiveThreshold ?? this.passiveThreshold,
      passivePassingFrameRatio:
          passivePassingFrameRatio ?? this.passivePassingFrameRatio,
      passiveHardFloor: passiveHardFloor ?? this.passiveHardFloor,
      passiveBoxExpansion: passiveBoxExpansion ?? this.passiveBoxExpansion,
      passivePreprocessConfig:
          passivePreprocessConfig ?? this.passivePreprocessConfig,
      recognitionThreshold: recognitionThreshold ?? this.recognitionThreshold,
      recognitionMargin: recognitionMargin ?? this.recognitionMargin,
      attendanceCooldown: attendanceCooldown ?? this.attendanceCooldown,
      qualityMinFaceWidthRatio:
          qualityMinFaceWidthRatio ?? this.qualityMinFaceWidthRatio,
      qualityMaxYaw: qualityMaxYaw ?? this.qualityMaxYaw,
      qualityMaxPitch: qualityMaxPitch ?? this.qualityMaxPitch,
      qualityMaxRoll: qualityMaxRoll ?? this.qualityMaxRoll,
      qualityMinSharpness: qualityMinSharpness ?? this.qualityMinSharpness,
      qualityMinBrightness: qualityMinBrightness ?? this.qualityMinBrightness,
      qualityMaxBrightness: qualityMaxBrightness ?? this.qualityMaxBrightness,
      qualityMaxNearSaturatedRatio:
          qualityMaxNearSaturatedRatio ?? this.qualityMaxNearSaturatedRatio,
      ovalCornerTolerance: ovalCornerTolerance ?? this.ovalCornerTolerance,
      ovalCardinalTolerance:
          ovalCardinalTolerance ?? this.ovalCardinalTolerance,
      challengeBlinkEyeOpenThreshold:
          challengeBlinkEyeOpenThreshold ?? this.challengeBlinkEyeOpenThreshold,
      challengeBlinkEyeClosedThreshold:
          challengeBlinkEyeClosedThreshold ??
          this.challengeBlinkEyeClosedThreshold,
      challengeBlinkMinClosedFrames:
          challengeBlinkMinClosedFrames ?? this.challengeBlinkMinClosedFrames,
      challengeBlinkMinOpenFrames:
          challengeBlinkMinOpenFrames ?? this.challengeBlinkMinOpenFrames,
      challengeNeutralMaxYaw:
          challengeNeutralMaxYaw ?? this.challengeNeutralMaxYaw,
      challengeNeutralMaxPitch:
          challengeNeutralMaxPitch ?? this.challengeNeutralMaxPitch,
      challengeNeutralMaxRoll:
          challengeNeutralMaxRoll ?? this.challengeNeutralMaxRoll,
      challengeNeutralMinFrames:
          challengeNeutralMinFrames ?? this.challengeNeutralMinFrames,
      challengeTurnYawThreshold:
          challengeTurnYawThreshold ?? this.challengeTurnYawThreshold,
      challengeTurnStartMaxYaw:
          challengeTurnStartMaxYaw ?? this.challengeTurnStartMaxYaw,
      challengeTurnHysteresis:
          challengeTurnHysteresis ?? this.challengeTurnHysteresis,
      challengeTurnMinFrames:
          challengeTurnMinFrames ?? this.challengeTurnMinFrames,
      yawSignForUserLeft: yawSignForUserLeft ?? this.yawSignForUserLeft,
      challengeSmileFloorThreshold:
          challengeSmileFloorThreshold ?? this.challengeSmileFloorThreshold,
      challengeSmileProbabilityThreshold:
          challengeSmileProbabilityThreshold ??
          this.challengeSmileProbabilityThreshold,
      challengeSmileMinFrames:
          challengeSmileMinFrames ?? this.challengeSmileMinFrames,
      challengeNodPitchThreshold:
          challengeNodPitchThreshold ?? this.challengeNodPitchThreshold,
      faceLostGracePeriod: faceLostGracePeriod ?? this.faceLostGracePeriod,
      temporalConfidenceThreshold:
          temporalConfidenceThreshold ?? this.temporalConfidenceThreshold,
      temporalMicroMotionWeight:
          temporalMicroMotionWeight ?? this.temporalMicroMotionWeight,
      temporalLoopWeight: temporalLoopWeight ?? this.temporalLoopWeight,
      temporalRigidityWeight:
          temporalRigidityWeight ?? this.temporalRigidityWeight,
      temporalWindowSize: temporalWindowSize ?? this.temporalWindowSize,
      flashChallengeEnabled:
          flashChallengeEnabled ?? this.flashChallengeEnabled,
      flashColorDwellDuration:
          flashColorDwellDuration ?? this.flashColorDwellDuration,
      flashCorrelationThreshold:
          flashCorrelationThreshold ?? this.flashCorrelationThreshold,
      flashMinBrightness: flashMinBrightness ?? this.flashMinBrightness,
      flashMaxBrightness: flashMaxBrightness ?? this.flashMaxBrightness,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppConfig &&
        other.sessionTimeout == sessionTimeout &&
        other.perChallengeTimeout == perChallengeTimeout &&
        other.failureLimit == failureLimit &&
        other.lockoutDuration == lockoutDuration &&
        other.passiveThreshold == passiveThreshold &&
        other.passivePassingFrameRatio == passivePassingFrameRatio &&
        other.passiveHardFloor == passiveHardFloor &&
        other.passiveBoxExpansion == passiveBoxExpansion &&
        other.passivePreprocessConfig == passivePreprocessConfig &&
        other.recognitionThreshold == recognitionThreshold &&
        other.recognitionMargin == recognitionMargin &&
        other.attendanceCooldown == attendanceCooldown &&
        other.qualityMinFaceWidthRatio == qualityMinFaceWidthRatio &&
        other.qualityMaxYaw == qualityMaxYaw &&
        other.qualityMaxPitch == qualityMaxPitch &&
        other.qualityMaxRoll == qualityMaxRoll &&
        other.qualityMinSharpness == qualityMinSharpness &&
        other.qualityMinBrightness == qualityMinBrightness &&
        other.qualityMaxBrightness == qualityMaxBrightness &&
        other.qualityMaxNearSaturatedRatio == qualityMaxNearSaturatedRatio &&
        other.ovalCornerTolerance == ovalCornerTolerance &&
        other.ovalCardinalTolerance == ovalCardinalTolerance &&
        other.challengeBlinkEyeOpenThreshold ==
            challengeBlinkEyeOpenThreshold &&
        other.challengeBlinkEyeClosedThreshold ==
            challengeBlinkEyeClosedThreshold &&
        other.challengeBlinkMinClosedFrames == challengeBlinkMinClosedFrames &&
        other.challengeBlinkMinOpenFrames == challengeBlinkMinOpenFrames &&
        other.challengeNeutralMaxYaw == challengeNeutralMaxYaw &&
        other.challengeNeutralMaxPitch == challengeNeutralMaxPitch &&
        other.challengeNeutralMaxRoll == challengeNeutralMaxRoll &&
        other.challengeNeutralMinFrames == challengeNeutralMinFrames &&
        other.challengeTurnYawThreshold == challengeTurnYawThreshold &&
        other.challengeTurnStartMaxYaw == challengeTurnStartMaxYaw &&
        other.challengeTurnHysteresis == challengeTurnHysteresis &&
        other.challengeTurnMinFrames == challengeTurnMinFrames &&
        other.yawSignForUserLeft == yawSignForUserLeft &&
        other.challengeSmileFloorThreshold == challengeSmileFloorThreshold &&
        other.challengeSmileProbabilityThreshold ==
            challengeSmileProbabilityThreshold &&
        other.challengeSmileMinFrames == challengeSmileMinFrames &&
        other.challengeNodPitchThreshold == challengeNodPitchThreshold &&
        other.faceLostGracePeriod == faceLostGracePeriod &&
        other.temporalConfidenceThreshold == temporalConfidenceThreshold &&
        other.temporalMicroMotionWeight == temporalMicroMotionWeight &&
        other.temporalLoopWeight == temporalLoopWeight &&
        other.temporalRigidityWeight == temporalRigidityWeight &&
        other.temporalWindowSize == temporalWindowSize &&
        other.flashChallengeEnabled == flashChallengeEnabled &&
        other.flashColorDwellDuration == flashColorDwellDuration &&
        other.flashCorrelationThreshold == flashCorrelationThreshold &&
        other.flashMinBrightness == flashMinBrightness &&
        other.flashMaxBrightness == flashMaxBrightness;
  }

  @override
  int get hashCode => Object.hashAll([
    sessionTimeout,
    perChallengeTimeout,
    failureLimit,
    lockoutDuration,
    passiveThreshold,
    passivePassingFrameRatio,
    passiveHardFloor,
    passiveBoxExpansion,
    passivePreprocessConfig,
    recognitionThreshold,
    recognitionMargin,
    attendanceCooldown,
    qualityMinFaceWidthRatio,
    qualityMaxYaw,
    qualityMaxPitch,
    qualityMaxRoll,
    qualityMinSharpness,
    qualityMinBrightness,
    qualityMaxBrightness,
    qualityMaxNearSaturatedRatio,
    ovalCornerTolerance,
    ovalCardinalTolerance,
    challengeBlinkEyeOpenThreshold,
    challengeBlinkEyeClosedThreshold,
    challengeBlinkMinClosedFrames,
    challengeBlinkMinOpenFrames,
    challengeNeutralMaxYaw,
    challengeNeutralMaxPitch,
    challengeNeutralMaxRoll,
    challengeNeutralMinFrames,
    challengeTurnYawThreshold,
    challengeTurnStartMaxYaw,
    challengeTurnHysteresis,
    challengeTurnMinFrames,
    yawSignForUserLeft,
    challengeSmileFloorThreshold,
    challengeSmileProbabilityThreshold,
    challengeSmileMinFrames,
    challengeNodPitchThreshold,
    faceLostGracePeriod,
    temporalConfidenceThreshold,
    temporalMicroMotionWeight,
    temporalLoopWeight,
    temporalRigidityWeight,
    temporalWindowSize,
    flashChallengeEnabled,
    flashColorDwellDuration,
    flashCorrelationThreshold,
    flashMinBrightness,
    flashMaxBrightness,
  ]);
}

/// Abstract contract for reading and writing app configuration.
abstract class AppConfigRepository {
  Future<AppConfig> loadConfig();
  Future<void> saveConfig(AppConfig config);
}
