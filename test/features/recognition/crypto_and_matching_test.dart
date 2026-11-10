import 'dart:math' as math;
import 'dart:typed_data';

import 'package:attendence/core/config/app_config.dart';
import 'package:attendence/core/crypto/encryption_service.dart';
import 'package:attendence/core/utils/clock.dart';
import 'package:attendence/core/utils/math_utils.dart';
import 'package:attendence/core/utils/random_source.dart';
import 'package:attendence/features/employees/data/fake_employee_repository.dart';
import 'package:attendence/features/recognition/domain/face_matcher.dart';
import 'package:attendence/features/recognition/domain/match_result.dart';
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

  group('AES-256-GCM Biometric Encryption', () {
    late _FakeSecureStorage fakeStorage;
    late RandomSource random;
    late AesGcmEncryptionService crypto;

    setUp(() {
      fakeStorage = _FakeSecureStorage();
      random = FakeRandomSource(sequence: <double>[0.1, 0.2, 0.3, 0.4]);
      crypto = AesGcmEncryptionService(
        secureStorage: fakeStorage,
        randomSource: random,
      );
    });

    test(
      'encrypts and decrypts 128-d embedding with exact float fidelity',
      () async {
        final List<double> original = List<double>.generate(
          128,
          (int i) => math.sin(i * 0.1),
        );

        final EncryptedPayload payload = await crypto.encryptEmbedding(
          original,
        );

        expect(payload.ciphertext.length, greaterThan(0));
        expect(payload.nonce.length, 12);
        expect(payload.mac.length, 16);

        final List<double> decrypted = await crypto.decryptEmbedding(payload);
        expect(decrypted.length, 128);

        for (int i = 0; i < 128; i++) {
          expect(decrypted[i], closeTo(original[i], 1e-6));
        }
      },
    );

    test('tamper detection: modifying ciphertext throws exception', () async {
      final List<double> original = List<double>.filled(128, 0.5);
      final EncryptedPayload payload = await crypto.encryptEmbedding(original);

      final Uint8List tamperedCiphertext = Uint8List.fromList(
        payload.ciphertext,
      );
      tamperedCiphertext[0] ^= 0xFF; // Flip bits

      final EncryptedPayload tamperedPayload = EncryptedPayload(
        ciphertext: tamperedCiphertext,
        nonce: payload.nonce,
        mac: payload.mac,
      );

      expect(
        () async => await crypto.decryptEmbedding(tamperedPayload),
        throwsA(anything),
      );
    });

    test(
      'tamper detection: modifying MAC authentication tag throws exception',
      () async {
        final List<double> original = List<double>.filled(128, 0.5);
        final EncryptedPayload payload = await crypto.encryptEmbedding(
          original,
        );

        final Uint8List tamperedMac = Uint8List.fromList(payload.mac);
        tamperedMac[0] ^= 0xFF;

        final EncryptedPayload tamperedPayload = EncryptedPayload(
          ciphertext: payload.ciphertext,
          nonce: payload.nonce,
          mac: tamperedMac,
        );

        expect(
          () async => await crypto.decryptEmbedding(tamperedPayload),
          throwsA(anything),
        );
      },
    );
  });

  group('FaceMatcher 1:N Identification', () {
    late FakeEmployeeRepository repo;
    late FaceMatcher matcher;
    late FakeClock clock;
    const AppConfig config = AppConfig(
      recognitionThreshold: 0.363,
      recognitionMargin: 0.10,
    );

    setUp(() {
      clock = FakeClock(DateTime(2026, 1, 1, 12, 0));
      repo = FakeEmployeeRepository(clock: clock);
      matcher = FaceMatcher(repository: repo, config: config, clock: clock);
    });

    test(
      'returns MatchResultNoEnrolledEmployees when database has no employees',
      () async {
        final List<double> query = MathUtils.l2Normalize(
          List<double>.filled(128, 1.0),
        );
        final MatchResult result = await matcher.match(query);

        expect(result, isA<MatchResultNoEnrolledEmployees>());
      },
    );

    test(
      'returns MatchResultNoMatch when best score is strictly below threshold',
      () async {
        // Enroll Alice with vector pointing along dim 0
        final List<double> aliceVec = List<double>.filled(128, 0.0);
        aliceVec[0] = 1.0;

        await repo.createEmployee(
          code: 'EMP-1',
          name: 'Alice',
          embeddings: <List<double>>[aliceVec],
          modelId: 'sface',
          dimension: 128,
        );

        // Query vector orthogonal to Alice (dim 1 = 1.0), cosine = 0.0 < 0.363
        final List<double> query = List<double>.filled(128, 0.0);
        query[1] = 1.0;

        final MatchResult result = await matcher.match(query);
        expect(result, isA<MatchResultNoMatch>());

        final MatchResultNoMatch noMatch = result as MatchResultNoMatch;
        expect(noMatch.bestScore, closeTo(0.0, 1e-4));
        expect(noMatch.bestEmployee?.name, 'Alice');
      },
    );

    test(
      'returns MatchResultMatched when single employee matches above threshold',
      () async {
        final List<double> aliceVec = MathUtils.l2Normalize(
          List<double>.filled(128, 1.0),
        );

        await repo.createEmployee(
          code: 'EMP-1',
          name: 'Alice',
          embeddings: <List<double>>[aliceVec],
          modelId: 'sface',
          dimension: 128,
        );

        final MatchResult result = await matcher.match(aliceVec);
        expect(result, isA<MatchResultMatched>());

        final MatchResultMatched matched = result as MatchResultMatched;
        expect(matched.employee.name, 'Alice');
        expect(matched.rawScore, closeTo(1.0, 1e-4));
        expect(matched.displayPercent, greaterThan(95.0));
      },
    );

    test('returns MatchResultAmbiguous when top two candidates differ by less than margin', () async {
      // Alice vector
      final List<double> aliceVec = List<double>.filled(128, 0.0);
      aliceVec[0] = 1.0;

      // Bob vector slightly tilted from Alice (cosine ~ 0.95)
      final List<double> bobVec = MathUtils.l2Normalize(<double>[
        1.0,
        0.05,
        ...List<double>.filled(126, 0.0),
      ]);

      await repo.createEmployee(
        code: 'EMP-1',
        name: 'Alice',
        embeddings: <List<double>>[aliceVec],
        modelId: 'sface',
        dimension: 128,
      );

      await repo.createEmployee(
        code: 'EMP-2',
        name: 'Bob',
        embeddings: <List<double>>[bobVec],
        modelId: 'sface',
        dimension: 128,
      );

      // Query identical to Alice -> Alice cosine = 1.0, Bob cosine = ~0.998
      // Margin = 1.0 - 0.998 = 0.002 < 0.10 margin threshold
      final MatchResult result = await matcher.match(aliceVec);
      expect(result, isA<MatchResultAmbiguous>());

      final MatchResultAmbiguous amb = result as MatchResultAmbiguous;
      expect(amb.bestEmployee.name, 'Alice');
      expect(amb.secondEmployee.name, 'Bob');
      expect(amb.margin, lessThan(0.10));
    });

    test('returns MatchResultMatched when top candidate exceeds threshold and second candidate by margin', () async {
      final List<double> aliceVec = List<double>.filled(128, 0.0);
      aliceVec[0] = 1.0;

      final List<double> bobVec = List<double>.filled(128, 0.0);
      bobVec[1] = 1.0;

      await repo.createEmployee(
        code: 'EMP-1',
        name: 'Alice',
        embeddings: <List<double>>[aliceVec],
        modelId: 'sface',
        dimension: 128,
      );

      await repo.createEmployee(
        code: 'EMP-2',
        name: 'Bob',
        embeddings: <List<double>>[bobVec],
        modelId: 'sface',
        dimension: 128,
      );

      final MatchResult result = await matcher.match(aliceVec);
      expect(result, isA<MatchResultMatched>());

      final MatchResultMatched matched = result as MatchResultMatched;
      expect(matched.employee.name, 'Alice');
      expect(matched.rawScore, closeTo(1.0, 1e-4));
      expect(matched.margin, closeTo(1.0, 1e-4));
    });

    test(
      'calibrated display percentage behaves monotonically around threshold',
      () {
        const double threshold = 0.363;
        final double atThreshold = FaceMatcher.calculateDisplayPercent(
          threshold,
          threshold,
        );
        expect(atThreshold, closeTo(50.0, 0.5));

        final double high = FaceMatcher.calculateDisplayPercent(
          0.60,
          threshold,
        );
        expect(high, greaterThan(95.0));

        final double low = FaceMatcher.calculateDisplayPercent(0.10, threshold);
        expect(low, lessThan(5.0));
      },
    );
  });
}
