import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/nexus_theme.dart';
import '../../../core/updater/github_release_updater.dart';
import '../../../core/widgets/nexus_ui_kit.dart';
import '../domain/gamer_profile.dart';

/// Screen 7 — Perfil & Gamer DNA Shareable Card (`9:16` via `RepaintBoundary`)
/// + Central LGPD (exportar JSON / excluir conta)
/// + GitHubReleaseUpdater (`WagnerxOliveira/nexus-duo/releases/latest` com SHA-256).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final GlobalKey _shareCardKey = GlobalKey();
  ReleaseUpdateInfo? _updateInfo;
  String? _updateStatus;
  bool _checkingUpdate = false;
  bool _exportingCard = false;

  Future<void> _exportShareableCard() async {
    setState(() => _exportingCard = true);
    try {
      final boundary =
          _shareCardKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final kb = ((byteData?.lengthInBytes ?? 0) / 1024).toStringAsFixed(1);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gamer DNA Card 9:16 renderizado ($kb KB PNG) pronto para Stories!',
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _exportingCard = false);
    }
  }

  Future<void> _checkUpdates() async {
    setState(() {
      _checkingUpdate = true;
      _updateStatus = null;
    });
    final res = await ref
        .read(releaseUpdaterProvider)
        .checkForUpdate(force: true);
    if (!mounted) return;
    setState(() {
      _checkingUpdate = false;
      res.fold(
        onSuccess: (info) {
          _updateInfo = info;
          _updateStatus = info.hasUpdate
              ? 'Nova versão v${info.latestVersion} disponível (SHA-256 verificado)!'
              : 'Você está na versão mais recente (v${info.currentVersion}).';
        },
        onFailure: (failure) => _updateStatus = failure.message,
      );
    });
  }

  Future<void> _exportLgpdJson() async {
    final res = await ref.read(profileRepositoryProvider).exportLgpdJson();
    if (!mounted) return;
    res.fold(
      onSuccess: (jsonMap) {
        const encoder = JsonEncoder.withIndent('  ');
        final formatted = encoder.convert(jsonMap);
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: NexusColors.bgSurface,
            title: const Text('Portabilidade LGPD (JSON)'),
            content: SingleChildScrollView(
              child: SelectableText(
                formatted,
                style: NexusTheme.monoStat(
                  fontSize: 11,
                  color: NexusColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Fechar'),
              ),
            ],
          ),
        );
      },
      onFailure: (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NexusColors.bgSurface,
        title: const Text('Excluir conta permanentemente?'),
        content: const Text(
          'Esta ação aplica exclusão LGPD completa (`ON DELETE CASCADE`), revoga sessões e remove suas chaves locais.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NexusColors.semanticDanger,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir Conta'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(profileRepositoryProvider).deleteMyAccount();
    ref.read(authSessionProvider.notifier).state = null;
    if (mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < NexusBreakpoints.mobileCompactMax
        ? NexusSpacing.pageCompact
        : NexusSpacing.pageStandard;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Meu Perfil & Gamer DNA',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.push('/onboarding'),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar'),
                    ),
                  ],
                ),
                const SizedBox(height: NexusSpacing.md),

                // 9:16 Shareable Holographic Gamer DNA Card inside RepaintBoundary
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: RepaintBoundary(
                      key: _shareCardKey,
                      child: AspectRatio(
                        aspectRatio: 9 / 14,
                        child: _GamerDnaShareCard(profile: profile),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: NexusSpacing.md),
                NexusGradientButton(
                  label: 'Exportar Gamer DNA Card (9:16)',
                  icon: Icons.share_rounded,
                  isLoading: _exportingCard,
                  onPressed: _exportShareableCard,
                ),
                const SizedBox(height: NexusSpacing.lg),

                // Safety & Privacy LGPD Center
                NexusGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Central de Privacidade & LGPD',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: NexusSpacing.sm),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: profile.onlyVerifiedFilter,
                        onChanged: (value) {
                          ref.read(myProfileProvider.notifier).state = profile
                              .copyWith(onlyVerifiedFilter: value);
                          ref.invalidate(discoveryDeckProvider);
                        },
                        title: const Text('Mostrar apenas perfis verificados'),
                        subtitle: const Text('Filtro anti-catfish (Liveness)'),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: profile.receiverFirstMode,
                        onChanged: (value) {
                          ref.read(myProfileProvider.notifier).state = profile
                              .copyWith(receiverFirstMode: value);
                        },
                        title: const Text('Modo "Elas/Eles Primeiro"'),
                        subtitle: const Text(
                          'Exige resposta ao Co-op Icebreaker antes de mídia',
                        ),
                      ),
                      const Divider(),
                      Wrap(
                        spacing: NexusSpacing.sm,
                        runSpacing: NexusSpacing.sm,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: _exportLgpdJson,
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('Exportar Dados (JSON)'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _confirmDeleteAccount,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: NexusColors.semanticDanger,
                              side: const BorderSide(
                                color: NexusColors.semanticDanger,
                              ),
                            ),
                            icon: const Icon(
                              Icons.delete_forever_rounded,
                              size: 18,
                            ),
                            label: const Text('Excluir Conta (LGPD)'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: NexusSpacing.md),

                // Autonomous GitHub Releases Updater + Shorebird OTA
                NexusGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.system_update_rounded,
                            color: NexusColors.accentCyber,
                          ),
                          const SizedBox(width: NexusSpacing.sm),
                          Expanded(
                            child: Text(
                              'Atualizações Autônomas (GitHub + OTA)',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: NexusSpacing.xs),
                      Text(
                        'Repositório: WagnerxOliveira/nexus-duo • Verificação obrigatória SHA-256 + Shorebird OTA.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: NexusSpacing.md),
                      OutlinedButton.icon(
                        onPressed: _checkingUpdate ? null : _checkUpdates,
                        icon: _checkingUpdate
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: const Text('Verificar Nova Release no GitHub'),
                      ),
                      if (_updateStatus != null) ...<Widget>[
                        const SizedBox(height: NexusSpacing.sm),
                        Text(
                          _updateStatus!,
                          style: TextStyle(
                            color: (_updateInfo?.hasUpdate ?? false)
                                ? NexusColors.semanticSuccess
                                : NexusColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: NexusSpacing.md),
                TextButton.icon(
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    ref.read(authSessionProvider.notifier).state = null;
                    if (context.mounted) context.go('/welcome');
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sair da conta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GamerDnaShareCard extends StatelessWidget {
  const _GamerDnaShareCard({required this.profile});

  final GamerProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NexusSpacing.lg),
      decoration: BoxDecoration(
        color: NexusColors.bgSurface,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF1A1432),
            NexusColors.bgSurface,
            Color(0xFF0D1E2E),
          ],
        ),
        borderRadius: BorderRadius.circular(NexusRadii.xl),
        border: Border.all(color: NexusColors.borderGlow, width: 1.5),
        boxShadow: const <BoxShadow>[
          NexusShadows.card,
          NexusShadows.glowPrimary,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Expanded(child: NexusBrandLogo(compact: true)),
              VerifiedPlayerBadge(compact: true),
            ],
          ),
          const SizedBox(height: NexusSpacing.md),
          Text(
            profile.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(
            '${profile.gamerDna.archetypeTitle} • ${profile.scheduleMask.activeHoursCount}h/sem',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: NexusTheme.monoStat(
              fontSize: 12,
              color: NexusColors.accentCyber,
            ),
          ),
          const SizedBox(height: NexusSpacing.md),
          GamerDnaBars(dna: profile.gamerDna),
          const SizedBox(height: NexusSpacing.md),
          Text(
            'TOP JOGOS',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: NexusColors.brandSecondary),
          ),
          const SizedBox(height: NexusSpacing.xs),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: profile.games
                .take(3)
                .map(
                  (g) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: NexusColors.bgElevated,
                      borderRadius: BorderRadius.circular(NexusRadii.pill),
                      border: Border.all(color: NexusColors.borderSubtle),
                    ),
                    child: Text(
                      g.title,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(NexusSpacing.sm),
            decoration: BoxDecoration(
              color: NexusColors.bgVoid.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(NexusRadii.md),
              border: Border.all(color: NexusColors.borderSubtle),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.qr_code_2_rounded,
                  size: 36,
                  color: NexusColors.textPrimary,
                ),
                const SizedBox(width: NexusSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Escaneie para jogar comigo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: NexusColors.textSecondary,
                        ),
                      ),
                      Text(
                        'nexusduo.app/u/@${profile.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NexusTheme.monoStat(
                          fontSize: 11,
                          color: NexusColors.accentCyber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
