import 'dart:typed_data';

import '../../device/domain/device_tier.dart';
import '../../liveness/domain/liveness_session.dart';
import '../../ml/domain/model_registry.dart';
import '../../ml/worker/ml_worker.dart';
import '../../ml/worker/worker_protocol.dart';
import '../domain/face_recognizer.dart';

/// Concrete SFace implementation of [FaceRecognizer] executing in the background worker isolate.
class SFaceRecognizerImpl implements FaceRecognizer {
  SFaceRecognizerImpl({
    required this.mlWorker,
    this.tierProfile,
    this.preprocessConfig = const RecognizerPreprocessConfig(),
  });

  final MlWorker mlWorker;
  final TierProfile? tierProfile;
  final RecognizerPreprocessConfig preprocessConfig;

  @override
  String get modelId => ModelRegistry.sFace.id;

  @override
  int get dimension => ModelRegistry.sFace.expectedOutputSize;

  ModelSpec get _resolvedModelSpec {
    if (tierProfile != null &&
        tierProfile!.hasInt8Model &&
        tierProfile!.sfaceVariantPreference ==
            SFaceVariantPreference.int8Model) {
      return ModelSpec(
        id: 'sface_int8',
        name: tierProfile!.effectiveSFaceModelName,
        assetPath: tierProfile!.sfaceModelPath,
        inputShape: ModelRegistry.sFace.inputShape,
        expectedInputName: ModelRegistry.sFace.expectedInputName,
        expectedOutputName: ModelRegistry.sFace.expectedOutputName,
        expectedOutputSize: ModelRegistry.sFace.expectedOutputSize,
      );
    }
    return ModelRegistry.sFace;
  }

  String get _resolvedModelName {
    if (tierProfile != null) {
      return tierProfile!.effectiveSFaceModelName;
    }
    return ModelRegistry.sFace.name;
  }

  @override
  Future<List<double>> embedVerifiedFaces(VerifiedLiveFaces liveFaces) async {
    if (liveFaces.crops.isEmpty) {
      throw ArgumentError('VerifiedLiveFaces must contain at least one crop');
    }

    await mlWorker.ensureInitialized(models: <ModelSpec>[_resolvedModelSpec]);

    final List<Uint8List> crops = liveFaces.crops
        .map((VerifiedLiveFaceCrop c) => c.rgbBytes)
        .toList(growable: false);

    final EmbedData data = await mlWorker.computeEmbedding(
      cropsRgb: crops,
      modelName: _resolvedModelName,
      preprocessConfig: preprocessConfig,
    );

    return data.embedding;
  }

  @override
  Future<List<double>> embedSingleCrop(Uint8List alignedRgb) async {
    await mlWorker.ensureInitialized(models: <ModelSpec>[_resolvedModelSpec]);

    final EmbedData data = await mlWorker.computeEmbedding(
      cropsRgb: <Uint8List>[alignedRgb],
      modelName: _resolvedModelName,
      preprocessConfig: preprocessConfig,
    );

    return data.embedding;
  }
}
