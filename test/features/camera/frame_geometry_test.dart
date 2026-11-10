import 'package:attendence/core/utils/affine_matrix.dart';
import 'package:attendence/features/camera/domain/frame_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FrameGeometry', () {
    const int rawW = 720;
    const int rawH = 1280;

    test('rotation 0 degrees preserves dimensions and transforms identity', () {
      final FrameGeometry geo = FrameGeometry(
        rawWidth: rawW,
        rawHeight: rawH,
        rotation: 0,
      );
      expect(geo.uprightWidth, equals(rawW));
      expect(geo.uprightHeight, equals(rawH));
      expect(geo.uprightToRaw, equals(AffineMatrix.identity));
      expect(geo.rawToUpright, equals(AffineMatrix.identity));

      final ({double x, double y}) pt = geo.uprightToRaw.transformPoint(
        100.0,
        200.0,
      );
      expect(pt.x, closeTo(100.0, 1e-6));
      expect(pt.y, closeTo(200.0, 1e-6));
    });

    test('rotation 90 degrees swaps dimensions and maps coordinates', () {
      final FrameGeometry geo = FrameGeometry(
        rawWidth: rawW,
        rawHeight: rawH,
        rotation: 90,
      );
      expect(geo.uprightWidth, equals(rawH)); // 1280
      expect(geo.uprightHeight, equals(rawW)); // 720

      // Upright (0, 0) top-left -> Raw (0, rawH)
      final ({double x, double y}) p0 = geo.uprightToRaw.transformPoint(
        0.0,
        0.0,
      );
      expect(p0.x, closeTo(0.0, 1e-6));
      expect(p0.y, closeTo(rawH.toDouble(), 1e-6));

      // Upright (uprightW, 0) top-right -> Raw (0, 0)
      final ({double x, double y}) p1 = geo.uprightToRaw.transformPoint(
        geo.uprightWidth.toDouble(),
        0.0,
      );
      expect(p1.x, closeTo(0.0, 1e-6));
      expect(p1.y, closeTo(0.0, 1e-6));

      // Inverse identity: uprightToRaw * rawToUpright == Identity
      final AffineMatrix composed = geo.uprightToRaw.multiply(geo.rawToUpright);
      expect(composed.a, closeTo(1.0, 1e-6));
      expect(composed.b, closeTo(0.0, 1e-6));
      expect(composed.tx, closeTo(0.0, 1e-6));
      expect(composed.c, closeTo(0.0, 1e-6));
      expect(composed.d, closeTo(1.0, 1e-6));
      expect(composed.ty, closeTo(0.0, 1e-6));
    });

    test('rotation 180 degrees keeps dimensions and inverts axes', () {
      final FrameGeometry geo = FrameGeometry(
        rawWidth: rawW,
        rawHeight: rawH,
        rotation: 180,
      );
      expect(geo.uprightWidth, equals(rawW));
      expect(geo.uprightHeight, equals(rawH));

      // Upright (0, 0) -> Raw (rawW, rawH)
      final ({double x, double y}) p0 = geo.uprightToRaw.transformPoint(
        0.0,
        0.0,
      );
      expect(p0.x, closeTo(rawW.toDouble(), 1e-6));
      expect(p0.y, closeTo(rawH.toDouble(), 1e-6));

      // Center (rawW/2, rawH/2) -> remains center
      final ({double x, double y}) pc = geo.uprightToRaw.transformPoint(
        rawW / 2.0,
        rawH / 2.0,
      );
      expect(pc.x, closeTo(rawW / 2.0, 1e-6));
      expect(pc.y, closeTo(rawH / 2.0, 1e-6));

      // Inverse identity
      final AffineMatrix composed = geo.uprightToRaw.multiply(geo.rawToUpright);
      expect(composed.a, closeTo(1.0, 1e-6));
      expect(composed.d, closeTo(1.0, 1e-6));
    });

    test('rotation 270 degrees swaps dimensions and maps coordinates', () {
      final FrameGeometry geo = FrameGeometry(
        rawWidth: rawW,
        rawHeight: rawH,
        rotation: 270,
      );
      expect(geo.uprightWidth, equals(rawH)); // 1280
      expect(geo.uprightHeight, equals(rawW)); // 720

      // Upright (0, 0) -> Raw (rawW, 0)
      final ({double x, double y}) p0 = geo.uprightToRaw.transformPoint(
        0.0,
        0.0,
      );
      expect(p0.x, closeTo(rawW.toDouble(), 1e-6));
      expect(p0.y, closeTo(0.0, 1e-6));

      // Upright (uprightW, 0) -> Raw (rawW, rawH)
      final ({double x, double y}) p1 = geo.uprightToRaw.transformPoint(
        geo.uprightWidth.toDouble(),
        0.0,
      );
      expect(p1.x, closeTo(rawW.toDouble(), 1e-6));
      expect(p1.y, closeTo(rawH.toDouble(), 1e-6));

      // Inverse identity: uprightToRaw * rawToUpright == Identity
      final AffineMatrix composed = geo.uprightToRaw.multiply(geo.rawToUpright);
      expect(composed.a, closeTo(1.0, 1e-6));
      expect(composed.b, closeTo(0.0, 1e-6));
      expect(composed.tx, closeTo(0.0, 1e-6));
      expect(composed.c, closeTo(0.0, 1e-6));
      expect(composed.d, closeTo(1.0, 1e-6));
      expect(composed.ty, closeTo(0.0, 1e-6));
    });

    test('constructor validates positive dimensions and valid rotations', () {
      expect(
        () => FrameGeometry(rawWidth: 0, rawHeight: 100, rotation: 0),
        throwsAssertionError,
      );
      expect(
        () => FrameGeometry(rawWidth: 100, rawHeight: 0, rotation: 0),
        throwsAssertionError,
      );
      expect(
        () => FrameGeometry(rawWidth: 100, rawHeight: 100, rotation: 45),
        throwsAssertionError,
      );
    });
  });
}
