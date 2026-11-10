import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../../core/utils/affine_matrix.dart';
import '../../../core/utils/math_utils.dart';
import '../../camera/domain/frame_data.dart';
import '../../camera/domain/frame_geometry.dart';
import '../../liveness/domain/passive_cropper.dart';
import '../data/onnx_inference_engine.dart';
import '../domain/inference_engine.dart';
import '../domain/model_registry.dart';
import '../sampler/pixel_sampler.dart';
import 'worker_protocol.dart';

/// Client proxy for interacting with the background ML worker isolate.
///
/// Encapsulates isolate lifecycle, typed command dispatching, request tracking,
/// cancellation, error handling, and crash recovery.
class MlWorker {
  MlWorker({InferenceEngine Function()? engineFactory})
    : _engineFactory = engineFactory ?? OnnxInferenceEngine.new;

  final InferenceEngine Function() _engineFactory;

  Isolate? _isolate;
  SendPort? _toWorkerPort;
  ReceivePort? _fromWorkerPort;
  ReceivePort? _errorPort;
  ReceivePort? _exitPort;

  StreamSubscription<dynamic>? _messageSub;
  StreamSubscription<dynamic>? _errorSub;
  StreamSubscription<dynamic>? _exitSub;

  final Map<String, Completer<dynamic>> _pendingRequests =
      <String, Completer<dynamic>>{};
  int _requestIdCounter = 0;
  bool _isStarted = false;
  bool _isDisposing = false;
  Future<void>? _startingFuture;
  final Set<String> _loadedModelNames = <String>{};

  /// Whether the background worker isolate is currently running and healthy.
  bool get isAlive => _isStarted && _isolate != null && !_isDisposing;

  /// Returns whether the specified model has been loaded into the worker sessions.
  bool isModelLoaded(String name) => _loadedModelNames.contains(name);

  /// Starts the worker isolate and awaits bidirectional handshake.
  Future<void> start() {
    if (_isStarted && isAlive) return Future<void>.value();
    if (_startingFuture != null) return _startingFuture!;

    _startingFuture = _doStart().whenComplete(() {
      _startingFuture = null;
    });
    return _startingFuture!;
  }

  Future<void> _doStart() async {
    _isDisposing = false;

    _fromWorkerPort = ReceivePort();
    _errorPort = ReceivePort();
    _exitPort = ReceivePort();

    final Completer<SendPort> handshakeCompleter = Completer<SendPort>();

    _messageSub = _fromWorkerPort!.listen((dynamic message) {
      if (message is SendPort) {
        if (!handshakeCompleter.isCompleted) {
          handshakeCompleter.complete(message);
        }
      } else if (message is WorkerResponse) {
        _handleResponse(message);
      }
    });

    _errorSub = _errorPort!.listen((dynamic error) {
      _handleCrash('Worker isolate encountered error: $error');
    });

    _exitSub = _exitPort!.listen((dynamic exitCode) {
      if (!_isDisposing) {
        _handleCrash('Worker isolate terminated unexpectedly: $exitCode');
      }
    });

    _isolate = await Isolate.spawn(
      _workerEntrypoint,
      _WorkerInitData(
        toMainPort: _fromWorkerPort!.sendPort,
        engineFactory: _engineFactory,
      ),
      errorsAreFatal: false,
    );

    _isolate!.addErrorListener(_errorPort!.sendPort);
    _isolate!.addOnExitListener(_exitPort!.sendPort);

    _toWorkerPort = await handshakeCompleter.future;
    _isStarted = true;
  }

  /// Sends a [command] to the worker and returns a future for its result.
  Future<T> send<T>(WorkerCommand command) async {
    if (!isAlive) {
      await start();
    }

    final Completer<T> completer = Completer<T>();
    _pendingRequests[command.id] = completer;

    _toWorkerPort!.send(command);
    return completer.future;
  }

  /// Ensures the worker isolate is started and specified [models] are loaded into sessions.
  Future<void> ensureInitialized({
    List<ModelSpec>? models,
    AssetBundle? bundle,
  }) async {
    if (!isAlive) {
      await start();
    }

    final List<ModelSpec> targetModels = models ?? ModelRegistry.allModels;

    final List<ModelSpec> toLoad = targetModels
        .where((ModelSpec m) => !_loadedModelNames.contains(m.name))
        .toList();

    if (toLoad.isEmpty) return;

    final AssetBundle assetBundle = bundle ?? rootBundle;
    final Map<String, Uint8List> modelBytes = <String, Uint8List>{};

    for (final ModelSpec spec in toLoad) {
      try {
        final ByteData byteData = await assetBundle.load(spec.assetPath);
        modelBytes[spec.name] = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
      } catch (_) {
        // Silently ignore asset loading error (e.g. in test environments).
      }
    }

    if (modelBytes.isNotEmpty) {
      await loadModels(modelBytes);
    }
  }

  /// Helper to generate a unique command ID.
  String generateCommandId(String prefix) {
    _requestIdCounter++;
    return '$prefix-$_requestIdCounter-${DateTime.now().microsecondsSinceEpoch}';
  }

  /// Cancels an in-flight or pending command by its ID.
  void cancel(String commandId) {
    if (!isAlive) return;
    final String cancelId = generateCommandId('cancel');
    _toWorkerPort!.send(CancelCommand(cancelId, commandId));
  }

  /// Convenience helper to load models into the worker isolate.
  Future<List<String>> loadModels(Map<String, Uint8List> modelBytes) async {
    final String id = generateCommandId('load-models');
    final List<String> loaded = await send<List<String>>(
      LoadModelsCommand(id, modelBytes),
    );
    _loadedModelNames.addAll(loaded);
    return loaded;
  }

  /// Convenience helper to benchmark loaded models in the worker isolate.
  Future<BenchmarkData> benchmark({
    int iterations = 10,
    int warmupIterations = 1,
  }) {
    final String id = generateCommandId('benchmark');
    return send<BenchmarkData>(
      BenchmarkCommand(
        id,
        iterations: iterations,
        warmupIterations: warmupIterations,
      ),
    );
  }

  /// Computes face image quality statistics on a grayscale crop.
  Future<FaceStats> getFaceStats(
    TransferableFrameData frame,
    Rect faceRect, {
    int sampleSize = 80,
  }) {
    final String id = generateCommandId('face-stats');
    return send<FaceStats>(
      FaceStatsCommand(
        id,
        frame: frame,
        faceRect: faceRect,
        sampleSize: sampleSize,
      ),
    );
  }

  /// Extracts a 112x112 aligned RGB crop using Umeyama affine transform.
  Future<AlignedCropData> getAlignedCrop(
    TransferableFrameData frame,
    AffineMatrix uprightToOutput,
  ) {
    final String id = generateCommandId('aligned-crop');
    return send<AlignedCropData>(
      AlignedCropCommand(id, frame: frame, uprightToOutput: uprightToOutput),
    );
  }

  /// Samples mean RGB skin color and brightness from specific face regions.
  Future<SkinColorSampleData> getSkinColorSample(
    TransferableFrameData frame,
    List<Rect> skinRegions,
  ) {
    final String id = generateCommandId('skin-color');
    return send<SkinColorSampleData>(
      SkinColorSampleCommand(id, frame: frame, skinRegions: skinRegions),
    );
  }

  /// Evaluates passive anti-spoofing liveness on a detected face in a camera frame.
  Future<PassiveFrameResult> runPassive({
    required TransferableFrameData frame,
    required Rect faceRect,
    required List<String> modelNames,
    required PassivePreprocessConfig preprocessConfig,
  }) {
    final String id = generateCommandId('passive');
    return send<PassiveFrameResult>(
      PassiveLivenessCommand(
        id,
        frame: frame,
        faceRect: faceRect,
        modelNames: modelNames,
        preprocessConfig: preprocessConfig,
      ),
    );
  }

  /// Computes face recognition embedding(s) from aligned RGB crops.
  Future<EmbedData> computeEmbedding({
    required List<Uint8List> cropsRgb,
    String modelName = 'SFace',
    RecognizerPreprocessConfig preprocessConfig =
        const RecognizerPreprocessConfig(),
  }) async {
    if (!isModelLoaded(modelName)) {
      final ModelSpec spec = ModelRegistry.allModels.firstWhere(
        (ModelSpec s) => s.name == modelName || s.id == modelName,
        orElse: () => ModelRegistry.sFace,
      );
      await ensureInitialized(models: <ModelSpec>[spec]);
    }
    final String id = generateCommandId('embed');
    return send<EmbedData>(
      EmbedCommand(
        id,
        cropsRgb: cropsRgb,
        modelName: modelName,
        preprocessConfig: preprocessConfig,
      ),
    );
  }

  /// Restarts the worker isolate after a crash or for a clean session.
  Future<void> restart() async {
    await dispose();
    await start();
  }

  /// Gracefully terminates the worker isolate and frees all resources.
  Future<void> dispose() async {
    _isDisposing = true;
    _isStarted = false;

    if (_toWorkerPort != null) {
      try {
        final String id = generateCommandId('dispose');
        _toWorkerPort!.send(DisposeCommand(id));
      } catch (_) {
        // Discard send error during tear-down.
      }
    }

    // Fail all pending completers
    for (final Completer<dynamic> completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Worker was disposed before completing request'),
        );
      }
    }
    _pendingRequests.clear();

    await _messageSub?.cancel();
    await _errorSub?.cancel();
    await _exitSub?.cancel();

    _fromWorkerPort?.close();
    _errorPort?.close();
    _exitPort?.close();

    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _toWorkerPort = null;
    _fromWorkerPort = null;
    _errorPort = null;
    _exitPort = null;
    _startingFuture = null;
    _loadedModelNames.clear();
  }

  void _handleResponse(WorkerResponse response) {
    final Completer<dynamic>? completer = _pendingRequests.remove(response.id);
    if (completer == null) return;

    if (response is WorkerSuccessResponse) {
      completer.complete(response.data);
    } else if (response is WorkerErrorResponse) {
      completer.completeError(
        Exception(response.message),
        response.stackTrace != null
            ? StackTrace.fromString(response.stackTrace!)
            : null,
      );
    } else if (response is WorkerCancelledResponse) {
      completer.completeError(
        TimeoutException('Command ${response.id} was cancelled by caller'),
      );
    }
  }

  void _handleCrash(String reason) {
    _isStarted = false;
    for (final Completer<dynamic> completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError(reason));
      }
    }
    _pendingRequests.clear();
  }
}

class _WorkerInitData {
  const _WorkerInitData({
    required this.toMainPort,
    required this.engineFactory,
  });

  final SendPort toMainPort;
  final InferenceEngine Function() engineFactory;
}

/// Worker entry point running in the dedicated background isolate.
void _workerEntrypoint(_WorkerInitData initData) {
  final SendPort toMainPort = initData.toMainPort;
  final ReceivePort fromMainPort = ReceivePort();
  toMainPort.send(fromMainPort.sendPort);

  final InferenceEngine engine = initData.engineFactory();
  final PixelSampler sampler = const PixelSampler();
  final PassiveCropper cropper = PassiveCropper(sampler: sampler);
  final Map<String, InferenceSession> sessions = <String, InferenceSession>{};
  final Set<String> cancelledIds = <String>{};

  Uint8List? reusablePassiveRgb;
  Float32List? reusablePassiveFloats;

  fromMainPort.listen((dynamic message) async {
    if (message is! WorkerCommand) return;

    if (message is CancelCommand) {
      cancelledIds.add(message.targetCommandId);
      toMainPort.send(WorkerSuccessResponse<bool>(message.id, true));
      return;
    }

    if (cancelledIds.remove(message.id)) {
      toMainPort.send(WorkerCancelledResponse(message.id));
      return;
    }

    try {
      if (message is LoadModelsCommand) {
        for (final MapEntry<String, Uint8List> entry
            in message.modelBytes.entries) {
          final InferenceSession? existing = sessions.remove(entry.key);
          existing?.dispose();
          final InferenceSession session = await engine.createSessionFromBytes(
            entry.value,
          );
          sessions[entry.key] = session;
        }
        toMainPort.send(
          WorkerSuccessResponse<List<String>>(
            message.id,
            sessions.keys.toList(),
          ),
        );
      } else if (message is BenchmarkCommand) {
        final Map<String, double> medianLatencyMs = <String, double>{};
        final Map<String, List<double>> allLatenciesMs =
            <String, List<double>>{};

        for (final MapEntry<String, InferenceSession> entry
            in sessions.entries) {
          if (cancelledIds.remove(message.id)) {
            toMainPort.send(WorkerCancelledResponse(message.id));
            return;
          }

          final String modelName = entry.key;
          final InferenceSession session = entry.value;

          if (session.inputNames.isEmpty) {
            medianLatencyMs[modelName] = 0.0;
            allLatenciesMs[modelName] = <double>[0.0];
            continue;
          }

          final String inputNodeName = session.inputNames.first;
          final ModelSpec? spec = ModelRegistry.allModels
              .cast<ModelSpec?>()
              .firstWhere(
                (ModelSpec? s) => s?.name == modelName,
                orElse: () => null,
              );
          final List<int> concreteShape =
              spec?.inputShape ?? <int>[1, 3, 80, 80];
          final int totalElements =
              spec?.inputElementCount ?? (1 * 3 * 80 * 80);

          final Float32Tensor dummyTensor = Float32Tensor(
            shape: concreteShape,
            data: Float32List(totalElements),
          );

          // Warmup
          for (int w = 0; w < message.warmupIterations; w++) {
            session.run(<String, Float32Tensor>{inputNodeName: dummyTensor});
          }

          // Measurement
          final List<double> latencies = <double>[];
          for (int i = 0; i < message.iterations; i++) {
            final Stopwatch sw = Stopwatch()..start();
            session.run(<String, Float32Tensor>{inputNodeName: dummyTensor});
            sw.stop();
            latencies.add(sw.elapsedMicroseconds / 1000.0);
          }

          final List<double> sorted = List<double>.from(latencies)..sort();
          final double median = sorted.isNotEmpty
              ? (sorted.length.isOdd
                    ? sorted[sorted.length ~/ 2]
                    : (sorted[(sorted.length ~/ 2) - 1] +
                              sorted[sorted.length ~/ 2]) /
                          2.0)
              : 0.0;

          medianLatencyMs[modelName] = median;
          allLatenciesMs[modelName] = latencies;
        }

        toMainPort.send(
          WorkerSuccessResponse<BenchmarkData>(
            message.id,
            BenchmarkData(
              medianLatencyMs: medianLatencyMs,
              allLatenciesMs: allLatenciesMs,
            ),
          ),
        );
      } else if (message is FaceStatsCommand) {
        final FrameData frame = message.frame.toFrameData();
        final FaceStats stats = sampler.computeFaceStats(
          frame,
          message.faceRect,
          sampleSize: message.sampleSize,
        );
        toMainPort.send(WorkerSuccessResponse<FaceStats>(message.id, stats));
      } else if (message is AlignedCropCommand) {
        final FrameData frame = message.frame.toFrameData();
        final Uint8List rgbBytes = sampler.warpAffine(
          frame,
          message.uprightToOutput,
          112,
          112,
        );
        toMainPort.send(
          WorkerSuccessResponse<AlignedCropData>(
            message.id,
            AlignedCropData(rgbBytes: rgbBytes, width: 112, height: 112),
          ),
        );
      } else if (message is SkinColorSampleCommand) {
        final FrameData frame = message.frame.toFrameData();
        final SkinColorSampleData sample = sampler.sampleSkinRegionsRgb(
          frame,
          message.skinRegions,
        );
        toMainPort.send(
          WorkerSuccessResponse<SkinColorSampleData>(message.id, sample),
        );
      } else if (message is PassiveLivenessCommand) {
        final FrameData frame = message.frame.toFrameData();
        final FrameGeometry geometry = FrameGeometry(
          rawWidth: frame.width,
          rawHeight: frame.height,
          rotation: frame.sensorRotation,
        );
        final int uprightW = geometry.uprightWidth;
        final int uprightH = geometry.uprightHeight;

        const int cropW = 80;
        const int cropH = 80;
        const int requiredRgbLen = cropW * cropH * 3;
        const int requiredFloatLen = 1 * 3 * cropW * cropH;

        if (reusablePassiveRgb == null ||
            reusablePassiveRgb!.length != requiredRgbLen) {
          reusablePassiveRgb = Uint8List(requiredRgbLen);
        }
        if (reusablePassiveFloats == null ||
            reusablePassiveFloats!.length != requiredFloatLen) {
          reusablePassiveFloats = Float32List(requiredFloatLen);
        }

        final Map<String, PassiveModelResult> modelResults =
            <String, PassiveModelResult>{};

        for (final String modelName in message.modelNames) {
          if (cancelledIds.remove(message.id)) {
            toMainPort.send(WorkerCancelledResponse(message.id));
            return;
          }

          final InferenceSession? session = sessions[modelName];
          if (session == null || session.inputNames.isEmpty) {
            continue;
          }

          final double cropScale =
              modelName == ModelRegistry.miniFASNetV1SE.name ||
                  modelName.contains('V1SE')
              ? message.preprocessConfig.v1SeCropScale
              : message.preprocessConfig.v2CropScale;

          final Rect cropRect = cropper.computeCropRect(
            faceBox: message.faceRect,
            srcW: uprightW,
            srcH: uprightH,
            cropScale: cropScale,
            boxExpansion: message.preprocessConfig.boxExpansion,
          );

          final AffineMatrix transform = cropper.computeUprightToCropTransform(
            cropRect: cropRect,
            outW: cropW,
            outH: cropH,
          );

          sampler.warpAffine(
            frame,
            transform,
            cropW,
            cropH,
            outBuffer: reusablePassiveRgb,
          );

          final bool isBgr =
              message.preprocessConfig.channelOrder == ChannelOrder.bgr;
          final double scale = message.preprocessConfig.scale;
          final List<double> mean = message.preprocessConfig.mean;
          final List<double> std = message.preprocessConfig.std;
          const int planeSize = cropW * cropH;

          for (int i = 0; i < planeSize; i++) {
            final int rgbOffset = i * 3;
            final double r = reusablePassiveRgb![rgbOffset].toDouble();
            final double g = reusablePassiveRgb![rgbOffset + 1].toDouble();
            final double b = reusablePassiveRgb![rgbOffset + 2].toDouble();

            final double c0 = isBgr ? b : r;
            final double c1 = g;
            final double c2 = isBgr ? r : b;

            reusablePassiveFloats![i] = (c0 * scale - mean[0]) / std[0];
            reusablePassiveFloats![planeSize + i] =
                (c1 * scale - mean[1]) / std[1];
            reusablePassiveFloats![planeSize * 2 + i] =
                (c2 * scale - mean[2]) / std[2];
          }

          final String inputNodeName = session.inputNames.first;
          final Float32Tensor inputTensor = Float32Tensor(
            shape: const <int>[1, 3, cropW, cropH],
            data: reusablePassiveFloats!,
          );

          final Stopwatch sw = Stopwatch()..start();
          final Map<String, List<double>> outputs = session.run(
            <String, Float32Tensor>{inputNodeName: inputTensor},
          );
          sw.stop();
          final double latencyMs = sw.elapsedMicroseconds / 1000.0;

          if (outputs.isEmpty) continue;
          final List<double> rawScores = outputs.values.first.sublist(
            0,
            math.min(3, outputs.values.first.length),
          );
          final List<double> probs = message.preprocessConfig.applySoftmax
              ? MathUtils.softmax(rawScores)
              : rawScores;

          final int realIdx = message.preprocessConfig.realClassIndex;
          final double realProb = (realIdx >= 0 && realIdx < probs.length)
              ? probs[realIdx]
              : 0.0;

          modelResults[modelName] = PassiveModelResult(
            modelName: modelName,
            realProbability: realProb,
            rawScores: List<double>.unmodifiable(rawScores),
            softmaxProbabilities: List<double>.unmodifiable(probs),
            latencyMs: latencyMs,
            cropRgbBytes: Uint8List.fromList(reusablePassiveRgb!),
          );
        }

        final double meanProb = modelResults.isNotEmpty
            ? modelResults.values.fold<double>(
                    0.0,
                    (double sum, PassiveModelResult r) =>
                        sum + r.realProbability,
                  ) /
                  modelResults.length
            : 0.0;

        final double totalLatency = modelResults.values.fold<double>(
          0.0,
          (double sum, PassiveModelResult r) => sum + r.latencyMs,
        );

        toMainPort.send(
          WorkerSuccessResponse<PassiveFrameResult>(
            message.id,
            PassiveFrameResult(
              modelResults: modelResults,
              meanRealProbability: meanProb,
              totalLatencyMs: totalLatency,
            ),
          ),
        );
      } else if (message is EmbedCommand) {
        if (cancelledIds.remove(message.id)) {
          toMainPort.send(WorkerCancelledResponse(message.id));
          return;
        }

        final InferenceSession? session =
            sessions[message.modelName] ??
            sessions[ModelRegistry.sFace.name] ??
            sessions[ModelRegistry.sFace.id];

        if (session == null || session.inputNames.isEmpty) {
          toMainPort.send(
            WorkerErrorResponse(
              message.id,
              'Model ${message.modelName} session not found or uninitialized',
            ),
          );
          return;
        }

        final ModelSpec? spec = ModelRegistry.allModels
            .cast<ModelSpec?>()
            .firstWhere(
              (ModelSpec? s) =>
                  s?.name == message.modelName || s?.id == message.modelName,
              orElse: () => ModelRegistry.sFace,
            );

        final List<int> concreteShape =
            spec?.inputShape ?? const <int>[1, 3, 112, 112];
        final int channels = concreteShape.length >= 2 ? concreteShape[1] : 3;
        final int h = concreteShape.length >= 3 ? concreteShape[2] : 112;
        final int w = concreteShape.length >= 4 ? concreteShape[3] : 112;
        final int planeSize = h * w;
        final int totalElements = channels * planeSize;
        final String inputNodeName = session.inputNames.first;

        final bool isBgr =
            message.preprocessConfig.channelOrder == ChannelOrder.bgr;
        final double scale = message.preprocessConfig.scale;
        final List<double> mean = message.preprocessConfig.mean;
        final List<double> std = message.preprocessConfig.std;

        final List<List<double>> cropEmbeddings = <List<double>>[];
        final Stopwatch totalSw = Stopwatch()..start();

        for (final Uint8List cropRgb in message.cropsRgb) {
          if (cropRgb.length < totalElements) continue;

          final Float32List floats = Float32List(totalElements);
          for (int i = 0; i < planeSize; i++) {
            final int rgbOffset = i * 3;
            final double r = cropRgb[rgbOffset].toDouble();
            final double g = cropRgb[rgbOffset + 1].toDouble();
            final double b = cropRgb[rgbOffset + 2].toDouble();

            final double c0 = isBgr ? b : r;
            final double c1 = g;
            final double c2 = isBgr ? r : b;

            floats[i] = (c0 * scale - mean[0]) / std[0];
            floats[planeSize + i] = (c1 * scale - mean[1]) / std[1];
            floats[2 * planeSize + i] = (c2 * scale - mean[2]) / std[2];
          }

          final Float32Tensor inputTensor = Float32Tensor(
            shape: concreteShape,
            data: floats,
          );

          final Map<String, List<double>> outputs = session.run(
            <String, Float32Tensor>{inputNodeName: inputTensor},
          );

          if (outputs.isNotEmpty) {
            final List<double> raw = outputs.values.first;
            cropEmbeddings.add(MathUtils.l2Normalize(raw));
          }
        }

        totalSw.stop();

        if (cropEmbeddings.isEmpty) {
          toMainPort.send(
            WorkerErrorResponse(
              message.id,
              'No valid embeddings could be computed from provided crops',
            ),
          );
          return;
        }

        final List<double> finalEmbedding;
        if (cropEmbeddings.length == 1) {
          finalEmbedding = cropEmbeddings.first;
        } else {
          final int dim = cropEmbeddings.first.length;
          final List<double> sumVec = List<double>.filled(dim, 0.0);
          for (final List<double> emb in cropEmbeddings) {
            for (int d = 0; d < dim; d++) {
              sumVec[d] += emb[d];
            }
          }
          for (int d = 0; d < dim; d++) {
            sumVec[d] /= cropEmbeddings.length;
          }
          finalEmbedding = MathUtils.l2Normalize(sumVec);
        }

        toMainPort.send(
          WorkerSuccessResponse<EmbedData>(
            message.id,
            EmbedData(
              embedding: finalEmbedding,
              modelId: spec?.id ?? ModelRegistry.sFace.id,
              dimension: finalEmbedding.length,
              latencyMs: totalSw.elapsedMicroseconds / 1000.0,
            ),
          ),
        );
      } else if (message is DisposeCommand) {
        for (final InferenceSession session in sessions.values) {
          session.dispose();
        }
        sessions.clear();
        engine.dispose();
        toMainPort.send(WorkerSuccessResponse<bool>(message.id, true));
        fromMainPort.close();
      } else {
        toMainPort.send(
          WorkerErrorResponse(
            message.id,
            'Unhandled command: ${message.runtimeType}',
          ),
        );
      }
    } catch (e, st) {
      toMainPort.send(
        WorkerErrorResponse(message.id, e.toString(), st.toString()),
      );
    }
  });
}
