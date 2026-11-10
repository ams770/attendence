import 'dart:math';

/// Abstraction over random generation for deterministic testing.
abstract class RandomSource {
  int nextInt(int max);
  double nextDouble();
  bool nextBool();
}

/// Cryptographically secure implementation using [Random.secure].
class SecureRandomSource implements RandomSource {
  SecureRandomSource([Random? random]) : _random = random ?? Random.secure();

  final Random _random;

  @override
  int nextInt(int max) => _random.nextInt(max);

  @override
  double nextDouble() => _random.nextDouble();

  @override
  bool nextBool() => _random.nextBool();
}

/// Test double random source with configurable or sequenced values.
class FakeRandomSource implements RandomSource {
  FakeRandomSource({
    this.intVal = 0,
    this.doubleVal = 0.5,
    this.boolVal = true,
    List<double>? sequence,
  }) : _doubleSequence = sequence;

  int intVal;
  double doubleVal;
  bool boolVal;
  final List<double>? _doubleSequence;
  int _doubleIndex = 0;

  @override
  int nextInt(int max) => intVal % max;

  @override
  double nextDouble() {
    if (_doubleSequence != null && _doubleSequence.isNotEmpty) {
      final double val = _doubleSequence[_doubleIndex % _doubleSequence.length];
      _doubleIndex++;
      return val;
    }
    return doubleVal;
  }

  @override
  bool nextBool() => boolVal;
}
