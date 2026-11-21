import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../errors/app_failure.dart';

/// Serialized E2EE payload matching the cross-platform Mobile <-> Web contract.
///
/// `ciphertextB64` stores `Base64(cipherTextBytes || authTag16Bytes)`.
class EncryptedPayload {
  const EncryptedPayload({
    required this.ciphertextB64,
    required this.nonceB64,
    required this.aadUtf8,
  });

  final String ciphertextB64;
  final String nonceB64;
  final String aadUtf8;
}

/// Abstract vault that protects the user's X25519 private key.
/// Private key bytes are never exposed outside the crypto layer.
abstract interface class SecureKeyVault {
  Future<SimpleKeyPairData?> readKeyPair();
  Future<void> saveKeyPair(SimpleKeyPairData keyPair);
  Future<void> clear();
}

/// Pure Dart in-memory vault used for unit tests and Instant Demo Mode.
class InMemorySecureKeyVault implements SecureKeyVault {
  InMemorySecureKeyVault({SimpleKeyPairData? initialKeyPair})
    : _keyPair = initialKeyPair;

  SimpleKeyPairData? _keyPair;

  /// Creates a vault pre-seeded from raw 32-byte X25519 private & public Base64 keys.
  factory InMemorySecureKeyVault.fromBase64({
    required String privateKeyB64,
    required String publicKeyB64,
  }) {
    final privateBytes = base64Decode(privateKeyB64);
    final publicBytes = base64Decode(publicKeyB64);
    return InMemorySecureKeyVault(
      initialKeyPair: SimpleKeyPairData(
        privateBytes,
        publicKey: SimplePublicKey(publicBytes, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      ),
    );
  }

  @override
  Future<SimpleKeyPairData?> readKeyPair() async => _keyPair;

  @override
  Future<void> saveKeyPair(SimpleKeyPairData keyPair) async {
    _keyPair = keyPair;
  }

  @override
  Future<void> clear() async {
    _keyPair = null;
  }
}

/// Polymorphic contract for End-to-End Message Encryption.
abstract interface class IMessageCipher {
  Future<String> getOrCreatePublicKeyB64();

  Future<EncryptedPayload> encrypt({
    required String plaintext,
    required String peerPublicKeyB64,
    required String matchId,
    required String senderId,
    List<int>? nonceOverride,
  });

  Future<String> decrypt({
    required EncryptedPayload payload,
    required String peerPublicKeyB64,
    required String matchId,
    required String senderId,
  });
}

/// Production X25519 + HKDF-SHA256 + AES-256-GCM cipher compatible 1:1 with WebCrypto.
///
/// Binary contract:
/// 1. Key exchange: X25519 (`KeyPairType.x25519`, raw 32-byte public key Base64).
/// 2. Key derivation: HKDF-SHA256 (`ikm = shared_secret(32B)`, `salt = UTF8(matchId)`,
///    `info = UTF8("nexus-duo-e2ee-v1")`, `outputLength = 32`).
/// 3. Cipher: AES-256-GCM (`nonce = 12 bytes`, `aad = UTF8("$matchId:$senderId")`,
///    `tagLength = 128 bits / 16 bytes`).
/// 4. Serialization: `ciphertext_b64 = Base64(cipherText || mac.bytes)`.
class AesGcmE2EECipher implements IMessageCipher {
  AesGcmE2EECipher({
    required SecureKeyVault keyVault,
    X25519? x25519,
    AesGcm? aesGcm,
    Random? random,
  }) : _keyVault = keyVault,
       _x25519 = x25519 ?? X25519(),
       _aesGcm = aesGcm ?? AesGcm.with256bits(),
       _random = random ?? Random.secure();

  static const String kdfInfoLabel = 'nexus-duo-e2ee-v1';
  static const int nonceLengthBytes = 12;
  static const int authTagLengthBytes = 16;
  static const int sessionKeyLengthBytes = 32;

  final SecureKeyVault _keyVault;
  final X25519 _x25519;
  final AesGcm _aesGcm;
  final Random _random;

  Future<SimpleKeyPairData> _getOrCreateKeyPair() async {
    final existing = await _keyVault.readKeyPair();
    if (existing != null) {
      return existing;
    }
    final generated = await _x25519.newKeyPair();
    final extracted = await generated.extract();
    await _keyVault.saveKeyPair(extracted);
    return extracted;
  }

  @override
  Future<String> getOrCreatePublicKeyB64() async {
    final keyPair = await _getOrCreateKeyPair();
    final pubKey = await keyPair.extractPublicKey();
    return base64Encode(pubKey.bytes);
  }

  /// Computes the raw 32-byte X25519 shared secret with [peerPublicKeyB64].
  Future<List<int>> deriveSharedSecretBytes({
    required String peerPublicKeyB64,
  }) async {
    try {
      final myKeyPair = await _getOrCreateKeyPair();
      final peerBytes = base64Decode(peerPublicKeyB64);
      if (peerBytes.length != 32) {
        throw const CryptoFailure(
          'Chave pública X25519 do destinatário inválida (esperado 32 bytes).',
          code: 'INVALID_PEER_PUBKEY',
        );
      }
      final peerPublicKey = SimplePublicKey(
        peerBytes,
        type: KeyPairType.x25519,
      );
      final sharedSecret = await _x25519.sharedSecretKey(
        keyPair: myKeyPair,
        remotePublicKey: peerPublicKey,
      );
      return await sharedSecret.extractBytes();
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw CryptoFailure(
        'Falha ao derivar segredo compartilhado X25519: $error',
        code: 'X25519_DERIVE_FAILED',
      );
    }
  }

  /// Derives the 32-byte AES-256 session key via HKDF-SHA256 for [matchId].
  Future<SecretKey> deriveSessionKey({
    required String peerPublicKeyB64,
    required String matchId,
  }) async {
    try {
      final sharedBytes = await deriveSharedSecretBytes(
        peerPublicKeyB64: peerPublicKeyB64,
      );
      final hkdf = Hkdf(
        hmac: Hmac.sha256(),
        outputLength: sessionKeyLengthBytes,
      );
      return await hkdf.deriveKey(
        secretKey: SecretKey(sharedBytes),
        nonce: utf8.encode(matchId),
        info: utf8.encode(kdfInfoLabel),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw CryptoFailure(
        'Falha na derivação HKDF-SHA256: $error',
        code: 'HKDF_FAILED',
      );
    }
  }

  /// Convenience helper exposing raw session key bytes for Golden Vector verification.
  Future<List<int>> deriveSessionKeyBytes({
    required String peerPublicKeyB64,
    required String matchId,
  }) async {
    final key = await deriveSessionKey(
      peerPublicKeyB64: peerPublicKeyB64,
      matchId: matchId,
    );
    return key.extractBytes();
  }

  @override
  Future<EncryptedPayload> encrypt({
    required String plaintext,
    required String peerPublicKeyB64,
    required String matchId,
    required String senderId,
    List<int>? nonceOverride,
  }) async {
    try {
      final nonce =
          nonceOverride ??
          List<int>.generate(nonceLengthBytes, (_) => _random.nextInt(256));
      if (nonce.length != nonceLengthBytes) {
        throw const CryptoFailure(
          'Nonce AES-256-GCM deve conter exatamente 12 bytes.',
          code: 'INVALID_NONCE_LENGTH',
        );
      }

      final sessionKey = await deriveSessionKey(
        peerPublicKeyB64: peerPublicKeyB64,
        matchId: matchId,
      );
      final aadString = '$matchId:$senderId';
      final secretBox = await _aesGcm.encrypt(
        utf8.encode(plaintext),
        secretKey: sessionKey,
        nonce: nonce,
        aad: utf8.encode(aadString),
      );

      final combined = <int>[...secretBox.cipherText, ...secretBox.mac.bytes];

      return EncryptedPayload(
        ciphertextB64: base64Encode(combined),
        nonceB64: base64Encode(nonce),
        aadUtf8: aadString,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw CryptoFailure(
        'Falha ao cifrar mensagem E2EE: $error',
        code: 'ENCRYPT_FAILED',
      );
    }
  }

  @override
  Future<String> decrypt({
    required EncryptedPayload payload,
    required String peerPublicKeyB64,
    required String matchId,
    required String senderId,
  }) async {
    try {
      final combined = base64Decode(payload.ciphertextB64);
      final nonce = base64Decode(payload.nonceB64);
      if (nonce.length != nonceLengthBytes) {
        throw const CryptoFailure(
          'Nonce inválido para AES-256-GCM.',
          code: 'INVALID_NONCE_LENGTH',
        );
      }
      if (combined.length < authTagLengthBytes) {
        throw const CryptoFailure(
          'Ciphertext corrompido: tamanho menor que o auth tag de 16 bytes.',
          code: 'INVALID_CIPHERTEXT',
        );
      }

      final splitIndex = combined.length - authTagLengthBytes;
      final cipherText = combined.sublist(0, splitIndex);
      final mac = Mac(combined.sublist(splitIndex));

      final sessionKey = await deriveSessionKey(
        peerPublicKeyB64: peerPublicKeyB64,
        matchId: matchId,
      );
      final aadString = '$matchId:$senderId';
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
      final clearBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: sessionKey,
        aad: utf8.encode(aadString),
      );
      return utf8.decode(clearBytes);
    } on AppFailure {
      rethrow;
    } on SecretBoxAuthenticationError {
      throw const CryptoFailure(
        'Falha na verificação de integridade AES-GCM (chave, AAD ou payload adulterado).',
        code: 'MAC_VERIFICATION_FAILED',
      );
    } catch (error) {
      throw CryptoFailure(
        'Falha ao decifrar mensagem E2EE: $error',
        code: 'DECRYPT_FAILED',
      );
    }
  }
}
