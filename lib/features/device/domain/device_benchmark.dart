import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ml/domain/model_registry.dart';
import '../../ml/worker/ml_worker.dart';
import '../../ml/worker/worker_protocol.dart';
import 'device_tier.dart';

/// Full summary report produced by a device benchmark run.
@immutable
class BenchmarkReport {
  const BenchmarkReport({
    required this.classifiedTier,
    required this.totalPipelineLatencyMs,
    required this.medianLatencyMs,
    required this.evaluatedAt,
    this.estimatedRamMb,
    this.overrideTier,
  });

  final DeviceTier classifiedTier;
  final double totalPipelineLatencyMs;
  final Map<String, double> medianLatencyMs;
  final DateTime evaluatedAt;
  final int? estimatedRamMb;
  final DeviceTier? overrideTier;

  /// Effective tier honoring manual override if set.
  DeviceTier get effectiveTier => overrideTier ?? classifiedTier;
}

/// Service that executes on-device inference benchmarks, classifies hardware tier,
/// and manages manual tier overrides.
class DeviceBenchmark {
  DeviceBenchmark({
    required this.worker,
    DeviceInfoPlugin? deviceInfo,
    SharedPreferences? prefs,
    AssetBundle? assetBundle,
  }) : _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
       _prefsInstance = prefs,
       _assetBundle = assetBundle ?? rootBundle;

  final MlWorker worker;
  final DeviceInfoPlugin _deviceInfo;
  SharedPreferences? _prefsInstance;
  final AssetBundle _assetBundle;

  static const String keyClassifiedTier = 'device_benchmark_classified_tier';
  static const String keyOverrideTier = 'device_benchmark_override_tier';
  static const String keyTotalLatency = 'device_benchmark_total_latency_ms';

  Future<SharedPreferences> get _prefs async =>
      _prefsInstance ??= await SharedPreferences.getInstance();

  /// Checks if the optional INT8 SFace model exists in assets.
  Future<bool> hasInt8Model() async {
    try {
      await _assetBundle.load(
        'assets/ai/face_recognition_sface_2021dec_int8.onnx',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves the current effective tier (honoring manual override if present).
  Future<DeviceTier> getEffectiveTier() async {
    final SharedPreferences p = await _prefs;
    final String? overrideName = p.getString(keyOverrideTier);
    if (overrideName != null) {
      return DeviceTier.fromName(overrideName);
    }

    final String? classifiedName = p.getString(keyClassifiedTier);
    if (classifiedName != null) {
      return DeviceTier.fromName(classifiedName);
    }

    return DeviceTier.mid;
  }

  /// Sets or clears a manual tier override.
  Future<void> setTierOverride(DeviceTier? override) async {
    final SharedPreferences p = await _prefs;
    if (override == null) {
      await p.remove(keyOverrideTier);
    } else {
      await p.setString(keyOverrideTier, override.name);
    }
  }

  /// Gets the currently stored manual override, if any.
  Future<DeviceTier?> getManualOverride() async {
    final SharedPreferences p = await _prefs;
    final String? overrideName = p.getString(keyOverrideTier);
    if (overrideName == null) return null;
    return DeviceTier.fromName(overrideName);
  }

  /// Runs the full warmup and measurement benchmark through the worker isolate.
  Future<BenchmarkReport> runBenchmark({
    int iterations = 10,
    int warmupIterations = 1,
    double highTierThresholdMs = 60.0,
    double midTierThresholdMs = 120.0,
  }) async {
    if (!worker.isAlive) {
      await worker.start();
    }

    // 1. Ensure models are loaded in worker isolate
    final Map<String, Uint8List> modelBytes = <String, Uint8List>{};
    for (final ModelSpec spec in ModelRegistry.allModels) {
      final ByteData data = await _assetBundle.load(spec.assetPath);
      modelBytes[spec.name] = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
    }
    await worker.loadModels(modelBytes);

    // 2. Execute benchmark in worker isolate
    final BenchmarkData data = await worker.benchmark(
      iterations: iterations,
      warmupIterations: warmupIterations,
    );

    // 3. Compute total pipeline latency (sum of median latencies)
    double totalLatency = 0.0;
    for (final double latency in data.medianLatencyMs.values) {
      totalLatency += latency;
    }

    // 4. Query RAM as secondary hint
    final int? ramMb = await _querySystemRamMb();

    // 5. Classify tier
    DeviceTier tier;
    if (totalLatency < highTierThresholdMs) {
      // If RAM is strictly below 3 GB, downgrade high tier to mid
      if (ramMb != null && ramMb < 2800) {
        tier = DeviceTier.mid;
      } else {
        tier = DeviceTier.high;
      }
    } else if (totalLatency < midTierThresholdMs) {
      tier = DeviceTier.mid;
    } else {
      tier = DeviceTier.low;
    }

    // 6. Persist results
    final SharedPreferences p = await _prefs;
    await p.setString(keyClassifiedTier, tier.name);
    await p.setDouble(keyTotalLatency, totalLatency);

    final DeviceTier? override = await getManualOverride();

    return BenchmarkReport(
      classifiedTier: tier,
      totalPipelineLatencyMs: totalLatency,
      medianLatencyMs: data.medianLatencyMs,
      evaluatedAt: DateTime.now(),
      estimatedRamMb: ramMb,
      overrideTier: override,
    );
  }

  Future<int?> _querySystemRamMb() async {
    try {
      if (kIsWeb) return null;
      if (Platform.isAndroid) {
        await _deviceInfo.androidInfo;
        // Primary classification relies on inference latency; RAM is secondary.
        return null;
      }
    } catch (_) {
      // Non-fatal secondary signal
    }
    return null;
  }
}
