import '../../../core/config/app_config.dart';

/// Configuration parameters for the screen-color-flash challenge.
///
/// Implemented in pure Dart without UI dependencies.
class FlashConfig {
  const FlashConfig({
    this.enabled = false,
    this.dwellDuration = const Duration(milliseconds: 350),
    this.correlationThreshold = 0.35,
    this.minBrightness = 30.0,
    this.maxBrightness = 220.0,
    this.minReflectionStd = 1.5,
    this.sequenceLength = 3,
  });

  /// Instantiates a [FlashConfig] populated from [AppConfig].
  factory FlashConfig.fromAppConfig(AppConfig config) {
    return FlashConfig(
      enabled: config.flashChallengeEnabled,
      dwellDuration: config.flashColorDwellDuration,
      correlationThreshold: config.flashCorrelationThreshold,
      minBrightness: config.flashMinBrightness,
      maxBrightness: config.flashMaxBrightness,
    );
  }

  /// Whether the flash challenge is active for the current hardware profile.
  final bool enabled;

  /// Duration for which each color is presented on screen.
  final Duration dwellDuration;

  /// Minimum Pearson correlation required between flash colors and measured skin color shifts.
  final double correlationThreshold;

  /// Ambient brightness floor below which reflection signals cannot be reliably measured.
  final double minBrightness;

  /// Ambient brightness ceiling above which sunlight or ambient glare washes out screen reflections.
  final double maxBrightness;

  /// Minimum standard deviation required across color channel deltas to exceed sensor noise floor.
  final double minReflectionStd;

  /// Number of distinct color steps in a single flash sequence (typically 3 or 4).
  final int sequenceLength;
}
