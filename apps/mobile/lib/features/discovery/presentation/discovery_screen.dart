import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/nexus_theme.dart';
import '../../../core/widgets/nexus_ui_kit.dart';
import '../domain/discovery_entities.dart';
import '../domain/match_scoring_strategy.dart';

/// Screen 3 — Descoberta: Deck "Daily Loot Drop".
class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  bool _isSubmitting = false;

  Future<void> _handleSwipe(
    DiscoveryCandidate candidate,
    SwipeAction action,
  ) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final me = ref.read(myProfileProvider);
    final result = await ref
        .read(discoveryRepositoryProvider)
        .submitSwipe(
          me: me,
          candidate: candidate,
          action: action,
          introNote: action == SwipeAction.superDuo
              ? 'Super Duo enviado! Bora uma partida hoje?'
              : null,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.fold(
      onSuccess: (match) {
        ref.invalidate(discoveryDeckProvider);
        ref.invalidate(matchesProvider);
        if (match != null) {
          ref.read(latestCelebrationMatchProvider.notifier).state = match;
          context.push('/match-celebration');
        }
      },
      onFailure: (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  void _toggleStrategy() {
    final current = ref.read(scoringStrategyProvider);
    ref
        .read(scoringStrategyProvider.notifier)
        .state = current is HybridGamerScoringStrategy
        ? const CoopDuoScoringStrategy()
        : const HybridGamerScoringStrategy();
  }

  @override
  Widget build(BuildContext context) {
    final deckAsync = ref.watch(discoveryDeckProvider);
    final strategy = ref.watch(scoringStrategyProvider);
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = width < NexusBreakpoints.mobileCompactMax
        ? NexusSpacing.pageCompact
        : NexusSpacing.pageStandard;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: <Widget>[
              // Top header
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  NexusSpacing.md,
                  horizontalPad,
                  NexusSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Daily Loot Drop',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(
                            'Próximo drop curado às 20:00 • Sem swipe infinito',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: NexusSpacing.sm),
                    ActionChip(
                      onPressed: _toggleStrategy,
                      avatar: const Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: NexusColors.accentCyber,
                      ),
                      label: Text(
                        strategy is HybridGamerScoringStrategy
                            ? 'Híbrido'
                            : 'Co-op Duo',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: deckAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: NexusColors.brandPrimary,
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(NexusSpacing.lg),
                      child: Text('Erro ao carregar deck: $err'),
                    ),
                  ),
                  data: (candidates) {
                    if (candidates.isEmpty) {
                      return _buildEmptyLootDrop(context, horizontalPad);
                    }
                    final top = candidates.first;
                    return Column(
                      children: <Widget>[
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPad,
                            ),
                            child: _DiscoveryCandidateCard(candidate: top),
                          ),
                        ),
                        // Thumb Zone Action Bar
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPad,
                            NexusSpacing.sm,
                            horizontalPad,
                            NexusSpacing.md,
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: _ThumbActionButton(
                                  tooltip: 'Passar',
                                  icon: Icons.close_rounded,
                                  label: 'Passar',
                                  color: NexusColors.textSecondary,
                                  onTap: () =>
                                      _handleSwipe(top, SwipeAction.pass),
                                ),
                              ),
                              Expanded(
                                child: _ThumbActionButton(
                                  tooltip: 'Super Duo',
                                  icon: Icons.sports_esports_rounded,
                                  label: 'Super Duo',
                                  color: NexusColors.accentCyber,
                                  highlighted: true,
                                  onTap: () =>
                                      _handleSwipe(top, SwipeAction.superDuo),
                                ),
                              ),
                              Expanded(
                                child: _ThumbActionButton(
                                  tooltip: 'Curtir',
                                  icon: Icons.favorite_rounded,
                                  label: 'Curtir',
                                  color: NexusColors.brandSecondary,
                                  onTap: () =>
                                      _handleSwipe(top, SwipeAction.like),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyLootDrop(BuildContext context, double pad) {
    return Padding(
      padding: EdgeInsets.all(pad),
      child: Center(
        child: NexusGlassCard(
          glow: true,
          padding: const EdgeInsets.all(NexusSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.auto_awesome_rounded,
                size: 48,
                color: NexusColors.brandPrimary,
              ),
              const SizedBox(height: NexusSpacing.md),
              Text(
                'Drop de hoje concluído!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: NexusSpacing.sm),
              Text(
                'Para evitar fadiga de swipe, novos perfis de alta afinidade chegam às 20:00. Enquanto isso, explore a Lobby Duo Agora!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: NexusSpacing.lg),
              NexusGradientButton(
                label: 'Recarregar Deck Demo',
                icon: Icons.refresh_rounded,
                onPressed: () {
                  ref.read(demoSeedStoreProvider).swipedIds.clear();
                  ref.invalidate(discoveryDeckProvider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoveryCandidateCard extends StatelessWidget {
  const _DiscoveryCandidateCard({required this.candidate});

  final DiscoveryCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final profile = candidate.profile;
    final breakdown = candidate.breakdown;

    return Container(
      decoration: BoxDecoration(
        color: NexusColors.bgSurface,
        borderRadius: BorderRadius.circular(NexusRadii.xl),
        border: Border.all(color: NexusColors.borderGlow),
        boxShadow: const <BoxShadow>[NexusShadows.card],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Portrait with mandatory scrim + Match Score Ring + Identity overlay
            Stack(
              children: <Widget>[
                GamerPortraitArtwork(profile: profile, height: 270),
                Positioned(
                  top: NexusSpacing.md,
                  right: NexusSpacing.md,
                  child: MatchScoreRing(
                    percent: breakdown.totalScorePercent,
                    size: 62,
                  ),
                ),
                if (profile.isLivenessVerified)
                  const Positioned(
                    top: NexusSpacing.md,
                    left: NexusSpacing.md,
                    child: VerifiedPlayerBadge(),
                  ),
                Positioned(
                  left: NexusSpacing.md,
                  right: NexusSpacing.md,
                  bottom: NexusSpacing.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '${profile.displayName}, ${profile.age.years}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(color: NexusColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: NexusSpacing.sm,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: NexusColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${profile.cityLabel} • ${profile.distanceKmBucket}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: NexusColors.semanticSuccess.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(
                                NexusRadii.pill,
                              ),
                              border: Border.all(
                                color: NexusColors.semanticSuccess.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            child: Text(
                              '${breakdown.commonHoursPerWeek}h livres em comum',
                              style: NexusTheme.monoStat(
                                fontSize: 11,
                                color: NexusColors.semanticSuccess,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Card scrollable body: Shared games, Bio, Prompt, Gamer DNA, OCR Ranks, GG Badges
            Padding(
              padding: const EdgeInsets.all(NexusSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (breakdown.commonGames.isNotEmpty) ...<Widget>[
                    Text(
                      'JOGOS EM COMUM',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: NexusColors.accentCyber,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: NexusSpacing.sm),
                    Wrap(
                      spacing: NexusSpacing.sm,
                      runSpacing: NexusSpacing.sm,
                      children: breakdown.commonGames
                          .map(
                            (game) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: NexusColors.brandPrimary.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(
                                  NexusRadii.pill,
                                ),
                                border: Border.all(
                                  color: NexusColors.borderGlow,
                                ),
                              ),
                              child: Text(
                                game,
                                style: const TextStyle(
                                  color: NexusColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: NexusSpacing.md),
                  ],
                  Text(
                    profile.bio,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: NexusSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(NexusSpacing.md),
                    decoration: BoxDecoration(
                      color: NexusColors.bgElevated,
                      borderRadius: BorderRadius.circular(NexusRadii.lg),
                      border: Border.all(color: NexusColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          profile.promptQuestion,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: NexusColors.brandSecondary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          profile.promptAnswer,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: NexusSpacing.md),
                  Text(
                    'Gamer DNA • ${profile.gamerDna.archetypeTitle}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: NexusSpacing.sm),
                  GamerDnaBars(dna: profile.gamerDna),
                  const SizedBox(height: NexusSpacing.md),
                  Text(
                    'Ranks & Biblioteca',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: NexusSpacing.sm),
                  Wrap(
                    spacing: NexusSpacing.sm,
                    runSpacing: NexusSpacing.sm,
                    children: profile.games.map((g) {
                      final label = g.rankLabel != null
                          ? '${g.title} • ${g.rankLabel}${g.isRankOcrVerified ? ' ✓OCR' : ''}'
                          : g.title;
                      return Chip(label: Text(label));
                    }).toList(),
                  ),
                  if (profile.ggBadges.isNotEmpty) ...<Widget>[
                    const SizedBox(height: NexusSpacing.md),
                    Text(
                      'GG Fair Play Badges',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: NexusSpacing.sm),
                    Wrap(
                      spacing: NexusSpacing.sm,
                      runSpacing: NexusSpacing.sm,
                      children: profile.ggBadges
                          .map(
                            (b) => Chip(label: Text('${b.emoji} ${b.label}')),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbActionButton extends StatelessWidget {
  const _ThumbActionButton({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.highlighted = false,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NexusRadii.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: highlighted ? 58 : 52,
                height: highlighted ? 58 : 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: highlighted ? 0.22 : 0.14),
                  border: Border.all(
                    color: color.withValues(alpha: 0.7),
                    width: highlighted ? 2 : 1.2,
                  ),
                  boxShadow: highlighted
                      ? const <BoxShadow>[NexusShadows.glowCyber]
                      : null,
                ),
                child: Icon(icon, color: color, size: highlighted ? 28 : 24),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
