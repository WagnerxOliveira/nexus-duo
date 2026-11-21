import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'github_release_updater.dart';

enum AppUpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  verifying,
  permissionRequired,
  readyToInstall,
  error,
}

class AppUpdateState {
  const AppUpdateState({
    this.status = AppUpdateStatus.idle,
    this.currentVersion = '1.1.0',
    this.currentVersionCode = 3,
    this.info,
    this.progress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.bytesPerSecond = 0.0,
    this.etaSeconds,
    this.statusMessage,
    this.downloadedApkPath,
    this.needsInstallPermission = false,
    this.isSnoozed = false,
    this.isForceUpdate = false,
    this.isMinimized = false,
    this.signatureMismatchDetected = false,
    this.lastCheckedAt,
  });

  final AppUpdateStatus status;
  final String currentVersion;
  final int currentVersionCode;
  final ReleaseUpdateInfo? info;
  final double progress;
  final int receivedBytes;
  final int totalBytes;
  final double bytesPerSecond;
  final int? etaSeconds;
  final String? statusMessage;
  final String? downloadedApkPath;
  final bool needsInstallPermission;
  final bool isSnoozed;
  final bool isForceUpdate;
  final bool isMinimized;
  final bool signatureMismatchDetected;
  final DateTime? lastCheckedAt;

  bool get hasUpdate => info?.hasUpdate ?? false;
  bool get isBusy =>
      status == AppUpdateStatus.checking ||
      status == AppUpdateStatus.downloading ||
      status == AppUpdateStatus.verifying;

  /// Zero visual clutter when up-to-date or snoozed; appears only when actionable.
  bool get shouldShowDiscreetPill {
    if (status == AppUpdateStatus.downloading ||
        status == AppUpdateStatus.verifying ||
        status == AppUpdateStatus.permissionRequired) {
      return true;
    }
    return hasUpdate && (!isSnoozed || isForceUpdate);
  }

  AppUpdateState copyWith({
    AppUpdateStatus? status,
    String? currentVersion,
    int? currentVersionCode,
    ReleaseUpdateInfo? info,
    double? progress,
    int? receivedBytes,
    int? totalBytes,
    double? bytesPerSecond,
    int? etaSeconds,
    bool clearEtaSeconds = false,
    String? statusMessage,
    bool clearStatusMessage = false,
    String? downloadedApkPath,
    bool? needsInstallPermission,
    bool? isSnoozed,
    bool? isForceUpdate,
    bool? isMinimized,
    bool? signatureMismatchDetected,
    DateTime? lastCheckedAt,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      currentVersion: currentVersion ?? this.currentVersion,
      currentVersionCode: currentVersionCode ?? this.currentVersionCode,
      info: info ?? this.info,
      progress: progress ?? this.progress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
      etaSeconds: clearEtaSeconds ? null : (etaSeconds ?? this.etaSeconds),
      statusMessage: clearStatusMessage
          ? null
          : (statusMessage ?? this.statusMessage),
      downloadedApkPath: downloadedApkPath ?? this.downloadedApkPath,
      needsInstallPermission:
          needsInstallPermission ?? this.needsInstallPermission,
      isSnoozed: isSnoozed ?? this.isSnoozed,
      isForceUpdate: isForceUpdate ?? this.isForceUpdate,
      isMinimized: isMinimized ?? this.isMinimized,
      signatureMismatchDetected:
          signatureMismatchDetected ?? this.signatureMismatchDetected,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }
}

/// Global reactive update controller shared across Login, AppShell, Profile, and App Lifecycle.
class AppUpdateController extends StateNotifier<AppUpdateState> {
  AppUpdateController(this._updater, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const AppUpdateState());

  final GitHubReleaseUpdater _updater;
  final DateTime Function() _clock;
  bool _initialCheckTriggered = false;
  UpdateCancellationToken? _activeCancellationToken;

  Future<void> initializeAndAutoCheck({bool autoCheck = true}) async {
    final buildInfo = await _updater.resolveInstalledBuildInfo();
    if (!mounted) return;
    state = state.copyWith(
      currentVersion: buildInfo.versionName,
      currentVersionCode: buildInfo.versionCode,
    );

    // Non-blocking stale cache cleanup on startup
    unawaited(
      _updater.cleanupStaleApks(currentVersionOverride: buildInfo.versionName),
    );

    if (autoCheck && !_initialCheckTriggered) {
      _initialCheckTriggered = true;
      await checkForUpdates(force: false, silentErrors: true);
    }
  }

  Future<void> checkForUpdates({
    bool force = false,
    bool silentErrors = false,
  }) async {
    if (state.status == AppUpdateStatus.checking ||
        state.status == AppUpdateStatus.downloading ||
        state.status == AppUpdateStatus.verifying) {
      return;
    }

    state = state.copyWith(
      status: AppUpdateStatus.checking,
      signatureMismatchDetected: false,
      clearStatusMessage: !silentErrors,
    );

    final res = await _updater.checkForUpdate(force: force);
    if (!mounted) return;

    await res.fold(
      onSuccess: (info) async {
        var snoozed = false;
        if (info.hasUpdate &&
            !info.isForceUpdate &&
            info.latestVersionCode > 0) {
          snoozed = await _updater.snoozeStore.isVersionSnoozed(
            info.latestVersionCode,
          );
          if (!snoozed) {
            await _updater.snoozeStore.clear();
          }
        }
        if (!mounted) return;

        state = state.copyWith(
          currentVersion: info.currentVersion,
          currentVersionCode: info.currentVersionCode,
          info: info,
          isSnoozed: snoozed,
          isForceUpdate: info.isForceUpdate,
          lastCheckedAt: _clock(),
          status: info.hasUpdate
              ? AppUpdateStatus.available
              : AppUpdateStatus.upToDate,
          statusMessage: info.hasUpdate
              ? 'Nova versão v${info.latestVersion} disponível (APK assinado + SHA-256).'
              : 'Seu aplicativo está atualizado (v${info.currentVersion}).',
        );
      },
      onFailure: (failure) async {
        if (!mounted) return;
        if (silentErrors) {
          state = state.copyWith(
            status: state.hasUpdate
                ? AppUpdateStatus.available
                : AppUpdateStatus.idle,
            lastCheckedAt: _clock(),
          );
        } else {
          state = state.copyWith(
            status: AppUpdateStatus.error,
            statusMessage: failure.message,
            lastCheckedAt: _clock(),
          );
        }
      },
    );
  }

  Future<void> downloadAndInstall() async {
    var info = state.info;
    if (info == null || !info.hasUpdate) {
      await checkForUpdates(force: true);
      info = state.info;
      if (info == null || !info.hasUpdate) return;
    }

    _activeCancellationToken?.cancel();
    final cancelToken = UpdateCancellationToken();
    _activeCancellationToken = cancelToken;

    state = state.copyWith(
      status: AppUpdateStatus.downloading,
      progress: 0.04,
      receivedBytes: 0,
      totalBytes: info.apkSizeBytes ?? 0,
      bytesPerSecond: 0.0,
      clearEtaSeconds: true,
      needsInstallPermission: false,
      isSnoozed: false,
      isMinimized: false,
      signatureMismatchDetected: false,
      statusMessage: 'Baixando APK otimizado e validando SHA-256...',
    );

    final downloadRes = await _updater.downloadAndVerifyApk(
      info,
      cancellationToken: cancelToken,
      onProgress: (p) {
        if (!mounted || cancelToken.isCancelled) return;
        state = state.copyWith(
          progress: p,
          status: p >= 0.98
              ? AppUpdateStatus.verifying
              : AppUpdateStatus.downloading,
        );
      },
      onBytesProgress: (received, total) {
        if (!mounted || cancelToken.isCancelled) return;
        state = state.copyWith(
          receivedBytes: received,
          totalBytes: total > 0 ? total : state.totalBytes,
        );
      },
      onTransferMetrics: (received, total, bps, eta) {
        if (!mounted || cancelToken.isCancelled) return;
        state = state.copyWith(
          receivedBytes: received,
          totalBytes: total > 0 ? total : state.totalBytes,
          bytesPerSecond: bps,
          etaSeconds: eta,
        );
      },
    );

    if (!mounted) return;
    if (_activeCancellationToken == cancelToken) {
      _activeCancellationToken = null;
    }

    await downloadRes.fold(
      onSuccess: (apkFile) async {
        state = state.copyWith(
          status: AppUpdateStatus.verifying,
          progress: 0.99,
          statusMessage: 'Validando assinatura e versão do APK...',
        );
        final nativeVerify = await _updater.verifyDownloadedApkNative(apkFile);
        if (!mounted) return;

        if (!nativeVerify.isValid) {
          final isSigMismatch = nativeVerify.errorCode == 'SIGNATURE_MISMATCH';
          state = state.copyWith(
            status: AppUpdateStatus.error,
            isMinimized: false,
            signatureMismatchDetected: isSigMismatch,
            statusMessage: isSigMismatch
                ? 'Esta versão instalada possui outra assinatura digital (ex.: build de teste). Desinstale o app antigo antes de instalar a v${info!.latestVersion}.'
                : (nativeVerify.message ??
                      'Falha na validação nativa do pacote APK.'),
          );
          return;
        }

        final hasPermission = await _updater.canRequestPackageInstalls();
        if (!mounted) return;
        if (!hasPermission) {
          state = state.copyWith(
            status: AppUpdateStatus.permissionRequired,
            downloadedApkPath: apkFile.path,
            needsInstallPermission: true,
            progress: 1.0,
            statusMessage:
                'SHA-256 verificado! Ative "Instalar apps desconhecidos" — ao voltar para o app a instalação abrirá automaticamente.',
          );
          return;
        }
        await _launchInstaller(apkFile);
      },
      onFailure: (failure) async {
        if (failure.code == 'DOWNLOAD_CANCELLED') {
          state = state.copyWith(
            status: AppUpdateStatus.available,
            progress: 0.0,
            receivedBytes: 0,
            bytesPerSecond: 0.0,
            clearEtaSeconds: true,
            isMinimized: false,
            statusMessage:
                'Download cancelado. Você pode atualizar quando quiser.',
          );
          return;
        }
        state = state.copyWith(
          status: AppUpdateStatus.error,
          isMinimized: false,
          statusMessage: failure.message,
        );
      },
    );
  }

  /// Cancels an active APK download immediately and returns cleanly to available state.
  void cancelDownload() {
    _activeCancellationToken?.cancel();
    _activeCancellationToken = null;
    if (!mounted) return;
    state = state.copyWith(
      status: state.hasUpdate
          ? AppUpdateStatus.available
          : AppUpdateStatus.idle,
      progress: 0.0,
      receivedBytes: 0,
      bytesPerSecond: 0.0,
      clearEtaSeconds: true,
      isMinimized: false,
      statusMessage: 'Download cancelado.',
    );
  }

  /// Snoozes non-mandatory update reminders for [duration] (default 24h).
  Future<void> snoozeCurrentUpdate({
    Duration duration = const Duration(hours: 24),
  }) async {
    final info = state.info;
    if (info == null || info.isForceUpdate) return;
    final code = info.latestVersionCode > 0
        ? info.latestVersionCode
        : (state.currentVersionCode + 1);
    await _updater.snoozeStore.save(
      UpdateSnoozeRecord(
        versionCode: code,
        snoozedUntil: _clock().add(duration),
      ),
    );
    if (!mounted) return;
    state = state.copyWith(isSnoozed: true);
  }

  /// Allows minimizing the update modal while downloading in the top pill.
  void minimizeDownloadSheet() {
    if (!mounted) return;
    state = state.copyWith(isMinimized: true);
  }

  Future<void> openInstallPermissionSettings() async {
    await _updater.openUnknownAppSourcesSettings();
  }

  Future<void> retryInstallDownloadedApk() async {
    final path = state.downloadedApkPath;
    if (path == null || path.isEmpty) {
      await downloadAndInstall();
      return;
    }
    final hasPermission = await _updater.canRequestPackageInstalls();
    if (!mounted) return;
    if (!hasPermission) {
      state = state.copyWith(
        status: AppUpdateStatus.permissionRequired,
        needsInstallPermission: true,
        statusMessage:
            'A permissão ainda não está ativada nas configurações do Android.',
      );
      return;
    }
    await _launchInstaller(File(path));
  }

  /// Called by [WidgetsBindingObserver] whenever the user returns to the app:
  /// 1) If waiting for Android install permission, auto-launches installer at once!
  /// 2) Otherwise triggers silent background check if >= 15 min elapsed.
  Future<void> onAppResumed() async {
    if (!mounted) return;
    if (state.status == AppUpdateStatus.permissionRequired &&
        state.downloadedApkPath != null &&
        state.downloadedApkPath!.isNotEmpty) {
      final allowed = await _updater.canRequestPackageInstalls();
      if (!mounted) return;
      if (allowed) {
        await _launchInstaller(File(state.downloadedApkPath!));
      }
      return;
    }

    if (!state.isBusy && state.status != AppUpdateStatus.readyToInstall) {
      final last = state.lastCheckedAt;
      if (last == null ||
          _clock().difference(last) >= const Duration(minutes: 15)) {
        await checkForUpdates(force: false, silentErrors: true);
      }
    }
  }

  Future<void> _launchInstaller(File apkFile) async {
    final installRes = await _updater.triggerAndroidInstall(apkFile);
    if (!mounted) return;
    installRes.fold(
      onSuccess: (launched) {
        state = state.copyWith(
          status: AppUpdateStatus.readyToInstall,
          downloadedApkPath: apkFile.path,
          needsInstallPermission: false,
          progress: 1.0,
          isMinimized: false,
          statusMessage: launched
              ? 'SHA-256 e assinatura verificados! Instalador Android aberto com segurança.'
              : 'APK verificado salvo em ${apkFile.path}.',
        );
      },
      onFailure: (failure) {
        state = state.copyWith(
          status: AppUpdateStatus.error,
          isMinimized: false,
          statusMessage: failure.message,
        );
      },
    );
  }

  @override
  void dispose() {
    _activeCancellationToken?.cancel();
    super.dispose();
  }
}
