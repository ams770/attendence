import 'package:attendence/core/utils/random_source.dart';
import 'package:attendence/features/liveness/domain/challenge_selector.dart';
import 'package:attendence/features/liveness/domain/challenge_type.dart';
import 'package:flutter_test/flutter_test.dart';

class _SequenceRandomSource implements RandomSource {
  _SequenceRandomSource(this.sequence);

  final List<int> sequence;
  int _index = 0;

  @override
  int nextInt(int max) {
    if (_index >= sequence.length) {
      _index = 0;
    }
    final int val = sequence[_index++];
    return val % max;
  }

  @override
  double nextDouble() => 0.5;

  @override
  bool nextBool() => true;
}

void main() {
  group('ChallengeSelector', () {
    test('always prepends lookStraight as the first calibration challenge', () {
      final RandomSource random = _SequenceRandomSource(<int>[0, 1]);
      final ChallengeSelector selector = ChallengeSelector(
        randomSource: random,
      );

      final List<ChallengeType> sequence = selector.selectChallenges(count: 2);
      expect(sequence.first, ChallengeType.lookStraight);
      expect(sequence.length, 3);
    });

    test('never repeats a challenge within the same session', () {
      final RandomSource random = SecureRandomSource();
      final ChallengeSelector selector = ChallengeSelector(
        randomSource: random,
      );

      for (int i = 0; i < 50; i++) {
        final List<ChallengeType> sequence = selector.selectChallenges(
          count: 3,
        );
        expect(sequence.first, ChallengeType.lookStraight);

        final List<ChallengeType> activeChallenges = sequence.sublist(1);
        final Set<ChallengeType> unique = activeChallenges.toSet();
        expect(unique.length, activeChallenges.length);
      }
    });

    test('produces deterministic selection with controlled random source', () {
      final RandomSource random1 = _SequenceRandomSource(<int>[1, 2]);
      final RandomSource random2 = _SequenceRandomSource(<int>[1, 2]);

      final ChallengeSelector sel1 = ChallengeSelector(randomSource: random1);
      final ChallengeSelector sel2 = ChallengeSelector(randomSource: random2);

      final List<ChallengeType> seq1 = sel1.selectChallenges(count: 2);
      final List<ChallengeType> seq2 = sel2.selectChallenges(count: 2);

      expect(seq1, equals(seq2));
    });

    test('throws ArgumentError if requested count is out of range', () {
      final RandomSource random = _SequenceRandomSource(<int>[0]);
      final ChallengeSelector selector = ChallengeSelector(
        randomSource: random,
      );

      expect(() => selector.selectChallenges(count: 0), throwsArgumentError);
      expect(() => selector.selectChallenges(count: 5), throwsArgumentError);
    });
  });
}
