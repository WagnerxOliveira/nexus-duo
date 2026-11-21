#!/usr/bin/env node
/**
 * scripts/sync-person-names.mjs
 * Compiles packages/contracts/person_names_blocklist.json into:
 *   - apps/mobile/lib/core/security/person_names_blocklist.g.dart
 *   - supabase/functions/_shared/person_names_blocklist.ts
 */

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const contractPath = resolve(process.cwd(), 'packages/contracts/person_names_blocklist.json');
const contract = JSON.parse(readFileSync(contractPath, 'utf8'));

const allNames = new Set([
  ...(contract.br_first_names ?? []),
  ...(contract.br_surnames ?? []),
  ...(contract.intl_names ?? []),
]);

const short3 = [...allNames].filter((n) => n.length === 3).sort();
const standard4Plus = [...allNames].filter((n) => n.length >= 4).sort();

const formatListLines = (items, indent = '  ') => {
  const lines = [];
  for (let i = 0; i < items.length; i += 8) {
    const chunk = items.slice(i, i + 8).map((s) => `'${s}'`).join(', ');
    lines.push(`${indent}${chunk},`);
  }
  return lines.join('\n');
};

const dartOutPath = resolve(process.cwd(), 'apps/mobile/lib/core/security/person_names_blocklist.g.dart');
mkdirSync(dirname(dartOutPath), { recursive: true });
const dartContent = `// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: packages/contracts/person_names_blocklist.json
// Generator: node scripts/sync-person-names.mjs

/// 3-letter person names matched strictly as full alphabetic tokens.
const Set<String> kShortPersonNames3 = <String>{
${formatListLines(short3)}
};

/// 4+ letter person names (IBGE BR + BR surnames + international) matched
/// across whole alphabetic tokens and contiguous substrings.
const Set<String> kPersonNamesBlocklist = <String>{
${formatListLines(standard4Plus)}
};
`;
writeFileSync(dartOutPath, dartContent, 'utf8');

const tsOutPath = resolve(process.cwd(), 'supabase/functions/_shared/person_names_blocklist.ts');
mkdirSync(dirname(tsOutPath), { recursive: true });
const tsContent = `// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: packages/contracts/person_names_blocklist.json
// Generator: node scripts/sync-person-names.mjs

export const SHORT_PERSON_NAMES_3: ReadonlySet<string> = new Set([
${formatListLines(short3, '  ')}
]);

export const PERSON_NAMES_BLOCKLIST: ReadonlySet<string> = new Set([
${formatListLines(standard4Plus, '  ')}
]);
`;
writeFileSync(tsOutPath, tsContent, 'utf8');

console.log(
  `Synced blocklist -> Dart & Deno TypeScript: ${short3.length} short (3-char) + ${standard4Plus.length} standard (4+ char) entries.`,
);
