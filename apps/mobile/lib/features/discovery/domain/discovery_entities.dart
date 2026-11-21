import '../../profile/domain/gamer_profile.dart';
import 'match_scoring_strategy.dart';

enum SwipeAction { like, pass, superDuo }

class DiscoveryCandidate {
  const DiscoveryCandidate({required this.profile, required this.breakdown});

  final GamerProfile profile;
  final MatchScoreBreakdown breakdown;
}

class DuoMatch {
  const DuoMatch({
    required this.id,
    required this.peer,
    required this.compatibilityScore,
    required this.commonHoursPerWeek,
    required this.icebreakerPrompts,
    required this.createdAt,
    this.isActive = true,
    this.lastMessagePreview,
  });

  final String id;
  final GamerProfile peer;
  final int compatibilityScore;
  final int commonHoursPerWeek;
  final List<String> icebreakerPrompts;
  final DateTime createdAt;
  final bool isActive;
  final String? lastMessagePreview;

  DuoMatch copyWith({bool? isActive, String? lastMessagePreview}) {
    return DuoMatch(
      id: id,
      peer: peer,
      compatibilityScore: compatibilityScore,
      commonHoursPerWeek: commonHoursPerWeek,
      icebreakerPrompts: icebreakerPrompts,
      createdAt: createdAt,
      isActive: isActive ?? this.isActive,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
    );
  }
}

/// Deterministic Zero-Cost Co-op Icebreaker generator eliminating blank chats.
abstract final class CoopIcebreakerGenerator {
  static List<String> generate({
    required GamerProfile me,
    required GamerProfile peer,
    required MatchScoreBreakdown breakdown,
  }) {
    final sharedGame = breakdown.commonGames.isNotEmpty
        ? breakdown.commonGames.first
        : (peer.games.isNotEmpty ? peer.games.first.title : 'Co-op');
    final hours = breakdown.commonHoursPerWeek > 0
        ? breakdown.commonHoursPerWeek
        : 4;

    final secondPrompt = switch (sharedGame.toLowerCase()) {
      final g when g.contains('stardew') =>
        'No Stardew Valley: fazenda perfeitamente organizada ou caos criativo?',
      final g when g.contains('valorant') =>
        'No Valorant: qual mapa você baniria para sempre da rotação?',
      final g when g.contains('league') =>
        'No LoL: duo bot sincronizado ou mid + jungle dominando o mapa?',
      final g when g.contains('counter') || g.contains('cs2') =>
        'No CS2: rush B sem freio ou tático controlado na Mirage?',
      _ =>
        'Em $sharedGame: jogar para relaxar rindo em call ou foco total na vitória?',
    };

    return List<String>.unmodifiable(<String>[
      'Vocês dois jogam $sharedGame e têm ${hours}h/sem livres em comum. Topa uma partida hoje à noite?',
      secondPrompt,
      'Se fossem zerar um co-op de história juntos nesse fim de semana, qual escolheria primeiro?',
    ]);
  }
}
