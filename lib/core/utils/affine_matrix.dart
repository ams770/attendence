import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// An immutable 2D affine transformation represented by a 3x3 matrix:
///
/// [ a   b   tx ]
/// [ c   d   ty ]
/// [ 0   0   1  ]
@immutable
class AffineMatrix {
  const AffineMatrix({
    required this.a,
    required this.b,
    required this.tx,
    required this.c,
    required this.d,
    required this.ty,
  });

  /// Identity affine transform.
  static const AffineMatrix identity = AffineMatrix(
    a: 1.0,
    b: 0.0,
    tx: 0.0,
    c: 0.0,
    d: 1.0,
    ty: 0.0,
  );

  final double a;
  final double b;
  final double tx;
  final double c;
  final double d;
  final double ty;

  /// Pure translation transform.
  factory AffineMatrix.translation(double tx, double ty) {
    return AffineMatrix(a: 1.0, b: 0.0, tx: tx, c: 0.0, d: 1.0, ty: ty);
  }

  /// Pure scaling transform.
  factory AffineMatrix.scale(double sx, [double? sy]) {
    final double actualSy = sy ?? sx;
    return AffineMatrix(a: sx, b: 0.0, tx: 0.0, c: 0.0, d: actualSy, ty: 0.0);
  }

  /// Rotation transform about origin (0, 0) or specified center (cx, cy).
  factory AffineMatrix.rotation(
    double radians, {
    double cx = 0.0,
    double cy = 0.0,
  }) {
    final double cosVal = math.cos(radians);
    final double sinVal = math.sin(radians);
    if (cx == 0.0 && cy == 0.0) {
      return AffineMatrix(
        a: cosVal,
        b: -sinVal,
        tx: 0.0,
        c: sinVal,
        d: cosVal,
        ty: 0.0,
      );
    }
    // Translation(cx, cy) * Rotation(radians) * Translation(-cx, -cy)
    return AffineMatrix(
      a: cosVal,
      b: -sinVal,
      tx: cx * (1.0 - cosVal) + cy * sinVal,
      c: sinVal,
      d: cosVal,
      ty: cy * (1.0 - cosVal) - cx * sinVal,
    );
  }

  /// Transforms a 2D point (x, y) into (x', y').
  ({double x, double y}) transformPoint(double x, double y) {
    return (x: a * x + b * y + tx, y: c * x + d * y + ty);
  }

  /// Transforms an [Offset] (x, y) into a transformed [Offset] (x', y').
  Offset mapPoint(Offset p) {
    return Offset(a * p.dx + b * p.dy + tx, c * p.dx + d * p.dy + ty);
  }

  /// Transforms coordinates (x, y) into a transformed [Offset] (x', y').
  Offset mapXY(double x, double y) {
    return Offset(a * x + b * y + tx, c * x + d * y + ty);
  }

  /// Multiplies this matrix by another affine matrix: [this] * [other].
  AffineMatrix multiply(AffineMatrix other) {
    return AffineMatrix(
      a: a * other.a + b * other.c,
      b: a * other.b + b * other.d,
      tx: a * other.tx + b * other.ty + tx,
      c: c * other.a + d * other.c,
      d: c * other.b + d * other.d,
      ty: c * other.tx + d * other.ty + ty,
    );
  }

  /// Computes the inverse of this affine matrix.
  ///
  /// Throws [StateError] if the determinant is 0.
  AffineMatrix inverted() {
    final double det = a * d - b * c;
    if (det.abs() < 1e-12) {
      throw StateError('Affine matrix is singular and cannot be inverted.');
    }
    final double invDet = 1.0 / det;
    final double invA = d * invDet;
    final double invB = -b * invDet;
    final double invC = -c * invDet;
    final double invD = a * invDet;
    final double invTx = (b * ty - d * tx) * invDet;
    final double invTy = (c * tx - a * ty) * invDet;

    return AffineMatrix(
      a: invA,
      b: invB,
      tx: invTx,
      c: invC,
      d: invD,
      ty: invTy,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AffineMatrix &&
        (a - other.a).abs() < 1e-9 &&
        (b - other.b).abs() < 1e-9 &&
        (tx - other.tx).abs() < 1e-9 &&
        (c - other.c).abs() < 1e-9 &&
        (d - other.d).abs() < 1e-9 &&
        (ty - other.ty).abs() < 1e-9;
  }

  @override
  int get hashCode => Object.hash(
    a.toStringAsFixed(6),
    b.toStringAsFixed(6),
    tx.toStringAsFixed(6),
    c.toStringAsFixed(6),
    d.toStringAsFixed(6),
    ty.toStringAsFixed(6),
  );

  @override
  String toString() =>
      'AffineMatrix(a: $a, b: $b, tx: $tx, c: $c, d: $d, ty: $ty)';
}
