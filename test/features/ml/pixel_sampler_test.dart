import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:attendence/core/utils/affine_matrix.dart';
import 'package:attendence/features/camera/domain/frame_data.dart';
import 'package:attendence/features/detection/domain/face_stats.dart';
import 'package:attendence/features/ml/sampler/pixel_sampler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PixelSampler', () {
    const PixelSampler sampler = PixelSampler();

    test('samples 2x2 BGRA8888 frame accurately with rotation 0', () {
      // 2x2 image:
      // (0,0): Red,    (1,0): Green
      // (0,1): Blue,   (1,1): White
      final Uint8List bgraBytes = Uint8List.fromList(<int>[
        0, 0, 255, 255, // (0,0) Red [B, G, R, A]
        0, 255, 0, 255, // (1,0) Green
        255, 0, 0, 255, // (0,1) Blue
        255, 255, 255, 255, // (1,1) White
      ]);

      final FrameData frame = FrameData(
        format: FrameFormat.bgra8888,
        width: 2,
        height: 2,
        planes: <FramePlane>[
          FramePlane(bytes: bgraBytes, bytesPerRow: 8, bytesPerPixel: 4),
        ],
        sensorRotation: 0,
        lensDirection: CameraLensDirection.front,
        timestamp: DateTime(2026, 1, 1),
      );

      final Uint8List rgb = sampler.warpAffine(
        frame,
        AffineMatrix.identity,
        2,
        2,
      );

      // (0, 0) -> Red
      expect(rgb[0], equals(255));
      expect(rgb[1], equals(0));
      expect(rgb[2], equals(0));

      // (1, 0) -> Green
      expect(rgb[3], equals(0));
      expect(rgb[4], equals(255));
      expect(rgb[5], equals(0));

      // (0, 1) -> Blue
      expect(rgb[6], equals(0));
      expect(rgb[7], equals(0));
      expect(rgb[8], equals(255));

      // (1, 1) -> White
      expect(rgb[9], equals(255));
      expect(rgb[10], equals(255));
      expect(rgb[11], equals(255));
    });

    test('BGRA8888 handles row stride padding correctly', () {
      // 2x2 image with 4 padding bytes per row (bytesPerRow = 12 instead of 8)
      final Uint8List bgraWithStride = Uint8List.fromList(<int>[
        0, 0, 255, 255, 0, 255, 0, 255, 99, 99, 99, 99, // row 0 + 4 padding
        255, 0, 0, 255, 255, 255, 255, 255, 88, 88, 88, 88, // row 1 + 4 padding
      ]);

      final FrameData frame = FrameData(
        format: FrameFormat.bgra8888,
        width: 2,
        height: 2,
        planes: <FramePlane>[
          FramePlane(bytes: bgraWithStride, bytesPerRow: 12, bytesPerPixel: 4),
        ],
        sensorRotation: 0,
        lensDirection: CameraLensDirection.front,
        timestamp: DateTime(2026, 1, 1),
      );

      final Uint8List rgb = sampler.warpAffine(
        frame,
        AffineMatrix.identity,
        2,
        2,
      );

      expect(rgb[0], equals(255)); // Red
      expect(rgb[4], equals(255)); // Green
      expect(rgb[8], equals(255)); // Blue
      expect(rgb[9], equals(255)); // White R
    });

    test('pads out-of-bounds regions with configurable padValue', () {
      final Uint8List bgraBytes = Uint8List.fromList(<int>[0, 0, 255, 255]);

      final FrameData frame = FrameData(
        format: FrameFormat.bgra8888,
        width: 1,
        height: 1,
        planes: <FramePlane>[FramePlane(bytes: bgraBytes, bytesPerRow: 4)],
        sensorRotation: 0,
        lensDirection: CameraLensDirection.front,
        timestamp: DateTime(2026, 1, 1),
      );

      // Translate far off bounds
      final AffineMatrix farOut = AffineMatrix.translation(100.0, 100.0);
      final Uint8List rgb = sampler.warpAffine(
        frame,
        farOut,
        2,
        2,
        padValue: 128,
      );

      for (int i = 0; i < rgb.length; i++) {
        expect(rgb[i], equals(128));
      }
    });

    test(
      'samples synthetic NV21 frame correctly with YUV to RGB conversion',
      () {
        // 2x2 image in NV21
        // Plane 0 (Y): 2x2 = 4 bytes
        // Plane 1 (VU): 1x1 VU pair = 2 bytes (V, U)
        // Neutral gray: Y=128, U=128, V=128 -> RGB (128, 128, 128)
        final Uint8List yBytes = Uint8List.fromList(<int>[128, 128, 128, 128]);
        final Uint8List vuBytes = Uint8List.fromList(<int>[128, 128]);

        final FrameData frame = FrameData(
          format: FrameFormat.nv21,
          width: 2,
          height: 2,
          planes: <FramePlane>[
            FramePlane(bytes: yBytes, bytesPerRow: 2, bytesPerPixel: 1),
            FramePlane(bytes: vuBytes, bytesPerRow: 2, bytesPerPixel: 2),
          ],
          sensorRotation: 0,
          lensDirection: CameraLensDirection.front,
          timestamp: DateTime(2026, 1, 1),
        );

        final Uint8List rgb = sampler.warpAffine(
          frame,
          AffineMatrix.identity,
          2,
          2,
        );

        for (int i = 0; i < rgb.length; i++) {
          expect(rgb[i], closeTo(128, 2));
        }
      },
    );

    test('samples synthetic YUV420 frame with 3 planes', () {
      final Uint8List yBytes = Uint8List.fromList(<int>[200, 200, 200, 200]);
      final Uint8List uBytes = Uint8List.fromList(<int>[128]);
      final Uint8List vBytes = Uint8List.fromList(<int>[128]);

      final FrameData frame = FrameData(
        format: FrameFormat.yuv420,
        width: 2,
        height: 2,
        planes: <FramePlane>[
          FramePlane(bytes: yBytes, bytesPerRow: 2, bytesPerPixel: 1),
          FramePlane(bytes: uBytes, bytesPerRow: 1, bytesPerPixel: 1),
          FramePlane(bytes: vBytes, bytesPerRow: 1, bytesPerPixel: 1),
        ],
        sensorRotation: 0,
        lensDirection: CameraLensDirection.front,
        timestamp: DateTime(2026, 1, 1),
      );

      final Uint8List rgb = sampler.warpAffine(
        frame,
        AffineMatrix.identity,
        2,
        2,
      );

      expect(rgb[0], closeTo(200, 2));
      expect(rgb[1], closeTo(200, 2));
      expect(rgb[2], closeTo(200, 2));
    });

    test('toGrayscaleDownsampled extracts luma without full conversion', () {
      // NV21 frame: Y plane directly sampled
      final Uint8List yBytes = Uint8List.fromList(<int>[
        10,
        20,
        30,
        40,
        50,
        60,
        70,
        80,
      ]);

      final FrameData nv21Frame = FrameData(
        format: FrameFormat.nv21,
        width: 4,
        height: 2,
        planes: <FramePlane>[FramePlane(bytes: yBytes, bytesPerRow: 4)],
        sensorRotation: 0,
        lensDirection: CameraLensDirection.front,
        timestamp: DateTime(2026, 1, 1),
      );

      final Uint8List gray = sampler.toGrayscaleDownsampled(
        nv21Frame,
        targetWidth: 2,
        targetHeight: 1,
      );

      expect(gray.length, equals(2));
      expect(gray[0], equals(10));
      expect(gray[1], equals(30));
    });

    test('reusable output buffer avoids allocations', () {
      final Uint8List bgraBytes = Uint8List.fromList(<int>[0, 0, 100, 255]);
      final FrameData frame = FrameData(
        format: FrameFormat.bgra8888,
        width: 1,
        height: 1,
        planes: <FramePlane>[FramePlane(bytes: bgraBytes, bytesPerRow: 4)],
        sensorRotation: 0,
        lensDirection: CameraLensDirection.front,
        timestamp: DateTime(2026, 1, 1),
      );

      final Uint8List preallocated = Uint8List(1 * 1 * 3);
      final Uint8List result = sampler.warpAffine(
        frame,
        AffineMatrix.identity,
        1,
        1,
        outBuffer: preallocated,
      );

      expect(identical(result, preallocated), isTrue);
      expect(result[0], equals(100));
    });

    test('warpGrayscale and computeFaceStats calculate metrics accurately', () {
      // 10x10 NV21 image with sharp high-contrast pattern:
      // Alternating black (0) and white (255) pixels to produce high sharpness and glare
      final Uint8List yBytes = Uint8List(100);
      for (int i = 0; i < 100; i++) {
        yBytes[i] = (i % 2 == 0) ? 0 : 255;
      }

      final FrameData frame = FrameData(
        format: FrameFormat.nv21,
        width: 10,
        height: 10,
        planes: <FramePlane>[FramePlane(bytes: yBytes, bytesPerRow: 10)],
        sensorRotation: 0,
        lensDirection: CameraLensDirection.front,
        timestamp: DateTime(2026, 1, 1),
      );

      final FaceStats stats = sampler.computeFaceStats(
        frame,
        const Rect.fromLTWH(0, 0, 10, 10),
        sampleSize: 10,
      );

      // Mean brightness of alternating 0 and 255 should be approximately 127.5
      expect(stats.meanBrightness, closeTo(127.5, 5.0));
      // Near saturated ratio should be around 0.5 (half are 255)
      expect(stats.nearSaturatedRatio, closeTo(0.5, 0.05));
      // Sharpness (Laplacian variance) must be high for high-frequency checkerboard pattern
      expect(stats.sharpness, greaterThan(100.0));
    });

    test(
      'computeFaceStats returns zero metrics on invalid or empty face rect',
      () {
        final FrameData frame = FrameData(
          format: FrameFormat.nv21,
          width: 10,
          height: 10,
          planes: <FramePlane>[
            FramePlane(bytes: Uint8List(100), bytesPerRow: 10),
          ],
          sensorRotation: 0,
          lensDirection: CameraLensDirection.front,
          timestamp: DateTime(2026, 1, 1),
        );

        final FaceStats stats = sampler.computeFaceStats(
          frame,
          const Rect.fromLTWH(0, 0, 0, 0),
        );

        expect(stats.sharpness, equals(0.0));
        expect(stats.meanBrightness, equals(0.0));
        expect(stats.nearSaturatedRatio, equals(0.0));
      },
    );
  });
}
