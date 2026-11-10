import 'dart:collection';

/// Continuous passive liveness monitor operating during active challenge phases.
///
/// Maintains a rolling window of the last [windowSize] (K) sampled frame scores.
/// Flags an active violation if the rolling average drops below [hardFloor]
/// (e.g. 0.40), catching attempts to substitute a photo or static screen
/// after completing an initial active challenge.
class PassiveMonitor {
  PassiveMonitor({this.windowSize = 3, required this.hardFloor})
    : assert(windowSize >= 1, 'windowSize must be at least 1'),
      assert(
        hardFloor >= 0.0 && hardFloor <= 1.0,
        'hardFloor must be between 0 and 1',
      );

  /// Number of recent samples (K) included in the rolling window.
  final int windowSize;

  /// Absolute minimum acceptable threshold for the rolling average score.
  final double hardFloor;

  final Queue<double> _window = Queue<double>();

  /// Number of samples currently held in the rolling window.
  int get sampleCount => _window.length;

  /// Arithmetic mean of scores currently held in the rolling window.
  double? get rollingAverage {
    if (_window.isEmpty) return null;
    final double sum = _window.fold<double>(
      0.0,
      (double acc, double s) => acc + s,
    );
    return sum / _window.length;
  }

  /// Whether the rolling average over the last [windowSize] frames has dropped below [hardFloor].
  bool get isCompromised {
    if (_window.length < windowSize) return false;
    final double? avg = rollingAverage;
    if (avg == null) return false;
    return avg < hardFloor;
  }

  /// Adds a new frame score to the rolling window.
  void addSample(double score) {
    _window.addLast(score);
    if (_window.length > windowSize) {
      _window.removeFirst();
    }
  }

  /// Clears the rolling history for a new challenge or session.
  void reset() {
    _window.clear();
  }
}
