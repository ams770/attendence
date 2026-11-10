import 'dart:math' as math;

/// Mathematical utility functions for vector embeddings and tensor outputs.
class MathUtils {
  const MathUtils._();

  /// Calculates the Euclidean (L2) norm of a numeric vector.
  static double l2Norm(List<double> vector) {
    double sum = 0.0;
    for (int i = 0; i < vector.length; i++) {
      final double val = vector[i];
      sum += val * val;
    }
    return math.sqrt(sum);
  }

  /// Normalizes a vector in-place or returns a new L2-normalized vector.
  static List<double> l2Normalize(List<double> vector) {
    final double norm = l2Norm(vector);
    if (norm == 0.0 || norm.isNaN) {
      return List<double>.filled(vector.length, 0.0);
    }
    final List<double> result = List<double>.filled(vector.length, 0.0);
    for (int i = 0; i < vector.length; i++) {
      result[i] = vector[i] / norm;
    }
    return result;
  }

  /// Computes the cosine similarity between two numeric vectors.
  ///
  /// Cosine similarity = dot(a, b) / (norm(a) * norm(b)).
  /// Returns 0.0 if either vector has zero magnitude or if dimensions mismatch.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) {
      return 0.0;
    }

    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      final double va = a[i];
      final double vb = b[i];
      dot += va * vb;
      normA += va * va;
      normB += vb * vb;
    }

    final double denom = math.sqrt(normA) * math.sqrt(normB);
    if (denom == 0.0 || denom.isNaN) {
      return 0.0;
    }
    return dot / denom;
  }

  /// Computes numerical-stable softmax over a list of logits.
  static List<double> softmax(List<double> logits) {
    if (logits.isEmpty) {
      return const <double>[];
    }

    double maxLogit = logits[0];
    for (int i = 1; i < logits.length; i++) {
      if (logits[i] > maxLogit) {
        maxLogit = logits[i];
      }
    }

    double sumExp = 0.0;
    final List<double> expValues = List<double>.filled(logits.length, 0.0);
    for (int i = 0; i < logits.length; i++) {
      final double e = math.exp(logits[i] - maxLogit);
      expValues[i] = e;
      sumExp += e;
    }

    if (sumExp == 0.0 || sumExp.isNaN) {
      return List<double>.filled(logits.length, 1.0 / logits.length);
    }

    for (int i = 0; i < logits.length; i++) {
      expValues[i] /= sumExp;
    }
    return expValues;
  }

  /// Clamps a numeric [value] to the range [[min], [max]].
  static double clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
