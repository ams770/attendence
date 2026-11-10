import 'dart:typed_data';

import 'package:onnxruntime/onnxruntime.dart';

import '../domain/inference_engine.dart';

/// Concrete [InferenceSession] powered by ONNX Runtime native FFI.
class OnnxInferenceSession implements InferenceSession {
  OnnxInferenceSession(this._session) : _runOptions = OrtRunOptions();

  final OrtSession _session;
  final OrtRunOptions _runOptions;
  bool _isDisposed = false;

  @override
  List<String> get inputNames => _session.inputNames;

  @override
  List<String> get outputNames => _session.outputNames;

  @override
  Map<String, List<double>> run(Map<String, Float32Tensor> inputs) {
    if (_isDisposed) {
      throw StateError('Cannot run inference on a disposed session');
    }

    final Map<String, OrtValueTensor> ortInputs = <String, OrtValueTensor>{};
    final List<OrtValue?> ortOutputs = <OrtValue?>[];

    try {
      for (final MapEntry<String, Float32Tensor> entry in inputs.entries) {
        final OrtValueTensor tensor = OrtValueTensor.createTensorWithDataList(
          entry.value.data,
          entry.value.shape,
        );
        ortInputs[entry.key] = tensor;
      }

      final List<OrtValue?> rawOutputs = _session.run(_runOptions, ortInputs);
      ortOutputs.addAll(rawOutputs);

      final Map<String, List<double>> resultMap = <String, List<double>>{};
      final List<String> outNames = _session.outputNames;

      for (int i = 0; i < rawOutputs.length; i++) {
        final OrtValue? outVal = rawOutputs[i];
        final String name = (i < outNames.length) ? outNames[i] : 'output_$i';
        if (outVal != null) {
          resultMap[name] = _flattenDoubles(outVal.value);
        } else {
          resultMap[name] = const <double>[];
        }
      }

      return resultMap;
    } finally {
      for (final OrtValueTensor tensor in ortInputs.values) {
        tensor.release();
      }
      for (final OrtValue? out in ortOutputs) {
        out?.release();
      }
    }
  }

  static List<double> _flattenDoubles(dynamic value) {
    final List<double> result = <double>[];
    void recurse(dynamic item) {
      if (item is num) {
        result.add(item.toDouble());
      } else if (item is Iterable) {
        for (final dynamic sub in item) {
          recurse(sub);
        }
      }
    }

    recurse(value);
    return result;
  }

  @override
  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      _runOptions.release();
      _session.release();
    }
  }
}

/// Concrete [InferenceEngine] creating sessions with ONNX Runtime.
class OnnxInferenceEngine implements InferenceEngine {
  OnnxInferenceEngine() {
    _initEnv();
  }

  static bool _envInitialized = false;

  static void _initEnv() {
    if (!_envInitialized) {
      OrtEnv.instance.init();
      _envInitialized = true;
    }
  }

  @override
  Future<InferenceSession> createSessionFromBytes(Uint8List bytes) async {
    _initEnv();
    final OrtSessionOptions options = OrtSessionOptions();
    try {
      final OrtSession session = OrtSession.fromBuffer(bytes, options);
      return OnnxInferenceSession(session);
    } finally {
      options.release();
    }
  }

  @override
  void dispose() {
    if (_envInitialized) {
      OrtEnv.instance.release();
      _envInitialized = false;
    }
  }
}
