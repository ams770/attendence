import '../../../core/utils/clock.dart';
import '../domain/employee.dart';
import '../domain/employee_repository.dart';

/// Test double implementing [EmployeeRepository] entirely in memory.
class FakeEmployeeRepository implements EmployeeRepository {
  FakeEmployeeRepository({this.clock = const SystemClock()});

  final Clock clock;
  final List<Employee> _employees = <Employee>[];
  final List<EnrolledEmbedding> _embeddings = <EnrolledEmbedding>[];
  int _nextEmployeeId = 1;
  int _nextEmbeddingId = 1;

  @override
  Future<List<Employee>> getAllEmployees({bool? activeOnly}) async {
    List<Employee> list = List<Employee>.from(_employees);
    if (activeOnly == true) {
      list = list.where((Employee e) => e.isActive).toList();
    }
    return list;
  }

  @override
  Future<Employee?> getEmployeeById(int id) async {
    final int idx = _employees.indexWhere((Employee e) => e.id == id);
    if (idx < 0) return null;
    return _employees[idx];
  }

  @override
  Future<Employee?> getEmployeeByCode(String code) async {
    final int idx = _employees.indexWhere((Employee e) => e.code == code);
    if (idx < 0) return null;
    return _employees[idx];
  }

  @override
  Future<bool> isCodeTaken(String code, {int? excludeId}) async {
    return _employees.any(
      (Employee e) =>
          e.code == code && (excludeId == null || e.id != excludeId),
    );
  }

  @override
  Future<Employee> createEmployee({
    required String code,
    required String name,
    required List<List<double>> embeddings,
    required String modelId,
    required int dimension,
  }) async {
    final DateTime now = clock.now();
    final int empId = _nextEmployeeId++;

    for (final List<double> vec in embeddings) {
      _embeddings.add(
        EnrolledEmbedding(
          id: _nextEmbeddingId++,
          employeeId: empId,
          vector: List<double>.unmodifiable(vec),
          modelId: modelId,
          dimension: dimension,
          createdAt: now,
        ),
      );
    }

    final Employee emp = Employee(
      id: empId,
      code: code,
      name: name,
      isActive: true,
      createdAt: now,
      embeddingCount: embeddings.length,
      needsReEnrollment: false,
    );

    _employees.add(emp);
    return emp;
  }

  @override
  Future<void> updateEmployee(Employee employee) async {
    final int idx = _employees.indexWhere((Employee e) => e.id == employee.id);
    if (idx >= 0) {
      _employees[idx] = employee;
    }
  }

  @override
  Future<void> setEmployeeActive(int id, bool isActive) async {
    final int idx = _employees.indexWhere((Employee e) => e.id == id);
    if (idx >= 0) {
      _employees[idx] = _employees[idx].copyWith(isActive: isActive);
    }
  }

  @override
  Future<void> deleteEmployee(int id) async {
    _employees.removeWhere((Employee e) => e.id == id);
    _embeddings.removeWhere((EnrolledEmbedding e) => e.employeeId == id);
  }

  @override
  Future<void> reEnrollEmployee({
    required int employeeId,
    required List<List<double>> embeddings,
    required String modelId,
    required int dimension,
  }) async {
    _embeddings.removeWhere(
      (EnrolledEmbedding e) => e.employeeId == employeeId,
    );
    final DateTime now = clock.now();

    for (final List<double> vec in embeddings) {
      _embeddings.add(
        EnrolledEmbedding(
          id: _nextEmbeddingId++,
          employeeId: employeeId,
          vector: List<double>.unmodifiable(vec),
          modelId: modelId,
          dimension: dimension,
          createdAt: now,
        ),
      );
    }

    final int idx = _employees.indexWhere((Employee e) => e.id == employeeId);
    if (idx >= 0) {
      _employees[idx] = _employees[idx].copyWith(
        embeddingCount: embeddings.length,
        needsReEnrollment: false,
      );
    }
  }

  @override
  Future<List<EnrolledEmbedding>> getActiveEmbeddings({
    required String currentModelId,
    required int currentDimension,
  }) async {
    final Set<int> activeEmpIds = _employees
        .where((Employee e) => e.isActive)
        .map((Employee e) => e.id)
        .toSet();

    return _embeddings.where((EnrolledEmbedding e) {
      return activeEmpIds.contains(e.employeeId) &&
          e.modelId == currentModelId &&
          e.dimension == currentDimension;
    }).toList();
  }

  @override
  Future<int> countEmployees() async => _employees.length;
}
