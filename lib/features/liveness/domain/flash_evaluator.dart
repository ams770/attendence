import 'dart:math' as math;

import 'flash_color.dart';
import 'flash_config.dart';
import 'flash_sample.dart';

/// Categorical verdict resulting from flash challenge evaluation.
enum FlashVerdict {
  passed,
  failed,
  inconclusive,
  skipped;

  bool get isPassed => this == FlashVerdict.passed;
  bool get isFailed => this == FlashVerdict.failed;
  bool get isSkipped => this == FlashVerdict.skipped;
}

/// Recorded reason when a flash challenge evaluation is skipped.
enum FlashSkipReason {
  none,
  ambientTooDark,
  ambientTooBright,
  insufficientSamples,
}

/// Evaluation result detailing flash correlation and verdict.
class FlashEvaluationResult {
  const FlashEvaluationResult({
    required this.verdict,
    required this.correlation,
    this.skipReason = FlashSkipReason.none,
    this.details,
  });

  final FlashVerdict verdict;
  final double correlation;
  final FlashSkipReason skipReason;
  final String? details;
}

/// Evaluates correlation between displayed screen flash colors and skin reflection deltas.
///
/// Implemented entirely in pure Dart without Flutter UI or platform dependencies.
///
/// LIMITATIONS:
/// 1. Highly sensitive to ambient lighting: in bright outdoor environments or direct sunlight,
///    screen flash intensity is overpowered by ambient illumination and cannot create a detectable shift.
/// 2. In pitch darkness without sufficient baseline face illumination, camera auto-gain can cause
///    severe channel noise or clipping.
/// 3. Curved matte paper or replayed videos on an OLED device held very close to the flashing screen
///    can pick up physical specular bounce from glass. Flash correlation is a secondary weighted signal.
class FlashEvaluator {
  const FlashEvaluator({this.config = const FlashConfig()});

  final FlashConfig config;

  /// Evaluates a flash sequence against baseline skin color.
  FlashEvaluationResult evaluate({
    required SkinColorSample baseline,
    required List<FlashStepRecord> steps,
  }) {
    // 1. Ambient lighting boundary checks
    if (baseline.brightness < config.minBrightness) {
      return const FlashEvaluationResult(
        verdict: FlashVerdict.skipped,
        correlation: 0.0,
        skipReason: FlashSkipReason.ambientTooDark,
        details: 'Ambient illumination too dark for reliable flash measurement',
      );
    }

    if (baseline.brightness > config.maxBrightness) {
      return const FlashEvaluationResult(
        verdict: FlashVerdict.skipped,
        correlation: 0.0,
        skipReason: FlashSkipReason.ambientTooBright,
        details: 'Ambient illumination washed out screen flash reflection',
      );
    }

    if (steps.length < 2) {
      return const FlashEvaluationResult(
        verdict: FlashVerdict.skipped,
        correlation: 0.0,
        skipReason: FlashSkipReason.insufficientSamples,
        details: 'Insufficient color steps captured during flash challenge',
      );
    }

    // 2. Build expected vs measured response vectors across all channels
    final List<double> expected = <double>[];
    final List<double> measured = <double>[];

    for (final FlashStepRecord record in steps) {
      final double dr = record.sample.meanR - baseline.meanR;
      final double dg = record.sample.meanG - baseline.meanG;
      final double db = record.sample.meanB - baseline.meanB;

      switch (record.color) {
        case FlashColor.red:
          expected.addAll(const <double>[1.0, -0.5, -0.5]);
          measured.addAll(<double>[dr, dg, db]);

        case FlashColor.green:
          expected.addAll(const <double>[-0.5, 1.0, -0.5]);
          measured.addAll(<double>[dr, dg, db]);

        case FlashColor.blue:
          expected.addAll(const <double>[-0.5, -0.5, 1.0]);
          measured.addAll(<double>[dr, dg, db]);

        case FlashColor.white:
          expected.addAll(const <double>[1.0, 1.0, 1.0]);
          measured.addAll(<double>[dr, dg, db]);
      }
    }

    // 3. Compute measured response standard deviation against sensor noise floor
    double sumM = 0.0;
    for (int i = 0; i < measured.length; i++) {
      sumM += measured[i];
    }
    final double meanM = sumM / measured.length;
    double varM = 0.0;
    for (int i = 0; i < measured.length; i++) {
      final double diff = measured[i] - meanM;
      varM += diff * diff;
    }
    final double stdM = math.sqrt(varM / measured.length);
    if (stdM < config.minReflectionStd) {
      return const FlashEvaluationResult(
        verdict: FlashVerdict.failed,
        correlation: 0.0,
        details: 'Measured color modulation below camera sensor noise floor',
      );
    }

    // 4. Compute Pearson correlation coefficient
    final double correlation = _pearsonCorrelation(expected, measured);

    // 5. Assign verdict based on correlation thresholds
    if (correlation >= config.correlationThreshold) {
      return FlashEvaluationResult(
        verdict: FlashVerdict.passed,
        correlation: correlation,
        details:
            'Reflection matched flash sequence (correlation: ${correlation.toStringAsFixed(3)})',
      );
    } else if (correlation < 0.0) {
      return FlashEvaluationResult(
        verdict: FlashVerdict.failed,
        correlation: correlation,
        details:
            'Reflection was absent or uncorrelated with flash (correlation: ${correlation.toStringAsFixed(3)})',
      );
    } else {
      return FlashEvaluationResult(
        verdict: FlashVerdict.inconclusive,
        correlation: correlation,
        details:
            'Reflection correlation inconclusive (${correlation.toStringAsFixed(3)})',
      );
    }
  }

  /// Calculates the Pearson correlation coefficient between two equal-length vectors.
  double _pearsonCorrelation(List<double> x, List<double> y) {
    final int n = x.length;
    if (n < 2 || n != y.length) return 0.0;

    double sumX = 0.0;
    double sumY = 0.0;
    for (int i = 0; i < n; i++) {
      sumX += x[i];
      sumY += y[i];
    }
    final double meanX = sumX / n;
    final double meanY = sumY / n;

    double num = 0.0;
    double denX = 0.0;
    double denY = 0.0;

    for (int i = 0; i < n; i++) {
      final double dx = x[i] - meanX;
      final double dy = y[i] - meanY;
      num += dx * dy;
      denX += dx * dx;
      denY += dy * dy;
    }

    final double den = math.sqrt(denX * denY);
    if (den < 1.0e-8) return 0.0;

    return (num / den).clamp(-1.0, 1.0);
  }
}
