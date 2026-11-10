import 'package:attendence/features/liveness/domain/flash_color.dart';
import 'package:attendence/features/liveness/domain/flash_config.dart';
import 'package:attendence/features/liveness/domain/flash_evaluator.dart';
import 'package:attendence/features/liveness/domain/flash_sample.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlashEvaluator', () {
    const FlashEvaluator evaluator = FlashEvaluator(
      config: FlashConfig(
        correlationThreshold: 0.35,
        minBrightness: 30.0,
        maxBrightness: 220.0,
      ),
    );

    final DateTime baseTime = DateTime(2026, 11, 7, 10, 0, 0);

    test('correlated reflection shifts pass flash evaluation', () {
      final SkinColorSample baseline = SkinColorSample(
        meanR: 120.0,
        meanG: 100.0,
        meanB: 90.0,
        brightness: 105.0,
        timestamp: baseTime,
      );

      // Red step illuminates skin with red
      final FlashStepRecord redStep = FlashStepRecord(
        color: FlashColor.red,
        sample: SkinColorSample(
          meanR: 155.0,
          meanG: 95.0,
          meanB: 85.0,
          brightness: 110.0,
          timestamp: baseTime.add(const Duration(milliseconds: 350)),
        ),
      );

      // Green step illuminates skin with green
      final FlashStepRecord greenStep = FlashStepRecord(
        color: FlashColor.green,
        sample: SkinColorSample(
          meanR: 115.0,
          meanG: 135.0,
          meanB: 85.0,
          brightness: 112.0,
          timestamp: baseTime.add(const Duration(milliseconds: 700)),
        ),
      );

      // Blue step illuminates skin with blue
      final FlashStepRecord blueStep = FlashStepRecord(
        color: FlashColor.blue,
        sample: SkinColorSample(
          meanR: 115.0,
          meanG: 95.0,
          meanB: 125.0,
          brightness: 108.0,
          timestamp: baseTime.add(const Duration(milliseconds: 1050)),
        ),
      );

      final FlashEvaluationResult result = evaluator.evaluate(
        baseline: baseline,
        steps: <FlashStepRecord>[redStep, greenStep, blueStep],
      );

      expect(result.verdict, FlashVerdict.passed);
      expect(result.correlation, greaterThan(0.70));
    });

    test('uncorrelated constant reflection fails flash evaluation', () {
      final SkinColorSample baseline = SkinColorSample(
        meanR: 120.0,
        meanG: 100.0,
        meanB: 90.0,
        brightness: 105.0,
        timestamp: baseTime,
      );

      // Replayed video or flat photo where screen flash does not modulate face color
      final List<FlashStepRecord> steps = <FlashStepRecord>[
        FlashStepRecord(
          color: FlashColor.red,
          sample: SkinColorSample(
            meanR: 120.5,
            meanG: 99.8,
            meanB: 90.1,
            brightness: 105.0,
            timestamp: baseTime.add(const Duration(milliseconds: 350)),
          ),
        ),
        FlashStepRecord(
          color: FlashColor.green,
          sample: SkinColorSample(
            meanR: 119.8,
            meanG: 100.2,
            meanB: 89.9,
            brightness: 105.0,
            timestamp: baseTime.add(const Duration(milliseconds: 700)),
          ),
        ),
        FlashStepRecord(
          color: FlashColor.blue,
          sample: SkinColorSample(
            meanR: 120.1,
            meanG: 100.0,
            meanB: 90.3,
            brightness: 105.0,
            timestamp: baseTime.add(const Duration(milliseconds: 1050)),
          ),
        ),
      ];

      final FlashEvaluationResult result = evaluator.evaluate(
        baseline: baseline,
        steps: steps,
      );

      expect(result.verdict, isNot(FlashVerdict.passed));
      expect(result.correlation, lessThan(0.35));
    });

    test(
      'inverted color reflection produces negative correlation and fails',
      () {
        final SkinColorSample baseline = SkinColorSample(
          meanR: 100.0,
          meanG: 100.0,
          meanB: 100.0,
          brightness: 100.0,
          timestamp: baseTime,
        );

        // Opposing colors (red flash causes blue rise, etc.)
        final List<FlashStepRecord> steps = <FlashStepRecord>[
          FlashStepRecord(
            color: FlashColor.red,
            sample: SkinColorSample(
              meanR: 80.0,
              meanG: 80.0,
              meanB: 140.0,
              brightness: 100.0,
              timestamp: baseTime.add(const Duration(milliseconds: 350)),
            ),
          ),
          FlashStepRecord(
            color: FlashColor.green,
            sample: SkinColorSample(
              meanR: 140.0,
              meanG: 80.0,
              meanB: 80.0,
              brightness: 100.0,
              timestamp: baseTime.add(const Duration(milliseconds: 700)),
            ),
          ),
          FlashStepRecord(
            color: FlashColor.blue,
            sample: SkinColorSample(
              meanR: 80.0,
              meanG: 140.0,
              meanB: 80.0,
              brightness: 100.0,
              timestamp: baseTime.add(const Duration(milliseconds: 1050)),
            ),
          ),
        ];

        final FlashEvaluationResult result = evaluator.evaluate(
          baseline: baseline,
          steps: steps,
        );

        expect(result.verdict, FlashVerdict.failed);
        expect(result.correlation, lessThan(0.0));
      },
    );

    test('skips evaluation when ambient light is too dark', () {
      final SkinColorSample darkBaseline = SkinColorSample(
        meanR: 15.0,
        meanG: 12.0,
        meanB: 10.0,
        brightness: 12.5,
        timestamp: baseTime,
      );

      final FlashEvaluationResult result = evaluator.evaluate(
        baseline: darkBaseline,
        steps: const <FlashStepRecord>[],
      );

      expect(result.verdict, FlashVerdict.skipped);
      expect(result.skipReason, FlashSkipReason.ambientTooDark);
    });

    test('skips evaluation when ambient light is saturated / too bright', () {
      final SkinColorSample brightBaseline = SkinColorSample(
        meanR: 240.0,
        meanG: 235.0,
        meanB: 230.0,
        brightness: 236.0,
        timestamp: baseTime,
      );

      final FlashEvaluationResult result = evaluator.evaluate(
        baseline: brightBaseline,
        steps: const <FlashStepRecord>[],
      );

      expect(result.verdict, FlashVerdict.skipped);
      expect(result.skipReason, FlashSkipReason.ambientTooBright);
    });

    test('skips evaluation when step count is insufficient (< 2)', () {
      final SkinColorSample baseline = SkinColorSample(
        meanR: 120.0,
        meanG: 100.0,
        meanB: 90.0,
        brightness: 105.0,
        timestamp: baseTime,
      );

      final FlashEvaluationResult result = evaluator.evaluate(
        baseline: baseline,
        steps: <FlashStepRecord>[
          FlashStepRecord(color: FlashColor.red, sample: baseline),
        ],
      );

      expect(result.verdict, FlashVerdict.skipped);
      expect(result.skipReason, FlashSkipReason.insufficientSamples);
    });
  });
}
