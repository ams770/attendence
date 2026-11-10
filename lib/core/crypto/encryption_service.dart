import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/random_source.dart';

/// Encrypted container for a sensitive biometric embedding payload.
class EncryptedPayload {
  const EncryptedPayload({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
  });

  /// AES-256-GCM ciphertext bytes.
  final Uint8List ciphertext;

  /// 12-byte initialization vector / nonce.
  final Uint8List nonce;

  /// 16-byte authentication tag (MAC).
  final Uint8List mac;
}

/// Abstract interface for encrypting and decrypting biometric vectors.
abstract class EncryptionService {
  /// Encrypts an embedding vector using AES-256-GCM.
  Future<EncryptedPayload> encryptEmbedding(List<double> embedding);

  /// Decrypts an AES-256-GCM encrypted payload back to the embedding vector.
  ///
  /// Throws an exception if the ciphertext or MAC has been tampered with.
  Future<List<double>> decryptEmbedding(EncryptedPayload payload);
}

/// Concrete AES-GCM 256-bit encryption service backed by secure hardware key storage.
class AesGcmEncryptionService implements EncryptionService {
  AesGcmEncryptionService({
    FlutterSecureStorage? secureStorage,
    RandomSource? randomSource,
    this.keyAlias = 'face_biometric_master_key',
  }) : _secureStorage =
           secureStorage ??
           const FlutterSecureStorage(
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock,
             ),
             aOptions: AndroidOptions(),
           ),
       _randomSource = randomSource ?? SecureRandomSource();

  final FlutterSecureStorage _secureStorage;
  final RandomSource _randomSource;
  final String keyAlias;

  final AesGcm _algorithm = AesGcm.with256bits();
  SecretKey? _cachedKey;

  Future<SecretKey> _getOrCreateKey() async {
    if (_cachedKey != null) return _cachedKey!;

    final String? storedKeyBase64 = await _secureStorage.read(key: keyAlias);
    if (storedKeyBase64 != null && storedKeyBase64.isNotEmpty) {
      final Uint8List keyBytes = base64Decode(storedKeyBase64);
      _cachedKey = SecretKey(keyBytes);
      return _cachedKey!;
    }

    // Generate 32 bytes (256 bits) for AES-256
    final Uint8List newKeyBytes = Uint8List.fromList(
      List<int>.generate(32, (_) => _randomSource.nextInt(256)),
    );
    await _secureStorage.write(key: keyAlias, value: base64Encode(newKeyBytes));
    _cachedKey = SecretKey(newKeyBytes);
    return _cachedKey!;
  }

  @override
  Future<EncryptedPayload> encryptEmbedding(List<double> embedding) async {
    final SecretKey key = await _getOrCreateKey();

    // Serialize List<double> as Float32 little-endian bytes (128 floats = 512 bytes)
    final Float32List floatList = Float32List.fromList(embedding);
    final Uint8List plainBytes = floatList.buffer.asUint8List();

    final SecretBox secretBox = await _algorithm.encrypt(
      plainBytes,
      secretKey: key,
    );

    return EncryptedPayload(
      ciphertext: Uint8List.fromList(secretBox.cipherText),
      nonce: Uint8List.fromList(secretBox.nonce),
      mac: Uint8List.fromList(secretBox.mac.bytes),
    );
  }

  @override
  Future<List<double>> decryptEmbedding(EncryptedPayload payload) async {
    final SecretKey key = await _getOrCreateKey();

    final SecretBox secretBox = SecretBox(
      payload.ciphertext,
      nonce: payload.nonce,
      mac: Mac(payload.mac),
    );

    final List<int> plainBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: key,
    );

    final Uint8List byteList = Uint8List.fromList(plainBytes);
    final ByteData byteData = ByteData.sublistView(byteList);
    final int count = byteList.length ~/ 4;
    final List<double> result = List<double>.filled(count, 0.0);

    for (int i = 0; i < count; i++) {
      result[i] = byteData.getFloat32(i * 4, Endian.little);
    }

    return result;
  }
}
