import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../errors/app_failure.dart';

/// Native build & signing metadata reported by Android `PackageManager`.
class InstalledBuildInfo {
  const InstalledBuildInfo({
    required this.versionName,
    required this.versionCode,
    this.signingCertSha256 = '',
    this.supportedAbis = const <String>[],
  });

  final String versionName;
  final int versionCode;
  final String signingCertSha256;
  final List<String> supportedAbis;
}

/// Outcome of pre-install native Android APK inspection (`verifyApkPackage`).
class ApkVerificationResult {
  const ApkVerificationResult({
    required this.isValid,
    this.errorCode,
    this.message,
    this.apkCertSha256,
    this.installedCertSha256,
  });

  final bool isValid;
  final String? errorCode;
  final String? message;
  final String? apkCertSha256;
  final String? installedCertSha256;
}

/// Cooperative cancellation token allowing the user to abort an active APK download.
class UpdateCancellationToken {
  bool _isCancelled = false;
  final Set<VoidCallback> _listeners = <VoidCallback>{};

  bool get isCancelled => _isCancelled;

  void addListener(VoidCallback listener) {
    if (_isCancelled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    final copy = List<VoidCallback>.of(_listeners);
    for (final listener in copy) {
      listener();
    }
    _listeners.clear();
  }
}

/// Persisted "Lembrar depois" state scoped by target `versionCode`.
class UpdateSnoozeRecord {
  const UpdateSnoozeRecord({
    required this.versionCode,
    required this.snoozedUntil,
  });

  factory UpdateSnoozeRecord.fromJson(Map<String, dynamic> json) {
    return UpdateSnoozeRecord(
      versionCode: (json['version_code'] as num?)?.toInt() ?? 0,
      snoozedUntil:
          DateTime.tryParse(json['snoozed_until_iso'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final int versionCode;
  final DateTime snoozedUntil;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version_code': versionCode,
    'snoozed_until_iso': snoozedUntil.toUtc().toIso8601String(),
  };
}

/// Lightweight JSON persistence for update snooze (zero extra platform plugins).
class UpdateSnoozeStore {
  UpdateSnoozeStore({
    Future<Directory> Function()? supportDirProvider,
    DateTime Function()? clock,
  }) : _supportDirProvider = supportDirProvider,
       _clock = clock ?? DateTime.now;

  final Future<Directory> Function()? _supportDirProvider;
  final DateTime Function() _clock;
  UpdateSnoozeRecord? _inMemoryFallback;

  Future<File?> _resolveFile() async {
    if (_supportDirProvider == null &&
        Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    try {
      final dir = _supportDirProvider != null
          ? await _supportDirProvider()
          : await getApplicationSupportDirectory();
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return File('${dir.path}/update_snooze.json');
    } catch (_) {
      return null;
    }
  }

  Future<UpdateSnoozeRecord?> read() async {
    final file = await _resolveFile();
    if (file == null) return _inMemoryFallback;
    try {
      if (!file.existsSync()) return _inMemoryFallback;
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final rec = UpdateSnoozeRecord.fromJson(decoded);
        _inMemoryFallback = rec;
        return rec;
      }
    } catch (_) {
      return _inMemoryFallback;
    }
    return _inMemoryFallback;
  }

  Future<void> save(UpdateSnoozeRecord record) async {
    _inMemoryFallback = record;
    final file = await _resolveFile();
    if (file == null) return;
    try {
      await file.writeAsString(jsonEncode(record.toJson()));
    } catch (_) {
      // Keep in-memory record if storage is temporarily unavailable.
    }
  }

  Future<void> clear() async {
    _inMemoryFallback = null;
    final file = await _resolveFile();
    if (file == null) return;
    try {
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore cleanup failures.
    }
  }

  /// Returns `true` only while inside the snooze window AND no newer build arrived.
  Future<bool> isVersionSnoozed(int candidateVersionCode) async {
    final record = await read();
    if (record == null) return false;
    if (candidateVersionCode > record.versionCode) {
      return false;
    }
    return _clock().isBefore(record.snoozedUntil);
  }
}

/// Metadata describing the latest available NEXUS DUO release.
class ReleaseUpdateInfo {
  const ReleaseUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    required this.releaseNotes,
    required this.htmlUrl,
    this.currentVersionCode = 1,
    this.latestVersionCode = 1,
    this.minSupportedVersionCode = 1,
    this.forceUpdate = false,
    this.rolloutEnabled = true,
    this.releaseNotesBullets = const <String>[],
    this.selectedAbi,
    this.expectedSigningCertSha256,
    this.source = 'cdn_manifest',
    this.apkDownloadUrl,
    this.apkFileName,
    this.apkSizeBytes,
    this.sha256SumsUrl,
    this.expectedSha256,
  });

  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String releaseNotes;
  final String htmlUrl;
  final int currentVersionCode;
  final int latestVersionCode;
  final int minSupportedVersionCode;
  final bool forceUpdate;
  final bool rolloutEnabled;
  final List<String> releaseNotesBullets;
  final String? selectedAbi;
  final String? expectedSigningCertSha256;
  final String source;
  final String? apkDownloadUrl;
  final String? apkFileName;
  final int? apkSizeBytes;
  final String? sha256SumsUrl;
  final String? expectedSha256;

  bool get isForceUpdate =>
      hasUpdate &&
      (forceUpdate || currentVersionCode < minSupportedVersionCode);

  String get formattedSizeMb {
    final bytes = apkSizeBytes;
    if (bytes == null || bytes <= 0) return '';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _DigestCaptureSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}

class _CancelledSignal implements Exception {
  const _CancelledSignal();
}

/// Production-hardened in-app self-updater for NEXUS DUO:
/// 1. Zero-rate-limit CDN `update-manifest.json` primary -> Supabase Edge fallback -> Legacy GitHub API;
/// 2. Strict HTTPS host allowlist + SemVer & monotonic `versionCode` check;
/// 3. Pre-download `StatFs` storage check + verified APK cache reuse;
/// 4. Resumable streaming download (`HTTP 206 Range` + backoff + cancellation + ETA);
/// 5. Incremental SHA-256 verification + native Android `verifyApkPackage` + guided install.
class GitHubReleaseUpdater {
  GitHubReleaseUpdater({
    this.repository = 'WagnerxOliveira/nexus-duo',
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    http.Client? httpClient,
    Future<String> Function()? currentVersionProvider,
    Future<InstalledBuildInfo> Function()? installedBuildInfoProvider,
    Future<List<String>> Function()? supportedAbisProvider,
    Future<int?> Function()? availableStorageBytesProvider,
    Future<ApkVerificationResult> Function(File apkFile)? apkPackageVerifier,
    Future<bool> Function()? canRequestPackageInstallsProvider,
    Future<bool> Function()? openSettingsLauncher,
    Future<bool> Function(File apkFile)? installApkLauncher,
    UpdateSnoozeStore? snoozeStore,
    Directory? defaultDownloadDirectory,
    Future<void> Function(Duration delay)? retryDelayProvider,
    DateTime Function()? clock,
  }) : _client = httpClient ?? http.Client(),
       _currentVersionProvider = currentVersionProvider,
       _installedBuildInfoProvider = installedBuildInfoProvider,
       _supportedAbisProvider = supportedAbisProvider,
       _availableStorageBytesProvider = availableStorageBytesProvider,
       _apkPackageVerifier = apkPackageVerifier,
       _canRequestPackageInstallsProvider = canRequestPackageInstallsProvider,
       _openSettingsLauncher = openSettingsLauncher,
       _installApkLauncher = installApkLauncher,
       _snoozeStore = snoozeStore ?? UpdateSnoozeStore(clock: clock),
       _defaultDownloadDirectory = defaultDownloadDirectory,
       _retryDelayProvider = retryDelayProvider ?? Future<void>.delayed,
       _clock = clock ?? DateTime.now;

  static const MethodChannel _installerChannel = MethodChannel(
    'com.nexusduo.app/apk_installer',
  );
  static const Duration _throttleInterval = Duration(minutes: 15);
  static const Duration _manifestTimeout = Duration(seconds: 12);
  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _chunkIdleTimeout = Duration(seconds: 25);
  static const int _maxDownloadAttempts = 3;
  static const int _storageMarginBytes = 50 * 1024 * 1024;

  static const Set<String> allowedDownloadHosts = <String>{
    'github.com',
    'objects.githubusercontent.com',
    'release-assets.githubusercontent.com',
  };

  final String repository;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final http.Client _client;
  final Future<String> Function()? _currentVersionProvider;
  final Future<InstalledBuildInfo> Function()? _installedBuildInfoProvider;
  final Future<List<String>> Function()? _supportedAbisProvider;
  final Future<int?> Function()? _availableStorageBytesProvider;
  final Future<ApkVerificationResult> Function(File apkFile)?
  _apkPackageVerifier;
  final Future<bool> Function()? _canRequestPackageInstallsProvider;
  final Future<bool> Function()? _openSettingsLauncher;
  final Future<bool> Function(File apkFile)? _installApkLauncher;
  final UpdateSnoozeStore _snoozeStore;
  final Directory? _defaultDownloadDirectory;
  final Future<void> Function(Duration delay) _retryDelayProvider;
  final DateTime Function() _clock;

  String? _cachedManifestEtag;
  String? _cachedEdgeEtag;
  String? _cachedApiEtag;
  DateTime? _lastCheckedAt;
  ReleaseUpdateInfo? _lastResult;

  UpdateSnoozeStore get snoozeStore => _snoozeStore;

  Uri get cdnManifestEndpoint => Uri.parse(
    'https://github.com/$repository/releases/latest/download/update-manifest.json',
  );

  Uri? get edgeManifestEndpoint {
    final trimmed = supabaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) return null;
    return Uri.parse('$trimmed/functions/v1/app-update-manifest');
  }

  Uri get latestReleaseEndpoint =>
      Uri.parse('https://api.github.com/repos/$repository/releases/latest');

  /// Validates that [rawUrl] uses HTTPS and a trusted GitHub Releases domain.
  static bool isAllowedDownloadUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || uri.scheme.toLowerCase() != 'https') {
      return false;
    }
    return allowedDownloadHosts.contains(uri.host.toLowerCase());
  }

  /// Compares two semantic version strings (accepts leading `v` and `+build`).
  /// Returns positive if [candidate] is newer than [current].
  static int compareSemVer(String candidate, String current) {
    List<int> parse(String raw) {
      final cleaned = raw
          .trim()
          .replaceFirst(RegExp(r'^[vV]'), '')
          .split('+')
          .first
          .split('-')
          .first;
      final parts = cleaned.split('.');
      return List<int>.generate(
        3,
        (i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0,
      );
    }

    final a = parse(candidate);
    final b = parse(current);
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) {
        return a[i].compareTo(b[i]);
      }
    }
    return 0;
  }

  /// Dual comparison using monotonic `versionCode` first, then SemVer tie-breaker.
  static bool isReleaseNewer({
    required String candidateVersion,
    required int candidateVersionCode,
    required String currentVersion,
    required int currentVersionCode,
  }) {
    if (candidateVersionCode > 0 && currentVersionCode > 0) {
      if (candidateVersionCode > currentVersionCode) return true;
      if (candidateVersionCode < currentVersionCode) return false;
    }
    return compareSemVer(candidateVersion, currentVersion) > 0;
  }

  /// Selects the best Android APK asset from a GitHub Release assets list.
  static Map<String, dynamic>? selectBestApkAsset(
    List<Map<String, dynamic>> assets, {
    List<String> supportedAbis = const <String>[],
  }) {
    final apks = assets
        .where(
          (a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'),
        )
        .toList();
    if (apks.isEmpty) return null;

    for (final rawAbi in supportedAbis) {
      final abi = rawAbi.trim().toLowerCase();
      if (abi.isEmpty) continue;
      for (final asset in apks) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.contains(abi)) {
          return asset;
        }
      }
    }

    for (final asset in apks) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.contains('universal') || name.contains('app-release')) {
        return asset;
      }
    }
    for (final asset in apks) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (!name.contains('x86') &&
          !name.contains('arm64') &&
          !name.contains('armeabi')) {
        return asset;
      }
    }
    for (final asset in apks) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.contains('arm64')) {
        return asset;
      }
    }
    return apks.first;
  }

  /// Selects the best APK entry from a v2 `apks` manifest map keyed by ABI.
  static ({String abiKey, Map<String, dynamic> asset})? selectManifestApk(
    Map<String, dynamic> apksMap, {
    List<String> supportedAbis = const <String>[],
  }) {
    for (final rawAbi in supportedAbis) {
      final normalized = rawAbi.trim();
      final candidate = apksMap[normalized];
      if (candidate is Map<String, dynamic>) {
        return (abiKey: normalized, asset: candidate);
      }
    }
    const fallbackOrder = <String>[
      'universal',
      'arm64-v8a',
      'armeabi-v7a',
      'x86_64',
    ];
    for (final key in fallbackOrder) {
      final candidate = apksMap[key];
      if (candidate is Map<String, dynamic>) {
        return (abiKey: key, asset: candidate);
      }
    }
    for (final entry in apksMap.entries) {
      if (entry.value is Map<String, dynamic>) {
        return (abiKey: entry.key, asset: entry.value as Map<String, dynamic>);
      }
    }
    return null;
  }

  /// Parses `SHA256SUMS.txt` content (`<64-hex-hash>  <filename>`).
  static String? parseSha256ForAsset(String sumsContent, String apkFileName) {
    final normalizedTarget = apkFileName.trim().toLowerCase();
    for (final line in sumsContent.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final match = RegExp(
        r'^([a-fA-F0-9]{64})\s+\*?(.+)$',
      ).firstMatch(trimmed);
      if (match == null) continue;
      final hash = match.group(1)!.toLowerCase();
      final name = match.group(2)!.trim().toLowerCase();
      if (name == normalizedTarget || name.endsWith('/$normalizedTarget')) {
        return hash;
      }
    }
    return null;
  }

  /// Verifies [bytes] against [expectedHexSha256]. Returns `true` iff equal.
  static bool verifySha256(List<int> bytes, String expectedHexSha256) {
    final actual = sha256.convert(bytes).toString().toLowerCase();
    return actual == expectedHexSha256.trim().toLowerCase();
  }

  /// Computes SHA-256 of a local file using streaming chunks (low RAM footprint).
  static Future<String> computeFileSha256Streaming(File file) async {
    final digestCollector = _DigestCaptureSink();
    final inputSink = sha256.startChunkedConversion(digestCollector);
    await for (final chunk in file.openRead()) {
      inputSink.add(chunk);
    }
    inputSink.close();
    return digestCollector.value?.toString().toLowerCase() ?? '';
  }

  /// Returns device ABIs on Android (`Build.SUPPORTED_ABIS`).
  Future<List<String>> getSupportedAbis() async {
    if (_supportedAbisProvider != null) {
      return _supportedAbisProvider();
    }
    try {
      if (!Platform.isAndroid) return const <String>[];
      final res = await _installerChannel.invokeListMethod<String>(
        'getSupportedAbis',
      );
      return res ?? const <String>[];
    } catch (_) {
      return const <String>[];
    }
  }

  /// Returns available free cache bytes on Android via `StatFs`.
  Future<int?> getAvailableStorageBytes() async {
    if (_availableStorageBytesProvider != null) {
      return _availableStorageBytesProvider();
    }
    try {
      if (!Platform.isAndroid) return null;
      return await _installerChannel.invokeMethod<int>(
        'getAvailableStorageBytes',
      );
    } catch (_) {
      return null;
    }
  }

  /// Resolves currently running versionName + versionCode + signing cert fingerprint.
  Future<InstalledBuildInfo> resolveInstalledBuildInfo() async {
    if (_installedBuildInfoProvider != null) {
      return _installedBuildInfoProvider();
    }
    if (_currentVersionProvider != null) {
      final raw = await _currentVersionProvider();
      final parts = raw.split('+');
      return InstalledBuildInfo(
        versionName: parts.first.replaceFirst(RegExp(r'^[vV]'), ''),
        versionCode: parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1,
      );
    }
    try {
      if (Platform.isAndroid) {
        final native = await _installerChannel.invokeMapMethod<String, dynamic>(
          'getInstalledBuildInfo',
        );
        if (native != null) {
          final vName = (native['versionName'] as String?) ?? '1.1.0';
          final vCode = (native['versionCode'] as num?)?.toInt() ?? 3;
          final cert = (native['signingCertSha256'] as String?) ?? '';
          final abis = (native['supportedAbis'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList();
          return InstalledBuildInfo(
            versionName: vName,
            versionCode: vCode,
            signingCertSha256: cert,
            supportedAbis: abis,
          );
        }
      }
    } catch (_) {
      // Fall through cleanly to PackageInfo fallback.
    }
    try {
      final info = await PackageInfo.fromPlatform();
      return InstalledBuildInfo(
        versionName: info.version,
        versionCode: int.tryParse(info.buildNumber) ?? 3,
      );
    } catch (_) {
      return const InstalledBuildInfo(versionName: '1.1.0', versionCode: 3);
    }
  }

  Future<String> resolveCurrentVersion() async {
    final buildInfo = await resolveInstalledBuildInfo();
    return buildInfo.versionName;
  }

  /// Checks Android `REQUEST_INSTALL_PACKAGES` permission status before installation.
  Future<bool> canRequestPackageInstalls() async {
    if (_canRequestPackageInstallsProvider != null) {
      return _canRequestPackageInstallsProvider();
    }
    try {
      if (!Platform.isAndroid) return true;
      final allowed = await _installerChannel.invokeMethod<bool>(
        'canRequestPackageInstalls',
      );
      return allowed ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Opens Android Settings directly on "Install unknown apps" for `com.nexusduo.app`.
  Future<bool> openUnknownAppSourcesSettings() async {
    if (_openSettingsLauncher != null) {
      return _openSettingsLauncher();
    }
    try {
      if (!Platform.isAndroid) return false;
      final opened = await _installerChannel.invokeMethod<bool>(
        'openUnknownAppSourcesSettings',
      );
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Calls Android native pre-install validation (`packageName`, `versionCode`, signing cert).
  Future<ApkVerificationResult> verifyDownloadedApkNative(File apkFile) async {
    if (_apkPackageVerifier != null) {
      return _apkPackageVerifier(apkFile);
    }
    try {
      if (!Platform.isAndroid) {
        return const ApkVerificationResult(isValid: true);
      }
      final map = await _installerChannel.invokeMapMethod<String, dynamic>(
        'verifyApkPackage',
        <String, dynamic>{'filePath': apkFile.path},
      );
      if (map == null) {
        return const ApkVerificationResult(isValid: true);
      }
      return ApkVerificationResult(
        isValid: (map['valid'] as bool?) ?? true,
        errorCode: map['errorCode'] as String?,
        message: map['message'] as String?,
        apkCertSha256: map['apkCertSha256'] as String?,
        installedCertSha256: map['installedCertSha256'] as String?,
      );
    } catch (_) {
      return const ApkVerificationResult(isValid: true);
    }
  }

  /// Checks for updates using CDN `update-manifest.json` -> Supabase Edge -> Legacy API.
  Future<Result<ReleaseUpdateInfo>> checkForUpdate({bool force = false}) async {
    if (!force &&
        _lastCheckedAt != null &&
        _lastResult != null &&
        _clock().difference(_lastCheckedAt!) < _throttleInterval) {
      return Success<ReleaseUpdateInfo>(_lastResult!);
    }

    try {
      final buildInfo = await resolveInstalledBuildInfo();
      final supportedAbis = buildInfo.supportedAbis.isNotEmpty
          ? buildInfo.supportedAbis
          : await getSupportedAbis();

      // 1. Primary: Direct CDN `update-manifest.json` (zero GitHub REST rate limit)
      final cdnOutcome = await _tryFetchManifest(
        uri: cdnManifestEndpoint,
        sourceLabel: 'cdn_manifest',
        etag: force ? null : _cachedManifestEtag,
        onEtag: (e) => _cachedManifestEtag = e,
        buildInfo: buildInfo,
        supportedAbis: supportedAbis,
      );
      if (cdnOutcome != null) {
        return cdnOutcome;
      }

      // 2. Secondary fallback: Cached Supabase Edge Function `app-update-manifest`
      final edgeUri = edgeManifestEndpoint;
      if (edgeUri != null) {
        final edgeHeaders = <String, String>{
          if (supabaseAnonKey.trim().isNotEmpty) 'apikey': supabaseAnonKey,
          if (supabaseAnonKey.trim().isNotEmpty)
            'Authorization': 'Bearer $supabaseAnonKey',
        };
        final edgeOutcome = await _tryFetchManifest(
          uri: edgeUri,
          sourceLabel: 'edge_manifest',
          extraHeaders: edgeHeaders,
          etag: force ? null : _cachedEdgeEtag,
          onEtag: (e) => _cachedEdgeEtag = e,
          buildInfo: buildInfo,
          supportedAbis: supportedAbis,
        );
        if (edgeOutcome != null) {
          return edgeOutcome;
        }
      }

      // 3. Tertiary fallback: Legacy GitHub REST API (pre-manifest releases only)
      return await _fetchLegacyGithubRelease(
        buildInfo: buildInfo,
        supportedAbis: supportedAbis,
        force: force,
      );
    } catch (error) {
      return FailureResult<ReleaseUpdateInfo>(
        NetworkFailure(
          'Não foi possível consultar atualizações do NEXUS DUO: $error',
          code: 'UPDATE_CHECK_FAILED',
        ),
      );
    }
  }

  Future<Result<ReleaseUpdateInfo>?> _tryFetchManifest({
    required Uri uri,
    required String sourceLabel,
    required InstalledBuildInfo buildInfo,
    required List<String> supportedAbis,
    required void Function(String? etag) onEtag,
    String? etag,
    Map<String, String> extraHeaders = const <String, String>{},
  }) async {
    try {
      final headers = <String, String>{
        'Accept': 'application/json',
        ...extraHeaders,
        if (etag != null && etag.isNotEmpty) 'If-None-Match': etag,
      };
      final response = await _client
          .get(uri, headers: headers)
          .timeout(_manifestTimeout);

      if (response.statusCode == 304 && _lastResult != null) {
        _lastCheckedAt = _clock();
        return Success<ReleaseUpdateInfo>(_lastResult!);
      }

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      onEtag(response.headers['etag']);
      final info = _parseManifestToInfo(
        decoded,
        buildInfo: buildInfo,
        supportedAbis: supportedAbis,
        source: sourceLabel,
      );
      _lastCheckedAt = _clock();
      _lastResult = info;
      return Success<ReleaseUpdateInfo>(info);
    } catch (_) {
      return null;
    }
  }

  ReleaseUpdateInfo _parseManifestToInfo(
    Map<String, dynamic> manifest, {
    required InstalledBuildInfo buildInfo,
    required List<String> supportedAbis,
    required String source,
  }) {
    final latestVersion = (manifest['version_name'] as String? ?? '')
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '');
    final resolvedVersion = latestVersion.isEmpty
        ? buildInfo.versionName
        : latestVersion;
    final latestCode = (manifest['version_code'] as num?)?.toInt() ?? 1;
    final minSupportedCode =
        (manifest['min_supported_version_code'] as num?)?.toInt() ?? 1;
    final forceUpdate = (manifest['force_update'] as bool?) ?? false;
    final rolloutEnabled = (manifest['rollout_enabled'] as bool?) ?? true;
    final releaseUrl =
        (manifest['release_url'] as String?) ??
        'https://github.com/$repository/releases/latest';
    final certSha = (manifest['signing_cert_sha256'] as String?)?.trim();

    final rawNotes =
        manifest['release_notes_pt_br'] as List<dynamic>? ?? const <dynamic>[];
    final bullets = rawNotes
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final joinedNotes = bullets.isNotEmpty
        ? bullets.map((b) => '• $b').join('\n')
        : 'Melhorias de desempenho, segurança Zero-Trust e estabilidade.';

    final apksMap =
        manifest['apks'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final selected = selectManifestApk(apksMap, supportedAbis: supportedAbis);
    final apkUrl = selected?.asset['url'] as String?;
    final apkFileName = selected?.asset['file_name'] as String?;
    final apkSha = selected?.asset['sha256'] as String?;
    final apkSize = (selected?.asset['size_bytes'] as num?)?.toInt();

    final rawNewer = isReleaseNewer(
      candidateVersion: resolvedVersion,
      candidateVersionCode: latestCode,
      currentVersion: buildInfo.versionName,
      currentVersionCode: buildInfo.versionCode,
    );

    return ReleaseUpdateInfo(
      currentVersion: buildInfo.versionName,
      latestVersion: resolvedVersion,
      hasUpdate: rolloutEnabled && rawNewer,
      releaseNotes: joinedNotes,
      htmlUrl: releaseUrl,
      currentVersionCode: buildInfo.versionCode,
      latestVersionCode: latestCode,
      minSupportedVersionCode: minSupportedCode,
      forceUpdate: forceUpdate,
      rolloutEnabled: rolloutEnabled,
      releaseNotesBullets: bullets,
      selectedAbi: selected?.abiKey,
      expectedSigningCertSha256: certSha,
      source: source,
      apkDownloadUrl: apkUrl,
      apkFileName: apkFileName,
      apkSizeBytes: apkSize,
      expectedSha256: apkSha,
    );
  }

  Future<Result<ReleaseUpdateInfo>> _fetchLegacyGithubRelease({
    required InstalledBuildInfo buildInfo,
    required List<String> supportedAbis,
    required bool force,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      if (_cachedApiEtag != null && !force) 'If-None-Match': _cachedApiEtag!,
    };

    final response = await _client
        .get(latestReleaseEndpoint, headers: headers)
        .timeout(_manifestTimeout);

    if (response.statusCode == 304 && _lastResult != null) {
      _lastCheckedAt = _clock();
      return Success<ReleaseUpdateInfo>(_lastResult!);
    }

    if (response.statusCode == 404) {
      final noRelease = ReleaseUpdateInfo(
        currentVersion: buildInfo.versionName,
        latestVersion: buildInfo.versionName,
        currentVersionCode: buildInfo.versionCode,
        latestVersionCode: buildInfo.versionCode,
        hasUpdate: false,
        releaseNotes: 'Nenhuma release publicada ainda em $repository.',
        htmlUrl: 'https://github.com/$repository/releases',
        source: 'github_api_legacy',
      );
      _lastCheckedAt = _clock();
      _lastResult = noRelease;
      return Success<ReleaseUpdateInfo>(noRelease);
    }

    if (response.statusCode != 200) {
      return FailureResult<ReleaseUpdateInfo>(
        NetworkFailure(
          'GitHub Releases retornou HTTP ${response.statusCode}.',
          code: 'GITHUB_HTTP_${response.statusCode}',
        ),
      );
    }

    _cachedApiEtag = response.headers['etag'];
    final body =
        jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true))
            as Map<String, dynamic>;
    final tagName = (body['tag_name'] as String?) ?? buildInfo.versionName;
    final cleanLatest = tagName.replaceFirst(RegExp(r'^[vV]'), '');
    final notes =
        (body['body'] as String?) ?? 'Melhorias de performance e segurança.';
    final htmlUrl =
        (body['html_url'] as String?) ??
        'https://github.com/$repository/releases/latest';
    final assets = (body['assets'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();

    final apkAsset = selectBestApkAsset(assets, supportedAbis: supportedAbis);
    Map<String, dynamic>? sumsAsset;
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.contains('sha256') && sumsAsset == null) {
        sumsAsset = asset;
      }
    }

    String? expectedHash;
    final apkName = apkAsset?['name'] as String?;
    final sumsUrl = sumsAsset?['browser_download_url'] as String?;
    if (apkName != null && sumsUrl != null) {
      final sumsResp = await _client
          .get(Uri.parse(sumsUrl))
          .timeout(_manifestTimeout);
      if (sumsResp.statusCode == 200) {
        expectedHash = parseSha256ForAsset(
          utf8.decode(sumsResp.bodyBytes, allowMalformed: true),
          apkName,
        );
      }
    }

    final bullets = notes
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^[-*•#]+\s*'), '').trim())
        .where((l) => l.isNotEmpty && !l.startsWith('```'))
        .take(5)
        .toList();

    final info = ReleaseUpdateInfo(
      currentVersion: buildInfo.versionName,
      latestVersion: cleanLatest,
      currentVersionCode: buildInfo.versionCode,
      latestVersionCode: 0,
      hasUpdate: compareSemVer(tagName, buildInfo.versionName) > 0,
      releaseNotes: notes,
      releaseNotesBullets: bullets,
      htmlUrl: htmlUrl,
      source: 'github_api_legacy',
      apkDownloadUrl: apkAsset?['browser_download_url'] as String?,
      apkFileName: apkName,
      apkSizeBytes: (apkAsset?['size'] as num?)?.toInt(),
      sha256SumsUrl: sumsUrl,
      expectedSha256: expectedHash,
    );

    _lastCheckedAt = _clock();
    _lastResult = info;
    return Success<ReleaseUpdateInfo>(info);
  }

  /// Downloads APK cleanly with host allowlist, disk check, verified cache fast-path,
  /// exponential retry + `HTTP 206 Range` resume, cancellation, speed/ETA, and SHA-256 verification.
  Future<Result<File>> downloadAndVerifyApk(
    ReleaseUpdateInfo info, {
    void Function(double progress)? onProgress,
    void Function(int receivedBytes, int totalBytes)? onBytesProgress,
    void Function(
      int receivedBytes,
      int totalBytes,
      double bytesPerSecond,
      int? etaSeconds,
    )?
    onTransferMetrics,
    UpdateCancellationToken? cancellationToken,
    Directory? downloadDirectoryOverride,
  }) async {
    if (cancellationToken?.isCancelled ?? false) {
      return const FailureResult<File>(
        ValidationFailure(
          'Download cancelado pelo usuário.',
          code: 'DOWNLOAD_CANCELLED',
        ),
      );
    }

    final downloadUrl = info.apkDownloadUrl;
    final expectedSha = info.expectedSha256;
    if (downloadUrl == null || downloadUrl.isEmpty) {
      return const FailureResult<File>(
        ValidationFailure(
          'A release selecionada não possui arquivo APK anexado.',
          code: 'APK_ASSET_MISSING',
        ),
      );
    }
    if (!isAllowedDownloadUrl(downloadUrl)) {
      return const FailureResult<File>(
        CryptoFailure(
          'URL de download fora da lista confiável HTTPS do GitHub Releases — bloqueada por segurança.',
          code: 'UNTRUSTED_DOWNLOAD_HOST',
        ),
      );
    }
    if (expectedSha == null || expectedSha.isEmpty) {
      return const FailureResult<File>(
        CryptoFailure(
          'Hash SHA-256 ausente para este APK — instalação bloqueada por segurança.',
          code: 'SHA256_MISSING',
        ),
      );
    }

    final expectedShaNormalized = expectedSha.trim().toLowerCase();
    final baseDir =
        downloadDirectoryOverride ??
        _defaultDownloadDirectory ??
        await getTemporaryDirectory();
    final updatesDir = Directory('${baseDir.path}/updates');
    if (!updatesDir.existsSync()) {
      updatesDir.createSync(recursive: true);
    }

    final fileName = info.apkFileName ?? 'nexus-duo-${info.latestVersion}.apk';
    final finalFile = File('${updatesDir.path}/$fileName');
    final partFile = File('${updatesDir.path}/$fileName.part');

    // Fast-path: Reuse already-verified cached APK if intact on disk
    if (finalFile.existsSync()) {
      final cachedDigest = await computeFileSha256Streaming(finalFile);
      if (cachedDigest == expectedShaNormalized) {
        final size = finalFile.lengthSync();
        onBytesProgress?.call(size, size);
        onTransferMetrics?.call(size, size, 0, 0);
        onProgress?.call(1.0);
        return Success<File>(finalFile);
      }
      await finalFile.delete();
    }

    // Storage pre-check via native `StatFs`
    final availableBytes = await getAvailableStorageBytes();
    if (availableBytes != null) {
      final estimatedApk = info.apkSizeBytes ?? (55 * 1024 * 1024);
      final requiredBytes = (estimatedApk * 2) + _storageMarginBytes;
      if (availableBytes < requiredBytes) {
        final neededMb = ((requiredBytes - availableBytes) / (1024 * 1024))
            .ceil();
        return FailureResult<File>(
          ValidationFailure(
            'Espaço insuficiente no celular. Libere pelo menos $neededMb MB e tente novamente.',
            code: 'INSUFFICIENT_STORAGE',
          ),
        );
      }
    }

    IOSink? fileSink;
    StreamSubscription<List<int>>? activeSub;
    VoidCallback? cancelListener;
    Object? lastError;

    try {
      for (var attempt = 1; attempt <= _maxDownloadAttempts; attempt++) {
        if (cancellationToken?.isCancelled ?? false) {
          throw const _CancelledSignal();
        }

        try {
          onProgress?.call(0.03);
          final existingPartBytes = partFile.existsSync()
              ? partFile.lengthSync()
              : 0;

          final req = http.Request('GET', Uri.parse(downloadUrl));
          if (existingPartBytes > 0) {
            req.headers['Range'] = 'bytes=$existingPartBytes-';
          }

          final streamed = await _client.send(req).timeout(_connectTimeout);
          if (cancellationToken?.isCancelled ?? false) {
            throw const _CancelledSignal();
          }

          if (streamed.statusCode == 416 && partFile.existsSync()) {
            await partFile.delete();
            continue;
          }

          final isResumedPartial =
              streamed.statusCode == 206 && existingPartBytes > 0;
          if (streamed.statusCode != 200 && !isResumedPartial) {
            final retryable =
                streamed.statusCode >= 500 ||
                streamed.statusCode == 408 ||
                streamed.statusCode == 429;
            final httpErr = NetworkFailure(
              'Falha ao baixar APK (HTTP ${streamed.statusCode}).',
              code: 'APK_DOWNLOAD_FAILED',
            );
            if (!retryable || attempt == _maxDownloadAttempts) {
              return FailureResult<File>(httpErr);
            }
            lastError = httpErr.message;
            await _retryDelayProvider(
              Duration(milliseconds: 500 * (1 << (attempt - 1))),
            );
            continue;
          }

          final digestCollector = _DigestCaptureSink();
          final shaInputSink = sha256.startChunkedConversion(digestCollector);

          var received = 0;
          if (isResumedPartial) {
            await for (final prefixChunk in partFile.openRead()) {
              shaInputSink.add(prefixChunk);
              received += prefixChunk.length;
            }
            fileSink = partFile.openWrite(mode: FileMode.append);
          } else {
            if (partFile.existsSync()) {
              await partFile.delete();
            }
            fileSink = partFile.openWrite(mode: FileMode.write);
          }

          final expectedTotal = isResumedPartial
              ? (info.apkSizeBytes ??
                    (received + (streamed.contentLength ?? 0)))
              : (streamed.contentLength ?? info.apkSizeBytes ?? 0);

          final completer = Completer<void>();
          var smoothedBytesPerSec = 0.0;
          var lastMetricAt = _clock();
          var bytesSinceLastMetric = 0;

          Timer? idleWatchdog;
          void resetWatchdog() {
            idleWatchdog?.cancel();
            idleWatchdog = Timer(_chunkIdleTimeout, () {
              if (!completer.isCompleted) {
                completer.completeError(
                  TimeoutException('Download sem dados por 25s.'),
                );
              }
            });
          }

          cancelListener = () {
            idleWatchdog?.cancel();
            activeSub?.cancel();
            if (!completer.isCompleted) {
              completer.completeError(const _CancelledSignal());
            }
          };
          cancellationToken?.addListener(cancelListener);

          resetWatchdog();
          activeSub = streamed.stream.listen(
            (chunk) {
              if (cancellationToken?.isCancelled ?? false) {
                return;
              }
              resetWatchdog();
              fileSink?.add(chunk);
              shaInputSink.add(chunk);
              received += chunk.length;
              bytesSinceLastMetric += chunk.length;

              onBytesProgress?.call(received, expectedTotal);
              if (expectedTotal > 0) {
                onProgress?.call((received / expectedTotal).clamp(0.05, 0.96));
              } else {
                onProgress?.call(0.5);
              }

              final now = _clock();
              final elapsedMs = now.difference(lastMetricAt).inMilliseconds;
              if (elapsedMs >= 200 ||
                  (expectedTotal > 0 && received >= expectedTotal)) {
                final sec = elapsedMs > 0 ? elapsedMs / 1000.0 : 0.05;
                final instant = bytesSinceLastMetric / sec;
                smoothedBytesPerSec = smoothedBytesPerSec <= 0
                    ? instant
                    : (0.35 * instant) + (0.65 * smoothedBytesPerSec);
                final remaining = expectedTotal > received
                    ? expectedTotal - received
                    : 0;
                final eta = smoothedBytesPerSec > 0
                    ? (remaining / smoothedBytesPerSec).ceil()
                    : null;
                onTransferMetrics?.call(
                  received,
                  expectedTotal,
                  smoothedBytesPerSec,
                  eta,
                );
                lastMetricAt = now;
                bytesSinceLastMetric = 0;
              }
            },
            onError: (Object err, StackTrace st) {
              idleWatchdog?.cancel();
              if (!completer.isCompleted) {
                completer.completeError(err, st);
              }
            },
            onDone: () {
              idleWatchdog?.cancel();
              if (!completer.isCompleted) {
                completer.complete();
              }
            },
            cancelOnError: true,
          );

          await completer.future;

          cancellationToken?.removeListener(cancelListener);
          cancelListener = null;
          await activeSub.cancel();
          activeSub = null;

          await fileSink.flush();
          await fileSink.close();
          fileSink = null;
          shaInputSink.close();

          final actualDigest =
              digestCollector.value?.toString().toLowerCase() ?? '';
          if (actualDigest != expectedShaNormalized) {
            if (partFile.existsSync()) {
              await partFile.delete();
            }
            return const FailureResult<File>(
              CryptoFailure(
                'Checksum SHA-256 divergente! Arquivo rejeitado contra adulteração.',
                code: 'SHA256_MISMATCH',
              ),
            );
          }

          if (finalFile.existsSync()) {
            await finalFile.delete();
          }
          final verifiedFile = await partFile.rename(finalFile.path);
          onProgress?.call(1.0);
          return Success<File>(verifiedFile);
        } on _CancelledSignal {
          if (cancelListener != null) {
            cancellationToken?.removeListener(cancelListener);
            cancelListener = null;
          }
          await activeSub?.cancel();
          activeSub = null;
          if (fileSink != null) {
            try {
              await fileSink.flush();
              await fileSink.close();
            } catch (_) {}
            fileSink = null;
          }
          if (partFile.existsSync()) {
            await partFile.delete();
          }
          return const FailureResult<File>(
            ValidationFailure(
              'Download cancelado pelo usuário.',
              code: 'DOWNLOAD_CANCELLED',
            ),
          );
        } catch (err) {
          lastError = err;
          if (cancelListener != null) {
            cancellationToken?.removeListener(cancelListener);
            cancelListener = null;
          }
          await activeSub?.cancel();
          activeSub = null;
          if (fileSink != null) {
            try {
              await fileSink.flush();
              await fileSink.close();
            } catch (_) {}
            fileSink = null;
          }
          if (attempt < _maxDownloadAttempts &&
              !(cancellationToken?.isCancelled ?? false)) {
            await _retryDelayProvider(
              Duration(milliseconds: 500 * (1 << (attempt - 1))),
            );
            continue;
          }
        }
      }

      return FailureResult<File>(
        NetworkFailure(
          'Erro durante o download verificado do APK após $_maxDownloadAttempts tentativas: $lastError',
          code: 'APK_IO_ERROR',
        ),
      );
    } finally {
      if (cancelListener != null) {
        cancellationToken?.removeListener(cancelListener);
      }
      await activeSub?.cancel();
      if (fileSink != null) {
        try {
          await fileSink.close();
        } catch (_) {}
      }
    }
  }

  /// Cleans stale `.apk` and `.part` files whose version is already installed or > 7 days old.
  Future<int> cleanupStaleApks({
    Directory? downloadDirectoryOverride,
    String? currentVersionOverride,
  }) async {
    if (downloadDirectoryOverride == null &&
        _defaultDownloadDirectory == null &&
        Platform.environment.containsKey('FLUTTER_TEST')) {
      return 0;
    }
    try {
      final baseDir =
          downloadDirectoryOverride ??
          _defaultDownloadDirectory ??
          await getTemporaryDirectory();
      final updatesDir = Directory('${baseDir.path}/updates');
      if (!updatesDir.existsSync()) return 0;

      final currentVersion =
          currentVersionOverride ?? await resolveCurrentVersion();
      final now = _clock();
      var deleted = 0;

      for (final entity in updatesDir.listSync()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last.toLowerCase();
        final stat = entity.statSync();
        final age = now.difference(stat.modified);

        if (name.endsWith('.part')) {
          if (age > const Duration(days: 1)) {
            await entity.delete();
            deleted++;
          }
          continue;
        }

        if (name.endsWith('.apk')) {
          final verMatch = RegExp(r'v?(\d+\.\d+\.\d+)').firstMatch(name);
          final isOldVersion =
              verMatch != null &&
              compareSemVer(verMatch.group(1)!, currentVersion) <= 0;
          if (isOldVersion || age > const Duration(days: 7)) {
            await entity.delete();
            deleted++;
          }
        }
      }
      return deleted;
    } catch (_) {
      return 0;
    }
  }

  /// Launches the native Android package installer via `FileProvider`.
  Future<Result<bool>> triggerAndroidInstall(File verifiedApk) async {
    if (_installApkLauncher != null) {
      try {
        final ok = await _installApkLauncher(verifiedApk);
        return Success<bool>(ok);
      } catch (error) {
        return FailureResult<bool>(
          ValidationFailure(
            'Não foi possível abrir o instalador nativo Android: $error',
            code: 'INSTALL_INTENT_FAILED',
          ),
        );
      }
    }
    try {
      final launched = await _installerChannel.invokeMethod<bool>(
        'installApk',
        <String, dynamic>{'filePath': verifiedApk.path},
      );
      return Success<bool>(launched ?? false);
    } catch (error) {
      return FailureResult<bool>(
        ValidationFailure(
          'Não foi possível abrir o instalador nativo Android: $error',
          code: 'INSTALL_INTENT_FAILED',
        ),
      );
    }
  }
}
