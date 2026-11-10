import 'employee.dart';

/// Abstract repository contract for employee profiles and encrypted biometric embeddings.
abstract class EmployeeRepository {
  /// Retrieves all employees, optionally filtering by active status.
  Future<List<Employee>> getAllEmployees({bool? activeOnly});

  /// Retrieves an employee by their database ID.
  Future<Employee?> getEmployeeById(int id);

  /// Retrieves an employee by their unique employee code.
  Future<Employee?> getEmployeeByCode(String code);

  /// Checks if an employee code already exists in the system.
  Future<bool> isCodeTaken(String code, {int? excludeId});

  /// Enrolls a new employee along with their encrypted biometric embeddings.
  ///
  /// Returns the newly created [Employee] record.
  Future<Employee> createEmployee({
    required String code,
    required String name,
    required List<List<double>> embeddings,
    required String modelId,
    required int dimension,
  });

  /// Updates editable employee profile details (code, name, isActive).
  Future<void> updateEmployee(Employee employee);

  /// Deactivates or activates an employee profile.
  Future<void> setEmployeeActive(int id, bool isActive);

  /// Deletes an employee and removes all associated encrypted embeddings.
  Future<void> deleteEmployee(int id);

  /// Replaces all existing embeddings for an employee with fresh samples.
  Future<void> reEnrollEmployee({
    required int employeeId,
    required List<List<double>> embeddings,
    required String modelId,
    required int dimension,
  });

  /// Retrieves decrypted embeddings for all active employees matching the current model and dimension.
  ///
  /// Stored embeddings with mismatched model IDs or dimensions are omitted, and those employees
  /// are flagged as needing re-enrollment.
  Future<List<EnrolledEmbedding>> getActiveEmbeddings({
    required String currentModelId,
    required int currentDimension,
  });

  /// Returns the total count of registered employees.
  Future<int> countEmployees();
}
