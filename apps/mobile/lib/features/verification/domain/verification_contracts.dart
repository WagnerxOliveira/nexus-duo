import '../../../core/errors/app_failure.dart';

/// Result produced by any polymorphic [IVerificationProvider].
class VerificationProof {
  const VerificationProof({
    required this.providerName,
    required this.isVerified,
    required this.verifiedAt,
    required this.summary,
    this.extractedGame,
    this.extractedGamertag,
    this.extractedRank,
    this.confidence = 1.0,
  });

  final String providerName;
  final bool isVerified;
  final DateTime verifiedAt;
  final String summary;
  final String? extractedGame;
  final String? extractedGamertag;
  final String? extractedRank;
  final double confidence;
}

/// Polymorphic contract for on-device identity and rank verifiers.
abstract interface class IVerificationProvider {
  String get providerName;

  Future<Result<VerificationProof>> verify();
}

/// Three anti-catfish liveness challenges evaluated strictly on-device.
enum LivenessChallengeType {
  blinkBothEyes('Pisque os dois olhos'),
  turnHead('Vire levemente o rosto'),
  naturalSmile('Dê um sorriso natural');

  const LivenessChallengeType(this.instruction);
  final String instruction;
}

/// Lightweight telemetry extracted from a single camera frame (ML Kit Face).
class FaceMetricsFrame {
  const FaceMetricsFrame({
    required this.faceCount,
    required this.trackingId,
    required this.leftEyeOpenProbability,
    required this.rightEyeOpenProbability,
    required this.headEulerAngleY,
    required this.smilingProbability,
    this.luminanceOk = true,
  });

  final int faceCount;
  final int? trackingId;
  final double leftEyeOpenProbability;
  final double rightEyeOpenProbability;
  final double headEulerAngleY;
  final double smilingProbability;
  final bool luminanceOk;
}

/// Deterministic 3-step liveness state machine rejecting static photos & cuts.
class LivenessStateMachine {
  LivenessStateMachine({List<LivenessChallengeType>? challenges})
    : challenges = List<LivenessChallengeType>.unmodifiable(
        challenges ?? LivenessChallengeType.values,
      );

  final List<LivenessChallengeType> challenges;
  int _currentIndex = 0;
  int? _lockedTrackingId;
  bool _sawEyesClosed = false;

  int get completedCount => _currentIndex;
  bool get isCompleted => _currentIndex >= challenges.length;

  LivenessChallengeType? get currentChallenge =>
      isCompleted ? null : challenges[_currentIndex];

  void reset() {
    _currentIndex = 0;
    _lockedTrackingId = null;
    _sawEyesClosed = false;
  }

  /// Feeds a single camera frame and returns status feedback.
  String processFrame(FaceMetricsFrame frame) {
    if (isCompleted) return 'Verificação concluída!';
    if (!frame.luminanceOk) {
      return 'Ambiente escuro: melhore a iluminação.';
    }
    if (frame.faceCount != 1) {
      reset();
      return 'Centralize exatamente 1 rosto na câmera.';
    }
    if (frame.trackingId != null) {
      if (_lockedTrackingId == null) {
        _lockedTrackingId = frame.trackingId;
      } else if (_lockedTrackingId != frame.trackingId) {
        reset();
        return 'Rosto perdido: mantenha o enquadramento contínuo.';
      }
    }

    final challenge = challenges[_currentIndex];
    switch (challenge) {
      case LivenessChallengeType.blinkBothEyes:
        if (frame.leftEyeOpenProbability < 0.25 &&
            frame.rightEyeOpenProbability < 0.25) {
          _sawEyesClosed = true;
          return 'Olhos fechados detectados — agora abra os olhos.';
        }
        if (_sawEyesClosed &&
            frame.leftEyeOpenProbability > 0.75 &&
            frame.rightEyeOpenProbability > 0.75) {
          _sawEyesClosed = false;
          _currentIndex += 1;
          return 'Piscada confirmada!';
        }
        return challenge.instruction;
      case LivenessChallengeType.turnHead:
        if (frame.headEulerAngleY.abs() >= 18.0) {
          _currentIndex += 1;
          return 'Movimento lateral confirmado!';
        }
        return challenge.instruction;
      case LivenessChallengeType.naturalSmile:
        if (frame.smilingProbability >= 0.72) {
          _currentIndex += 1;
          return 'Sorriso confirmado! Selo Player Verificado liberado.';
        }
        return challenge.instruction;
    }
  }
}

/// Structured output extracted from a game profile screenshot via OCR.
class ParsedRankResult {
  const ParsedRankResult({
    required this.gameTitle,
    required this.gamertag,
    required this.rankLabel,
    required this.confidence,
    required this.parserName,
  });

  final String gameTitle;
  final String gamertag;
  final String rankLabel;
  final double confidence;
  final String parserName;
}

/// Polymorphic parser contract for game rank screenshot OCR extraction.
abstract interface class IRankOcrParser {
  String get parserName;

  ParsedRankResult? parse(String rawOcrText);
}

class ValorantOcrParser implements IRankOcrParser {
  const ValorantOcrParser();

  static final RegExp _keywordRegex = RegExp(
    r'\b(valorant|vct|act\s+rank|ato|radiant|radiante|ascendant|ascendente|immortal|imortal|swiftplay)\b',
    caseSensitive: false,
  );

  static final RegExp _riotIdRegex = RegExp(
    r'([A-Za-z0-9_.\-]{3,16}\s*#\s*[A-Za-z0-9]{2,6})',
  );

  static final RegExp _rankRegex = RegExp(
    r'\b(radiante|radiant|(?:imortal|immortal|ascendente|ascendant|diamante|diamond|platina|platinum|ouro|gold|prata|silver|bronze|ferro|iron)\s*(?:[123]|I{1,3})?)\b',
    caseSensitive: false,
  );

  @override
  String get parserName => 'ValorantOcrParser';

  @override
  ParsedRankResult? parse(String rawOcrText) {
    if (!_keywordRegex.hasMatch(rawOcrText)) {
      return null;
    }
    final rankMatch = _rankRegex.firstMatch(rawOcrText);
    if (rankMatch == null) {
      return null;
    }
    final riotMatch = _riotIdRegex.firstMatch(rawOcrText);
    final gamertag =
        riotMatch?.group(1)?.replaceAll(RegExp(r'\s+'), '') ?? 'Player#BR1';
    return ParsedRankResult(
      gameTitle: 'Valorant',
      gamertag: gamertag,
      rankLabel: _normalizeRank(rankMatch.group(1)!),
      confidence: riotMatch != null ? 0.94 : 0.82,
      parserName: parserName,
    );
  }
}

class LolOcrParser implements IRankOcrParser {
  const LolOcrParser();

  static final RegExp _keywordRegex = RegExp(
    r'\b(league\s+of\s+legends|lol|solo\s*/\s*duo|flex|pdl|lp|esmeralda|emerald|desafiante|challenger|gr[aã]o[\s-]?mestre|grandmaster|summoner)\b',
    caseSensitive: false,
  );

  static final RegExp _riotIdRegex = RegExp(
    r'([A-Za-z0-9_.\-]{3,16}\s*#\s*[A-Za-z0-9]{2,6})',
  );

  static final RegExp _rankRegex = RegExp(
    r'\b(desafiante|challenger|gr[aã]o[\s-]?mestre|grandmaster|mestre|master|(?:diamante|diamond|esmeralda|emerald|platina|platinum|ouro|gold|prata|silver|bronze|ferro|iron)\s*(?:[1-4]|IV|I{1,3})?)\b',
    caseSensitive: false,
  );

  @override
  String get parserName => 'LolOcrParser';

  @override
  ParsedRankResult? parse(String rawOcrText) {
    if (!_keywordRegex.hasMatch(rawOcrText)) {
      return null;
    }
    final rankMatch = _rankRegex.firstMatch(rawOcrText);
    if (rankMatch == null) {
      return null;
    }
    final riotMatch = _riotIdRegex.firstMatch(rawOcrText);
    final gamertag =
        riotMatch?.group(1)?.replaceAll(RegExp(r'\s+'), '') ?? 'Summoner#BR1';
    return ParsedRankResult(
      gameTitle: 'League of Legends',
      gamertag: gamertag,
      rankLabel: _normalizeRank(rankMatch.group(1)!),
      confidence: riotMatch != null ? 0.93 : 0.80,
      parserName: parserName,
    );
  }
}

class Cs2OcrParser implements IRankOcrParser {
  const Cs2OcrParser();

  static final RegExp _keywordRegex = RegExp(
    r'\b(counter[\s-]?strike|cs2|cs:go|premier|cs\s*rating|faceit|global\s+elite|aguia|águia)\b',
    caseSensitive: false,
  );

  static final RegExp _premierRatingRegex = RegExp(r'\b(\d{1,2}[.,]\d{3})\b');

  static final RegExp _legacyRankRegex = RegExp(
    r'\b(global\s+elite|supreme|supremo|legendary\s+eagle|águia\s+lendária|aguia\s+lendaria|master\s+guardian|xerife|faceit\s*(?:lvl|level|nível)?\s*\d{1,2})\b',
    caseSensitive: false,
  );

  static final RegExp _handleRegex = RegExp(
    r'(?:player|nick|steam|perfil)\s*[:\-]\s*([A-Za-z0-9_.\-]{3,20})',
    caseSensitive: false,
  );

  @override
  String get parserName => 'Cs2OcrParser';

  @override
  ParsedRankResult? parse(String rawOcrText) {
    if (!_keywordRegex.hasMatch(rawOcrText)) {
      return null;
    }
    final ratingMatch = _premierRatingRegex.firstMatch(rawOcrText);
    final legacyMatch = _legacyRankRegex.firstMatch(rawOcrText);
    if (ratingMatch == null && legacyMatch == null) {
      return null;
    }
    final rankLabel = ratingMatch != null
        ? '${ratingMatch.group(1)} Premier'
        : _normalizeRank(legacyMatch!.group(1)!);
    final handle = _handleRegex.firstMatch(rawOcrText)?.group(1) ?? 'CS2Player';
    return ParsedRankResult(
      gameTitle: 'Counter-Strike 2',
      gamertag: handle,
      rankLabel: rankLabel,
      confidence: 0.91,
      parserName: parserName,
    );
  }
}

class GenericGamerOcrParser implements IRankOcrParser {
  const GenericGamerOcrParser();

  static final RegExp _genshinRegex = RegExp(
    r'\b(?:genshin|adventure\s+rank|ar)\s*[:#]?\s*(\d{2})\b',
    caseSensitive: false,
  );

  static final RegExp _genericRankRegex = RegExp(
    r'\b(grand\s*champion|champion\s*[1-3I]+|master|diamond|diamante|platinum|platina|gold|ouro|level\s*\d+|nível\s*\d+|lvl\s*\d+)\b',
    caseSensitive: false,
  );

  static final RegExp _psnXboxRegex = RegExp(
    r'(?:psn|xbox|gamertag|id|nick)\s*[:\-]\s*([A-Za-z0-9_.\-#]{3,24})',
    caseSensitive: false,
  );

  @override
  String get parserName => 'GenericGamerOcrParser';

  @override
  ParsedRankResult? parse(String rawOcrText) {
    final genshinMatch = _genshinRegex.firstMatch(rawOcrText);
    final tagMatch = _psnXboxRegex.firstMatch(rawOcrText);
    if (genshinMatch != null) {
      return ParsedRankResult(
        gameTitle: 'Genshin Impact',
        gamertag: tagMatch?.group(1) ?? 'Traveler',
        rankLabel: 'AR ${genshinMatch.group(1)}',
        confidence: 0.85,
        parserName: parserName,
      );
    }

    final rankMatch = _genericRankRegex.firstMatch(rawOcrText);
    if (rankMatch == null && tagMatch == null) {
      return null;
    }
    return ParsedRankResult(
      gameTitle: _inferGenericGame(rawOcrText),
      gamertag: tagMatch?.group(1) ?? 'GamerVerificado',
      rankLabel: rankMatch != null
          ? _normalizeRank(rankMatch.group(1)!)
          : 'Perfil Verificado',
      confidence: 0.74,
      parserName: parserName,
    );
  }

  String _inferGenericGame(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('rocket league')) return 'Rocket League';
    if (lower.contains('overwatch')) return 'Overwatch 2';
    if (lower.contains('stardew')) return 'Stardew Valley';
    if (lower.contains('playstation') || lower.contains('psn')) {
      return 'PlayStation Network';
    }
    if (lower.contains('xbox')) return 'Xbox Live';
    return 'Perfil Gamer';
  }
}

/// Polymorphic orchestrator iterating specialized parsers before generic fallback.
class RankOcrParserChain {
  const RankOcrParserChain({
    this.parsers = const <IRankOcrParser>[
      ValorantOcrParser(),
      LolOcrParser(),
      Cs2OcrParser(),
      GenericGamerOcrParser(),
    ],
  });

  final List<IRankOcrParser> parsers;

  ParsedRankResult? parse(String rawOcrText) {
    if (rawOcrText.trim().isEmpty) return null;
    for (final parser in parsers) {
      final result = parser.parse(rawOcrText);
      if (result != null) {
        return result;
      }
    }
    return null;
  }
}

String _normalizeRank(String raw) {
  final words = raw.trim().split(RegExp(r'\s+'));
  return words
      .map((w) {
        final upper = w.toUpperCase();
        if (upper == 'I' || upper == 'II' || upper == 'III' || upper == 'IV') {
          return upper;
        }
        if (w.isEmpty) return w;
        return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
      })
      .join(' ');
}
