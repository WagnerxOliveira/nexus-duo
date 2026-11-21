import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexus_duo/core/domain/value_objects/profile_db_normalizer.dart';
import 'package:nexus_duo/core/errors/app_failure.dart';
import 'package:nexus_duo/core/updater/github_release_updater.dart';

void main() {
  group('GitHubReleaseUpdater.selectBestApkAsset', () {
    test(
      'prefers device-matching ABI (~58% smaller) when supportedAbis provided',
      () {
        final assets = <Map<String, dynamic>>[
          <String, dynamic>{'name': 'nexus-duo-v1.1.0-x86_64.apk'},
          <String, dynamic>{'name': 'nexus-duo-v1.1.0-armeabi-v7a.apk'},
          <String, dynamic>{'name': 'nexus-duo-v1.1.0-arm64-v8a.apk'},
          <String, dynamic>{'name': 'nexus-duo-v1.1.0-universal.apk'},
        ];

        expect(
          GitHubReleaseUpdater.selectBestApkAsset(
            assets,
            supportedAbis: const <String>['arm64-v8a', 'armeabi-v7a'],
          )?['name'],
          'nexus-duo-v1.1.0-arm64-v8a.apk',
        );
        expect(
          GitHubReleaseUpdater.selectBestApkAsset(
            assets,
            supportedAbis: const <String>['armeabi-v7a'],
          )?['name'],
          'nexus-duo-v1.1.0-armeabi-v7a.apk',
        );
      },
    );

    test(
      'prefers universal APK over ABI-split APKs when supportedAbis is empty',
      () {
        final assets = <Map<String, dynamic>>[
          <String, dynamic>{'name': 'nexus-duo-v1.0.1-x86_64.apk'},
          <String, dynamic>{'name': 'nexus-duo-v1.0.1-armeabi-v7a.apk'},
          <String, dynamic>{'name': 'nexus-duo-v1.0.1-arm64-v8a.apk'},
          <String, dynamic>{'name': 'nexus-duo-v1.0.1-universal.apk'},
        ];

        final picked = GitHubReleaseUpdater.selectBestApkAsset(assets);
        expect(picked?['name'], 'nexus-duo-v1.0.1-universal.apk');
      },
    );

    test('falls back to arm64-v8a before x86_64 when universal is absent', () {
      final assets = <Map<String, dynamic>>[
        <String, dynamic>{'name': 'app-x86_64-release.apk'},
        <String, dynamic>{'name': 'app-arm64-v8a-release.apk'},
      ];

      final picked = GitHubReleaseUpdater.selectBestApkAsset(assets);
      expect(picked?['name'], 'app-arm64-v8a-release.apk');
    });

    test('picks clean single APK asset like nexus-duo-v1.0.0.apk', () {
      final assets = <Map<String, dynamic>>[
        <String, dynamic>{'name': 'SHA256SUMS.txt'},
        <String, dynamic>{'name': 'nexus-duo-v1.0.0.apk'},
      ];

      final picked = GitHubReleaseUpdater.selectBestApkAsset(assets);
      expect(picked?['name'], 'nexus-duo-v1.0.0.apk');
    });
  });

  group('GitHubReleaseUpdater streaming download & SHA-256 verification', () {
    test(
      'streams APK to disk, verifies incremental SHA-256, and rejects tampering',
      () async {
        final payloadBytes = utf8.encode('FAKE-SIGNED-APK-STREAM-PAYLOAD-V110');
        final validSha = sha256.convert(payloadBytes).toString();
        final tempDir = Directory.systemTemp.createTempSync(
          'nexus_updater_test_',
        );
        addTearDown(() {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        });

        final client = MockClient((request) async {
          return http.Response.bytes(payloadBytes, 200);
        });
        final updater = GitHubReleaseUpdater(
          httpClient: client,
          currentVersionProvider: () async => '1.0.1',
        );

        final validInfo = ReleaseUpdateInfo(
          currentVersion: '1.0.1',
          latestVersion: '1.1.0',
          hasUpdate: true,
          releaseNotes: 'Test notes',
          htmlUrl:
              'https://github.com/WagnerxOliveira/nexus-duo/releases/tag/v1.1.0',
          apkDownloadUrl:
              'https://github.com/WagnerxOliveira/nexus-duo/releases/download/v1.1.0/nexus-duo-v1.1.0-arm64-v8a.apk',
          apkFileName: 'nexus-duo-v1.1.0-arm64-v8a.apk',
          apkSizeBytes: payloadBytes.length,
          expectedSha256: validSha,
        );

        final progressSteps = <double>[];
        final okRes = await updater.downloadAndVerifyApk(
          validInfo,
          onProgress: progressSteps.add,
          downloadDirectoryOverride: tempDir,
        );
        expect(okRes.isSuccess, isTrue);
        expect(okRes.valueOrNull!.existsSync(), isTrue);
        expect(progressSteps.last, 1.0);

        final tamperedInfo = ReleaseUpdateInfo(
          currentVersion: '1.0.1',
          latestVersion: '1.1.0',
          hasUpdate: true,
          releaseNotes: 'Test notes',
          htmlUrl:
              'https://github.com/WagnerxOliveira/nexus-duo/releases/tag/v1.1.0',
          apkDownloadUrl:
              'https://github.com/WagnerxOliveira/nexus-duo/releases/download/v1.1.0/nexus-duo-v1.1.0-arm64-v8a.apk',
          apkFileName: 'nexus-duo-v1.1.0-tampered.apk',
          apkSizeBytes: payloadBytes.length,
          expectedSha256: '0' * 64,
        );

        final badRes = await updater.downloadAndVerifyApk(
          tamperedInfo,
          downloadDirectoryOverride: tempDir,
        );
        expect(badRes.isFailure, isTrue);
        expect(badRes.failureOrNull, isA<CryptoFailure>());
        expect(badRes.failureOrNull!.code, 'SHA256_MISMATCH');
        expect(
          File(
            '${tempDir.path}/updates/nexus-duo-v1.1.0-tampered.apk.part',
          ).existsSync(),
          isFalse,
        );
      },
    );
  });

  group('ProfileDbNormalizer CHECK constraints', () {
    test('maps PT-BR genders to Postgres enum-checked values', () {
      expect(ProfileDbNormalizer.normalizeGender('Feminino'), 'woman');
      expect(ProfileDbNormalizer.normalizeGender('Masculino'), 'man');
      expect(ProfileDbNormalizer.normalizeGender('Não-binário'), 'non_binary');
      expect(ProfileDbNormalizer.normalizeGender('Outro'), 'other');
    });

    test('normalizes interested_in including "Todos" expansion', () {
      expect(
        ProfileDbNormalizer.normalizeInterestedIn(<String>['Todos']),
        equals(ProfileDbNormalizer.allValidGenders),
      );
      expect(
        ProfileDbNormalizer.normalizeInterestedIn(<String>[
          'Feminino',
          'Feminino',
          'Não-binário',
        ]),
        equals(<String>['woman', 'non_binary']),
      );
    });

    test('enforces ^[a-z0-9_]{3,24}\$ username constraint', () {
      final u1 = ProfileDbNormalizer.normalizeUsername(
        'Valkyrie#BR1!',
        userId: '11111111-1111-4111-8111-111111111111',
      );
      expect(RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(u1), isTrue);
      expect(u1, 'valkyrie_br1');

      final uShort = ProfileDbNormalizer.normalizeUsername(
        '!!',
        userId: 'abcdef12-3456-7890-abcd-ef1234567890',
      );
      expect(RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(uShort), isTrue);
      expect(uShort, 'duo_abcdef');
    });
  });
}
