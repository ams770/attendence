import 'dart:ui';

import '../../../core/utils/affine_matrix.dart';
import '../../camera/domain/frame_data.dart';
import '../../ml/worker/ml_worker.dart';
import '../../ml/worker/worker_protocol.dart';

/// Contract for asynchronous worker isolate operations needed by the verification session.
abstract interface class LivenessSessionWorker {
  /// Computes face photometric statistics (sharpness, brightness, glare).
  Future<FaceStats> getFaceStats(
    TransferableFrameData frame,
    Rect faceRect, {
    int sampleSize = 80,
  });

  /// Computes a 112x112 aligned RGB crop using the provided affine transform.
  Future<AlignedCropData> getAlignedCrop(
    TransferableFrameData frame,
    AffineMatrix uprightToOutput,
  );

  /// Samples mean RGB skin color and brightness for flash reflection analysis.
  Future<SkinColorSampleData> getSkinColorSample(
    TransferableFrameData frame,
    List<Rect> skinRegions,
  );
}

/// Production implementation of [LivenessSessionWorker] backed by [MlWorker].
class MlWorkerLivenessAdapter implements LivenessSessionWorker {
  const MlWorkerLivenessAdapter({required this.worker});

  final MlWorker worker;

  @override
  Future<FaceStats> getFaceStats(
    TransferableFrameData frame,
    Rect faceRect, {
    int sampleSize = 80,
  }) {
    return worker.getFaceStats(frame, faceRect, sampleSize: sampleSize);
  }

  @override
  Future<AlignedCropData> getAlignedCrop(
    TransferableFrameData frame,
    AffineMatrix uprightToOutput,
  ) {
    return worker.getAlignedCrop(frame, uprightToOutput);
  }

  @override
  Future<SkinColorSampleData> getSkinColorSample(
    TransferableFrameData frame,
    List<Rect> skinRegions,
  ) {
    return worker.getSkinColorSample(frame, skinRegions);
  }
}
