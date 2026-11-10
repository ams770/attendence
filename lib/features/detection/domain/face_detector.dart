import '../../camera/domain/frame_data.dart';
import 'detected_face.dart';

/// Abstract contract for detecting human faces from camera frame data.
abstract interface class FaceDetector {
  /// Detects all faces present in the given [frame].
  ///
  /// Output coordinates must be transformed to upright image coordinates.
  Future<List<DetectedFace>> detect(FrameData frame);

  /// Releases detector resources.
  Future<void> dispose();
}
