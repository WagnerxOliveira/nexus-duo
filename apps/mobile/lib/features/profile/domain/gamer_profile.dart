import 'dart:math' as math;

import '../../../core/domain/value_objects/gamer_age.dart';
import '../../../core/domain/value_objects/weekly_schedule_mask.dart';

enum GamerPlatform {
  pc('PC'),
  ps5('PS5'),
  xbox('Xbox'),
  switchConsole('Switch'),
  mobile('Mobile');

  const GamerPlatform(this.label);
  final String label;
}

enum GgBadgeCode {
  greatComms('Boa Comunicação', '🎧'),
  zeroTilt('Zero Tilt / Calmo(a)', '🧘'),
  squadPartner('Parceiro(a) de Squad', '🛡️'),
  greatVibe('Papo Incrível', '✨'),
  respectful('Respeitoso(a)', '🏆');

  const GgBadgeCode(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// Captures a player's behavioral sliders (0..100) and generates a deterministic
/// normalized 128-dimensional embedding compatible with `pgvector` `vector(128)`.
class GamerDna {
  const GamerDna({
    required this.competitiveScore,
    required this.voicePreferenceScore,
    required this.coopFocusScore,
    required this.nightOwlScore,
    required this.archetypeTitle,
  });

  /// 0 = 100% Casual/Cozy, 100 = 100% Competitivo/Tryhard.
  final int competitiveScore;

  /// 0 = Só Chat de Texto, 100 = Call de Voz sempre.
  final int voicePreferenceScore;

  /// 0 = Single-player / Solo, 100 = Co-op / Duo sempre.
  final int coopFocusScore;

  /// 0 = Diurno, 100 = Madrugador / Corujão.
  final int nightOwlScore;

  final String archetypeTitle;

  GamerDna copyWith({
    int? competitiveScore,
    int? voicePreferenceScore,
    int? coopFocusScore,
    int? nightOwlScore,
    String? archetypeTitle,
  }) {
    return GamerDna(
      competitiveScore: competitiveScore ?? this.competitiveScore,
      voicePreferenceScore: voicePreferenceScore ?? this.voicePreferenceScore,
      coopFocusScore: coopFocusScore ?? this.coopFocusScore,
      nightOwlScore: nightOwlScore ?? this.nightOwlScore,
      archetypeTitle: archetypeTitle ?? this.archetypeTitle,
    );
  }

  /// Derives an archetype title from the current slider values.
  static String inferArchetype({
    required int competitiveScore,
    required int voicePreferenceScore,
    required int coopFocusScore,
  }) {
    if (competitiveScore >= 70 && voicePreferenceScore >= 65) {
      return 'Estrategista Tático';
    }
    if (competitiveScore <= 35 && coopFocusScore >= 60) {
      return 'Cozy Explorador';
    }
    if (coopFocusScore >= 75) {
      return 'Dupla Raiz';
    }
    if (voicePreferenceScore >= 70) {
      return 'Vibe de Call & Risada';
    }
    return 'Tático Tranquilo';
  }

  /// Generates a deterministic unit-normalized 128D embedding vector.
  List<double> toEmbedding128({
    List<String> genres = const <String>[],
    List<GamerPlatform> platforms = const <GamerPlatform>[],
  }) {
    final vec = List<double>.filled(128, 0.0);
    // Dims 0..31: genre hashing
    for (final genre in genres) {
      final hash = genre.toLowerCase().codeUnits.fold<int>(
        17,
        (acc, c) => (acc * 31 + c) & 0x7fffffff,
      );
      vec[hash % 32] += 1.0;
    }
    // Dims 32..63: DNA behavioral sliders & platforms
    vec[32] = competitiveScore / 100.0;
    vec[33] = 1.0 - (competitiveScore / 100.0);
    vec[34] = voicePreferenceScore / 100.0;
    vec[35] = 1.0 - (voicePreferenceScore / 100.0);
    vec[36] = coopFocusScore / 100.0;
    vec[37] = nightOwlScore / 100.0;
    for (final platform in platforms) {
      vec[40 + platform.index] = 1.0;
    }
    // Dims 64..127: archetype projection
    final archUnits = archetypeTitle.toLowerCase().codeUnits;
    for (var i = 0; i < archUnits.length; i++) {
      vec[64 + ((archUnits[i] + i * 7) % 64)] += 0.35;
    }

    var normSq = 0.0;
    for (final v in vec) {
      normSq += v * v;
    }
    final norm = math.sqrt(normSq);
    if (norm <= 1e-9) {
      return vec;
    }
    return vec.map((v) => v / norm).toList(growable: false);
  }
}

class UserGameEntry {
  const UserGameEntry({
    required this.gameId,
    required this.title,
    required this.slug,
    required this.genres,
    required this.platforms,
    required this.supportsCrossplay,
    required this.priorityOrder,
    this.rankLabel,
    this.isRankOcrVerified = false,
    this.verifiedGamertag,
    this.hoursPlayed = 0,
    this.preferredMode = 'Co-op',
  });

  final int gameId;
  final String title;
  final String slug;
  final List<String> genres;
  final List<GamerPlatform> platforms;
  final bool supportsCrossplay;
  final int priorityOrder;
  final String? rankLabel;
  final bool isRankOcrVerified;
  final String? verifiedGamertag;
  final int hoursPlayed;
  final String preferredMode;

  UserGameEntry copyWith({
    String? rankLabel,
    bool? isRankOcrVerified,
    String? verifiedGamertag,
    int? hoursPlayed,
    int? priorityOrder,
  }) {
    return UserGameEntry(
      gameId: gameId,
      title: title,
      slug: slug,
      genres: genres,
      platforms: platforms,
      supportsCrossplay: supportsCrossplay,
      priorityOrder: priorityOrder ?? this.priorityOrder,
      rankLabel: rankLabel ?? this.rankLabel,
      isRankOcrVerified: isRankOcrVerified ?? this.isRankOcrVerified,
      verifiedGamertag: verifiedGamertag ?? this.verifiedGamertag,
      hoursPlayed: hoursPlayed ?? this.hoursPlayed,
      preferredMode: preferredMode,
    );
  }
}

class GamerProfile {
  const GamerProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.age,
    required this.gender,
    required this.interestedIn,
    required this.bio,
    required this.promptQuestion,
    required this.promptAnswer,
    required this.cityLabel,
    required this.distanceKmBucket,
    required this.approximateDistanceKm,
    required this.gamerDna,
    required this.scheduleMask,
    required this.games,
    required this.platforms,
    required this.ggBadges,
    required this.isLivenessVerified,
    required this.e2eePublicKeyB64,
    this.discordHandle,
    this.steamId,
    this.dailyImpressions = 0,
    this.isNewbie = false,
    this.avatarGradientHex = const <int>[0xFF8B5CF6, 0xFFEC4899],
    this.onlyVerifiedFilter = false,
    this.receiverFirstMode = false,
  });

  final String id;
  final String username;
  final String displayName;
  final GamerAge age;
  final String gender;
  final List<String> interestedIn;
  final String bio;
  final String promptQuestion;
  final String promptAnswer;
  final String cityLabel;

  /// Privacy-safe distance label (e.g. `~8 km`, `< 5 km`). Never raw lat/lng.
  final String distanceKmBucket;
  final double approximateDistanceKm;
  final GamerDna gamerDna;
  final WeeklyScheduleMask scheduleMask;
  final List<UserGameEntry> games;
  final List<GamerPlatform> platforms;
  final List<GgBadgeCode> ggBadges;
  final bool isLivenessVerified;
  final String e2eePublicKeyB64;
  final String? discordHandle;
  final String? steamId;
  final int dailyImpressions;
  final bool isNewbie;
  final List<int> avatarGradientHex;
  final bool onlyVerifiedFilter;
  final bool receiverFirstMode;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'ND';
    if (parts.length == 1) {
      return parts.first
          .substring(0, math.min(2, parts.first.length))
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  List<String> get allGenres {
    final set = <String>{};
    for (final game in games) {
      set.addAll(game.genres);
    }
    return set.toList(growable: false);
  }

  GamerProfile copyWith({
    String? displayName,
    String? username,
    GamerAge? age,
    String? gender,
    List<String>? interestedIn,
    String? bio,
    String? cityLabel,
    GamerDna? gamerDna,
    WeeklyScheduleMask? scheduleMask,
    List<UserGameEntry>? games,
    List<GamerPlatform>? platforms,
    List<GgBadgeCode>? ggBadges,
    bool? isLivenessVerified,
    String? e2eePublicKeyB64,
    String? discordHandle,
    String? steamId,
    bool? onlyVerifiedFilter,
    bool? receiverFirstMode,
  }) {
    return GamerProfile(
      id: id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      interestedIn: interestedIn ?? this.interestedIn,
      bio: bio ?? this.bio,
      promptQuestion: promptQuestion,
      promptAnswer: promptAnswer,
      cityLabel: cityLabel ?? this.cityLabel,
      distanceKmBucket: distanceKmBucket,
      approximateDistanceKm: approximateDistanceKm,
      gamerDna: gamerDna ?? this.gamerDna,
      scheduleMask: scheduleMask ?? this.scheduleMask,
      games: games ?? this.games,
      platforms: platforms ?? this.platforms,
      ggBadges: ggBadges ?? this.ggBadges,
      isLivenessVerified: isLivenessVerified ?? this.isLivenessVerified,
      e2eePublicKeyB64: e2eePublicKeyB64 ?? this.e2eePublicKeyB64,
      discordHandle: discordHandle ?? this.discordHandle,
      steamId: steamId ?? this.steamId,
      dailyImpressions: dailyImpressions,
      isNewbie: isNewbie,
      avatarGradientHex: avatarGradientHex,
      onlyVerifiedFilter: onlyVerifiedFilter ?? this.onlyVerifiedFilter,
      receiverFirstMode: receiverFirstMode ?? this.receiverFirstMode,
    );
  }
}
