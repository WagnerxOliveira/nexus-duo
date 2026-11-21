// GENERATED FILE - DO NOT EDIT DIRECTLY.
// Source: packages/design-tokens/tokens.json via build-tokens.mjs

import 'package:flutter/material.dart';

/// Design tokens for the NEXUS DUO Cyber-Velvet & Obsidian Neon system.
abstract final class NexusColors {
  static const Color bgVoid = Color(0xFF080A0F);
  static const Color bgSurface = Color(0xFF111521);
  static const Color bgElevated = Color(0xFF191F31);

  static const Color borderSubtle = Color(0x14FFFFFF);
  static const Color borderGlow = Color(0x738B5CF6);

  static const Color brandPrimary = Color(0xFF8B5CF6);
  static const Color brandSecondary = Color(0xFFEC4899);
  static const Color accentCyber = Color(0xFF06B6D4);

  static const Color semanticSuccess = Color(0xFF10B981);
  static const Color semanticWarning = Color(0xFFF59E0B);
  static const Color semanticDanger = Color(0xFFEF4444);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
}

/// Gradients shared across Cyber-Velvet surfaces and photo scrims.
abstract final class NexusGradients {
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF8B5CF6), Color(0xFFEC4899)],
    stops: <double>[0, 1],
  );

  static const LinearGradient scrimCard = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: <Color>[Color(0xF2080A0F), Color(0x8C080A0F), Color(0x00080A0F)],
    stops: <double>[0, 0.45, 1],
  );

  static const LinearGradient cyberAura = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0x388B5CF6), Color(0x2906B6D4), Color(0x24EC4899)],
    stops: <double>[0, 0.5, 1],
  );
}

/// Typography specification aligned with Minor Third (1.200) scale.
abstract final class NexusTypographyTokens {
  static const String displayFont = 'Space Grotesk';
  static const String bodyFont = 'Plus Jakarta Sans';
  static const String monoFont = 'JetBrains Mono';
  static const double scaleRatio = 1.2;

  static const double displayXlSizeMobile = 32.0;
  static const double displayXlSizeWeb = 44.0;
  static const double displayXlLineHeight = 1.15;
  static const int displayXlWeight = 700;
  static const double displayXlLetterSpacingEm = -0.03;
  static const double headingLgSizeMobile = 24.0;
  static const double headingLgSizeWeb = 24.0;
  static const double headingLgLineHeight = 1.2;
  static const int headingLgWeight = 700;
  static const double headingLgLetterSpacingEm = -0.02;
  static const double headingMdSizeMobile = 18.0;
  static const double headingMdSizeWeb = 18.0;
  static const double headingMdLineHeight = 1.3;
  static const int headingMdWeight = 600;
  static const double headingMdLetterSpacingEm = -0.01;
  static const double bodyLgSizeMobile = 16.0;
  static const double bodyLgSizeWeb = 16.0;
  static const double bodyLgLineHeight = 1.5;
  static const int bodyLgWeight = 400;
  static const double bodyLgLetterSpacingEm = 0;
  static const double bodyMdSizeMobile = 14.0;
  static const double bodyMdSizeWeb = 14.0;
  static const double bodyMdLineHeight = 1.45;
  static const int bodyMdWeight = 500;
  static const double bodyMdLetterSpacingEm = 0;
  static const double labelSmSizeMobile = 12.0;
  static const double labelSmSizeWeb = 12.0;
  static const double labelSmLineHeight = 1.3;
  static const int labelSmWeight = 600;
  static const double labelSmLetterSpacingEm = 0.04;
  static const double monoStatSizeMobile = 14.0;
  static const double monoStatSizeWeb = 20.0;
  static const double monoStatLineHeight = 1.1;
  static const int monoStatWeight = 700;
  static const double monoStatLetterSpacingEm = -0.02;
}

/// 4px / 8px grid spacing constants.
abstract final class NexusSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double pageCompact = 16.0;
  static const double pageStandard = 20.0;
  static const double pageDesktop = 32.0;
}

/// Border radius scale.
abstract final class NexusRadii {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double pill = 9999.0;
}

/// Elevation and glow shadow tokens.
abstract final class NexusShadows {
  static const BoxShadow card = BoxShadow(
    color: Color(0x73000000),
    offset: Offset(0.0, 16.0),
    blurRadius: 40.0,
    spreadRadius: -8.0,
  );
  static const BoxShadow glowPrimary = BoxShadow(
    color: Color(0x598B5CF6),
    offset: Offset(0.0, 0.0),
    blurRadius: 24.0,
    spreadRadius: 0.0,
  );
  static const BoxShadow glowCyber = BoxShadow(
    color: Color(0x4D06B6D4),
    offset: Offset(0.0, 0.0),
    blurRadius: 20.0,
    spreadRadius: 0.0,
  );
  static const BoxShadow glowMatch = BoxShadow(
    color: Color(0x61EC4899),
    offset: Offset(0.0, 0.0),
    blurRadius: 28.0,
    spreadRadius: 0.0,
  );
}

/// Responsive breakpoints across Mobile, Tablet, and 2nd-Monitor Web.
abstract final class NexusBreakpoints {
  static const double mobileCompactMax = 380.0;
  static const double tabletMin = 600.0;
  static const double desktopMin = 1024.0;
  static const double ultrawideMin = 1440.0;
}
