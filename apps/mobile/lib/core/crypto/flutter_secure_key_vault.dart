import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'e2ee_cipher.dart';

/// Hardware-backed key vault using Android Keystore / iOS Keychain via
/// `flutter_secure_storage`.
class FlutterSecureKeyVault implements SecureKeyVault {
  FlutterSecureKeyVault({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const String _privateKeyStorageKey = 'nexus_duo_e2ee_x25519_priv_b64';
  static const String _publicKeyStorageKey = 'nexus_duo_e2ee_x25519_pub_b64';

  final FlutterSecureStorage _storage;

  @override
  Future<SimpleKeyPairData?> readKeyPair() async {
    final privB64 = await _storage.read(key: _privateKeyStorageKey);
    final pubB64 = await _storage.read(key: _publicKeyStorageKey);
    if (privB64 == null || pubB64 == null) {
      return null;
    }
    return SimpleKeyPairData(
      base64Decode(privB64),
      publicKey: SimplePublicKey(
        base64Decode(pubB64),
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );
  }

  @override
  Future<void> saveKeyPair(SimpleKeyPairData keyPair) async {
    final privBytes = await keyPair.extractPrivateKeyBytes();
    final pubKey = await keyPair.extractPublicKey();
    await _storage.write(
      key: _privateKeyStorageKey,
      value: base64Encode(privBytes),
    );
    await _storage.write(
      key: _publicKeyStorageKey,
      value: base64Encode(pubKey.bytes),
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _privateKeyStorageKey);
    await _storage.delete(key: _publicKeyStorageKey);
  }
}
