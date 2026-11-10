import 'package:attendence/core/utils/clock.dart';
import 'package:attendence/features/camera/domain/frame_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FrameThrottler', () {
    late FakeClock fakeClock;

    setUp(() {
      fakeClock = FakeClock(DateTime(2026, 1, 1, 12, 0, 0));
    });

    test(
      'accepts first frame and rejects concurrent frames while processing',
      () {
        final FrameThrottler throttler = FrameThrottler(
          clock: fakeClock,
          targetFps: 10.0, // 100ms interval
        );

        // First frame accepted
        expect(throttler.shouldProcess(), isTrue);
        throttler.onFrameStarted();
        expect(throttler.isProcessing, isTrue);
        expect(throttler.framesProcessed, equals(1));

        // Second frame arrives while first is still processing -> dropped
        fakeClock.advance(const Duration(milliseconds: 50));
        expect(throttler.shouldProcess(), isFalse);
        expect(throttler.framesDropped, equals(1));

        // Processing completes
        throttler.onFrameCompleted(const Duration(milliseconds: 50));
        expect(throttler.isProcessing, isFalse);
      },
    );

    test('enforces target FPS interval', () {
      final FrameThrottler throttler = FrameThrottler(
        clock: fakeClock,
        targetFps: 10.0, // 100ms min interval
      );

      // Frame 1
      expect(throttler.shouldProcess(), isTrue);
      throttler.onFrameStarted();
      throttler.onFrameCompleted(const Duration(milliseconds: 10));

      // Frame 2 arrives too soon (50ms < 100ms) -> dropped
      fakeClock.advance(const Duration(milliseconds: 50));
      expect(throttler.shouldProcess(), isFalse);

      // Frame 3 arrives after 110ms total -> accepted
      fakeClock.advance(const Duration(milliseconds: 60));
      expect(throttler.shouldProcess(), isTrue);
    });

    test('adapts interval when processing EMA exceeds target FPS interval', () {
      final FrameThrottler throttler = FrameThrottler(
        clock: fakeClock,
        targetFps: 20.0, // 50ms interval
        alpha: 0.5,
      );

      // Frame 1 completes after 100ms (worker is slow)
      expect(throttler.shouldProcess(), isTrue);
      throttler.onFrameStarted();
      throttler.onFrameCompleted(const Duration(milliseconds: 100));
      expect(throttler.processingDurationEmaMs, closeTo(100.0, 1e-3));

      // Frame 2 arrives 60ms later:
      // Even though 60ms > target interval (50ms), adaptive interval is ~100ms -> dropped!
      fakeClock.advance(const Duration(milliseconds: 60));
      expect(throttler.shouldProcess(), isFalse);

      // Frame 3 arrives 105ms after dispatch -> accepted
      fakeClock.advance(const Duration(milliseconds: 45));
      expect(throttler.shouldProcess(), isTrue);
    });

    test('reset clears processing state and counters', () {
      final FrameThrottler throttler = FrameThrottler(
        clock: fakeClock,
        targetFps: 10.0,
      );

      throttler.shouldProcess();
      throttler.onFrameStarted();
      throttler.onFrameCompleted(const Duration(milliseconds: 25));

      expect(throttler.framesProcessed, equals(1));
      expect(throttler.processingDurationEmaMs, isNotNull);

      throttler.reset();

      expect(throttler.isProcessing, isFalse);
      expect(throttler.framesReceived, equals(0));
      expect(throttler.framesProcessed, equals(0));
      expect(throttler.framesDropped, equals(0));
      expect(throttler.processingDurationEmaMs, isNull);
    });
  });
}
