import 'dart:ui';

import '../../camera/domain/frame_data.dart';
import '../../ml/worker/worker_protocol.dart';

/// Abstract contract for passive facial liveness / anti-spoofing evaluation.
///
/// Decouples model inference from specific backend runtimes (e.g. ONNX Runtime).
abstract class PassiveLivenessEngine {
  /// Evaluates the passive liveness of a detected face within [frame].
  ///
  /// [faceRect] is in upright image coordinates.
  /// [modelNames] specifies which registered models to run (e.g. ['MiniFASNetV2']).
  /// [preprocessConfig] optionally overrides the default preprocessing parameters.
  Future<PassiveFrameResult> evaluateFrame({
    required TransferableFrameData frame,
    required Rect faceRect,
    required List<String> modelNames,
    PassivePreprocessConfig? preprocessConfig,
  });
}
