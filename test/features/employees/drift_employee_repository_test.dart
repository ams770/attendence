import 'dart:math' as math;
import 'dart:typed_data';

import 'package:attendence/core/crypto/encryption_service.dart';
import 'package:attendence/core/database/app_database.dart';
import 'package:attendence/core/utils/clock.dart';
import 'package:attendence/core/utils/random_source.dart';
import 'package:attendence/features/employees/data/drift_employee_repository.dart';
import 'package:attendence/features/employees/domain/employee.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _storage = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _storage[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _storage[key] = value;
    } else {
      _storage.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DriftEmployeeRepository & Encrypted SQLite Storage', () {
    late AppDatabase db;
    late _FakeSecureStorage secureStorage;
    late AesGcmEncryptionService crypto;
    late FakeClock clock;
    late DriftEmployeeRepository repository;

    final List<List<double>> sampleEmbeddings = List<List<double>>.generate(
      5,
      (int sampleIdx) => List<double>.generate(
        128,
        (int i) => math.cos((sampleIdx + 1) * i * 0.05),
      ),
    );

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      secureStorage = _FakeSecureStorage();
      crypto = AesGcmEncryptionService(
        secureStorage: secureStorage,
        randomSource: FakeRandomSource(),
      );
      clock = FakeClock(DateTime(2026, 11, 7, 10, 0, 0));
      repository = DriftEmployeeRepository(
        db: db,
        encryptionService: crypto,
        clock: clock,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'creates employee with 5 encrypted embeddings without plaintext storage',
      () async {
        final Employee created = await repository.createEmployee(
          code: 'EMP001',
          name: 'John Doe',
          embeddings: sampleEmbeddings,
          modelId: 'sface',
          dimension: 128,
        );

        expect(created.id, greaterThan(0));
        expect(created.code, 'EMP001');
        expect(created.name, 'John Doe');
        expect(created.isActive, isTrue);
        expect(created.embeddingCount, 5);
        expect(created.needsReEnrollment, isFalse);

        // Verify raw database table rows contain encrypted blobs and no plaintext floats
        final List<DbEmbedding> rawEmbeddings = await db
            .select(db.embeddings)
            .get();
        expect(rawEmbeddings.length, 5);

        for (final DbEmbedding row in rawEmbeddings) {
          expect(row.employeeId, created.id);
          expect(row.modelId, 'sface');
          expect(row.dimension, 128);
          expect(row.ciphertext.length, 512); // 128 float32 = 512 bytes
          expect(row.nonce.length, 12);
          expect(row.mac.length, 16);

          // Verify raw bytes are NOT the original Float32List
          final Float32List rawFloats = Float32List.view(
            row.ciphertext.buffer,
            row.ciphertext.offsetInBytes,
            128,
          );
          expect(rawFloats[0], isNot(closeTo(sampleEmbeddings[0][0], 1e-4)));
        }
      },
    );

    test('retrieves employee by id and by code', () async {
      final Employee created = await repository.createEmployee(
        code: 'EMP100',
        name: 'Alice Smith',
        embeddings: sampleEmbeddings,
        modelId: 'sface',
        dimension: 128,
      );

      final Employee? byId = await repository.getEmployeeById(created.id);
      expect(byId, isNotNull);
      expect(byId!.name, 'Alice Smith');
      expect(byId.code, 'EMP100');

      final Employee? byCode = await repository.getEmployeeByCode('EMP100');
      expect(byCode, isNotNull);
      expect(byCode!.id, created.id);

      final Employee? missing = await repository.getEmployeeByCode(
        'NON_EXISTENT',
      );
      expect(missing, isNull);
    });

    test('isCodeTaken handles new and excluded ids', () async {
      final Employee emp = await repository.createEmployee(
        code: 'UNIQUE1',
        name: 'Bob',
        embeddings: sampleEmbeddings,
        modelId: 'sface',
        dimension: 128,
      );

      expect(await repository.isCodeTaken('UNIQUE1'), isTrue);
      expect(await repository.isCodeTaken('UNIQUE2'), isFalse);
      expect(
        await repository.isCodeTaken('UNIQUE1', excludeId: emp.id),
        isFalse,
      );
    });

    test('getAllEmployees filters active status correctly', () async {
      final Employee emp1 = await repository.createEmployee(
        code: 'ACT01',
        name: 'Active One',
        embeddings: sampleEmbeddings,
        modelId: 'sface',
        dimension: 128,
      );
      final Employee emp2 = await repository.createEmployee(
        code: 'ACT02',
        name: 'Active Two',
        embeddings: sampleEmbeddings,
        modelId: 'sface',
        dimension: 128,
      );

      await repository.setEmployeeActive(emp2.id, false);

      final List<Employee> all = await repository.getAllEmployees();
      expect(all.length, 2);

      final List<Employee> activeOnly = await repository.getAllEmployees(
        activeOnly: true,
      );
      expect(activeOnly.length, 1);
      expect(activeOnly.first.id, emp1.id);
    });

    test('updateEmployee updates code, name, and status', () async {
      final Employee created = await repository.createEmployee(
        code: 'OLD_CODE',
        name: 'Old Name',
        embeddings: sampleEmbeddings,
        modelId: 'sface',
        dimension: 128,
      );

      final Employee updated = created.copyWith(
        code: 'NEW_CODE',
        name: 'New Name',
        isActive: false,
      );
      await repository.updateEmployee(updated);

      final Employee? reloaded = await repository.getEmployeeById(created.id);
      expect(reloaded!.code, 'NEW_CODE');
      expect(reloaded.name, 'New Name');
      expect(reloaded.isActive, isFalse);
    });

    test('deleteEmployee cascades and deletes embeddings', () async {
      final Employee created = await repository.createEmployee(
        code: 'DEL01',
        name: 'To Delete',
        embeddings: sampleEmbeddings,
        modelId: 'sface',
        dimension: 128,
      );

      expect(await repository.countEmployees(), 1);
      expect((await db.select(db.embeddings).get()).length, 5);

      await repository.deleteEmployee(created.id);

      expect(await repository.countEmployees(), 0);
      expect((await db.select(db.embeddings).get()).isEmpty, isTrue);
      expect(await repository.getEmployeeById(created.id), isNull);
    });

    test('reEnrollEmployee replaces old embeddings with new samples', () async {
      final Employee created = await repository.createEmployee(
        code: 'RE_ENROLL',
        name: 'Re-enroll Me',
        embeddings: sampleEmbeddings,
        modelId: 'sface',
        dimension: 128,
      );

      final List<List<double>> newSamples = List<List<double>>.generate(
        5,
        (int i) => List<double>.filled(128, 0.5 + i * 0.1),
      );

      await repository.reEnrollEmployee(
        employeeId: created.id,
        embeddings: newSamples,
        modelId: 'sface',
        dimension: 128,
      );

      final List<EnrolledEmbedding> active = await repository
          .getActiveEmbeddings(currentModelId: 'sface', currentDimension: 128);
      expect(active.length, 5);
      for (int i = 0; i < 5; i++) {
        expect(active[i].vector[0], closeTo(newSamples[i][0], 1e-5));
      }
    });

    test(
      'flags needsReEnrollment and ignores mismatched model ID or dimension',
      () async {
        // Create employee with old model
        await repository.createEmployee(
          code: 'OLD_MODEL',
          name: 'Legacy Model User',
          embeddings: sampleEmbeddings,
          modelId: 'arcface_old',
          dimension: 512,
        );

        // Create employee with current model
        await repository.createEmployee(
          code: 'CURR_MODEL',
          name: 'Current Model User',
          embeddings: sampleEmbeddings,
          modelId: 'sface',
          dimension: 128,
        );

        final List<Employee> employees = await repository.getAllEmployees();
        final Employee legacy = employees.firstWhere(
          (Employee e) => e.code == 'OLD_MODEL',
        );
        final Employee current = employees.firstWhere(
          (Employee e) => e.code == 'CURR_MODEL',
        );

        expect(legacy.needsReEnrollment, isTrue);
        expect(current.needsReEnrollment, isFalse);

        // getActiveEmbeddings must exclude incompatible embeddings
        final List<EnrolledEmbedding> active = await repository
            .getActiveEmbeddings(
              currentModelId: 'sface',
              currentDimension: 128,
            );
        expect(active.length, 5);
        expect(
          active.every((EnrolledEmbedding e) => e.modelId == 'sface'),
          isTrue,
        );
      },
    );
  });
}
