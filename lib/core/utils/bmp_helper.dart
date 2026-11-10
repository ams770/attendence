import 'dart:typed_data';

/// Pure Dart utility to wrap raw RGB pixel buffers into standard uncompressed
/// 24-bit BMP image bytes for rendering via [Image.memory].
class BmpHelper {
  const BmpHelper._();

  /// Converts an [rgbBytes] buffer of dimensions [width] x [height] into
  /// top-down 24-bit BMP image bytes.
  static Uint8List createBmpFromRgb(Uint8List rgbBytes, int width, int height) {
    // Each row in a 24-bit BMP must be padded to a multiple of 4 bytes
    final int rowStride = (width * 3 + 3) & ~3;
    final int pixelDataSize = rowStride * height;
    final int fileSize = 54 + pixelDataSize;

    final Uint8List bmp = Uint8List(fileSize);
    final ByteData bd = ByteData.view(bmp.buffer);

    // Bitmap File Header (14 bytes)
    bmp[0] = 0x42; // 'B'
    bmp[1] = 0x4D; // 'M'
    bd.setUint32(2, fileSize, Endian.little);
    bd.setUint16(6, 0, Endian.little); // Reserved 1
    bd.setUint16(8, 0, Endian.little); // Reserved 2
    bd.setUint32(10, 54, Endian.little); // Pixel data offset

    // DIB Header - BITMAPINFOHEADER (40 bytes)
    bd.setUint32(14, 40, Endian.little); // Header size
    bd.setInt32(18, width, Endian.little);
    // Negative height specifies top-down row order
    bd.setInt32(22, -height, Endian.little);
    bd.setUint16(26, 1, Endian.little); // Color planes
    bd.setUint16(28, 24, Endian.little); // Bits per pixel (24-bit BGR)
    bd.setUint32(30, 0, Endian.little); // Compression (0 = BI_RGB)
    bd.setUint32(34, pixelDataSize, Endian.little);
    bd.setInt32(38, 2835, Endian.little); // Horizontal resolution (~72 DPI)
    bd.setInt32(42, 2835, Endian.little); // Vertical resolution (~72 DPI)
    bd.setUint32(46, 0, Endian.little); // Colors in palette
    bd.setUint32(50, 0, Endian.little); // Important colors

    // Copy RGB to BGR with stride padding
    int srcIdx = 0;
    int dstRowStart = 54;

    for (int y = 0; y < height; y++) {
      int dstIdx = dstRowStart;
      for (int x = 0; x < width; x++) {
        final int r = rgbBytes[srcIdx++];
        final int g = rgbBytes[srcIdx++];
        final int b = rgbBytes[srcIdx++];

        bmp[dstIdx++] = b;
        bmp[dstIdx++] = g;
        bmp[dstIdx++] = r;
      }
      dstRowStart += rowStride;
    }

    return bmp;
  }
}
