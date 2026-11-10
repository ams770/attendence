import 'package:flutter/foundation.dart';

/// Domain entity representing an employee in the system.
@immutable
class Employee {
  const Employee({
    required this.id,
    required this.code,
    required this.name,
    this.isActive = true,
    required this.createdAt,
    this.embeddingCount = 0,
    this.needsReEnrollment = false,
  });

  /// Internal database identifier.
  final int id;

  /// Unique human-readable employee identifier/code (e.g. 'EMP-1001').
  final String code;

  /// Full employee name.
  final String name;

  /// Whether the employee is actively eligible for attendance check-ins.
  final bool isActive;

  /// Enrollment timestamp.
  final DateTime createdAt;

  /// Number of enrolled biometric embedding samples stored.
  final int embeddingCount;

  /// Whether the stored embeddings mismatch current model specifications,
  /// requiring the employee to re-enroll.
  final bool needsReEnrollment;

  Employee copyWith({
    int? id,
    String? code,
    String? name,
    bool? isActive,
    DateTime? createdAt,
    int? embeddingCount,
    bool? needsReEnrollment,
  }) {
    return Employee(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      embeddingCount: embeddingCount ?? this.embeddingCount,
      needsReEnrollment: needsReEnrollment ?? this.needsReEnrollment,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Employee &&
        other.id == id &&
        other.code == code &&
        other.name == name &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.embeddingCount == embeddingCount &&
        other.needsReEnrollment == needsReEnrollment;
  }

  @override
  int get hashCode => Object.hash(
    id,
    code,
    name,
    isActive,
    createdAt,
    embeddingCount,
    needsReEnrollment,
  );
}

/// Decrypted in-memory facial embedding vector associated with an employee.
@immutable
class EnrolledEmbedding {
  const EnrolledEmbedding({
    required this.id,
    required this.employeeId,
    required this.vector,
    required this.modelId,
    required this.dimension,
    required this.createdAt,
  });

  /// Internal record ID.
  final int id;

  /// Referenced employee ID.
  final int employeeId;

  /// 128-d L2-normalized biometric embedding vector.
  final List<double> vector;

  /// Model identifier under which this vector was generated.
  final String modelId;

  /// Vector dimension.
  final int dimension;

  /// Creation timestamp.
  final DateTime createdAt;
}
