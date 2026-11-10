import 'dart:math' as math;

import 'temporal_config.dart';
import 'temporal_sample.dart';

/// Comprehensive evaluation result produced by [TemporalAnalyzer].
class TemporalAnalysisResult {
  const TemporalAnalysisResult({
    required this.microMotionScore,
    required this.loopScore,
    required this.rigidityScore,
    required this.combinedConfidence,
    required this.isPassed,
    required this.rigidityEvaluated,
    required this.sampleCount,
    this.details,
  });

  /// Natural micro-motion score (0.0 to 1.0, 0 = frozen static photo).
  final double microMotionScore;

  /// Repeating loop score (0.0 to 1.0, 0 = replayed periodic video).
  final double loopScore;

  /// 3D depth parallax rigidity score (0.0 to 1.0, 0 = rigid 2D planar surface).
  final double rigidityScore;

  /// Weighted overall confidence score (0.0 to 1.0).
  final double combinedConfidence;

  /// Whether the session passed temporal consistency checks.
  final bool isPassed;

  /// Whether a qualifying head turn occurred to evaluate 3D rigidity.
  final bool rigidityEvaluated;

  /// Number of frame samples analyzed in this evaluation.
  final int sampleCount;

  /// Optional human-readable diagnosis details.
  final String? details;
}

/// Multi-signal temporal consistency and motion analyzer.
///
/// Evaluates facial micro-motion, replayed video loop periodicity, and
/// 3D depth parallax rigidity during head rotation across a sliding window of frames.
///
/// LIMITATIONS & SECURITY CONSIDERATIONS:
/// 1. Micro-motion: A live person holding their breath and staying extremely still in dim lighting
///    can exhibit very low landmark variance. Conversely, holding a printed photo by hand with natural
///    hand tremor introduces synthetic motion that can mimic micro-movement.
/// 2. Loop detection: Detects repeating video loops within [TemporalConfig.loopMinLag] to
///    [TemporalConfig.loopMaxLag] frames (approx 0.3s to 2.0s). Non-repeating long video replays or
///    loops longer than the sliding window will not be flagged by this signal.
/// 3. Planar rigidity: Assumes an affine projection approximation over a 5-point landmark model.
///    Under close-up wide-angle selfie distortion, perspective effects can inflate planar residuals.
///    Conversely, curved masks or small yaw rotations (< 15 degrees) cannot reliably distinguish
///    depth relief from planar motion.
///
/// These signals serve strictly as supporting weighted evidence in defense-in-depth, not standalone proof.
class TemporalAnalyzer {
  TemporalAnalyzer({this.config = const TemporalConfig()});

  final TemporalConfig config;

  final List<TemporalFrameSample> _window = <TemporalFrameSample>[];

  /// Current number of frame samples in the sliding buffer.
  int get bufferLength => _window.length;

  /// Adds a new frame sample into the sliding window.
  void addSample(TemporalFrameSample sample) {
    _window.add(sample);
    if (_window.length > config.windowSize) {
      _window.removeAt(0);
    }
  }

  /// Clears all buffered frame samples.
  void reset() {
    _window.clear();
  }

  /// Evaluates all temporal signals across the current frame window.
  TemporalAnalysisResult evaluate() {
    if (_window.length < 5) {
      return const TemporalAnalysisResult(
        microMotionScore: 1.0,
        loopScore: 1.0,
        rigidityScore: 1.0,
        combinedConfidence: 1.0,
        isPassed: true,
        rigidityEvaluated: false,
        sampleCount: 0,
        details: 'Insufficient samples for temporal evaluation',
      );
    }

    final double microMotion = _computeMicroMotionScore();
    final double loop = _computeLoopScore();
    final ({double score, bool evaluated}) rigidityResult =
        _computeRigidityScore();

    final double effectiveRigidityWeight = rigidityResult.evaluated
        ? config.rigidityWeight
        : 0.0;
    final double totalWeight =
        config.microMotionWeight + config.loopWeight + effectiveRigidityWeight;

    final double combinedConfidence = totalWeight > 0.0
        ? (microMotion * config.microMotionWeight +
                  loop * config.loopWeight +
                  rigidityResult.score * effectiveRigidityWeight) /
              totalWeight
        : 1.0;

    final bool isPassed =
        combinedConfidence >= config.confidenceThreshold && microMotion > 0.05;

    return TemporalAnalysisResult(
      microMotionScore: microMotion,
      loopScore: loop,
      rigidityScore: rigidityResult.score,
      combinedConfidence: combinedConfidence,
      isPassed: isPassed,
      rigidityEvaluated: rigidityResult.evaluated,
      sampleCount: _window.length,
    );
  }

  /// Signal 1: Micro-motion variance across normalized landmark coordinates.
  double _computeMicroMotionScore() {
    final int n = _window.length;
    // 10 coordinates: 5 normalized x, 5 normalized y
    final List<List<double>> series = List<List<double>>.generate(
      10,
      (_) => List<double>.filled(n, 0.0),
    );

    for (int t = 0; t < n; t++) {
      final TemporalFrameSample sample = _window[t];
      final double bw = math.max(1.0, sample.boxWidth);
      final double bh = math.max(1.0, sample.boxHeight);
      final List<TemporalPoint> pts = sample.landmarks.asList;

      for (int i = 0; i < 5; i++) {
        series[i][t] = (pts[i].x - sample.boxLeft) / bw;
        series[i + 5][t] = (pts[i].y - sample.boxTop) / bh;
      }
    }

    double totalVariance = 0.0;
    for (int c = 0; c < 10; c++) {
      final List<double> values = series[c];
      double mean = 0.0;
      for (int t = 0; t < n; t++) {
        mean += values[t];
      }
      mean /= n;

      double variance = 0.0;
      for (int t = 0; t < n; t++) {
        final double diff = values[t] - mean;
        variance += diff * diff;
      }
      totalVariance += (variance / n);
    }

    final double avgVariance = totalVariance / 10.0;

    // Check frozen lower bound
    if (avgVariance <= config.microMotionFrozenVariance) {
      return 0.0;
    }

    // Interpolate up to target natural variance
    if (avgVariance < config.microMotionNaturalVarianceTarget) {
      final double t =
          (avgVariance - config.microMotionFrozenVariance) /
          (config.microMotionNaturalVarianceTarget -
              config.microMotionFrozenVariance);
      return t.clamp(0.0, 1.0);
    }

    // Between target and max: healthy micro-motion
    if (avgVariance <= config.microMotionMaxVariance) {
      return 1.0;
    }

    // Excessive variance indicates tracking jitter or noise
    final double excess =
        (avgVariance - config.microMotionMaxVariance) /
        config.microMotionMaxVariance;
    return (1.0 - excess * 0.8).clamp(0.2, 1.0);
  }

  /// Signal 2: Sequence distance / autocorrelation across sliding lags.
  double _computeLoopScore() {
    final int n = _window.length;
    final int maxLag = math.min(config.loopMaxLag, n ~/ 2);
    final int minLag = config.loopMinLag;

    if (n < minLag * 2 || minLag > maxLag) {
      return 1.0;
    }

    // Construct 10-dimensional normalized landmark feature vector per frame
    final List<List<double>> vectors = List<List<double>>.generate(n, (int t) {
      final TemporalFrameSample sample = _window[t];
      final double bw = math.max(1.0, sample.boxWidth);
      final double bh = math.max(1.0, sample.boxHeight);
      final List<TemporalPoint> pts = sample.landmarks.asList;
      return <double>[
        (pts[0].x - sample.boxLeft) / bw,
        (pts[0].y - sample.boxTop) / bh,
        (pts[1].x - sample.boxLeft) / bw,
        (pts[1].y - sample.boxTop) / bh,
        (pts[2].x - sample.boxLeft) / bw,
        (pts[2].y - sample.boxTop) / bh,
        (pts[3].x - sample.boxLeft) / bw,
        (pts[3].y - sample.boxTop) / bh,
        (pts[4].x - sample.boxLeft) / bw,
        (pts[4].y - sample.boxTop) / bh,
      ];
    });

    // Compute overall signal variance
    final List<double> meanVec = List<double>.filled(10, 0.0);
    for (int t = 0; t < n; t++) {
      for (int c = 0; c < 10; c++) {
        meanVec[c] += vectors[t][c];
      }
    }
    for (int c = 0; c < 10; c++) {
      meanVec[c] /= n;
    }

    double totalVariance = 0.0;
    for (int t = 0; t < n; t++) {
      for (int c = 0; c < 10; c++) {
        final double d = vectors[t][c] - meanVec[c];
        totalVariance += d * d;
      }
    }
    totalVariance /= n;

    // If signal has no variance at all, handled by micro-motion check
    if (totalVariance < 1.0e-6) {
      return 1.0;
    }

    double minRelativeDistance = 1.0;

    for (int lag = minLag; lag <= maxLag; lag++) {
      final int pairs = n - lag;
      double distanceSum = 0.0;
      for (int t = lag; t < n; t++) {
        double distSq = 0.0;
        for (int c = 0; c < 10; c++) {
          final double diff = vectors[t][c] - vectors[t - lag][c];
          distSq += diff * diff;
        }
        distanceSum += distSq;
      }
      final double avgDist = distanceSum / pairs;
      final double relativeDist = avgDist / (2.0 * totalVariance + 1.0e-8);
      if (relativeDist < minRelativeDistance) {
        minRelativeDistance = relativeDist;
      }
    }

    if (minRelativeDistance < config.loopDistanceThreshold) {
      // Loop detected: score drops sharply toward 0
      final double score = minRelativeDistance / config.loopDistanceThreshold;
      return score.clamp(0.0, 1.0);
    }

    return 1.0;
  }

  /// Signal 3: 2D Affine residual measurement between neutral and turned poses.
  ({double score, bool evaluated}) _computeRigidityScore() {
    TemporalFrameSample? neutralSample;
    TemporalFrameSample? turnedSample;
    double minNeutralYaw = double.infinity;
    double maxTurnYaw = 0.0;

    for (final TemporalFrameSample sample in _window) {
      final double yawAbs = sample.yaw.abs();
      if (yawAbs <= config.turnNeutralMaxYaw && yawAbs < minNeutralYaw) {
        minNeutralYaw = yawAbs;
        neutralSample = sample;
      }
      if (yawAbs >= config.turnMinYawForRigidity && yawAbs > maxTurnYaw) {
        maxTurnYaw = yawAbs;
        turnedSample = sample;
      }
    }

    if (neutralSample == null || turnedSample == null) {
      // No sufficient head turn observed in the current window
      return (score: 1.0, evaluated: false);
    }

    final double residual = _fitAffineResidual(
      neutralSample.landmarks.asList,
      turnedSample.landmarks.asList,
      turnedSample.boxWidth,
    );

    if (residual <= config.rigidityPlanarMaxResidual) {
      // Extremely low residual indicates 2D planar rotation (e.g. rotated photo)
      return (score: 0.0, evaluated: true);
    }

    if (residual >= config.rigidityParallaxMinResidual) {
      // Parallax residual matches expected 3D human head geometry
      return (score: 1.0, evaluated: true);
    }

    final double t =
        (residual - config.rigidityPlanarMaxResidual) /
        (config.rigidityParallaxMinResidual - config.rigidityPlanarMaxResidual);
    return (score: t.clamp(0.0, 1.0), evaluated: true);
  }

  /// Fits a 2D affine transform from source to target landmarks using least squares,
  /// and returns the normalized root-mean-squared residual.
  double _fitAffineResidual(
    List<TemporalPoint> src,
    List<TemporalPoint> dst,
    double targetBoxWidth,
  ) {
    if (src.length != 5 || dst.length != 5 || targetBoxWidth <= 0.0) {
      return 0.0;
    }

    // Solve for affine transform [a, b, tx] and [c, d, ty]
    // u = a*x + b*y + tx
    // v = c*x + d*y + ty
    double m00 = 0.0, m01 = 0.0, m02 = 0.0;
    double m11 = 0.0, m12 = 0.0;
    const double m22 = 5.0;

    double bu0 = 0.0, bu1 = 0.0, bu2 = 0.0;
    double bv0 = 0.0, bv1 = 0.0, bv2 = 0.0;

    for (int i = 0; i < 5; i++) {
      final double x = src[i].x;
      final double y = src[i].y;
      final double u = dst[i].x;
      final double v = dst[i].y;

      m00 += x * x;
      m01 += x * y;
      m02 += x;
      m11 += y * y;
      m12 += y;

      bu0 += x * u;
      bu1 += y * u;
      bu2 += u;

      bv0 += x * v;
      bv1 += y * v;
      bv2 += v;
    }

    final double m10 = m01;
    final double m20 = m02;
    final double m21 = m12;

    // 3x3 Determinant
    final double det =
        m00 * (m11 * m22 - m12 * m21) -
        m01 * (m10 * m22 - m12 * m20) +
        m02 * (m10 * m21 - m11 * m20);

    if (det.abs() < 1.0e-9) {
      return 0.0;
    }

    // Solve for (a, b, tx) via Cramer's rule
    final double detA =
        bu0 * (m11 * m22 - m12 * m21) -
        m01 * (bu1 * m22 - m12 * bu2) +
        m02 * (bu1 * m21 - m11 * bu2);
    final double detB =
        m00 * (bu1 * m22 - m12 * bu2) -
        bu0 * (m10 * m22 - m12 * m20) +
        m02 * (m10 * bu2 - bu1 * m20);
    final double detTx =
        m00 * (m11 * bu2 - bu1 * m21) -
        m01 * (m10 * bu2 - bu1 * m20) +
        bu0 * (m10 * m21 - m11 * m20);

    final double a = detA / det;
    final double b = detB / det;
    final double tx = detTx / det;

    // Solve for (c, d, ty) via Cramer's rule
    final double detC =
        bv0 * (m11 * m22 - m12 * m21) -
        m01 * (bv1 * m22 - m12 * bv2) +
        m02 * (bv1 * m21 - m11 * bv2);
    final double detD =
        m00 * (bv1 * m22 - m12 * bv2) -
        bv0 * (m10 * m22 - m12 * m20) +
        m02 * (m10 * bv2 - bv1 * m20);
    final double detTy =
        m00 * (m11 * bv2 - bv1 * m21) -
        m01 * (m10 * bv2 - bv1 * m20) +
        bv0 * (m10 * m21 - m11 * m20);

    final double c = detC / det;
    final double d = detD / det;
    final double ty = detTy / det;

    // Calculate mean Euclidean residual across the 5 points
    double totalResidual = 0.0;
    for (int i = 0; i < 5; i++) {
      final double predU = a * src[i].x + b * src[i].y + tx;
      final double predV = c * src[i].x + d * src[i].y + ty;
      final double du = dst[i].x - predU;
      final double dv = dst[i].y - predV;
      totalResidual += math.sqrt(du * du + dv * dv);
    }

    final double meanResidual = totalResidual / 5.0;
    return meanResidual / targetBoxWidth;
  }
}
