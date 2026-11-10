import 'dart:typed_data';

import 'package:attendence/features/camera/domain/frame_data.dart';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCameraImage extends Mock implements CameraImage {}

class _MockPlane extends Mock implements Plane {}

class _MockImageFormat extends Mock implements ImageFormat {}

void main() {
  group('FrameData & TransferableFrameData', () {
    test('roundtrips accurately through TransferableFrameData', () {
      final Uint8List plane0Bytes = Uint8List.fromList(<int>[10, 20, 30, 40]);
      final Uint8List plane1Bytes = Uint8List.fromList(<int>[50, 60]);

      final FrameData original = FrameData(
        format: FrameFormat.nv21,
        width: 2,
        height: 2,
        planes: <FramePlane>[
          FramePlane(
            bytes: plane0Bytes,
            bytesPerRow: 2,
            bytesPerPixel: 1,
            width: 2,
            height: 2,
          ),
          FramePlane(
            bytes: plane1Bytes,
            bytesPerRow: 2,
            bytesPerPixel: 2,
            width: 1,
            height: 1,
          ),
        ],
        sensorRotation: 270,
        lensDirection: CameraLensDirection.front,
        timestamp: DateTime(2026, 1, 15, 10, 30, 0),
      );

      final TransferableFrameData transferable = original.toTransferable();
      final FrameData reconstructed = transferable.toFrameData();

      expect(reconstructed.format, equals(original.format));
      expect(reconstructed.width, equals(original.width));
      expect(reconstructed.height, equals(original.height));
      expect(reconstructed.sensorRotation, equals(original.sensorRotation));
      expect(reconstructed.lensDirection, equals(original.lensDirection));
      expect(reconstructed.timestamp, equals(original.timestamp));

      expect(reconstructed.planes.length, equals(2));
      expect(reconstructed.planes[0].bytes, equals(plane0Bytes));
      expect(reconstructed.planes[0].bytesPerRow, equals(2));
      expect(reconstructed.planes[0].bytesPerPixel, equals(1));
      expect(reconstructed.planes[1].bytes, equals(plane1Bytes));
      expect(reconstructed.planes[1].bytesPerRow, equals(2));
      expect(reconstructed.planes[1].bytesPerPixel, equals(2));
    });

    test('fromCameraImage sets effectiveRotation to 0 when buffer is already portrait', () {
      final _MockCameraImage image = _MockCameraImage();
      final _MockPlane plane = _MockPlane();
      final _MockImageFormat format = _MockImageFormat();

      when(() => format.group).thenReturn(ImageFormatGroup.bgra8888);
      when(() => image.format).thenReturn(format);

      when(() => plane.bytes).thenReturn(Uint8List(720 * 1280 * 4));
      when(() => plane.bytesPerRow).thenReturn(720 * 4);
      when(() => plane.bytesPerPixel).thenReturn(4);
      when(() => plane.width).thenReturn(720);
      when(() => plane.height).thenReturn(1280);

      when(() => image.width).thenReturn(720);
      when(() => image.height).thenReturn(1280);
      when(() => image.planes).thenReturn(<Plane>[plane]);

      final FrameData frame = FrameData.fromCameraImage(
        image,
        sensorRotation: 90,
        lensDirection: CameraLensDirection.front,
        timestamp: DateTime(2026, 1, 1),
      );

      expect(frame.width, equals(720));
      expect(frame.height, equals(1280));
      expect(frame.sensorRotation, equals(0));
    });

    test(
      'fromCameraImage preserves sensorRotation when buffer is landscape',
      () {
        final _MockCameraImage image = _MockCameraImage();
        final _MockPlane plane = _MockPlane();
        final _MockImageFormat format = _MockImageFormat();

        when(() => format.group).thenReturn(ImageFormatGroup.nv21);
        when(() => image.format).thenReturn(format);

        when(() => plane.bytes).thenReturn(Uint8List(1280 * 720 * 4));
        when(() => plane.bytesPerRow).thenReturn(1280 * 4);
        when(() => plane.bytesPerPixel).thenReturn(4);
        when(() => plane.width).thenReturn(1280);
        when(() => plane.height).thenReturn(720);

        when(() => image.width).thenReturn(1280);
        when(() => image.height).thenReturn(720);
        when(() => image.planes).thenReturn(<Plane>[plane]);

        final FrameData frame = FrameData.fromCameraImage(
          image,
          sensorRotation: 270,
          lensDirection: CameraLensDirection.front,
          timestamp: DateTime(2026, 1, 1),
        );

        expect(frame.width, equals(1280));
        expect(frame.height, equals(720));
        expect(frame.sensorRotation, equals(270));
      },
    );

    test('fromCameraImage sets effectiveRotation to 0 when buffer is already portrait', () {
      final _MockCameraImage image = _MockCameraImage();
      final _MockPlane plane = _MockPlane();
      final _MockImageFormat format = _MockImageFormat();

      when(() => format.group).thenReturn(ImageFormatGroup.bgra8888);
      when(() => image.format).thenReturn(format);

      when(() => plane.bytes).thenReturn(Uint8List(720 * 1280 * 4));
      when(() => plane.bytesPerRow).thenReturn(720 * 4);
      when(() => plane.bytesPerPixel).thenReturn(4);
      when(() => plane.width).thenReturn(720);
      when(() => plane.height).thenReturn(1280);

      when(() => image.width).thenReturn(720);
      when(() => image.height).thenReturn(1280);
      when(() => image.planes).thenReturn(<Plane>[plane]);

      final FrameData frame = FrameData.fromCameraImage(
        image,
        sensorRotation: 90,
        lensDirection: CameraLensDirection.front,
        timestamp: DateTime(2026, 1, 1),
      );

      expect(frame.width, equals(720));
      expect(frame.height, equals(1280));
      expect(frame.sensorRotation, equals(0));
    });

    test(
      'fromCameraImage preserves sensorRotation when buffer is landscape',
      () {
        final _MockCameraImage image = _MockCameraImage();
        final _MockPlane plane = _MockPlane();
        final _MockImageFormat format = _MockImageFormat();

        when(() => format.group).thenReturn(ImageFormatGroup.nv21);
        when(() => image.format).thenReturn(format);

        when(() => plane.bytes).thenReturn(Uint8List(1280 * 720 * 4));
        when(() => plane.bytesPerRow).thenReturn(1280 * 4);
        when(() => plane.bytesPerPixel).thenReturn(4);
        when(() => plane.width).thenReturn(1280);
        when(() => plane.height).thenReturn(720);

        when(() => image.width).thenReturn(1280);
        when(() => image.height).thenReturn(720);
        when(() => image.planes).thenReturn(<Plane>[plane]);

        final FrameData frame = FrameData.fromCameraImage(
          image,
          sensorRotation: 270,
          lensDirection: CameraLensDirection.front,
          timestamp: DateTime(2026, 1, 1),
        );

        expect(frame.width, equals(1280));
        expect(frame.height, equals(720));
        expect(frame.sensorRotation, equals(270));
      },
    );
  });
}
