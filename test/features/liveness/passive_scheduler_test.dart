import 'package:attendence/features/liveness/domain/passive_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PassiveScheduler', () {
    test('enforces minimum interval between consecutive frame samples', () {
      final PassiveScheduler scheduler = PassiveScheduler(
        targetTotalSamples: 8,
        minSampleInterval: const Duration(milliseconds: 300),
      );

      // First sample at 0ms should be allowed
      expect(
        scheduler.shouldSample(
          phase: SessionPhase.neutral,
          phaseElapsed: Duration.zero,
          totalElapsed: Duration.zero,
        ),
        isTrue,
      );
      scheduler.recordSample(
        phase: SessionPhase.neutral,
        totalElapsed: Duration.zero,
      );

      // 100ms later (too fast, less than 300ms) -> should be rejected
      expect(
        scheduler.shouldSample(
          phase: SessionPhase.neutral,
          phaseElapsed: const Duration(milliseconds: 100),
          totalElapsed: const Duration(milliseconds: 100),
        ),
        isFalse,
      );

      // 250ms later -> still rejected
      expect(
        scheduler.shouldSample(
          phase: SessionPhase.neutral,
          phaseElapsed: const Duration(milliseconds: 250),
          totalElapsed: const Duration(milliseconds: 250),
        ),
        isFalse,
      );

      // 300ms later -> allowed
      expect(
        scheduler.shouldSample(
          phase: SessionPhase.neutral,
          phaseElapsed: const Duration(milliseconds: 300),
          totalElapsed: const Duration(milliseconds: 300),
        ),
        isTrue,
      );
    });

    test('distributes samples across neutral, challenge, and final phases', () {
      // Target total samples = 8
      // neutral target = max(1, (8 * 0.25).round()) = 2
      // final target = max(1, (8 * 0.25).round()) = 2
      // challenge target = 8 - 2 - 2 = 4
      final PassiveScheduler scheduler = PassiveScheduler(
        targetTotalSamples: 8,
        minSampleInterval: const Duration(milliseconds: 200),
      );

      expect(scheduler.targetForPhase(SessionPhase.neutral), 2);
      expect(scheduler.targetForPhase(SessionPhase.challenge), 4);
      expect(scheduler.targetForPhase(SessionPhase.finalPhase), 2);

      // Neutral phase: samples 2 frames
      scheduler.recordSample(
        phase: SessionPhase.neutral,
        totalElapsed: const Duration(milliseconds: 200),
      );
      scheduler.recordSample(
        phase: SessionPhase.neutral,
        totalElapsed: const Duration(milliseconds: 400),
      );

      // 3rd sample in neutral should be rejected (quota for neutral is 2)
      expect(
        scheduler.shouldSample(
          phase: SessionPhase.neutral,
          phaseElapsed: const Duration(milliseconds: 600),
          totalElapsed: const Duration(milliseconds: 600),
        ),
        isFalse,
      );

      // But entering challenge phase should be allowed!
      expect(
        scheduler.shouldSample(
          phase: SessionPhase.challenge,
          phaseElapsed: Duration.zero,
          totalElapsed: const Duration(milliseconds: 600),
        ),
        isTrue,
      );

      // Challenge phase records 4 samples
      for (int i = 0; i < 4; i++) {
        scheduler.recordSample(
          phase: SessionPhase.challenge,
          totalElapsed: Duration(milliseconds: 800 + i * 200),
        );
      }

      // 5th sample in challenge should be rejected
      expect(
        scheduler.shouldSample(
          phase: SessionPhase.challenge,
          phaseElapsed: const Duration(milliseconds: 1000),
          totalElapsed: const Duration(milliseconds: 1600),
        ),
        isFalse,
      );

      // Entering final phase is allowed
      expect(
        scheduler.shouldSample(
          phase: SessionPhase.finalPhase,
          phaseElapsed: Duration.zero,
          totalElapsed: const Duration(milliseconds: 1600),
        ),
        isTrue,
      );

      // Final phase records 2 samples
      scheduler.recordSample(
        phase: SessionPhase.finalPhase,
        totalElapsed: const Duration(milliseconds: 1800),
      );
      scheduler.recordSample(
        phase: SessionPhase.finalPhase,
        totalElapsed: const Duration(milliseconds: 2000),
      );

      // Now all 8 samples recorded -> no further sampling anywhere
      expect(scheduler.totalSamplesRecorded, 8);
      expect(
        scheduler.shouldSample(
          phase: SessionPhase.finalPhase,
          phaseElapsed: const Duration(milliseconds: 500),
          totalElapsed: const Duration(milliseconds: 2500),
        ),
        isFalse,
      );
    });

    test('reset clears counts and restores initial state', () {
      final PassiveScheduler scheduler = PassiveScheduler(
        targetTotalSamples: 5,
        minSampleInterval: const Duration(milliseconds: 100),
      );

      scheduler.recordSample(
        phase: SessionPhase.neutral,
        totalElapsed: const Duration(milliseconds: 100),
      );
      expect(scheduler.totalSamplesRecorded, 1);

      scheduler.reset();
      expect(scheduler.totalSamplesRecorded, 0);
      expect(scheduler.sampleCountForPhase(SessionPhase.neutral), 0);
    });
  });
}
