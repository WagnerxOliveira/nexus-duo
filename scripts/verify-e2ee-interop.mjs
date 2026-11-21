#!/usr/bin/env node
/**
 * scripts/verify-e2ee-interop.mjs
 * Cross-platform E2EE Interoperability & Golden Vector Verifier for NEXUS DUO:
 * - Validates packages/contracts/crypto_golden_vectors.json
 * - Performs cross-verification of X25519 Diffie-Hellman, HKDF-SHA256, and AES-256-GCM
 * - Verifies encryption, decryption, authentication tags, and tamper-resistance
 *
 * Exit code 0 on all vectors valid, 1 on error.
 */

import {
  createPrivateKey,
  createPublicKey,
  diffieHellman,
  hkdfSync,
  createCipheriv,
  createDecipheriv,
} from 'node:crypto';
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

// RFC 8410 ASN.1 DER prefixes for X25519 keys
const X25519_PKCS8_PREFIX = Buffer.from('302e020100300506032b656e04220420', 'hex');
const X25519_SPKI_PREFIX = Buffer.from('302a300506032b656e032100', 'hex');

const AUTH_TAG_LENGTH = 16;
const E2EE_INFO = Buffer.from('nexus-duo-e2ee-v1', 'utf8');

function importRawPrivateKey(rawPrivateBytes) {
  const pkcs8Der = Buffer.concat([X25519_PKCS8_PREFIX, rawPrivateBytes]);
  return createPrivateKey({
    key: pkcs8Der,
    format: 'der',
    type: 'pkcs8',
  });
}

function importRawPublicKey(rawPublicBytes) {
  const spkiDer = Buffer.concat([X25519_SPKI_PREFIX, rawPublicBytes]);
  return createPublicKey({
    key: spkiDer,
    format: 'der',
    type: 'spki',
  });
}

function deriveSharedSecret(privateKeyBytes, peerPublicKeyBytes) {
  const privKeyObj = importRawPrivateKey(privateKeyBytes);
  const peerPubObj = importRawPublicKey(peerPublicKeyBytes);
  return diffieHellman({
    privateKey: privKeyObj,
    publicKey: peerPubObj,
  });
}

function deriveSessionKey(sharedSecret, matchId) {
  const salt = Buffer.from(matchId, 'utf8');
  return Buffer.from(hkdfSync('sha256', sharedSecret, salt, E2EE_INFO, 32));
}

function encryptAesGcm({ sessionKey, nonce, aad, plaintext }) {
  const cipher = createCipheriv('aes-256-gcm', sessionKey, nonce, {
    authTagLength: AUTH_TAG_LENGTH,
  });
  cipher.setAAD(aad);
  const cipherText = Buffer.concat([
    cipher.update(Buffer.from(plaintext, 'utf8')),
    cipher.final(),
  ]);
  const authTag = cipher.getAuthTag();
  const serialized = Buffer.concat([cipherText, authTag]);
  return { cipherText, authTag, serialized };
}

function decryptAesGcm({ sessionKey, nonce, aad, serializedPayload }) {
  if (serializedPayload.length < AUTH_TAG_LENGTH) {
    throw new Error('Payload is too short to contain an auth tag');
  }
  const cipherText = serializedPayload.subarray(0, serializedPayload.length - AUTH_TAG_LENGTH);
  const authTag = serializedPayload.subarray(serializedPayload.length - AUTH_TAG_LENGTH);

  const decipher = createDecipheriv('aes-256-gcm', sessionKey, nonce, {
    authTagLength: AUTH_TAG_LENGTH,
  });
  decipher.setAAD(aad);
  decipher.setAuthTag(authTag);
  const decrypted = Buffer.concat([decipher.update(cipherText), decipher.final()]);
  return decrypted.toString('utf8');
}

function main() {
  const args = process.argv.slice(2);
  let vectorsPath = resolve(process.cwd(), 'packages/contracts/crypto_golden_vectors.json');

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--vectors' || args[i] === '-v') {
      vectorsPath = resolve(process.cwd(), args[++i]);
    } else if (args[i] === '--help' || args[i] === '-h') {
      console.log(`
NEXUS DUO — E2EE Interoperability & Golden Vector Verifier

Usage:
  node scripts/verify-e2ee-interop.mjs [options]

Options:
  --vectors, -v <path>  Path to crypto golden vectors JSON (default: packages/contracts/crypto_golden_vectors.json)
  --help, -h            Show this help message
`);
      process.exit(0);
    }
  }

  console.log('='.repeat(70));
  console.log('🔐 NEXUS DUO — End-to-End Encryption (E2EE) Interop & Golden Tests');
  console.log('='.repeat(70));

  if (!existsSync(vectorsPath)) {
    console.error(`Error: Golden vectors file not found at: ${vectorsPath}`);
    process.exit(1);
  }

  const spec = JSON.parse(readFileSync(vectorsPath, 'utf8'));
  console.log(`Spec Version: ${spec.version}`);
  console.log(`Key Exchange: ${spec.algorithm.key_exchange} | KDF: ${spec.algorithm.kdf} | Cipher: ${spec.algorithm.cipher}`);
  console.log(`Vectors count: ${spec.vectors.length}\n`);

  let passedTests = 0;
  let failedTests = 0;

  for (const [index, vec] of spec.vectors.entries()) {
    console.log(`--- [Vector ${index + 1}/${spec.vectors.length}] ${vec.id}: ${vec.description} ---`);

    const senderPriv = Buffer.from(vec.sender_private_key_b64, 'base64');
    const senderPub = Buffer.from(vec.sender_public_key_b64, 'base64');
    const recipientPriv = Buffer.from(vec.recipient_private_key_b64, 'base64');
    const recipientPub = Buffer.from(vec.recipient_public_key_b64, 'base64');
    const nonce = Buffer.from(vec.nonce_b64, 'base64');
    const aad = Buffer.from(vec.aad_utf8, 'utf8');

    // 1. Test X25519 DH Sender -> Recipient
    const sharedSecretSender = deriveSharedSecret(senderPriv, recipientPub);
    const sharedSecretSenderB64 = sharedSecretSender.toString('base64');

    if (sharedSecretSenderB64 !== vec.expected_shared_secret_b64) {
      console.error(`  ❌ Shared secret mismatch (sender):\n     Expected: ${vec.expected_shared_secret_b64}\n     Actual:   ${sharedSecretSenderB64}`);
      failedTests++;
      continue;
    }

    // 2. Test X25519 DH Recipient -> Sender (Symmetry)
    const sharedSecretRecipient = deriveSharedSecret(recipientPriv, senderPub);
    const sharedSecretRecipientB64 = sharedSecretRecipient.toString('base64');

    if (sharedSecretRecipientB64 !== sharedSecretSenderB64) {
      console.error(`  ❌ DH symmetry failure: sender and recipient computed different shared secrets!`);
      failedTests++;
      continue;
    }
    console.log(`  ✅ X25519 Diffie-Hellman key exchange verified (symmetric match)`);

    // 3. Test HKDF session key derivation
    const sessionKey = deriveSessionKey(sharedSecretSender, vec.match_id);
    const sessionKeyB64 = sessionKey.toString('base64');

    if (sessionKeyB64 !== vec.expected_session_key_b64) {
      console.error(`  ❌ Session key mismatch:\n     Expected: ${vec.expected_session_key_b64}\n     Actual:   ${sessionKeyB64}`);
      failedTests++;
      continue;
    }
    console.log(`  ✅ HKDF-SHA256 session key derivation verified`);

    // 4. Test Encryption & Payload Serialization
    const { serialized } = encryptAesGcm({
      sessionKey,
      nonce,
      aad,
      plaintext: vec.plaintext,
    });
    const serializedB64 = serialized.toString('base64');

    if (serializedB64 !== vec.expected_ciphertext_b64) {
      console.error(`  ❌ Ciphertext mismatch:\n     Expected: ${vec.expected_ciphertext_b64}\n     Actual:   ${serializedB64}`);
      failedTests++;
      continue;
    }
    console.log(`  ✅ AES-256-GCM encryption and serialization matches golden vector`);

    // 5. Test Decryption
    const decryptedText = decryptAesGcm({
      sessionKey,
      nonce,
      aad,
      serializedPayload: Buffer.from(vec.expected_ciphertext_b64, 'base64'),
    });

    if (decryptedText !== vec.plaintext) {
      console.error(`  ❌ Decryption mismatch:\n     Expected: ${vec.plaintext}\n     Actual:   ${decryptedText}`);
      failedTests++;
      continue;
    }
    console.log(`  ✅ AES-256-GCM roundtrip decryption verified with 100% fidelity`);

    // 6. Test Tamper Resistance (Security negative test)
    let tamperDetected = false;
    try {
      const tamperedPayload = Buffer.from(vec.expected_ciphertext_b64, 'base64');
      tamperedPayload[0] ^= 0x01; // flip 1 bit
      decryptAesGcm({
        sessionKey,
        nonce,
        aad,
        serializedPayload: tamperedPayload,
      });
    } catch {
      tamperDetected = true;
    }

    if (!tamperDetected) {
      console.error(`  ❌ Security failure: Tampered ciphertext was accepted!`);
      failedTests++;
      continue;
    }
    console.log(`  ✅ Tamper resistance verified (bit-flip rejected with auth error)`);

    passedTests++;
    console.log();
  }

  console.log('='.repeat(70));
  if (failedTests === 0) {
    console.log(`🎉 ALL ${passedTests} GOLDEN VECTORS VERIFIED SUCCESSFULLY (100% Interoperability)`);
    console.log('='.repeat(70));
    process.exit(0);
  } else {
    console.error(`🚨 ${failedTests} VECTOR TEST(S) FAILED`);
    console.log('='.repeat(70));
    process.exit(1);
  }
}

main();
