import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart'
    as mlkit;

import '../../camera/domain/frame_data.dart';
import '../../camera/domain/frame_geometry.dart';
import '../domain/detected_face.dart';
import '../domain/face_aligner.dart';
import '../domain/face_detector.dart';

/// Concrete [FaceDetector] implementation backed by Google ML Kit.
///
/// Runs on the main isolate (utilizing ML Kit's internal background thread).
class MlKitFaceDetector implements FaceDetector {
  MlKitFaceDetector({
    double minFaceSize = 0.15,
    mlkit.FaceDetector? detector,
    this.isAndroidOverride,
  }) : _detector =
           detector ??
           mlkit.FaceDetector(
             options: mlkit.FaceDetectorOptions(
               performanceMode: mlkit.FaceDetectorMode.accurate,
               enableLandmarks: true,
               enableClassification: true,
               enableTracking: true,
               enableContours: false,
               minFaceSize: minFaceSize,
             ),
           );

  final mlkit.FaceDetector _detector;
  final bool? isAndroidOverride;

  bool get _isAndroid =>
      isAndroidOverride ?? (defaultTargetPlatform == TargetPlatform.android);

  @override
  Future<List<DetectedFace>> detect(FrameData frame) async {
    final mlkit.InputImage inputImage = _buildInputImage(frame);
    final List<mlkit.Face> mlFaces = await _detector.processImage(inputImage);

    final FrameGeometry geometry = FrameGeometry(
      rawWidth: frame.width,
      rawHeight: frame.height,
      rotation: frame.sensorRotation,
    );

    return mlFaces
        .map((mlkit.Face f) => _mapFace(f, geometry))
        .toList(growable: false);
  }

  @override
  Future<void> dispose() async {
    await _detector.close();
  }

  mlkit.InputImage _buildInputImage(FrameData frame) {
    final mlkit.InputImageRotation rotation = _mapRotation(
      frame.sensorRotation,
    );
    final mlkit.InputImageFormat format = _mapFormat(frame.format);

    final Uint8List bytes;
    if (frame.planes.length == 1) {
      bytes = frame.planes[0].bytes;
    } else {
      final int totalBytes = frame.planes.fold(
        0,
        (int sum, FramePlane p) => sum + p.bytes.length,
      );
      final Uint8List combined = Uint8List(totalBytes);
      int offset = 0;
      for (final FramePlane plane in frame.planes) {
        combined.setRange(offset, offset + plane.bytes.length, plane.bytes);
        offset += plane.bytes.length;
      }
      bytes = combined;
    }

    return mlkit.InputImage.fromBytes(
      bytes: bytes,
      metadata: mlkit.InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: frame.planes.isNotEmpty
            ? frame.planes.first.bytesPerRow
            : frame.width * 4,
      ),
    );
  }

  mlkit.InputImageRotation _mapRotation(int degrees) {
    switch (degrees) {
      case 0:
        return mlkit.InputImageRotation.rotation0deg;
      case 90:
        return mlkit.InputImageRotation.rotation90deg;
      case 180:
        return mlkit.InputImageRotation.rotation180deg;
      case 270:
      default:
        return mlkit.InputImageRotation.rotation270deg;
    }
  }

  mlkit.InputImageFormat _mapFormat(FrameFormat format) {
    switch (format) {
      case FrameFormat.nv21:
        return mlkit.InputImageFormat.nv21;
      case FrameFormat.bgra8888:
        return mlkit.InputImageFormat.bgra8888;
      case FrameFormat.yuv420:
        return _isAndroid
            ? mlkit.InputImageFormat.yuv_420_888
            : mlkit.InputImageFormat.yuv420;
    }
  }

  DetectedFace _mapFace(mlkit.Face face, FrameGeometry geometry) {
    final Rect uprightBox;
    final Map<mlkit.FaceLandmarkType, Offset> uprightLandmarks =
        <mlkit.FaceLandmarkType, Offset>{};

    // On Android, ML Kit processes rotation internally and returns coordinates
    // in the rotated upright frame. On iOS, ML Kit receives unrotated pixel buffer
    // and returns coordinates in raw frame space, needing rawToUpright mapping.
    final bool coordinatesAreUpright = _isAndroid || geometry.rotation == 0;

    if (coordinatesAreUpright) {
      uprightBox = face.boundingBox;
      for (final MapEntry<mlkit.FaceLandmarkType, mlkit.FaceLandmark?> entry
          in face.landmarks.entries) {
        if (entry.value != null) {
          uprightLandmarks[entry.key] = Offset(
            entry.value!.position.x.toDouble(),
            entry.value!.position.y.toDouble(),
          );
        }
      }
    } else {
      // Map raw box corners to upright coordinates
      final Rect r = face.boundingBox;
      final Offset c1 = geometry.rawToUpright.mapXY(r.left, r.top);
      final Offset c2 = geometry.rawToUpright.mapXY(r.right, r.top);
      final Offset c3 = geometry.rawToUpright.mapXY(r.left, r.bottom);
      final Offset c4 = geometry.rawToUpright.mapXY(r.right, r.bottom);

      final double minX = math.min(
        math.min(c1.dx, c2.dx),
        math.min(c3.dx, c4.dx),
      );
      final double maxX = math.max(
        math.max(c1.dx, c2.dx),
        math.max(c3.dx, c4.dx),
      );
      final double minY = math.min(
        math.min(c1.dy, c2.dy),
        math.min(c3.dy, c4.dy),
      );
      final double maxY = math.max(
        math.max(c1.dy, c2.dy),
        math.max(c3.dy, c4.dy),
      );
      uprightBox = Rect.fromLTRB(minX, minY, maxX, maxY);

      for (final MapEntry<mlkit.FaceLandmarkType, mlkit.FaceLandmark?> entry
          in face.landmarks.entries) {
        if (entry.value != null) {
          uprightLandmarks[entry.key] = geometry.rawToUpright.mapXY(
            entry.value!.position.x.toDouble(),
            entry.value!.position.y.toDouble(),
          );
        }
      }
    }

    // Extract the 5 canonical landmarks
    final Offset? eye1 = uprightLandmarks[mlkit.FaceLandmarkType.leftEye];
    final Offset? eye2 = uprightLandmarks[mlkit.FaceLandmarkType.rightEye];
    final Offset? nose = uprightLandmarks[mlkit.FaceLandmarkType.noseBase];
    final Offset? mouth1 = uprightLandmarks[mlkit.FaceLandmarkType.leftMouth];
    final Offset? mouth2 = uprightLandmarks[mlkit.FaceLandmarkType.rightMouth];

    final FiveLandmarks? fiveLandmarks;
    if (eye1 != null &&
        eye2 != null &&
        nose != null &&
        mouth1 != null &&
        mouth2 != null) {
      fiveLandmarks = FaceAligner.sortLandmarks(
        eyeA: eye1,
        eyeB: eye2,
        nose: nose,
        mouthA: mouth1,
        mouthB: mouth2,
      );
    } else {
      fiveLandmarks = null;
    }

    return DetectedFace(
      trackingId: face.trackingId,
      boundingBox: uprightBox,
      headEulerAngleX: face.headEulerAngleX,
      headEulerAngleY: face.headEulerAngleY,
      headEulerAngleZ: face.headEulerAngleZ,
      leftEyeOpenProbability: face.leftEyeOpenProbability,
      rightEyeOpenProbability: face.rightEyeOpenProbability,
      smilingProbability: face.smilingProbability,
      landmarks: fiveLandmarks,
    );
  }
}
