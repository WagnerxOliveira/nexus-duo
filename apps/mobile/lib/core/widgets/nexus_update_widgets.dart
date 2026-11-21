import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';

import '../providers/app_providers.dart';
import '../theme/nexus_theme.dart';
import '../updater/app_update_controller.dart';
import '../widgets/nexus_ui_kit.dart';

/// Backward-compatible alias for the refined discreet update pill.
typedef NexusUpdatePillButton = NexusDiscreetUpdatePill;

/// Ultra-discreet Obsidian Glass + Cyber-Velvet update pill.
///
/// Golden rule of UX discretion: occupies ZERO space (`SizedBox.shrink()`)
/// when the app is up-to-date or snoozed, appearing smoothly only when an
/// actionable update, minimized download, or permission step exists.
class NexusDiscreetUpdatePill extends ConsumerWidget {
  const NexusDiscreetUpdatePill({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(appUpdateControllerProvider);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final animDuration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 280);

    final Widget content = updateState.shouldShowDiscreetPill
        ? _DiscreetPillBody(
            key: const ValueKey<String>('pill_visible'),
            state: updateState,
            compact: compact,
          )
        : const SizedBox.shrink(key: ValueKey<String>('pill_hidden'));

    return AnimatedSwitcher(
      duration: animDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        if (disableAnimations) return child;
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.2),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: content,
    );
  }
}

class _DiscreetPillBody extends StatelessWidget {
  const _DiscreetPillBody({
    required this.state,
    required this.compact,
    super.key,
  });

  final AppUpdateState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final veryNarrow = width < 360;
    final latest = state.info?.latestVersion ?? state.currentVersion;

    final String label = switch (state.status) {
      AppUpdateStatus.downloading => '${(state.progress * 100).round()}%',
      AppUpdateStatus.verifying => 'SHA-256',
      AppUpdateStatus.permissionRequired => 'Liberar',
      _ => (compact || veryNarrow) ? 'Atualizar' : 'Atualizar · v$latest',
    };

    final double? ringProgress = switch (state.status) {
      AppUpdateStatus.downloading => state.progress.clamp(0.06, 0.96),
      AppUpdateStatus.verifying => 0.98,
      _ => null,
    };

    return Semantics(
      button: true,
      label: 'Atualização disponível v$latest. Toque para atualizar.',
      child: Tooltip(
        message: 'NEXUS DUO v$latest disponível — Atualizar com SHA-256',
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[
                NexusColors.brandPrimary,
                NexusColors.brandSecondary,
                NexusColors.accentCyber,
              ],
            ),
            borderRadius: BorderRadius.circular(NexusRadii.pill),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: NexusColors.brandSecondary.withValues(alpha: 0.34),
                blurRadius: 14,
              ),
            ],
          ),
          padding: const EdgeInsets.all(1.25),
          child: Material(
            color: NexusColors.bgElevated.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(NexusRadii.pill),
            child: InkWell(
              key: const Key('nexus_update_pill_button'),
              borderRadius: BorderRadius.circular(NexusRadii.pill),
              onTap: () => showNexusUpdateCenterSheet(
                context,
                forceBlocking: state.isForceUpdate,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40, maxWidth: 185),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: (compact || veryNarrow) ? 10 : 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (ringProgress != null)
                        SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            value: ringProgress,
                            strokeWidth: 2.2,
                            backgroundColor: NexusColors.borderSubtle,
                            color: NexusColors.accentCyber,
                          ),
                        )
                      else if (state.status ==
                          AppUpdateStatus.permissionRequired)
                        const Icon(
                          Icons.security_rounded,
                          size: 15,
                          color: NexusColors.accentCyber,
                        )
                      else
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: <Color>[
                              NexusColors.brandSecondary,
                              NexusColors.accentCyber,
                            ],
                          ).createShader(bounds),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: NexusColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      if (ringProgress == null &&
                          state.status !=
                              AppUpdateStatus.permissionRequired) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: NexusColors.accentCyber,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: NexusColors.accentCyber,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Non-dismissible full-screen gate rendered automatically when a release is
/// flagged with `force_update: true` or below `min_supported_version_code`.
class NexusForceUpdateGate extends ConsumerWidget {
  const NexusForceUpdateGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isForced = ref.watch(
      appUpdateControllerProvider.select((s) => s.isForceUpdate),
    );
    if (!isForced) {
      return child;
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        key: const Key('nexus_force_update_gate'),
        backgroundColor: NexusColors.bgVoid,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: const NexusUpdateCenterSheet(forceBlocking: true),
          ),
        ),
      ),
    );
  }
}

/// Opens the Cyber-Velvet Update Center Modal Sheet.
Future<void> showNexusUpdateCenterSheet(
  BuildContext context, {
  bool forceBlocking = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: !forceBlocking,
    enableDrag: !forceBlocking,
    backgroundColor: NexusColors.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(NexusRadii.xl)),
    ),
    builder: (ctx) => NexusUpdateCenterSheet(forceBlocking: forceBlocking),
  );
}

class NexusUpdateCenterSheet extends ConsumerWidget {
  const NexusUpdateCenterSheet({this.forceBlocking = false, super.key});

  final bool forceBlocking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateControllerProvider);
    final controller = ref.read(appUpdateControllerProvider.notifier);
    final info = state.info;
    final hasUpdate = info?.hasUpdate ?? false;
    final isDownloadingOrVerifying =
        state.status == AppUpdateStatus.downloading ||
        state.status == AppUpdateStatus.verifying;

    final double? mbReceived = state.receivedBytes > 0
        ? state.receivedBytes / (1024 * 1024)
        : null;
    final double? mbTotal = state.totalBytes > 0
        ? state.totalBytes / (1024 * 1024)
        : null;
    final String speedLabel = state.bytesPerSecond > 0
        ? '${(state.bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s'
        : '';
    final String etaLabel = state.etaSeconds != null && state.etaSeconds! > 0
        ? '~${state.etaSeconds}s'
        : '';

    final bullets = info?.releaseNotesBullets ?? const <String>[];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          NexusSpacing.lg,
          NexusSpacing.md,
          NexusSpacing.lg,
          NexusSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (!forceBlocking)
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: NexusColors.borderSubtle,
                      borderRadius: BorderRadius.circular(NexusRadii.pill),
                    ),
                  ),
                ),
              const SizedBox(height: NexusSpacing.md),
              Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: NexusGradients.brand,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const <BoxShadow>[NexusShadows.glowPrimary],
                    ),
                    child: Icon(
                      forceBlocking
                          ? Icons.shield_outlined
                          : Icons.rocket_launch_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: NexusSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          forceBlocking
                              ? 'Atualização Obrigatória'
                              : 'Central de Atualizações',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          hasUpdate
                              ? 'v${state.currentVersion} → v${info!.latestVersion}'
                              : 'NEXUS DUO · v${state.currentVersion}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: NexusColors.accentCyber),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NexusSpacing.md),
              NexusGlassCard(
                padding: const EdgeInsets.all(NexusSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: NexusSpacing.sm,
                      runSpacing: NexusSpacing.sm,
                      children: <Widget>[
                        _VersionBadge(
                          label: hasUpdate
                              ? 'Disponível: v${info!.latestVersion}'
                              : 'Instalada: v${state.currentVersion}',
                          color: hasUpdate
                              ? NexusColors.accentCyber
                              : NexusColors.semanticSuccess,
                        ),
                        if (info != null &&
                            info.formattedSizeMb.isNotEmpty) ...<Widget>[
                          _VersionBadge(
                            label: info.selectedAbi != null
                                ? '~${info.formattedSizeMb} · ${info.selectedAbi}'
                                : info.formattedSizeMb,
                            color: NexusColors.brandPrimary,
                          ),
                        ],
                        const _VersionBadge(
                          label: 'APK Assinado · SHA-256',
                          color: NexusColors.semanticSuccess,
                        ),
                      ],
                    ),
                    const SizedBox(height: NexusSpacing.md),
                    if (bullets.isNotEmpty) ...<Widget>[
                      for (final bullet in bullets.take(5))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: SizedBox(
                                  width: 5,
                                  height: 5,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: NexusColors.accentCyber,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  bullet,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: NexusColors.textSecondary,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ] else if (info != null &&
                        info.releaseNotes.isNotEmpty) ...<Widget>[
                      Text(
                        info.releaseNotes,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NexusColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isDownloadingOrVerifying) ...<Widget>[
                const SizedBox(height: NexusSpacing.md),
                _GradientProgressBar(progress: state.progress.clamp(0.04, 1.0)),
                const SizedBox(height: 8),
                Text(
                  _buildProgressCaption(
                    state: state,
                    mbReceived: mbReceived,
                    mbTotal: mbTotal,
                    speedLabel: speedLabel,
                    etaLabel: etaLabel,
                  ),
                  textAlign: TextAlign.center,
                  style: NexusTheme.monoStat(
                    fontSize: 12,
                    color: NexusColors.accentCyber,
                  ),
                ),
              ],
              if (state.signatureMismatchDetected) ...<Widget>[
                const SizedBox(height: NexusSpacing.md),
                Container(
                  key: const Key('update_signature_mismatch_banner'),
                  padding: const EdgeInsets.all(NexusSpacing.md),
                  decoration: BoxDecoration(
                    color: NexusColors.semanticDanger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(NexusRadii.md),
                    border: Border.all(
                      color: NexusColors.semanticDanger.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Row(
                        children: <Widget>[
                          Icon(
                            Icons.verified_user_outlined,
                            size: 18,
                            color: NexusColors.semanticDanger,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Conflito de assinatura detectado',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: NexusColors.semanticDanger,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${state.statusMessage ?? ''}\n1. Desinstale a versão de teste anterior do celular.\n2. Reinstale a nova release oficial pelo botão abaixo.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NexusColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (state.statusMessage != null) ...<Widget>[
                const SizedBox(height: NexusSpacing.md),
                Container(
                  padding: const EdgeInsets.all(NexusSpacing.sm),
                  decoration: BoxDecoration(
                    color:
                        (state.status == AppUpdateStatus.error
                                ? NexusColors.semanticDanger
                                : NexusColors.accentCyber)
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(NexusRadii.md),
                    border: Border.all(
                      color:
                          (state.status == AppUpdateStatus.error
                                  ? NexusColors.semanticDanger
                                  : NexusColors.accentCyber)
                              .withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    state.statusMessage!,
                    style: TextStyle(
                      fontSize: 13,
                      color: state.status == AppUpdateStatus.error
                          ? NexusColors.semanticDanger
                          : NexusColors.textPrimary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: NexusSpacing.lg),
              if (state.needsInstallPermission) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(NexusSpacing.sm),
                  margin: const EdgeInsets.only(bottom: NexusSpacing.sm),
                  decoration: BoxDecoration(
                    color: NexusColors.bgElevated,
                    borderRadius: BorderRadius.circular(NexusRadii.md),
                    border: Border.all(color: NexusColors.borderSubtle),
                  ),
                  child: Text(
                    'Passo único no Android: toque em "Ativar permissão", permita o NEXUS DUO e volte — a instalação abrirá sozinha!',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: NexusColors.textSecondary,
                    ),
                  ),
                ),
                NexusGradientButton(
                  key: const Key('update_sheet_permission_cta'),
                  label: 'Ativar permissão',
                  icon: Icons.security_rounded,
                  onPressed: controller.openInstallPermissionSettings,
                ),
                const SizedBox(height: NexusSpacing.sm),
                OutlinedButton.icon(
                  key: const Key('update_sheet_retry_install_cta'),
                  onPressed: controller.retryInstallDownloadedApk,
                  icon: const Icon(Icons.install_mobile_rounded),
                  label: const Text('Já ativei — Instalar agora'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NexusColors.accentCyber,
                    side: const BorderSide(color: NexusColors.accentCyber),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ] else if (isDownloadingOrVerifying) ...<Widget>[
                Row(
                  children: <Widget>[
                    if (!forceBlocking) ...<Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('update_sheet_minimize_cta'),
                          onPressed: () {
                            controller.minimizeDownloadSheet();
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          label: const Text('Minimizar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: NexusColors.textPrimary,
                            side: const BorderSide(
                              color: NexusColors.borderSubtle,
                            ),
                            minimumSize: const Size.fromHeight(46),
                          ),
                        ),
                      ),
                      const SizedBox(width: NexusSpacing.sm),
                    ],
                    Expanded(
                      child: TextButton.icon(
                        key: const Key('update_sheet_cancel_cta'),
                        onPressed: controller.cancelDownload,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Cancelar'),
                        style: TextButton.styleFrom(
                          foregroundColor: NexusColors.semanticDanger,
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (hasUpdate) ...<Widget>[
                NexusGradientButton(
                  key: const Key('update_sheet_start_cta'),
                  label: 'Atualizar Agora',
                  icon: Icons.rocket_launch_rounded,
                  onPressed: controller.downloadAndInstall,
                ),
                if (!forceBlocking) ...<Widget>[
                  const SizedBox(height: NexusSpacing.xs),
                  TextButton(
                    key: const Key('update_sheet_snooze_cta'),
                    onPressed: () async {
                      await controller.snoozeCurrentUpdate();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: NexusColors.textSecondary,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('Lembrar depois'),
                  ),
                ],
              ] else ...<Widget>[
                NexusGradientButton(
                  key: const Key('update_sheet_check_cta'),
                  label: state.status == AppUpdateStatus.checking
                      ? 'Verificando atualizações...'
                      : 'Verificar Atualizações Agora',
                  icon: Icons.refresh_rounded,
                  isLoading: state.status == AppUpdateStatus.checking,
                  onPressed: state.isBusy
                      ? null
                      : () => controller.checkForUpdates(force: true),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _buildProgressCaption({
    required AppUpdateState state,
    required double? mbReceived,
    required double? mbTotal,
    required String speedLabel,
    required String etaLabel,
  }) {
    if (state.status == AppUpdateStatus.verifying) {
      return 'Verificando integridade SHA-256 e assinatura...';
    }
    final pct = '${(state.progress * 100).round()}%';
    final parts = <String>[
      if (mbReceived != null && mbTotal != null)
        '${mbReceived.toStringAsFixed(1)} / ${mbTotal.toStringAsFixed(1)} MB',
      pct,
      if (speedLabel.isNotEmpty) speedLabel,
      if (etaLabel.isNotEmpty) etaLabel,
    ];
    return parts.join(' · ');
  }
}

class _GradientProgressBar extends StatelessWidget {
  const _GradientProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(NexusRadii.pill),
      child: Container(
        height: 10,
        color: NexusColors.bgElevated,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          child: const DecoratedBox(
            decoration: BoxDecoration(gradient: NexusGradients.brand),
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(NexusRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
