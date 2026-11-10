import 'dart:math' as math;

import 'package:attendence/core/utils/affine_matrix.dart';
import 'package:attendence/features/detection/domain/detected_face.dart';
import 'package:attendence/features/detection/domain/face_aligner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaceAligner', () {
    const FaceAligner aligner = FaceAligner();
    final List<Offset> template = FaceAligner.standardTemplate;

    test(
      'sortLandmarks orders left and right strictly by horizontal position',
      () {
        final FiveLandmarks landmarks = FaceAligner.sortLandmarks(
          eyeA: const Offset(70.0, 50.0), // Higher x
          eyeB: const Offset(35.0, 50.0), // Lower x
          nose: const Offset(55.0, 70.0),
          mouthA: const Offset(75.0, 90.0), // Higher x
          mouthB: const Offset(40.0, 90.0), // Lower x
        );

        expect(landmarks.leftEye.dx, equals(35.0));
        expect(landmarks.rightEye.dx, equals(70.0));
        expect(landmarks.leftMouth.dx, equals(40.0));
        expect(landmarks.rightMouth.dx, equals(75.0));
        expect(landmarks.noseBase, equals(const Offset(55.0, 70.0)));
      },
    );

    test('Umeyama identity transform returns identity matrix', () {
      final AffineMatrix? matrix = FaceAligner.computeUmeyama(
        template,
        template,
      );
      expect(matrix, isNotNull);

      expect(matrix!.a, closeTo(1.0, 1e-6));
      expect(matrix.b, closeTo(0.0, 1e-6));
      expect(matrix.tx, closeTo(0.0, 1e-6));
      expect(matrix.c, closeTo(0.0, 1e-6));
      expect(matrix.d, closeTo(1.0, 1e-6));
      expect(matrix.ty, closeTo(0.0, 1e-6));

      for (int i = 0; i < template.length; i++) {
        final Offset mapped = matrix.mapPoint(template[i]);
        expect(mapped.dx, closeTo(template[i].dx, 1e-5));
        expect(mapped.dy, closeTo(template[i].dy, 1e-5));
      }
    });

    test('Umeyama recovers pure scale', () {
      const double scale = 2.5;
      final List<Offset> src = template.map((Offset p) => p / scale).toList();

      final AffineMatrix? matrix = FaceAligner.computeUmeyama(src, template);
      expect(matrix, isNotNull);

      expect(matrix!.a, closeTo(scale, 1e-5));
      expect(matrix.d, closeTo(scale, 1e-5));
      expect(matrix.b, closeTo(0.0, 1e-5));
      expect(matrix.c, closeTo(0.0, 1e-5));

      for (int i = 0; i < template.length; i++) {
        final Offset mapped = matrix.mapPoint(src[i]);
        expect(mapped.dx, closeTo(template[i].dx, 1e-5));
        expect(mapped.dy, closeTo(template[i].dy, 1e-5));
      }
    });

    test('Umeyama recovers pure rotation', () {
      const double angle = 40.0 * math.pi / 180.0;
      final double cosA = math.cos(angle);
      final double sinA = math.sin(angle);

      // Rotate source such that R * src = template => src = R^T * template
      final List<Offset> src = template.map((Offset p) {
        return Offset(cosA * p.dx + sinA * p.dy, -sinA * p.dx + cosA * p.dy);
      }).toList();

      final AffineMatrix? matrix = FaceAligner.computeUmeyama(src, template);
      expect(matrix, isNotNull);

      for (int i = 0; i < template.length; i++) {
        final Offset mapped = matrix!.mapPoint(src[i]);
        expect(mapped.dx, closeTo(template[i].dx, 1e-5));
        expect(mapped.dy, closeTo(template[i].dy, 1e-5));
      }
    });

    test('Umeyama recovers pure translation', () {
      const Offset shift = Offset(30.0, -45.0);
      final List<Offset> src = template.map((Offset p) => p - shift).toList();

      final AffineMatrix? matrix = FaceAligner.computeUmeyama(src, template);
      expect(matrix, isNotNull);

      expect(matrix!.tx, closeTo(shift.dx, 1e-5));
      expect(matrix.ty, closeTo(shift.dy, 1e-5));
      expect(matrix.a, closeTo(1.0, 1e-5));
      expect(matrix.d, closeTo(1.0, 1e-5));

      for (int i = 0; i < template.length; i++) {
        final Offset mapped = matrix.mapPoint(src[i]);
        expect(mapped.dx, closeTo(template[i].dx, 1e-5));
        expect(mapped.dy, closeTo(template[i].dy, 1e-5));
      }
    });

    test('Umeyama recovers combined scale, rotation, and translation', () {
      const double scale = 1.4;
      const double angle = -25.0 * math.pi / 180.0;
      final double cosA = math.cos(angle);
      final double sinA = math.sin(angle);
      const Offset translation = Offset(20.0, 35.0);

      // template = s * R * src + t => src = (1/s) * R^T * (template - t)
      final List<Offset> src = template.map((Offset p) {
        final double dx = p.dx - translation.dx;
        final double dy = p.dy - translation.dy;
        return Offset(
          (cosA * dx + sinA * dy) / scale,
          (-sinA * dx + cosA * dy) / scale,
        );
      }).toList();

      final AffineMatrix? matrix = FaceAligner.computeUmeyama(src, template);
      expect(matrix, isNotNull);

      for (int i = 0; i < template.length; i++) {
        final Offset mapped = matrix!.mapPoint(src[i]);
        expect(mapped.dx, closeTo(template[i].dx, 1e-5));
        expect(mapped.dy, closeTo(template[i].dy, 1e-5));
      }
    });

    test('Umeyama handles noisy points with least-squares fit', () {
      final List<Offset> noisy = <Offset>[
        Offset(template[0].dx + 0.8, template[0].dy - 0.5),
        Offset(template[1].dx - 0.7, template[1].dy + 0.6),
        Offset(template[2].dx + 0.3, template[2].dy + 0.2),
        Offset(template[3].dx - 0.5, template[3].dy - 0.8),
        Offset(template[4].dx + 0.6, template[4].dy + 0.4),
      ];

      final AffineMatrix? matrix = FaceAligner.computeUmeyama(noisy, template);
      expect(matrix, isNotNull);

      // Residual error should be small (sub-pixel)
      for (int i = 0; i < template.length; i++) {
        final Offset mapped = matrix!.mapPoint(noisy[i]);
        final double err = (mapped - template[i]).distance;
        expect(err, lessThan(1.5));
      }
    });

    test('Umeyama rejects reflection and enforces proper rotation', () {
      // Reflected template across y-axis (x -> -x)
      final List<Offset> reflectedSrc = template
          .map((Offset p) => Offset(-p.dx, p.dy))
          .toList();

      final AffineMatrix? matrix = FaceAligner.computeUmeyama(
        reflectedSrc,
        template,
      );
      expect(matrix, isNotNull);

      // The determinant of the rotation part R (normalized by scale^2) MUST be +1.0 (not -1.0)
      final double det = matrix!.a * matrix.d - matrix.b * matrix.c;
      expect(
        det,
        greaterThan(0.0),
      ); // Positive determinant ensures orientation preservation
    });

    test('Umeyama returns null for degenerate points', () {
      // All points collapsed to the same coordinate
      final List<Offset> degenerate = List<Offset>.filled(
        5,
        const Offset(50, 50),
      );
      final AffineMatrix? matrix = FaceAligner.computeUmeyama(
        degenerate,
        template,
      );
      expect(matrix, isNull);
    });

    test('computeSimilarityTransform accepts FiveLandmarks', () {
      final FiveLandmarks landmarks = FiveLandmarks(
        leftEye: template[0],
        rightEye: template[1],
        noseBase: template[2],
        leftMouth: template[3],
        rightMouth: template[4],
      );

      final AffineMatrix? matrix = aligner.computeSimilarityTransform(
        landmarks,
      );
      expect(matrix, isNotNull);
      expect(matrix!.a, closeTo(1.0, 1e-6));
    });
  });
}
