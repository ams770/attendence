import 'dart:typed_data';

/// Represents a multi-dimensional float32 tensor for model inference.
class Float32Tensor {
  const Float32Tensor({required this.shape, required this.data});

  final List<int> shape;
  final Float32List data;
}

/// Abstract contract for an active model session.
abstract class InferenceSession {
  /// Input node names discovered from the model graph.
  List<String> get inputNames;

  /// Output node names discovered from the model graph.
  List<String> get outputNames;

  /// Executes inference synchronously with the given named float32 input tensors.
  ///
  /// Returns a map of output node names to flattened output values.
  Map<String, List<double>> run(Map<String, Float32Tensor> inputs);

  /// Releases native session resources.
  void dispose();
}

/// Abstract contract for creating inference sessions across engine implementations.
abstract class InferenceEngine {
  /// Creates an [InferenceSession] from the provided in-memory model byte buffer.
  Future<InferenceSession> createSessionFromBytes(Uint8List bytes);

  /// Releases global engine resources.
  void dispose();
}
