#!/usr/bin/env node
import {
  createHash,
  createPrivateKey,
  createPublicKey,
  diffieHellman,
  hkdfSync,
  createCipheriv,
  createDecipheriv,
} from 'node:crypto';
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// RFC 8410 ASN.1 DER prefixes for X25519 keys
const X25519_PKCS8_PREFIX = Buffer.from('302e020100300506032b656e04220420', 'hex');
const X25519_SPKI_PREFIX = Buffer.from('302a300506032b656e032100', 'hex');

const E2EE_INFO = Buffer.from('nexus-duo-e2ee-v1', 'utf8');
const AUTH_TAG_LENGTH = 16;

function deterministicPrivateKeyBytes(label) {
  const digest = createHash('sha256').update(label, 'utf8').digest();
  const key = Buffer.from(digest);
  // RFC 7748 clamping
  key[0] &= 0xf8;
  key[31] &= 0x7f;
  key[31] |= 0x40;
  return key;
}

function keyPairFromSeed(label) {
  const rawPrivate = deterministicPrivateKeyBytes(label);
  const pkcs8Der = Buffer.concat([X25519_PKCS8_PREFIX, rawPrivate]);
  const privateKeyObj = createPrivateKey({
    key: pkcs8Der,
    format: 'der',
    type: 'pkcs8',
  });
  const publicKeyObj = createPublicKey(privateKeyObj);
  const spkiDer = publicKeyObj.export({ format: 'der', type: 'spki' });
  if (!spkiDer.subarray(0, X25519_SPKI_PREFIX.length).equals(X25519_SPKI_PREFIX)) {
    throw new Error('Unexpected X25519 SPKI prefix');
  }
  const rawPublic = spkiDer.subarray(X25519_SPKI_PREFIX.length);
  if (rawPublic.length !== 32) {
    throw new Error(`Expected 32-byte X25519 public key, got ${rawPublic.length}`);
  }
  return { rawPrivate, rawPublic, privateKeyObj, publicKeyObj };
}

function importRawPublicKey(rawPublic) {
  const spkiDer = Buffer.concat([X25519_SPKI_PREFIX, rawPublic]);
  return createPublicKey({ key: spkiDer, format: 'der', type: 'spki' });
}

function deriveSessionKey(myPrivateObj, peerRawPublic, matchId) {
  const peerPubObj = importRawPublicKey(peerRawPublic);
  const sharedSecret = diffieHellman({
    privateKey: myPrivateObj,
    publicKey: peerPubObj,
  });
  const salt = Buffer.from(matchId, 'utf8');
  const sessionKey = Buffer.from(hkdfSync('sha256', sharedSecret, salt, E2EE_INFO, 32));
  return { sharedSecret, sessionKey };
}

function encryptMessage({
  senderKeys,
  recipientKeys,
  match_id: matchId,
  sender_id: senderId,
  nonceBytes,
  plaintext,
}) {
  const { sharedSecret, sessionKey } = deriveSessionKey(
    senderKeys.privateKeyObj,
    recipientKeys.rawPublic,
    matchId
  );
  const aad = Buffer.from(`${matchId}:${senderId}`, 'utf8');
  const cipher = createCipheriv('aes-256-gcm', sessionKey, nonceBytes, {
    authTagLength: AUTH_TAG_LENGTH,
  });
  cipher.setAAD(aad);
  const cipherText = Buffer.concat([
    cipher.update(Buffer.from(plaintext, 'utf8')),
    cipher.final(),
  ]);
  const authTag = cipher.getAuthTag();
  if (authTag.length !== AUTH_TAG_LENGTH) {
    throw new Error(`Invalid authTag length: ${authTag.length}`);
  }
  const serializedPayload = Buffer.concat([cipherText, authTag]);
  return {
    sharedSecret,
    sessionKey,
    aadUtf8: `${matchId}:${senderId}`,
    serializedPayload,
  };
}

function decryptMessage({
  recipientKeys,
  senderRawPublic,
  matchId,
  senderId,
  nonceBytes,
  serializedPayload,
}) {
  const { sharedSecret, sessionKey } = deriveSessionKey(
    recipientKeys.privateKeyObj,
    senderRawPublic,
    matchId
  );
  if (serializedPayload.length < AUTH_TAG_LENGTH) {
    throw new Error('Ciphertext too short to contain 16-byte GCM auth tag');
  }
  const cipherText = serializedPayload.subarray(
    0,
    serializedPayload.length - AUTH_TAG_LENGTH
  );
  const authTag = serializedPayload.subarray(
    serializedPayload.length - AUTH_TAG_LENGTH
  );
  const aad = Buffer.from(`${matchId}:${senderId}`, 'utf8');
  const decipher = createDecipheriv('aes-256-gcm', sessionKey, nonceBytes, {
    authTagLength: AUTH_TAG_LENGTH,
  });
  decipher.setAAD(aad);
  decipher.setAuthTag(authTag);
  const plainBuf = Buffer.concat([decipher.update(cipherText), decipher.final()]);
  return {
    sharedSecret,
    sessionKey,
    plaintext: plainBuf.toString('utf8'),
  };
}

const claraKeys = keyPairFromSeed('nexus-duo-golden-clara-valkyrie-v1');
const lucasKeys = keyPairFromSeed('nexus-duo-golden-lucas-kael-v1');
const biaKeys = keyPairFromSeed('nexus-duo-golden-bia-cozy-v1');

const specs = [
  {
    id: 'vector-1-ptbr-emoji',
    description:
      'Clara envia mensagem PT-BR com acentos e emojis para Lucas no Match 1',
    match_id: '550e8400-e29b-41d4-a716-446655440001',
    sender_id: '11111111-1111-4111-8111-111111111111',
    senderKeys: claraKeys,
    recipientKeys: lucasKeys,
    nonceBytes: createHash('sha256').update('nexus-nonce-1').digest().subarray(0, 12),
    plaintext:
      'Oi Lucas! Vi que você também joga Valorant às 21h 🎮💜 Topa um Swiftplay hoje?',
  },
  {
    id: 'vector-2-symmetric-reply-json',
    description:
      'Lucas responde para Clara (simetria X25519) com payload JSON de convite de lobby',
    match_id: '550e8400-e29b-41d4-a716-446655440001',
    sender_id: '22222222-2222-4222-8222-222222222222',
    senderKeys: lucasKeys,
    recipientKeys: claraKeys,
    nonceBytes: createHash('sha256').update('nexus-nonce-2').digest().subarray(0, 12),
    plaintext:
      '{"type":"lobby_invite","game":"Valorant","mode":"casual","voice":"discord","code":"DUO-9421"}',
  },
  {
    id: 'vector-3-multibyte-different-match',
    description:
      'Bia envia mensagem multi-byte e caracteres especiais para Clara em outro Match',
    match_id: '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d',
    sender_id: '33333333-3333-4333-8333-333333333333',
    senderKeys: biaKeys,
    recipientKeys: claraKeys,
    nonceBytes: createHash('sha256').update('nexus-nonce-3').digest().subarray(0, 12),
    plaintext:
      'Stardew Valley co-op: fazenda organizada ou caos criativo? ✨🌱 — Ação & café ☕!',
  },
];

const vectors = specs.map((spec) => {
  const encrypted = encryptMessage(spec);
  const decrypted = decryptMessage({
    recipientKeys: spec.recipientKeys,
    senderRawPublic: spec.senderKeys.rawPublic,
    matchId: spec.match_id,
    senderId: spec.sender_id,
    nonceBytes: spec.nonceBytes,
    serializedPayload: encrypted.serializedPayload,
  });

  if (decrypted.plaintext !== spec.plaintext) {
    throw new Error(`Round-trip plaintext mismatch for ${spec.id}`);
  }
  if (!decrypted.sharedSecret.equals(encrypted.sharedSecret)) {
    throw new Error(`Shared secret asymmetry detected for ${spec.id}`);
  }
  if (!decrypted.sessionKey.equals(encrypted.sessionKey)) {
    throw new Error(`Session key mismatch for ${spec.id}`);
  }

  return {
    id: spec.id,
    description: spec.description,
    match_id: spec.match_id,
    sender_id: spec.sender_id,
    sender_private_key_b64: spec.senderKeys.rawPrivate.toString('base64'),
    sender_public_key_b64: spec.senderKeys.rawPublic.toString('base64'),
    recipient_private_key_b64: spec.recipientKeys.rawPrivate.toString('base64'),
    recipient_public_key_b64: spec.recipientKeys.rawPublic.toString('base64'),
    nonce_b64: spec.nonceBytes.toString('base64'),
    aad_utf8: encrypted.aadUtf8,
    plaintext: spec.plaintext,
    expected_shared_secret_b64: encrypted.sharedSecret.toString('base64'),
    expected_session_key_b64: encrypted.sessionKey.toString('base64'),
    expected_ciphertext_b64: encrypted.serializedPayload.toString('base64'),
  };
});

const output = {
  version: '1.0.0',
  algorithm: {
    key_exchange: 'X25519',
    kdf: 'HKDF-SHA256',
    kdf_salt: 'UTF8(match_id)',
    kdf_info: 'nexus-duo-e2ee-v1',
    kdf_length_bytes: 32,
    cipher: 'AES-256-GCM',
    nonce_length_bytes: 12,
    tag_length_bits: 128,
    aad_format: 'UTF8(match_id + ":" + sender_id)',
    ciphertext_serialization: 'Base64(cipherTextBytes || authTag16Bytes)',
  },
  vectors,
};

const outPath = resolve(__dirname, 'crypto_golden_vectors.json');
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, `${JSON.stringify(output, null, 2)}\n`, 'utf8');
console.log(`Generated and self-verified ${vectors.length} golden vectors at ${outPath}`);
