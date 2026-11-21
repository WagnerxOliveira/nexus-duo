import 'package:flutter/material.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';

/// Cyber-Velvet & Obsidian Neon Material 3 theme powered by `nexus_design_tokens`.
///
/// Uses local font family declarations with deterministic system fallbacks so
/// tests and offline environments never block on remote Google Font fetches.
abstract final class NexusTheme {
  static const List<String> _displayFallback = <String>[
    'Space Grotesk',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  static const List<String> _bodyFallback = <String>[
    'Plus Jakarta Sans',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  static const List<String> _monoFallback = <String>[
    'JetBrains Mono',
    'Consolas',
    'monospace',
  ];

  static TextStyle monoStat({
    double fontSize = NexusTypographyTokens.monoStatSizeMobile,
    Color color = NexusColors.textPrimary,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return TextStyle(
      fontFamily: NexusTypographyTokens.monoFont,
      fontFamilyFallback: _monoFallback,
      fontSize: fontSize,
      height: NexusTypographyTokens.monoStatLineHeight,
      fontWeight: fontWeight,
      letterSpacing: fontSize * NexusTypographyTokens.monoStatLetterSpacingEm,
      color: color,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: NexusColors.brandPrimary,
      onPrimary: Colors.white,
      secondary: NexusColors.brandSecondary,
      onSecondary: Colors.white,
      tertiary: NexusColors.accentCyber,
      onTertiary: NexusColors.bgVoid,
      surface: NexusColors.bgSurface,
      onSurface: NexusColors.textPrimary,
      surfaceContainerHighest: NexusColors.bgElevated,
      error: NexusColors.semanticDanger,
      onError: Colors.white,
      outline: NexusColors.borderSubtle,
    );

    const baseTextTheme = TextTheme(
      displayLarge: TextStyle(
        fontFamily: NexusTypographyTokens.displayFont,
        fontFamilyFallback: _displayFallback,
        fontSize: NexusTypographyTokens.displayXlSizeMobile,
        height: NexusTypographyTokens.displayXlLineHeight,
        fontWeight: FontWeight.w700,
        letterSpacing:
            NexusTypographyTokens.displayXlSizeMobile *
            NexusTypographyTokens.displayXlLetterSpacingEm,
        color: NexusColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontFamily: NexusTypographyTokens.displayFont,
        fontFamilyFallback: _displayFallback,
        fontSize: NexusTypographyTokens.headingLgSizeMobile,
        height: NexusTypographyTokens.headingLgLineHeight,
        fontWeight: FontWeight.w700,
        letterSpacing:
            NexusTypographyTokens.headingLgSizeMobile *
            NexusTypographyTokens.headingLgLetterSpacingEm,
        color: NexusColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontFamily: NexusTypographyTokens.displayFont,
        fontFamilyFallback: _displayFallback,
        fontSize: NexusTypographyTokens.headingMdSizeMobile,
        height: NexusTypographyTokens.headingMdLineHeight,
        fontWeight: FontWeight.w600,
        letterSpacing:
            NexusTypographyTokens.headingMdSizeMobile *
            NexusTypographyTokens.headingMdLetterSpacingEm,
        color: NexusColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontFamily: NexusTypographyTokens.bodyFont,
        fontFamilyFallback: _bodyFallback,
        fontSize: NexusTypographyTokens.bodyLgSizeMobile,
        height: NexusTypographyTokens.bodyLgLineHeight,
        fontWeight: FontWeight.w400,
        color: NexusColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: NexusTypographyTokens.bodyFont,
        fontFamilyFallback: _bodyFallback,
        fontSize: NexusTypographyTokens.bodyMdSizeMobile,
        height: NexusTypographyTokens.bodyMdLineHeight,
        fontWeight: FontWeight.w500,
        color: NexusColors.textSecondary,
      ),
      labelMedium: TextStyle(
        fontFamily: NexusTypographyTokens.bodyFont,
        fontFamilyFallback: _bodyFallback,
        fontSize: NexusTypographyTokens.labelSmSizeMobile,
        height: NexusTypographyTokens.labelSmLineHeight,
        fontWeight: FontWeight.w600,
        letterSpacing:
            NexusTypographyTokens.labelSmSizeMobile *
            NexusTypographyTokens.labelSmLetterSpacingEm,
        color: NexusColors.textPrimary,
      ),
      labelSmall: TextStyle(
        fontFamily: NexusTypographyTokens.bodyFont,
        fontFamilyFallback: _bodyFallback,
        fontSize: 11,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: NexusColors.textMuted,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: NexusColors.bgVoid,
      canvasColor: NexusColors.bgVoid,
      textTheme: baseTextTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: NexusColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: NexusColors.bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NexusRadii.xl),
          side: const BorderSide(color: NexusColors.borderSubtle),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NexusColors.bgElevated,
        hintStyle: const TextStyle(color: NexusColors.textMuted),
        labelStyle: const TextStyle(color: NexusColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: NexusSpacing.md,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexusRadii.md),
          borderSide: const BorderSide(color: NexusColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexusRadii.md),
          borderSide: const BorderSide(color: NexusColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexusRadii.md),
          borderSide: const BorderSide(
            color: NexusColors.brandPrimary,
            width: 1.5,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: NexusColors.bgElevated,
        selectedColor: NexusColors.brandPrimary.withValues(alpha: 0.28),
        side: const BorderSide(color: NexusColors.borderSubtle),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NexusRadii.pill),
        ),
        labelStyle: const TextStyle(
          color: NexusColors.textPrimary,
          fontSize: NexusTypographyTokens.labelSmSizeMobile,
          fontWeight: FontWeight.w600,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: NexusColors.brandPrimary,
        inactiveTrackColor: NexusColors.bgElevated,
        thumbColor: NexusColors.brandSecondary,
        overlayColor: NexusColors.brandSecondary.withValues(alpha: 0.2),
      ),
      dividerTheme: const DividerThemeData(
        color: NexusColors.borderSubtle,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: NexusColors.bgElevated,
        contentTextStyle: const TextStyle(color: NexusColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NexusRadii.md),
          side: const BorderSide(color: NexusColors.borderGlow),
        ),
      ),
    );
  }
}
