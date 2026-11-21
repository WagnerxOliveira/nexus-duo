import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';

import '../../features/profile/domain/gamer_profile.dart';
import '../theme/nexus_theme.dart';

/// Clamps system accessibility text scaling safely inside `[0.85, 1.35]`
/// so layouts stay fluid and readable without `RenderFlex` overflows.
class ResponsiveTextScaleGuard extends StatelessWidget {
  const ResponsiveTextScaleGuard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final clampedScaler = media.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.35,
    );
    return MediaQuery(
      data: media.copyWith(textScaler: clampedScaler),
      child: child,
    );
  }
}

/// Cyber-Velvet brand emblem combining Electric Violet and Cyber Cyan accents.
class NexusBrandLogo extends StatelessWidget {
  const NexusBrandLogo({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: compact ? 32 : 44,
          height: compact ? 32 : 44,
          decoration: BoxDecoration(
            gradient: NexusGradients.brand,
            borderRadius: BorderRadius.circular(compact ? 10 : 14),
            boxShadow: const <BoxShadow>[NexusShadows.glowPrimary],
          ),
          child: Icon(
            Icons.sports_esports_rounded,
            color: Colors.white,
            size: compact ? 18 : 24,
          ),
        ),
        const SizedBox(width: NexusSpacing.sm),
        Flexible(
          child: Text(
            'NEXUS DUO',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontSize: compact ? 16 : 22,
            ),
          ),
        ),
      ],
    );
  }
}

/// Primary CTA button with `NexusGradients.brand` and WCAG AA+ white label.
class NexusGradientButton extends StatelessWidget {
  const NexusGradientButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled
            ? NexusGradients.brand
            : LinearGradient(
                colors: <Color>[
                  NexusColors.brandPrimary.withValues(alpha: 0.35),
                  NexusColors.brandSecondary.withValues(alpha: 0.35),
                ],
              ),
        borderRadius: BorderRadius.circular(NexusRadii.md),
        boxShadow: enabled ? const <BoxShadow>[NexusShadows.glowPrimary] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(NexusRadii.md),
          onTap: enabled ? onPressed : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NexusSpacing.md,
                vertical: 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  else if (icon != null) ...<Widget>[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: NexusSpacing.sm),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cyber-Velvet elevated container with 1px subtle or glowing border.
class NexusGlassCard extends StatelessWidget {
  const NexusGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(NexusSpacing.md),
    this.glow = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NexusColors.bgSurface,
        borderRadius: BorderRadius.circular(NexusRadii.xl),
        border: Border.all(
          color: glow ? NexusColors.borderGlow : NexusColors.borderSubtle,
        ),
        boxShadow: glow
            ? const <BoxShadow>[NexusShadows.card, NexusShadows.glowPrimary]
            : const <BoxShadow>[NexusShadows.card],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Circular Neon Match Score Ring displaying `XX%` in tabular mono typography.
class MatchScoreRing extends StatelessWidget {
  const MatchScoreRing({required this.percent, this.size = 58, super.key});

  final int percent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: NexusColors.bgVoid.withValues(alpha: 0.82),
        boxShadow: clamped >= 85
            ? const <BoxShadow>[NexusShadows.glowPrimary]
            : null,
      ),
      child: CustomPaint(
        painter: _ScoreRingPainter(progress: clamped / 100.0),
        child: Center(
          child: Text(
            '$clamped%',
            maxLines: 1,
            style: NexusTheme.monoStat(
              fontSize: size * 0.25,
              color: clamped >= 85
                  ? NexusColors.semanticSuccess
                  : NexusColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.max(3.5, size.width * 0.08);
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;

    final trackPaint = Paint()
      ..color = NexusColors.borderSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);

    final sweepPaint = Paint()
      ..shader = NexusGradients.brand.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Cyber Cyan verified player seal (Selfie Liveness verified).
class VerifiedPlayerBadge extends StatelessWidget {
  const VerifiedPlayerBadge({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: NexusColors.accentCyber.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(NexusRadii.pill),
        border: Border.all(
          color: NexusColors.accentCyber.withValues(alpha: 0.65),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.verified_rounded,
            size: 14,
            color: NexusColors.accentCyber,
          ),
          if (!compact) ...<Widget>[
            const SizedBox(width: 4),
            const Text(
              'Verificado',
              style: TextStyle(
                color: NexusColors.accentCyber,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Stylized offline-safe portrait artwork with mandatory bottom scrim
/// guaranteeing WCAG AAA contrast for overlay names/tags.
class GamerPortraitArtwork extends StatelessWidget {
  const GamerPortraitArtwork({
    required this.profile,
    this.height = 300,
    super.key,
  });

  final GamerProfile profile;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c1 = Color(
      profile.avatarGradientHex.isNotEmpty
          ? profile.avatarGradientHex.first
          : 0xFF8B5CF6,
    );
    final c2 = Color(
      profile.avatarGradientHex.length > 1
          ? profile.avatarGradientHex[1]
          : 0xFFEC4899,
    );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  c1.withValues(alpha: 0.72),
                  NexusColors.bgElevated,
                  c2.withValues(alpha: 0.58),
                ],
              ),
            ),
          ),
          Positioned(
            right: -28,
            top: -28,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c2.withValues(alpha: 0.22),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: <Color>[c1, c2]),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 2.5,
                    ),
                    boxShadow: const <BoxShadow>[NexusShadows.glowPrimary],
                  ),
                  child: Center(
                    child: Text(
                      profile.initials,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: NexusSpacing.sm),
                Text(
                  '@${profile.username}',
                  style: NexusTheme.monoStat(
                    fontSize: 13,
                    color: NexusColors.textPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          // Mandatory Cyber-Velvet scrim ensuring AAA text legibility over imagery
          const DecoratedBox(
            decoration: BoxDecoration(gradient: NexusGradients.scrimCard),
          ),
        ],
      ),
    );
  }
}

/// Visual horizontal bars summarizing a player's Gamer DNA sliders.
class GamerDnaBars extends StatelessWidget {
  const GamerDnaBars({required this.dna, super.key});

  final GamerDna dna;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _DnaMetricRow(
          leftLabel: 'Casual',
          rightLabel: 'Competitivo',
          value: dna.competitiveScore,
          barColor: NexusColors.brandPrimary,
        ),
        const SizedBox(height: 10),
        _DnaMetricRow(
          leftLabel: 'Só Chat',
          rightLabel: 'Call de Voz',
          value: dna.voicePreferenceScore,
          barColor: NexusColors.accentCyber,
        ),
        const SizedBox(height: 10),
        _DnaMetricRow(
          leftLabel: 'Solo',
          rightLabel: 'Co-op / Duo',
          value: dna.coopFocusScore,
          barColor: NexusColors.brandSecondary,
        ),
      ],
    );
  }
}

class _DnaMetricRow extends StatelessWidget {
  const _DnaMetricRow({
    required this.leftLabel,
    required this.rightLabel,
    required this.value,
    required this.barColor,
  });

  final String leftLabel;
  final String rightLabel;
  final int value;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                leftLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            Text(
              '$value%',
              style: NexusTheme.monoStat(fontSize: 12, color: barColor),
            ),
            Expanded(
              child: Text(
                rightLabel,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(NexusRadii.pill),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: (value / 100.0).clamp(0.0, 1.0),
            backgroundColor: NexusColors.bgElevated,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}
