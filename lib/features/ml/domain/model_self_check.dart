import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'inference_engine.dart';
import 'model_registry.dart';

/// Signature for loading raw asset bytes from an asset path.
typedef AssetByteLoader = Future<Uint8List> Function(String assetPath);

/// Default loader using Flutter [rootBundle].
Future<Uint8List> defaultAssetByteLoader(String assetPath) async {
  final ByteData data = await rootBundle.load(assetPath);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// Result of checking a single AI model.
class ModelCheckResult {
  const ModelCheckResult({
    required this.spec,
    required this.isSuccess,
    this.errorMessage,
    this.actualInputNames = const <String>[],
    this.actualOutputNames = const <String>[],
    this.actualOutputSize = 0,
  });

  final ModelSpec spec;
  final bool isSuccess;
  final String? errorMessage;
  final List<String> actualInputNames;
  final List<String> actualOutputNames;
  final int actualOutputSize;
}

/// Comprehensive report of the startup self-check across all models.
class SelfCheckReport {
  const SelfCheckReport({required this.results, required this.isAllSuccess});

  final List<ModelCheckResult> results;
  final bool isAllSuccess;

  List<ModelCheckResult> get failures =>
      results.where((ModelCheckResult r) => !r.isSuccess).toList();
}

/// Verifies that all required AI models can be loaded and executed.
class ModelSelfCheck {
  ModelSelfCheck({
    required this._engine,
    AssetByteLoader? assetLoader,
    List<ModelSpec>? models,
  }) : _assetLoader = assetLoader ?? defaultAssetByteLoader,
       _models = models ?? ModelRegistry.allModels;

  final InferenceEngine _engine;
  final AssetByteLoader _assetLoader;
  final List<ModelSpec> _models;

  /// Runs the self-check sequentially on all registered models.
  Future<SelfCheckReport> runCheck() async {
    final List<ModelCheckResult> results = <ModelCheckResult>[];

    for (final ModelSpec spec in _models) {
      final ModelCheckResult result = await _checkSingleModel(spec);
      results.add(result);
    }

    final bool allSuccess = results.every((ModelCheckResult r) => r.isSuccess);
    return SelfCheckReport(results: results, isAllSuccess: allSuccess);
  }

  Future<ModelCheckResult> _checkSingleModel(ModelSpec spec) async {
    Uint8List? bytes;
    InferenceSession? session;

    try {
      try {
        bytes = await _assetLoader(spec.assetPath);
      } catch (e) {
        return ModelCheckResult(
          spec: spec,
          isSuccess: false,
          errorMessage: 'Failed to load model asset: $e',
        );
      }

      try {
        session = await _engine.createSessionFromBytes(bytes);
      } catch (e) {
        return ModelCheckResult(
          spec: spec,
          isSuccess: false,
          errorMessage: 'Failed to initialize inference session: $e',
        );
      } finally {
        bytes = null;
      }

      final List<String> inputNames = session.inputNames;
      final List<String> outputNames = session.outputNames;

      if (!inputNames.contains(spec.expectedInputName)) {
        return ModelCheckResult(
          spec: spec,
          isSuccess: false,
          actualInputNames: inputNames,
          actualOutputNames: outputNames,
          errorMessage:
              'Expected input node "${spec.expectedInputName}" not found in $inputNames',
        );
      }

      if (!outputNames.contains(spec.expectedOutputName)) {
        return ModelCheckResult(
          spec: spec,
          isSuccess: false,
          actualInputNames: inputNames,
          actualOutputNames: outputNames,
          errorMessage:
              'Expected output node "${spec.expectedOutputName}" not found in $outputNames',
        );
      }

      final Float32List dummyData = Float32List(spec.inputElementCount);
      final Float32Tensor dummyTensor = Float32Tensor(
        shape: spec.inputShape,
        data: dummyData,
      );

      final Map<String, List<double>> outputs = session.run(
        <String, Float32Tensor>{spec.expectedInputName: dummyTensor},
      );

      final List<double> outputValues =
          outputs[spec.expectedOutputName] ?? const <double>[];

      if (outputValues.length != spec.expectedOutputSize) {
        return ModelCheckResult(
          spec: spec,
          isSuccess: false,
          actualInputNames: inputNames,
          actualOutputNames: outputNames,
          actualOutputSize: outputValues.length,
          errorMessage:
              'Output size ${outputValues.length} does not match expected size ${spec.expectedOutputSize}',
        );
      }

      return ModelCheckResult(
        spec: spec,
        isSuccess: true,
        actualInputNames: inputNames,
        actualOutputNames: outputNames,
        actualOutputSize: outputValues.length,
      );
    } catch (e) {
      return ModelCheckResult(
        spec: spec,
        isSuccess: false,
        errorMessage: 'Unexpected inference failure: $e',
      );
    } finally {
      session?.dispose();
    }
  }
}
