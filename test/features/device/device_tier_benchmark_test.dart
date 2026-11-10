import 'package:attendence/features/device/domain/device_benchmark.dart';
import 'package:attendence/features/device/domain/device_tier.dart';
import 'package:attendence/features/ml/domain/inference_engine.dart';
import 'package:attendence/features/ml/worker/ml_worker.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSession implements InferenceSession {
  _FakeSession();

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
  @override
  Future<InferenceSession> createSessionFromBytes(Uint8List bytes) async {
    return _FakeSession();
  }

  @override
  void dispose() {}
}

InferenceEngine _fastEngineFactory() => _FakeEngine();

class _FakeAssetBundle extends Fake implements AssetBundle {
  @override
  Future<ByteData> load(String key) async {
    return ByteData(64);
  }
}

void main() {
  group('TierProfile', () {
    test('low tier configuration matches specifications', () {
      final TierProfile profile = TierProfile.fromTier(DeviceTier.low);
      expect(profile.tier, equals(DeviceTier.low));
      expect(profile.cameraPreset, equals(ResolutionPreset.medium));
      expect(profile.analysisFps, equals(10.0));
      expect(profile.passiveFrameCount, equals(5));
      expect(profile.flashChallengeDefault, isFalse);
      expect(
        profile.sfaceVariantPreference,
        equals(SFaceVariantPreference.floatModel),
      );
    });

    test('low tier selects int8 variant when int8 model is present', () {
      final TierProfile profile = TierProfile.fromTier(
        DeviceTier.low,
        hasInt8Model: true,
      );
      expect(
        profile.sfaceVariantPreference,
        equals(SFaceVariantPreference.int8Model),
      );
      expect(
        profile.sfaceModelPath,
        equals('assets/ai/face_recognition_sface_2021dec_int8.onnx'),
      );
    });

    test('mid tier configuration matches specifications', () {
      final TierProfile profile = TierProfile.fromTier(DeviceTier.mid);
      expect(profile.tier, equals(DeviceTier.mid));
      expect(profile.cameraPreset, equals(ResolutionPreset.medium));
      expect(profile.analysisFps, equals(15.0));
      expect(profile.passiveFrameCount, equals(8));
      expect(profile.flashChallengeDefault, isTrue);
    });

    test('high tier configuration matches specifications', () {
      final TierProfile profile = TierProfile.fromTier(DeviceTier.high);
      expect(profile.tier, equals(DeviceTier.high));
      expect(profile.cameraPreset, equals(ResolutionPreset.high));
      expect(profile.analysisFps, equals(20.0));
      expect(profile.passiveFrameCount, equals(12));
      expect(profile.flashChallengeDefault, isTrue);
    });
  });

  group('DeviceBenchmark', () {
    late MlWorker worker;
    late DeviceBenchmark benchmark;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      worker = MlWorker(engineFactory: _fastEngineFactory);
      benchmark = DeviceBenchmark(
        worker: worker,
        assetBundle: _FakeAssetBundle(),
      );
    });

    tearDown(() async {
      await worker.dispose();
    });

    test('runs benchmark and classifies fast device as high tier', () async {
      final BenchmarkReport report = await benchmark.runBenchmark(
        iterations: 2,
        warmupIterations: 1,
      );

      expect(report.classifiedTier, equals(DeviceTier.high));
      expect(report.totalPipelineLatencyMs, lessThan(60.0));
      expect(await benchmark.getEffectiveTier(), equals(DeviceTier.high));
    });

    test(
      'manual tier override takes precedence over benchmarked tier',
      () async {
        await benchmark.runBenchmark(iterations: 1, warmupIterations: 1);
        expect(await benchmark.getEffectiveTier(), equals(DeviceTier.high));

        await benchmark.setTierOverride(DeviceTier.low);
        expect(await benchmark.getEffectiveTier(), equals(DeviceTier.low));
        expect(await benchmark.getManualOverride(), equals(DeviceTier.low));

        await benchmark.setTierOverride(null);
        expect(await benchmark.getEffectiveTier(), equals(DeviceTier.high));
        expect(await benchmark.getManualOverride(), isNull);
      },
    );
  });
}
