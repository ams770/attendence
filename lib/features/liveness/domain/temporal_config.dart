import '../../../core/config/app_config.dart';

/// Configuration parameters for the multi-signal temporal motion analyzer.
///
/// Implemented in pure Dart without UI dependencies.
class TemporalConfig {
  const TemporalConfig({
    this.confidenceThreshold = 0.50,
    this.microMotionWeight = 0.35,
    this.loopWeight = 0.35,
    this.rigidityWeight = 0.30,
    this.windowSize = 25,
    this.microMotionFrozenVariance = 1.0e-7,
    this.microMotionNaturalVarianceTarget = 1.0e-5,
    this.microMotionMaxVariance = 0.02,
    this.loopMinLag = 4,
    this.loopMaxLag = 16,
    this.loopDistanceThreshold = 0.08,
    this.turnMinYawForRigidity = 15.0,
    this.turnNeutralMaxYaw = 8.0,
    this.rigidityPlanarMaxResidual = 0.007,
    this.rigidityParallaxMinResidual = 0.020,
  });

  /// Instantiates a [TemporalConfig] from the shared [AppConfig].
  factory TemporalConfig.fromAppConfig(AppConfig config) {
    return TemporalConfig(
      confidenceThreshold: config.temporalConfidenceThreshold,
      microMotionWeight: config.temporalMicroMotionWeight,
      loopWeight: config.temporalLoopWeight,
      rigidityWeight: config.temporalRigidityWeight,
      windowSize: config.temporalWindowSize,
    );
  }

  /// Minimum combined confidence score required for temporal analysis to pass.
  final double confidenceThreshold;

  /// Weight assigned to facial micro-motion variance.
  final double microMotionWeight;

  /// Weight assigned to repeating video loop detection.
  final double loopWeight;

  /// Weight assigned to 3D planar rigidity / depth parallax analysis.
  final double rigidityWeight;

  /// Maximum number of historical frame samples retained in the analysis window.
  final int windowSize;

  /// Variance threshold below which face landmarks are considered frozen.
  final double microMotionFrozenVariance;

  /// Expected average natural micro-motion coordinate variance.
  final double microMotionNaturalVarianceTarget;

  /// Maximum realistic micro-motion variance before noise penalty applies.
  final double microMotionMaxVariance;

  /// Minimum frame lag evaluated during loop detection.
  final int loopMinLag;

  /// Maximum frame lag evaluated during loop detection.
  final int loopMaxLag;

  /// Distance threshold below which a repeating trajectory indicates video replay.
  final double loopDistanceThreshold;

  /// Minimum yaw angle in degrees required to evaluate 3D planar rigidity.
  final double turnMinYawForRigidity;

  /// Maximum yaw angle in degrees considered a neutral front-facing baseline.
  final double turnNeutralMaxYaw;

  /// Normalized residual threshold below which face behaves as a 2D planar photo.
  final double rigidityPlanarMaxResidual;

  /// Normalized residual threshold above which 3D depth parallax is confirmed.
  final double rigidityParallaxMinResidual;
}
