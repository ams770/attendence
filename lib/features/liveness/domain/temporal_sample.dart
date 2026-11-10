/// A 2D point representation in pure Dart for temporal calculations.
class TemporalPoint {
  const TemporalPoint(this.x, this.y);

  final double x;
  final double y;

  double distanceTo(TemporalPoint other) {
    final double dx = x - other.x;
    final double dy = y - other.y;
    return (dx * dx + dy * dy);
  }
}

/// The five canonical facial landmarks formatted for temporal analysis.
class TemporalLandmarks {
  const TemporalLandmarks({
    required this.leftEye,
    required this.rightEye,
    required this.noseBase,
    required this.leftMouth,
    required this.rightMouth,
  });

  final TemporalPoint leftEye;
  final TemporalPoint rightEye;
  final TemporalPoint noseBase;
  final TemporalPoint leftMouth;
  final TemporalPoint rightMouth;

  List<TemporalPoint> get asList => <TemporalPoint>[
    leftEye,
    rightEye,
    noseBase,
    leftMouth,
    rightMouth,
  ];
}

/// Frame telemetry sample containing landmarks, bounding box, pose, and timestamp.
class TemporalFrameSample {
  const TemporalFrameSample({
    required this.landmarks,
    required this.boxLeft,
    required this.boxTop,
    required this.boxWidth,
    required this.boxHeight,
    required this.yaw,
    required this.pitch,
    required this.timestamp,
  });

  final TemporalLandmarks landmarks;
  final double boxLeft;
  final double boxTop;
  final double boxWidth;
  final double boxHeight;
  final double yaw;
  final double pitch;
  final DateTime timestamp;
}
