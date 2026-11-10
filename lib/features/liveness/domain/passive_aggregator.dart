import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'passive_sample.dart';

/// Verdict state of passive anti-spoofing evaluation.
enum PassiveVerdict {
  /// Insufficient samples collected to render a definitive verdict.
  pending,

  /// Passed passive liveness: mean score and passing ratio both met requirements.
  passed,

  /// Failed passive liveness: spoof detected or thresholds not satisfied.
  failed,
}

/// Aggregated multi-frame passive liveness summary.
@immutable
class PassiveAggregatedResult {
  const PassiveAggregatedResult({
    required this.verdict,
    required this.sampleCount,
    required this.meanScore,
    required this.passingRatio,
    required this.minScore,
    required this.maxScore,
    required this.samples,
  });

  /// The aggregated verdict.
  final PassiveVerdict verdict;

  /// Total number of evaluated frame samples.
  final int sampleCount;

  /// Arithmetic mean of passive real scores across all samples.
  final double meanScore;

  /// Fraction of samples whose score was at or above the passive threshold (0.0 to 1.0).
  final double passingRatio;

  /// Lowest individual sample score.
  final double minScore;

  /// Highest individual sample score.
  final double maxScore;

  /// Full history of recorded samples in chronological order.
  final List<PassiveSample> samples;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PassiveAggregatedResult &&
        other.verdict == verdict &&
        other.sampleCount == sampleCount &&
        other.meanScore == meanScore &&
        other.passingRatio == passingRatio &&
        other.minScore == minScore &&
        other.maxScore == maxScore &&
        listEquals(other.samples, samples);
  }

  @override
  int get hashCode => Object.hash(
    verdict,
    sampleCount,
    meanScore,
    passingRatio,
    minScore,
    maxScore,
    Object.hashAll(samples),
  );
}

/// Aggregates per-frame passive liveness scores across an entire session.
///
/// Rules:
/// 1. Verdict passes only if BOTH:
///    - [meanScore] >= [passiveThreshold]
///    - [passingRatio] >= [passingFrameRatio]
/// 2. Requires at least [minSamples] frames before rendering a pass verdict.
///    One good frame never passes alone; one bad frame never decides alone.
class PassiveAggregator {
  PassiveAggregator({
    required this.passiveThreshold,
    required this.passingFrameRatio,
    this.minSamples = 3,
  }) : assert(
         passiveThreshold >= 0.0 && passiveThreshold <= 1.0,
         'passiveThreshold must be between 0 and 1',
       ),
       assert(
         passingFrameRatio >= 0.0 && passingFrameRatio <= 1.0,
         'passingFrameRatio must be between 0 and 1',
       ),
       assert(minSamples >= 2, 'minSamples must be at least 2');

  /// Minimum probability required to consider a single frame passing.
  final double passiveThreshold;

  /// Minimum fraction of sampled frames that must meet or exceed [passiveThreshold].
  final double passingFrameRatio;

  /// Minimum number of samples required before passing verdict can be issued.
  final int minSamples;

  final List<PassiveSample> _samples = <PassiveSample>[];

  /// List of all recorded samples.
  List<PassiveSample> get samples => List<PassiveSample>.unmodifiable(_samples);

  /// Number of samples collected so far.
  int get sampleCount => _samples.length;

  /// Adds a new frame evaluation sample to the aggregator.
  void addSample(PassiveSample sample) {
    _samples.add(sample);
  }

  /// Evaluates all collected samples and computes the current aggregated result.
  PassiveAggregatedResult get result {
    if (_samples.isEmpty) {
      return const PassiveAggregatedResult(
        verdict: PassiveVerdict.pending,
        sampleCount: 0,
        meanScore: 0.0,
        passingRatio: 0.0,
        minScore: 0.0,
        maxScore: 0.0,
        samples: <PassiveSample>[],
      );
    }

    final int n = _samples.length;
    double sum = 0.0;
    int passingCount = 0;
    double minS = _samples.first.meanScore;
    double maxS = _samples.first.meanScore;

    for (final PassiveSample s in _samples) {
      final double score = s.meanScore;
      sum += score;
      if (score >= passiveThreshold) {
        passingCount++;
      }
      minS = math.min(minS, score);
      maxS = math.max(maxS, score);
    }

    final double mean = sum / n;
    final double ratio = passingCount / n;

    final PassiveVerdict verdict;
    if (n < minSamples) {
      // One or too few good frames can never pass alone
      verdict = PassiveVerdict.pending;
    } else if (mean >= passiveThreshold && ratio >= passingFrameRatio) {
      verdict = PassiveVerdict.passed;
    } else {
      verdict = PassiveVerdict.failed;
    }

    return PassiveAggregatedResult(
      verdict: verdict,
      sampleCount: n,
      meanScore: mean,
      passingRatio: ratio,
      minScore: minS,
      maxScore: maxS,
      samples: List<PassiveSample>.unmodifiable(_samples),
    );
  }

  /// Clears all collected samples for a clean verification session.
  void reset() {
    _samples.clear();
  }
}
