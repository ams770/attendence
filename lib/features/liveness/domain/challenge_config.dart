import '../../../core/config/app_config.dart';

/// Configuration parameters governing the active challenge state machine.
///
/// Designed as a pure Dart object without UI or framework dependencies.
class ChallengeConfig {
  const ChallengeConfig({
    this.neutralMaxYaw = 10.0,
    this.neutralMaxPitch = 12.0,
    this.neutralMaxRoll = 12.0,
    this.neutralEyeOpenThreshold = 0.60,
    this.neutralSmileFloorThreshold = 0.30,
    this.neutralMinFrames = 3,
    this.blinkEyeOpenThreshold = 0.60,
    this.blinkEyeClosedThreshold = 0.25,
    this.blinkMinClosedFrames = 2,
    this.blinkMinOpenFrames = 2,
    this.turnYawThreshold = 20.0,
    this.turnStartMaxYaw = 10.0,
    this.turnHysteresis = 4.0,
    this.turnMinFrames = 3,
    this.yawSignForUserLeft = 1.0,
    this.smileFloorThreshold = 0.30,
    this.smileThreshold = 0.80,
    this.smileMinFrames = 3,
    this.perChallengeTimeout = const Duration(seconds: 6),
    this.faceLostGracePeriod = const Duration(milliseconds: 700),
  });

  /// Creates a [ChallengeConfig] instance populated from an [AppConfig].
  factory ChallengeConfig.fromAppConfig(AppConfig config) {
    return ChallengeConfig(
      neutralMaxYaw: config.challengeNeutralMaxYaw,
      neutralMaxPitch: config.challengeNeutralMaxPitch,
      neutralMaxRoll: config.challengeNeutralMaxRoll,
      neutralMinFrames: config.challengeNeutralMinFrames,
      blinkEyeOpenThreshold: config.challengeBlinkEyeOpenThreshold,
      blinkEyeClosedThreshold: config.challengeBlinkEyeClosedThreshold,
      blinkMinClosedFrames: config.challengeBlinkMinClosedFrames,
      blinkMinOpenFrames: config.challengeBlinkMinOpenFrames,
      turnYawThreshold: config.challengeTurnYawThreshold,
      turnStartMaxYaw: config.challengeTurnStartMaxYaw,
      turnHysteresis: config.challengeTurnHysteresis,
      turnMinFrames: config.challengeTurnMinFrames,
      yawSignForUserLeft: config.yawSignForUserLeft,
      smileFloorThreshold: config.challengeSmileFloorThreshold,
      smileThreshold: config.challengeSmileProbabilityThreshold,
      smileMinFrames: config.challengeSmileMinFrames,
      perChallengeTimeout: config.perChallengeTimeout,
      faceLostGracePeriod: config.faceLostGracePeriod,
    );
  }

  /// Maximum absolute yaw allowed for neutral look straight step in degrees.
  final double neutralMaxYaw;

  /// Maximum absolute pitch allowed for neutral look straight step in degrees.
  final double neutralMaxPitch;

  /// Maximum absolute roll allowed for neutral look straight step in degrees.
  final double neutralMaxRoll;

  /// Minimum eye open probability required during neutral step.
  final double neutralEyeOpenThreshold;

  /// Maximum smiling probability allowed during neutral step.
  final double neutralSmileFloorThreshold;

  /// Minimum consecutive frames required to establish neutral baseline.
  final int neutralMinFrames;

  /// Eye open probability required to verify eyes are open in blink hysteresis.
  final double blinkEyeOpenThreshold;

  /// Eye open probability below which eyes are registered as closed.
  final double blinkEyeClosedThreshold;

  /// Minimum consecutive frames eyes must remain closed to register a blink.
  final int blinkMinClosedFrames;

  /// Minimum consecutive frames eyes must reopen to complete a blink.
  final int blinkMinOpenFrames;

  /// Head turn yaw threshold in degrees required for turn challenges.
  final double turnYawThreshold;

  /// Maximum yaw deviation from baseline allowed before starting a turn challenge.
  final double turnStartMaxYaw;

  /// Angle tolerance in degrees to prevent flutter while holding a head turn.
  final double turnHysteresis;

  /// Minimum consecutive frames required to hold a turn pose.
  final int turnMinFrames;

  /// Sign multiplier for user turning left (+1.0 for positive yaw, -1.0 if inverted).
  final double yawSignForUserLeft;

  /// Maximum smiling probability allowed to register non-smiling baseline.
  final double smileFloorThreshold;

  /// Minimum smiling probability required to complete a smile challenge.
  final double smileThreshold;

  /// Minimum consecutive frames required to hold a smile.
  final int smileMinFrames;

  /// Maximum duration allowed for a single challenge before failing with timeout.
  final Duration perChallengeTimeout;

  /// Maximum allowable face loss duration before failing with tracking lost.
  final Duration faceLostGracePeriod;
}
