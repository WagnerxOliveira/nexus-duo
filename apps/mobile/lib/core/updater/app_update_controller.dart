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
    this.info,
    this.progress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.statusMessage,
    this.downloadedApkPath,
    this.needsInstallPermission = false,
  });

  final AppUpdateStatus status;
  final String currentVersion;
  final ReleaseUpdateInfo? info;
  final double progress;
  final int receivedBytes;
  final int totalBytes;
  final String? statusMessage;
  final String? downloadedApkPath;
  final bool needsInstallPermission;

  bool get hasUpdate => info?.hasUpdate ?? false;
  bool get isBusy =>
      status == AppUpdateStatus.checking ||
      status == AppUpdateStatus.downloading ||
      status == AppUpdateStatus.verifying;

  AppUpdateState copyWith({
    AppUpdateStatus? status,
    String? currentVersion,
    ReleaseUpdateInfo? info,
    double? progress,
    int? receivedBytes,
    int? totalBytes,
    String? statusMessage,
    bool clearStatusMessage = false,
    String? downloadedApkPath,
    bool? needsInstallPermission,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      currentVersion: currentVersion ?? this.currentVersion,
      info: info ?? this.info,
      progress: progress ?? this.progress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      statusMessage: clearStatusMessage
          ? null
          : (statusMessage ?? this.statusMessage),
      downloadedApkPath: downloadedApkPath ?? this.downloadedApkPath,
      needsInstallPermission:
          needsInstallPermission ?? this.needsInstallPermission,
    );
  }
}

/// Global reactive update controller shared across Login, AppShell, and Profile.
class AppUpdateController extends StateNotifier<AppUpdateState> {
  AppUpdateController(this._updater) : super(const AppUpdateState());

  final GitHubReleaseUpdater _updater;
  bool _initialCheckTriggered = false;

  Future<void> initializeAndAutoCheck({bool autoCheck = true}) async {
    final current = await _updater.resolveCurrentVersion();
    if (!mounted) return;
    state = state.copyWith(currentVersion: current);

    if (autoCheck && !_initialCheckTriggered) {
      _initialCheckTriggered = true;
      await checkForUpdates(force: false, silentErrors: true);
    }
  }

  Future<void> checkForUpdates({
    bool force = false,
    bool silentErrors = false,
  }) async {
    if (state.status == AppUpdateStatus.checking) return;
    state = state.copyWith(
      status: AppUpdateStatus.checking,
      clearStatusMessage: !silentErrors,
    );

    final res = await _updater.checkForUpdate(force: force);
    if (!mounted) return;

    res.fold(
      onSuccess: (info) {
        state = state.copyWith(
          currentVersion: info.currentVersion,
          info: info,
          status: info.hasUpdate
              ? AppUpdateStatus.available
              : AppUpdateStatus.upToDate,
          statusMessage: info.hasUpdate
              ? 'Nova versão v${info.latestVersion} disponível (SHA-256 pronto)!'
              : 'Seu aplicativo está atualizado (v${info.currentVersion}).',
        );
      },
      onFailure: (failure) {
        if (silentErrors) {
          state = state.copyWith(status: AppUpdateStatus.idle);
        } else {
          state = state.copyWith(
            status: AppUpdateStatus.error,
            statusMessage: failure.message,
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

    state = state.copyWith(
      status: AppUpdateStatus.downloading,
      progress: 0.04,
      receivedBytes: 0,
      totalBytes: info.apkSizeBytes ?? 0,
      needsInstallPermission: false,
      statusMessage: 'Baixando APK otimizado e validando SHA-256...',
    );

    final downloadRes = await _updater.downloadAndVerifyApk(
      info,
      onProgress: (p) {
        if (!mounted) return;
        state = state.copyWith(
          progress: p,
          status: p >= 0.98
              ? AppUpdateStatus.verifying
              : AppUpdateStatus.downloading,
        );
      },
      onBytesProgress: (received, total) {
        if (!mounted) return;
        state = state.copyWith(
          receivedBytes: received,
          totalBytes: total > 0 ? total : state.totalBytes,
        );
      },
    );

    if (!mounted) return;
    await downloadRes.fold(
      onSuccess: (apkFile) async {
        final hasPermission = await _updater.canRequestPackageInstalls();
        if (!mounted) return;
        if (!hasPermission) {
          state = state.copyWith(
            status: AppUpdateStatus.permissionRequired,
            downloadedApkPath: apkFile.path,
            needsInstallPermission: true,
            progress: 1.0,
            statusMessage:
                'SHA-256 verificado! Autorize "Instalar apps desconhecidos" para concluir a instalação.',
          );
          return;
        }
        await _launchInstaller(apkFile);
      },
      onFailure: (failure) async {
        state = state.copyWith(
          status: AppUpdateStatus.error,
          statusMessage: failure.message,
        );
      },
    );
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
          statusMessage: launched
              ? 'SHA-256 verificado! Instalador Android aberto com segurança.'
              : 'APK verificado salvo em ${apkFile.path}.',
        );
      },
      onFailure: (failure) {
        state = state.copyWith(
          status: AppUpdateStatus.error,
          statusMessage: failure.message,
        );
      },
    );
  }
}
