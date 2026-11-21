import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/nexus_ui_kit.dart';
import '../../chat/domain/chat_message.dart';
import '../../profile/domain/gamer_profile.dart';
import '../domain/discovery_entities.dart';

/// Screen 4 — Celebração de Match ("IT'S A DUO!") com avatares convergindo
/// em anel gradiente e 3 botões clicáveis de Co-op Icebreakers.
class MatchCelebrationScreen extends ConsumerWidget {
  const MatchCelebrationScreen({this.matchOverride, super.key});

  final DuoMatch? matchOverride;

  Future<void> _sendIcebreakerAndOpenChat(
    BuildContext context,
    WidgetRef ref,
    DuoMatch match,
    String prompt,
  ) async {
    final me = ref.read(myProfileProvider);
    await ref
        .read(chatRepositoryProvider)
        .sendMessage(
          match: match,
          senderId: me.id,
          plaintext: prompt,
          type: ChatMessageType.icebreaker,
        );
    if (!context.mounted) return;
    context.go('/chat/${match.id}', extra: match);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myProfileProvider);
    final match = matchOverride ?? ref.watch(latestCelebrationMatchProvider);

    if (match == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Match')),
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/app'),
            child: const Text('Voltar para Descoberta'),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(
              color: NexusColors.bgVoid,
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: <Color>[
                  Color(0x52EC4899),
                  Color(0x388B5CF6),
                  NexusColors.bgVoid,
                ],
                stops: <double>[0.0, 0.4, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(NexusSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () => context.go('/app'),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                      Text(
                        'IT\'S A DUO!',
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.displayLarge?.copyWith(letterSpacing: 1.5),
                      ),
                      const SizedBox(height: NexusSpacing.xs),
                      Text(
                        'Você e ${match.peer.displayName} deram match!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: NexusColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: NexusSpacing.xl),
                      // Converging dual avatars + gradient ring
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          _CelebrationAvatar(profile: me),
                          Transform.translate(
                            offset: const Offset(-10, 0),
                            child: MatchScoreRing(
                              percent: match.compatibilityScore,
                              size: 64,
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(-20, 0),
                            child: _CelebrationAvatar(profile: match.peer),
                          ),
                        ],
                      ),
                      const SizedBox(height: NexusSpacing.md),
                      Center(
                        child: Chip(
                          avatar: const Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: NexusColors.semanticSuccess,
                          ),
                          label: Text(
                            '${match.commonHoursPerWeek}h/sem livres em comum',
                          ),
                        ),
                      ),
                      const SizedBox(height: NexusSpacing.xl),
                      Text(
                        'QUEBRE O GELO EM 1 TOQUE (CO-OP ICEBREAKERS)',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: NexusColors.accentCyber,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: NexusSpacing.md),
                      for (final prompt in match.icebreakerPrompts) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: NexusSpacing.sm,
                          ),
                          child: InkWell(
                            onTap: () => _sendIcebreakerAndOpenChat(
                              context,
                              ref,
                              match,
                              prompt,
                            ),
                            borderRadius: BorderRadius.circular(NexusRadii.lg),
                            child: Container(
                              padding: const EdgeInsets.all(NexusSpacing.md),
                              decoration: BoxDecoration(
                                color: NexusColors.bgSurface,
                                borderRadius: BorderRadius.circular(
                                  NexusRadii.lg,
                                ),
                                border: Border.all(
                                  color: NexusColors.borderGlow,
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.sports_esports_outlined,
                                    color: NexusColors.brandSecondary,
                                  ),
                                  const SizedBox(width: NexusSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      prompt,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: NexusColors.textPrimary,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: NexusSpacing.sm),
                                  const Icon(
                                    Icons.send_rounded,
                                    size: 18,
                                    color: NexusColors.accentCyber,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: NexusSpacing.md),
                      NexusGradientButton(
                        label: 'Abrir Chat E2EE Agora',
                        icon: Icons.lock_rounded,
                        onPressed: () =>
                            context.go('/chat/${match.id}', extra: match),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CelebrationAvatar extends StatelessWidget {
  const _CelebrationAvatar({required this.profile});

  final GamerProfile profile;

  @override
  Widget build(BuildContext context) {
    final c1 = Color(profile.avatarGradientHex.first);
    final c2 = Color(profile.avatarGradientHex.last);
    return Container(
      width: 84,
      height: 84,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: NexusGradients.brand,
        boxShadow: <BoxShadow>[NexusShadows.glowMatch],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: <Color>[c1, c2]),
        ),
        child: Center(
          child: Text(
            profile.initials,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
