import 'package:drift/drift.dart';

import '../../../core/crypto/encryption_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/clock.dart';
import '../domain/employee.dart';
import '../domain/employee_repository.dart';

/// Concrete [EmployeeRepository] backed by Drift SQLite and AES-GCM encryption.
class DriftEmployeeRepository implements EmployeeRepository {
  DriftEmployeeRepository({
    required this.db,
    required this.encryptionService,
    this.clock = const SystemClock(),
  });

  final AppDatabase db;
  final EncryptionService encryptionService;
  final Clock clock;

  @override
  Future<List<Employee>> getAllEmployees({bool? activeOnly}) async {
    final SimpleSelectStatement<$EmployeesTable, DbEmployee> query = db.select(
      db.employees,
    );

    if (activeOnly == true) {
      query.where(($EmployeesTable tbl) => tbl.isActive.equals(true));
    }

    final List<DbEmployee> rows = await query.get();
    if (rows.isEmpty) return const <Employee>[];

    final List<DbEmbedding> allEmbeddings = await db
        .select(db.embeddings)
        .get();

    final Map<int, List<DbEmbedding>> empEmbeddings =
        <int, List<DbEmbedding>>{};
    for (final DbEmbedding emb in allEmbeddings) {
      empEmbeddings.putIfAbsent(emb.employeeId, () => <DbEmbedding>[]).add(emb);
    }

    return rows.map((DbEmployee row) {
      final List<DbEmbedding> embs =
          empEmbeddings[row.id] ?? const <DbEmbedding>[];
      final bool needsRe = embs.any(
        (DbEmbedding e) => e.modelId != 'sface' || e.dimension != 128,
      );

      return Employee(
        id: row.id,
        code: row.employeeCode,
        name: row.name,
        isActive: row.isActive,
        createdAt: row.createdAt,
        embeddingCount: embs.length,
        needsReEnrollment: needsRe,
      );
    }).toList();
  }

  @override
  Future<Employee?> getEmployeeById(int id) async {
    final DbEmployee? row = await (db.select(
      db.employees,
    )..where(($EmployeesTable tbl) => tbl.id.equals(id))).getSingleOrNull();

    if (row == null) return null;

    final List<DbEmbedding> embs = await (db.select(
      db.embeddings,
    )..where(($EmbeddingsTable tbl) => tbl.employeeId.equals(id))).get();

    final bool needsRe = embs.any(
      (DbEmbedding e) => e.modelId != 'sface' || e.dimension != 128,
    );

    return Employee(
      id: row.id,
      code: row.employeeCode,
      name: row.name,
      isActive: row.isActive,
      createdAt: row.createdAt,
      embeddingCount: embs.length,
      needsReEnrollment: needsRe,
    );
  }

  @override
  Future<Employee?> getEmployeeByCode(String code) async {
    final DbEmployee? row =
        await (db.select(db.employees)
              ..where(($EmployeesTable tbl) => tbl.employeeCode.equals(code)))
            .getSingleOrNull();

    if (row == null) return null;

    final List<DbEmbedding> embs = await (db.select(
      db.embeddings,
    )..where(($EmbeddingsTable tbl) => tbl.employeeId.equals(row.id))).get();

    final bool needsRe = embs.any(
      (DbEmbedding e) => e.modelId != 'sface' || e.dimension != 128,
    );

    return Employee(
      id: row.id,
      code: row.employeeCode,
      name: row.name,
      isActive: row.isActive,
      createdAt: row.createdAt,
      embeddingCount: embs.length,
      needsReEnrollment: needsRe,
    );
  }

  @override
  Future<bool> isCodeTaken(String code, {int? excludeId}) async {
    final SimpleSelectStatement<$EmployeesTable, DbEmployee> query = db.select(
      db.employees,
    )..where(($EmployeesTable tbl) => tbl.employeeCode.equals(code));

    if (excludeId != null) {
      query.where(($EmployeesTable tbl) => tbl.id.isNotValue(excludeId));
    }

    final DbEmployee? match = await query.getSingleOrNull();
    return match != null;
  }

  @override
  Future<Employee> createEmployee({
    required String code,
    required String name,
    required List<List<double>> embeddings,
    required String modelId,
    required int dimension,
  }) async {
    // Encrypt all embeddings before opening the transaction to avoid
    // holding SQLite connection locks during platform-channel crypto operations.
    final List<EncryptedPayload> payloads = <EncryptedPayload>[];
    for (final List<double> vector in embeddings) {
      final EncryptedPayload p = await encryptionService.encryptEmbedding(
        vector,
      );
      payloads.add(p);
    }

    return db.transaction<Employee>(() async {
      final DateTime now = clock.now();

      final int employeeId = await db
          .into(db.employees)
          .insert(
            EmployeesCompanion.insert(
              employeeCode: code,
              name: name,
              isActive: const Value<bool>(true),
              createdAt: now,
            ),
          );

      for (final EncryptedPayload payload in payloads) {
        await db
            .into(db.embeddings)
            .insert(
              EmbeddingsCompanion.insert(
                employeeId: employeeId,
                ciphertext: payload.ciphertext,
                nonce: payload.nonce,
                mac: payload.mac,
                modelId: modelId,
                dimension: dimension,
                createdAt: now,
              ),
            );
      }

      return Employee(
        id: employeeId,
        code: code,
        name: name,
        isActive: true,
        createdAt: now,
        embeddingCount: embeddings.length,
        needsReEnrollment: false,
      );
    });
  }

  @override
  Future<void> updateEmployee(Employee employee) async {
    await (db.update(
      db.employees,
    )..where(($EmployeesTable tbl) => tbl.id.equals(employee.id))).write(
      EmployeesCompanion(
        employeeCode: Value<String>(employee.code),
        name: Value<String>(employee.name),
        isActive: Value<bool>(employee.isActive),
      ),
    );
  }

  @override
  Future<void> setEmployeeActive(int id, bool isActive) async {
    await (db.update(db.employees)
          ..where(($EmployeesTable tbl) => tbl.id.equals(id)))
        .write(EmployeesCompanion(isActive: Value<bool>(isActive)));
  }

  @override
  Future<void> deleteEmployee(int id) async {
    await db.transaction<void>(() async {
      await (db.delete(
        db.embeddings,
      )..where(($EmbeddingsTable tbl) => tbl.employeeId.equals(id))).go();
      await (db.delete(
        db.employees,
      )..where(($EmployeesTable tbl) => tbl.id.equals(id))).go();
    });
  }

  @override
  Future<void> reEnrollEmployee({
    required int employeeId,
    required List<List<double>> embeddings,
    required String modelId,
    required int dimension,
  }) async {
    final List<EncryptedPayload> payloads = <EncryptedPayload>[];
    for (final List<double> vector in embeddings) {
      final EncryptedPayload p = await encryptionService.encryptEmbedding(
        vector,
      );
      payloads.add(p);
    }

    await db.transaction<void>(() async {
      final DateTime now = clock.now();

      // Clear old embeddings
      await (db.delete(
            db.embeddings,
          )..where(($EmbeddingsTable tbl) => tbl.employeeId.equals(employeeId)))
          .go();

      // Insert new encrypted samples
      for (final EncryptedPayload payload in payloads) {
        await db
            .into(db.embeddings)
            .insert(
              EmbeddingsCompanion.insert(
                employeeId: employeeId,
                ciphertext: payload.ciphertext,
                nonce: payload.nonce,
                mac: payload.mac,
                modelId: modelId,
                dimension: dimension,
                createdAt: now,
              ),
            );
      }
    });
  }

  @override
  Future<List<EnrolledEmbedding>> getActiveEmbeddings({
    required String currentModelId,
    required int currentDimension,
  }) async {
    final List<TypedResult> query = await (db.select(db.embeddings).join([
      innerJoin(
        db.employees,
        db.employees.id.equalsExp(db.embeddings.employeeId),
      ),
    ])..where(db.employees.isActive.equals(true))).get();

    final List<EnrolledEmbedding> results = <EnrolledEmbedding>[];

    for (final TypedResult row in query) {
      final DbEmbedding emb = row.readTable(db.embeddings);

      // Enforce model ID and dimension compatibility
      if (emb.modelId != currentModelId || emb.dimension != currentDimension) {
        continue;
      }

      final List<double> vector = await encryptionService.decryptEmbedding(
        EncryptedPayload(
          ciphertext: emb.ciphertext,
          nonce: emb.nonce,
          mac: emb.mac,
        ),
      );

      results.add(
        EnrolledEmbedding(
          id: emb.id,
          employeeId: emb.employeeId,
          vector: vector,
          modelId: emb.modelId,
          dimension: emb.dimension,
          createdAt: emb.createdAt,
        ),
      );
    }

    return results;
  }

  @override
  Future<int> countEmployees() async {
    final Expression<int> countExp = db.employees.id.count();
    final TypedResult row = await (db.selectOnly(
      db.employees,
    )..addColumns(<Expression<Object>>[countExp])).getSingle();

    return row.read(countExp) ?? 0;
  }
}
