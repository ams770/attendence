import 'package:flutter/foundation.dart';

/// Specification of an on-device AI model used by the application.
@immutable
class ModelSpec {
  const ModelSpec({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.inputShape,
    required this.expectedInputName,
    required this.expectedOutputName,
    required this.expectedOutputSize,
  });

  /// Unique identifier for the model.
  final String id;

  /// Human-readable model name.
  final String name;

  /// Asset bundle path to the ONNX model file.
  final String assetPath;

  /// Expected tensor dimensions (e.g. [1, 3, 80, 80]).
  final List<int> inputShape;

  /// Name of the primary input node in the ONNX graph.
  final String expectedInputName;

  /// Name of the primary output node in the ONNX graph.
  final String expectedOutputName;

  /// Expected number of numeric values in the flattened output.
  final int expectedOutputSize;

  /// Total element count required by [inputShape].
  int get inputElementCount =>
      inputShape.fold<int>(1, (int acc, int dim) => acc * dim);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ModelSpec &&
        other.id == id &&
        other.name == name &&
        other.assetPath == assetPath &&
        listEquals(other.inputShape, inputShape) &&
        other.expectedInputName == expectedInputName &&
        other.expectedOutputName == expectedOutputName &&
        other.expectedOutputSize == expectedOutputSize;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    assetPath,
    Object.hashAll(inputShape),
    expectedInputName,
    expectedOutputName,
    expectedOutputSize,
  );
}

/// Registry of all built-in neural network models required by the system.
class ModelRegistry {
  const ModelRegistry._();

  static const ModelSpec miniFASNetV1SE = ModelSpec(
    id: 'mini_fas_net_v1_se',
    name: 'MiniFASNetV1SE',
    assetPath: 'assets/ai/MiniFASNetV1SE.onnx',
    inputShape: <int>[1, 3, 80, 80],
    expectedInputName: 'input',
    expectedOutputName: 'output',
    expectedOutputSize: 3,
  );

  static const ModelSpec miniFASNetV2 = ModelSpec(
    id: 'mini_fas_net_v2',
    name: 'MiniFASNetV2',
    assetPath: 'assets/ai/MiniFASNetV2.onnx',
    inputShape: <int>[1, 3, 80, 80],
    expectedInputName: 'input',
    expectedOutputName: 'output',
    expectedOutputSize: 3,
  );

  static const ModelSpec sFace = ModelSpec(
    id: 'sface',
    name: 'SFace',
    assetPath: 'assets/ai/face_recognition_sface_2021dec.onnx',
    inputShape: <int>[1, 3, 112, 112],
    expectedInputName: 'data',
    expectedOutputName: 'fc1',
    expectedOutputSize: 128,
  );

  /// All required models that must pass startup self-check.
  static const List<ModelSpec> allModels = <ModelSpec>[
    miniFASNetV1SE,
    miniFASNetV2,
    sFace,
  ];
}
