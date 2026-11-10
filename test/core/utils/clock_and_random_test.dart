import 'package:attendence/core/utils/clock.dart';
import 'package:attendence/core/utils/math_utils.dart';
import 'package:attendence/core/utils/random_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Clock', () {
    test('SystemClock returns a valid non-null DateTime', () {
      const SystemClock clock = SystemClock();
      final DateTime now = clock.now();
      expect(now.year, greaterThanOrEqualTo(2024));
    });

    test('FakeClock allows deterministic time control', () {
      final DateTime fixed = DateTime(2025, 1, 1, 12, 0, 0);
      final FakeClock fake = FakeClock(fixed);
      expect(fake.now(), fixed);

      final DateTime advanced = fixed.add(const Duration(minutes: 5));
      fake.currentTime = advanced;
      expect(fake.now(), advanced);
    });
  });

  group('RandomSource', () {
    test('SecureRandomSource generates values in expected ranges', () {
      final SecureRandomSource random = SecureRandomSource();
      final int intVal = random.nextInt(10);
      expect(intVal, inInclusiveRange(0, 9));

      final double doubleVal = random.nextDouble();
      expect(doubleVal, inInclusiveRange(0.0, 1.0));

      expect(random.nextBool(), isA<bool>());
    });

    test('FakeRandomSource allows deterministic output', () {
      final FakeRandomSource fake = FakeRandomSource(
        intVal: 3,
        doubleVal: 0.75,
        boolVal: false,
      );
      expect(fake.nextInt(10), 3);
      expect(fake.nextDouble(), 0.75);
      expect(fake.nextBool(), isFalse);
    });
  });

  group('MathUtils', () {
    test('l2Norm calculates accurate norm', () {
      expect(MathUtils.l2Norm(const <double>[3.0, 4.0]), closeTo(5.0, 1e-6));
      expect(MathUtils.l2Norm(const <double>[0.0, 0.0, 0.0]), 0.0);
    });

    test('l2Normalize yields unit vector', () {
      final List<double> normalized = MathUtils.l2Normalize(const <double>[
        3.0,
        4.0,
      ]);
      expect(MathUtils.l2Norm(normalized), closeTo(1.0, 1e-6));
      expect(normalized[0], closeTo(0.6, 1e-6));
      expect(normalized[1], closeTo(0.8, 1e-6));

      final List<double> zeroNorm = MathUtils.l2Normalize(const <double>[
        0.0,
        0.0,
      ]);
      expect(zeroNorm, equals(const <double>[0.0, 0.0]));
    });

    test('cosineSimilarity calculates cosine angle correctly', () {
      // Parallel vectors: 1.0
      expect(
        MathUtils.cosineSimilarity(
          const <double>[1.0, 0.0],
          const <double>[2.0, 0.0],
        ),
        closeTo(1.0, 1e-6),
      );

      // Orthogonal vectors: 0.0
      expect(
        MathUtils.cosineSimilarity(
          const <double>[1.0, 0.0],
          const <double>[0.0, 1.0],
        ),
        closeTo(0.0, 1e-6),
      );

      // Opposite vectors: -1.0
      expect(
        MathUtils.cosineSimilarity(
          const <double>[1.0, 0.0],
          const <double>[-1.0, 0.0],
        ),
        closeTo(-1.0, 1e-6),
      );

      // Dimension mismatch returns 0.0
      expect(
        MathUtils.cosineSimilarity(
          const <double>[1.0, 0.0],
          const <double>[1.0, 0.0, 0.0],
        ),
        0.0,
      );
    });

    test('softmax outputs sum to 1.0 and preserve ranking', () {
      final List<double> logits = const <double>[1.0, 2.0, 3.0];
      final List<double> probs = MathUtils.softmax(logits);

      expect(probs.length, 3);
      final double sum = probs.reduce((double a, double b) => a + b);
      expect(sum, closeTo(1.0, 1e-6));
      expect(probs[2], greaterThan(probs[1]));
      expect(probs[1], greaterThan(probs[0]));
    });

    test('clamp restricts to [min, max]', () {
      expect(MathUtils.clamp(5.0, 0.0, 10.0), 5.0);
      expect(MathUtils.clamp(-5.0, 0.0, 10.0), 0.0);
      expect(MathUtils.clamp(15.0, 0.0, 10.0), 10.0);
    });
  });
}
