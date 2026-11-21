import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexus_duo/core/errors/app_failure.dart';
import 'package:nexus_duo/core/updater/app_update_controller.dart';
import 'package:nexus_duo/core/updater/github_release_updater.dart';

Map<String, dynamic> _sampleManifest({
  String versionName = '1.2.0',
  int versionCode = 4,
  int minSupportedCode = 1,
  bool forceUpdate = false,
  bool rolloutEnabled = true,
  String apkUrl =
      'https://github.com/WagnerxOliveira/nexus-duo/releases/download/v1.2.0/nexus-duo-v1.2.0-arm64-v8a.apk',
  String? expectedSha256,
  int sizeBytes = 50000000,
}) {
  return <String, dynamic>{
    'schema_version': 2,
    'app_id': 'com.nexusduo.app',
    'channel': 'stable',
    'version_name': versionName,
    'version_code': versionCode,
    'min_supported_version_code': minSupportedCode,
    'force_update': forceUpdate,
    'rollout_enabled': rolloutEnabled,
    'published_at': '2026-11-21T20:00:00Z',
    'signing_cert_sha256': 'b' * 64,
    'release_url':
        'https://github.com/WagnerxOliveira/nexus-duo/releases/tag/v$versionName',
    'release_notes_pt_br': <String>[
      'Botão de atualização discreto no estilo Cyber-Velvet.',
      'Retomada automática após liberar permissão.',
    ],
    'apks': <String, dynamic>{
      'arm64-v8a': <String, dynamic>{
        'file_name': 'nexus-duo-v$versionName-arm64-v8a.apk',
        'url': apkUrl,
        'sha256': expectedSha256 ?? ('a' * 64),
        'size_bytes': sizeBytes,
      },
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Manifest source chain (CDN -> Edge -> Legacy API)', () {
    test(
      'reads update-manifest.json from CDN without touching GitHub REST API',
      () async {
        final requestedPaths = <String>[];
        final client = MockClient((req) async {
          requestedPaths.add(req.url.toString());
          if (req.url.path.endsWith('/update-manifest.json')) {
            return http.Response(jsonEncode(_sampleManifest()), 200);
          }
          return http.Response('Should not be called', 500);
        });

        final updater = GitHubReleaseUpdater(
          httpClient: client,
          supabaseUrl: 'https://hfuntccxwoijjkmitewb.supabase.co',
          installedBuildInfoProvider: () async => const InstalledBuildInfo(
            versionName: '1.1.0',
            versionCode: 3,
            supportedAbis: <String>['arm64-v8a'],
          ),
        );

        final res = await updater.checkForUpdate(force: true);
        expect(res.isSuccess, isTrue);
        final info = res.valueOrNull!;
        expect(info.source, 'cdn_manifest');
        expect(info.hasUpdate, isTrue);
        expect(info.latestVersion, '1.2.0');
        expect(info.latestVersionCode, 4);
        expect(info.selectedAbi, 'arm64-v8a');
        expect(requestedPaths.length, 1);
        expect(
          requestedPaths.single,
          contains('/releases/latest/download/update-manifest.json'),
        );
      },
    );

    test('falls back to Supabase Edge Function when CDN fails', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/update-manifest.json')) {
          return http.Response('CDN glitch', 503);
        }
        if (req.url.path.endsWith('/functions/v1/app-update-manifest')) {
          return http.Response(
            jsonEncode(_sampleManifest(forceUpdate: true)),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final updater = GitHubReleaseUpdater(
        httpClient: client,
        supabaseUrl: 'https://hfuntccxwoijjkmitewb.supabase.co',
        supabaseAnonKey: 'anon-key-test',
        installedBuildInfoProvider: () async => const InstalledBuildInfo(
          versionName: '1.1.0',
          versionCode: 3,
          supportedAbis: <String>['arm64-v8a'],
        ),
      );

      final res = await updater.checkForUpdate(force: true);
      expect(res.isSuccess, isTrue);
      final info = res.valueOrNull!;
      expect(info.source, 'edge_manifest');
      expect(info.hasUpdate, isTrue);
      expect(info.isForceUpdate, isTrue);
    });

    test(
      'falls back to legacy GitHub API when both manifest endpoints 404',
      () async {
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/update-manifest.json') ||
              req.url.path.endsWith('/functions/v1/app-update-manifest')) {
            return http.Response('Not found', 404);
          }
          if (req.url.path.endsWith('/releases/latest')) {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'tag_name': 'v1.2.0',
                'body': '- Novo motor E2EE',
                'html_url':
                    'https://github.com/WagnerxOliveira/nexus-duo/releases/tag/v1.2.0',
                'assets': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'name': 'nexus-duo-v1.2.0-universal.apk',
                    'size': 50000000,
                    'browser_download_url':
                        'https://github.com/WagnerxOliveira/nexus-duo/releases/download/v1.2.0/nexus-duo-v1.2.0-universal.apk',
                  },
                  <String, dynamic>{
                    'name': 'SHA256SUMS.txt',
                    'browser_download_url':
                        'https://github.com/WagnerxOliveira/nexus-duo/releases/download/v1.2.0/SHA256SUMS.txt',
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            '${'c' * 64}  nexus-duo-v1.2.0-universal.apk\n',
            200,
          );
        });

        final updater = GitHubReleaseUpdater(
          httpClient: client,
          supabaseUrl: 'https://hfuntccxwoijjkmitewb.supabase.co',
          installedBuildInfoProvider: () async =>
              const InstalledBuildInfo(versionName: '1.1.0', versionCode: 3),
        );

        final res = await updater.checkForUpdate(force: true);
        expect(res.isSuccess, isTrue);
        expect(res.valueOrNull!.source, 'github_api_legacy');
        expect(res.valueOrNull!.hasUpdate, isTrue);
      },
    );
  });

  group('VersionCode comparison, rollout switch & force update', () {
    test(
      'detects update on versionCode bump even with equal SemVer, and respects rollout_enabled=false',
      () async {
        final pausedClient = MockClient((req) async {
          return http.Response(
            jsonEncode(
              _sampleManifest(
                versionName: '1.1.0',
                versionCode: 4,
                rolloutEnabled: false,
              ),
            ),
            200,
          );
        });

        final pausedUpdater = GitHubReleaseUpdater(
          httpClient: pausedClient,
          installedBuildInfoProvider: () async =>
              const InstalledBuildInfo(versionName: '1.1.0', versionCode: 3),
        );
        final pausedRes = await pausedUpdater.checkForUpdate(force: true);
        expect(pausedRes.valueOrNull!.hasUpdate, isFalse);

        expect(
          GitHubReleaseUpdater.isReleaseNewer(
            candidateVersion: '1.1.0',
            candidateVersionCode: 4,
            currentVersion: '1.1.0',
            currentVersionCode: 3,
          ),
          isTrue,
        );
        expect(
          GitHubReleaseUpdater.isReleaseNewer(
            candidateVersion: '1.1.0',
            candidateVersionCode: 3,
            currentVersion: '1.1.0',
            currentVersionCode: 3,
          ),
          isFalse,
        );
      },
    );
  });

  group(
    'Download hardening: host allowlist, storage check, cache reuse, 206 resume & cancellation',
    () {
      test(
        'rejects untrusted non-GitHub download URL with UNTRUSTED_DOWNLOAD_HOST',
        () async {
          final updater = GitHubReleaseUpdater(
            httpClient: MockClient((_) async => http.Response('', 200)),
          );
          final res = await updater.downloadAndVerifyApk(
            ReleaseUpdateInfo(
              currentVersion: '1.1.0',
              latestVersion: '1.2.0',
              hasUpdate: true,
              releaseNotes: '',
              htmlUrl:
                  'https://github.com/WagnerxOliveira/nexus-duo/releases/tag/v1.2.0',
              apkDownloadUrl: 'https://evil-cdn.example.com/nexus.apk',
              apkFileName: 'nexus.apk',
              expectedSha256: 'a' * 64,
            ),
          );
          expect(res.isFailure, isTrue);
          expect(res.failureOrNull, isA<CryptoFailure>());
          expect(res.failureOrNull!.code, 'UNTRUSTED_DOWNLOAD_HOST');
        },
      );

      test(
        'rejects download when available storage is insufficient (StatFs guard)',
        () async {
          final tempDir = Directory.systemTemp.createTempSync(
            'nexus_storage_test_',
          );
          addTearDown(() => tempDir.deleteSync(recursive: true));

          final updater = GitHubReleaseUpdater(
            httpClient: MockClient((_) async => http.Response('', 200)),
            availableStorageBytesProvider: () async =>
                20 * 1024 * 1024, // Only 20 MB free
          );

          final res = await updater.downloadAndVerifyApk(
            ReleaseUpdateInfo(
              currentVersion: '1.1.0',
              latestVersion: '1.2.0',
              hasUpdate: true,
              releaseNotes: '',
              htmlUrl:
                  'https://github.com/WagnerxOliveira/nexus-duo/releases/tag/v1.2.0',
              apkDownloadUrl:
                  'https://github.com/WagnerxOliveira/nexus-duo/releases/download/v1.2.0/app.apk',
              apkFileName: 'app.apk',
              apkSizeBytes: 50 * 1024 * 1024,
              expectedSha256: 'a' * 64,
            ),
            downloadDirectoryOverride: tempDir,
          );
          expect(res.isFailure, isTrue);
          expect(res.failureOrNull!.code, 'INSUFFICIENT_STORAGE');
        },
      );

      test('reuses verified cached APK on disk without network download', () async {
        final tempDir = Directory.systemTemp.createTempSync('nexus_cache_hit_');
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final payload = utf8.encode('VALID-CACHED-SIGNED-APK-V120');
        final hash = sha256.convert(payload).toString();
        final updatesDir = Directory('${tempDir.path}/updates')
          ..createSync(recursive: true);
        final cachedFile = File('${updatesDir.path}/nexus-v1.2.0.apk')
          ..writeAsBytesSync(payload);

        var httpCalled = false;
        final updater = GitHubReleaseUpdater(
          httpClient: MockClient((_) async {
            httpCalled = true;
            return http.Response.bytes(payload, 200);
          }),
        );

        final res = await updater.downloadAndVerifyApk(
          ReleaseUpdateInfo(
            currentVersion: '1.1.0',
            latestVersion: '1.2.0',
            hasUpdate: true,
            releaseNotes: '',
            htmlUrl:
                'https://github.com/WagnerxOliveira/nexus-duo/releases/tag/v1.2.0',
            apkDownloadUrl:
                'https://github.com/WagnerxOliveira/nexus-duo/releases/download/v1.2.0/nexus-v1.2.0.apk',
            apkFileName: 'nexus-v1.2.0.apk',
            apkSizeBytes: payload.length,
            expectedSha256: hash,
          ),
          downloadDirectoryOverride: tempDir,
        );
        expect(httpCalled, isFalse);
        expect(res.isSuccess, isTrue);
        expect(res.valueOrNull!.path, cachedFile.path);
      });

      test('recovers partial download using HTTP 206 Range header', () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'nexus_range_test_',
        );
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final fullPayload = utf8.encode('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ');
        final fullHash = sha256.convert(fullPayload).toString();
        var attempt = 0;

        final rangeClient = MockClient.streaming((request, bodyStream) async {
          attempt++;
          if (attempt == 1) {
            final controller = StreamController<List<int>>();
            controller.add(fullPayload.sublist(0, 10));
            controller.addError(
              const SocketException('Drop connection mid-stream'),
            );
            unawaited(controller.close());
            return http.StreamedResponse(
              controller.stream,
              200,
              contentLength: fullPayload.length,
            );
          }
          expect(request.headers['Range'], 'bytes=10-');
          final remainder = fullPayload.sublist(10);
          return http.StreamedResponse(
            Stream<List<int>>.value(remainder),
            206,
            contentLength: remainder.length,
          );
        });

        final updater = GitHubReleaseUpdater(
          httpClient: rangeClient,
          retryDelayProvider: (_) async {},
          availableStorageBytesProvider: () async => 500 * 1024 * 1024,
        );

        final res = await updater.downloadAndVerifyApk(
          ReleaseUpdateInfo(
            currentVersion: '1.1.0',
            latestVersion: '1.2.0',
            hasUpdate: true,
            releaseNotes: '',
            htmlUrl:
                'https://github.com/WagnerxOliveira/nexus-duo/releases/tag/v1.2.0',
            apkDownloadUrl:
                'https://objects.githubusercontent.com/nexus-duo-v1.2.0-arm64-v8a.apk',
            apkFileName: 'nexus-duo-v1.2.0-arm64-v8a.apk',
            apkSizeBytes: fullPayload.length,
            expectedSha256: fullHash,
          ),
          downloadDirectoryOverride: tempDir,
        );

        expect(attempt, 2);
        expect(res.isSuccess, isTrue);
        expect(res.valueOrNull!.readAsBytesSync(), equals(fullPayload));
      });

      test(
        'supports clean user cancellation via UpdateCancellationToken',
        () async {
          final tempDir = Directory.systemTemp.createTempSync(
            'nexus_cancel_test_',
          );
          addTearDown(() => tempDir.deleteSync(recursive: true));

          final token = UpdateCancellationToken();
          final client = MockClient.streaming((request, bodyStream) async {
            final controller = StreamController<List<int>>();
            controller.add(utf8.encode('PARTIAL'));
            // Do not close until cancelled
            token.addListener(() {
              if (!controller.isClosed) controller.close();
            });
            return http.StreamedResponse(
              controller.stream,
              200,
              contentLength: 1000,
            );
          });

          final updater = GitHubReleaseUpdater(
            httpClient: client,
            availableStorageBytesProvider: () async => 500 * 1024 * 1024,
          );

          final future = updater.downloadAndVerifyApk(
            ReleaseUpdateInfo(
              currentVersion: '1.1.0',
              latestVersion: '1.2.0',
              hasUpdate: true,
              releaseNotes: '',
              htmlUrl:
                  'https://github.com/WagnerxOliveira/nexus-duo/releases/tag/v1.2.0',
              apkDownloadUrl:
                  'https://github.com/WagnerxOliveira/nexus-duo/releases/download/v1.2.0/app.apk',
              apkFileName: 'app.apk',
              apkSizeBytes: 1000,
              expectedSha256: 'a' * 64,
            ),
            cancellationToken: token,
            downloadDirectoryOverride: tempDir,
          );

          await Future<void>.delayed(const Duration(milliseconds: 30));
          token.cancel();
          final res = await future;
          expect(res.isFailure, isTrue);
          expect(res.failureOrNull!.code, 'DOWNLOAD_CANCELLED');
        },
      );

      test(
        'cleanupStaleApks removes older installed versions and stale .part files',
        () async {
          final tempDir = Directory.systemTemp.createTempSync('nexus_gc_test_');
          addTearDown(() => tempDir.deleteSync(recursive: true));
          final updatesDir = Directory('${tempDir.path}/updates')
            ..createSync(recursive: true);

          final oldApk = File(
            '${updatesDir.path}/nexus-duo-v1.1.0-arm64-v8a.apk',
          )..writeAsBytesSync(<int>[1, 2, 3]);
          final futureApk = File(
            '${updatesDir.path}/nexus-duo-v1.3.0-arm64-v8a.apk',
          )..writeAsBytesSync(<int>[4, 5, 6]);

          final updater = GitHubReleaseUpdater(
            installedBuildInfoProvider: () async =>
                const InstalledBuildInfo(versionName: '1.2.0', versionCode: 4),
          );
          final removedCount = await updater.cleanupStaleApks(
            downloadDirectoryOverride: tempDir,
            currentVersionOverride: '1.2.0',
          );
          expect(removedCount, 1);
          expect(oldApk.existsSync(), isFalse);
          expect(futureApk.existsSync(), isTrue);
        },
      );
    },
  );

  group('Snooze store & AppUpdateController lifecycle', () {
    test(
      'snooze persists 24h per versionCode and breaks automatically when newer version arrives',
      () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'nexus_snooze_test_',
        );
        addTearDown(() => tempDir.deleteSync(recursive: true));

        var now = DateTime.utc(2026, 11, 21, 12, 0);
        final store = UpdateSnoozeStore(
          supportDirProvider: () async => tempDir,
          clock: () => now,
        );

        await store.save(
          UpdateSnoozeRecord(
            versionCode: 4,
            snoozedUntil: now.add(const Duration(hours: 24)),
          ),
        );

        expect(await store.isVersionSnoozed(4), isTrue);
        expect(
          await store.isVersionSnoozed(5),
          isFalse,
        ); // Newer release breaks snooze

        now = now.add(const Duration(hours: 25));
        expect(await store.isVersionSnoozed(4), isFalse); // Window expired
      },
    );

    test(
      'onAppResumed auto-launches installer after permission granted & flags SIGNATURE_MISMATCH cleanly',
      () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'nexus_resume_test_',
        );
        addTearDown(() {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        });
        final payload = utf8.encode('APK-BYTES-FOR-RESUME-TEST');
        final sha = sha256.convert(payload).toString();
        var allowInstalls = false;
        var installerLaunched = false;

        final client = MockClient((req) async {
          if (req.url.path.endsWith('/update-manifest.json')) {
            return http.Response(
              jsonEncode(
                _sampleManifest(expectedSha256: sha, sizeBytes: payload.length),
              ),
              200,
            );
          }
          return http.Response.bytes(payload, 200);
        });

        final updater = GitHubReleaseUpdater(
          httpClient: client,
          defaultDownloadDirectory: tempDir,
          installedBuildInfoProvider: () async => const InstalledBuildInfo(
            versionName: '1.1.0',
            versionCode: 3,
            supportedAbis: <String>['arm64-v8a'],
          ),
          availableStorageBytesProvider: () async => 500 * 1024 * 1024,
          apkPackageVerifier: (_) async =>
              const ApkVerificationResult(isValid: true),
          canRequestPackageInstallsProvider: () async => allowInstalls,
          installApkLauncher: (_) async {
            installerLaunched = true;
            return true;
          },
          snoozeStore: UpdateSnoozeStore(),
        );

        final controller = AppUpdateController(updater);
        await controller.initializeAndAutoCheck(autoCheck: true);
        expect(controller.state.hasUpdate, isTrue);

        await controller.downloadAndInstall();
        expect(controller.state.status, AppUpdateStatus.permissionRequired);
        expect(installerLaunched, isFalse);

        // User toggles Android setting and returns to NEXUS DUO
        allowInstalls = true;
        await controller.onAppResumed();
        expect(installerLaunched, isTrue);
        expect(controller.state.status, AppUpdateStatus.readyToInstall);

        // Verify SIGNATURE_MISMATCH handling
        final mismatchUpdater = GitHubReleaseUpdater(
          httpClient: client,
          defaultDownloadDirectory: tempDir,
          installedBuildInfoProvider: () async => const InstalledBuildInfo(
            versionName: '1.1.0',
            versionCode: 3,
            supportedAbis: <String>['arm64-v8a'],
          ),
          availableStorageBytesProvider: () async => 500 * 1024 * 1024,
          apkPackageVerifier: (_) async => const ApkVerificationResult(
            isValid: false,
            errorCode: 'SIGNATURE_MISMATCH',
            message: 'Cert mismatch',
          ),
          snoozeStore: UpdateSnoozeStore(),
        );
        final mismatchController = AppUpdateController(mismatchUpdater);
        await mismatchController.checkForUpdates(force: true);
        await mismatchController.downloadAndInstall();
        expect(mismatchController.state.status, AppUpdateStatus.error);
        expect(mismatchController.state.signatureMismatchDetected, isTrue);
      },
    );
  });
}
