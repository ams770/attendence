import 'dart:ui';

import '../../../core/config/app_config.dart';
import '../../camera/domain/frame_data.dart';
import '../../ml/worker/ml_worker.dart';
import '../../ml/worker/worker_protocol.dart';
import '../domain/passive_liveness_engine.dart';

/// Concrete [PassiveLivenessEngine] backed by ONNX Runtime sessions executed
/// in a background worker isolate.
class OnnxPassiveLivenessEngine implements PassiveLivenessEngine {
  const OnnxPassiveLivenessEngine({required this.worker, required this.config});

  final MlWorker worker;
  final AppConfig config;

  @override
  Future<PassiveFrameResult> evaluateFrame({
    required TransferableFrameData frame,
    required Rect faceRect,
    required List<String> modelNames,
    PassivePreprocessConfig? preprocessConfig,
  }) async {
    if (!worker.isAlive ||
        modelNames.any((String name) => !worker.isModelLoaded(name))) {
      await worker.ensureInitialized();
    }

    final PassivePreprocessConfig effectiveConfig =
        preprocessConfig ?? config.passivePreprocessConfig;

    return worker.runPassive(
      frame: frame,
      faceRect: faceRect,
      modelNames: modelNames,
      preprocessConfig: effectiveConfig,
    );
  }
}
