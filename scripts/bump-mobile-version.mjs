#!/usr/bin/env node
/**
 * scripts/bump-mobile-version.mjs
 * Automatically increments Flutter SemVer (`versionName`) and Android monotonic
 * `versionCode` in `apps/mobile/pubspec.yaml` using Conventional Commits.
 */

import { execFileSync } from 'node:child_process';
import { appendFileSync, existsSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parsePubspecVersion } from './generate-update-manifest.mjs';

/**
 * Determines SemVer bump level from commit messages since the previous tag.
 */
export function determineBumpType(commitsInput) {
  const rawText = Array.isArray(commitsInput) ? commitsInput.join('\n') : String(commitsInput || '');
  const lines = rawText
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean);

  let hasMinor = false;
  let hasPatch = false;

  for (const line of lines) {
    if (/^BREAKING\s+CHANGE:/i.test(line) || /^[a-z]+(\([^)]+\))?!:/i.test(line)) {
      return 'major';
    }
    if (/^feat(\([^)]+\))?:/i.test(line)) {
      hasMinor = true;
    } else if (/^(fix|perf|refactor|style)(\([^)]+\))?:/i.test(line)) {
      hasPatch = true;
    }
  }

  if (hasMinor) return 'minor';
  if (hasPatch) return 'patch';
  return 'patch';
}

/**
 * Computes next SemVer string and strictly greater `versionCode`.
 */
export function computeNextVersion(
  currentVersionName,
  currentVersionCode,
  bumpType,
  existingTags = new Set()
) {
  const parts = currentVersionName.split('.').map((n) => Number.parseInt(n, 10));
  if (parts.length !== 3 || parts.some((n) => Number.isNaN(n))) {
    throw new Error(`Invalid SemVer "${currentVersionName}".`);
  }

  let [major, minor, patch] = parts;
  if (bumpType === 'major') {
    major += 1;
    minor = 0;
    patch = 0;
  } else if (bumpType === 'minor') {
    minor += 1;
    patch = 0;
  } else {
    patch += 1;
  }

  let nextVersion = `${major}.${minor}.${patch}`;
  while (existingTags.has(`v${nextVersion}`) || existingTags.has(nextVersion)) {
    patch += 1;
    nextVersion = `${major}.${minor}.${patch}`;
  }

  const nextCode = currentVersionCode + 1;
  return {
    nextVersion,
    nextCode,
    tag: `v${nextVersion}`,
    bumpType,
  };
}

/**
 * Returns updated `pubspec.yaml` content plus structured bump summary.
 */
export function bumpPubspecContent(
  pubspecContent,
  { commits = '', existingTags = new Set(), bumpTypeOverride = null } = {}
) {
  const current = parsePubspecVersion(pubspecContent);
  const bumpType = bumpTypeOverride || determineBumpType(commits);
  const next = computeNextVersion(
    current.versionName,
    current.versionCode,
    bumpType,
    existingTags
  );

  const lineEnding = pubspecContent.includes('\r\n') ? '\r\n' : '\n';
  const nextLine = `version: ${next.nextVersion}+${next.nextCode}`;
  const updatedContent = pubspecContent.replace(
    /^(\s*)version:\s*[^\s#]+/m,
    `$1${nextLine}`
  );

  if (updatedContent === pubspecContent) {
    throw new Error('Failed to replace version line in pubspec.yaml.');
  }

  return {
    updatedContent: updatedContent.replace(/\r?\n/g, lineEnding),
    summary: {
      previousVersion: current.versionName,
      previousCode: current.versionCode,
      nextVersion: next.nextVersion,
      nextCode: next.nextCode,
      tag: next.tag,
      bumpType: next.bumpType,
    },
  };
}

function getCommitsSinceLatestTag() {
  try {
    let latestTag = '';
    try {
      latestTag = execFileSync('git', ['describe', '--tags', '--abbrev=0', '--match', 'v*'], {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
      }).trim();
    } catch {
      latestTag = '';
    }
    const rangeArgs = latestTag
      ? ['log', `${latestTag}..HEAD`, '--pretty=format:%s%n%b']
      : ['log', '-n', '20', '--pretty=format:%s%n%b'];
    return execFileSync('git', rangeArgs, {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });
  } catch {
    return '';
  }
}

function getExistingGitTags() {
  try {
    const out = execFileSync('git', ['tag', '-l', 'v*'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });
    return new Set(
      out
        .split(/\r?\n/)
        .map((t) => t.trim())
        .filter(Boolean)
    );
  } catch {
    return new Set();
  }
}

function runCli() {
  const args = process.argv.slice(2);
  if (args.includes('--help') || args.includes('-h')) {
    console.log(`
NEXUS DUO — Mobile Version Bumper (Conventional Commits)

Usage:
  node scripts/bump-mobile-version.mjs [--pubspec apps/mobile/pubspec.yaml] [--commits "..."] [--write] [--github-output <path>]
`);
    process.exit(0);
  }

  let pubspecPath = 'apps/mobile/pubspec.yaml';
  let commitsArg = null;
  let write = false;
  let githubOutputPath = null;
  let bumpOverride = null;

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    switch (arg) {
      case '--pubspec':
        pubspecPath = args[++i];
        break;
      case '--commits':
        commitsArg = args[++i];
        break;
      case '--write':
        write = true;
        break;
      case '--github-output':
        githubOutputPath = args[++i];
        break;
      case '--bump':
        bumpOverride = args[++i];
        break;
      default:
        console.error(`Unknown argument: ${arg}`);
        process.exit(1);
    }
  }

  const resolvedPubspec = resolve(process.cwd(), pubspecPath);
  if (!existsSync(resolvedPubspec)) {
    console.error(`pubspec.yaml not found: ${resolvedPubspec}`);
    process.exit(1);
  }

  const pubspecContent = readFileSync(resolvedPubspec, 'utf8');
  const commits = commitsArg !== null ? commitsArg : getCommitsSinceLatestTag();
  const existingTags = getExistingGitTags();

  const { updatedContent, summary } = bumpPubspecContent(pubspecContent, {
    commits,
    existingTags,
    bumpTypeOverride: bumpOverride,
  });

  if (write) {
    writeFileSync(resolvedPubspec, updatedContent, 'utf8');
  }

  if (githubOutputPath) {
    const resolvedOut = resolve(process.cwd(), githubOutputPath);
    const lines = [
      `version_name=${summary.nextVersion}`,
      `version_code=${summary.nextCode}`,
      `tag=${summary.tag}`,
      `bump_type=${summary.bumpType}`,
      '',
    ].join('\n');
    appendFileSync(resolvedOut, lines, 'utf8');
  }

  console.log(JSON.stringify(summary, null, 2));
}

const isEntrypoint =
  process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url));
if (isEntrypoint) {
  runCli();
}
