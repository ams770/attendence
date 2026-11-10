import 'package:attendence/features/liveness/domain/passive_aggregator.dart';
import 'package:attendence/features/liveness/domain/passive_sample.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PassiveAggregator', () {
    test('empty aggregator returns pending verdict and zero counts', () {
      final PassiveAggregator aggregator = PassiveAggregator(
        passiveThreshold: 0.85,
        passingFrameRatio: 0.75,
        minSamples: 3,
      );

      final PassiveAggregatedResult result = aggregator.result;
      expect(result.verdict, PassiveVerdict.pending);
      expect(result.sampleCount, 0);
      expect(result.meanScore, 0.0);
      expect(result.passingRatio, 0.0);
      expect(result.samples, isEmpty);
    });

    test('single good frame never passes alone (pending verdict)', () {
      final PassiveAggregator aggregator = PassiveAggregator(
        passiveThreshold: 0.85,
        passingFrameRatio: 0.75,
        minSamples: 3,
      );

      aggregator.addSample(
        PassiveSample(
          timestamp: DateTime.now(),
          meanScore: 0.98,
          modelScores: const <String, double>{'MiniFASNetV2': 0.98},
          latencyMs: 25.0,
        ),
      );

      final PassiveAggregatedResult result = aggregator.result;
      expect(result.verdict, PassiveVerdict.pending);
      expect(result.sampleCount, 1);
      expect(result.meanScore, 0.98);
      expect(result.passingRatio, 1.0);
    });

    test('single bad frame does not decide alone when majority passes', () {
      final PassiveAggregator aggregator = PassiveAggregator(
        passiveThreshold: 0.85,
        passingFrameRatio: 0.75,
        minSamples: 3,
      );

      final DateTime now = DateTime.now();
      // 3 frames at 0.95, 1 frame at 0.70 (below 0.85)
      // Total 4 frames:
      // Passing ratio = 3 / 4 = 75% (meets 75% ratio)
      // Mean = (0.95 * 3 + 0.70) / 4 = (2.85 + 0.70) / 4 = 3.55 / 4 = 0.8875 >= 0.85
      aggregator.addSample(
        PassiveSample(
          timestamp: now,
          meanScore: 0.95,
          modelScores: const <String, double>{'MiniFASNetV2': 0.95},
          latencyMs: 20.0,
        ),
      );
      aggregator.addSample(
        PassiveSample(
          timestamp: now,
          meanScore: 0.95,
          modelScores: const <String, double>{'MiniFASNetV2': 0.95},
          latencyMs: 20.0,
        ),
      );
      aggregator.addSample(
        PassiveSample(
          timestamp: now,
          meanScore: 0.95,
          modelScores: const <String, double>{'MiniFASNetV2': 0.95},
          latencyMs: 20.0,
        ),
      );
      aggregator.addSample(
        PassiveSample(
          timestamp: now,
          meanScore: 0.70,
          modelScores: const <String, double>{'MiniFASNetV2': 0.70},
          latencyMs: 20.0,
        ),
      );

      final PassiveAggregatedResult result = aggregator.result;
      expect(result.sampleCount, 4);
      expect(result.passingRatio, equals(0.75));
      expect(result.meanScore, closeTo(0.8875, 0.0001));
      expect(result.verdict, PassiveVerdict.passed);
    });

    test('fails ratio rule when passing frame ratio is below 75 percent', () {
      final PassiveAggregator aggregator = PassiveAggregator(
        passiveThreshold: 0.85,
        passingFrameRatio: 0.75,
        minSamples: 3,
      );

      final DateTime now = DateTime.now();
      // 2 frames at 0.99, 2 frames at 0.80
      // Mean = (0.99 * 2 + 0.80 * 2) / 4 = 3.58 / 4 = 0.895 >= 0.85 (Mean passes!)
      // But passing count = 2 / 4 = 50% < 75% (Ratio fails!)
      for (int i = 0; i < 2; i++) {
        aggregator.addSample(
          PassiveSample(
            timestamp: now,
            meanScore: 0.99,
            modelScores: const <String, double>{'MiniFASNetV2': 0.99},
            latencyMs: 20.0,
          ),
        );
      }
      for (int i = 0; i < 2; i++) {
        aggregator.addSample(
          PassiveSample(
            timestamp: now,
            meanScore: 0.80,
            modelScores: const <String, double>{'MiniFASNetV2': 0.80},
            latencyMs: 20.0,
          ),
        );
      }

      final PassiveAggregatedResult result = aggregator.result;
      expect(result.meanScore, greaterThanOrEqualTo(0.85));
      expect(result.passingRatio, equals(0.50));
      expect(result.verdict, PassiveVerdict.failed);
    });

    test(
      'fails mean rule when ratio passes but mean score drops below threshold',
      () {
        final PassiveAggregator aggregator = PassiveAggregator(
          passiveThreshold: 0.85,
          passingFrameRatio: 0.75,
          minSamples: 4,
        );

        final DateTime now = DateTime.now();
        // 3 frames at 0.86 (above 0.85) -> ratio = 3/4 = 75% (Ratio passes!)
        // 1 frame at 0.10 (severe drop)
        // Mean = (0.86 * 3 + 0.10) / 4 = (2.58 + 0.10) / 4 = 2.68 / 4 = 0.67 < 0.85 (Mean fails!)
        for (int i = 0; i < 3; i++) {
          aggregator.addSample(
            PassiveSample(
              timestamp: now,
              meanScore: 0.86,
              modelScores: const <String, double>{'MiniFASNetV2': 0.86},
              latencyMs: 20.0,
            ),
          );
        }
        aggregator.addSample(
          PassiveSample(
            timestamp: now,
            meanScore: 0.10,
            modelScores: const <String, double>{'MiniFASNetV2': 0.10},
            latencyMs: 20.0,
          ),
        );

        final PassiveAggregatedResult result = aggregator.result;
        expect(result.passingRatio, equals(0.75));
        expect(result.meanScore, lessThan(0.85));
        expect(result.verdict, PassiveVerdict.failed);
      },
    );

    test('reset clears all samples and restores pending state', () {
      final PassiveAggregator aggregator = PassiveAggregator(
        passiveThreshold: 0.85,
        passingFrameRatio: 0.75,
        minSamples: 3,
      );

      final DateTime now = DateTime.now();
      for (int i = 0; i < 5; i++) {
        aggregator.addSample(
          PassiveSample(
            timestamp: now,
            meanScore: 0.95,
            modelScores: const <String, double>{'MiniFASNetV2': 0.95},
            latencyMs: 20.0,
          ),
        );
      }
      expect(aggregator.result.verdict, PassiveVerdict.passed);

      aggregator.reset();
      expect(aggregator.sampleCount, 0);
      expect(aggregator.result.verdict, PassiveVerdict.pending);
    });
  });
}
