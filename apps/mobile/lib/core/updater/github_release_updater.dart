import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../errors/app_failure.dart';

/// Metadata describing the latest GitHub Release for NEXUS DUO.
class ReleaseUpdateInfo {
  const ReleaseUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    required this.releaseNotes,
    required this.htmlUrl,
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
  final String? apkDownloadUrl;
  final String? apkFileName;
  final int? apkSizeBytes;
  final String? sha256SumsUrl;
  final String? expectedSha256;

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

/// Autonomous in-app updater that checks `WagnerxOliveira/nexus-duo/releases/latest`,
/// selects the smallest ABI-compatible APK, streams directly to disk with incremental
/// `SHA-256` validation against `SHA256SUMS.txt`, checks Android install permission,
/// and invokes Android's native `FileProvider` package installer.
class GitHubReleaseUpdater {
  GitHubReleaseUpdater({
    this.repository = 'WagnerxOliveira/nexus-duo',
    http.Client? httpClient,
    Future<String> Function()? currentVersionProvider,
  }) : _client = httpClient ?? http.Client(),
       _currentVersionProvider = currentVersionProvider;

  static const MethodChannel _installerChannel = MethodChannel(
    'com.nexusduo.app/apk_installer',
  );
  static const Duration _throttleInterval = Duration(hours: 2);

  final String repository;
  final http.Client _client;
  final Future<String> Function()? _currentVersionProvider;

  String? _cachedEtag;
  DateTime? _lastCheckedAt;
  ReleaseUpdateInfo? _lastResult;

  Uri get latestReleaseEndpoint =>
      Uri.parse('https://api.github.com/repos/$repository/releases/latest');

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

  /// Selects the best Android APK asset from a GitHub Release assets list.
  ///
  /// When [supportedAbis] is supplied (from Android `Build.SUPPORTED_ABIS`),
  /// selects the highest-priority ABI-specific APK first (~58% smaller download),
  /// falling back safely to universal APKs (`universal` / `app-release`).
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

  /// Parses `SHA256SUMS.txt` content (`<64-hex-hash>  <filename>`) and extracts
  /// the expected SHA-256 hash matching [apkFileName].
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

  /// Returns device ABIs on Android (`Build.SUPPORTED_ABIS`), or empty outside Android.
  Future<List<String>> getSupportedAbis() async {
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

  /// Checks Android `REQUEST_INSTALL_PACKAGES` permission status before installation.
  Future<bool> canRequestPackageInstalls() async {
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

  Future<String> resolveCurrentVersion() async {
    if (_currentVersionProvider != null) {
      return _currentVersionProvider();
    }
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '1.1.0';
    }
  }

  /// Checks GitHub Releases for a newer version. Uses ETag + 2h cache unless [force] is true.
  Future<Result<ReleaseUpdateInfo>> checkForUpdate({bool force = false}) async {
    if (!force &&
        _lastCheckedAt != null &&
        _lastResult != null &&
        DateTime.now().difference(_lastCheckedAt!) < _throttleInterval) {
      return Success<ReleaseUpdateInfo>(_lastResult!);
    }

    try {
      final currentVersion = await resolveCurrentVersion();
      final headers = <String, String>{
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        if (_cachedEtag != null && !force) 'If-None-Match': _cachedEtag!,
      };

      final response = await _client.get(
        latestReleaseEndpoint,
        headers: headers,
      );

      if (response.statusCode == 304 && _lastResult != null) {
        _lastCheckedAt = DateTime.now();
        return Success<ReleaseUpdateInfo>(_lastResult!);
      }

      if (response.statusCode == 404) {
        final noRelease = ReleaseUpdateInfo(
          currentVersion: currentVersion,
          latestVersion: currentVersion,
          hasUpdate: false,
          releaseNotes: 'Nenhuma release publicada ainda em $repository.',
          htmlUrl: 'https://github.com/$repository/releases',
        );
        _lastCheckedAt = DateTime.now();
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

      _cachedEtag = response.headers['etag'];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (body['tag_name'] as String?) ?? currentVersion;
      final notes =
          (body['body'] as String?) ?? 'Melhorias de performance e segurança.';
      final htmlUrl =
          (body['html_url'] as String?) ??
          'https://github.com/$repository/releases/latest';
      final assets = (body['assets'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList();

      final abis = await getSupportedAbis();
      final apkAsset = selectBestApkAsset(assets, supportedAbis: abis);
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
        final sumsResp = await _client.get(Uri.parse(sumsUrl));
        if (sumsResp.statusCode == 200) {
          expectedHash = parseSha256ForAsset(sumsResp.body, apkName);
        }
      }

      final info = ReleaseUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: tagName.replaceFirst(RegExp(r'^[vV]'), ''),
        hasUpdate: compareSemVer(tagName, currentVersion) > 0,
        releaseNotes: notes,
        htmlUrl: htmlUrl,
        apkDownloadUrl: apkAsset?['browser_download_url'] as String?,
        apkFileName: apkName,
        apkSizeBytes: (apkAsset?['size'] as num?)?.toInt(),
        sha256SumsUrl: sumsUrl,
        expectedSha256: expectedHash,
      );

      _lastCheckedAt = DateTime.now();
      _lastResult = info;
      return Success<ReleaseUpdateInfo>(info);
    } catch (error) {
      return FailureResult<ReleaseUpdateInfo>(
        NetworkFailure(
          'Não foi possível consultar atualizações no GitHub: $error',
          code: 'UPDATE_CHECK_FAILED',
        ),
      );
    }
  }

  /// Streams the APK directly into app cache `updates/`, computes `SHA-256`
  /// incrementally on chunks (low RAM usage), rejects tampered downloads, and
  /// renames atomically once verified.
  Future<Result<File>> downloadAndVerifyApk(
    ReleaseUpdateInfo info, {
    void Function(double progress)? onProgress,
    void Function(int receivedBytes, int totalBytes)? onBytesProgress,
    Directory? downloadDirectoryOverride,
  }) async {
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
    if (expectedSha == null || expectedSha.isEmpty) {
      return const FailureResult<File>(
        CryptoFailure(
          'SHA256SUMS.txt ausente ou sem hash para este APK — instalação bloqueada por segurança.',
          code: 'SHA256_MISSING',
        ),
      );
    }

    File? partFile;
    IOSink? fileSink;
    try {
      onProgress?.call(0.03);
      final req = http.Request('GET', Uri.parse(downloadUrl));
      final streamed = await _client.send(req);

      if (streamed.statusCode != 200) {
        return FailureResult<File>(
          NetworkFailure(
            'Falha ao baixar APK (HTTP ${streamed.statusCode}).',
            code: 'APK_DOWNLOAD_FAILED',
          ),
        );
      }

      final baseDir =
          downloadDirectoryOverride ?? await getTemporaryDirectory();
      final updatesDir = Directory('${baseDir.path}/updates');
      if (!updatesDir.existsSync()) {
        updatesDir.createSync(recursive: true);
      }

      final fileName =
          info.apkFileName ?? 'nexus-duo-${info.latestVersion}.apk';
      final finalFile = File('${updatesDir.path}/$fileName');
      partFile = File('${updatesDir.path}/$fileName.part');
      if (partFile.existsSync()) {
        await partFile.delete();
      }

      fileSink = partFile.openWrite();
      final digestCollector = _DigestCaptureSink();
      final shaInputSink = sha256.startChunkedConversion(digestCollector);

      final expectedTotal = streamed.contentLength ?? info.apkSizeBytes ?? 0;
      var received = 0;

      await for (final chunk in streamed.stream) {
        fileSink.add(chunk);
        shaInputSink.add(chunk);
        received += chunk.length;
        onBytesProgress?.call(received, expectedTotal);
        if (expectedTotal > 0) {
          onProgress?.call((received / expectedTotal).clamp(0.05, 0.96));
        } else {
          onProgress?.call(0.5);
        }
      }

      await fileSink.flush();
      await fileSink.close();
      fileSink = null;
      shaInputSink.close();

      final actualDigest =
          digestCollector.value?.toString().toLowerCase() ?? '';
      if (actualDigest != expectedSha.trim().toLowerCase()) {
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
    } catch (error) {
      if (fileSink != null) {
        try {
          await fileSink.close();
        } catch (_) {}
      }
      if (partFile != null && partFile.existsSync()) {
        try {
          await partFile.delete();
        } catch (_) {}
      }
      return FailureResult<File>(
        NetworkFailure(
          'Erro durante o download verificado do APK: $error',
          code: 'APK_IO_ERROR',
        ),
      );
    }
  }

  /// Launches the native Android package installer via `FileProvider`.
  Future<Result<bool>> triggerAndroidInstall(File verifiedApk) async {
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
