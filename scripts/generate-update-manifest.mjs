#!/usr/bin/env node
/**
 * scripts/generate-update-manifest.mjs
 * Generates and verifies canonical `update-manifest.json` (schema v2) for NEXUS DUO releases.
 */

import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const ALLOWED_DOWNLOAD_HOSTS = new Set([
  'github.com',
  'objects.githubusercontent.com',
  'release-assets.githubusercontent.com',
]);

const VALID_ABI_KEYS = new Set(['arm64-v8a', 'armeabi-v7a', 'x86_64', 'universal']);

/**
 * Parses `version: X.Y.Z+N` from Flutter `pubspec.yaml`.
 */
export function parsePubspecVersion(pubspecContent) {
  const match = pubspecContent.match(/^\s*version:\s*([^\s#]+)\s*$/m);
  if (!match) {
    throw new Error('Could not find "version:" field in pubspec.yaml.');
  }
  const raw = match[1].trim();
  const verMatch = raw.match(/^(\d+\.\d+\.\d+)\+(\d+)$/);
  if (!verMatch) {
    throw new Error(`Invalid pubspec version format "${raw}". Expected X.Y.Z+N.`);
  }
  return {
    raw,
    versionName: verMatch[1],
    versionCode: Number.parseInt(verMatch[2], 10),
  };
}

/**
 * Computes lowercase SHA-256 hex digest for a local file.
 */
export function computeFileSha256(filePath) {
  const buf = readFileSync(filePath);
  return createHash('sha256').update(buf).digest('hex').toLowerCase();
}

/**
 * Maps an APK file name to its canonical ABI key.
 */
export function detectAbiKey(fileName) {
  const lower = fileName.toLowerCase();
  if (lower.includes('arm64-v8a') || lower.includes('arm64')) return 'arm64-v8a';
  if (lower.includes('armeabi-v7a') || lower.includes('armeabi')) return 'armeabi-v7a';
  if (lower.includes('x86_64')) return 'x86_64';
  if (lower.includes('universal') || lower.includes('app-release')) return 'universal';
  return 'universal';
}

/**
 * Extracts clean, human-readable PT-BR release notes from git commit subjects or custom notes.
 */
export function extractHumanReleaseNotes(commitSubjects = [], customNotes = '') {
  const bullets = [];
  const seen = new Set();

  const pushUnique = (text) => {
    const clean = text.replace(/\s+/g, ' ').trim();
    if (!clean || clean.length < 4) return;
    const capitalized = clean.charAt(0).toUpperCase() + clean.slice(1);
    const key = capitalized.toLowerCase();
    if (!seen.has(key)) {
      seen.add(key);
      bullets.push(capitalized);
    }
  };

  if (typeof customNotes === 'string' && customNotes.trim().length > 0) {
    for (const rawLine of customNotes.split(/\r?\n/)) {
      const cleaned = rawLine
        .replace(/^[-*•]\s*/, '')
        .replace(/\[(skip ci|skip release)\]/gi, '')
        .trim();
      if (cleaned && !cleaned.startsWith('#')) {
        pushUnique(cleaned);
      }
    }
  }

  for (const subject of commitSubjects) {
    if (typeof subject !== 'string') continue;
    const trimmed = subject.trim();
    if (!trimmed) continue;
    if (/^merge\b/i.test(trimmed)) continue;
    if (/^chore\(release\):/i.test(trimmed)) continue;
    if (/\[(skip ci|skip release)\]/i.test(trimmed)) continue;

    // Strip Conventional Commits prefix and scope, e.g., `feat(updater)!: ...` -> `...`
    const stripped = trimmed
      .replace(/^[a-z]+(\([^)]+\))?!?:\s*/i, '')
      .replace(/\s*\(#\d+\)\s*$/, '')
      .trim();
    if (stripped) {
      pushUnique(stripped);
    }
  }

  if (bullets.length === 0) {
    return [
      'Melhorias de estabilidade, segurança Zero-Trust e desempenho no NEXUS DUO.',
    ];
  }

  return bullets.slice(0, 8);
}

/**
 * Validates that a URL is HTTPS and belongs to the strict download host allowlist.
 */
export function isAllowedDownloadUrl(rawUrl) {
  try {
    const parsed = new URL(rawUrl);
    return (
      parsed.protocol === 'https:' &&
      ALLOWED_DOWNLOAD_HOSTS.has(parsed.hostname.toLowerCase())
    );
  } catch {
    return false;
  }
}

/**
 * Validates a manifest object against NEXUS DUO schema v2 and optional APK files on disk.
 */
export function validateManifestObject(manifest, options = {}) {
  const { dir = null } = options;
  const errors = [];

  if (!manifest || typeof manifest !== 'object' || Array.isArray(manifest)) {
    return { valid: false, errors: ['Manifest root must be a JSON object.'] };
  }

  if (manifest.schema_version !== 2) {
    errors.push(`schema_version must be 2 (got ${manifest.schema_version}).`);
  }
  if (manifest.app_id !== 'com.nexusduo.app') {
    errors.push(`app_id must be "com.nexusduo.app" (got ${manifest.app_id}).`);
  }
  if (manifest.channel !== 'stable' && manifest.channel !== 'beta') {
    errors.push(`channel must be "stable" or "beta" (got ${manifest.channel}).`);
  }
  if (typeof manifest.version_name !== 'string' || !/^\d+\.\d+\.\d+$/.test(manifest.version_name)) {
    errors.push(`Invalid version_name "${manifest.version_name}".`);
  }
  if (!Number.isInteger(manifest.version_code) || manifest.version_code < 1) {
    errors.push(`version_code must be an integer >= 1 (got ${manifest.version_code}).`);
  }
  if (
    !Number.isInteger(manifest.min_supported_version_code) ||
    manifest.min_supported_version_code < 1
  ) {
    errors.push(
      `min_supported_version_code must be an integer >= 1 (got ${manifest.min_supported_version_code}).`
    );
  }
  if (typeof manifest.force_update !== 'boolean') {
    errors.push('force_update must be a boolean.');
  }
  if (typeof manifest.published_at !== 'string' || Number.isNaN(Date.parse(manifest.published_at))) {
    errors.push(`Invalid ISO-8601 published_at "${manifest.published_at}".`);
  }
  if (
    typeof manifest.signing_cert_sha256 !== 'string' ||
    !/^(|[a-f0-9]{64})$/.test(manifest.signing_cert_sha256)
  ) {
    errors.push('signing_cert_sha256 must be empty or 64 lowercase hex characters.');
  }
  if (
    typeof manifest.release_url !== 'string' ||
    !manifest.release_url.startsWith('https://github.com/')
  ) {
    errors.push(`Invalid release_url "${manifest.release_url}".`);
  }
  if (
    !Array.isArray(manifest.release_notes_pt_br) ||
    manifest.release_notes_pt_br.length === 0 ||
    manifest.release_notes_pt_br.some((item) => typeof item !== 'string' || item.trim().length === 0)
  ) {
    errors.push('release_notes_pt_br must be a non-empty array of non-empty strings.');
  }

  if (!manifest.apks || typeof manifest.apks !== 'object' || Array.isArray(manifest.apks)) {
    errors.push('apks must be an object keyed by ABI.');
  } else {
    const entries = Object.entries(manifest.apks);
    if (entries.length === 0) {
      errors.push('apks map must contain at least one APK entry.');
    }
    for (const [abiKey, asset] of entries) {
      if (!VALID_ABI_KEYS.has(abiKey)) {
        errors.push(`Unsupported ABI key "${abiKey}".`);
        continue;
      }
      if (!asset || typeof asset !== 'object') {
        errors.push(`apks.${abiKey} must be an object.`);
        continue;
      }
      if (typeof asset.file_name !== 'string' || !asset.file_name.endsWith('.apk')) {
        errors.push(`apks.${abiKey}.file_name must end with .apk.`);
      }
      if (typeof asset.url !== 'string' || !isAllowedDownloadUrl(asset.url)) {
        errors.push(`apks.${abiKey}.url "${asset.url}" is not an allowed HTTPS release URL.`);
      }
      if (typeof asset.sha256 !== 'string' || !/^[a-f0-9]{64}$/.test(asset.sha256)) {
        errors.push(`apks.${abiKey}.sha256 must be 64 lowercase hex characters.`);
      }
      if (!Number.isInteger(asset.size_bytes) || asset.size_bytes < 1) {
        errors.push(`apks.${abiKey}.size_bytes must be a positive integer.`);
      }

      if (dir && typeof asset.file_name === 'string') {
        const filePath = join(dir, asset.file_name);
        if (!existsSync(filePath)) {
          errors.push(`Referenced APK missing on disk: ${filePath}`);
        } else {
          const actualSize = statSync(filePath).size;
          if (actualSize !== asset.size_bytes) {
            errors.push(
              `Size mismatch for ${asset.file_name}: manifest=${asset.size_bytes}, disk=${actualSize}`
            );
          }
          const actualSha = computeFileSha256(filePath);
          if (actualSha !== asset.sha256) {
            errors.push(
              `SHA-256 mismatch for ${asset.file_name}: manifest=${asset.sha256}, disk=${actualSha}`
            );
          }
        }
      }
    }
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

function getCommitSubjectsSincePreviousTag(currentTag) {
  try {
    const tagsRaw = execFileSync('git', ['tag', '--sort=-v:refname', '--list', 'v*'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });
    const tags = tagsRaw
      .split(/\r?\n/)
      .map((t) => t.trim())
      .filter(Boolean);
    const previousTag = tags.find((t) => t !== currentTag);
    const range = previousTag ? `${previousTag}..HEAD` : 'HEAD~15..HEAD';
    let logOutput = '';
    try {
      logOutput = execFileSync('git', ['log', range, '--pretty=format:%s'], {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
      });
    } catch {
      logOutput = execFileSync('git', ['log', '-n', '10', '--pretty=format:%s'], {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
      });
    }
    return logOutput.split(/\r?\n/).filter(Boolean);
  } catch {
    return [];
  }
}

/**
 * Builds an `update-manifest.json` object from disk APKs and pubspec metadata.
 */
export function buildUpdateManifest({
  dir,
  tag,
  repo = 'WagnerxOliveira/nexus-duo',
  pubspecPath = 'apps/mobile/pubspec.yaml',
  certSha256 = '',
  minSupportedCode = 1,
  forceUpdate = false,
  rolloutEnabled = true,
  channel = 'stable',
  customNotes = '',
  commitsSincePrevTag = null,
  publishedAt = new Date().toISOString(),
}) {
  const resolvedDir = resolve(process.cwd(), dir);
  if (!existsSync(resolvedDir)) {
    throw new Error(`APKs directory not found: ${resolvedDir}`);
  }

  const resolvedPubspec = resolve(process.cwd(), pubspecPath);
  if (!existsSync(resolvedPubspec)) {
    throw new Error(`pubspec.yaml not found: ${resolvedPubspec}`);
  }

  const pubspecVersion = parsePubspecVersion(readFileSync(resolvedPubspec, 'utf8'));
  const normalizedTag = tag.trim().startsWith('v') ? tag.trim() : `v${tag.trim()}`;
  const tagVersionName = normalizedTag.replace(/^v/i, '');

  if (pubspecVersion.versionName !== tagVersionName) {
    throw new Error(
      `Version mismatch: pubspec.yaml has "${pubspecVersion.versionName}", but release tag is "${normalizedTag}".`
    );
  }

  const apkFiles = readdirSync(resolvedDir)
    .filter((f) => f.toLowerCase().endsWith('.apk'))
    .sort();

  if (apkFiles.length === 0) {
    throw new Error(`No .apk files found in ${resolvedDir}`);
  }

  const apks = {};
  for (const fileName of apkFiles) {
    const abiKey = detectAbiKey(fileName);
    const fullPath = join(resolvedDir, fileName);
    const stats = statSync(fullPath);
    apks[abiKey] = {
      file_name: fileName,
      url: `https://github.com/${repo}/releases/download/${normalizedTag}/${fileName}`,
      sha256: computeFileSha256(fullPath),
      size_bytes: stats.size,
    };
  }

  const commits =
    Array.isArray(commitsSincePrevTag)
      ? commitsSincePrevTag
      : getCommitSubjectsSincePreviousTag(normalizedTag);

  const normalizedCert = certSha256.trim().toLowerCase();
  if (normalizedCert && !/^[a-f0-9]{64}$/.test(normalizedCert)) {
    throw new Error(`Invalid --cert-sha256 value: "${certSha256}"`);
  }

  const parsedMinCode = Number.parseInt(String(minSupportedCode), 10);
  const manifest = {
    schema_version: 2,
    app_id: 'com.nexusduo.app',
    channel,
    version_name: pubspecVersion.versionName,
    version_code: pubspecVersion.versionCode,
    min_supported_version_code: Number.isNaN(parsedMinCode) || parsedMinCode < 1 ? 1 : parsedMinCode,
    force_update: Boolean(forceUpdate),
    rollout_enabled: Boolean(rolloutEnabled),
    published_at: publishedAt,
    signing_cert_sha256: normalizedCert,
    release_url: `https://github.com/${repo}/releases/tag/${normalizedTag}`,
    release_notes_pt_br: extractHumanReleaseNotes(commits, customNotes),
    apks,
  };

  const validation = validateManifestObject(manifest, { dir: resolvedDir });
  if (!validation.valid) {
    throw new Error(`Generated manifest failed validation:\n- ${validation.errors.join('\n- ')}`);
  }

  return manifest;
}

function parseBoolFlag(val, defaultVal = false) {
  if (val === undefined || val === null || val === '') return defaultVal;
  return String(val).trim().toLowerCase() === 'true';
}

function runCli() {
  const args = process.argv.slice(2);
  if (args.includes('--help') || args.includes('-h') || args.length === 0) {
    console.log(`
NEXUS DUO — Update Manifest Generator & Verifier (schema v2)

Usage:
  node scripts/generate-update-manifest.mjs --dir dist/apks --tag v1.2.0 [options]
  node scripts/generate-update-manifest.mjs --verify dist/apks/update-manifest.json [--dir dist/apks]
`);
    process.exit(0);
  }

  let dir = null;
  let tag = null;
  let repo = 'WagnerxOliveira/nexus-duo';
  let pubspec = 'apps/mobile/pubspec.yaml';
  let certSha256 = '';
  let minSupportedCode = 1;
  let forceUpdate = false;
  let channel = 'stable';
  let notes = '';
  let write = false;
  let output = null;
  let verifyPath = null;

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    switch (arg) {
      case '--dir':
        dir = args[++i];
        break;
      case '--tag':
        tag = args[++i];
        break;
      case '--repo':
        repo = args[++i];
        break;
      case '--pubspec':
        pubspec = args[++i];
        break;
      case '--cert-sha256':
        certSha256 = args[++i] || '';
        break;
      case '--min-supported-code':
        minSupportedCode = args[++i];
        break;
      case '--force-update':
        forceUpdate = parseBoolFlag(args[++i], false);
        break;
      case '--channel':
        channel = args[++i] || 'stable';
        break;
      case '--notes':
        notes = args[++i] || '';
        break;
      case '--write':
        write = true;
        break;
      case '--output':
        output = args[++i];
        break;
      case '--verify':
        verifyPath = args[++i];
        break;
      default:
        console.error(`Unknown argument: ${arg}`);
        process.exit(1);
    }
  }

  if (verifyPath) {
    const resolvedVerify = resolve(process.cwd(), verifyPath);
    if (!existsSync(resolvedVerify)) {
      console.error(`Manifest file not found: ${resolvedVerify}`);
      process.exit(1);
    }
    const raw = JSON.parse(readFileSync(resolvedVerify, 'utf8'));
    const verifyDir = dir ? resolve(process.cwd(), dir) : dirname(resolvedVerify);
    const result = validateManifestObject(raw, { dir: verifyDir });
    if (!result.valid) {
      console.error(`Manifest verification FAILED:\n- ${result.errors.join('\n- ')}`);
      process.exit(1);
    }
    console.log(
      `Manifest verified OK: v${raw.version_name}+${raw.version_code} (${Object.keys(raw.apks).length} APKs)`
    );
    return;
  }

  if (!dir || !tag) {
    console.error('--dir and --tag are required when generating update-manifest.json.');
    process.exit(1);
  }

  const manifest = buildUpdateManifest({
    dir,
    tag,
    repo,
    pubspecPath: pubspec,
    certSha256,
    minSupportedCode,
    forceUpdate,
    channel,
    customNotes: notes,
  });

  const serialized = `${JSON.stringify(manifest, null, 2)}\n`;
  if (output || write) {
    const target = output ? resolve(process.cwd(), output) : join(resolve(process.cwd(), dir), 'update-manifest.json');
    writeFileSync(target, serialized, 'utf8');
    console.log(`Generated ${target} (v${manifest.version_name}+${manifest.version_code})`);
  } else {
    process.stdout.write(serialized);
  }
}

const isEntrypoint =
  process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url));
if (isEntrypoint) {
  runCli();
}
