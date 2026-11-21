#!/usr/bin/env node
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const tokensPath = resolve(__dirname, 'tokens.json');
const distDir = resolve(__dirname, 'dist');
const libDir = resolve(__dirname, 'lib');

mkdirSync(distDir, { recursive: true });
mkdirSync(libDir, { recursive: true });

const tokens = JSON.parse(readFileSync(tokensPath, 'utf8'));

/**
 * Converts a CSS color (#RRGGBB or rgba(r, g, b, a)) into a Dart Color(0xAARRGGBB) literal.
 */
function toDartColor(value) {
  if (typeof value !== 'string') {
    throw new Error(`Invalid color token: ${String(value)}`);
  }
  const trimmed = value.trim();
  if (trimmed.startsWith('#')) {
    const hex = trimmed.slice(1).toUpperCase();
    if (hex.length === 6) {
      return `Color(0xFF${hex})`;
    }
    if (hex.length === 8) {
      return `Color(0x${hex})`;
    }
    throw new Error(`Unsupported hex color: ${value}`);
  }
  const rgbaMatch = trimmed.match(
    /^rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})(?:\s*,\s*([\d.]+))?\s*\)$/i
  );
  if (rgbaMatch) {
    const r = Number(rgbaMatch[1]).toString(16).padStart(2, '0').toUpperCase();
    const g = Number(rgbaMatch[2]).toString(16).padStart(2, '0').toUpperCase();
    const b = Number(rgbaMatch[3]).toString(16).padStart(2, '0').toUpperCase();
    const alphaFloat = rgbaMatch[4] === undefined ? 1.0 : Number(rgbaMatch[4]);
    const a = Math.round(alphaFloat * 255)
      .toString(16)
      .padStart(2, '0')
      .toUpperCase();
    return `Color(0x${a}${r}${g}${b})`;
  }
  throw new Error(`Unsupported color format: ${value}`);
}

function buildCss(t) {
  const lines = [
    '/* GENERATED FILE - DO NOT EDIT DIRECTLY. */',
    '/* Source: packages/design-tokens/tokens.json via build-tokens.mjs */',
    '',
    ':root {',
    '  /* Colors: Backgrounds */',
    `  --nexus-bg-void: ${t.colors.bg.void};`,
    `  --nexus-bg-surface: ${t.colors.bg.surface};`,
    `  --nexus-bg-elevated: ${t.colors.bg.elevated};`,
    '',
    '  /* Colors: Borders */',
    `  --nexus-border-subtle: ${t.colors.border.subtle};`,
    `  --nexus-border-glow: ${t.colors.border.glow};`,
    '',
    '  /* Colors: Brand & Accent */',
    `  --nexus-brand-primary: ${t.colors.brand.primary};`,
    `  --nexus-brand-secondary: ${t.colors.brand.secondary};`,
    `  --nexus-accent-cyber: ${t.colors.accent.cyber};`,
    '',
    '  /* Colors: Semantic */',
    `  --nexus-semantic-success: ${t.colors.semantic.success};`,
    `  --nexus-semantic-warning: ${t.colors.semantic.warning};`,
    `  --nexus-semantic-danger: ${t.colors.semantic.danger};`,
    '',
    '  /* Colors: Text */',
    `  --nexus-text-primary: ${t.colors.text.primary};`,
    `  --nexus-text-secondary: ${t.colors.text.secondary};`,
    `  --nexus-text-muted: ${t.colors.text.muted};`,
    '',
    '  /* Gradients */',
    `  --nexus-gradient-brand: ${t.gradients.brandGradient.css};`,
    `  --nexus-gradient-scrim-card: ${t.gradients.scrimCard.css};`,
    `  --nexus-gradient-cyber-aura: ${t.gradients.cyberAura.css};`,
    '',
    '  /* Typography Families */',
    `  --nexus-font-display: '${t.typography.families.display}', system-ui, sans-serif;`,
    `  --nexus-font-body: '${t.typography.families.body}', system-ui, sans-serif;`,
    `  --nexus-font-mono: '${t.typography.families.mono}', ui-monospace, monospace;`,
    `  --nexus-type-scale-ratio: ${t.typography.scaleRatio};`,
    '',
    '  /* Typography Scale */',
  ];

  for (const [role, spec] of Object.entries(t.typography.roles)) {
    const kebab = role.replace(/[A-Z]/g, (m) => `-${m.toLowerCase()}`);
    lines.push(`  --nexus-text-${kebab}-size-mobile: ${spec.sizeMobilePx}px;`);
    lines.push(`  --nexus-text-${kebab}-size-web: ${spec.sizeWebPx}px;`);
    lines.push(`  --nexus-text-${kebab}-lh: ${spec.lineHeight};`);
    lines.push(`  --nexus-text-${kebab}-weight: ${spec.fontWeight};`);
    lines.push(`  --nexus-text-${kebab}-tracking: ${spec.letterSpacingEm}em;`);
  }

  lines.push('');
  lines.push('  /* Spacing (4px / 8px grid) */');
  for (const [key, val] of Object.entries(t.spacing)) {
    const kebab = key.replace(/[A-Z]/g, (m) => `-${m.toLowerCase()}`);
    lines.push(`  --nexus-space-${kebab}: ${val}px;`);
  }

  lines.push('');
  lines.push('  /* Radii */');
  for (const [key, val] of Object.entries(t.radii)) {
    lines.push(`  --nexus-radius-${key}: ${val}px;`);
  }

  lines.push('');
  lines.push('  /* Shadows */');
  for (const [key, val] of Object.entries(t.shadows)) {
    const kebab = key.replace(/[A-Z]/g, (m) => `-${m.toLowerCase()}`);
    lines.push(`  --nexus-shadow-${kebab}: ${val.css};`);
  }

  lines.push('');
  lines.push('  /* Breakpoints */');
  for (const [key, val] of Object.entries(t.breakpoints)) {
    const kebab = key.replace(/[A-Z]/g, (m) => `-${m.toLowerCase()}`);
    lines.push(`  --nexus-bp-${kebab}: ${val}px;`);
  }

  lines.push('}');
  lines.push('');
  return lines.join('\n');
}

function buildDart(t) {
  const brandStops = t.gradients.brandGradient.stops;
  const scrimStops = t.gradients.scrimCard.stops;
  const auraStops = t.gradients.cyberAura.stops;

  const lines = [
    '// GENERATED FILE - DO NOT EDIT DIRECTLY.',
    '// Source: packages/design-tokens/tokens.json via build-tokens.mjs',
    '',
    "import 'package:flutter/material.dart';",
    '',
    '/// Design tokens for the NEXUS DUO Cyber-Velvet & Obsidian Neon system.',
    'abstract final class NexusColors {',
    `  static const Color bgVoid = ${toDartColor(t.colors.bg.void)};`,
    `  static const Color bgSurface = ${toDartColor(t.colors.bg.surface)};`,
    `  static const Color bgElevated = ${toDartColor(t.colors.bg.elevated)};`,
    '',
    `  static const Color borderSubtle = ${toDartColor(t.colors.border.subtle)};`,
    `  static const Color borderGlow = ${toDartColor(t.colors.border.glow)};`,
    '',
    `  static const Color brandPrimary = ${toDartColor(t.colors.brand.primary)};`,
    `  static const Color brandSecondary = ${toDartColor(t.colors.brand.secondary)};`,
    `  static const Color accentCyber = ${toDartColor(t.colors.accent.cyber)};`,
    '',
    `  static const Color semanticSuccess = ${toDartColor(t.colors.semantic.success)};`,
    `  static const Color semanticWarning = ${toDartColor(t.colors.semantic.warning)};`,
    `  static const Color semanticDanger = ${toDartColor(t.colors.semantic.danger)};`,
    '',
    `  static const Color textPrimary = ${toDartColor(t.colors.text.primary)};`,
    `  static const Color textSecondary = ${toDartColor(t.colors.text.secondary)};`,
    `  static const Color textMuted = ${toDartColor(t.colors.text.muted)};`,
    '}',
    '',
    '/// Gradients shared across Cyber-Velvet surfaces and photo scrims.',
    'abstract final class NexusGradients {',
    '  static const LinearGradient brand = LinearGradient(',
    '    begin: Alignment.topLeft,',
    '    end: Alignment.bottomRight,',
    `    colors: <Color>[${toDartColor(brandStops[0].color)}, ${toDartColor(brandStops[1].color)}],`,
    `    stops: <double>[${brandStops[0].position}, ${brandStops[1].position}],`,
    '  );',
    '',
    '  static const LinearGradient scrimCard = LinearGradient(',
    '    begin: Alignment.bottomCenter,',
    '    end: Alignment.topCenter,',
    `    colors: <Color>[${toDartColor(scrimStops[0].color)}, ${toDartColor(scrimStops[1].color)}, ${toDartColor(scrimStops[2].color)}],`,
    `    stops: <double>[${scrimStops[0].position}, ${scrimStops[1].position}, ${scrimStops[2].position}],`,
    '  );',
    '',
    '  static const LinearGradient cyberAura = LinearGradient(',
    '    begin: Alignment.topLeft,',
    '    end: Alignment.bottomRight,',
    `    colors: <Color>[${toDartColor(auraStops[0].color)}, ${toDartColor(auraStops[1].color)}, ${toDartColor(auraStops[2].color)}],`,
    `    stops: <double>[${auraStops[0].position}, ${auraStops[1].position}, ${auraStops[2].position}],`,
    '  );',
    '}',
    '',
    '/// Typography specification aligned with Minor Third (1.200) scale.',
    'abstract final class NexusTypographyTokens {',
    `  static const String displayFont = '${t.typography.families.display}';`,
    `  static const String bodyFont = '${t.typography.families.body}';`,
    `  static const String monoFont = '${t.typography.families.mono}';`,
    `  static const double scaleRatio = ${t.typography.scaleRatio};`,
    '',
  ];

  for (const [role, spec] of Object.entries(t.typography.roles)) {
    lines.push(`  static const double ${role}SizeMobile = ${spec.sizeMobilePx}.0;`);
    lines.push(`  static const double ${role}SizeWeb = ${spec.sizeWebPx}.0;`);
    lines.push(`  static const double ${role}LineHeight = ${spec.lineHeight};`);
    lines.push(`  static const int ${role}Weight = ${spec.fontWeight};`);
    lines.push(`  static const double ${role}LetterSpacingEm = ${spec.letterSpacingEm};`);
  }

  lines.push('}');
  lines.push('');
  lines.push('/// 4px / 8px grid spacing constants.');
  lines.push('abstract final class NexusSpacing {');
  for (const [key, val] of Object.entries(t.spacing)) {
    lines.push(`  static const double ${key} = ${val}.0;`);
  }
  lines.push('}');
  lines.push('');
  lines.push('/// Border radius scale.');
  lines.push('abstract final class NexusRadii {');
  for (const [key, val] of Object.entries(t.radii)) {
    lines.push(`  static const double ${key} = ${val}.0;`);
  }
  lines.push('}');
  lines.push('');
  lines.push('/// Elevation and glow shadow tokens.');
  lines.push('abstract final class NexusShadows {');
  for (const [key, val] of Object.entries(t.shadows)) {
    lines.push(`  static const BoxShadow ${key} = BoxShadow(`);
    lines.push(`    color: ${toDartColor(val.color)},`);
    lines.push(`    offset: Offset(${val.offsetX}.0, ${val.offsetY}.0),`);
    lines.push(`    blurRadius: ${val.blur}.0,`);
    lines.push(`    spreadRadius: ${val.spread}.0,`);
    lines.push('  );');
  }
  lines.push('}');
  lines.push('');
  lines.push('/// Responsive breakpoints across Mobile, Tablet, and 2nd-Monitor Web.');
  lines.push('abstract final class NexusBreakpoints {');
  for (const [key, val] of Object.entries(t.breakpoints)) {
    lines.push(`  static const double ${key} = ${val}.0;`);
  }
  lines.push('}');
  lines.push('');
  return lines.join('\n');
}

const cssOut = buildCss(tokens);
const dartOut = buildDart(tokens);

writeFileSync(resolve(distDir, 'tokens.css'), cssOut, 'utf8');
writeFileSync(resolve(distDir, 'nexus_tokens.dart'), dartOut, 'utf8');
writeFileSync(resolve(libDir, 'nexus_tokens.dart'), dartOut, 'utf8');

console.log('Generated packages/design-tokens/dist/tokens.css');
console.log('Generated packages/design-tokens/dist/nexus_tokens.dart');
console.log('Generated packages/design-tokens/lib/nexus_tokens.dart');
