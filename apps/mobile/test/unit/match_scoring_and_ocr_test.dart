import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_duo/core/domain/value_objects/gamer_age.dart';
import 'package:nexus_duo/core/domain/value_objects/weekly_schedule_mask.dart';
import 'package:nexus_duo/core/updater/github_release_updater.dart';
import 'package:nexus_duo/features/discovery/domain/match_scoring_strategy.dart';
import 'package:nexus_duo/features/profile/domain/gamer_profile.dart';
import 'package:nexus_duo/features/shared/data/demo_seed_repositories.dart';
import 'package:nexus_duo/features/verification/domain/verification_contracts.dart';

void main() {
  group('IMatchScoringStrategy & Fairness Decay', () {
    late DemoSeedStore store;

    setUp(() {
      store = DemoSeedStore();
    });

    test(
      'HybridGamerScoringStrategy prioritizes DCG #1 game over lower priority games',
      () {
        const strategy = HybridGamerScoringStrategy();
        final me = store.myProfile;

        // Target A shares #1 game (Valorant), Target B only shares #4 game (It Takes Two)
        final targetTopGame = GamerProfile(
          id: 't-1',
          username: 'top_match',
          displayName: 'Top Match',
          age: GamerAge.fromYears(25).valueOrNull!,
          gender: 'Masculino',
          interestedIn: const <String>['Feminino'],
          bio: 'bio',
          promptQuestion: 'q',
          promptAnswer: 'a',
          cityLabel: 'SP',
          distanceKmBucket: '~8 km',
          approximateDistanceKm: 8,
          gamerDna: me.gamerDna,
          scheduleMask: me.scheduleMask,
          games: <UserGameEntry>[
            store.gamesCatalog[0].copyWith(priorityOrder: 1),
          ],
          platforms: me.platforms,
          ggBadges: const <GgBadgeCode>[],
          isLivenessVerified: true,
          e2eePublicKeyB64: me.e2eePublicKeyB64,
        );

        final targetLowerGame = GamerProfile(
          id: 't-2',
          username: 'low_match',
          displayName: 'Low Match',
          age: GamerAge.fromYears(25).valueOrNull!,
          gender: 'Masculino',
          interestedIn: const <String>['Feminino'],
          bio: 'bio',
          promptQuestion: 'q',
          promptAnswer: 'a',
          cityLabel: 'SP',
          distanceKmBucket: '~8 km',
          approximateDistanceKm: 8,
          gamerDna: me.gamerDna,
          scheduleMask: me.scheduleMask,
          games: <UserGameEntry>[
            store.gamesCatalog[8].copyWith(priorityOrder: 1),
            store.gamesCatalog[7].copyWith(priorityOrder: 2),
            store.gamesCatalog[6].copyWith(priorityOrder: 3),
            store.gamesCatalog[5].copyWith(priorityOrder: 4),
          ],
          platforms: me.platforms,
          ggBadges: const <GgBadgeCode>[],
          isLivenessVerified: true,
          e2eePublicKeyB64: me.e2eePublicKeyB64,
        );

        final scoreTop = strategy.calculate(me: me, target: targetTopGame);
        final scoreLow = strategy.calculate(me: me, target: targetLowerGame);

        expect(scoreTop.gamesScore, greaterThan(scoreLow.gamesScore));
        expect(
          scoreTop.totalScorePercent,
          greaterThan(scoreLow.totalScorePercent),
        );
      },
    );

    test('Exposure Fairness Decay penalizes overexposed profiles', () {
      const strategy = HybridGamerScoringStrategy();
      final me = store.myProfile;
      final baseTarget = store.discoveryPool.first;

      final freshTarget = GamerProfile(
        id: baseTarget.id,
        username: baseTarget.username,
        displayName: baseTarget.displayName,
        age: baseTarget.age,
        gender: baseTarget.gender,
        interestedIn: baseTarget.interestedIn,
        bio: baseTarget.bio,
        promptQuestion: baseTarget.promptQuestion,
        promptAnswer: baseTarget.promptAnswer,
        cityLabel: baseTarget.cityLabel,
        distanceKmBucket: baseTarget.distanceKmBucket,
        approximateDistanceKm: baseTarget.approximateDistanceKm,
        gamerDna: baseTarget.gamerDna,
        scheduleMask: baseTarget.scheduleMask,
        games: baseTarget.games,
        platforms: baseTarget.platforms,
        ggBadges: baseTarget.ggBadges,
        isLivenessVerified: true,
        e2eePublicKeyB64: baseTarget.e2eePublicKeyB64,
        dailyImpressions: 1,
        isNewbie: true,
      );

      final overexposedTarget = GamerProfile(
        id: baseTarget.id,
        username: baseTarget.username,
        displayName: baseTarget.displayName,
        age: baseTarget.age,
        gender: baseTarget.gender,
        interestedIn: baseTarget.interestedIn,
        bio: baseTarget.bio,
        promptQuestion: baseTarget.promptQuestion,
        promptAnswer: baseTarget.promptAnswer,
        cityLabel: baseTarget.cityLabel,
        distanceKmBucket: baseTarget.distanceKmBucket,
        approximateDistanceKm: baseTarget.approximateDistanceKm,
        gamerDna: baseTarget.gamerDna,
        scheduleMask: baseTarget.scheduleMask,
        games: baseTarget.games,
        platforms: baseTarget.platforms,
        ggBadges: baseTarget.ggBadges,
        isLivenessVerified: true,
        e2eePublicKeyB64: baseTarget.e2eePublicKeyB64,
        dailyImpressions: 80,
        isNewbie: false,
      );

      final freshRes = strategy.calculate(me: me, target: freshTarget);
      final overRes = strategy.calculate(me: me, target: overexposedTarget);

      expect(freshRes.rawTotalScore, closeTo(overRes.rawTotalScore, 1e-6));
      expect(freshRes.rankScore, greaterThan(overRes.rankScore * 2.0));
    });

    test(
      'CoopDuoScoringStrategy weighs shared games/schedule higher than far distance',
      () {
        const hybrid = HybridGamerScoringStrategy();
        const coop = CoopDuoScoringStrategy();
        final me = store.myProfile;

        final farButSameGamesAndSchedule = GamerProfile(
          id: 'far-duo',
          username: 'far_duo',
          displayName: 'Far Duo',
          age: me.age,
          gender: 'Masculino',
          interestedIn: const <String>['Feminino'],
          bio: 'bio',
          promptQuestion: 'q',
          promptAnswer: 'a',
          cityLabel: 'Curitiba',
          distanceKmBucket: '~120 km',
          approximateDistanceKm: 120,
          gamerDna: me.gamerDna,
          scheduleMask: WeeklyScheduleMask.full(),
          games: me.games,
          platforms: me.platforms,
          ggBadges: const <GgBadgeCode>[],
          isLivenessVerified: true,
          e2eePublicKeyB64: me.e2eePublicKeyB64,
        );

        final hybridScore = hybrid.calculate(
          me: me,
          target: farButSameGamesAndSchedule,
        );
        final coopScore = coop.calculate(
          me: me,
          target: farButSameGamesAndSchedule,
        );

        expect(coopScore.rawTotalScore, greaterThan(hybridScore.rawTotalScore));
        expect(coopScore.strategyName, equals('CoopDuoScoringStrategy'));
      },
    );
  });

  group('IRankOcrParser Polymorphic Chain', () {
    const chain = RankOcrParserChain();

    test('parses Valorant noisy screenshot text', () {
      final result = chain.parse('''
        VALORANT // CARREIRA ATO 3
        Valkyrie#BR1
        RANK ATUAL: Platina II   68 RR
      ''');
      expect(result, isNotNull);
      expect(result!.gameTitle, equals('Valorant'));
      expect(result.gamertag, equals('Valkyrie#BR1'));
      expect(result.rankLabel, equals('Platina II'));
      expect(result.parserName, equals('ValorantOcrParser'));
    });

    test('parses League of Legends screenshot text', () {
      final result = chain.parse('''
        League of Legends - Solo/Duo
        KaelMid#BR1
        Esmeralda IV • 42 PDL
      ''');
      expect(result, isNotNull);
      expect(result!.gameTitle, equals('League of Legends'));
      expect(result.gamertag, equals('KaelMid#BR1'));
      expect(result.rankLabel, equals('Esmeralda IV'));
      expect(result.parserName, equals('LolOcrParser'));
    });

    test('parses CS2 Premier screenshot text', () {
      final result = chain.parse('''
        Counter-Strike 2 PREMIER SEASON
        Player: Kael_BR
        CS Rating 18.450
      ''');
      expect(result, isNotNull);
      expect(result!.gameTitle, equals('Counter-Strike 2'));
      expect(result.gamertag, equals('Kael_BR'));
      expect(result.rankLabel, equals('18.450 Premier'));
      expect(result.parserName, equals('Cs2OcrParser'));
    });

    test(
      'parses generic Genshin Impact screenshot and rejects empty noise',
      () {
        final genshin = chain.parse('Genshin Impact | UID: 601122 | AR 58');
        expect(genshin, isNotNull);
        expect(genshin!.gameTitle, equals('Genshin Impact'));
        expect(genshin.rankLabel, equals('AR 58'));
        expect(genshin.parserName, equals('GenericGamerOcrParser'));

        expect(chain.parse('apenas texto aleatorio sem jogo'), isNull);
      },
    );
  });

  group('LivenessStateMachine & GitHubReleaseUpdater', () {
    test(
      'LivenessStateMachine completes 3 challenges and resets on face cut',
      () {
        final sm = LivenessStateMachine();
        expect(sm.isCompleted, isFalse);

        // Blink closed -> open
        sm.processFrame(
          const FaceMetricsFrame(
            faceCount: 1,
            trackingId: 7,
            leftEyeOpenProbability: 0.1,
            rightEyeOpenProbability: 0.1,
            headEulerAngleY: 0,
            smilingProbability: 0.1,
          ),
        );
        sm.processFrame(
          const FaceMetricsFrame(
            faceCount: 1,
            trackingId: 7,
            leftEyeOpenProbability: 0.9,
            rightEyeOpenProbability: 0.9,
            headEulerAngleY: 0,
            smilingProbability: 0.1,
          ),
        );
        expect(sm.completedCount, equals(1));

        // Tracking ID cut resets state machine
        sm.processFrame(
          const FaceMetricsFrame(
            faceCount: 1,
            trackingId: 99,
            leftEyeOpenProbability: 0.9,
            rightEyeOpenProbability: 0.9,
            headEulerAngleY: 25,
            smilingProbability: 0.1,
          ),
        );
        expect(sm.completedCount, equals(0));
      },
    );

    test(
      'GitHubReleaseUpdater SemVer comparison & SHA-256 integrity validation',
      () {
        expect(
          GitHubReleaseUpdater.compareSemVer('v1.0.1', '1.0.0'),
          greaterThan(0),
        );
        expect(
          GitHubReleaseUpdater.compareSemVer('v1.0.0', '1.0.0'),
          equals(0),
        );
        expect(
          GitHubReleaseUpdater.compareSemVer('v0.9.9', '1.0.0'),
          lessThan(0),
        );

        final payload = utf8.encode('fake-apk-binary-content');
        final digest = sha256.convert(payload).toString();
        final sumsTxt = '$digest  nexus-duo-v1.0.1-arm64.apk\n';

        final parsed = GitHubReleaseUpdater.parseSha256ForAsset(
          sumsTxt,
          'nexus-duo-v1.0.1-arm64.apk',
        );
        expect(parsed, equals(digest));
        expect(GitHubReleaseUpdater.verifySha256(payload, digest), isTrue);
        expect(
          GitHubReleaseUpdater.verifySha256(utf8.encode('tampered'), digest),
          isFalse,
        );
      },
    );
  });
}
