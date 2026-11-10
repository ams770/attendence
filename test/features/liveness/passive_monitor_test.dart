import 'package:attendence/features/liveness/domain/passive_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PassiveMonitor', () {
    test('normal high scores do not trigger violation', () {
      final PassiveMonitor monitor = PassiveMonitor(
        windowSize: 3,
        hardFloor: 0.40,
      );

      expect(monitor.sampleCount, 0);
      expect(monitor.rollingAverage, isNull);
      expect(monitor.isCompromised, isFalse);

      monitor.addSample(0.92);
      monitor.addSample(0.88);
      monitor.addSample(0.95);

      expect(monitor.sampleCount, 3);
      expect(monitor.rollingAverage, closeTo((0.92 + 0.88 + 0.95) / 3, 0.001));
      expect(monitor.isCompromised, isFalse);
    });

    test(
      'does not flag compromised when fewer than windowSize samples exist',
      () {
        final PassiveMonitor monitor = PassiveMonitor(
          windowSize: 3,
          hardFloor: 0.40,
        );

        // Single very low sample
        monitor.addSample(0.10);
        expect(monitor.isCompromised, isFalse);

        // Two low samples (windowSize is 3)
        monitor.addSample(0.15);
        expect(monitor.isCompromised, isFalse);
      },
    );

    test(
      'rolling average dropping below hard floor triggers isCompromised',
      () {
        final PassiveMonitor monitor = PassiveMonitor(
          windowSize: 3,
          hardFloor: 0.40,
        );

        // 3 low scores representing a swapped photo or spoof
        monitor.addSample(0.20);
        monitor.addSample(0.25);
        monitor.addSample(0.30);

        expect(monitor.sampleCount, 3);
        expect(monitor.rollingAverage, closeTo(0.25, 0.001));
        expect(monitor.isCompromised, isTrue);
      },
    );

    test('sliding window pushes out old samples as new ones arrive', () {
      final PassiveMonitor monitor = PassiveMonitor(
        windowSize: 3,
        hardFloor: 0.40,
      );

      // 3 low scores -> compromised
      monitor.addSample(0.10);
      monitor.addSample(0.10);
      monitor.addSample(0.10);
      expect(monitor.isCompromised, isTrue);

      // Add 3 high scores -> window now holds only high scores
      monitor.addSample(0.90);
      monitor.addSample(0.90);
      monitor.addSample(0.90);

      expect(monitor.sampleCount, 3);
      expect(monitor.rollingAverage, closeTo(0.90, 0.001));
      expect(monitor.isCompromised, isFalse);
    });

    test('reset clears window and violation status', () {
      final PassiveMonitor monitor = PassiveMonitor(
        windowSize: 3,
        hardFloor: 0.40,
      );

      monitor.addSample(0.10);
      monitor.addSample(0.10);
      monitor.addSample(0.10);
      expect(monitor.isCompromised, isTrue);

      monitor.reset();
      expect(monitor.sampleCount, 0);
      expect(monitor.rollingAverage, isNull);
      expect(monitor.isCompromised, isFalse);
    });
  });
}
