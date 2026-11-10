import '../../../core/utils/clock.dart';

/// Throttles incoming camera frames to match target frame rate and worker throughput.
///
/// Guarantees that at most one frame is in flight at any time. Automatically adapts
/// frame rate throttling using an exponential moving average (EMA) of observed
/// processing latency.
class FrameThrottler {
  FrameThrottler({
    required this.clock,
    required double targetFps,
    this.alpha = 0.2,
  }) : assert(targetFps > 0, 'targetFps must be greater than 0'),
       assert(
         alpha > 0.0 && alpha <= 1.0,
         'alpha must be in the range (0.0, 1.0]',
       ),
       _targetFps = targetFps;

  final Clock clock;
  final double alpha;
  double _targetFps;

  bool _isProcessing = false;
  DateTime? _lastDispatchedTime;
  double? _processingDurationEmaMs;

  int _framesReceived = 0;
  int _framesProcessed = 0;
  int _framesDropped = 0;

  /// Target frames per second.
  double get targetFps => _targetFps;

  set targetFps(double fps) {
    assert(fps > 0, 'targetFps must be greater than 0');
    _targetFps = fps;
  }

  /// Whether a frame is currently being processed by the worker.
  bool get isProcessing => _isProcessing;

  /// Exponential moving average of frame processing latency in milliseconds.
  double? get processingDurationEmaMs => _processingDurationEmaMs;

  /// Total frames received since initialization or last reset.
  int get framesReceived => _framesReceived;

  /// Total frames successfully dispatched for processing.
  int get framesProcessed => _framesProcessed;

  /// Total frames dropped due to backpressure or rate limiting.
  int get framesDropped => _framesDropped;

  /// Target interval between frames in microseconds based on [targetFps].
  int get _minIntervalMicros => (1000000.0 / _targetFps).round();

  /// Evaluates whether the incoming frame should be processed or dropped.
  bool shouldProcess() {
    _framesReceived++;

    // Single-frame in flight guarantee.
    if (_isProcessing) {
      _framesDropped++;
      return false;
    }

    if (_lastDispatchedTime != null) {
      final int elapsedMicros = clock
          .now()
          .difference(_lastDispatchedTime!)
          .inMicroseconds;

      int effectiveIntervalMicros = _minIntervalMicros;
      if (_processingDurationEmaMs != null) {
        final int emaMicros = (_processingDurationEmaMs! * 1000.0).round();
        if (emaMicros > effectiveIntervalMicros) {
          effectiveIntervalMicros = emaMicros;
        }
      }

      if (elapsedMicros < effectiveIntervalMicros) {
        _framesDropped++;
        return false;
      }
    }

    return true;
  }

  /// Marks the start of processing for an accepted frame.
  void onFrameStarted() {
    _isProcessing = true;
    _lastDispatchedTime = clock.now();
    _framesProcessed++;
  }

  /// Marks completion of processing and updates the latency EMA.
  void onFrameCompleted(Duration duration) {
    _isProcessing = false;
    final double durMs = duration.inMicroseconds / 1000.0;
    if (_processingDurationEmaMs == null) {
      _processingDurationEmaMs = durMs;
    } else {
      _processingDurationEmaMs =
          alpha * durMs + (1.0 - alpha) * _processingDurationEmaMs!;
    }
  }

  /// Resets all counters and state.
  void reset() {
    _isProcessing = false;
    _lastDispatchedTime = null;
    _processingDurationEmaMs = null;
    _framesReceived = 0;
    _framesProcessed = 0;
    _framesDropped = 0;
  }
}
