import 'dart:typed_data';

import 'package:attendence/features/ml/domain/inference_engine.dart';
import 'package:attendence/features/ml/domain/model_registry.dart';
import 'package:attendence/features/ml/domain/model_self_check.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeInferenceSession implements InferenceSession {
  FakeInferenceSession({
    required this.inputNames,
    required this.outputNames,
    required this.outputMap,
  });

  @override
  final List<String> inputNames;

  @override
  final List<String> outputNames;

  final Map<String, List<double>> outputMap;
  bool isDisposed = false;

  @override
  Map<String, List<double>> run(Map<String, Float32Tensor> inputs) {
    if (isDisposed) {
      throw StateError('Cannot run on disposed session');
    }
    return outputMap;
  }

  @override
  void dispose() {
    isDisposed = true;
  }
}

class FakeInferenceEngine implements InferenceEngine {
  FakeInferenceEngine({this.sessionBuilder, this.shouldThrow = false});

  final InferenceSession Function(Uint8List bytes)? sessionBuilder;
  final bool shouldThrow;
  bool isDisposed = false;

  @override
  Future<InferenceSession> createSessionFromBytes(Uint8List bytes) async {
    if (shouldThrow) {
      throw Exception('Engine initialization error');
    }
    if (sessionBuilder != null) {
      return sessionBuilder!(bytes);
    }
    return FakeInferenceSession(
      inputNames: const <String>['input', 'data'],
      outputNames: const <String>['output', 'fc1'],
      outputMap: <String, List<double>>{
        'output': const <double>[0.1, 0.2, 0.7],
        'fc1': List<double>.filled(128, 0.5),
      },
    );
  }

  @override
  void dispose() {
    isDisposed = true;
  }
}

void main() {
  group('ModelSelfCheck', () {
    test(
      'reports all success when engine and assets conform to specs',
      () async {
        final FakeInferenceEngine engine = FakeInferenceEngine(
          sessionBuilder: (Uint8List bytes) {
            return FakeInferenceSession(
              inputNames: const <String>['input', 'data'],
              outputNames: const <String>['output', 'fc1'],
              outputMap: <String, List<double>>{
                'output': const <double>[0.1, 0.2, 0.7],
                'fc1': List<double>.filled(128, 0.0),
              },
            );
          },
        );

        final ModelSelfCheck selfCheck = ModelSelfCheck(
          engine: engine,
          assetLoader: (String path) async => Uint8List(10),
        );

        final SelfCheckReport report = await selfCheck.runCheck();

        expect(report.isAllSuccess, isTrue);
        expect(report.failures, isEmpty);
        expect(report.results.length, 3);
        for (final ModelCheckResult res in report.results) {
          expect(res.isSuccess, isTrue);
          expect(res.errorMessage, isNull);
        }
      },
    );

    test(
      'reports failure when asset file is missing or loader throws',
      () async {
        final FakeInferenceEngine engine = FakeInferenceEngine();

        final ModelSelfCheck selfCheck = ModelSelfCheck(
          engine: engine,
          assetLoader: (String path) async {
            if (path.contains('face_recognition_sface')) {
              throw Exception('Asset not found: $path');
            }
            return Uint8List(10);
          },
        );

        final SelfCheckReport report = await selfCheck.runCheck();

        expect(report.isAllSuccess, isFalse);
        expect(report.failures.length, 1);
        final ModelCheckResult failure = report.failures.first;
        expect(failure.spec.id, ModelRegistry.sFace.id);
        expect(failure.errorMessage, contains('Failed to load model asset'));
      },
    );

    test(
      'reports failure when inference engine fails to create session',
      () async {
        final FakeInferenceEngine engine = FakeInferenceEngine(
          shouldThrow: true,
        );

        final ModelSelfCheck selfCheck = ModelSelfCheck(
          engine: engine,
          assetLoader: (String path) async => Uint8List(10),
        );

        final SelfCheckReport report = await selfCheck.runCheck();

        expect(report.isAllSuccess, isFalse);
        expect(report.failures.length, 3);
        for (final ModelCheckResult f in report.failures) {
          expect(
            f.errorMessage,
            contains('Failed to initialize inference session'),
          );
        }
      },
    );

    test('reports failure when expected input node is missing', () async {
      final FakeInferenceEngine engine = FakeInferenceEngine(
        sessionBuilder: (Uint8List bytes) {
          return FakeInferenceSession(
            inputNames: const <String>['wrong_input'],
            outputNames: const <String>['output', 'fc1'],
            outputMap: <String, List<double>>{
              'output': const <double>[0.1, 0.2, 0.7],
              'fc1': List<double>.filled(128, 0.0),
            },
          );
        },
      );

      final ModelSelfCheck selfCheck = ModelSelfCheck(
        engine: engine,
        assetLoader: (String path) async => Uint8List(10),
      );

      final SelfCheckReport report = await selfCheck.runCheck();

      expect(report.isAllSuccess, isFalse);
      for (final ModelCheckResult f in report.failures) {
        expect(f.errorMessage, contains('Expected input node'));
      }
    });

    test('reports failure when expected output node is missing', () async {
      final FakeInferenceEngine engine = FakeInferenceEngine(
        sessionBuilder: (Uint8List bytes) {
          return FakeInferenceSession(
            inputNames: const <String>['input', 'data'],
            outputNames: const <String>['wrong_output'],
            outputMap: const <String, List<double>>{},
          );
        },
      );

      final ModelSelfCheck selfCheck = ModelSelfCheck(
        engine: engine,
        assetLoader: (String path) async => Uint8List(10),
      );

      final SelfCheckReport report = await selfCheck.runCheck();

      expect(report.isAllSuccess, isFalse);
      for (final ModelCheckResult f in report.failures) {
        expect(f.errorMessage, contains('Expected output node'));
      }
    });

    test('reports failure when output tensor dimension mismatches', () async {
      final FakeInferenceEngine engine = FakeInferenceEngine(
        sessionBuilder: (Uint8List bytes) {
          return FakeInferenceSession(
            inputNames: const <String>['input', 'data'],
            outputNames: const <String>['output', 'fc1'],
            outputMap: <String, List<double>>{
              // MiniFAS models expect 3, but provide 2
              'output': const <double>[0.1, 0.9],
              // SFace expects 128, but provide 64
              'fc1': List<double>.filled(64, 0.0),
            },
          );
        },
      );

      final ModelSelfCheck selfCheck = ModelSelfCheck(
        engine: engine,
        assetLoader: (String path) async => Uint8List(10),
      );

      final SelfCheckReport report = await selfCheck.runCheck();

      expect(report.isAllSuccess, isFalse);
      expect(report.failures.length, 3);
      for (final ModelCheckResult f in report.failures) {
        expect(f.errorMessage, contains('does not match expected size'));
      }
    });
  });
}
