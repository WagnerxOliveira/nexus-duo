import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';
import {
  MemoryKeyVault,
  WebCryptoE2EECipher,
  base64ToBytes,
  bytesToBase64,
} from '@/core/crypto/webCryptoCipher';

interface GoldenVector {
  id: string;
  description: string;
  match_id: string;
  sender_id: string;
  sender_private_key_b64: string;
  sender_public_key_b64: string;
  recipient_private_key_b64: string;
  recipient_public_key_b64: string;
  nonce_b64: string;
  aad_utf8: string;
  plaintext: string;
  expected_shared_secret_b64: string;
  expected_session_key_b64: string;
  expected_ciphertext_b64: string;
}

interface GoldenVectorFile {
  version: string;
  vectors: GoldenVector[];
}

const goldenVectorsPath = resolve(
  __dirname,
  '../../../../packages/contracts/crypto_golden_vectors.json',
);
const goldenData = JSON.parse(
  readFileSync(goldenVectorsPath, 'utf-8'),
) as GoldenVectorFile;

describe('WebCryptoE2EECipher — Cross-Platform Golden Vectors (X25519 + HKDF-SHA256 + AES-256-GCM)', () => {
  const cipher = new WebCryptoE2EECipher();

  it('loads all shared golden vectors from packages/contracts/crypto_golden_vectors.json', () => {
    expect(goldenData.version).toBe('1.0.0');
    expect(goldenData.vectors.length).toBeGreaterThanOrEqual(3);
  });

  for (const vector of goldenData.vectors) {
    it(`matches 100% binary compatibility for ${vector.id}`, async () => {
      // 1. Public key derivation from raw 32-byte private keys
      expect(cipher.derivePublicKey(vector.sender_private_key_b64)).toBe(
        vector.sender_public_key_b64,
      );
      expect(cipher.derivePublicKey(vector.recipient_private_key_b64)).toBe(
        vector.recipient_public_key_b64,
      );

      // 2. X25519 Shared Secret (symmetric for both sides)
      const senderShared = cipher.deriveSharedSecret(
        vector.sender_private_key_b64,
        vector.recipient_public_key_b64,
      );
      const recipientShared = cipher.deriveSharedSecret(
        vector.recipient_private_key_b64,
        vector.sender_public_key_b64,
      );
      expect(bytesToBase64(senderShared)).toBe(vector.expected_shared_secret_b64);
      expect(bytesToBase64(recipientShared)).toBe(vector.expected_shared_secret_b64);

      // 3. HKDF-SHA256 Session Key derivation
      const sessionKey = await cipher.deriveSessionKeyBytes(
        senderShared,
        vector.match_id,
      );
      expect(bytesToBase64(sessionKey)).toBe(vector.expected_session_key_b64);

      // 4. Deterministic Encryption matching Base64(cipherText || authTag16)
      const encrypted = await cipher.encrypt({
        plaintext: vector.plaintext,
        myPrivateKeyB64: vector.sender_private_key_b64,
        peerPublicKeyB64: vector.recipient_public_key_b64,
        matchId: vector.match_id,
        senderId: vector.sender_id,
        deterministicNonceB64: vector.nonce_b64,
      });

      expect(encrypted.aadUtf8).toBe(vector.aad_utf8);
      expect(encrypted.nonceB64).toBe(vector.nonce_b64);
      expect(encrypted.ciphertextB64).toBe(vector.expected_ciphertext_b64);

      // 5. Decryption on recipient side
      const decrypted = await cipher.decrypt({
        ciphertextB64: vector.expected_ciphertext_b64,
        nonceB64: vector.nonce_b64,
        myPrivateKeyB64: vector.recipient_private_key_b64,
        peerPublicKeyB64: vector.sender_public_key_b64,
        matchId: vector.match_id,
        senderId: vector.sender_id,
      });

      expect(decrypted).toBe(vector.plaintext);
    });
  }

  it('rejects tampered ciphertext and mismatched AAD (anti-redirection)', async () => {
    const vector = goldenData.vectors[0]!;

    // Flip 1 bit in ciphertext
    const tampered = base64ToBytes(vector.expected_ciphertext_b64);
    tampered[0] = (tampered[0] ?? 0) ^ 0x01;

    await expect(
      cipher.decrypt({
        ciphertextB64: bytesToBase64(tampered),
        nonceB64: vector.nonce_b64,
        myPrivateKeyB64: vector.recipient_private_key_b64,
        peerPublicKeyB64: vector.sender_public_key_b64,
        matchId: vector.match_id,
        senderId: vector.sender_id,
      }),
    ).rejects.toThrow();

    // Wrong senderId in AAD
    await expect(
      cipher.decrypt({
        ciphertextB64: vector.expected_ciphertext_b64,
        nonceB64: vector.nonce_b64,
        myPrivateKeyB64: vector.recipient_private_key_b64,
        peerPublicKeyB64: vector.sender_public_key_b64,
        matchId: vector.match_id,
        senderId: '99999999-9999-4999-8999-999999999999',
      }),
    ).rejects.toThrow();
  });

  it('generates fresh random CSPRNG nonces and round-trips with MemoryKeyVault', async () => {
    const vault = new MemoryKeyVault(cipher);
    const alice = await vault.getOrCreateKeyPair('alice');
    const bob = await vault.getOrCreateKeyPair('bob');

    const msg1 = await cipher.encrypt({
      plaintext: 'Partida às 21h confirmada!',
      myPrivateKeyB64: alice.privateKeyB64,
      peerPublicKeyB64: bob.publicKeyB64,
      matchId: 'match-random-1',
      senderId: 'alice',
    });
    const msg2 = await cipher.encrypt({
      plaintext: 'Partida às 21h confirmada!',
      myPrivateKeyB64: alice.privateKeyB64,
      peerPublicKeyB64: bob.publicKeyB64,
      matchId: 'match-random-1',
      senderId: 'alice',
    });

    // Different CSPRNG nonces produce distinct ciphertexts for identical plaintexts
    expect(msg1.nonceB64).not.toBe(msg2.nonceB64);
    expect(msg1.ciphertextB64).not.toBe(msg2.ciphertextB64);

    const decoded = await cipher.decrypt({
      ciphertextB64: msg1.ciphertextB64,
      nonceB64: msg1.nonceB64,
      myPrivateKeyB64: bob.privateKeyB64,
      peerPublicKeyB64: alice.publicKeyB64,
      matchId: 'match-random-1',
      senderId: 'alice',
    });
    expect(decoded).toBe('Partida às 21h confirmada!');
  });
});
