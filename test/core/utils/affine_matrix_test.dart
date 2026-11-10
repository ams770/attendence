import 'dart:math' as math;

import 'package:attendence/core/utils/affine_matrix.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AffineMatrix', () {
    test('identity transform preserves points', () {
      const AffineMatrix m = AffineMatrix.identity;
      final ({double x, double y}) pt = m.transformPoint(10.0, 25.0);
      expect(pt.x, closeTo(10.0, 1e-6));
      expect(pt.y, closeTo(25.0, 1e-6));
    });

    test('translation shifts points by (tx, ty)', () {
      final AffineMatrix m = AffineMatrix.translation(5.0, -12.0);
      final ({double x, double y}) pt = m.transformPoint(10.0, 20.0);
      expect(pt.x, closeTo(15.0, 1e-6));
      expect(pt.y, closeTo(8.0, 1e-6));
    });

    test('scale scales coordinates uniformly or non-uniformly', () {
      final AffineMatrix m = AffineMatrix.scale(2.0, 0.5);
      final ({double x, double y}) pt = m.transformPoint(10.0, 20.0);
      expect(pt.x, closeTo(20.0, 1e-6));
      expect(pt.y, closeTo(10.0, 1e-6));
    });

    test('rotation rotates points around origin', () {
      final AffineMatrix m = AffineMatrix.rotation(math.pi / 2.0);
      final ({double x, double y}) pt = m.transformPoint(1.0, 0.0);
      expect(pt.x, closeTo(0.0, 1e-6));
      expect(pt.y, closeTo(1.0, 1e-6));
    });

    test('rotation around custom center rotates around specified pivot', () {
      final AffineMatrix m = AffineMatrix.rotation(
        math.pi / 2.0,
        cx: 5.0,
        cy: 5.0,
      );
      final ({double x, double y}) pt = m.transformPoint(6.0, 5.0);
      expect(pt.x, closeTo(5.0, 1e-6));
      expect(pt.y, closeTo(6.0, 1e-6));
    });

    test('multiply composes transforms correctly', () {
      final AffineMatrix t = AffineMatrix.translation(10.0, 20.0);
      final AffineMatrix s = AffineMatrix.scale(2.0, 2.0);

      // (T * S)(x, y) = T(S(x, y)) = 2*x + 10, 2*y + 20
      final AffineMatrix combined = t.multiply(s);
      final ({double x, double y}) pt = combined.transformPoint(5.0, 5.0);
      expect(pt.x, closeTo(20.0, 1e-6));
      expect(pt.y, closeTo(30.0, 1e-6));
    });

    test('inverted computes exact inverse transform', () {
      final AffineMatrix m = AffineMatrix(
        a: 2.0,
        b: 1.0,
        tx: 4.0,
        c: 1.0,
        d: 3.0,
        ty: -2.0,
      );
      final AffineMatrix inv = m.inverted();
      final AffineMatrix ident = m.multiply(inv);

      expect(ident.a, closeTo(1.0, 1e-6));
      expect(ident.b, closeTo(0.0, 1e-6));
      expect(ident.tx, closeTo(0.0, 1e-6));
      expect(ident.c, closeTo(0.0, 1e-6));
      expect(ident.d, closeTo(1.0, 1e-6));
      expect(ident.ty, closeTo(0.0, 1e-6));
    });

    test('inverted throws StateError on singular matrix', () {
      final AffineMatrix singular = AffineMatrix(
        a: 1.0,
        b: 2.0,
        tx: 0.0,
        c: 2.0,
        d: 4.0,
        ty: 0.0,
      );
      expect(() => singular.inverted(), throwsStateError);
    });

    test('equality and hashCode contract', () {
      final AffineMatrix m1 = AffineMatrix.translation(10.0, 20.0);
      final AffineMatrix m2 = AffineMatrix.translation(10.0, 20.0);
      final AffineMatrix m3 = AffineMatrix.translation(10.1, 20.0);

      expect(m1, equals(m2));
      expect(m1.hashCode, equals(m2.hashCode));
      expect(m1, isNot(equals(m3)));
    });
  });
}
