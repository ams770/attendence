/// Abstraction over system time for deterministic testing.
abstract class Clock {
  DateTime now();
}

/// Default system clock implementation delegating to [DateTime.now].
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Test double clock allowing programmatic control over time.
class FakeClock implements Clock {
  FakeClock(this.currentTime);

  DateTime currentTime;

  @override
  DateTime now() => currentTime;

  /// Advances the clock by [duration].
  void advance(Duration duration) {
    currentTime = currentTime.add(duration);
  }
}
