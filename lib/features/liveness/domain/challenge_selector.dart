import '../../../core/utils/random_source.dart';
import 'challenge_type.dart';

/// Selects a randomized active challenge sequence for a verification session.
///
/// Guaranteed to always prepend [ChallengeType.lookStraight] as the first
/// calibration step, followed by N distinct active challenges selected from the
/// available pool using an injected [RandomSource].
class ChallengeSelector {
  const ChallengeSelector({required this.randomSource});

  final RandomSource randomSource;

  /// The pool of active challenges available for random selection.
  static const List<ChallengeType> activePool = <ChallengeType>[
    ChallengeType.blink,
    ChallengeType.turnLeft,
    ChallengeType.turnRight,
    ChallengeType.smile,
  ];

  /// Selects [count] unique challenges from [activePool] and prepends [ChallengeType.lookStraight].
  ///
  /// Guarantees that no challenge is repeated within a single session.
  List<ChallengeType> selectChallenges({int count = 2}) {
    if (count < 1 || count > activePool.length) {
      throw ArgumentError.value(
        count,
        'count',
        'Must be between 1 and ${activePool.length}',
      );
    }

    // Fisher-Yates partial shuffle of the active pool
    final List<ChallengeType> poolCopy = List<ChallengeType>.from(activePool);
    final List<ChallengeType> selected = <ChallengeType>[];

    for (int i = 0; i < count; i++) {
      final int chosenIndex = i + randomSource.nextInt(poolCopy.length - i);
      final ChallengeType chosen = poolCopy[chosenIndex];
      poolCopy[chosenIndex] = poolCopy[i];
      poolCopy[i] = chosen;
      selected.add(chosen);
    }

    return <ChallengeType>[ChallengeType.lookStraight, ...selected];
  }
}
