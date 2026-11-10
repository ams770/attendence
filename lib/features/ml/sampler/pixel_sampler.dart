import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../../core/utils/affine_matrix.dart';
import '../../camera/domain/frame_data.dart';
import '../../camera/domain/frame_geometry.dart';
import '../worker/worker_protocol.dart';

/// Pure Dart pixel sampler providing fast bilinear sampling and geometric warping
/// directly on raw camera image buffers without intermediate full-frame conversions.
class PixelSampler {
  const PixelSampler();

  /// Warps a region of the [frame] defined by an affine transformation into an
  /// RGB output buffer of size [outW] x [outH].
  ///
  /// [uprightToOutput] maps upright portrait coordinates to destination output
  /// coordinates [0, outW] x [0, outH].
  /// The sampler inverts this to find source coordinates, composes it with
  /// [FrameGeometry.uprightToRaw], and bilinearly interpolates RGB pixels.
  ///
  /// Out-of-bounds samples are padded with [padValue] (0 - 255).
  /// Reusable [outBuffer] avoids memory allocation per frame.
  Uint8List warpAffine(
    FrameData frame,
    AffineMatrix uprightToOutput,
    int outW,
    int outH, {
    Uint8List? outBuffer,
    int padValue = 0,
  }) {
    final int requiredLen = outW * outH * 3;
    final Uint8List buffer = outBuffer ?? Uint8List(requiredLen);
    assert(
      buffer.length >= requiredLen,
      'outBuffer must be at least $requiredLen bytes',
    );

    final FrameGeometry geometry = FrameGeometry(
      rawWidth: frame.width,
      rawHeight: frame.height,
      rotation: frame.sensorRotation,
    );

    // M_o2u: maps output (destination) coordinates to upright coordinates
    final AffineMatrix outputToUpright = uprightToOutput.inverted();
    // M_u2r: maps upright coordinates to raw buffer coordinates
    final AffineMatrix uprightToRaw = geometry.uprightToRaw;
    // M_o2r: maps output pixel coordinates directly to raw buffer coordinates
    final AffineMatrix outputToRaw = uprightToRaw.multiply(outputToUpright);

    final double mA = outputToRaw.a;
    final double mB = outputToRaw.b;
    final double mTx = outputToRaw.tx;
    final double mC = outputToRaw.c;
    final double mD = outputToRaw.d;
    final double mTy = outputToRaw.ty;

    final int rawW = frame.width;
    final int rawH = frame.height;
    final FrameFormat format = frame.format;

    int outIndex = 0;

    for (int yOut = 0; yOut < outH; yOut++) {
      final double rowRawX = mB * yOut + mTx;
      final double rowRawY = mD * yOut + mTy;

      for (int xOut = 0; xOut < outW; xOut++) {
        final double srcX = mA * xOut + rowRawX;
        final double srcY = mC * xOut + rowRawY;

        final int x0 = srcX.floor();
        final int y0 = srcY.floor();
        final int x1 = x0 + 1;
        final int y1 = y0 + 1;

        final double fx = srcX - x0;
        final double fy = srcY - y0;

        final double w00 = (1.0 - fx) * (1.0 - fy);
        final double w10 = fx * (1.0 - fy);
        final double w01 = (1.0 - fx) * fy;
        final double w11 = fx * fy;

        final ({int r, int g, int b}) p00 = _samplePixel(
          frame,
          format,
          x0,
          y0,
          rawW,
          rawH,
          padValue,
        );
        final ({int r, int g, int b}) p10 = _samplePixel(
          frame,
          format,
          x1,
          y0,
          rawW,
          rawH,
          padValue,
        );
        final ({int r, int g, int b}) p01 = _samplePixel(
          frame,
          format,
          x0,
          y1,
          rawW,
          rawH,
          padValue,
        );
        final ({int r, int g, int b}) p11 = _samplePixel(
          frame,
          format,
          x1,
          y1,
          rawW,
          rawH,
          padValue,
        );

        final int r = (p00.r * w00 + p10.r * w10 + p01.r * w01 + p11.r * w11)
            .round()
            .clamp(0, 255);
        final int g = (p00.g * w00 + p10.g * w10 + p01.g * w01 + p11.g * w11)
            .round()
            .clamp(0, 255);
        final int b = (p00.b * w00 + p10.b * w10 + p01.b * w01 + p11.b * w11)
            .round()
            .clamp(0, 255);

        buffer[outIndex++] = r;
        buffer[outIndex++] = g;
        buffer[outIndex++] = b;
      }
    }

    return buffer;
  }

  /// Downsamples the [frame] directly into a grayscale grid of size
  /// [targetWidth] x [targetHeight] for real-time image quality evaluation.
  Uint8List toGrayscaleDownsampled(
    FrameData frame, {
    required int targetWidth,
    required int targetHeight,
    Uint8List? outBuffer,
  }) {
    final int requiredLen = targetWidth * targetHeight;
    final Uint8List buffer = outBuffer ?? Uint8List(requiredLen);
    assert(
      buffer.length >= requiredLen,
      'outBuffer must be at least $requiredLen bytes',
    );

    final int rawW = frame.width;
    final int rawH = frame.height;
    final FramePlane plane0 = frame.planes[0];
    final int rowStride = plane0.bytesPerRow;
    final Uint8List bytes0 = plane0.bytes;

    int outIdx = 0;

    if (frame.format == FrameFormat.bgra8888) {
      for (int y = 0; y < targetHeight; y++) {
        final int srcY = (y * rawH) ~/ targetHeight;
        final int rowOffset = srcY * rowStride;
        for (int x = 0; x < targetWidth; x++) {
          final int srcX = (x * rawW) ~/ targetWidth;
          final int offset = rowOffset + (srcX * 4);
          final int b = bytes0[offset];
          final int g = bytes0[offset + 1];
          final int r = bytes0[offset + 2];
          // Standard ITU-R BT.601 luma conversion
          buffer[outIdx++] = (299 * r + 587 * g + 114 * b) ~/ 1000;
        }
      }
    } else {
      // NV21 and YUV420: Plane 0 is luma (Y)
      for (int y = 0; y < targetHeight; y++) {
        final int srcY = (y * rawH) ~/ targetHeight;
        final int rowOffset = srcY * rowStride;
        for (int x = 0; x < targetWidth; x++) {
          final int srcX = (x * rawW) ~/ targetWidth;
          buffer[outIdx++] = bytes0[rowOffset + srcX];
        }
      }
    }

    return buffer;
  }

  /// Warps a region of the [frame] defined by an affine transformation into a
  /// grayscale (luma) output buffer of size [outW] x [outH].
  Uint8List warpGrayscale(
    FrameData frame,
    AffineMatrix uprightToOutput,
    int outW,
    int outH, {
    Uint8List? outBuffer,
    int padValue = 0,
  }) {
    final int requiredLen = outW * outH;
    final Uint8List buffer = outBuffer ?? Uint8List(requiredLen);
    assert(
      buffer.length >= requiredLen,
      'outBuffer must be at least $requiredLen bytes',
    );

    final FrameGeometry geometry = FrameGeometry(
      rawWidth: frame.width,
      rawHeight: frame.height,
      rotation: frame.sensorRotation,
    );

    final AffineMatrix outputToUpright = uprightToOutput.inverted();
    final AffineMatrix uprightToRaw = geometry.uprightToRaw;
    final AffineMatrix outputToRaw = uprightToRaw.multiply(outputToUpright);

    final double mA = outputToRaw.a;
    final double mB = outputToRaw.b;
    final double mTx = outputToRaw.tx;
    final double mC = outputToRaw.c;
    final double mD = outputToRaw.d;
    final double mTy = outputToRaw.ty;

    final int rawW = frame.width;
    final int rawH = frame.height;
    final FrameFormat format = frame.format;

    int outIndex = 0;

    for (int yOut = 0; yOut < outH; yOut++) {
      final double rowRawX = mB * yOut + mTx;
      final double rowRawY = mD * yOut + mTy;

      for (int xOut = 0; xOut < outW; xOut++) {
        final double srcX = mA * xOut + rowRawX;
        final double srcY = mC * xOut + rowRawY;

        final int x0 = srcX.floor();
        final int y0 = srcY.floor();
        final int x1 = x0 + 1;
        final int y1 = y0 + 1;

        final double fx = srcX - x0;
        final double fy = srcY - y0;

        final double w00 = (1.0 - fx) * (1.0 - fy);
        final double w10 = fx * (1.0 - fy);
        final double w01 = (1.0 - fx) * fy;
        final double w11 = fx * fy;

        final int p00 = _sampleLuma(
          frame,
          format,
          x0,
          y0,
          rawW,
          rawH,
          padValue,
        );
        final int p10 = _sampleLuma(
          frame,
          format,
          x1,
          y0,
          rawW,
          rawH,
          padValue,
        );
        final int p01 = _sampleLuma(
          frame,
          format,
          x0,
          y1,
          rawW,
          rawH,
          padValue,
        );
        final int p11 = _sampleLuma(
          frame,
          format,
          x1,
          y1,
          rawW,
          rawH,
          padValue,
        );

        final double luma = w00 * p00 + w10 * p10 + w01 * p01 + w11 * p11;
        buffer[outIndex++] = luma.round().clamp(0, 255);
      }
    }

    return buffer;
  }

  /// Computes face image quality statistics (sharpness, brightness, glare) on a
  /// small grayscale crop of the face bounding box in upright coordinates.
  FaceStats computeFaceStats(
    FrameData frame,
    Rect uprightFaceRect, {
    int sampleSize = 80,
    Uint8List? outBuffer,
  }) {
    if (uprightFaceRect.width <= 0 || uprightFaceRect.height <= 0) {
      return const FaceStats(
        sharpness: 0.0,
        meanBrightness: 0.0,
        nearSaturatedRatio: 0.0,
      );
    }

    final double sx = sampleSize / uprightFaceRect.width;
    final double sy = sampleSize / uprightFaceRect.height;
    final double tx = -uprightFaceRect.left * sx;
    final double ty = -uprightFaceRect.top * sy;
    final AffineMatrix uprightToOutput = AffineMatrix(
      a: sx,
      b: 0.0,
      tx: tx,
      c: 0.0,
      d: sy,
      ty: ty,
    );

    final Uint8List crop = warpGrayscale(
      frame,
      uprightToOutput,
      sampleSize,
      sampleSize,
      outBuffer: outBuffer,
    );

    double sumBrightness = 0.0;
    int nearSaturatedCount = 0;
    final int totalPixels = sampleSize * sampleSize;

    for (int i = 0; i < totalPixels; i++) {
      final int pixel = crop[i];
      sumBrightness += pixel;
      if (pixel >= 250) {
        nearSaturatedCount++;
      }
    }

    final double meanBrightness = totalPixels > 0
        ? sumBrightness / totalPixels
        : 0.0;
    final double nearSaturatedRatio = totalPixels > 0
        ? nearSaturatedCount / totalPixels
        : 0.0;

    double lapSum = 0.0;
    double lapSumSq = 0.0;
    int lapCount = 0;

    for (int y = 1; y < sampleSize - 1; y++) {
      final int rowOffset = y * sampleSize;
      final int rowAbove = (y - 1) * sampleSize;
      final int rowBelow = (y + 1) * sampleSize;

      for (int x = 1; x < sampleSize - 1; x++) {
        final int center = crop[rowOffset + x];
        final int top = crop[rowAbove + x];
        final int bottom = crop[rowBelow + x];
        final int left = crop[rowOffset + x - 1];
        final int right = crop[rowOffset + x + 1];

        final double lapVal = (top + bottom + left + right - 4.0 * center);
        lapSum += lapVal;
        lapSumSq += lapVal * lapVal;
        lapCount++;
      }
    }

    final double lapMean = lapCount > 0 ? lapSum / lapCount : 0.0;
    final double sharpness = lapCount > 0
        ? (lapSumSq / lapCount) - (lapMean * lapMean)
        : 0.0;

    return FaceStats(
      sharpness: sharpness,
      meanBrightness: meanBrightness,
      nearSaturatedRatio: nearSaturatedRatio,
    );
  }

  /// Samples mean RGB values across the specified [skinRegions] defined in upright image coordinates.
  SkinColorSampleData sampleSkinRegionsRgb(
    FrameData frame,
    List<Rect> skinRegions,
  ) {
    if (skinRegions.isEmpty) {
      return const SkinColorSampleData(
        meanR: 0.0,
        meanG: 0.0,
        meanB: 0.0,
        brightness: 0.0,
      );
    }

    final FrameGeometry geometry = FrameGeometry(
      rawWidth: frame.width,
      rawHeight: frame.height,
      rotation: frame.sensorRotation,
    );
    final AffineMatrix uprightToRaw = geometry.uprightToRaw;

    final int rawW = frame.width;
    final int rawH = frame.height;
    final FrameFormat format = frame.format;

    double totalR = 0.0;
    double totalG = 0.0;
    double totalB = 0.0;
    int pixelCount = 0;

    for (final Rect region in skinRegions) {
      final int left = region.left.round();
      final int right = region.right.round();
      final int top = region.top.round();
      final int bottom = region.bottom.round();

      final int stepX = math.max(1, (right - left) ~/ 10);
      final int stepY = math.max(1, (bottom - top) ~/ 10);

      for (int y = top; y < bottom; y += stepY) {
        for (int x = left; x < right; x += stepX) {
          final Offset rawPt = uprightToRaw.mapXY(x.toDouble(), y.toDouble());
          final int rawX = rawPt.dx.round();
          final int rawY = rawPt.dy.round();

          if (rawX >= 0 && rawX < rawW && rawY >= 0 && rawY < rawH) {
            final ({int r, int g, int b}) pixel = _samplePixel(
              frame,
              format,
              rawX,
              rawY,
              rawW,
              rawH,
              0,
            );
            totalR += pixel.r;
            totalG += pixel.g;
            totalB += pixel.b;
            pixelCount++;
          }
        }
      }
    }

    if (pixelCount == 0) {
      return const SkinColorSampleData(
        meanR: 0.0,
        meanG: 0.0,
        meanB: 0.0,
        brightness: 0.0,
      );
    }

    final double meanR = totalR / pixelCount;
    final double meanG = totalG / pixelCount;
    final double meanB = totalB / pixelCount;
    final double brightness = 0.299 * meanR + 0.587 * meanG + 0.114 * meanB;

    return SkinColorSampleData(
      meanR: meanR,
      meanG: meanG,
      meanB: meanB,
      brightness: brightness,
    );
  }

  int _sampleLuma(
    FrameData frame,
    FrameFormat format,
    int x,
    int y,
    int rawW,
    int rawH,
    int padValue,
  ) {
    if (x < 0 || x >= rawW || y < 0 || y >= rawH) {
      return padValue;
    }

    if (format == FrameFormat.bgra8888) {
      final FramePlane plane = frame.planes[0];
      final int offset = y * plane.bytesPerRow + (x * 4);
      final Uint8List bytes = plane.bytes;
      final int b = bytes[offset];
      final int g = bytes[offset + 1];
      final int r = bytes[offset + 2];
      return (299 * r + 587 * g + 114 * b) ~/ 1000;
    } else {
      final FramePlane yPlane = frame.planes[0];
      final int stride = yPlane.bytesPerRow;
      final int pixelStride = yPlane.bytesPerPixel ?? 1;
      return yPlane.bytes[y * stride + x * pixelStride];
    }
  }

  ({int r, int g, int b}) _samplePixel(
    FrameData frame,
    FrameFormat format,
    int x,
    int y,
    int rawW,
    int rawH,
    int padValue,
  ) {
    if (x < 0 || x >= rawW || y < 0 || y >= rawH) {
      return (r: padValue, g: padValue, b: padValue);
    }

    switch (format) {
      case FrameFormat.bgra8888:
        final FramePlane plane = frame.planes[0];
        final int offset = y * plane.bytesPerRow + (x * 4);
        final Uint8List bytes = plane.bytes;
        return (b: bytes[offset], g: bytes[offset + 1], r: bytes[offset + 2]);

      case FrameFormat.nv21:
        final FramePlane yPlane = frame.planes[0];
        final int yVal = yPlane.bytes[y * yPlane.bytesPerRow + x];

        final int cx = x >> 1;
        final int cy = y >> 1;
        int uVal;
        int vVal;

        if (frame.planes.length >= 2) {
          final FramePlane uvPlane = frame.planes[1];
          final int uvPixelStride = uvPlane.bytesPerPixel ?? 2;
          final int uvOffset = cy * uvPlane.bytesPerRow + (cx * uvPixelStride);
          // In NV21, V precedes U
          vVal = uvPlane.bytes[uvOffset];
          uVal = uvPlane.bytes[uvOffset + 1];
        } else {
          // Continuous single buffer NV21
          final int uvOffset =
              (yPlane.bytesPerRow * rawH) +
              (cy * yPlane.bytesPerRow) +
              (cx * 2);
          vVal = yPlane.bytes[uvOffset];
          uVal = yPlane.bytes[uvOffset + 1];
        }

        return _yuvToRgb(yVal, uVal, vVal);

      case FrameFormat.yuv420:
        final FramePlane yPlane = frame.planes[0];
        final int yVal = yPlane
            .bytes[y * yPlane.bytesPerRow + (x * (yPlane.bytesPerPixel ?? 1))];

        final int cx = x >> 1;
        final int cy = y >> 1;

        if (frame.planes.length >= 3) {
          final FramePlane uPlane = frame.planes[1];
          final FramePlane vPlane = frame.planes[2];
          final int uVal =
              uPlane.bytes[cy * uPlane.bytesPerRow +
                  (cx * (uPlane.bytesPerPixel ?? 1))];
          final int vVal =
              vPlane.bytes[cy * vPlane.bytesPerRow +
                  (cx * (vPlane.bytesPerPixel ?? 1))];
          return _yuvToRgb(yVal, uVal, vVal);
        } else {
          return (r: yVal, g: yVal, b: yVal);
        }
    }
  }

  /// Converts YUV (BT.601) values to RGB clamped to [0, 255].
  static ({int r, int g, int b}) _yuvToRgb(int y, int u, int v) {
    final int c = y;
    final int d = u - 128;
    final int e = v - 128;

    final int r = (c + ((1436 * e) >> 10)).clamp(0, 255);
    final int g = (c - ((352 * d + 731 * e) >> 10)).clamp(0, 255);
    final int b = (c + ((1815 * d) >> 10)).clamp(0, 255);

    return (r: r, g: g, b: b);
  }
}
