import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../core/utils/affine_matrix.dart';
import '../../camera/domain/frame_data.dart';
import '../../liveness/domain/passive_preprocess_config.dart';
import '../../recognition/domain/recognizer_preprocess_config.dart';

export '../../detection/domain/face_stats.dart';
export '../../liveness/domain/passive_preprocess_config.dart';
export '../../recognition/domain/recognizer_preprocess_config.dart';

/// Base class for all commands dispatched from the main isolate to the worker.
@immutable
sealed class WorkerCommand {
  const WorkerCommand(this.id);
  final String id;
}

/// Commands the worker to load ONNX model sessions from in-memory buffers.
class LoadModelsCommand extends WorkerCommand {
  const LoadModelsCommand(super.id, this.modelBytes);
  final Map<String, Uint8List> modelBytes;
}

/// Commands the worker to execute inference latency benchmarks on all loaded models.
class BenchmarkCommand extends WorkerCommand {
  const BenchmarkCommand(
    super.id, {
    this.iterations = 10,
    this.warmupIterations = 1,
  });

  final int iterations;
  final int warmupIterations;
}

/// Commands the worker to process a transferable camera frame.
class ProcessFrameCommand extends WorkerCommand {
  const ProcessFrameCommand(super.id, this.frame, this.task);
  final TransferableFrameData frame;
  final String task;
}

/// Commands the worker to compute face image quality statistics (sharpness, brightness, glare).
class FaceStatsCommand extends WorkerCommand {
  const FaceStatsCommand(
    super.id, {
    required this.frame,
    required this.faceRect,
    this.sampleSize = 80,
  });

  final TransferableFrameData frame;
  final Rect faceRect;
  final int sampleSize;
}

/// Commands the worker to produce a 112x112 aligned RGB crop using Umeyama transform.
class AlignedCropCommand extends WorkerCommand {
  const AlignedCropCommand(
    super.id, {
    required this.frame,
    required this.uprightToOutput,
  });

  final TransferableFrameData frame;
  final AffineMatrix uprightToOutput;
}

/// Commands the worker to evaluate passive liveness using MiniFASNet models.
class PassiveLivenessCommand extends WorkerCommand {
  const PassiveLivenessCommand(
    super.id, {
    required this.frame,
    required this.faceRect,
    required this.modelNames,
    required this.preprocessConfig,
  });

  final TransferableFrameData frame;
  final Rect faceRect;
  final List<String> modelNames;
  final PassivePreprocessConfig preprocessConfig;
}

/// Commands the worker to sample mean skin color from fixed upright face regions.
class SkinColorSampleCommand extends WorkerCommand {
  const SkinColorSampleCommand(
    super.id, {
    required this.frame,
    required this.skinRegions,
  });

  final TransferableFrameData frame;
  final List<Rect> skinRegions;
}

/// Commands the worker to compute face recognition embeddings from aligned RGB crops.
class EmbedCommand extends WorkerCommand {
  const EmbedCommand(
    super.id, {
    required this.cropsRgb,
    this.modelName = 'SFace',
    this.preprocessConfig = const RecognizerPreprocessConfig(),
  });

  /// List of aligned RGB crops (each 112x112x3 bytes).
  final List<Uint8List> cropsRgb;

  /// Model name to execute (default 'SFace' or int8 SFace variant).
  final String modelName;

  /// Preprocessing parameters.
  final RecognizerPreprocessConfig preprocessConfig;
}

/// Cancels an in-flight or pending command.
class CancelCommand extends WorkerCommand {
  const CancelCommand(super.id, this.targetCommandId);
  final String targetCommandId;
}

/// Gracefully disposes worker resources and terminates its isolate.
class DisposeCommand extends WorkerCommand {
  const DisposeCommand(super.id);
}

/// Base class for all responses sent from the worker isolate back to the main thread.
@immutable
sealed class WorkerResponse {
  const WorkerResponse(this.id);
  final String id;
}

/// Successful result response.
class WorkerSuccessResponse<T> extends WorkerResponse {
  const WorkerSuccessResponse(super.id, this.data);
  final T data;
}

/// Error response indicating an exception occurred during command processing.
class WorkerErrorResponse extends WorkerResponse {
  const WorkerErrorResponse(super.id, this.message, [this.stackTrace]);
  final String message;
  final String? stackTrace;
}

/// Acknowledges that a command was cancelled before or during execution.
class WorkerCancelledResponse extends WorkerResponse {
  const WorkerCancelledResponse(super.id);
}

/// Benchmark metrics returned by [BenchmarkCommand].
@immutable
class BenchmarkData {
  const BenchmarkData({
    required this.medianLatencyMs,
    required this.allLatenciesMs,
  });

  /// Median inference latency per model name in milliseconds.
  final Map<String, double> medianLatencyMs;

  /// Full list of measured latencies per model name in milliseconds.
  final Map<String, List<double>> allLatenciesMs;
}

/// Aligned 112x112 crop result containing RGB bytes and dimensions.
@immutable
class AlignedCropData {
  const AlignedCropData({
    required this.rgbBytes,
    required this.width,
    required this.height,
  });

  final Uint8List rgbBytes;
  final int width;
  final int height;
}

/// Evaluation result for a single passive anti-spoofing model on a frame.
@immutable
class PassiveModelResult {
  const PassiveModelResult({
    required this.modelName,
    required this.realProbability,
    required this.rawScores,
    this.softmaxProbabilities = const <double>[],
    required this.latencyMs,
    this.cropRgbBytes,
  });

  /// Name of the model evaluated (e.g. MiniFASNetV2).
  final String modelName;

  /// Probability that the face is real (class index per config).
  final double realProbability;

  /// Raw scores or logits from the model output.
  final List<double> rawScores;

  /// Softmax probabilities for all output classes.
  final List<double> softmaxProbabilities;

  /// Inference execution time in milliseconds.
  final double latencyMs;

  /// Exact 80x80 RGB crop bytes fed to the model (for debugging/inspection).
  final Uint8List? cropRgbBytes;
}

/// Aggregated result across all passive models evaluated on a single frame.
@immutable
class PassiveFrameResult {
  const PassiveFrameResult({
    required this.modelResults,
    required this.meanRealProbability,
    required this.totalLatencyMs,
  });

  /// Per-model evaluation outputs.
  final Map<String, PassiveModelResult> modelResults;

  /// Average real probability across evaluated models.
  final double meanRealProbability;

  /// Total inference time across evaluated models in milliseconds.
  final double totalLatencyMs;
}

/// Mean RGB skin color and brightness data returned by [SkinColorSampleCommand].
@immutable
class SkinColorSampleData {
  const SkinColorSampleData({
    required this.meanR,
    required this.meanG,
    required this.meanB,
    required this.brightness,
  });

  final double meanR;
  final double meanG;
  final double meanB;
  final double brightness;
}

/// Embedding vector data returned by [EmbedCommand].
@immutable
class EmbedData {
  const EmbedData({
    required this.embedding,
    required this.modelId,
    required this.dimension,
    required this.latencyMs,
  });

  /// 128-d L2-normalized embedding vector.
  final List<double> embedding;

  /// Model spec identifier.
  final String modelId;

  /// Embedding dimension (e.g. 128).
  final int dimension;

  /// Total inference time in milliseconds.
  final double latencyMs;
}
