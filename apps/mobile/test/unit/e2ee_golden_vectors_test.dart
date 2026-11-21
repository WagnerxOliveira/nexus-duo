import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_duo/core/crypto/e2ee_cipher.dart';
import 'package:nexus_duo/core/errors/app_failure.dart';

void main() {
  group('E2EE Golden Vectors (X25519 + HKDF-SHA256 + AES-256-GCM)', () {
    late Map<String, dynamic> contract;
    late List<Map<String, dynamic>> vectors;

    setUpAll(() {
      final file = File('../../packages/contracts/crypto_golden_vectors.json');
      expect(
        file.existsSync(),
        isTrue,
        reason:
            'Shared contract packages/contracts/crypto_golden_vectors.json must exist',
      );
      contract = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      vectors = (contract['vectors'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(vectors.length, greaterThanOrEqualTo(3));
    });

    test(
      'matches every shared secret, session key, ciphertext, and plaintext',
      () async {
        for (final vector in vectors) {
          final id = vector['id'] as String;
          final matchId = vector['match_id'] as String;
          final senderId = vector['sender_id'] as String;
          final senderPriv = vector['sender_private_key_b64'] as String;
          final senderPub = vector['sender_public_key_b64'] as String;
          final recipientPriv = vector['recipient_private_key_b64'] as String;
          final recipientPub = vector['recipient_public_key_b64'] as String;
          final nonceB64 = vector['nonce_b64'] as String;
          final plaintext = vector['plaintext'] as String;
          final expectedShared = vector['expected_shared_secret_b64'] as String;
          final expectedSession = vector['expected_session_key_b64'] as String;
          final expectedCiphertext =
              vector['expected_ciphertext_b64'] as String;

          final senderCipher = AesGcmE2EECipher(
            keyVault: InMemorySecureKeyVault.fromBase64(
              privateKeyB64: senderPriv,
              publicKeyB64: senderPub,
            ),
          );
          final recipientCipher = AesGcmE2EECipher(
            keyVault: InMemorySecureKeyVault.fromBase64(
              privateKeyB64: recipientPriv,
              publicKeyB64: recipientPub,
            ),
          );

          // 1. Shared secret (both sides must be identical)
          final senderShared = await senderCipher.deriveSharedSecretBytes(
            peerPublicKeyB64: recipientPub,
          );
          final recipientShared = await recipientCipher.deriveSharedSecretBytes(
            peerPublicKeyB64: senderPub,
          );
          expect(
            base64Encode(senderShared),
            equals(expectedShared),
            reason: '$id: sender shared secret mismatch',
          );
          expect(
            base64Encode(recipientShared),
            equals(expectedShared),
            reason: '$id: recipient shared secret mismatch',
          );

          // 2. Session key via HKDF-SHA256
          final sessionBytes = await senderCipher.deriveSessionKeyBytes(
            peerPublicKeyB64: recipientPub,
            matchId: matchId,
          );
          expect(
            base64Encode(sessionBytes),
            equals(expectedSession),
            reason: '$id: HKDF session key mismatch',
          );

          // 3. Deterministic encryption matching expected_ciphertext_b64 byte-for-byte
          final encrypted = await senderCipher.encrypt(
            plaintext: plaintext,
            peerPublicKeyB64: recipientPub,
            matchId: matchId,
            senderId: senderId,
            nonceOverride: base64Decode(nonceB64),
          );
          expect(
            encrypted.ciphertextB64,
            equals(expectedCiphertext),
            reason: '$id: ciphertext||mac serialization mismatch',
          );
          expect(encrypted.aadUtf8, equals('$matchId:$senderId'));

          // 4. Recipient decrypts expected ciphertext back to exact plaintext
          final decrypted = await recipientCipher.decrypt(
            payload: EncryptedPayload(
              ciphertextB64: expectedCiphertext,
              nonceB64: nonceB64,
              aadUtf8: '$matchId:$senderId',
            ),
            peerPublicKeyB64: senderPub,
            matchId: matchId,
            senderId: senderId,
          );
          expect(
            decrypted,
            equals(plaintext),
            reason: '$id: decrypted plaintext mismatch',
          );
        }
      },
    );

    test(
      'rejects AAD forgery and tampered ciphertext with CryptoFailure',
      () async {
        final v = vectors.first;
        final recipientCipher = AesGcmE2EECipher(
          keyVault: InMemorySecureKeyVault.fromBase64(
            privateKeyB64: v['recipient_private_key_b64'] as String,
            publicKeyB64: v['recipient_public_key_b64'] as String,
          ),
        );

        // Tampered senderId in AAD
        await expectLater(
          () => recipientCipher.decrypt(
            payload: EncryptedPayload(
              ciphertextB64: v['expected_ciphertext_b64'] as String,
              nonceB64: v['nonce_b64'] as String,
              aadUtf8: '${v['match_id']}:forged-sender',
            ),
            peerPublicKeyB64: v['sender_public_key_b64'] as String,
            matchId: v['match_id'] as String,
            senderId: 'forged-sender',
          ),
          throwsA(isA<CryptoFailure>()),
        );

        // Bit-flipped ciphertext
        final raw = base64Decode(v['expected_ciphertext_b64'] as String);
        raw[0] = raw[0] ^ 0xFF;
        await expectLater(
          () => recipientCipher.decrypt(
            payload: EncryptedPayload(
              ciphertextB64: base64Encode(raw),
              nonceB64: v['nonce_b64'] as String,
              aadUtf8: v['aad_utf8'] as String,
            ),
            peerPublicKeyB64: v['sender_public_key_b64'] as String,
            matchId: v['match_id'] as String,
            senderId: v['sender_id'] as String,
          ),
          throwsA(isA<CryptoFailure>()),
        );
      },
    );
  });
}
