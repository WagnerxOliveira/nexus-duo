import { x25519 } from '@noble/curves/ed25519';

export const E2EE_PROTOCOL_INFO = 'nexus-duo-e2ee-v1';
export const X25519_KEY_LENGTH = 32;
export const AES_GCM_NONCE_LENGTH = 12;
export const AES_GCM_TAG_LENGTH_BITS = 128;
export const AES_GCM_TAG_LENGTH_BYTES = 16;

export interface E2EEKeyPair {
  publicKeyB64: string;
  privateKeyB64: string;
}

export interface EncryptedPayload {
  ciphertextB64: string;
  nonceB64: string;
  aadUtf8: string;
}

export interface EncryptParams {
  plaintext: string;
  myPrivateKeyB64: string;
  peerPublicKeyB64: string;
  matchId: string;
  senderId: string;
  /** Optional 12-byte Base64 nonce strictly for deterministic golden-vector verification */
  deterministicNonceB64?: string;
}

export interface DecryptParams {
  ciphertextB64: string;
  nonceB64: string;
  myPrivateKeyB64: string;
  peerPublicKeyB64: string;
  matchId: string;
  senderId: string;
}

export interface IMessageCipher {
  generateKeyPair(): E2EEKeyPair;
  derivePublicKey(privateKeyB64: string): string;
  deriveSharedSecret(myPrivateKeyB64: string, peerPublicKeyB64: string): Uint8Array;
  deriveSessionKeyBytes(
    sharedSecret: Uint8Array,
    matchId: string,
  ): Promise<Uint8Array>;
  encrypt(params: EncryptParams): Promise<EncryptedPayload>;
  decrypt(params: DecryptParams): Promise<string>;
}

export interface ISecureKeyVault {
  getOrCreateKeyPair(userId: string): Promise<E2EEKeyPair>;
  saveKeyPair(userId: string, pair: E2EEKeyPair): Promise<void>;
  clear(userId: string): Promise<void>;
}

const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder('utf-8', { fatal: true });

export function bytesToBase64(bytes: Uint8Array): string {
  if (typeof Buffer !== 'undefined') {
    return Buffer.from(bytes).toString('base64');
  }
  let binary = '';
  for (let i = 0; i < bytes.length; i += 1) {
    binary += String.fromCharCode(bytes[i] ?? 0);
  }
  return btoa(binary);
}

export function base64ToBytes(b64: string): Uint8Array {
  if (typeof Buffer !== 'undefined') {
    const buf = Buffer.from(b64, 'base64');
    return new Uint8Array(buf.buffer, buf.byteOffset, buf.byteLength).slice();
  }
  const binary = atob(b64);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    out[i] = binary.charCodeAt(i);
  }
  return out;
}

function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const copy = new Uint8Array(bytes.byteLength);
  copy.set(bytes);
  return copy.buffer;
}

function getSubtleCrypto(): SubtleCrypto {
  const cryptoObj = globalThis.crypto;
  if (!cryptoObj?.subtle) {
    throw new Error('WebCrypto SubtleCrypto API is not available in this runtime.');
  }
  return cryptoObj.subtle;
}

function getRandomBytes(length: number): Uint8Array {
  const cryptoObj = globalThis.crypto;
  if (!cryptoObj?.getRandomValues) {
    throw new Error('CSPRNG crypto.getRandomValues is not available in this runtime.');
  }
  const bytes = new Uint8Array(length);
  cryptoObj.getRandomValues(bytes);
  return bytes;
}

export function buildAadUtf8(matchId: string, senderId: string): string {
  return `${matchId}:${senderId}`;
}

/**
 * NEXUS DUO Cross-Platform E2EE Cipher
 * Binary contract:
 * - Key Exchange: X25519 (raw 32-byte keys in Base64)
 * - KDF: HKDF-SHA256(ikm=sharedSecret, salt=UTF8(matchId), info=UTF8("nexus-duo-e2ee-v1"), len=32)
 * - Cipher: AES-256-GCM (nonce=12B CSPRNG, aad=UTF8(matchId + ":" + senderId), tagLength=128 bits)
 * - Wire format: Base64(cipherTextBytes || authTag16Bytes)
 */
export class WebCryptoE2EECipher implements IMessageCipher {
  generateKeyPair(): E2EEKeyPair {
    const privateBytes = x25519.utils.randomPrivateKey();
    const publicBytes = x25519.getPublicKey(privateBytes);
    return {
      privateKeyB64: bytesToBase64(privateBytes),
      publicKeyB64: bytesToBase64(publicBytes),
    };
  }

  derivePublicKey(privateKeyB64: string): string {
    const privateBytes = base64ToBytes(privateKeyB64);
    if (privateBytes.length !== X25519_KEY_LENGTH) {
      throw new Error(
        `Invalid X25519 private key length: expected ${X25519_KEY_LENGTH}, got ${privateBytes.length}`,
      );
    }
    return bytesToBase64(x25519.getPublicKey(privateBytes));
  }

  deriveSharedSecret(myPrivateKeyB64: string, peerPublicKeyB64: string): Uint8Array {
    const myPriv = base64ToBytes(myPrivateKeyB64);
    const peerPub = base64ToBytes(peerPublicKeyB64);

    if (myPriv.length !== X25519_KEY_LENGTH) {
      throw new Error(
        `Invalid X25519 private key length: expected ${X25519_KEY_LENGTH}, got ${myPriv.length}`,
      );
    }
    if (peerPub.length !== X25519_KEY_LENGTH) {
      throw new Error(
        `Invalid X25519 public key length: expected ${X25519_KEY_LENGTH}, got ${peerPub.length}`,
      );
    }

    return x25519.getSharedSecret(myPriv, peerPub);
  }

  async deriveSessionKeyBytes(
    sharedSecret: Uint8Array,
    matchId: string,
  ): Promise<Uint8Array> {
    if (sharedSecret.length !== X25519_KEY_LENGTH) {
      throw new Error(`Invalid shared secret length: ${sharedSecret.length}`);
    }
    const subtle = getSubtleCrypto();
    const hkdfKey = await subtle.importKey(
      'raw',
      toArrayBuffer(sharedSecret),
      'HKDF',
      false,
      ['deriveBits'],
    );
    const derivedBits = await subtle.deriveBits(
      {
        name: 'HKDF',
        hash: 'SHA-256',
        salt: toArrayBuffer(textEncoder.encode(matchId)),
        info: toArrayBuffer(textEncoder.encode(E2EE_PROTOCOL_INFO)),
      },
      hkdfKey,
      256,
    );
    return new Uint8Array(derivedBits);
  }

  private async importAesKey(
    sessionKeyBytes: Uint8Array,
    usages: KeyUsage[],
  ): Promise<CryptoKey> {
    const subtle = getSubtleCrypto();
    return subtle.importKey(
      'raw',
      toArrayBuffer(sessionKeyBytes),
      { name: 'AES-GCM', length: 256 },
      false,
      usages,
    );
  }

  async encrypt(params: EncryptParams): Promise<EncryptedPayload> {
    const sharedSecret = this.deriveSharedSecret(
      params.myPrivateKeyB64,
      params.peerPublicKeyB64,
    );
    const sessionKeyBytes = await this.deriveSessionKeyBytes(
      sharedSecret,
      params.matchId,
    );
    const aesKey = await this.importAesKey(sessionKeyBytes, ['encrypt']);

    const nonceBytes = params.deterministicNonceB64
      ? base64ToBytes(params.deterministicNonceB64)
      : getRandomBytes(AES_GCM_NONCE_LENGTH);

    if (nonceBytes.length !== AES_GCM_NONCE_LENGTH) {
      throw new Error(
        `Invalid AES-GCM nonce length: expected ${AES_GCM_NONCE_LENGTH}, got ${nonceBytes.length}`,
      );
    }

    const aadUtf8 = buildAadUtf8(params.matchId, params.senderId);
    const subtle = getSubtleCrypto();
    const cipherBuffer = await subtle.encrypt(
      {
        name: 'AES-GCM',
        iv: toArrayBuffer(nonceBytes),
        additionalData: toArrayBuffer(textEncoder.encode(aadUtf8)),
        tagLength: AES_GCM_TAG_LENGTH_BITS,
      },
      aesKey,
      toArrayBuffer(textEncoder.encode(params.plaintext)),
    );

    return {
      ciphertextB64: bytesToBase64(new Uint8Array(cipherBuffer)),
      nonceB64: bytesToBase64(nonceBytes),
      aadUtf8,
    };
  }

  async decrypt(params: DecryptParams): Promise<string> {
    const nonceBytes = base64ToBytes(params.nonceB64);
    if (nonceBytes.length !== AES_GCM_NONCE_LENGTH) {
      throw new Error(
        `Invalid AES-GCM nonce length: expected ${AES_GCM_NONCE_LENGTH}, got ${nonceBytes.length}`,
      );
    }

    const cipherBytes = base64ToBytes(params.ciphertextB64);
    if (cipherBytes.length < AES_GCM_TAG_LENGTH_BYTES) {
      throw new Error('Ciphertext payload is shorter than the 16-byte GCM auth tag.');
    }

    const sharedSecret = this.deriveSharedSecret(
      params.myPrivateKeyB64,
      params.peerPublicKeyB64,
    );
    const sessionKeyBytes = await this.deriveSessionKeyBytes(
      sharedSecret,
      params.matchId,
    );
    const aesKey = await this.importAesKey(sessionKeyBytes, ['decrypt']);

    const aadUtf8 = buildAadUtf8(params.matchId, params.senderId);
    const subtle = getSubtleCrypto();
    const plainBuffer = await subtle.decrypt(
      {
        name: 'AES-GCM',
        iv: toArrayBuffer(nonceBytes),
        additionalData: toArrayBuffer(textEncoder.encode(aadUtf8)),
        tagLength: AES_GCM_TAG_LENGTH_BITS,
      },
      aesKey,
      toArrayBuffer(cipherBytes),
    );

    return textDecoder.decode(new Uint8Array(plainBuffer));
  }
}

/**
 * In-memory vault for SSR, Node/Vitest, and environments without IndexedDB.
 */
export class MemoryKeyVault implements ISecureKeyVault {
  private readonly store = new Map<string, E2EEKeyPair>();
  private readonly cipher: IMessageCipher;

  constructor(cipher: IMessageCipher = new WebCryptoE2EECipher()) {
    this.cipher = cipher;
  }

  async getOrCreateKeyPair(userId: string): Promise<E2EEKeyPair> {
    const existing = this.store.get(userId);
    if (existing) {
      return existing;
    }
    const created = this.cipher.generateKeyPair();
    this.store.set(userId, created);
    return created;
  }

  async saveKeyPair(userId: string, pair: E2EEKeyPair): Promise<void> {
    this.store.set(userId, pair);
  }

  async clear(userId: string): Promise<void> {
    this.store.delete(userId);
  }
}

interface StoredVaultRecord {
  userId: string;
  publicKeyB64: string;
  wrappedPrivateB64: string;
  ivB64: string;
  wrappingKey: CryptoKey;
}

/**
 * Browser IndexedDB vault storing a non-extractable AES-GCM CryptoKey that wraps
 * the user's X25519 private key at rest, with automatic fallback to MemoryKeyVault
 * during SSR or when IndexedDB is unavailable.
 */
export class IndexedDbKeyVault implements ISecureKeyVault {
  private static readonly DB_NAME = 'nexus-duo-e2ee-vault-v1';
  private static readonly STORE_NAME = 'keypairs';
  private readonly fallback: MemoryKeyVault;
  private readonly cipher: IMessageCipher;

  constructor(cipher: IMessageCipher = new WebCryptoE2EECipher()) {
    this.cipher = cipher;
    this.fallback = new MemoryKeyVault(cipher);
  }

  private canUseIndexedDb(): boolean {
    return (
      typeof window !== 'undefined' &&
      typeof indexedDB !== 'undefined' &&
      Boolean(globalThis.crypto?.subtle)
    );
  }

  private openDb(): Promise<IDBDatabase> {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(IndexedDbKeyVault.DB_NAME, 1);
      request.onupgradeneeded = () => {
        const db = request.result;
        if (!db.objectStoreNames.contains(IndexedDbKeyVault.STORE_NAME)) {
          db.createObjectStore(IndexedDbKeyVault.STORE_NAME, { keyPath: 'userId' });
        }
      };
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error ?? new Error('Failed to open IndexedDB'));
    });
  }

  async getOrCreateKeyPair(userId: string): Promise<E2EEKeyPair> {
    if (!this.canUseIndexedDb()) {
      return this.fallback.getOrCreateKeyPair(userId);
    }

    try {
      const db = await this.openDb();
      const record = await new Promise<StoredVaultRecord | undefined>((resolve, reject) => {
        const tx = db.transaction(IndexedDbKeyVault.STORE_NAME, 'readonly');
        const req = tx.objectStore(IndexedDbKeyVault.STORE_NAME).get(userId);
        req.onsuccess = () => resolve(req.result as StoredVaultRecord | undefined);
        req.onerror = () => reject(req.error);
      });

      if (record) {
        const subtle = getSubtleCrypto();
        const plainPriv = await subtle.decrypt(
          { name: 'AES-GCM', iv: toArrayBuffer(base64ToBytes(record.ivB64)) },
          record.wrappingKey,
          toArrayBuffer(base64ToBytes(record.wrappedPrivateB64)),
        );
        return {
          publicKeyB64: record.publicKeyB64,
          privateKeyB64: bytesToBase64(new Uint8Array(plainPriv)),
        };
      }

      const generated = this.cipher.generateKeyPair();
      await this.saveKeyPair(userId, generated);
      return generated;
    } catch {
      return this.fallback.getOrCreateKeyPair(userId);
    }
  }

  async saveKeyPair(userId: string, pair: E2EEKeyPair): Promise<void> {
    if (!this.canUseIndexedDb()) {
      await this.fallback.saveKeyPair(userId, pair);
      return;
    }

    try {
      const subtle = getSubtleCrypto();
      const wrappingKey = await subtle.generateKey(
        { name: 'AES-GCM', length: 256 },
        false,
        ['encrypt', 'decrypt'],
      );
      const iv = getRandomBytes(AES_GCM_NONCE_LENGTH);
      const wrapped = await subtle.encrypt(
        { name: 'AES-GCM', iv: toArrayBuffer(iv) },
        wrappingKey,
        toArrayBuffer(base64ToBytes(pair.privateKeyB64)),
      );

      const record: StoredVaultRecord = {
        userId,
        publicKeyB64: pair.publicKeyB64,
        wrappedPrivateB64: bytesToBase64(new Uint8Array(wrapped)),
        ivB64: bytesToBase64(iv),
        wrappingKey,
      };

      const db = await this.openDb();
      await new Promise<void>((resolve, reject) => {
        const tx = db.transaction(IndexedDbKeyVault.STORE_NAME, 'readwrite');
        tx.objectStore(IndexedDbKeyVault.STORE_NAME).put(record);
        tx.oncomplete = () => resolve();
        tx.onerror = () => reject(tx.error);
      });
    } catch {
      await this.fallback.saveKeyPair(userId, pair);
    }
  }

  async clear(userId: string): Promise<void> {
    await this.fallback.clear(userId);
    if (!this.canUseIndexedDb()) return;
    try {
      const db = await this.openDb();
      await new Promise<void>((resolve, reject) => {
        const tx = db.transaction(IndexedDbKeyVault.STORE_NAME, 'readwrite');
        tx.objectStore(IndexedDbKeyVault.STORE_NAME).delete(userId);
        tx.oncomplete = () => resolve();
        tx.onerror = () => reject(tx.error);
      });
    } catch {
      // Ignore storage cleanup error in restricted browser modes
    }
  }
}

export const defaultE2EECipher = new WebCryptoE2EECipher();
