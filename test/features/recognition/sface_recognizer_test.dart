import 'dart:typed_data';

import 'package:attendence/core/utils/math_utils.dart';
import 'package:attendence/features/liveness/domain/liveness_session.dart';
import 'package:attendence/features/ml/domain/inference_engine.dart';
import 'package:attendence/features/ml/domain/model_registry.dart';
import 'package:attendence/features/ml/worker/ml_worker.dart';
import 'package:attendence/features/recognition/data/sface_recognizer_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSFaceSession implements InferenceSession {
  _FakeSFaceSession();

  @override
  List<String> get inputNames => const <String>['data'];

  @override
  List<String> get outputNames => const <String>['fc1'];

  @override
  Map<String, List<double>> run(Map<String, Float32Tensor> inputs) {
    return <String, List<double>>{'fc1': List<double>.filled(128, 0.42)};
  }

  @override
  void dispose() {}
}

class _FakeSFaceEngine implements InferenceEngine {
  final Map<String, _FakeSFaceSession> sessions = <String, _FakeSFaceSession>{};

  @override
  Future<InferenceSession> createSessionFromBytes(Uint8List bytes) async {
    final _FakeSFaceSession s = _FakeSFaceSession();
    sessions['session-${sessions.length}'] = s;
    return s;
  }

  @override
  void dispose() {
    sessions.clear();
  }
}

InferenceEngine _fakeEngineFactory() => _FakeSFaceEngine();

void main() {
  group('SFaceRecognizerImpl', () {
    late MlWorker worker;
    late SFaceRecognizerImpl recognizer;

    setUp(() {
      worker = MlWorker(engineFactory: _fakeEngineFactory);
      recognizer = SFaceRecognizerImpl(mlWorker: worker);
    });

    tearDown(() async {
      await worker.dispose();
    });

    test(
      'embedSingleCrop initializes worker and returns 128d embedding',
      () async {
        await worker.start();
        // Load fake SFace model bytes into isolate
        await worker.loadModels(<String, Uint8List>{
          ModelRegistry.sFace.name: Uint8List(16),
        });

        final Uint8List crop112 = Uint8List(112 * 112 * 3);
        final List<double> embedding = await recognizer.embedSingleCrop(
          crop112,
        );

        expect(embedding.length, equals(128));
        expect(MathUtils.l2Norm(embedding), closeTo(1.0, 1e-4));
      },
    );

    test(
      'embedVerifiedFaces produces normalized embedding from crops',
      () async {
        await worker.start();
        await worker.loadModels(<String, Uint8List>{
          ModelRegistry.sFace.name: Uint8List(16),
        });

        final VerifiedLiveFaces liveFaces = VerifiedLiveFaces.forTesting(
          crops: <VerifiedLiveFaceCrop>[
            VerifiedLiveFaceCrop(
              rgbBytes: Uint8List(112 * 112 * 3),
              sharpness: 100.0,
              width: 112,
              height: 112,
              trackingId: 1,
              timestamp: DateTime(2026, 1, 1),
            ),
            VerifiedLiveFaceCrop(
              rgbBytes: Uint8List(112 * 112 * 3),
              sharpness: 105.0,
              width: 112,
              height: 112,
              trackingId: 1,
              timestamp: DateTime(2026, 1, 1, 0, 0, 1),
            ),
          ],
        );

        final List<double> embedding = await recognizer.embedVerifiedFaces(
          liveFaces,
        );

        expect(embedding.length, equals(128));
        expect(MathUtils.l2Norm(embedding), closeTo(1.0, 1e-4));
      },
    );

    test(
      'embedVerifiedFaces throws ArgumentError when crops list is empty',
      () async {
        final VerifiedLiveFaces emptyFaces = VerifiedLiveFaces.forTesting(
          crops: <VerifiedLiveFaceCrop>[],
        );

        expect(
          () => recognizer.embedVerifiedFaces(emptyFaces),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });
}
