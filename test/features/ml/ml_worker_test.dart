import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:attendence/core/utils/affine_matrix.dart';
import 'package:attendence/features/camera/domain/frame_data.dart';
import 'package:attendence/features/ml/domain/inference_engine.dart';
import 'package:attendence/features/ml/worker/ml_worker.dart';
import 'package:attendence/features/ml/worker/worker_protocol.dart';
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
    return <String, List<double>>{
      'output': <double>[0.1, 0.8, 0.1],
    };
  }

  @override
  void dispose() {}
}

class _FakeEngine implements InferenceEngine {
  final Map<String, _FakeSession> sessions = <String, _FakeSession>{};

  @override
  Future<InferenceSession> createSessionFromBytes(Uint8List bytes) async {
    final _FakeSession s = _FakeSession('fake-session-${sessions.length}');
    sessions[s.name] = s;
    return s;
  }

  @override
  void dispose() {
    sessions.clear();
  }
}

InferenceEngine _fakeEngineFactory() => _FakeEngine();

void main() {
  group('MlWorker', () {
    late MlWorker worker;

    setUp(() {
      worker = MlWorker(engineFactory: _fakeEngineFactory);
    });

    tearDown(() async {
      await worker.dispose();
    });

    test(
      'starts isolate, executes loadModels and benchmark commands',
      () async {
        await worker.start();
        expect(worker.isAlive, isTrue);

        final List<String> loaded = await worker.loadModels(<String, Uint8List>{
          'model_a': Uint8List(16),
          'model_b': Uint8List(16),
        });

        expect(loaded, containsAll(<String>['model_a', 'model_b']));

        final BenchmarkData benchmark = await worker.benchmark(
          iterations: 3,
          warmupIterations: 1,
        );

        expect(benchmark.medianLatencyMs.containsKey('model_a'), isTrue);
        expect(benchmark.medianLatencyMs.containsKey('model_b'), isTrue);
        expect(benchmark.allLatenciesMs['model_a']!.length, equals(3));
      },
    );

    test(
      'cancellation cancels command and completes with TimeoutException',
      () async {
        await worker.start();

        final String cmdId = worker.generateCommandId('bench');
        worker.cancel(cmdId);

        // Sending a command that has already been marked cancelled
        final Future<BenchmarkData> future = worker.send<BenchmarkData>(
          BenchmarkCommand(cmdId, iterations: 5),
        );

        expect(future, throwsA(isA<Exception>()));
      },
    );

    test('restarts cleanly after disposal', () async {
      await worker.start();
      expect(worker.isAlive, isTrue);

      await worker.restart();
      expect(worker.isAlive, isTrue);

      final List<String> loaded = await worker.loadModels(<String, Uint8List>{
        'model_x': Uint8List(8),
      });
      expect(loaded, contains('model_x'));
    });

    test(
      'getFaceStats and getAlignedCrop process frames in worker isolate',
      () async {
        await worker.start();

        final Uint8List bgraBytes = Uint8List(4 * 4 * 4); // 4x4 image
        for (int i = 0; i < bgraBytes.length; i += 4) {
          bgraBytes[i] = 120; // B
          bgraBytes[i + 1] = 120; // G
          bgraBytes[i + 2] = 120; // R
          bgraBytes[i + 3] = 255; // A
        }

        final FrameData frame = FrameData(
          format: FrameFormat.bgra8888,
          width: 4,
          height: 4,
          planes: <FramePlane>[FramePlane(bytes: bgraBytes, bytesPerRow: 16)],
          sensorRotation: 0,
          lensDirection: CameraLensDirection.front,
          timestamp: DateTime(2026, 1, 1),
        );

        final TransferableFrameData transferable = frame.toTransferable();

        final FaceStats stats = await worker.getFaceStats(
          transferable,
          const Rect.fromLTWH(0, 0, 4, 4),
          sampleSize: 4,
        );

        expect(stats.meanBrightness, closeTo(120.0, 5.0));

        final AlignedCropData cropData = await worker.getAlignedCrop(
          frame.toTransferable(),
          AffineMatrix.identity,
        );

        expect(cropData.width, equals(112));
        expect(cropData.height, equals(112));
        expect(cropData.rgbBytes.length, equals(112 * 112 * 3));
      },
    );

    test('auto-starts worker isolate if send is called before start', () async {
      expect(worker.isAlive, isFalse);

      final List<String> loaded = await worker.loadModels(<String, Uint8List>{
        'model_auto': Uint8List(8),
      });

      expect(worker.isAlive, isTrue);
      expect(loaded, contains('model_auto'));
      expect(worker.isModelLoaded('model_auto'), isTrue);
    });
  });
}
