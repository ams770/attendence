import '../../employees/domain/employee.dart';

/// Sealed hierarchy of face matching outcomes returned by [FaceMatcher].
sealed class MatchResult {
  const MatchResult();
}

/// Face was successfully identified as an enrolled employee with adequate threshold and margin.
class MatchResultMatched extends MatchResult {
  const MatchResultMatched({
    required this.employee,
    required this.rawScore,
    required this.margin,
    required this.displayPercent,
  });

  /// The identified employee entity.
  final Employee employee;

  /// Raw cosine similarity score against the employee's best matching enrolled sample.
  final double rawScore;

  /// Score delta between this employee and the second-best candidate.
  final double margin;

  /// Calibrated presentation percentage (0.0 to 100.0%) for UI display only.
  final double displayPercent;
}

/// The best match exceeded the threshold, but the score difference from the runner-up
/// did not satisfy the required margin (ambiguous identity).
class MatchResultAmbiguous extends MatchResult {
  const MatchResultAmbiguous({
    required this.bestEmployee,
    required this.secondEmployee,
    required this.bestScore,
    required this.secondScore,
    required this.margin,
  });

  final Employee bestEmployee;
  final Employee secondEmployee;
  final double bestScore;
  final double secondScore;
  final double margin;
}

/// No enrolled employee scored above the recognition threshold.
class MatchResultNoMatch extends MatchResult {
  const MatchResultNoMatch({required this.bestScore, this.bestEmployee});

  final double bestScore;
  final Employee? bestEmployee;
}

/// No active employees or embeddings are currently registered in the database.
class MatchResultNoEnrolledEmployees extends MatchResult {
  const MatchResultNoEnrolledEmployees();
}
