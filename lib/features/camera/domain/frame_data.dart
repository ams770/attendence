import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Supported raw pixel formats for camera frame processing.
enum FrameFormat { nv21, yuv420, bgra8888 }

/// A single memory plane within a camera frame.
@immutable
class FramePlane {
  const FramePlane({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel,
    this.width,
    this.height,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;
  final int? width;
  final int? height;
}

/// Metadata describing a plane when transmitted across isolate boundaries.
@immutable
class PlaneMetadata {
  const PlaneMetadata({
    required this.offset,
    required this.length,
    required this.bytesPerRow,
    this.bytesPerPixel,
    this.width,
    this.height,
  });

  final int offset;
  final int length;
  final int bytesPerRow;
  final int? bytesPerPixel;
  final int? width;
  final int? height;
}

/// Immutable camera frame capturing raw pixel buffers and spatial metadata.
@immutable
class FrameData {
  const FrameData({
    required this.format,
    required this.width,
    required this.height,
    required this.planes,
    required this.sensorRotation,
    required this.lensDirection,
    required this.timestamp,
  });

  final FrameFormat format;
  final int width;
  final int height;
  final List<FramePlane> planes;
  final int sensorRotation;
  final CameraLensDirection lensDirection;
  final DateTime timestamp;

  /// Frame width when oriented upright according to [sensorRotation].
  int get uprightWidth =>
      (sensorRotation == 90 || sensorRotation == 270) ? height : width;

  /// Frame height when oriented upright according to [sensorRotation].
  int get uprightHeight =>
      (sensorRotation == 90 || sensorRotation == 270) ? width : height;

  /// Creates a [FrameData] instance from a [CameraImage] emitted by the camera stream.
  factory FrameData.fromCameraImage(
    CameraImage image, {
    required int sensorRotation,
    required CameraLensDirection lensDirection,
    required DateTime timestamp,
  }) {
    final FrameFormat format = _detectFormat(image);
    final List<FramePlane> planes = image.planes
        .map(
          (Plane p) => FramePlane(
            bytes: p.bytes,
            bytesPerRow: p.bytesPerRow,
            bytesPerPixel: p.bytesPerPixel,
            width: p.width,
            height: p.height,
          ),
        )
        .toList(growable: false);

    // If the image buffer is already portrait (width <= height), as is standard
    // on iOS where AVFoundation automatically matches device portrait orientation,
    // the effective sensor rotation required to orient the image upright is 0.
    final int effectiveRotation = (image.width <= image.height)
        ? 0
        : sensorRotation;

    return FrameData(
      format: format,
      width: image.width,
      height: image.height,
      planes: planes,
      sensorRotation: effectiveRotation,
      lensDirection: lensDirection,
      timestamp: timestamp,
    );
  }

  static FrameFormat _detectFormat(CameraImage image) {
    switch (image.format.group) {
      case ImageFormatGroup.nv21:
        return FrameFormat.nv21;
      case ImageFormatGroup.bgra8888:
        return FrameFormat.bgra8888;
      case ImageFormatGroup.yuv420:
        return FrameFormat.yuv420;
      default:
        if (image.planes.length == 1) {
          return FrameFormat.bgra8888;
        } else if (image.planes.length == 2) {
          return FrameFormat.nv21;
        } else {
          return FrameFormat.yuv420;
        }
    }
  }

  /// Packages this frame into a [TransferableFrameData] for efficient zero-copy
  /// cross-isolate message passing.
  TransferableFrameData toTransferable() {
    final List<PlaneMetadata> metadataList = <PlaneMetadata>[];
    final List<Uint8List> byteBuffers = <Uint8List>[];
    int currentOffset = 0;

    for (final FramePlane plane in planes) {
      final int len = plane.bytes.length;
      metadataList.add(
        PlaneMetadata(
          offset: currentOffset,
          length: len,
          bytesPerRow: plane.bytesPerRow,
          bytesPerPixel: plane.bytesPerPixel,
          width: plane.width,
          height: plane.height,
        ),
      );
      byteBuffers.add(plane.bytes);
      currentOffset += len;
    }

    final TransferableTypedData transferable = TransferableTypedData.fromList(
      byteBuffers,
    );

    return TransferableFrameData(
      format: format,
      width: width,
      height: height,
      sensorRotation: sensorRotation,
      lensDirection: lensDirection,
      timestamp: timestamp,
      planeMetadata: metadataList,
      transferableBytes: transferable,
    );
  }
}

/// Container for transferring frame data across isolate boundaries using
/// [TransferableTypedData].
class TransferableFrameData {
  const TransferableFrameData({
    required this.format,
    required this.width,
    required this.height,
    required this.sensorRotation,
    required this.lensDirection,
    required this.timestamp,
    required this.planeMetadata,
    required this.transferableBytes,
  });

  final FrameFormat format;
  final int width;
  final int height;
  final int sensorRotation;
  final CameraLensDirection lensDirection;
  final DateTime timestamp;
  final List<PlaneMetadata> planeMetadata;
  final TransferableTypedData transferableBytes;

  /// Materializes the transferable bytes and reconstructs the [FrameData] instance.
  FrameData toFrameData() {
    final ByteBuffer buffer = transferableBytes.materialize();
    final Uint8List combinedBytes = buffer.asUint8List();

    final List<FramePlane> planes = planeMetadata
        .map(
          (PlaneMetadata meta) => FramePlane(
            bytes: Uint8List.sublistView(
              combinedBytes,
              meta.offset,
              meta.offset + meta.length,
            ),
            bytesPerRow: meta.bytesPerRow,
            bytesPerPixel: meta.bytesPerPixel,
            width: meta.width,
            height: meta.height,
          ),
        )
        .toList(growable: false);

    return FrameData(
      format: format,
      width: width,
      height: height,
      planes: planes,
      sensorRotation: sensorRotation,
      lensDirection: lensDirection,
      timestamp: timestamp,
    );
  }
}
