import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import {
  bumpPubspecContent,
  computeNextVersion,
  determineBumpType,
} from '../bump-mobile-version.mjs';
import {
  buildUpdateManifest,
  extractHumanReleaseNotes,
  parsePubspecVersion,
  validateManifestObject,
} from '../generate-update-manifest.mjs';

test('determineBumpType follows Conventional Commits rules', () => {
  assert.equal(determineBumpType('fix(chat): handle reconnect edge case'), 'patch');
  assert.equal(determineBumpType('perf(dp): optimize mask lookup\nfix: ui'), 'patch');
  assert.equal(determineBumpType('fix: minor fix\nfeat(updater): discreet pill'), 'minor');
  assert.equal(determineBumpType('feat(api)!: change contract'), 'major');
  assert.equal(determineBumpType('fix: bug\n\nBREAKING CHANGE: drop old format'), 'major');
  assert.equal(determineBumpType('chore: update docs'), 'patch');
});

test('computeNextVersion enforces monotonic versionCode and tag collision guard', () => {
  const existing = new Set(['v1.1.1', 'v1.1.2']);
  const next = computeNextVersion('1.1.0', 3, 'patch', existing);
  assert.equal(next.nextVersion, '1.1.3');
  assert.equal(next.nextCode, 4);
  assert.equal(next.tag, 'v1.1.3');

  const samplePubspec = 'name: nexus_duo\nversion: 1.1.0+3\n';
  const { updatedContent, summary } = bumpPubspecContent(samplePubspec, {
    commits: 'feat(updater): discreet update UX',
  });
  assert.equal(summary.previousVersion, '1.1.0');
  assert.equal(summary.previousCode, 3);
  assert.equal(summary.nextVersion, '1.2.0');
  assert.equal(summary.nextCode, 4);
  assert.match(updatedContent, /^version: 1\.2\.0\+4$/m);
});

test('buildUpdateManifest and validateManifestObject verify APKs and reject tampering', () => {
  const sandbox = mkdtempSync(join(tmpdir(), 'nexus_manifest_test_'));
  try {
    const pubspecPath = join(sandbox, 'pubspec.yaml');
    writeFileSync(pubspecPath, 'name: nexus_duo\nversion: 1.2.0+4\n', 'utf8');

    const apksDir = join(sandbox, 'apks');
    const arm64Path = join(sandbox, 'nexus-duo-v1.2.0-arm64-v8a.apk');
    const univPath = join(sandbox, 'nexus-duo-v1.2.0-universal.apk');
    // Put APKs directly in sandbox dir for buildUpdateManifest
    const armBytes = Buffer.from('FAKE-ARM64-APK-BYTES');
    const univBytes = Buffer.from('FAKE-UNIVERSAL-APK-BYTES');
    writeFileSync(arm64Path, armBytes);
    writeFileSync(univPath, univBytes);

    const parsed = parsePubspecVersion(readFileSync(pubspecPath, 'utf8'));
    assert.equal(parsed.versionName, '1.2.0');
    assert.equal(parsed.versionCode, 4);

    const fakeCert = 'a'.repeat(64);
    const manifest = buildUpdateManifest({
      dir: sandbox,
      tag: 'v1.2.0',
      repo: 'WagnerxOliveira/nexus-duo',
      pubspecPath,
      certSha256: fakeCert,
      minSupportedCode: 2,
      forceUpdate: false,
      commitsSincePrevTag: [
        'feat(updater): add discreet Cyber-Velvet pill',
        'Merge pull request #12 from dev',
        'chore(release): bump v1.2.0 [skip ci]',
        'fix(android): auto resume install after settings',
      ],
    });

    assert.equal(manifest.schema_version, 2);
    assert.equal(manifest.version_name, '1.2.0');
    assert.equal(manifest.version_code, 4);
    assert.equal(manifest.signing_cert_sha256, fakeCert);
    assert.deepEqual(manifest.release_notes_pt_br, [
      'Add discreet Cyber-Velvet pill',
      'Auto resume install after settings',
    ]);
    assert.equal(
      manifest.apks['arm64-v8a'].sha256,
      createHash('sha256').update(armBytes).digest('hex')
    );
    assert.equal(
      manifest.apks['universal'].size_bytes,
      univBytes.length
    );

    const okCheck = validateManifestObject(manifest, { dir: sandbox });
    assert.equal(okCheck.valid, true, okCheck.errors.join(', '));

    // Tamper APK bytes -> verify fails
    writeFileSync(arm64Path, Buffer.from('TAMPERED-ARM64-APK-BYTES'));
    const tamperedDiskCheck = validateManifestObject(manifest, { dir: sandbox });
    assert.equal(tamperedDiskCheck.valid, false);
    assert.ok(tamperedDiskCheck.errors.some((e) => e.includes('SHA-256 mismatch')));

    // Untrusted download host -> verify fails
    const badHostManifest = structuredClone(manifest);
    badHostManifest.apks['universal'].url = 'https://evil.example.com/app.apk';
    const untrustedHostCheck = validateManifestObject(badHostManifest);
    assert.equal(untrustedHostCheck.valid, false);
    assert.ok(untrustedHostCheck.errors.some((e) => e.includes('not an allowed HTTPS release URL')));
  } finally {
    rmSync(sandbox, { recursive: true, force: true });
  }
});

test('extractHumanReleaseNotes handles empty noise cleanly', () => {
  const notes = extractHumanReleaseNotes([
    'Merge branch main',
    'chore(release): bump mobile v1.2.0+4 [skip ci]',
  ]);
  assert.equal(notes.length, 1);
  assert.ok(notes[0].includes('NEXUS DUO'));
});
