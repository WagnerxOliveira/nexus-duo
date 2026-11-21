#!/usr/bin/env node
/**
 * scripts/check-sql-security.mjs
 * Static Security & Integrity Validator for NEXUS DUO:
 * 1. Audits supabase/migrations/*.sql:
 *    - Balanced parentheses () and dollar-quotes ($$).
 *    - Enforces ENABLE ROW LEVEL SECURITY on every CREATE TABLE across all migrations.
 *    - Enforces SET search_path = public, pg_temp (or safe search_path) on every SECURITY DEFINER function.
 * 2. Audits apps/ (Mobile & Web client code):
 *    - Zero exposure of service_role keys or tokens in client code or client env templates.
 *
 * Exit code 0 on success, 1 on any violation.
 */

import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { resolve, join, relative } from 'node:path';

function printHelp() {
  console.log(`
NEXUS DUO — Static SQL & Client Security Auditor

Usage:
  node scripts/check-sql-security.mjs [options]

Options:
  --migrations, -m <dir>  Path to Supabase migrations folder (default: supabase/migrations)
  --apps, -a <dir>        Path to apps folder (default: apps)
  --help, -h              Show this help message
`);
}

function auditSqlSyntaxAndDefiner(filePath, relativePath) {
  const content = readFileSync(filePath, 'utf8');
  const issues = [];

  // Check 1: Balanced parentheses (ignoring string literals)
  let parenDepth = 0;
  const codeWithoutStrings = content.replace(/'(?:''|[^'])*'/g, (m) => ' '.repeat(m.length));
  for (let i = 0; i < codeWithoutStrings.length; i++) {
    const ch = codeWithoutStrings[i];
    if (ch === '(') parenDepth++;
    else if (ch === ')') {
      parenDepth--;
      if (parenDepth < 0) {
        issues.push({
          type: 'SYNTAX_ERROR',
          message: `Unmatched closing parenthesis ')' in ${relativePath} at char offset ${i}`,
        });
        break;
      }
    }
  }
  if (parenDepth > 0) {
    issues.push({
      type: 'SYNTAX_ERROR',
      message: `Unclosed open parenthesis '(' (${parenDepth} unclosed) in ${relativePath}`,
    });
  }

  // Check 2: Check dollar quotes balance ($$ or $tag$)
  const dollarQuoteMatches = content.match(/\$[a-zA-Z0-9_]*\$/g) || [];
  const dollarQuoteCounts = {};
  for (const tag of dollarQuoteMatches) {
    dollarQuoteCounts[tag] = (dollarQuoteCounts[tag] || 0) + 1;
  }
  for (const [tag, count] of Object.entries(dollarQuoteCounts)) {
    if (count % 2 !== 0) {
      issues.push({
        type: 'SYNTAX_ERROR',
        message: `Unbalanced dollar-quote tag "${tag}" (count: ${count}) in ${relativePath}`,
      });
    }
  }

  // Check 3: Check for SECURITY DEFINER functions without SET search_path
  const functionBlocks = content.split(/CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION/gi);
  if (functionBlocks.length > 1) {
    for (let f = 1; f < functionBlocks.length; f++) {
      const block = functionBlocks[f];
      if (/\bSECURITY\s+DEFINER\b/i.test(block)) {
        const nameMatch = block.match(/^\s*(?:([a-zA-Z0-9_]+)\.)?([a-zA-Z0-9_]+)/);
        const funcName = nameMatch ? nameMatch[0].trim() : `(unknown func #${f})`;

        const hasSafeSearchPath = /SET\s+search_path\s*(?:=|TO)\s*([^;\n]+)/i.test(block);
        if (!hasSafeSearchPath) {
          issues.push({
            type: 'SECURITY_DEFINER_SEARCH_PATH_MISSING',
            message: `Function "${funcName}" has SECURITY DEFINER without explicit "SET search_path = public, pg_temp" in ${relativePath}`,
          });
        }
      }
    }
  }

  return { content, issues };
}

function auditAppsDir(appsDir) {
  const issues = [];
  if (!existsSync(appsDir)) {
    return issues;
  }

  const ignoreDirs = new Set(['node_modules', '.next', '.dart_tool', 'dist', 'build', '.git', '.idea']);

  function scanDirectory(dir) {
    const entries = readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.isDirectory()) {
        if (!ignoreDirs.has(entry.name)) {
          scanDirectory(join(dir, entry.name));
        }
      } else if (entry.isFile()) {
        const ext = entry.name.split('.').pop()?.toLowerCase();
        if (
          ['dart', 'ts', 'tsx', 'js', 'mjs', 'json', 'yaml', 'yml', 'example', 'env'].some((e) =>
            entry.name.endsWith(e)
          )
        ) {
          const filePath = join(dir, entry.name);
          const rel = relative(process.cwd(), filePath).replace(/\\/g, '/');
          const content = readFileSync(filePath, 'utf8');

          if (
            /service_role/i.test(content) &&
            !entry.name.includes('check-sql-security') &&
            !entry.name.includes('README') &&
            !entry.name.includes('.test.') &&
            !entry.name.includes('.spec.')
          ) {
            issues.push({
              file: rel,
              type: 'SERVICE_ROLE_IN_CLIENT_APP',
              message: `Potential service_role key/role reference found in client application file: ${rel}`,
            });
          }
        }
      }
    }
  }

  scanDirectory(appsDir);
  return issues;
}

function main() {
  const args = process.argv.slice(2);
  if (args.includes('--help') || args.includes('-h')) {
    printHelp();
    process.exit(0);
  }

  let migrationsDir = resolve(process.cwd(), 'supabase/migrations');
  let appsDir = resolve(process.cwd(), 'apps');

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--migrations' || args[i] === '-m') {
      migrationsDir = resolve(process.cwd(), args[++i]);
    } else if (args[i] === '--apps' || args[i] === '-a') {
      appsDir = resolve(process.cwd(), args[++i]);
    }
  }

  console.log('='.repeat(70));
  console.log('🛡️  NEXUS DUO — Security & SQL Integrity Static Audit');
  console.log('='.repeat(70));

  let totalViolations = 0;

  // 1. Audit SQL Migrations
  console.log(`\n[1/3] Auditing SQL Migrations Syntax & Security Definer in: ${migrationsDir}`);
  const allCreatedTables = [];
  const allRlsEnabledTables = new Set();

  if (existsSync(migrationsDir)) {
    const migrationFiles = readdirSync(migrationsDir)
      .filter((f) => f.endsWith('.sql'))
      .sort();

    if (migrationFiles.length === 0) {
      console.log('  ℹ️  No .sql migration files found yet.');
    } else {
      for (const file of migrationFiles) {
        const fullPath = join(migrationsDir, file);
        const rel = relative(process.cwd(), fullPath).replace(/\\/g, '/');
        const { content, issues } = auditSqlSyntaxAndDefiner(fullPath, rel);

        if (issues.length === 0) {
          console.log(`  ✅ [PASS] ${rel}`);
        } else {
          console.error(`  ❌ [FAIL] ${rel}:`);
          for (const issue of issues) {
            console.error(`     - [${issue.type}] ${issue.message}`);
            totalViolations++;
          }
        }

        // Collect CREATE TABLE
        const createTableRegex = /CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:([a-zA-Z0-9_]+)\.)?([a-zA-Z0-9_]+)/gi;
        let match;
        while ((match = createTableRegex.exec(content)) !== null) {
          const schema = match[1] || 'public';
          const tableName = match[2];
          allCreatedTables.push({ schema, tableName, file: rel });
        }

        // Collect ALTER TABLE ... ENABLE ROW LEVEL SECURITY
        const rlsRegex = /ALTER\s+TABLE\s+(?:ONLY\s+)?(?:([a-zA-Z0-9_]+)\.)?([a-zA-Z0-9_]+)\s+ENABLE\s+ROW\s+LEVEL\s+SECURITY/gi;
        while ((match = rlsRegex.exec(content)) !== null) {
          const schema = match[1] || 'public';
          const tableName = match[2];
          allRlsEnabledTables.add(`${schema}.${tableName}`.toLowerCase());
          allRlsEnabledTables.add(tableName.toLowerCase());
        }
      }
    }
  } else {
    console.log(`  ℹ️  Migrations folder does not exist yet (${migrationsDir}).`);
  }

  // Check RLS coverage across all migrations
  console.log(`\n[2/3] Checking RLS Coverage for all Created Tables (${allCreatedTables.length} tables found)`);
  for (const table of allCreatedTables) {
    const fullName = `${table.schema}.${table.tableName}`.toLowerCase();
    const shortName = table.tableName.toLowerCase();
    if (allRlsEnabledTables.has(fullName) || allRlsEnabledTables.has(shortName)) {
      console.log(`  ✅ [RLS OK] ${table.schema}.${table.tableName}`);
    } else {
      console.error(`  ❌ [RLS MISSING] Table "${table.schema}.${table.tableName}" (defined in ${table.file}) does not have ENABLE ROW LEVEL SECURITY anywhere in migrations!`);
      totalViolations++;
    }
  }

  // 2. Audit Client Apps for Zero-Trust leaks
  console.log(`\n[3/3] Auditing Client Apps (Zero-Trust & Zero service_role) in: ${appsDir}`);
  const clientIssues = auditAppsDir(appsDir);
  if (clientIssues.length === 0) {
    console.log('  ✅ [PASS] Zero service_role leaks found across client applications.');
  } else {
    for (const issue of clientIssues) {
      console.error(`  ❌ [FAIL] ${issue.file}:`);
      console.error(`     - [${issue.type}] ${issue.message}`);
      totalViolations++;
    }
  }

  console.log('\n' + '='.repeat(70));
  if (totalViolations === 0) {
    console.log('🎉 AUDIT RESULT: ALL SECURITY CHECKS PASSED (0 violations)');
    console.log('='.repeat(70));
    process.exit(0);
  } else {
    console.error(`🚨 AUDIT RESULT: ${totalViolations} SECURITY VIOLATION(S) DETECTED`);
    console.log('='.repeat(70));
    process.exit(1);
  }
}

main();
