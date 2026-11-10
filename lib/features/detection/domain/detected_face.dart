import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../liveness/domain/challenge_type.dart';
import '../../liveness/domain/temporal_sample.dart';

/// The five canonical facial landmarks in upright image coordinates.
///
/// Landmark coordinates are guaranteed to be sorted by horizontal image position:
/// [leftEye].dx <= [rightEye].dx and [leftMouth].dx <= [rightMouth].dx.
@immutable
class FiveLandmarks {
  const FiveLandmarks({
    required this.leftEye,
    required this.rightEye,
    required this.noseBase,
    required this.leftMouth,
    required this.rightMouth,
  });

  /// Left eye position in the upright image (lower x coordinate).
  final Offset leftEye;

  /// Right eye position in the upright image (higher x coordinate).
  final Offset rightEye;

  /// Center base of the nose.
  final Offset noseBase;

  /// Left corner of the mouth in the upright image (lower x coordinate).
  final Offset leftMouth;

  /// Right corner of the mouth in the upright image (higher x coordinate).
  final Offset rightMouth;

  /// Returns the five landmarks as an ordered list matching the standard ArcFace template:
  /// [leftEye, rightEye, noseBase, leftMouth, rightMouth].
  List<Offset> get asList => <Offset>[
    leftEye,
    rightEye,
    noseBase,
    leftMouth,
    rightMouth,
  ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FiveLandmarks &&
        other.leftEye == leftEye &&
        other.rightEye == rightEye &&
        other.noseBase == noseBase &&
        other.leftMouth == leftMouth &&
        other.rightMouth == rightMouth;
  }

  @override
  int get hashCode =>
      Object.hash(leftEye, rightEye, noseBase, leftMouth, rightMouth);

  @override
  String toString() =>
      'FiveLandmarks(L-Eye: $leftEye, R-Eye: $rightEye, Nose: $noseBase, L-Mouth: $leftMouth, R-Mouth: $rightMouth)';
}

/// A face detected by the camera pipeline in upright image coordinates.
@immutable
class DetectedFace implements FaceSample {
  const DetectedFace({
    this.trackingId,
    required this.boundingBox,
    this.headEulerAngleX,
    this.headEulerAngleY,
    this.headEulerAngleZ,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    this.smilingProbability,
    this.landmarks,
  });

  /// Consistent tracking ID across consecutive frames.
  @override
  final int? trackingId;

  /// Axis-aligned bounding box in upright image coordinates.
  final Rect boundingBox;

  /// Pitch angle in degrees (head up / down).
  final double? headEulerAngleX;

  /// Yaw angle in degrees (head turned left / right).
  final double? headEulerAngleY;

  /// Roll angle in degrees (head tilted sideways).
  final double? headEulerAngleZ;

  /// Convenience alias for yaw.
  @override
  double? get yaw => headEulerAngleY;

  /// Convenience alias for pitch.
  @override
  double? get pitch => headEulerAngleX;

  /// Convenience alias for roll.
  @override
  double? get roll => headEulerAngleZ;

  /// Probability that the left eye is open (0.0 to 1.0).
  @override
  final double? leftEyeOpenProbability;

  /// Probability that the right eye is open (0.0 to 1.0).
  @override
  final double? rightEyeOpenProbability;

  /// Probability that the face is smiling (0.0 to 1.0).
  @override
  final double? smilingProbability;

  /// The five canonical facial landmarks. Null if one or more landmarks could not be detected.
  final FiveLandmarks? landmarks;

  /// Whether all five canonical facial landmarks are detected.
  bool get hasAllLandmarks => landmarks != null;

  /// Whether any canonical facial landmark is missing.
  bool get landmarksMissing => landmarks == null;

  /// Rejects faces missing landmarks for recognition purposes.
  bool get isValidForRecognition => hasAllLandmarks;

  /// Converts this detected face into a [TemporalFrameSample] if landmarks exist.
  TemporalFrameSample? toTemporalSample(DateTime timestamp) {
    if (landmarks == null) return null;
    return TemporalFrameSample(
      landmarks: TemporalLandmarks(
        leftEye: TemporalPoint(landmarks!.leftEye.dx, landmarks!.leftEye.dy),
        rightEye: TemporalPoint(landmarks!.rightEye.dx, landmarks!.rightEye.dy),
        noseBase: TemporalPoint(landmarks!.noseBase.dx, landmarks!.noseBase.dy),
        leftMouth: TemporalPoint(
          landmarks!.leftMouth.dx,
          landmarks!.leftMouth.dy,
        ),
        rightMouth: TemporalPoint(
          landmarks!.rightMouth.dx,
          landmarks!.rightMouth.dy,
        ),
      ),
      boxLeft: boundingBox.left,
      boxTop: boundingBox.top,
      boxWidth: boundingBox.width,
      boxHeight: boundingBox.height,
      yaw: yaw ?? 0.0,
      pitch: pitch ?? 0.0,
      timestamp: timestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DetectedFace &&
        other.trackingId == trackingId &&
        other.boundingBox == boundingBox &&
        other.headEulerAngleX == headEulerAngleX &&
        other.headEulerAngleY == headEulerAngleY &&
        other.headEulerAngleZ == headEulerAngleZ &&
        other.leftEyeOpenProbability == leftEyeOpenProbability &&
        other.rightEyeOpenProbability == rightEyeOpenProbability &&
        other.smilingProbability == smilingProbability &&
        other.landmarks == landmarks;
  }

  @override
  int get hashCode => Object.hash(
    trackingId,
    boundingBox,
    headEulerAngleX,
    headEulerAngleY,
    headEulerAngleZ,
    leftEyeOpenProbability,
    rightEyeOpenProbability,
    smilingProbability,
    landmarks,
  );

  @override
  String toString() =>
      'DetectedFace(id: $trackingId, box: $boundingBox, yaw: $yaw, pitch: $pitch, roll: $roll, landmarks: ${hasAllLandmarks ? "5/5" : "missing"})';
}
