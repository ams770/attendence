import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import 'detected_face.dart';
import 'face_stats.dart';
import 'oval_guide.dart';
import 'preview_mapper.dart';

/// Quality issues detected during face detection and quality assessment.
enum QualityIssue {
  noFace,
  multipleFaces,
  tooSmall,
  notInsideGuide,
  poseOutOfRange,
  landmarksMissing,
  tooBlurry,
  tooDark,
  tooBright,
  glare,
}

/// Comprehensive quality check result.
@immutable
class QualityResult {
  const QualityResult({required this.issues, this.faceStats, this.face});

  /// All identified quality issues (empty if frame passed all checks).
  final List<QualityIssue> issues;

  /// Measured face crop statistics (sharpness, brightness, glare).
  final FaceStats? faceStats;

  /// The evaluated single face, if present.
  final DetectedFace? face;

  /// Whether the frame meets all quality thresholds and is suitable for recognition.
  bool get isPass => issues.isEmpty;

  /// The most significant issue to display as immediate user guidance.
  QualityIssue? get primaryIssue => issues.isNotEmpty ? issues.first : null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QualityResult &&
        listEquals(other.issues, issues) &&
        other.faceStats == faceStats &&
        other.face == face;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(issues), faceStats, face);

  @override
  String toString() =>
      'QualityResult(pass: $isPass, primary: $primaryIssue, issues: $issues)';
}

/// Quality gate validating face detection, framing, pose, and photometric quality.
class QualityGate {
  const QualityGate();

  /// Evaluates detected faces against the configured quality criteria.
  QualityResult evaluate({
    required List<DetectedFace> faces,
    required Size previewSize,
    required Rect ovalRect,
    required PreviewMapper previewMapper,
    required AppConfig config,
    FaceStats? faceStats,
    bool checkPose = true,
    double? cornerTolerance,
    double? cardinalTolerance,
  }) {
    final List<QualityIssue> issues = <QualityIssue>[];

    // 1. Face presence check
    if (faces.isEmpty) {
      issues.add(QualityIssue.noFace);
      return QualityResult(issues: issues, faceStats: faceStats);
    }

    // 2. Multiple faces check (exactly one face allowed)
    if (faces.length > 1) {
      issues.add(QualityIssue.multipleFaces);
      return QualityResult(issues: issues, faceStats: faceStats);
    }

    final DetectedFace face = faces.first;

    // 3. Size check: face width must be >= qualityMinFaceWidthRatio of preview width
    final Rect previewFaceBox = previewMapper.mapRect(face.boundingBox);
    final double widthRatio = previewFaceBox.width / previewSize.width;
    if (widthRatio < config.qualityMinFaceWidthRatio) {
      issues.add(QualityIssue.tooSmall);
    }

    // 4. Position check: bounding box must be comfortably inside oval guide
    if (!isFaceInsideOval(
      previewFaceBox,
      ovalRect,
      cornerTolerance: cornerTolerance ?? config.ovalCornerTolerance,
      cardinalTolerance: cardinalTolerance ?? config.ovalCardinalTolerance,
    )) {
      issues.add(QualityIssue.notInsideGuide);
    }

    // 5. Pose check: yaw, pitch, roll
    if (checkPose) {
      final double yawAbs = (face.yaw ?? 0.0).abs();
      final double pitchAbs = (face.pitch ?? 0.0).abs();
      final double rollAbs = (face.roll ?? 0.0).abs();

      if (yawAbs > config.qualityMaxYaw ||
          pitchAbs > config.qualityMaxPitch ||
          rollAbs > config.qualityMaxRoll) {
        issues.add(QualityIssue.poseOutOfRange);
      }
    }

    // 6. Landmark presence
    if (!face.hasAllLandmarks) {
      issues.add(QualityIssue.landmarksMissing);
    }

    // 7. Photometric stats check (sharpness, brightness, glare)
    if (faceStats != null) {
      if (faceStats.meanBrightness < config.qualityMinBrightness) {
        issues.add(QualityIssue.tooDark);
      } else if (faceStats.meanBrightness > config.qualityMaxBrightness) {
        issues.add(QualityIssue.tooBright);
      }

      if (faceStats.nearSaturatedRatio > config.qualityMaxNearSaturatedRatio) {
        issues.add(QualityIssue.glare);
      }

      if (faceStats.sharpness < config.qualityMinSharpness) {
        issues.add(QualityIssue.tooBlurry);
      }
    }

    return QualityResult(issues: issues, faceStats: faceStats, face: face);
  }
}
