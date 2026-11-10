import 'dart:typed_data';

import 'package:attendence/core/utils/bmp_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BmpHelper', () {
    test(
      'creates valid top-down 24-bit BMP with correct header and BGR ordering',
      () {
        // 2x1 RGB image: [Red (255, 0, 0), Green (0, 255, 0)]
        final Uint8List rgb = Uint8List.fromList(<int>[
          255, 0, 0, // Red
          0, 255, 0, // Green
        ]);

        final Uint8List bmp = BmpHelper.createBmpFromRgb(rgb, 2, 1);
        final ByteData bd = ByteData.view(bmp.buffer);

        // Signature 'BM'
        expect(bmp[0], equals(0x42));
        expect(bmp[1], equals(0x4D));

        // Header size 40, offset 54
        expect(bd.getUint32(10, Endian.little), equals(54));
        expect(bd.getUint32(14, Endian.little), equals(40));

        // Width 2, Height -1 (top-down)
        expect(bd.getInt32(18, Endian.little), equals(2));
        expect(bd.getInt32(22, Endian.little), equals(-1));

        // 24 bits per pixel
        expect(bd.getUint16(28, Endian.little), equals(24));

        // Stride for 2 pixels: 2 * 3 = 6 bytes + 2 padding bytes = 8 bytes
        expect(bmp.length, equals(54 + 8));

        // Pixel 0: BGR order -> Blue: 0, Green: 0, Red: 255
        expect(bmp[54], equals(0));
        expect(bmp[55], equals(0));
        expect(bmp[56], equals(255));

        // Pixel 1: BGR order -> Blue: 0, Green: 255, Red: 0
        expect(bmp[57], equals(0));
        expect(bmp[58], equals(255));
        expect(bmp[59], equals(0));
      },
    );
  });
}
