#!/usr/bin/env node
/**
 * scripts/generate-sha256.mjs
 * Cross-platform utility to generate and verify SHA256SUMS.txt for build artifacts (APKs, archives, binaries).
 *
 * Usage:
 *   node scripts/generate-sha256.mjs [options] [files...]
 *
 * Examples:
 *   node scripts/generate-sha256.mjs build/app/outputs/flutter-apk/*.apk
 *   node scripts/generate-sha256.mjs --dir apps/mobile/build/app/outputs/flutter-apk --output SHA256SUMS.txt
 *   node scripts/generate-sha256.mjs --check SHA256SUMS.txt
 */

import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, existsSync, statSync, readdirSync } from 'node:fs';
import { resolve, relative, basename, join } from 'node:path';

function printHelp() {
  console.log(`
NEXUS DUO — Cross-Platform SHA-256 Checksum Generator & Verifier

Usage:
  node scripts/generate-sha256.mjs [options] [files/patterns...]

Options:
  --output, -o <file>   Write generated checksums to file (default: stdout or SHA256SUMS.txt when --write is set)
  --write, -w           Write directly to SHA256SUMS.txt in the target directory or current directory
  --dir, -d <directory> Process all files in the specified directory (non-recursive by default)
  --recursive, -r       Recurse into subdirectories when using --dir
  --check, -c <file>    Verify files against an existing SHA256SUMS file
  --help, -h            Show this help message and exit

Format:
  <64-hex-sha256>  <filename>
`);
}

function computeFileSha256(filePath) {
  const fileBuffer = readFileSync(filePath);
  return createHash('sha256').update(fileBuffer).digest('hex');
}

function verifyChecksums(checksumFilePath) {
  const resolvedPath = resolve(process.cwd(), checksumFilePath);
  if (!existsSync(resolvedPath)) {
    console.error(`Error: Checksum file not found: ${resolvedPath}`);
    process.exit(1);
  }

  const baseDir = resolve(resolvedPath, '..');
  const content = readFileSync(resolvedPath, 'utf8');
  const lines = content.split(/\r?\n/).filter((l) => l.trim() && !l.trim().startsWith('#'));

  let verifiedCount = 0;
  let failedCount = 0;
  let missingCount = 0;

  console.log(`Verifying checksums from: ${resolvedPath}`);

  for (const line of lines) {
    const match = line.match(/^([a-fA-F0-9]{64})\s+[*]?(.+)$/);
    if (!match) {
      console.warn(`  [SKIP] Invalid format: "${line}"`);
      continue;
    }

    const expectedHash = match[1].toLowerCase();
    const fileName = match[2].trim();
    const targetFile = resolve(baseDir, fileName);

    if (!existsSync(targetFile)) {
      console.error(`  [MISSING] ${fileName}`);
      missingCount++;
      continue;
    }

    const actualHash = computeFileSha256(targetFile);
    if (actualHash === expectedHash) {
      console.log(`  [OK] ${fileName}`);
      verifiedCount++;
    } else {
      console.error(`  [FAILED] ${fileName}`);
      console.error(`    Expected: ${expectedHash}`);
      console.error(`    Actual:   ${actualHash}`);
      failedCount++;
    }
  }

  console.log(`\nVerification Summary: ${verifiedCount} OK, ${failedCount} FAILED, ${missingCount} MISSING`);
  if (failedCount > 0 || missingCount > 0) {
    process.exit(1);
  }
}

function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    printHelp();
    process.exit(0);
  }

  let outputFile = null;
  let checkFile = null;
  let targetDir = null;
  let recursive = false;
  let autoWrite = false;
  const inputFiles = [];

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--output' || arg === '-o') {
      outputFile = args[++i];
    } else if (arg === '--write' || arg === '-w') {
      autoWrite = true;
    } else if (arg === '--dir' || arg === '-d') {
      targetDir = args[++i];
    } else if (arg === '--recursive' || arg === '-r') {
      recursive = true;
    } else if (arg === '--check' || arg === '-c') {
      checkFile = args[++i];
    } else if (!arg.startsWith('-')) {
      inputFiles.push(arg);
    } else {
      console.error(`Unknown option: ${arg}`);
      printHelp();
      process.exit(1);
    }
  }

  if (checkFile) {
    verifyChecksums(checkFile);
    return;
  }

  const filesToHash = [];

  if (targetDir) {
    const scanDir = (dir) => {
      const entries = readdirSync(dir, { withFileTypes: true });
      for (const entry of entries) {
        const fullPath = join(dir, entry.name);
        if (entry.isDirectory() && recursive) {
          scanDir(fullPath);
        } else if (entry.isFile()) {
          // Avoid hashing the checksum file itself
          if (entry.name !== 'SHA256SUMS.txt') {
            filesToHash.push(fullPath);
          }
        }
      }
    };
    if (existsSync(targetDir)) {
      scanDir(targetDir);
    } else {
      console.error(`Directory not found: ${targetDir}`);
      process.exit(1);
    }
  }

  for (const f of inputFiles) {
    const resolved = resolve(process.cwd(), f);
    if (existsSync(resolved) && statSync(resolved).isFile()) {
      if (!filesToHash.includes(resolved)) {
        filesToHash.push(resolved);
      }
    } else {
      console.warn(`File not found: ${f}`);
    }
  }

  if (filesToHash.length === 0) {
    console.error('No valid files provided to hash.');
    process.exit(1);
  }

  const results = [];
  for (const file of filesToHash) {
    const hash = computeFileSha256(file);
    const relativeName = targetDir
      ? relative(targetDir, file).replace(/\\/g, '/')
      : relative(process.cwd(), file).replace(/\\/g, '/');
    results.push(`${hash}  ${relativeName}`);
  }

  const outputContent = results.join('\n') + '\n';

  if (autoWrite && !outputFile) {
    outputFile = targetDir ? join(targetDir, 'SHA256SUMS.txt') : 'SHA256SUMS.txt';
  }

  if (outputFile) {
    writeFileSync(outputFile, outputContent, 'utf8');
    console.log(`Generated ${results.length} checksum(s) -> ${outputFile}`);
  } else {
    process.stdout.write(outputContent);
  }
}

main();
