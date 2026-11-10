import 'dart:math' as math;
import 'dart:ui';

import '../../../core/utils/affine_matrix.dart';
import 'detected_face.dart';

/// Aligns facial landmarks to the standard 112x112 ArcFace template using the
/// Umeyama least-squares similarity transform (scale, rotation, translation).
class FaceAligner {
  const FaceAligner();

  /// Canonical 112x112 facial alignment template points (ArcFace / InsightFace standard):
  /// 1. Left eye in image
  /// 2. Right eye in image
  /// 3. Nose base
  /// 4. Left mouth corner in image
  /// 5. Right mouth corner in image
  static const List<Offset> standardTemplate = <Offset>[
    Offset(38.2946, 51.6963), // Left eye
    Offset(73.5318, 51.5014), // Right eye
    Offset(56.0252, 71.7366), // Nose
    Offset(41.5493, 92.3655), // Left mouth
    Offset(70.7299, 92.2041), // Right mouth
  ];

  /// Canonical output crop dimensions.
  static const int outputWidth = 112;
  static const int outputHeight = 112;

  /// Sorts detected facial landmarks so that left and right positions are ordered
  /// strictly by horizontal image x coordinate (left.dx <= right.dx).
  ///
  /// This prevents landmark inversion under front camera preview mirroring.
  static FiveLandmarks sortLandmarks({
    required Offset eyeA,
    required Offset eyeB,
    required Offset nose,
    required Offset mouthA,
    required Offset mouthB,
  }) {
    final Offset leftEye = (eyeA.dx <= eyeB.dx) ? eyeA : eyeB;
    final Offset rightEye = (eyeA.dx <= eyeB.dx) ? eyeB : eyeA;
    final Offset leftMouth = (mouthA.dx <= mouthB.dx) ? mouthA : mouthB;
    final Offset rightMouth = (mouthA.dx <= mouthB.dx) ? mouthB : mouthA;

    return FiveLandmarks(
      leftEye: leftEye,
      rightEye: rightEye,
      noseBase: nose,
      leftMouth: leftMouth,
      rightMouth: rightMouth,
    );
  }

  /// Computes the 2x3 affine similarity transform matrix (represented as [AffineMatrix])
  /// that maps [landmarks] in upright image coordinates to [destinationTemplate].
  ///
  /// Returns null if the source points are degenerate (variance < 1e-12).
  AffineMatrix? computeSimilarityTransform(
    FiveLandmarks landmarks, {
    List<Offset> destinationTemplate = standardTemplate,
  }) {
    return computeUmeyama(landmarks.asList, destinationTemplate);
  }

  /// Computes the Umeyama least-squares similarity transformation from 2D points [src]
  /// to 2D points [dst].
  ///
  /// Returns the 2x3 affine matrix:
  /// [ a   b   tx ]
  /// [ c   d   ty ]
  /// satisfying: dst ≈ s * R * src + t.
  ///
  /// Reflections are rejected and constrained to proper rotations (det(R) = +1.0).
  static AffineMatrix? computeUmeyama(List<Offset> src, List<Offset> dst) {
    final int n = src.length;
    if (n < 2 || dst.length != n) return null;

    // 1. Centroids
    double meanSrcX = 0.0, meanSrcY = 0.0;
    double meanDstX = 0.0, meanDstY = 0.0;

    for (int i = 0; i < n; i++) {
      meanSrcX += src[i].dx;
      meanSrcY += src[i].dy;
      meanDstX += dst[i].dx;
      meanDstY += dst[i].dy;
    }

    meanSrcX /= n;
    meanSrcY /= n;
    meanDstX /= n;
    meanDstY /= n;

    // 2. Variance of source and covariance between dst and src
    double varSrc = 0.0;
    double sxx = 0.0, sxy = 0.0, syx = 0.0, syy = 0.0;

    for (int i = 0; i < n; i++) {
      final double dxSrc = src[i].dx - meanSrcX;
      final double dySrc = src[i].dy - meanSrcY;
      final double dxDst = dst[i].dx - meanDstX;
      final double dyDst = dst[i].dy - meanDstY;

      varSrc += dxSrc * dxSrc + dySrc * dySrc;

      // Covariance Cov = (dst - meanDst)^T * (src - meanSrc) / n
      sxx += dxDst * dxSrc;
      sxy += dxDst * dySrc;
      syx += dyDst * dxSrc;
      syy += dyDst * dySrc;
    }

    varSrc /= n;
    if (varSrc < 1e-12) return null; // Degenerate source points

    sxx /= n;
    sxy /= n;
    syx /= n;
    syy /= n;

    // 3. SVD of 2x2 Covariance Matrix Cov = U * D * V^T using Givens rotations
    final double s1 = sxx + syy;
    final double d1 = sxx - syy;
    final double s2 = syx - sxy;
    final double d2 = syx + sxy;
    final double diff = math.atan2(s2, s1);
    final double sum = math.atan2(d2, d1);
    final double theta = (sum + diff) / 2.0;
    final double phi = (sum - diff) / 2.0;

    double u00 = math.cos(theta), u01 = -math.sin(theta);
    double u10 = math.sin(theta), u11 = math.cos(theta);

    double v00 = math.cos(phi), v01 = -math.sin(phi);
    double v10 = math.sin(phi), v11 = math.cos(phi);

    // M = Cov * V
    final double m00 = sxx * v00 + sxy * v10;
    final double m01 = sxx * v01 + sxy * v11;
    final double m10 = syx * v00 + syy * v10;
    final double m11 = syx * v01 + syy * v11;

    // D = U^T * M
    double d00 = u00 * m00 + u10 * m10;
    double d11 = u01 * m01 + u11 * m11;

    // Enforce positive singular values by sign adjustment
    if (d00 < 0) {
      d00 = -d00;
      u00 = -u00;
      u10 = -u10;
    }
    if (d11 < 0) {
      d11 = -d11;
      u01 = -u01;
      u11 = -u11;
    }

    // Sort singular values d00 >= d11
    if (d00 < d11) {
      final double tempD = d00;
      d00 = d11;
      d11 = tempD;

      final double tempU0 = u00, tempU1 = u10;
      u00 = u01;
      u10 = u11;
      u01 = tempU0;
      u11 = tempU1;

      final double tempV0 = v00, tempV1 = v10;
      v00 = v01;
      v10 = v11;
      v01 = tempV0;
      v11 = tempV1;
    }

    // Determinants of orthogonal matrices U and V
    final double detU = u00 * u11 - u01 * u10;
    final double detV = v00 * v11 - v01 * v10;

    // Constrain to proper rotation (reject reflection):
    // S = diag(1, det(U) * det(V))
    final double sLast = (detU * detV).sign < 0 ? -1.0 : 1.0;

    // R = U * S * V^T
    final double sv00 = v00;
    final double sv01 = v10;
    final double sv10 = sLast * v01;
    final double sv11 = sLast * v11;

    final double r00 = u00 * sv00 + u01 * sv10;
    final double r01 = u00 * sv01 + u01 * sv11;
    final double r10 = u10 * sv00 + u11 * sv10;
    final double r11 = u10 * sv01 + u11 * sv11;

    // Scale factor: s = tr(D * S) / varSrc = (d00 + d11 * sLast) / varSrc
    final double scale = (d00 + d11 * sLast) / varSrc;

    // Translation vector: t = meanDst - s * R * meanSrc
    final double tx = meanDstX - scale * (r00 * meanSrcX + r01 * meanSrcY);
    final double ty = meanDstY - scale * (r10 * meanSrcX + r11 * meanSrcY);

    final double a = scale * r00;
    final double b = scale * r01;
    final double c = scale * r10;
    final double d = scale * r11;

    return AffineMatrix(a: a, b: b, tx: tx, c: c, d: d, ty: ty);
  }
}
