import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Maps coordinates and bounding rectangles between upright camera image space
/// and preview widget space, handling [BoxFit.cover] scaling, cropping offsets,
/// and front-camera display mirroring.
@immutable
class PreviewMapper {
  const PreviewMapper({
    required this.imageSize,
    required this.previewSize,
    required this.mirror,
  });

  /// Resolves coordinate mapping and mirroring based on target platform and camera lens direction.
  ///
  /// On iOS front camera, AVFoundation configures `isVideoMirrored = true` on the video data
  /// output, so both the raw frame buffer delivered to ML Kit and the preview texture are already
  /// in mirrored selfie coordinate space. Applying additional mirroring flips the coordinates.
  /// On Android front camera, frames delivered to ML Kit are unmirrored while the preview is
  /// mirrored, requiring horizontal coordinate inversion.
  factory PreviewMapper.forDevice({
    required Size imageSize,
    required Size previewSize,
    bool isFrontCamera = true,
    bool? isAndroid,
  }) {
    final bool isAndroidPlatform =
        isAndroid ?? (defaultTargetPlatform == TargetPlatform.android);
    final bool shouldMirror = isFrontCamera && isAndroidPlatform;
    return PreviewMapper(
      imageSize: imageSize,
      previewSize: previewSize,
      mirror: shouldMirror,
    );
  }

  /// Size of the camera frame in upright orientation (e.g. 720 x 1280).
  final Size imageSize;

  /// Size of the preview display widget (e.g. 360 x 640).
  final Size previewSize;

  /// Whether to mirror coordinates horizontally (true for front camera display).
  final bool mirror;

  /// Uniform scaling factor computed for [BoxFit.cover].
  double get scale => math.max(
    previewSize.width / imageSize.width,
    previewSize.height / imageSize.height,
  );

  /// Scaled image width on screen.
  double get scaledWidth => imageSize.width * scale;

  /// Scaled image height on screen.
  double get scaledHeight => imageSize.height * scale;

  /// Horizontal cropping/centering offset.
  double get dx => (previewSize.width - scaledWidth) / 2.0;

  /// Vertical cropping/centering offset.
  double get dy => (previewSize.height - scaledHeight) / 2.0;

  /// Maps a 2D point from upright image coordinates to preview widget coordinates.
  Offset mapPoint(Offset p) {
    final double unmirroredX = p.dx * scale + dx;
    final double y = p.dy * scale + dy;
    final double x = mirror ? (previewSize.width - unmirroredX) : unmirroredX;
    return Offset(x, y);
  }

  /// Maps a [Rect] from upright image coordinates to preview widget coordinates.
  Rect mapRect(Rect rect) {
    if (mirror) {
      final double left = previewSize.width - (rect.right * scale + dx);
      final double right = previewSize.width - (rect.left * scale + dx);
      final double top = rect.top * scale + dy;
      final double bottom = rect.bottom * scale + dy;
      return Rect.fromLTRB(left, top, right, bottom);
    } else {
      final double left = rect.left * scale + dx;
      final double right = rect.right * scale + dx;
      final double top = rect.top * scale + dy;
      final double bottom = rect.bottom * scale + dy;
      return Rect.fromLTRB(left, top, right, bottom);
    }
  }

  /// Inverts a point from preview widget coordinates back to upright image coordinates.
  Offset unmapPoint(Offset previewPoint) {
    final double unmirroredX = mirror
        ? (previewSize.width - previewPoint.dx)
        : previewPoint.dx;
    final double x = (unmirroredX - dx) / scale;
    final double y = (previewPoint.dy - dy) / scale;
    return Offset(x, y);
  }

  /// Inverts a [Rect] from preview widget coordinates back to upright image coordinates.
  Rect unmapRect(Rect previewRect) {
    if (mirror) {
      final double unmirroredLeft = previewSize.width - previewRect.right;
      final double unmirroredRight = previewSize.width - previewRect.left;
      final double left = (unmirroredLeft - dx) / scale;
      final double right = (unmirroredRight - dx) / scale;
      final double top = (previewRect.top - dy) / scale;
      final double bottom = (previewRect.bottom - dy) / scale;
      return Rect.fromLTRB(left, top, right, bottom);
    } else {
      final double left = (previewRect.left - dx) / scale;
      final double right = (previewRect.right - dx) / scale;
      final double top = (previewRect.top - dy) / scale;
      final double bottom = (previewRect.bottom - dy) / scale;
      return Rect.fromLTRB(left, top, right, bottom);
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PreviewMapper &&
        other.imageSize == imageSize &&
        other.previewSize == previewSize &&
        other.mirror == mirror;
  }

  @override
  int get hashCode => Object.hash(imageSize, previewSize, mirror);
}
