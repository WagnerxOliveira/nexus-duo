import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';

import '../providers/app_providers.dart';
import '../theme/nexus_theme.dart';
import '../updater/app_update_controller.dart';
import '../widgets/nexus_ui_kit.dart';

/// Stylish Cyber-Velvet pill button placed prominently in Login and AppShell headers.
/// Always stays visible so users can check/trigger updates immediately on phone launch.
class NexusUpdatePillButton extends ConsumerWidget {
  const NexusUpdatePillButton({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(appUpdateControllerProvider);
    final hasUpdate = updateState.hasUpdate;
    final latest =
        updateState.info?.latestVersion ?? updateState.currentVersion;

    final String label = switch (updateState.status) {
      AppUpdateStatus.checking => 'Verificando',
      AppUpdateStatus.downloading => '${(updateState.progress * 100).round()}%',
      AppUpdateStatus.verifying => 'SHA-256',
      _ when hasUpdate => compact ? 'v$latest' : 'Atualizar v$latest',
      _ => compact ? 'Atualizar' : 'Atualizar · v${updateState.currentVersion}',
    };

    return Tooltip(
      message: 'Central de Atualizações Seguras (SHA-256)',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: hasUpdate
              ? const LinearGradient(
                  colors: <Color>[
                    NexusColors.brandPrimary,
                    NexusColors.brandSecondary,
                    NexusColors.accentCyber,
                  ],
                )
              : LinearGradient(
                  colors: <Color>[
                    NexusColors.brandPrimary.withValues(alpha: 0.48),
                    NexusColors.accentCyber.withValues(alpha: 0.42),
                  ],
                ),
          borderRadius: BorderRadius.circular(NexusRadii.pill),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color:
                  (hasUpdate
                          ? NexusColors.brandSecondary
                          : NexusColors.brandPrimary)
                      .withValues(alpha: hasUpdate ? 0.42 : 0.24),
              blurRadius: hasUpdate ? 18 : 12,
              spreadRadius: hasUpdate ? 1 : 0,
            ),
          ],
        ),
        padding: const EdgeInsets.all(1.5),
        child: Material(
          color: hasUpdate
              ? NexusColors.bgElevated.withValues(alpha: 0.92)
              : NexusColors.bgSurface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(NexusRadii.pill),
          child: InkWell(
            key: const Key('nexus_update_pill_button'),
            borderRadius: BorderRadius.circular(NexusRadii.pill),
            onTap: () => showNexusUpdateCenterSheet(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 11 : 14,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (updateState.isBusy)
                      const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          color: NexusColors.accentCyber,
                        ),
                      )
                    else
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: <Color>[
                            NexusColors.brandSecondary,
                            NexusColors.accentCyber,
                          ],
                        ).createShader(bounds),
                        child: Icon(
                          hasUpdate
                              ? Icons.rocket_launch_rounded
                              : Icons.system_update_alt_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: NexusColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (hasUpdate) ...<Widget>[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: NexusColors.accentCyber,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: NexusColors.accentCyber,
                              blurRadius: 8,
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
    );
  }
}

/// Prominent glowing hero card displayed immediately whenever a new GitHub Release
/// is detected, enabling 1-tap verified update directly from the start screen.
class NexusUpdateSpotlightCard extends ConsumerWidget {
  const NexusUpdateSpotlightCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(appUpdateControllerProvider);
    final info = updateState.info;
    if (info == null || !info.hasUpdate) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: NexusSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(NexusRadii.lg),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0x4D8B5CF6),
              Color(0x3DEC4899),
              Color(0x3D06B6D4),
            ],
          ),
          border: Border.all(
            color: NexusColors.accentCyber.withValues(alpha: 0.72),
            width: 1.2,
          ),
          boxShadow: const <BoxShadow>[NexusShadows.glowPrimary],
        ),
        padding: const EdgeInsets.all(NexusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: NexusGradients.brand,
                    borderRadius: BorderRadius.circular(NexusRadii.pill),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'NOVA ATUALIZAÇÃO DISPONÍVEL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (info.formattedSizeMb.isNotEmpty)
                  Text(
                    info.formattedSizeMb,
                    style: NexusTheme.monoStat(
                      fontSize: 11,
                      color: NexusColors.accentCyber,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: NexusSpacing.sm),
            Text(
              'NEXUS DUO v${info.latestVersion} pronto para instalar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: NexusColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Versão atual: v${info.currentVersion} · Download otimizado com checagem criptográfica SHA-256.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: NexusColors.textSecondary),
            ),
            if (updateState.status == AppUpdateStatus.downloading ||
                updateState.status == AppUpdateStatus.verifying) ...<Widget>[
              const SizedBox(height: NexusSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(NexusRadii.pill),
                child: LinearProgressIndicator(
                  value: updateState.progress > 0 ? updateState.progress : null,
                  minHeight: 7,
                  backgroundColor: NexusColors.bgVoid,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    NexusColors.accentCyber,
                  ),
                ),
              ),
            ],
            const SizedBox(height: NexusSpacing.md),
            NexusGradientButton(
              key: const Key('nexus_update_spotlight_cta'),
              label: updateState.isBusy
                  ? 'Preparando v${info.latestVersion}...'
                  : 'Atualizar Agora para v${info.latestVersion}',
              icon: Icons.rocket_launch_rounded,
              isLoading: updateState.isBusy,
              onPressed: updateState.isBusy
                  ? null
                  : () => showNexusUpdateCenterSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the Cyber-Velvet Update Center Modal Sheet.
Future<void> showNexusUpdateCenterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: NexusColors.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(NexusRadii.xl)),
    ),
    builder: (ctx) => const NexusUpdateCenterSheet(),
  );
}

class NexusUpdateCenterSheet extends ConsumerWidget {
  const NexusUpdateCenterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateControllerProvider);
    final controller = ref.read(appUpdateControllerProvider.notifier);
    final info = state.info;
    final hasUpdate = info?.hasUpdate ?? false;

    final double? mbReceived = state.receivedBytes > 0
        ? state.receivedBytes / (1024 * 1024)
        : null;
    final double? mbTotal = state.totalBytes > 0
        ? state.totalBytes / (1024 * 1024)
        : null;

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
                    child: const Icon(
                      Icons.rocket_launch_rounded,
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
                          'Central de Atualizações',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          'GitHub Releases Oficial · APK Assinado',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: NexusColors.textSecondary),
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
                          label: 'Instalada: v${state.currentVersion}',
                          color: NexusColors.textSecondary,
                        ),
                        _VersionBadge(
                          label: hasUpdate
                              ? 'Disponível: v${info!.latestVersion}'
                              : 'Mais recente: v${info?.latestVersion ?? state.currentVersion}',
                          color: hasUpdate
                              ? NexusColors.accentCyber
                              : NexusColors.semanticSuccess,
                        ),
                        if (info != null && info.formattedSizeMb.isNotEmpty)
                          _VersionBadge(
                            label: info.formattedSizeMb,
                            color: NexusColors.brandPrimary,
                          ),
                      ],
                    ),
                    const SizedBox(height: NexusSpacing.md),
                    const Row(
                      children: <Widget>[
                        Icon(
                          Icons.verified_user_rounded,
                          size: 16,
                          color: NexusColors.semanticSuccess,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Integridade garantida com verificação SHA-256 obrigatória',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: NexusColors.semanticSuccess,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (info != null &&
                        info.releaseNotes.isNotEmpty) ...<Widget>[
                      const SizedBox(height: NexusSpacing.sm),
                      Text(
                        info.releaseNotes,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NexusColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (state.status == AppUpdateStatus.downloading ||
                  state.status == AppUpdateStatus.verifying) ...<Widget>[
                const SizedBox(height: NexusSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(NexusRadii.pill),
                  child: LinearProgressIndicator(
                    value: state.progress > 0 ? state.progress : null,
                    minHeight: 10,
                    backgroundColor: NexusColors.bgElevated,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      NexusColors.accentCyber,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  mbReceived != null && mbTotal != null
                      ? '${mbReceived.toStringAsFixed(1)} MB / ${mbTotal.toStringAsFixed(1)} MB (${(state.progress * 100).round()}%)'
                      : 'Processando download seguro (${(state.progress * 100).round()}%)...',
                  textAlign: TextAlign.center,
                  style: NexusTheme.monoStat(
                    fontSize: 12,
                    color: NexusColors.accentCyber,
                  ),
                ),
              ],
              if (state.statusMessage != null) ...<Widget>[
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
                NexusGradientButton(
                  label: '1. Liberar "Instalar apps desconhecidos"',
                  icon: Icons.security_rounded,
                  onPressed: controller.openInstallPermissionSettings,
                ),
                const SizedBox(height: NexusSpacing.sm),
                OutlinedButton.icon(
                  onPressed: controller.retryInstallDownloadedApk,
                  icon: const Icon(Icons.install_mobile_rounded),
                  label: const Text('2. Já liberei — Concluir Instalação'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NexusColors.accentCyber,
                    side: const BorderSide(color: NexusColors.accentCyber),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ] else if (hasUpdate) ...<Widget>[
                NexusGradientButton(
                  label: state.isBusy
                      ? 'Baixando e verificando SHA-256...'
                      : 'Baixar e Instalar v${info!.latestVersion}',
                  icon: Icons.download_for_offline_rounded,
                  isLoading: state.isBusy,
                  onPressed: state.isBusy
                      ? null
                      : controller.downloadAndInstall,
                ),
              ] else ...<Widget>[
                NexusGradientButton(
                  label: state.status == AppUpdateStatus.checking
                      ? 'Verificando no GitHub...'
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
