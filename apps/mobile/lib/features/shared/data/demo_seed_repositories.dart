import 'dart:async';
import 'dart:typed_data';

import '../../../core/crypto/e2ee_cipher.dart';
import '../../../core/domain/value_objects/gamer_age.dart';
import '../../../core/domain/value_objects/weekly_schedule_mask.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/media/avatar_photo_sanitizer.dart';
import '../../../core/security/nexus_password_policy.dart';
import '../../chat/domain/chat_message.dart';
import '../../discovery/domain/discovery_entities.dart';
import '../../discovery/domain/match_scoring_strategy.dart';
import '../../lobby/domain/duo_lobby.dart';
import '../../profile/domain/gamer_profile.dart';
import '../domain/nexus_repositories.dart';

/// Rich offline-ready seed dataset shared across DemoSeed repositories.
///
/// Includes personas Clara/Valkyrie, Lucas/Kael_BR, Beatriz/BiaCozy,
/// Rafael/RafaTank, real games catalog, overlapping schedules, real X25519
/// E2EE encryption/decryption, and active 2-hour lobbies.
class DemoSeedStore {
  DemoSeedStore() {
    _initialize();
  }

  // Deterministic X25519 key pairs (matching crypto_golden_vectors.json)
  static const String _claraPrivB64 =
      'YGkk4j92xxx0nYxvZXaTDjvg5nfX6c7kGaJyy7WcYEw=';
  static const String _claraPubB64 =
      'Lf5/8h/sZzBwu7f1D7KRq9Edf0y1NSFzFbjhiwrqs2E=';
  static const String _lucasPrivB64 =
      'GBoXatNGHkeTsUwxJVuRz3jmYmLvGSGZ3rKuAzm7EGQ=';
  static const String _lucasPubB64 =
      '6G4CBAE6tQC6mdGj6cOLjJPkS+WZ2pn8K+/hneZ78Q0=';
  static const String _biaPrivB64 =
      'mDxrdIEKT0kPMg2oLQGg/ddn5zKVEGzMhsmFpvk4KF0=';
  static const String _biaPubB64 =
      'lNvQ74Jl1TvHOHYNNRoJlf1cMAwwfAEBT7nK5iPNTyk=';

  late final AesGcmE2EECipher myCipher;
  final Map<String, ({String password, bool verified})> demoAccounts =
      <String, ({String password, bool verified})>{
        'clara@nexusduo.app': (password: 'K9#vQ2!pX4', verified: true),
        'demo@nexusduo.app': (password: 'K9#vQ2!pX4', verified: true),
        'valkyrie@nexusduo.app': (password: 'K9#vQ2!pX4', verified: true),
      };
  final Map<String, String> demoResetTokens = <String, String>{};
  late final Map<String, AesGcmE2EECipher> peerCiphers;

  AuthSession? session;
  late GamerProfile myProfile;
  late List<UserGameEntry> gamesCatalog;
  late List<GamerProfile> discoveryPool;
  final Set<String> swipedIds = <String>{};
  final Set<String> blockedIds = <String>{};
  final List<DuoMatch> matches = <DuoMatch>[];
  final List<DuoLobby> lobbies = <DuoLobby>[];
  final Map<String, List<ChatMessage>> messagesByMatch =
      <String, List<ChatMessage>>{};
  final Map<String, StreamController<List<ChatMessage>>> _messageStreams =
      <String, StreamController<List<ChatMessage>>>{};

  void _initialize() {
    myCipher = AesGcmE2EECipher(
      keyVault: InMemorySecureKeyVault.fromBase64(
        privateKeyB64: _claraPrivB64,
        publicKeyB64: _claraPubB64,
      ),
    );

    final lucasCipher = AesGcmE2EECipher(
      keyVault: InMemorySecureKeyVault.fromBase64(
        privateKeyB64: _lucasPrivB64,
        publicKeyB64: _lucasPubB64,
      ),
    );
    final biaCipher = AesGcmE2EECipher(
      keyVault: InMemorySecureKeyVault.fromBase64(
        privateKeyB64: _biaPrivB64,
        publicKeyB64: _biaPubB64,
      ),
    );
    peerCiphers = <String, AesGcmE2EECipher>{
      '22222222-2222-4222-8222-222222222222': lucasCipher,
      '33333333-3333-4333-8333-333333333333': biaCipher,
      '44444444-4444-4444-8444-444444444444': lucasCipher,
    };

    gamesCatalog = const <UserGameEntry>[
      UserGameEntry(
        gameId: 1,
        title: 'Valorant',
        slug: 'valorant',
        genres: <String>['FPS', 'Tático', 'Competitivo'],
        platforms: <GamerPlatform>[GamerPlatform.pc, GamerPlatform.ps5],
        supportsCrossplay: false,
        priorityOrder: 1,
        rankLabel: 'Platina II',
        isRankOcrVerified: true,
        verifiedGamertag: 'Valkyrie#BR1',
        hoursPlayed: 520,
        preferredMode: 'Ranked',
      ),
      UserGameEntry(
        gameId: 2,
        title: 'Baldur\'s Gate 3',
        slug: 'baldurs-gate-3',
        genres: <String>['RPG', 'Co-op', 'Narrativo'],
        platforms: <GamerPlatform>[
          GamerPlatform.pc,
          GamerPlatform.ps5,
          GamerPlatform.xbox,
        ],
        supportsCrossplay: true,
        priorityOrder: 2,
        hoursPlayed: 240,
        preferredMode: 'Co-op',
      ),
      UserGameEntry(
        gameId: 3,
        title: 'Stardew Valley',
        slug: 'stardew-valley',
        genres: <String>['Cozy', 'Indie', 'Co-op'],
        platforms: <GamerPlatform>[
          GamerPlatform.pc,
          GamerPlatform.switchConsole,
          GamerPlatform.mobile,
        ],
        supportsCrossplay: false,
        priorityOrder: 3,
        hoursPlayed: 195,
        preferredMode: 'Co-op',
      ),
      UserGameEntry(
        gameId: 4,
        title: 'League of Legends',
        slug: 'league-of-legends',
        genres: <String>['MOBA', 'Estratégia', 'Competitivo'],
        platforms: <GamerPlatform>[GamerPlatform.pc],
        supportsCrossplay: false,
        priorityOrder: 4,
        rankLabel: 'Esmeralda IV',
        hoursPlayed: 610,
        preferredMode: 'Ranked',
      ),
      UserGameEntry(
        gameId: 5,
        title: 'Counter-Strike 2',
        slug: 'counter-strike-2',
        genres: <String>['FPS', 'Tático', 'Competitivo'],
        platforms: <GamerPlatform>[GamerPlatform.pc],
        supportsCrossplay: false,
        priorityOrder: 5,
        rankLabel: '18.450 Premier',
        hoursPlayed: 480,
        preferredMode: 'Ranked',
      ),
      UserGameEntry(
        gameId: 6,
        title: 'It Takes Two',
        slug: 'it-takes-two',
        genres: <String>['Co-op', 'Aventura', 'Narrativo'],
        platforms: <GamerPlatform>[
          GamerPlatform.pc,
          GamerPlatform.ps5,
          GamerPlatform.xbox,
          GamerPlatform.switchConsole,
        ],
        supportsCrossplay: true,
        priorityOrder: 5,
        hoursPlayed: 38,
        preferredMode: 'Co-op',
      ),
      UserGameEntry(
        gameId: 7,
        title: 'Overwatch 2',
        slug: 'overwatch-2',
        genres: <String>['FPS', 'Hero Shooter', 'Co-op'],
        platforms: <GamerPlatform>[
          GamerPlatform.pc,
          GamerPlatform.ps5,
          GamerPlatform.xbox,
        ],
        supportsCrossplay: true,
        priorityOrder: 5,
        rankLabel: 'Diamante III',
        hoursPlayed: 310,
        preferredMode: 'Casual',
      ),
      UserGameEntry(
        gameId: 8,
        title: 'Genshin Impact',
        slug: 'genshin-impact',
        genres: <String>['RPG', 'Aventura', 'Co-op'],
        platforms: <GamerPlatform>[
          GamerPlatform.pc,
          GamerPlatform.ps5,
          GamerPlatform.mobile,
        ],
        supportsCrossplay: true,
        priorityOrder: 5,
        rankLabel: 'AR 58',
        hoursPlayed: 420,
        preferredMode: 'Co-op',
      ),
      UserGameEntry(
        gameId: 9,
        title: 'Rocket League',
        slug: 'rocket-league',
        genres: <String>['Esporte', 'Arcade', 'Competitivo'],
        platforms: <GamerPlatform>[
          GamerPlatform.pc,
          GamerPlatform.ps5,
          GamerPlatform.xbox,
          GamerPlatform.switchConsole,
        ],
        supportsCrossplay: true,
        priorityOrder: 5,
        rankLabel: 'Champion I',
        hoursPlayed: 290,
        preferredMode: 'Casual',
      ),
    ];

    // Active User Persona: Clara / Valkyrie
    myProfile = GamerProfile(
      id: '11111111-1111-4111-8111-111111111111',
      username: 'valkyrie',
      displayName: 'Clara (Valkyrie)',
      age: GamerAge.fromYears(25).valueOrNull!,
      gender: 'Feminino',
      interestedIn: const <String>['Masculino', 'Feminino', 'Não-binário'],
      bio:
          'Main Controladora no Valorant sem tilt, apaixonada por RPG narrativo e café às 22h. Buscando duo fixo que ria nas derrotas.',
      promptQuestion: 'Meu encontro co-op perfeito:',
      promptAnswer:
          'Swiftplay aquecendo no Valorant seguido de campanha co-op em Baldur\'s Gate 3 até meia-noite.',
      cityLabel: 'São Paulo, SP',
      distanceKmBucket: '< 5 km',
      approximateDistanceKm: 2.0,
      gamerDna: const GamerDna(
        competitiveScore: 62,
        voicePreferenceScore: 84,
        coopFocusScore: 90,
        nightOwlScore: 76,
        archetypeTitle: 'Tático Tranquilo',
      ),
      scheduleMask: WeeklyScheduleMask.fromDayPeriods(const <int, Set<int>>{
        0: <int>{2}, // Seg noite
        1: <int>{2}, // Ter noite
        2: <int>{2}, // Qua noite
        3: <int>{2}, // Qui noite
        4: <int>{2, 3}, // Sex noite + madrugada
        5: <int>{1, 2, 3}, // Sáb tarde/noite/madrugada
        6: <int>{1, 2, 3}, // Dom tarde/noite/madrugada (wrap-around!)
      }),
      games: <UserGameEntry>[
        gamesCatalog[0], // Valorant
        gamesCatalog[1], // BG3
        gamesCatalog[2], // Stardew
        gamesCatalog[5], // It Takes Two
      ],
      platforms: const <GamerPlatform>[
        GamerPlatform.pc,
        GamerPlatform.switchConsole,
      ],
      ggBadges: const <GgBadgeCode>[
        GgBadgeCode.greatComms,
        GgBadgeCode.zeroTilt,
        GgBadgeCode.squadPartner,
      ],
      isLivenessVerified: true,
      e2eePublicKeyB64: _claraPubB64,
      discordHandle: '@valkyrie.gg',
      steamId: 'valkyrie_br',
      avatarGradientHex: const <int>[0xFF8B5CF6, 0xFFEC4899],
    );

    // Candidate 1: Lucas / Kael_BR
    final lucas = GamerProfile(
      id: '22222222-2222-4222-8222-222222222222',
      username: 'kael_br',
      displayName: 'Lucas (Kael_BR)',
      age: GamerAge.fromYears(26).valueOrNull!,
      gender: 'Masculino',
      interestedIn: const <String>['Feminino'],
      bio:
          'Engenheiro de dia, IGL calmo no Valorant e mago atrapalhado no Baldur\'s Gate 3 à noite. Zero toxicidade, 100% call boa.',
      promptQuestion: 'Você sabe que deu química no lobby quando...',
      promptAnswer:
          'A gente erra a smoke junto, ri por 5 minutos e ainda vira o round no eco.',
      cityLabel: 'São Paulo, SP',
      distanceKmBucket: '~8 km',
      approximateDistanceKm: 8.0,
      gamerDna: const GamerDna(
        competitiveScore: 68,
        voicePreferenceScore: 88,
        coopFocusScore: 86,
        nightOwlScore: 74,
        archetypeTitle: 'Estrategista Tático',
      ),
      scheduleMask: WeeklyScheduleMask.fromDayPeriods(const <int, Set<int>>{
        0: <int>{2},
        2: <int>{2},
        4: <int>{2, 3},
        5: <int>{1, 2, 3},
        6: <int>{2, 3},
      }),
      games: <UserGameEntry>[
        gamesCatalog[0].copyWith(
          rankLabel: 'Diamante I',
          isRankOcrVerified: true,
          verifiedGamertag: 'Kael_BR#VCT',
          priorityOrder: 1,
        ),
        gamesCatalog[1].copyWith(priorityOrder: 2),
        gamesCatalog[4].copyWith(
          rankLabel: '18.450 Premier',
          isRankOcrVerified: true,
          verifiedGamertag: 'Kael_BR',
          priorityOrder: 3,
        ),
      ],
      platforms: const <GamerPlatform>[GamerPlatform.pc, GamerPlatform.ps5],
      ggBadges: const <GgBadgeCode>[
        GgBadgeCode.greatComms,
        GgBadgeCode.zeroTilt,
        GgBadgeCode.respectful,
      ],
      isLivenessVerified: true,
      e2eePublicKeyB64: _lucasPubB64,
      discordHandle: '@kael_br',
      steamId: 'kael_br_steam',
      dailyImpressions: 4,
      avatarGradientHex: const <int>[0xFF06B6D4, 0xFF8B5CF6],
    );

    // Candidate 2: Beatriz / BiaCozy
    final beatriz = GamerProfile(
      id: '33333333-3333-4333-8333-333333333333',
      username: 'biacozy',
      displayName: 'Beatriz (BiaCozy)',
      age: GamerAge.fromYears(24).valueOrNull!,
      gender: 'Feminino',
      interestedIn: const <String>['Feminino', 'Masculino', 'Não-binário'],
      bio:
          'Ilustradora, viciada em Stardew Valley co-op, It Takes Two e RPGs com boa história. Prometo não vender suas sementes por engano.',
      promptQuestion: 'Fazenda organizada ou caos criativo?',
      promptAnswer:
          'Planilha de plantações na primavera e caos total decorando a casa com 40 abajures.',
      cityLabel: 'Pinheiros, SP',
      distanceKmBucket: '~11 km',
      approximateDistanceKm: 11.0,
      gamerDna: const GamerDna(
        competitiveScore: 28,
        voicePreferenceScore: 72,
        coopFocusScore: 95,
        nightOwlScore: 60,
        archetypeTitle: 'Cozy Explorador',
      ),
      scheduleMask: WeeklyScheduleMask.fromDayPeriods(const <int, Set<int>>{
        1: <int>{2},
        3: <int>{2},
        5: <int>{1, 2},
        6: <int>{1, 2},
      }),
      games: <UserGameEntry>[
        gamesCatalog[2].copyWith(priorityOrder: 1),
        gamesCatalog[5].copyWith(priorityOrder: 2),
        gamesCatalog[1].copyWith(priorityOrder: 3),
        gamesCatalog[7].copyWith(
          rankLabel: 'AR 58',
          isRankOcrVerified: true,
          verifiedGamertag: 'BiaCozy',
          priorityOrder: 4,
        ),
      ],
      platforms: const <GamerPlatform>[
        GamerPlatform.pc,
        GamerPlatform.switchConsole,
      ],
      ggBadges: const <GgBadgeCode>[
        GgBadgeCode.greatVibe,
        GgBadgeCode.squadPartner,
        GgBadgeCode.respectful,
      ],
      isLivenessVerified: true,
      e2eePublicKeyB64: _biaPubB64,
      discordHandle: '@biacozy',
      steamId: 'biacozy_indie',
      dailyImpressions: 2,
      isNewbie: true,
      avatarGradientHex: const <int>[0xFFEC4899, 0xFFF59E0B],
    );

    // Candidate 3: Rafael / RafaTank
    final rafael = GamerProfile(
      id: '44444444-4444-4444-8444-444444444444',
      username: 'rafatank',
      displayName: 'Rafael (RafaTank)',
      age: GamerAge.fromYears(28).valueOrNull!,
      gender: 'Masculino',
      interestedIn: const <String>['Feminino'],
      bio:
          'Main Tank no Overwatch 2 e Top Laner no LoL que sempre protege o duo. Curto trilha sonora de jogos, sushi e partidas de sexta à noite.',
      promptQuestion: 'Meu superpoder em squad:',
      promptAnswer:
          'Call tranquila mesmo quando o time está 3x10 atrás — e sempre lembrar de dar peel.',
      cityLabel: 'Vila Mariana, SP',
      distanceKmBucket: '~6 km',
      approximateDistanceKm: 6.0,
      gamerDna: const GamerDna(
        competitiveScore: 76,
        voicePreferenceScore: 80,
        coopFocusScore: 82,
        nightOwlScore: 85,
        archetypeTitle: 'Dupla Raiz',
      ),
      scheduleMask: WeeklyScheduleMask.fromDayPeriods(const <int, Set<int>>{
        0: <int>{2},
        3: <int>{2},
        4: <int>{2, 3},
        5: <int>{2, 3},
        6: <int>{2},
      }),
      games: <UserGameEntry>[
        gamesCatalog[6].copyWith(
          rankLabel: 'Diamante II',
          isRankOcrVerified: true,
          verifiedGamertag: 'RafaTank#1337',
          priorityOrder: 1,
        ),
        gamesCatalog[3].copyWith(
          rankLabel: 'Esmeralda III',
          isRankOcrVerified: true,
          verifiedGamertag: 'RafaTank#BR1',
          priorityOrder: 2,
        ),
        gamesCatalog[0].copyWith(rankLabel: 'Ouro III', priorityOrder: 3),
      ],
      platforms: const <GamerPlatform>[
        GamerPlatform.pc,
        GamerPlatform.ps5,
        GamerPlatform.xbox,
      ],
      ggBadges: const <GgBadgeCode>[
        GgBadgeCode.squadPartner,
        GgBadgeCode.zeroTilt,
        GgBadgeCode.greatComms,
      ],
      isLivenessVerified: true,
      e2eePublicKeyB64: _lucasPubB64,
      discordHandle: '@rafatank',
      steamId: 'rafatank_gg',
      dailyImpressions: 3,
      avatarGradientHex: const <int>[0xFF10B981, 0xFF06B6D4],
    );

    discoveryPool = <GamerProfile>[lucas, beatriz, rafael];

    // Pre-seed one active Match with Lucas so Chat E2EE works immediately too!
    const strategy = HybridGamerScoringStrategy();
    final lucasBreakdown = strategy.calculate(me: myProfile, target: lucas);
    final seededMatch = DuoMatch(
      id: '550e8400-e29b-41d4-a716-446655440001',
      peer: lucas,
      compatibilityScore: lucasBreakdown.totalScorePercent,
      commonHoursPerWeek: lucasBreakdown.commonHoursPerWeek,
      icebreakerPrompts: CoopIcebreakerGenerator.generate(
        me: myProfile,
        peer: lucas,
        breakdown: lucasBreakdown,
      ),
      createdAt: DateTime.now().subtract(const Duration(minutes: 42)),
      lastMessagePreview: 'Topa um Swiftplay hoje às 21h? 🎮💜',
    );
    matches.add(seededMatch);

    // Seed real E2EE messages asynchronously on first chat load
    final now = DateTime.now();
    lobbies.addAll(<DuoLobby>[
      DuoLobby(
        id: 'lobby-1',
        hostId: lucas.id,
        hostDisplayName: lucas.displayName,
        hostUsername: lucas.username,
        hostVerified: true,
        gameTitle: 'Valorant',
        mode: LobbyMode.casual,
        voicePreference: VoicePreference.discord,
        notes: 'Aquecendo 2 Swiftplays tranquilos sem pressão, call aberta!',
        expiresAt: now.add(const Duration(hours: 1, minutes: 44)),
        compatibilityScore: lucasBreakdown.totalScorePercent,
        discordHandle: lucas.discordHandle,
      ),
      DuoLobby(
        id: 'lobby-2',
        hostId: beatriz.id,
        hostDisplayName: beatriz.displayName,
        hostUsername: beatriz.username,
        hostVerified: true,
        gameTitle: 'Stardew Valley',
        mode: LobbyMode.coop,
        voicePreference: VoicePreference.discord,
        notes: 'Começando fazenda nova na praia! Café e trilha lo-fi.',
        expiresAt: now.add(const Duration(hours: 1, minutes: 18)),
        compatibilityScore: 91,
        discordHandle: beatriz.discordHandle,
      ),
      DuoLobby(
        id: 'lobby-3',
        hostId: rafael.id,
        hostDisplayName: rafael.displayName,
        hostUsername: rafael.username,
        hostVerified: true,
        gameTitle: 'Overwatch 2',
        mode: LobbyMode.ranked,
        voicePreference: VoicePreference.inGame,
        notes:
            'Buscando suporte ou DPS que curta call calma e foco em objetivo.',
        expiresAt: now.add(const Duration(minutes: 52)),
        compatibilityScore: 87,
        discordHandle: rafael.discordHandle,
      ),
    ]);
  }

  StreamController<List<ChatMessage>> controllerForMatch(String matchId) {
    return _messageStreams.putIfAbsent(
      matchId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
  }
}

class DemoSeedAuthRepository implements IAuthRepository {
  DemoSeedAuthRepository(this._store);

  final DemoSeedStore _store;

  @override
  Future<AuthSession?> currentSession() async => _store.session;

  @override
  Future<Result<AuthSession>> signInWithDiscord() async {
    final session = AuthSession(
      userId: _store.myProfile.id,
      email: 'valkyrie@nexusduo.app',
      provider: 'discord_demo',
      isDemo: true,
      hasCompletedOnboarding: false,
    );
    _store.session = session;
    return Success<AuthSession>(session);
  }

  static const String demoOtpCode = '123456';

  String _mask(String email) {
    final clean = email.trim().toLowerCase();
    final parts = clean.split('@');
    if (parts.length != 2) return '***';
    final local = parts[0];
    final domain = parts[1];
    if (local.length <= 2) {
      return '${local.isEmpty ? '*' : local[0]}***@$domain';
    }
    return '${local[0]}***${local[local.length - 1]}@$domain';
  }

  @override
  Future<Result<AccountLookupStatus>> checkAccountStatus(String email) async {
    final clean = email.trim().toLowerCase();
    if (!clean.contains('@') || !clean.contains('.')) {
      return const FailureResult<AccountLookupStatus>(
        ValidationFailure('Informe um e-mail válido.', code: 'INVALID_EMAIL'),
      );
    }
    final record = _store.demoAccounts[clean];
    if (record == null) {
      return const Success<AccountLookupStatus>(AccountLookupStatus.notFound);
    }
    return Success<AccountLookupStatus>(
      record.verified
          ? AccountLookupStatus.active
          : AccountLookupStatus.unverified,
    );
  }

  @override
  Future<Result<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final clean = email.trim().toLowerCase();
    if (!clean.contains('@') || password.isEmpty) {
      return const FailureResult<AuthSession>(
        ValidationFailure('Informe um e-mail válido e sua senha.'),
      );
    }
    final record = _store.demoAccounts[clean];
    if (record == null) {
      return const FailureResult<AuthSession>(
        AuthFailure(
          'Nenhuma conta encontrada para este e-mail.',
          code: 'ACCOUNT_NOT_FOUND',
        ),
      );
    }
    if (!record.verified) {
      return const FailureResult<AuthSession>(
        AuthFailure(
          'Seu e-mail ainda aguarda validação do código de 6 dígitos.',
          code: 'EMAIL_NOT_CONFIRMED',
        ),
      );
    }
    if (record.password != password) {
      return const FailureResult<AuthSession>(
        AuthFailure('E-mail ou senha incorretos.', code: 'INVALID_CREDENTIALS'),
      );
    }
    final session = AuthSession(
      userId: _store.myProfile.id,
      email: clean,
      provider: 'email_demo',
      isDemo: true,
      hasCompletedOnboarding: false,
    );
    _store.session = session;
    return Success<AuthSession>(session);
  }

  @override
  Future<Result<OtpDispatchInfo>> startEmailRegistration({
    required String email,
    required String confirmEmail,
    required String password,
    required String confirmPassword,
    required bool acceptTerms,
    required bool confirmAge18Plus,
    required String termsVersion,
    required String privacyVersion,
    required String appVersion,
  }) async {
    final clean = email.trim().toLowerCase();
    final cleanConfirm = confirmEmail.trim().toLowerCase();
    if (!clean.contains('@') || !clean.contains('.')) {
      return const FailureResult<OtpDispatchInfo>(
        ValidationFailure('Informe um e-mail válido.', code: 'INVALID_EMAIL'),
      );
    }
    if (clean != cleanConfirm) {
      return const FailureResult<OtpDispatchInfo>(
        ValidationFailure(
          'Os dois campos de e-mail devem ser idênticos.',
          code: 'EMAIL_MISMATCH',
        ),
      );
    }
    if (!acceptTerms || !confirmAge18Plus) {
      return const FailureResult<OtpDispatchInfo>(
        ValidationFailure(
          'Você precisa confirmar ter 18+ anos e aceitar os Termos de Uso e LGPD.',
          code: 'LEGAL_CONSENT_REQUIRED',
        ),
      );
    }
    if (password != confirmPassword) {
      return const FailureResult<OtpDispatchInfo>(
        ValidationFailure(
          'As duas senhas digitadas não conferem.',
          code: 'PASSWORD_MISMATCH',
        ),
      );
    }
    final policy = NexusPasswordPolicy.evaluate(password, email: clean);
    if (!policy.isValid) {
      return FailureResult<OtpDispatchInfo>(
        ValidationFailure(
          policy.primaryErrorMessage ??
              'A senha não atende aos requisitos de segurança.',
          code: 'PASSWORD_POLICY_VIOLATION',
        ),
      );
    }
    final existing = _store.demoAccounts[clean];
    if (existing != null && existing.verified) {
      return const FailureResult<OtpDispatchInfo>(
        AuthFailure(
          'Este e-mail já possui conta cadastrada.',
          code: 'ACCOUNT_ALREADY_EXISTS',
        ),
      );
    }
    _store.demoAccounts[clean] = (password: password, verified: false);
    return Success<OtpDispatchInfo>(
      OtpDispatchInfo(
        maskedEmail: _mask(clean),
        expiresInSeconds: 600,
        cooldownSeconds: 60,
        demoCodeHint: demoOtpCode,
      ),
    );
  }

  @override
  Future<Result<OtpDispatchInfo>> requestPasswordResetOtp(String email) async {
    final clean = email.trim().toLowerCase();
    if (!_store.demoAccounts.containsKey(clean)) {
      return const FailureResult<OtpDispatchInfo>(
        AuthFailure(
          'Nenhuma conta NEXUS DUO encontrada para este e-mail.',
          code: 'ACCOUNT_NOT_FOUND',
        ),
      );
    }
    return Success<OtpDispatchInfo>(
      OtpDispatchInfo(
        maskedEmail: _mask(clean),
        expiresInSeconds: 600,
        cooldownSeconds: 60,
        demoCodeHint: demoOtpCode,
      ),
    );
  }

  @override
  Future<Result<OtpVerifyResult>> verifyEmailOtp({
    required String email,
    required String code,
    required OtpPurpose purpose,
  }) async {
    final clean = email.trim().toLowerCase();
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      return const FailureResult<OtpVerifyResult>(
        ValidationFailure(
          'Digite os 6 dígitos numéricos do código.',
          code: 'OTP_INVALID_FORMAT',
        ),
      );
    }
    if (code.trim() != demoOtpCode) {
      return const FailureResult<OtpVerifyResult>(
        AuthFailure(
          'Código incorreto (no modo Demo utilize 123456).',
          code: 'OTP_INVALID',
        ),
      );
    }
    final existing = _store.demoAccounts[clean];
    if (existing == null) {
      return const FailureResult<OtpVerifyResult>(
        AuthFailure(
          'Cadastro não encontrado para validação.',
          code: 'OTP_EXPIRED_OR_NOT_FOUND',
        ),
      );
    }
    if (purpose == OtpPurpose.signupVerify) {
      _store.demoAccounts[clean] = (
        password: existing.password,
        verified: true,
      );
      return const Success<OtpVerifyResult>(OtpVerifyResult(verified: true));
    }
    final token = 'demo-reset-token-${clean.hashCode.abs()}';
    _store.demoResetTokens[clean] = token;
    return Success<OtpVerifyResult>(
      OtpVerifyResult(verified: true, resetToken: token),
    );
  }

  @override
  Future<Result<void>> completePasswordReset({
    required String email,
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final clean = email.trim().toLowerCase();
    if (newPassword != confirmPassword) {
      return const FailureResult<void>(
        ValidationFailure('As duas senhas digitadas não conferem.'),
      );
    }
    final policy = NexusPasswordPolicy.evaluate(newPassword, email: clean);
    if (!policy.isValid) {
      return FailureResult<void>(
        ValidationFailure(
          policy.primaryErrorMessage ?? 'Senha fora da política de segurança.',
          code: 'PASSWORD_POLICY_VIOLATION',
        ),
      );
    }
    if (_store.demoResetTokens[clean] != resetToken) {
      return const FailureResult<void>(
        AuthFailure(
          'Sessão de redefinição expirada.',
          code: 'RESET_TOKEN_INVALID',
        ),
      );
    }
    _store.demoAccounts[clean] = (password: newPassword, verified: true);
    _store.demoResetTokens.remove(clean);
    return const Success<void>(null);
  }

  @override
  Future<Result<AuthSession>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    if (!email.contains('@') || password.length < 8) {
      return const FailureResult<AuthSession>(
        ValidationFailure(
          'Informe um email válido e senha com pelo menos 8 caracteres.',
        ),
      );
    }
    final session = AuthSession(
      userId: _store.myProfile.id,
      email: email.trim(),
      provider: 'email_demo',
      isDemo: true,
      hasCompletedOnboarding: false,
    );
    _store.session = session;
    return Success<AuthSession>(session);
  }

  @override
  Future<Result<AuthSession>> enterDemoMode() async {
    final session = AuthSession(
      userId: _store.myProfile.id,
      email: 'clara.valkyrie@demo.nexusduo.app',
      provider: 'instant_demo',
      isDemo: true,
      hasCompletedOnboarding: true,
    );
    _store.session = session;
    return Success<AuthSession>(session);
  }

  @override
  Future<void> signOut() async {
    _store.session = null;
  }
}

class DemoSeedProfileRepository implements IProfileRepository {
  DemoSeedProfileRepository(this._store);

  final DemoSeedStore _store;

  @override
  Future<Result<GamerProfile>> getMyProfile() async {
    return Success<GamerProfile>(_store.myProfile);
  }

  @override
  Future<Result<GamerProfile>> saveMyProfile(GamerProfile profile) async {
    _store.myProfile = profile;
    if (_store.session != null) {
      _store.session = AuthSession(
        userId: _store.session!.userId,
        email: _store.session!.email,
        provider: _store.session!.provider,
        isDemo: _store.session!.isDemo,
        hasCompletedOnboarding: true,
      );
    }
    return Success<GamerProfile>(profile);
  }

  @override
  Future<Result<List<UserGameEntry>>> searchGamesCatalog(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return Success<List<UserGameEntry>>(_store.gamesCatalog);
    }
    final filtered = _store.gamesCatalog
        .where(
          (g) =>
              g.title.toLowerCase().contains(normalized) ||
              g.genres.any((genre) => genre.toLowerCase().contains(normalized)),
        )
        .toList(growable: false);
    return Success<List<UserGameEntry>>(filtered);
  }

  @override
  Future<Result<void>> awardGgBadge({
    required String recipientId,
    required String matchId,
    required GgBadgeCode badge,
  }) async {
    for (var i = 0; i < _store.matches.length; i++) {
      final m = _store.matches[i];
      if (m.peer.id == recipientId && !m.peer.ggBadges.contains(badge)) {
        final updatedPeer = m.peer.copyWith(
          ggBadges: <GgBadgeCode>[...m.peer.ggBadges, badge],
        );
        _store.matches[i] = DuoMatch(
          id: m.id,
          peer: updatedPeer,
          compatibilityScore: m.compatibilityScore,
          commonHoursPerWeek: m.commonHoursPerWeek,
          icebreakerPrompts: m.icebreakerPrompts,
          createdAt: m.createdAt,
          isActive: m.isActive,
          lastMessagePreview: m.lastMessagePreview,
        );
      }
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<Map<String, dynamic>>> exportLgpdJson() async {
    final p = _store.myProfile;
    return Success<Map<String, dynamic>>(<String, dynamic>{
      'exported_at': DateTime.now().toIso8601String(),
      'lgpd_compliance': 'Lei 13.709/2018 — Portabilidade de Dados',
      'profile': <String, dynamic>{
        'id': p.id,
        'username': p.username,
        'display_name': p.displayName,
        'age_years': p.age.years,
        'city_label': p.cityLabel,
        'is_liveness_verified': p.isLivenessVerified,
        'schedule_mask_chunks': p.scheduleMask.chunks,
        'e2ee_public_key_b64': p.e2eePublicKeyB64,
        'games': p.games.map((g) => g.title).toList(),
        'gg_badges': p.ggBadges.map((b) => b.label).toList(),
      },
      'active_matches_count': _store.matches.length,
      'e2ee_note':
          'Mensagens privadas são criptografadas ponta a ponta; chaves privadas permanecem exclusivamente no dispositivo.',
    });
  }

  @override
  Future<Result<void>> deleteMyAccount() async {
    _store.session = null;
    _store.matches.clear();
    _store.messagesByMatch.clear();
    return const Success<void>(null);
  }

  @override
  Future<Result<String>> uploadSanitizedAvatar({
    required Uint8List rawBytes,
    required String fileName,
    int position = 0,
    bool isPrimary = true,
  }) async {
    const sanitizer = AvatarPhotoSanitizer();
    final sanitizedRes = sanitizer.sanitize(rawBytes);
    final sanitized = sanitizedRes.valueOrNull;
    if (sanitized == null) {
      return FailureResult<String>(
        sanitizedRes.failureOrNull ??
            const ValidationFailure('Falha ao sanitizar avatar.'),
      );
    }
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return Success<String>(
      'demo://${_store.myProfile.id}/$cleanName.${sanitized.format.extension}',
    );
  }
}

class DemoSeedDiscoveryRepository implements IDiscoveryRepository {
  DemoSeedDiscoveryRepository(this._store);

  final DemoSeedStore _store;

  @override
  Future<Result<List<DiscoveryCandidate>>> fetchDailyLootDrop({
    required GamerProfile me,
    required IMatchScoringStrategy strategy,
  }) async {
    final candidates = <DiscoveryCandidate>[];
    for (final profile in _store.discoveryPool) {
      if (_store.blockedIds.contains(profile.id) ||
          _store.swipedIds.contains(profile.id)) {
        continue;
      }
      if (me.onlyVerifiedFilter && !profile.isLivenessVerified) {
        continue;
      }
      final breakdown = strategy.calculate(
        me: me,
        target: profile,
        reciprocityProbability: 0.72,
      );
      candidates.add(
        DiscoveryCandidate(profile: profile, breakdown: breakdown),
      );
    }
    candidates.sort(
      (a, b) => b.breakdown.rankScore.compareTo(a.breakdown.rankScore),
    );
    return Success<List<DiscoveryCandidate>>(candidates);
  }

  @override
  Future<Result<DuoMatch?>> submitSwipe({
    required GamerProfile me,
    required DiscoveryCandidate candidate,
    required SwipeAction action,
    String? introNote,
  }) async {
    _store.swipedIds.add(candidate.profile.id);
    if (action == SwipeAction.pass) {
      return const Success<DuoMatch?>(null);
    }

    final existingIdx = _store.matches.indexWhere(
      (m) => m.peer.id == candidate.profile.id,
    );
    if (existingIdx != -1) {
      return Success<DuoMatch?>(_store.matches[existingIdx]);
    }

    final newMatch = DuoMatch(
      id: 'match-${candidate.profile.username}-${DateTime.now().millisecondsSinceEpoch}',
      peer: candidate.profile,
      compatibilityScore: candidate.breakdown.totalScorePercent,
      commonHoursPerWeek: candidate.breakdown.commonHoursPerWeek,
      icebreakerPrompts: CoopIcebreakerGenerator.generate(
        me: me,
        peer: candidate.profile,
        breakdown: candidate.breakdown,
      ),
      createdAt: DateTime.now(),
      lastMessagePreview: introNote,
    );
    _store.matches.insert(0, newMatch);
    return Success<DuoMatch?>(newMatch);
  }

  @override
  Future<Result<List<DuoMatch>>> fetchMatches() async {
    final visible = _store.matches
        .where((m) => m.isActive && !_store.blockedIds.contains(m.peer.id))
        .toList(growable: false);
    return Success<List<DuoMatch>>(visible);
  }

  @override
  Future<Result<void>> blockAndReport({
    required String targetUserId,
    required String reason,
  }) async {
    _store.blockedIds.add(targetUserId);
    _store.matches.removeWhere((m) => m.peer.id == targetUserId);
    return const Success<void>(null);
  }
}

class DemoSeedLobbyRepository implements ILobbyRepository {
  DemoSeedLobbyRepository(this._store);

  final DemoSeedStore _store;

  @override
  Future<Result<List<DuoLobby>>> fetchActiveLobbies({
    String? gameFilter,
    LobbyMode? modeFilter,
  }) async {
    final now = DateTime.now();
    final active = _store.lobbies
        .where((lobby) {
          if (!lobby.isActiveAt(now)) return false;
          if (_store.blockedIds.contains(lobby.hostId)) return false;
          if (gameFilter != null &&
              gameFilter.isNotEmpty &&
              gameFilter != 'Todos' &&
              lobby.gameTitle.toLowerCase() != gameFilter.toLowerCase()) {
            return false;
          }
          if (modeFilter != null && lobby.mode != modeFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    return Success<List<DuoLobby>>(active);
  }

  @override
  Future<Result<DuoLobby>> createLobby({
    required GamerProfile host,
    required String gameTitle,
    required LobbyMode mode,
    required VoicePreference voicePreference,
    required String notes,
  }) async {
    if (gameTitle.trim().isEmpty) {
      return const FailureResult<DuoLobby>(
        ValidationFailure('Escolha um jogo para abrir a lobby Duo Agora.'),
      );
    }
    final created = DuoLobby(
      id: 'lobby-${DateTime.now().millisecondsSinceEpoch}',
      hostId: host.id,
      hostDisplayName: host.displayName,
      hostUsername: host.username,
      hostVerified: host.isLivenessVerified,
      gameTitle: gameTitle.trim(),
      mode: mode,
      voicePreference: voicePreference,
      notes: notes.trim().isEmpty
          ? 'Disponível para jogar agora! Bora squad?'
          : notes.trim(),
      expiresAt: DateTime.now().add(const Duration(hours: 2)),
      compatibilityScore: 100,
      discordHandle: host.discordHandle,
    );
    _store.lobbies.insert(0, created);
    return Success<DuoLobby>(created);
  }
}

class DemoSeedChatRepository implements IChatRepository {
  DemoSeedChatRepository(this._store);

  final DemoSeedStore _store;

  Future<List<ChatMessage>> _ensureSeedMessages(DuoMatch match) async {
    final existing = _store.messagesByMatch[match.id];
    if (existing != null) return existing;

    final list = <ChatMessage>[];
    if (match.id == '550e8400-e29b-41d4-a716-446655440001') {
      final peerCipher = _store.peerCiphers[match.peer.id] ?? _store.myCipher;
      final encrypted1 = await peerCipher.encrypt(
        plaintext:
            'Oi Clara! Vi que você também joga Valorant à noite e curte BG3 🎮💜 Topa um Swiftplay hoje às 21h?',
        peerPublicKeyB64: _store.myProfile.e2eePublicKeyB64,
        matchId: match.id,
        senderId: match.peer.id,
      );
      final decrypted1 = await _store.myCipher.decrypt(
        payload: encrypted1,
        peerPublicKeyB64: match.peer.e2eePublicKeyB64,
        matchId: match.id,
        senderId: match.peer.id,
      );

      final encryptedImg = await peerCipher.encrypt(
        plaintext: 'Print da última partida: 24/11 de Omen na Ascent 🔥',
        peerPublicKeyB64: _store.myProfile.e2eePublicKeyB64,
        matchId: match.id,
        senderId: match.peer.id,
      );
      final decryptedImg = await _store.myCipher.decrypt(
        payload: encryptedImg,
        peerPublicKeyB64: match.peer.e2eePublicKeyB64,
        matchId: match.id,
        senderId: match.peer.id,
      );

      list.addAll(<ChatMessage>[
        ChatMessage(
          id: 'msg-seed-1',
          matchId: match.id,
          senderId: match.peer.id,
          ciphertextB64: encrypted1.ciphertextB64,
          nonceB64: encrypted1.nonceB64,
          plaintext: decrypted1,
          type: ChatMessageType.text,
          createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
          isRead: true,
        ),
        ChatMessage(
          id: 'msg-seed-2',
          matchId: match.id,
          senderId: match.peer.id,
          ciphertextB64: encryptedImg.ciphertextB64,
          nonceB64: encryptedImg.nonceB64,
          plaintext: decryptedImg,
          type: ChatMessageType.imageBlur,
          createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
          isRead: true,
        ),
      ]);
    }

    _store.messagesByMatch[match.id] = list;
    return list;
  }

  @override
  Future<Result<List<ChatMessage>>> fetchMessages(DuoMatch match) async {
    try {
      final messages = await _ensureSeedMessages(match);
      return Success<List<ChatMessage>>(
        List<ChatMessage>.unmodifiable(messages),
      );
    } on AppFailure catch (failure) {
      return FailureResult<List<ChatMessage>>(failure);
    } catch (error) {
      return FailureResult<List<ChatMessage>>(
        CryptoFailure('Erro ao decifrar mensagens E2EE: $error'),
      );
    }
  }

  @override
  Future<Result<ChatMessage>> sendMessage({
    required DuoMatch match,
    required String senderId,
    required String plaintext,
    ChatMessageType type = ChatMessageType.text,
  }) async {
    final trimmed = plaintext.trim();
    if (trimmed.isEmpty) {
      return const FailureResult<ChatMessage>(
        ValidationFailure('Digite uma mensagem antes de enviar.'),
      );
    }

    try {
      final encrypted = await _store.myCipher.encrypt(
        plaintext: trimmed,
        peerPublicKeyB64: match.peer.e2eePublicKeyB64,
        matchId: match.id,
        senderId: senderId,
      );

      // Verify round-trip compatibility with peer cipher in Demo Mode
      final peerCipher = _store.peerCiphers[match.peer.id];
      if (peerCipher != null) {
        await peerCipher.decrypt(
          payload: encrypted,
          peerPublicKeyB64: _store.myProfile.e2eePublicKeyB64,
          matchId: match.id,
          senderId: senderId,
        );
      }

      final message = ChatMessage(
        id: 'msg-${DateTime.now().microsecondsSinceEpoch}',
        matchId: match.id,
        senderId: senderId,
        ciphertextB64: encrypted.ciphertextB64,
        nonceB64: encrypted.nonceB64,
        plaintext: trimmed,
        type: type,
        createdAt: DateTime.now(),
        isRead: false,
      );

      final list = await _ensureSeedMessages(match);
      list.add(message);
      _store
          .controllerForMatch(match.id)
          .add(List<ChatMessage>.unmodifiable(list));

      final matchIdx = _store.matches.indexWhere((m) => m.id == match.id);
      if (matchIdx != -1) {
        _store.matches[matchIdx] = _store.matches[matchIdx].copyWith(
          lastMessagePreview: trimmed,
        );
      }

      return Success<ChatMessage>(message);
    } on AppFailure catch (failure) {
      return FailureResult<ChatMessage>(failure);
    } catch (error) {
      return FailureResult<ChatMessage>(
        CryptoFailure('Erro ao cifrar mensagem E2EE: $error'),
      );
    }
  }

  @override
  Stream<List<ChatMessage>> watchMessages(DuoMatch match) {
    return _store.controllerForMatch(match.id).stream;
  }
}
