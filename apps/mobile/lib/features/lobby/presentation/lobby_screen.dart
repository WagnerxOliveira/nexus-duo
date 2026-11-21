import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/nexus_theme.dart';
import '../../../core/widgets/nexus_ui_kit.dart';
import '../domain/duo_lobby.dart';

/// Screen 5 — Lobby Efêmero "Duo Agora" (2h): feed em tempo real, filtros
/// por jogo/modo, contador regressivo e criação de lobby.
class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({super.key});

  static const List<String> _gameFilters = <String>[
    'Todos',
    'Valorant',
    'Stardew Valley',
    'Overwatch 2',
    'Baldur\'s Gate 3',
  ];

  String _formatRemaining(Duration remaining) {
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes}m restantes';
  }

  Future<void> _openCreateLobbySheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    var selectedGame = 'Valorant';
    var selectedMode = LobbyMode.casual;
    var selectedVoice = VoicePreference.discord;
    final notesController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NexusColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NexusRadii.xl),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                NexusSpacing.lg,
                NexusSpacing.lg,
                NexusSpacing.lg,
                MediaQuery.viewInsetsOf(context).bottom + NexusSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Abrir Lobby "Duo Agora" (expira em 2h)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: NexusSpacing.md),
                    Text(
                      'Jogo',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: NexusSpacing.sm),
                    Wrap(
                      spacing: NexusSpacing.sm,
                      runSpacing: NexusSpacing.sm,
                      children: _gameFilters
                          .where((g) => g != 'Todos')
                          .map(
                            (game) => ChoiceChip(
                              label: Text(game),
                              selected: selectedGame == game,
                              onSelected: (_) =>
                                  setModalState(() => selectedGame = game),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: NexusSpacing.md),
                    Text(
                      'Modo',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: NexusSpacing.sm),
                    Wrap(
                      spacing: NexusSpacing.sm,
                      runSpacing: NexusSpacing.sm,
                      children: LobbyMode.values
                          .map(
                            (mode) => ChoiceChip(
                              label: Text(mode.label),
                              selected: selectedMode == mode,
                              onSelected: (_) =>
                                  setModalState(() => selectedMode = mode),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: NexusSpacing.md),
                    Text(
                      'Comunicação',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: NexusSpacing.sm),
                    Wrap(
                      spacing: NexusSpacing.sm,
                      runSpacing: NexusSpacing.sm,
                      children: VoicePreference.values
                          .map(
                            (voice) => ChoiceChip(
                              label: Text(voice.label),
                              selected: selectedVoice == voice,
                              onSelected: (_) =>
                                  setModalState(() => selectedVoice = voice),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: NexusSpacing.md),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Convite rápido',
                        hintText: 'Ex.: 2 partidas sem tilt, call no Discord!',
                      ),
                    ),
                    const SizedBox(height: NexusSpacing.lg),
                    NexusGradientButton(
                      label: 'Publicar Lobby por 2 horas',
                      icon: Icons.bolt_rounded,
                      onPressed: () async {
                        final me = ref.read(myProfileProvider);
                        await ref
                            .read(lobbyRepositoryProvider)
                            .createLobby(
                              host: me,
                              gameTitle: selectedGame,
                              mode: selectedMode,
                              voicePreference: selectedVoice,
                              notes: notesController.text,
                            );
                        ref.invalidate(activeLobbiesProvider);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    notesController.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lobbiesAsync = ref.watch(activeLobbiesProvider);
    final selectedGame = ref.watch(lobbyGameFilterProvider);
    final selectedMode = ref.watch(lobbyModeFilterProvider);
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPad = width < NexusBreakpoints.mobileCompactMax
        ? NexusSpacing.pageCompact
        : NexusSpacing.pageStandard;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    NexusSpacing.md,
                    horizontalPad,
                    NexusSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Lobby "Duo Agora"',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                                Text(
                                  'Salas efêmeras de 2h para jogar sem ansiedade',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: NexusSpacing.sm),
                          FilledButton.icon(
                            onPressed: () =>
                                _openCreateLobbySheet(context, ref),
                            style: FilledButton.styleFrom(
                              backgroundColor: NexusColors.accentCyber,
                              foregroundColor: NexusColors.bgVoid,
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Criar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: NexusSpacing.md),
                      Wrap(
                        spacing: NexusSpacing.sm,
                        runSpacing: NexusSpacing.sm,
                        children: _gameFilters
                            .map(
                              (game) => ChoiceChip(
                                label: Text(game),
                                selected: selectedGame == game,
                                onSelected: (_) =>
                                    ref
                                            .read(
                                              lobbyGameFilterProvider.notifier,
                                            )
                                            .state =
                                        game,
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: NexusSpacing.sm),
                      Wrap(
                        spacing: NexusSpacing.sm,
                        runSpacing: NexusSpacing.sm,
                        children: <Widget>[
                          ChoiceChip(
                            label: const Text('Todos os modos'),
                            selected: selectedMode == null,
                            onSelected: (_) =>
                                ref
                                        .read(lobbyModeFilterProvider.notifier)
                                        .state =
                                    null,
                          ),
                          ...LobbyMode.values.map(
                            (mode) => ChoiceChip(
                              label: Text(mode.label),
                              selected: selectedMode == mode,
                              onSelected: (_) =>
                                  ref
                                          .read(
                                            lobbyModeFilterProvider.notifier,
                                          )
                                          .state =
                                      mode,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              lobbiesAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: NexusColors.accentCyber,
                    ),
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(horizontalPad),
                    child: Text('Erro ao carregar lobbies: $err'),
                  ),
                ),
                data: (lobbies) {
                  if (lobbies.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(horizontalPad),
                        child: NexusGlassCard(
                          child: Column(
                            children: <Widget>[
                              const Icon(
                                Icons.sports_esports_outlined,
                                size: 40,
                                color: NexusColors.textMuted,
                              ),
                              const SizedBox(height: NexusSpacing.sm),
                              Text(
                                'Nenhuma lobby ativa para este filtro.',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: NexusSpacing.sm),
                              NexusGradientButton(
                                label: 'Abrir minha Lobby Agora',
                                onPressed: () =>
                                    _openCreateLobbySheet(context, ref),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPad,
                      NexusSpacing.sm,
                      horizontalPad,
                      NexusSpacing.xl,
                    ),
                    sliver: SliverList.separated(
                      itemCount: lobbies.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: NexusSpacing.md),
                      itemBuilder: (context, index) {
                        final lobby = lobbies[index];
                        final remaining = lobby.remainingAt(DateTime.now());
                        return NexusGlassCard(
                          glow: index == 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      lobby.hostDisplayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                  ),
                                  if (lobby.hostVerified) ...<Widget>[
                                    const SizedBox(width: 6),
                                    const VerifiedPlayerBadge(compact: true),
                                  ],
                                  const SizedBox(width: NexusSpacing.sm),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: NexusColors.accentCyber.withValues(
                                        alpha: 0.16,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        NexusRadii.pill,
                                      ),
                                    ),
                                    child: Text(
                                      _formatRemaining(remaining),
                                      style: NexusTheme.monoStat(
                                        fontSize: 11,
                                        color: NexusColors.accentCyber,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: NexusSpacing.sm),
                              Wrap(
                                spacing: NexusSpacing.sm,
                                runSpacing: NexusSpacing.sm,
                                children: <Widget>[
                                  Chip(
                                    avatar: const Icon(
                                      Icons.videogame_asset_rounded,
                                      size: 16,
                                    ),
                                    label: Text(lobby.gameTitle),
                                  ),
                                  Chip(label: Text(lobby.mode.label)),
                                  Chip(
                                    label: Text(lobby.voicePreference.label),
                                  ),
                                  Chip(
                                    label: Text(
                                      '${lobby.compatibilityScore}% Match',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: NexusSpacing.sm),
                              Text(
                                lobby.notes,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: NexusSpacing.md),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: NexusGradientButton(
                                      label: 'Pedir Convite pro Duo',
                                      icon: Icons.bolt_rounded,
                                      onPressed: () {
                                        final handle =
                                            lobby.discordHandle ??
                                            '@${lobby.hostUsername}';
                                        Clipboard.setData(
                                          ClipboardData(text: handle),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Convite enviado! Discord $handle copiado.',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
