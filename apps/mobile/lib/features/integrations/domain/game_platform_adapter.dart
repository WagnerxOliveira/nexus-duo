import '../../../core/errors/app_failure.dart';
import '../../verification/domain/verification_contracts.dart';

class PlatformProfile {
  const PlatformProfile({
    required this.platformName,
    required this.handle,
    required this.displayName,
    this.isVerified = false,
  });

  final String platformName;
  final String handle;
  final String displayName;
  final bool isVerified;
}

class PlatformGameStat {
  const PlatformGameStat({
    required this.title,
    required this.hoursPlayed,
    required this.platformName,
    this.rankLabel,
  });

  final String title;
  final int hoursPlayed;
  final String platformName;
  final String? rankLabel;
}

/// Polymorphic adapter contract isolating external gaming platforms.
abstract interface class IGamePlatformAdapter {
  String get platformName;

  Future<Result<PlatformProfile>> fetchProfile(String handle);

  Future<Result<List<PlatformGameStat>>> fetchTopGames(String handle);
}

class SteamPlatformAdapter implements IGamePlatformAdapter {
  const SteamPlatformAdapter();

  @override
  String get platformName => 'Steam';

  @override
  Future<Result<PlatformProfile>> fetchProfile(String handle) async {
    final clean = handle.trim();
    if (clean.isEmpty) {
      return const FailureResult<PlatformProfile>(
        ValidationFailure('Informe seu Steam ID ou vanity URL.'),
      );
    }
    return Success<PlatformProfile>(
      PlatformProfile(
        platformName: platformName,
        handle: clean,
        displayName: clean,
        isVerified: true,
      ),
    );
  }

  @override
  Future<Result<List<PlatformGameStat>>> fetchTopGames(String handle) async {
    if (handle.trim().isEmpty) {
      return const FailureResult<List<PlatformGameStat>>(
        ValidationFailure('Steam ID obrigatório para sincronizar jogos.'),
      );
    }
    return const Success<List<PlatformGameStat>>(<PlatformGameStat>[
      PlatformGameStat(
        title: 'Counter-Strike 2',
        hoursPlayed: 640,
        platformName: 'Steam',
        rankLabel: '18.450 Premier',
      ),
      PlatformGameStat(
        title: 'Baldur\'s Gate 3',
        hoursPlayed: 215,
        platformName: 'Steam',
      ),
      PlatformGameStat(
        title: 'Stardew Valley',
        hoursPlayed: 180,
        platformName: 'Steam',
      ),
    ]);
  }
}

class DiscordPlatformAdapter implements IGamePlatformAdapter {
  const DiscordPlatformAdapter();

  @override
  String get platformName => 'Discord';

  @override
  Future<Result<PlatformProfile>> fetchProfile(String handle) async {
    final clean = handle.trim();
    if (clean.length < 2) {
      return const FailureResult<PlatformProfile>(
        ValidationFailure('Handle do Discord inválido.'),
      );
    }
    return Success<PlatformProfile>(
      PlatformProfile(
        platformName: platformName,
        handle: clean,
        displayName: clean.replaceFirst('@', ''),
        isVerified: true,
      ),
    );
  }

  @override
  Future<Result<List<PlatformGameStat>>> fetchTopGames(String handle) async {
    return const Success<List<PlatformGameStat>>(<PlatformGameStat>[
      PlatformGameStat(
        title: 'Valorant',
        hoursPlayed: 410,
        platformName: 'Discord Rich Presence',
      ),
      PlatformGameStat(
        title: 'League of Legends',
        hoursPlayed: 320,
        platformName: 'Discord Rich Presence',
      ),
    ]);
  }
}

/// Adapts raw OCR text extracted from a screenshot into [PlatformGameStat].
class OcrScreenshotAdapter implements IGamePlatformAdapter {
  const OcrScreenshotAdapter({RankOcrParserChain? parserChain})
    : _parserChain = parserChain ?? const RankOcrParserChain();

  final RankOcrParserChain _parserChain;

  @override
  String get platformName => 'OCR Screenshot';

  @override
  Future<Result<PlatformProfile>> fetchProfile(String rawOcrText) async {
    final parsed = _parserChain.parse(rawOcrText);
    if (parsed == null) {
      return const FailureResult<PlatformProfile>(
        ValidationFailure(
          'Não foi possível reconhecer rank/gamertag no print enviado.',
          code: 'OCR_NO_MATCH',
        ),
      );
    }
    return Success<PlatformProfile>(
      PlatformProfile(
        platformName: platformName,
        handle: parsed.gamertag,
        displayName: parsed.gamertag,
        isVerified: true,
      ),
    );
  }

  @override
  Future<Result<List<PlatformGameStat>>> fetchTopGames(
    String rawOcrText,
  ) async {
    final parsed = _parserChain.parse(rawOcrText);
    if (parsed == null) {
      return const FailureResult<List<PlatformGameStat>>(
        ValidationFailure('Nenhum jogo reconhecido via OCR.'),
      );
    }
    return Success<List<PlatformGameStat>>(<PlatformGameStat>[
      PlatformGameStat(
        title: parsed.gameTitle,
        hoursPlayed: 100,
        platformName: platformName,
        rankLabel: parsed.rankLabel,
      ),
    ]);
  }
}

/// Polymorphically aggregates game stats from all connected platform adapters.
class SyncUserGamesUseCase {
  const SyncUserGamesUseCase(this.adapters);

  final List<IGamePlatformAdapter> adapters;

  Future<List<PlatformGameStat>> execute(
    Map<String, String> handlesByPlatform,
  ) async {
    final aggregated = <PlatformGameStat>[];
    for (final adapter in adapters) {
      final handle = handlesByPlatform[adapter.platformName];
      if (handle == null || handle.trim().isEmpty) continue;
      final res = await adapter.fetchTopGames(handle);
      res.fold(onSuccess: aggregated.addAll, onFailure: (_) {});
    }
    return List<PlatformGameStat>.unmodifiable(aggregated);
  }
}
