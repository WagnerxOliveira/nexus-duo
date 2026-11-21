import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_duo/core/domain/value_objects/profile_db_normalizer.dart';
import 'package:nexus_duo/core/updater/github_release_updater.dart';

void main() {
  group('GitHubReleaseUpdater.selectBestApkAsset', () {
    test('prefers universal APK over ABI-split APKs', () {
      final assets = <Map<String, dynamic>>[
        <String, dynamic>{'name': 'nexus-duo-v1.0.1-x86_64.apk'},
        <String, dynamic>{'name': 'nexus-duo-v1.0.1-armeabi-v7a.apk'},
        <String, dynamic>{'name': 'nexus-duo-v1.0.1-arm64-v8a.apk'},
        <String, dynamic>{'name': 'nexus-duo-v1.0.1-universal.apk'},
      ];

      final picked = GitHubReleaseUpdater.selectBestApkAsset(assets);
      expect(picked?['name'], 'nexus-duo-v1.0.1-universal.apk');
    });

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
