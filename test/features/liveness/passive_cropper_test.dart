import 'dart:ui';

import 'package:attendence/core/utils/affine_matrix.dart';
import 'package:attendence/features/liveness/domain/passive_cropper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const PassiveCropper cropper = PassiveCropper();

  group('PassiveCropper', () {
    test('normal centered box scales cleanly for V2 and V1SE', () {
      const Rect faceBox = Rect.fromLTWH(200, 300, 100, 100);
      const int srcW = 800;
      const int srcH = 1000;

      // MiniFASNetV2: scale 2.7
      final Rect cropV2 = cropper.computeCropRect(
        faceBox: faceBox,
        srcW: srcW,
        srcH: srcH,
        cropScale: 2.7,
      );
      expect(cropV2.width, closeTo(270.0, 0.001));
      expect(cropV2.height, closeTo(270.0, 0.001));
      expect(cropV2.center, equals(faceBox.center));

      // MiniFASNetV1SE: scale 4.0
      final Rect cropV1 = cropper.computeCropRect(
        faceBox: faceBox,
        srcW: srcW,
        srcH: srcH,
        cropScale: 4.0,
      );
      expect(cropV1.width, closeTo(400.0, 0.001));
      expect(cropV1.height, closeTo(400.0, 0.001));
      expect(cropV1.center, equals(faceBox.center));
    });

    test('box near left border shifts right without stretching', () {
      const Rect faceBox = Rect.fromLTWH(10, 400, 100, 100);
      const int srcW = 800;
      const int srcH = 1000;

      // Scale 2.7 -> width = 270. Centered would start at 60 - 135 = -75.
      final Rect crop = cropper.computeCropRect(
        faceBox: faceBox,
        srcW: srcW,
        srcH: srcH,
        cropScale: 2.7,
      );

      expect(crop.left, equals(0.0));
      expect(crop.width, closeTo(270.0, 0.001));
      expect(crop.height, closeTo(270.0, 0.001));
      expect(crop.right, closeTo(270.0, 0.001));
    });

    test('box near top border shifts down without stretching', () {
      const Rect faceBox = Rect.fromLTWH(400, 15, 100, 100);
      const int srcW = 800;
      const int srcH = 1000;

      final Rect crop = cropper.computeCropRect(
        faceBox: faceBox,
        srcW: srcW,
        srcH: srcH,
        cropScale: 2.7,
      );

      expect(crop.top, equals(0.0));
      expect(crop.width, closeTo(270.0, 0.001));
      expect(crop.height, closeTo(270.0, 0.001));
      expect(crop.bottom, closeTo(270.0, 0.001));
    });

    test('box near right border shifts left without stretching', () {
      const Rect faceBox = Rect.fromLTWH(700, 400, 100, 100);
      const int srcW = 800;
      const int srcH = 1000;

      final Rect crop = cropper.computeCropRect(
        faceBox: faceBox,
        srcW: srcW,
        srcH: srcH,
        cropScale: 2.7,
      );

      expect(crop.right, equals(799.0));
      expect(crop.width, closeTo(270.0, 0.001));
      expect(crop.height, closeTo(270.0, 0.001));
      expect(crop.left, closeTo(799.0 - 270.0, 0.001));
    });

    test('box near bottom border shifts up without stretching', () {
      const Rect faceBox = Rect.fromLTWH(400, 920, 100, 100);
      const int srcW = 800;
      const int srcH = 1000;

      final Rect crop = cropper.computeCropRect(
        faceBox: faceBox,
        srcW: srcW,
        srcH: srcH,
        cropScale: 2.7,
      );

      expect(crop.bottom, equals(999.0));
      expect(crop.width, closeTo(270.0, 0.001));
      expect(crop.height, closeTo(270.0, 0.001));
      expect(crop.top, closeTo(999.0 - 270.0, 0.001));
    });

    test('box larger than image triggers scale reduction to fit', () {
      // Image is 400x400, face box is 200x200, scale requested 4.0.
      // 200 * 4 = 800 > 399, so scale must be reduced to 399 / 200 = 1.995.
      const Rect faceBox = Rect.fromLTWH(100, 100, 200, 200);
      const int srcW = 400;
      const int srcH = 400;

      final Rect crop = cropper.computeCropRect(
        faceBox: faceBox,
        srcW: srcW,
        srcH: srcH,
        cropScale: 4.0,
      );

      expect(crop.width, lessThanOrEqualTo(399.0));
      expect(crop.height, lessThanOrEqualTo(399.0));
      expect(crop.left, greaterThanOrEqualTo(0.0));
      expect(crop.right, lessThanOrEqualTo(399.0));
      expect(crop.top, greaterThanOrEqualTo(0.0));
      expect(crop.bottom, lessThanOrEqualTo(399.0));
      expect(crop.width, closeTo(crop.height, 0.001)); // Aspect ratio preserved
    });

    test('box expansion multiplier expands box before scaling', () {
      const Rect faceBox = Rect.fromLTWH(300, 300, 100, 100);
      const int srcW = 1000;
      const int srcH = 1000;

      final Rect normalCrop = cropper.computeCropRect(
        faceBox: faceBox,
        srcW: srcW,
        srcH: srcH,
        cropScale: 2.0,
        boxExpansion: 1.0,
      );
      final Rect expandedCrop = cropper.computeCropRect(
        faceBox: faceBox,
        srcW: srcW,
        srcH: srcH,
        cropScale: 2.0,
        boxExpansion: 1.2,
      );

      expect(normalCrop.width, closeTo(200.0, 0.001));
      expect(expandedCrop.width, closeTo(240.0, 0.001)); // 100 * 1.2 * 2.0
      expect(expandedCrop.center, equals(faceBox.center));
    });

    test(
      'computeUprightToCropTransform maps crop rect to destination bounds',
      () {
        const Rect cropRect = Rect.fromLTWH(100, 200, 300, 300);
        final AffineMatrix transform = cropper.computeUprightToCropTransform(
          cropRect: cropRect,
          outW: 80,
          outH: 80,
        );

        // Top-left should map to (0, 0)
        final Offset p0 = transform.mapPoint(cropRect.topLeft);
        expect(p0.dx, closeTo(0.0, 0.001));
        expect(p0.dy, closeTo(0.0, 0.001));

        // Bottom-right should map to (80, 80)
        final Offset p1 = transform.mapPoint(cropRect.bottomRight);
        expect(p1.dx, closeTo(80.0, 0.001));
        expect(p1.dy, closeTo(80.0, 0.001));

        // Center should map to (40, 40)
        final Offset pCenter = transform.mapPoint(cropRect.center);
        expect(pCenter.dx, closeTo(40.0, 0.001));
        expect(pCenter.dy, closeTo(40.0, 0.001));
      },
    );
  });
}
