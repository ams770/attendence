import 'dart:typed_data';

import '../../liveness/domain/liveness_session.dart';

/// Abstract contract for computing 128-d L2-normalized face recognition embeddings.
abstract class FaceRecognizer {
  /// Unique identifier of the underlying model (e.g. 'sface').
  String get modelId;

  /// Output vector dimension (e.g. 128).
  int get dimension;

  /// Computes an L2-normalized 128-d embedding from verified live faces.
  ///
  /// Strictly requires [VerifiedLiveFaces] manufactured by a succeeded [LivenessSession]
  /// to ensure biometric identification cannot be invoked with unverified or forged crops.
  /// When multiple crops are present, embeddings are computed for each crop, averaged,
  /// and normalized again.
  Future<List<double>> embedVerifiedFaces(VerifiedLiveFaces liveFaces);

  /// Computes an L2-normalized embedding from a single aligned RGB crop.
  ///
  /// Used primarily during employee enrollment.
  Future<List<double>> embedSingleCrop(Uint8List alignedRgb);
}
