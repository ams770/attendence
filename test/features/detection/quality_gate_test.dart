import 'dart:ui';

import 'package:attendence/core/config/app_config.dart';
import 'package:attendence/features/detection/domain/detected_face.dart';
import 'package:attendence/features/detection/domain/face_stats.dart';
import 'package:attendence/features/detection/domain/oval_guide.dart';
import 'package:attendence/features/detection/domain/preview_mapper.dart';
import 'package:attendence/features/detection/domain/quality_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QualityGate', () {
    const QualityGate gate = QualityGate();
    const AppConfig config = AppConfig();

    const Size previewSize = Size(400.0, 800.0);
    const Size imageSize = Size(720.0, 1280.0);
    final Rect ovalRect = defaultOvalRect(previewSize);

    const PreviewMapper mapper = PreviewMapper(
      imageSize: imageSize,
      previewSize: previewSize,
      mirror: true,
    );

    DetectedFace createPassingFace() {
      // In preview, oval is centered at (200, 360), width 280, height 400
      // We want a face box in preview centered at (200, 360), width 160 (ratio 160/400 = 0.40 >= 0.25)
      // Unmap to image coordinates:
      const Rect previewBox = Rect.fromLTWH(120.0, 260.0, 160.0, 200.0);
      final Rect uprightBox = mapper.unmapRect(previewBox);

      return DetectedFace(
        trackingId: 1,
        boundingBox: uprightBox,
        headEulerAngleX: 2.0, // pitch
        headEulerAngleY: -3.0, // yaw
        headEulerAngleZ: 1.0, // roll
        landmarks: const FiveLandmarks(
          leftEye: Offset(200, 400),
          rightEye: Offset(400, 400),
          noseBase: Offset(300, 500),
          leftMouth: Offset(220, 600),
          rightMouth: Offset(380, 600),
        ),
      );
    }

    const FaceStats passingStats = FaceStats(
      sharpness: 120.0,
      meanBrightness: 128.0,
      nearSaturatedRatio: 0.02,
    );

    test('passes when face meets all criteria', () {
      final DetectedFace face = createPassingFace();
      final QualityResult result = gate.evaluate(
        faces: <DetectedFace>[face],
        previewSize: previewSize,
        ovalRect: ovalRect,
        previewMapper: mapper,
        config: config,
        faceStats: passingStats,
      );

      expect(result.isPass, isTrue);
      expect(result.issues, isEmpty);
      expect(result.primaryIssue, isNull);
      expect(result.face, equals(face));
      expect(result.faceStats, equals(passingStats));
    });

    test('flags noFace when faces list is empty', () {
      final QualityResult result = gate.evaluate(
        faces: const <DetectedFace>[],
        previewSize: previewSize,
        ovalRect: ovalRect,
        previewMapper: mapper,
        config: config,
        faceStats: passingStats,
      );

      expect(result.isPass, isFalse);
      expect(result.issues, contains(QualityIssue.noFace));
      expect(result.primaryIssue, equals(QualityIssue.noFace));
    });

    test('flags multipleFaces when more than one face is detected', () {
      final DetectedFace face = createPassingFace();
      final QualityResult result = gate.evaluate(
        faces: <DetectedFace>[face, face],
        previewSize: previewSize,
        ovalRect: ovalRect,
        previewMapper: mapper,
        config: config,
        faceStats: passingStats,
      );

      expect(result.isPass, isFalse);
      expect(result.issues, contains(QualityIssue.multipleFaces));
      expect(result.primaryIssue, equals(QualityIssue.multipleFaces));
    });

    test('flags tooSmall when face width ratio < 0.25', () {
      // Create tiny face: width 40 on 400 preview width (ratio 0.10)
      const Rect previewBox = Rect.fromLTWH(180.0, 340.0, 40.0, 50.0);
      final Rect uprightBox = mapper.unmapRect(previewBox);

      final DetectedFace face = DetectedFace(
        trackingId: 1,
        boundingBox: uprightBox,
        landmarks: const FiveLandmarks(
          leftEye: Offset(0, 0),
          rightEye: Offset(10, 0),
          noseBase: Offset(5, 5),
          leftMouth: Offset(2, 8),
          rightMouth: Offset(8, 8),
        ),
      );

      final QualityResult result = gate.evaluate(
        faces: <DetectedFace>[face],
        previewSize: previewSize,
        ovalRect: ovalRect,
        previewMapper: mapper,
        config: config,
        faceStats: passingStats,
      );

      expect(result.issues, contains(QualityIssue.tooSmall));
    });

    test('flags notInsideGuide when face box extends beyond oval', () {
      // Position face far to the top-left
      const Rect previewBox = Rect.fromLTWH(10.0, 10.0, 150.0, 180.0);
      final Rect uprightBox = mapper.unmapRect(previewBox);

      final DetectedFace face = DetectedFace(
        trackingId: 1,
        boundingBox: uprightBox,
        landmarks: const FiveLandmarks(
          leftEye: Offset(0, 0),
          rightEye: Offset(10, 0),
          noseBase: Offset(5, 5),
          leftMouth: Offset(2, 8),
          rightMouth: Offset(8, 8),
        ),
      );

      final QualityResult result = gate.evaluate(
        faces: <DetectedFace>[face],
        previewSize: previewSize,
        ovalRect: ovalRect,
        previewMapper: mapper,
        config: config,
        faceStats: passingStats,
      );

      expect(result.issues, contains(QualityIssue.notInsideGuide));
    });

    test('respects custom cornerTolerance and cardinalTolerance overrides', () {
      // Position face slightly extending cardinal tolerance beyond 1.08 but within 1.15
      // Oval: center (200, 360), rx = 140, ry = 225
      // dy / ry = 1.10 => 1.10^2 = 1.21 > 1.08^2 (1.1664) [fails default cardinal]
      // dx / rx = 0.40 => corner normDist = 0.40^2 + 1.10^2 = 0.16 + 1.21 = 1.37 [passes 1.45 corner]
      final Rect slightlyExtendedBox = Rect.fromCenter(
        center: ovalRect.center,
        width: ovalRect.width * 0.40,
        height: ovalRect.height * 1.10, // Exceeds default 1.08, within 1.15
      );

      final DetectedFace face = DetectedFace(
        trackingId: 1,
        boundingBox: mapper.unmapRect(slightlyExtendedBox),
        landmarks: const FiveLandmarks(
          leftEye: Offset(0, 0),
          rightEye: Offset(10, 0),
          noseBase: Offset(5, 5),
          leftMouth: Offset(2, 8),
          rightMouth: Offset(8, 8),
        ),
      );

      final QualityResult defaultResult = gate.evaluate(
        faces: <DetectedFace>[face],
        previewSize: previewSize,
        ovalRect: ovalRect,
        previewMapper: mapper,
        config: config,
        faceStats: passingStats,
      );
      expect(defaultResult.issues, contains(QualityIssue.notInsideGuide));

      final QualityResult overrideResult = gate.evaluate(
        faces: <DetectedFace>[face],
        previewSize: previewSize,
        ovalRect: ovalRect,
        previewMapper: mapper,
        config: config,
        faceStats: passingStats,
        cardinalTolerance: 1.15,
        cornerTolerance: 1.45,
      );
      expect(
        overrideResult.issues,
        isNot(contains(QualityIssue.notInsideGuide)),
      );
    });

    test('flags poseOutOfRange when yaw, pitch, or roll exceed maximums', () {
      final DetectedFace faceHighYaw = DetectedFace(
        trackingId: 1,
        boundingBox: mapper.unmapRect(
          const Rect.fromLTWH(120.0, 260.0, 160.0, 200.0),
        ),
        headEulerAngleY: 25.0, // Exceeds config.qualityMaxYaw (15.0)
        landmarks: const FiveLandmarks(
          leftEye: Offset(0, 0),
          rightEye: Offset(10, 0),
          noseBase: Offset(5, 5),
          leftMouth: Offset(2, 8),
          rightMouth: Offset(8, 8),
        ),
      );

      final QualityResult result = gate.evaluate(
        faces: <DetectedFace>[faceHighYaw],
        previewSize: previewSize,
        ovalRect: ovalRect,
        previewMapper: mapper,
        config: config,
        faceStats: passingStats,
      );

      expect(result.issues, contains(QualityIssue.poseOutOfRange));
    });

    test('skips poseOutOfRange when checkPose is false', () {
      final DetectedFace faceHighYaw = DetectedFace(
        trackingId: 1,
        boundingBox: mapper.unmapRect(
          const Rect.fromLTWH(120.0, 260.0, 160.0, 200.0),
        ),
        headEulerAngleY: 25.0, // Exceeds config.qualityMaxYaw (15.0)
        landmarks: const FiveLandmarks(
          leftEye: Offset(0, 0),
          rightEye: Offset(10, 0),
          noseBase: Offset(5, 5),
          leftMouth: Offset(2, 8),
          rightMouth: Offset(8, 8),
        ),
      );

      final QualityResult result = gate.evaluate(
        faces: <DetectedFace>[faceHighYaw],
        previewSize: previewSize,
        ovalRect: ovalRect,
        previewMapper: mapper,
        config: config,
        faceStats: passingStats,
        checkPose: false,
      );

      expect(result.issues, isNot(contains(QualityIssue.poseOutOfRange)));
      expect(result.isPass, isTrue);
    });

    test('flags landmarksMissing when five canonical landmarks are absent', () {
      final DetectedFace faceNoLandmarks = DetectedFace(
        trackingId: 1,
        boundingBox: mapper.unmapRect(
          const Rect.fromLTWH(120.0, 260.0, 160.0, 200.0),
        ),
        landmarks: null,
      );

      final QualityResult result = gate.evaluate(
        faces: <DetectedFace>[faceNoLandmarks],
        previewSize: previewSize,
        ovalRect: ovalRect,
        previewMapper: mapper,
        config: config,
        faceStats: passingStats,
      );

      expect(result.issues, contains(QualityIssue.landmarksMissing));
    });

    test(
      'flags tooDark, tooBright, glare, and tooBlurry based on FaceStats',
      () {
        final DetectedFace face = createPassingFace();

        // Too dark
        final QualityResult resDark = gate.evaluate(
          faces: <DetectedFace>[face],
          previewSize: previewSize,
          ovalRect: ovalRect,
          previewMapper: mapper,
          config: config,
          faceStats: const FaceStats(
            sharpness: 100.0,
            meanBrightness: 20.0, // < 40.0
            nearSaturatedRatio: 0.0,
          ),
        );
        expect(resDark.issues, contains(QualityIssue.tooDark));

        // Too bright
        final QualityResult resBright = gate.evaluate(
          faces: <DetectedFace>[face],
          previewSize: previewSize,
          ovalRect: ovalRect,
          previewMapper: mapper,
          config: config,
          faceStats: const FaceStats(
            sharpness: 100.0,
            meanBrightness: 235.0, // > 220.0
            nearSaturatedRatio: 0.0,
          ),
        );
        expect(resBright.issues, contains(QualityIssue.tooBright));

        // Glare
        final QualityResult resGlare = gate.evaluate(
          faces: <DetectedFace>[face],
          previewSize: previewSize,
          ovalRect: ovalRect,
          previewMapper: mapper,
          config: config,
          faceStats: const FaceStats(
            sharpness: 100.0,
            meanBrightness: 150.0,
            nearSaturatedRatio: 0.18, // > 0.10
          ),
        );
        expect(resGlare.issues, contains(QualityIssue.glare));

        // Too blurry
        final QualityResult resBlur = gate.evaluate(
          faces: <DetectedFace>[face],
          previewSize: previewSize,
          ovalRect: ovalRect,
          previewMapper: mapper,
          config: config,
          faceStats: const FaceStats(
            sharpness: 25.0, // < 50.0
            meanBrightness: 120.0,
            nearSaturatedRatio: 0.01,
          ),
        );
        expect(resBlur.issues, contains(QualityIssue.tooBlurry));
      },
    );
  });
}
