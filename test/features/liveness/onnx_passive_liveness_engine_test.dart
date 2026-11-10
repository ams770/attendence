import 'dart:typed_data';
import 'dart:ui';

import 'package:attendence/core/config/app_config.dart';
import 'package:attendence/features/camera/domain/frame_data.dart';
import 'package:attendence/features/liveness/data/onnx_passive_liveness_engine.dart';
import 'package:attendence/features/ml/domain/inference_engine.dart';
import 'package:attendence/features/ml/domain/model_registry.dart';
import 'package:attendence/features/ml/worker/ml_worker.dart';
import 'package:attendence/features/ml/worker/worker_protocol.dart';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSession implements InferenceSession {
  _FakeSession(this.name);
  final String name;

  @override
  List<String> get inputNames => const <String>['input'];

  @override
  List<String> get outputNames => const <String>['output'];

  @override
  Map<String, List<double>> run(Map<String, Float32Tensor> inputs) {
    // Return logits where index 1 is highest (real class)
    return <String, List<double>>{
      'output': <double>[1.0, 5.0, 1.0],
    };
  }

  @override
  void dispose() {}
}

class _FakeEngine implements InferenceEngine {
  @override
  Future<InferenceSession> createSessionFromBytes(Uint8List bytes) async {
    return _FakeSession('fake');
  }

  @override
  void dispose() {}
}

FrameData _createDummyNv21Frame(int width, int height) {
  final int ySize = width * height;
  final int uvSize = width * (height ~/ 2);
  final Uint8List yPlane = Uint8List(ySize)..fillRange(0, ySize, 128);
  final Uint8List uvPlane = Uint8List(uvSize)..fillRange(0, uvSize, 128);

  return FrameData(
    planes: <FramePlane>[
      FramePlane(bytes: yPlane, bytesPerRow: width, bytesPerPixel: 1),
      FramePlane(bytes: uvPlane, bytesPerRow: width, bytesPerPixel: 2),
    ],
    width: width,
    height: height,
    format: FrameFormat.nv21,
    sensorRotation: 0,
    lensDirection: CameraLensDirection.front,
    timestamp: DateTime.now(),
  );
}

void main() {
  group('OnnxPassiveLivenessEngine', () {
    late MlWorker worker;
    late OnnxPassiveLivenessEngine engine;

    setUp(() async {
      worker = MlWorker(engineFactory: () => _FakeEngine());
      await worker.start();

      // Pre-load dummy sessions for MiniFASNetV2 and MiniFASNetV1SE
      await worker.loadModels(<String, Uint8List>{
        ModelRegistry.miniFASNetV2.name: Uint8List(16),
        ModelRegistry.miniFASNetV1SE.name: Uint8List(16),
      });

      engine = OnnxPassiveLivenessEngine(
        worker: worker,
        config: const AppConfig(),
      );
    });

    tearDown(() async {
      await worker.dispose();
    });

    test(
      'evaluates both models and returns aggregated real probability',
      () async {
        final FrameData frame = _createDummyNv21Frame(640, 480);
        final TransferableFrameData transferable = frame.toTransferable();
        const Rect faceRect = Rect.fromLTWH(200, 150, 100, 100);

        final PassiveFrameResult result = await engine.evaluateFrame(
          frame: transferable,
          faceRect: faceRect,
          modelNames: <String>[
            ModelRegistry.miniFASNetV2.name,
            ModelRegistry.miniFASNetV1SE.name,
          ],
        );

        expect(result.modelResults.length, 2);
        expect(
          result.modelResults.containsKey(ModelRegistry.miniFASNetV2.name),
          isTrue,
        );
        expect(
          result.modelResults.containsKey(ModelRegistry.miniFASNetV1SE.name),
          isTrue,
        );

        // Logits [1.0, 5.0, 1.0]: softmax index 1 should be > 0.95
        final PassiveModelResult v2Result =
            result.modelResults[ModelRegistry.miniFASNetV2.name]!;
        expect(v2Result.realProbability, greaterThan(0.95));
        expect(v2Result.rawScores.length, 3);
        expect(v2Result.latencyMs, greaterThanOrEqualTo(0.0));

        expect(result.meanRealProbability, greaterThan(0.95));
        expect(result.totalLatencyMs, greaterThanOrEqualTo(0.0));
      },
    );

    test('supports single model execution (low tier mode)', () async {
      final FrameData frame = _createDummyNv21Frame(640, 480);
      final TransferableFrameData transferable = frame.toTransferable();
      const Rect faceRect = Rect.fromLTWH(200, 150, 100, 100);

      final PassiveFrameResult result = await engine.evaluateFrame(
        frame: transferable,
        faceRect: faceRect,
        modelNames: <String>[ModelRegistry.miniFASNetV2.name],
      );

      expect(result.modelResults.length, 1);
      expect(
        result.modelResults.containsKey(ModelRegistry.miniFASNetV2.name),
        isTrue,
      );
      expect(
        result.meanRealProbability,
        equals(
          result.modelResults[ModelRegistry.miniFASNetV2.name]!.realProbability,
        ),
      );
    });

    test('respects custom PassivePreprocessConfig', () async {
      final FrameData frame = _createDummyNv21Frame(640, 480);
      final TransferableFrameData transferable = frame.toTransferable();
      const Rect faceRect = Rect.fromLTWH(200, 150, 100, 100);

      // Disable softmax, class index 0
      const PassivePreprocessConfig customConfig = PassivePreprocessConfig(
        applySoftmax: false,
        realClassIndex: 0,
      );

      final PassiveFrameResult result = await engine.evaluateFrame(
        frame: transferable,
        faceRect: faceRect,
        modelNames: <String>[ModelRegistry.miniFASNetV2.name],
        preprocessConfig: customConfig,
      );

      final PassiveModelResult v2Result =
          result.modelResults[ModelRegistry.miniFASNetV2.name]!;
      // When applySoftmax is false, score is raw logit at index 0 (which is 1.0)
      expect(v2Result.realProbability, closeTo(1.0, 0.001));
    });
  });
}
