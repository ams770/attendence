import 'dart:math' as math;

import '../../../core/config/app_config.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/math_utils.dart';
import '../../employees/domain/employee.dart';
import '../../employees/domain/employee_repository.dart';
import '../../ml/domain/model_registry.dart';
import 'match_result.dart';

/// 1:N biometric face matching engine using cosine similarity and separation margins.
class FaceMatcher {
  FaceMatcher({
    required this.repository,
    required this.config,
    this.clock = const SystemClock(),
    this.cacheTtl = const Duration(minutes: 5),
  });

  final EmployeeRepository repository;
  final AppConfig config;
  final Clock clock;
  final Duration cacheTtl;

  List<EnrolledEmbedding>? _cachedEmbeddings;
  DateTime? _cacheTimestamp;

  /// Clears in-memory decrypted embeddings cache (e.g. on app pause or employee update).
  void clearCache() {
    _cachedEmbeddings = null;
    _cacheTimestamp = null;
  }

  /// Retrieves active decrypted embeddings, utilizing the short-lived in-memory cache.
  Future<List<EnrolledEmbedding>> _getEmbeddings({
    required String modelId,
    required int dimension,
    bool forceRefresh = false,
  }) async {
    final DateTime now = clock.now();
    if (!forceRefresh &&
        _cachedEmbeddings != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!) < cacheTtl) {
      return _cachedEmbeddings!;
    }

    final List<EnrolledEmbedding> loaded = await repository.getActiveEmbeddings(
      currentModelId: modelId,
      currentDimension: dimension,
    );

    _cachedEmbeddings = loaded;
    _cacheTimestamp = now;
    return loaded;
  }

  /// Matches an input 128-d embedding against all registered active employee templates.
  Future<MatchResult> match(
    List<double> queryEmbedding, {
    String? modelId,
    int? dimension,
    double? thresholdOverride,
    double? marginOverride,
    bool forceRefreshCache = false,
  }) async {
    final String activeModelId = modelId ?? ModelRegistry.sFace.id;
    final int activeDim = dimension ?? ModelRegistry.sFace.expectedOutputSize;
    final double threshold = thresholdOverride ?? config.recognitionThreshold;
    final double margin = marginOverride ?? config.recognitionMargin;

    final List<EnrolledEmbedding> embeddings = await _getEmbeddings(
      modelId: activeModelId,
      dimension: activeDim,
      forceRefresh: forceRefreshCache,
    );

    if (embeddings.isEmpty) {
      return const MatchResultNoEnrolledEmployees();
    }

    // Group embeddings by employee ID
    final Map<int, List<List<double>>> byEmployee = <int, List<List<double>>>{};
    for (final EnrolledEmbedding emb in embeddings) {
      byEmployee
          .putIfAbsent(emb.employeeId, () => <List<double>>[])
          .add(emb.vector);
    }

    // Compute max cosine similarity for each employee
    final List<MapEntry<int, double>> employeeScores =
        <MapEntry<int, double>>[];

    for (final MapEntry<int, List<List<double>>> entry in byEmployee.entries) {
      double maxSim = -1.0;
      for (final List<double> enrolledVector in entry.value) {
        final double sim = MathUtils.cosineSimilarity(
          queryEmbedding,
          enrolledVector,
        );
        if (sim > maxSim) {
          maxSim = sim;
        }
      }
      employeeScores.add(MapEntry<int, double>(entry.key, maxSim));
    }

    // Sort descending by similarity
    employeeScores.sort(
      (MapEntry<int, double> a, MapEntry<int, double> b) =>
          b.value.compareTo(a.value),
    );

    final MapEntry<int, double> best = employeeScores.first;
    final Employee? bestEmployee = await repository.getEmployeeById(best.key);

    if (bestEmployee == null) {
      return const MatchResultNoEnrolledEmployees();
    }

    // Check 1: Must satisfy recognition threshold
    if (best.value < threshold) {
      return MatchResultNoMatch(
        bestScore: best.value,
        bestEmployee: bestEmployee,
      );
    }

    // Check 2: If multiple candidates, must exceed second best by margin
    if (employeeScores.length > 1) {
      final MapEntry<int, double> secondBest = employeeScores[1];
      final double scoreDelta = best.value - secondBest.value;

      if (scoreDelta < margin) {
        final Employee? secondEmployee = await repository.getEmployeeById(
          secondBest.key,
        );
        if (secondEmployee != null) {
          return MatchResultAmbiguous(
            bestEmployee: bestEmployee,
            secondEmployee: secondEmployee,
            bestScore: best.value,
            secondScore: secondBest.value,
            margin: scoreDelta,
          );
        }
      }
    }

    final double secondScore = employeeScores.length > 1
        ? employeeScores[1].value
        : 0.0;
    final double actualMargin = best.value - secondScore;
    final double displayPercent = calculateDisplayPercent(
      best.value,
      threshold,
    );

    return MatchResultMatched(
      employee: bestEmployee,
      rawScore: best.value,
      margin: actualMargin,
      displayPercent: displayPercent,
    );
  }

  /// Computes a calibrated display percentage (0.0 to 100.0) around the threshold.
  ///
  /// Notice: This is strictly a presentation display transformation for the UI to provide
  /// a familiar percentage visual for non-technical users. It is NOT a posterior probability.
  /// Verification and security access decisions in the engine MUST rely solely on raw
  /// cosine similarity [rawScore].
  static double calculateDisplayPercent(double rawScore, double threshold) {
    // Sigmoid centered at threshold
    const double k = 25.0;
    final double normalized =
        1.0 / (1.0 + math.exp(-k * (rawScore - threshold)));
    return (normalized * 100.0).clamp(0.0, 100.0);
  }
}
