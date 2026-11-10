import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:attendence/features/camera/domain/frame_data.dart';
import 'package:attendence/features/detection/data/mlkit_face_detector.dart';
import 'package:attendence/features/detection/domain/detected_face.dart';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart'
    as mlkit;
import 'package:mocktail/mocktail.dart';

class _MockMlKitDetector extends Mock implements mlkit.FaceDetector {}

class _FakeInputImage extends Fake implements mlkit.InputImage {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeInputImage());
  });

  group('MlKitFaceDetector', () {
    late _MockMlKitDetector mockDetector;

    setUp(() {
      mockDetector = _MockMlKitDetector();
      when(() => mockDetector.close()).thenAnswer((_) async {});
    });

    mlkit.Face createMlKitFace({
      required Rect boundingBox,
      int? trackingId = 42,
      double? yaw = 5.0,
      double? pitch = -2.0,
      double? roll = 1.0,
      double? smile = 0.85,
      double? leftEyeOpen = 0.95,
      double? rightEyeOpen = 0.90,
      Map<mlkit.FaceLandmarkType, mlkit.FaceLandmark?>? landmarks,
    }) {
      final Map<mlkit.FaceLandmarkType, mlkit.FaceLandmark?> defaultLandmarks =
          landmarks ??
          <mlkit.FaceLandmarkType, mlkit.FaceLandmark?>{
            mlkit.FaceLandmarkType.leftEye: mlkit.FaceLandmark(
              type: mlkit.FaceLandmarkType.leftEye,
              position: const Point<int>(35, 50),
            ),
            mlkit.FaceLandmarkType.rightEye: mlkit.FaceLandmark(
              type: mlkit.FaceLandmarkType.rightEye,
              position: const Point<int>(75, 50),
            ),
            mlkit.FaceLandmarkType.noseBase: mlkit.FaceLandmark(
              type: mlkit.FaceLandmarkType.noseBase,
              position: const Point<int>(55, 70),
            ),
            mlkit.FaceLandmarkType.leftMouth: mlkit.FaceLandmark(
              type: mlkit.FaceLandmarkType.leftMouth,
              position: const Point<int>(40, 90),
            ),
            mlkit.FaceLandmarkType.rightMouth: mlkit.FaceLandmark(
              type: mlkit.FaceLandmarkType.rightMouth,
              position: const Point<int>(70, 90),
            ),
          };

      return mlkit.Face(
        boundingBox: boundingBox,
        landmarks: defaultLandmarks,
        contours: const <mlkit.FaceContourType, mlkit.FaceContour?>{},
        trackingId: trackingId,
        headEulerAngleX: pitch,
        headEulerAngleY: yaw,
        headEulerAngleZ: roll,
        smilingProbability: smile,
        leftEyeOpenProbability: leftEyeOpen,
        rightEyeOpenProbability: rightEyeOpen,
      );
    }

    test('detects face and converts correctly on Android with upright coords (sensor 270)', () async {
      final MlKitFaceDetector detector = MlKitFaceDetector(
        detector: mockDetector,
        isAndroidOverride: true,
      );

      final mlkit.Face fakeFace = createMlKitFace(
        boundingBox: const Rect.fromLTWH(100, 150, 200, 250),
      );

      when(() => mockDetector.processImage(any()))
          .thenAnswer((_) async => <mlkit.Face>[fakeFace]);

      final FrameData frame = FrameData(
        format: FrameFormat.nv21,
        width: 1280,
        height: 720,
        planes: <FramePlane>[
          FramePlane(bytes: Uint8List(1280 * 720), bytesPerRow: 1280),
          FramePlane(bytes: Uint8List(1280 * 360), bytesPerRow: 1280),
        ],
        sensorRotation: 270,
        lensDirection: CameraLensDirection.front,
        timestamp: DateTime(2026, 1, 1),
      );

      final List<DetectedFace> results = await detector.detect(frame);

      expect(results.length, equals(1));
      final DetectedFace face = results.first;

      expect(face.trackingId, equals(42));
      expect(face.boundingBox, equals(const Rect.fromLTWH(100, 150, 200, 250)));
      expect(face.yaw, equals(5.0));
      expect(face.pitch, equals(-2.0));
      expect(face.roll, equals(1.0));
      expect(face.smilingProbability, equals(0.85));
      expect(face.hasAllLandmarks, isTrue);
      expect(face.isValidForRecognition, isTrue);
      expect(face.landmarks!.leftEye.dx, equals(35.0));
      expect(face.landmarks!.rightEye.dx, equals(75.0));
    });

    test(
      'detects face correctly on Android with sensor rotation 90 front camera',
      () async {
        final MlKitFaceDetector detector = MlKitFaceDetector(
          detector: mockDetector,
          isAndroidOverride: true,
        );

        final mlkit.Face fakeFace = createMlKitFace(
          boundingBox: const Rect.fromLTWH(80, 120, 220, 280),
        );

        when(() => mockDetector.processImage(any()))
            .thenAnswer((_) async => <mlkit.Face>[fakeFace]);

        final FrameData frame = FrameData(
          format: FrameFormat.nv21,
          width: 1280,
          height: 720,
          planes: <FramePlane>[
            FramePlane(bytes: Uint8List(1280 * 720), bytesPerRow: 1280),
            FramePlane(bytes: Uint8List(1280 * 360), bytesPerRow: 1280),
          ],
          sensorRotation: 90,
          lensDirection: CameraLensDirection.front,
          timestamp: DateTime(2026, 1, 1),
        );

        final List<DetectedFace> results = await detector.detect(frame);
        expect(results.length, equals(1));
        final DetectedFace face = results.first;

        expect(
          face.boundingBox,
          equals(const Rect.fromLTWH(80, 120, 220, 280)),
        );
      },
    );

    test('treats iOS pre-rotated portrait frames (rotation 0) as upright without extra transform', () async {
      final MlKitFaceDetector detector = MlKitFaceDetector(
        detector: mockDetector,
        isAndroidOverride: false, // iOS
      );

      // Pre-rotated portrait coordinates directly from ML Kit in 720x1280 space
      final mlkit.Face fakeFace = createMlKitFace(
        boundingBox: const Rect.fromLTWH(150, 200, 300, 400),
      );

      when(() => mockDetector.processImage(any()))
          .thenAnswer((_) async => <mlkit.Face>[fakeFace]);

      // iOS pre-rotated portrait frame: width <= height, sensorRotation is 0
      final FrameData frame = FrameData(
        format: FrameFormat.bgra8888,
        width: 720,
        height: 1280,
        planes: <FramePlane>[
          FramePlane(bytes: Uint8List(720 * 1280 * 4), bytesPerRow: 720 * 4),
        ],
        sensorRotation: 0,
        lensDirection: CameraLensDirection.front,
        timestamp: DateTime(2026, 1, 1),
      );

      final List<DetectedFace> results = await detector.detect(frame);
      expect(results.length, equals(1));

      final DetectedFace face = results.first;
      // Bounding box must match fakeFace directly without spurious rotation
      expect(face.boundingBox, equals(const Rect.fromLTWH(150, 200, 300, 400)));
      expect(face.landmarks!.leftEye, equals(const Offset(35.0, 50.0)));
    });

    test('transforms raw coordinates to upright coordinates on iOS when rotated (e.g. landscape)', () async {
      final MlKitFaceDetector detector = MlKitFaceDetector(
        detector: mockDetector,
        isAndroidOverride: false, // iOS
      );

      // Raw box in 1280x720 frame
      final mlkit.Face fakeFace = createMlKitFace(
        boundingBox: const Rect.fromLTWH(100, 150, 200, 250),
      );

      when(() => mockDetector.processImage(any()))
          .thenAnswer((_) async => <mlkit.Face>[fakeFace]);

      final FrameData frame = FrameData(
        format: FrameFormat.bgra8888,
        width: 1280,
        height: 720,
        planes: <FramePlane>[
          FramePlane(bytes: Uint8List(1280 * 720 * 4), bytesPerRow: 1280 * 4),
        ],
        sensorRotation: 90,
        lensDirection: CameraLensDirection.front,
        timestamp: DateTime(2026, 1, 1),
      );

      final List<DetectedFace> results = await detector.detect(frame);
      expect(results.length, equals(1));

      final DetectedFace face = results.first;
      // Coordinates must be rotated to upright portrait frame (720x1280)
      expect(face.boundingBox.left, greaterThanOrEqualTo(0.0));
      expect(face.boundingBox.right, lessThanOrEqualTo(720.0));
      expect(face.boundingBox.top, greaterThanOrEqualTo(0.0));
      expect(face.boundingBox.bottom, lessThanOrEqualTo(1280.0));
    });

    test(
      'flags landmarksMissing when any canonical landmark is absent',
      () async {
        final MlKitFaceDetector detector = MlKitFaceDetector(
          detector: mockDetector,
          isAndroidOverride: true,
        );

        // Omit right mouth corner
        final mlkit.Face faceMissingMouth = createMlKitFace(
          boundingBox: const Rect.fromLTWH(50, 50, 100, 100),
          landmarks: <mlkit.FaceLandmarkType, mlkit.FaceLandmark?>{
            mlkit.FaceLandmarkType.leftEye: mlkit.FaceLandmark(
              type: mlkit.FaceLandmarkType.leftEye,
              position: const Point<int>(35, 50),
            ),
            mlkit.FaceLandmarkType.rightEye: mlkit.FaceLandmark(
              type: mlkit.FaceLandmarkType.rightEye,
              position: const Point<int>(75, 50),
            ),
            mlkit.FaceLandmarkType.noseBase: mlkit.FaceLandmark(
              type: mlkit.FaceLandmarkType.noseBase,
              position: const Point<int>(55, 70),
            ),
            mlkit.FaceLandmarkType.leftMouth: mlkit.FaceLandmark(
              type: mlkit.FaceLandmarkType.leftMouth,
              position: const Point<int>(40, 90),
            ),
            mlkit.FaceLandmarkType.rightMouth: null,
          },
        );

        when(() => mockDetector.processImage(any()))
            .thenAnswer((_) async => <mlkit.Face>[faceMissingMouth]);

        final FrameData frame = FrameData(
          format: FrameFormat.nv21,
          width: 100,
          height: 100,
          planes: <FramePlane>[
            FramePlane(bytes: Uint8List(100), bytesPerRow: 10),
          ],
          sensorRotation: 0,
          lensDirection: CameraLensDirection.front,
          timestamp: DateTime(2026, 1, 1),
        );

        final List<DetectedFace> results = await detector.detect(frame);
        expect(results.length, equals(1));
        expect(results.first.hasAllLandmarks, isFalse);
        expect(results.first.landmarksMissing, isTrue);
        expect(results.first.isValidForRecognition, isFalse);
        expect(results.first.landmarks, isNull);
      },
    );

    test('disposes underlying detector', () async {
      final MlKitFaceDetector detector = MlKitFaceDetector(
        detector: mockDetector,
      );
      await detector.dispose();
      verify(() => mockDetector.close()).called(1);
    });
  });
}
