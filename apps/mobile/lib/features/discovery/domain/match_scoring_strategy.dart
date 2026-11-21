import 'dart:math' as math;

import '../../profile/domain/gamer_profile.dart';

/// Explainable breakdown of a compatibility score shown transparently on cards.
class MatchScoreBreakdown {
  const MatchScoreBreakdown({
    required this.totalScorePercent,
    required this.rawTotalScore,
    required this.rankScore,
    required this.gamesScore,
    required this.scheduleScore,
    required this.dnaScore,
    required this.proximityScore,
    required this.commonGames,
    required this.commonHoursPerWeek,
    required this.longestContinuousWindowHours,
    required this.strategyName,
  });

  /// Rounded percentage `0..100` displayed inside the Match Score Ring.
  final int totalScorePercent;

  /// Raw multi-objective affinity `S_total` in `[0.0, 1.0]`.
  final double rawTotalScore;

  /// Exposure-fair ranking score after Reciprocity, DailyImpressions Decay, and Boost.
  final double rankScore;

  final double gamesScore;
  final double scheduleScore;
  final double dnaScore;
  final double proximityScore;
  final List<String> commonGames;
  final int commonHoursPerWeek;
  final int longestContinuousWindowHours;
  final String strategyName;
}

/// Polymorphic Strategy Pattern for computing gamer compatibility.
abstract interface class IMatchScoringStrategy {
  String get name;

  MatchScoreBreakdown calculate({
    required GamerProfile me,
    required GamerProfile target,
    double reciprocityProbability = 0.5,
  });
}

/// Shared math utilities for DCG game affinity, Weighted LCS DP on genres,
/// cosine DNA similarity, and exposure fairness decay.
abstract final class _ScoringMath {
  static double dcgWeight(int zeroBasedIndex) {
    return 1.0 / (math.log(zeroBasedIndex + 2) / math.ln2);
  }

  static double cosineSimilarity(List<double> a, List<double> b) {
    final len = math.min(a.length, b.length);
    if (len == 0) return 0.0;
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < len; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA <= 1e-9 || normB <= 1e-9) return 0.0;
    return (dot / (math.sqrt(normA) * math.sqrt(normB))).clamp(-1.0, 1.0);
  }

  /// Computes weighted priority game overlap using DCG (`1 / log2(i + 2)`)
  /// combined with Weighted LCS DP on ordered genres (`O(|G1| * |G2|)`).
  static ({double score, List<String> commonGames}) computeGamesAffinity(
    GamerProfile me,
    GamerProfile target,
  ) {
    if (me.games.isEmpty || target.games.isEmpty) {
      return (score: 0.0, commonGames: const <String>[]);
    }

    final mySorted = List<UserGameEntry>.from(me.games)
      ..sort((a, b) => a.priorityOrder.compareTo(b.priorityOrder));
    final targetSorted = List<UserGameEntry>.from(target.games)
      ..sort((a, b) => a.priorityOrder.compareTo(b.priorityOrder));

    final targetIndexBySlug = <String, int>{};
    for (var i = 0; i < targetSorted.length; i++) {
      targetIndexBySlug[targetSorted[i].slug] = i;
    }

    var matchedWeight = 0.0;
    var maxPossibleWeight = 0.0;
    final commonGames = <String>[];

    for (var i = 0; i < mySorted.length; i++) {
      final wI = dcgWeight(i);
      maxPossibleWeight += wI;
      final myGame = mySorted[i];
      final targetIdx = targetIndexBySlug[myGame.slug];
      if (targetIdx != null) {
        commonGames.add(myGame.title);
        final targetGame = targetSorted[targetIdx];
        final wJ = dcgWeight(targetIdx);
        var bonus = 1.0;
        final sharesPlatform =
            myGame.supportsCrossplay ||
            myGame.platforms.any(targetGame.platforms.contains);
        if (sharesPlatform) bonus += 0.12;
        if (myGame.preferredMode == targetGame.preferredMode) bonus += 0.08;
        matchedWeight += math.sqrt(wI * wJ) * bonus;
      }
    }

    final exactScore = maxPossibleWeight > 0
        ? (matchedWeight / maxPossibleWeight).clamp(0.0, 1.0)
        : 0.0;

    // Weighted LCS DP over ordered genres of top games (O(|A| * |B|))
    final myGenres = mySorted.expand((g) => g.genres).take(10).toList();
    final targetGenres = targetSorted.expand((g) => g.genres).take(10).toList();
    final genreLcsScore = _weightedGenreLcs(myGenres, targetGenres);

    final combined = (0.75 * exactScore + 0.25 * genreLcsScore).clamp(0.0, 1.0);
    return (
      score: combined,
      commonGames: List<String>.unmodifiable(commonGames),
    );
  }

  static double _weightedGenreLcs(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final rows = a.length;
    final cols = b.length;
    final dp = List<List<double>>.generate(
      rows + 1,
      (_) => List<double>.filled(cols + 1, 0.0),
    );

    for (var i = 1; i <= rows; i++) {
      for (var j = 1; j <= cols; j++) {
        if (a[i - 1].toLowerCase() == b[j - 1].toLowerCase()) {
          final weight = dcgWeight(math.min(i - 1, j - 1));
          dp[i][j] = dp[i - 1][j - 1] + weight;
        } else {
          dp[i][j] = math.max(dp[i - 1][j], dp[i][j - 1]);
        }
      }
    }

    var denom = 0.0;
    final limit = math.min(rows, cols);
    for (var i = 0; i < limit; i++) {
      denom += dcgWeight(i);
    }
    if (denom <= 0) return 0.0;
    return (dp[rows][cols] / denom).clamp(0.0, 1.0);
  }

  static double proximityScore(double distanceKm) {
    if (distanceKm <= 5) return 1.0;
    if (distanceKm >= 120) return 0.1;
    return (1.0 - ((distanceKm - 5) / 115.0) * 0.9).clamp(0.1, 1.0);
  }

  static double applyFairnessRankScore({
    required double totalScore,
    required double reciprocityProbability,
    required GamerProfile target,
    double alpha = 0.25,
    double beta = 0.04,
  }) {
    final reciprocityFactor =
        1.0 + alpha * reciprocityProbability.clamp(0.0, 1.0);
    final exposureDecay =
        1.0 / (1.0 + beta * math.max(0, target.dailyImpressions));
    final ethicalBoost =
        1.0 +
        (target.isNewbie ? 0.08 : 0.0) +
        (target.isLivenessVerified ? 0.07 : 0.0);
    return totalScore * reciprocityFactor * exposureDecay * ethicalBoost;
  }
}

/// Primary strategy for the "Daily Loot Drop" discovery deck:
/// `S_total = 0.35 * S_jogos + 0.25 * S_agenda + 0.25 * S_dna + 0.15 * S_proximidade`
class HybridGamerScoringStrategy implements IMatchScoringStrategy {
  const HybridGamerScoringStrategy();

  @override
  String get name => 'HybridGamerScoringStrategy';

  @override
  MatchScoreBreakdown calculate({
    required GamerProfile me,
    required GamerProfile target,
    double reciprocityProbability = 0.5,
  }) {
    final gamesAffinity = _ScoringMath.computeGamesAffinity(me, target);
    final scheduleAnalysis = me.scheduleMask.analyzeContinuousWindows(
      target.scheduleMask,
    );
    final myVec = me.gamerDna.toEmbedding128(
      genres: me.allGenres,
      platforms: me.platforms,
    );
    final targetVec = target.gamerDna.toEmbedding128(
      genres: target.allGenres,
      platforms: target.platforms,
    );
    final dnaScore =
        ((1.0 + _ScoringMath.cosineSimilarity(myVec, targetVec)) / 2.0).clamp(
          0.0,
          1.0,
        );
    final proxScore = _ScoringMath.proximityScore(target.approximateDistanceKm);

    final total =
        (0.35 * gamesAffinity.score +
                0.25 * scheduleAnalysis.score +
                0.25 * dnaScore +
                0.15 * proxScore)
            .clamp(0.0, 1.0);

    final rankScore = _ScoringMath.applyFairnessRankScore(
      totalScore: total,
      reciprocityProbability: reciprocityProbability,
      target: target,
    );

    return MatchScoreBreakdown(
      totalScorePercent: (total * 100).round().clamp(0, 100),
      rawTotalScore: total,
      rankScore: rankScore,
      gamesScore: gamesAffinity.score,
      scheduleScore: scheduleAnalysis.score,
      dnaScore: dnaScore,
      proximityScore: proxScore,
      commonGames: gamesAffinity.commonGames,
      commonHoursPerWeek: scheduleAnalysis.totalCommonHours,
      longestContinuousWindowHours: scheduleAnalysis.longestContinuousBlock,
      strategyName: name,
    );
  }
}

/// Strategy specialized for the ephemeral "Duo Agora" Lobby:
/// prioritizes shared games (`0.45`) and immediate continuous play windows (`0.35`)
/// while reducing geographic proximity weight (`0.05`).
class CoopDuoScoringStrategy implements IMatchScoringStrategy {
  const CoopDuoScoringStrategy();

  @override
  String get name => 'CoopDuoScoringStrategy';

  @override
  MatchScoreBreakdown calculate({
    required GamerProfile me,
    required GamerProfile target,
    double reciprocityProbability = 0.5,
  }) {
    final gamesAffinity = _ScoringMath.computeGamesAffinity(me, target);
    final scheduleAnalysis = me.scheduleMask.analyzeContinuousWindows(
      target.scheduleMask,
    );
    final myVec = me.gamerDna.toEmbedding128(
      genres: me.allGenres,
      platforms: me.platforms,
    );
    final targetVec = target.gamerDna.toEmbedding128(
      genres: target.allGenres,
      platforms: target.platforms,
    );
    final dnaScore =
        ((1.0 + _ScoringMath.cosineSimilarity(myVec, targetVec)) / 2.0).clamp(
          0.0,
          1.0,
        );
    final proxScore = _ScoringMath.proximityScore(target.approximateDistanceKm);

    final total =
        (0.45 * gamesAffinity.score +
                0.35 * scheduleAnalysis.score +
                0.15 * dnaScore +
                0.05 * proxScore)
            .clamp(0.0, 1.0);

    final rankScore = _ScoringMath.applyFairnessRankScore(
      totalScore: total,
      reciprocityProbability: reciprocityProbability,
      target: target,
    );

    return MatchScoreBreakdown(
      totalScorePercent: (total * 100).round().clamp(0, 100),
      rawTotalScore: total,
      rankScore: rankScore,
      gamesScore: gamesAffinity.score,
      scheduleScore: scheduleAnalysis.score,
      dnaScore: dnaScore,
      proximityScore: proxScore,
      commonGames: gamesAffinity.commonGames,
      commonHoursPerWeek: scheduleAnalysis.totalCommonHours,
      longestContinuousWindowHours: scheduleAnalysis.longestContinuousBlock,
      strategyName: name,
    );
  }
}
