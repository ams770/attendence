import 'dart:ui';

import 'package:attendence/features/detection/domain/preview_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PreviewMapper', () {
    test(
      'computes correct scale and offsets for wider image in cover mode',
      () {
        // Image: 800 x 400 (aspect 2.0). Preview: 300 x 300 (aspect 1.0)
        // Scale should be max(300/800, 300/400) = max(0.375, 0.75) = 0.75
        // Scaled width = 800 * 0.75 = 600. Scaled height = 400 * 0.75 = 300
        // dx = (300 - 600) / 2 = -150. dy = (300 - 300) / 2 = 0
        const PreviewMapper mapper = PreviewMapper(
          imageSize: Size(800, 400),
          previewSize: Size(300, 300),
          mirror: false,
        );

        expect(mapper.scale, equals(0.75));
        expect(mapper.dx, equals(-150.0));
        expect(mapper.dy, equals(0.0));
      },
    );

    test('computes correct scale and offsets for taller image in cover mode', () {
      // Image: 720 x 1280 (portrait). Preview: 360 x 720
      // Scale = max(360/720, 720/1280) = max(0.5, 0.5625) = 0.5625
      // Scaled width = 720 * 0.5625 = 405. Scaled height = 1280 * 0.5625 = 720
      // dx = (360 - 405) / 2 = -22.5. dy = 0.0
      const PreviewMapper mapper = PreviewMapper(
        imageSize: Size(720, 1280),
        previewSize: Size(360, 720),
        mirror: false,
      );

      expect(mapper.scale, equals(0.5625));
      expect(mapper.dx, equals(-22.5));
      expect(mapper.dy, equals(0.0));
    });

    test('maps and unmaps points without mirroring roundtrip', () {
      const PreviewMapper mapper = PreviewMapper(
        imageSize: Size(720, 1280),
        previewSize: Size(360, 640),
        mirror: false,
      );

      const Offset original = Offset(100.0, 250.0);
      final Offset preview = mapper.mapPoint(original);
      final Offset restored = mapper.unmapPoint(preview);

      expect(restored.dx, closeTo(original.dx, 1e-6));
      expect(restored.dy, closeTo(original.dy, 1e-6));
    });

    test('maps points with front camera horizontal mirroring', () {
      // Image 100x100, Preview 100x100. Scale = 1.0, dx = 0, dy = 0
      // Mirroring point (20, 30) horizontally -> (100 - 20, 30) = (80, 30)
      const PreviewMapper mapper = PreviewMapper(
        imageSize: Size(100, 100),
        previewSize: Size(100, 100),
        mirror: true,
      );

      final Offset mapped = mapper.mapPoint(const Offset(20.0, 30.0));
      expect(mapped.dx, equals(80.0));
      expect(mapped.dy, equals(30.0));

      final Offset restored = mapper.unmapPoint(mapped);
      expect(restored.dx, closeTo(20.0, 1e-6));
      expect(restored.dy, closeTo(30.0, 1e-6));
    });

    test('maps and unmaps Rect preserving dimensions under mirroring', () {
      const PreviewMapper mapper = PreviewMapper(
        imageSize: Size(720, 1280),
        previewSize: Size(360, 720),
        mirror: true,
      );

      const Rect original = Rect.fromLTRB(100.0, 200.0, 300.0, 500.0);
      final Rect preview = mapper.mapRect(original);

      // Width and height in preview must match scale
      expect(preview.width, closeTo(original.width * mapper.scale, 1e-6));
      expect(preview.height, closeTo(original.height * mapper.scale, 1e-6));

      // Unmap back to original
      final Rect restored = mapper.unmapRect(preview);
      expect(restored.left, closeTo(original.left, 1e-6));
      expect(restored.top, closeTo(original.top, 1e-6));
      expect(restored.right, closeTo(original.right, 1e-6));
      expect(restored.bottom, closeTo(original.bottom, 1e-6));
    });

    group('PreviewMapper.forDevice', () {
      test('disables mirror on iOS front camera because AVFoundation is pre-mirrored', () {
        final PreviewMapper mapper = PreviewMapper.forDevice(
          imageSize: const Size(720, 1280),
          previewSize: const Size(393, 852),
          isFrontCamera: true,
          isAndroid: false,
        );

        expect(mapper.mirror, isFalse);
      });

      test('enables mirror on Android front camera', () {
        final PreviewMapper mapper = PreviewMapper.forDevice(
          imageSize: const Size(720, 1280),
          previewSize: const Size(360, 800),
          isFrontCamera: true,
          isAndroid: true,
        );

        expect(mapper.mirror, isTrue);
      });

      test('disables mirror on back cameras for both platforms', () {
        final PreviewMapper iosBackMapper = PreviewMapper.forDevice(
          imageSize: const Size(720, 1280),
          previewSize: const Size(393, 852),
          isFrontCamera: false,
          isAndroid: false,
        );
        expect(iosBackMapper.mirror, isFalse);

        final PreviewMapper androidBackMapper = PreviewMapper.forDevice(
          imageSize: const Size(720, 1280),
          previewSize: const Size(360, 800),
          isFrontCamera: false,
          isAndroid: true,
        );
        expect(androidBackMapper.mirror, isFalse);
      });
    });
  });
}
