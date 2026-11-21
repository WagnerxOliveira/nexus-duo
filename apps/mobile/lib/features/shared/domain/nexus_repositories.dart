import 'dart:typed_data';

import '../../../core/errors/app_failure.dart';
import '../../chat/domain/chat_message.dart';
import '../../discovery/domain/discovery_entities.dart';
import '../../discovery/domain/match_scoring_strategy.dart';
import '../../lobby/domain/duo_lobby.dart';
import '../../profile/domain/gamer_profile.dart';

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.email,
    required this.provider,
    required this.isDemo,
    required this.hasCompletedOnboarding,
  });

  final String userId;
  final String email;
  final String provider;
  final bool isDemo;
  final bool hasCompletedOnboarding;
}

abstract interface class IAuthRepository {
  Future<AuthSession?> currentSession();
  Future<Result<AuthSession>> signInWithDiscord();
  Future<Result<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  });
  Future<Result<AuthSession>> signUpWithEmail({
    required String email,
    required String password,
  });
  Future<Result<AuthSession>> enterDemoMode();
  Future<void> signOut();
}

abstract interface class IProfileRepository {
  Future<Result<GamerProfile>> getMyProfile();
  Future<Result<GamerProfile>> saveMyProfile(GamerProfile profile);
  Future<Result<List<UserGameEntry>>> searchGamesCatalog(String query);
  Future<Result<void>> awardGgBadge({
    required String recipientId,
    required String matchId,
    required GgBadgeCode badge,
  });
  Future<Result<Map<String, dynamic>>> exportLgpdJson();
  Future<Result<void>> deleteMyAccount();
  Future<Result<String>> uploadSanitizedAvatar({
    required Uint8List rawBytes,
    required String fileName,
    int position = 0,
    bool isPrimary = true,
  });
}

abstract interface class IDiscoveryRepository {
  Future<Result<List<DiscoveryCandidate>>> fetchDailyLootDrop({
    required GamerProfile me,
    required IMatchScoringStrategy strategy,
  });

  Future<Result<DuoMatch?>> submitSwipe({
    required GamerProfile me,
    required DiscoveryCandidate candidate,
    required SwipeAction action,
    String? introNote,
  });

  Future<Result<List<DuoMatch>>> fetchMatches();

  Future<Result<void>> blockAndReport({
    required String targetUserId,
    required String reason,
  });
}

abstract interface class ILobbyRepository {
  Future<Result<List<DuoLobby>>> fetchActiveLobbies({
    String? gameFilter,
    LobbyMode? modeFilter,
  });

  Future<Result<DuoLobby>> createLobby({
    required GamerProfile host,
    required String gameTitle,
    required LobbyMode mode,
    required VoicePreference voicePreference,
    required String notes,
  });
}

abstract interface class IChatRepository {
  Future<Result<List<ChatMessage>>> fetchMessages(DuoMatch match);

  Future<Result<ChatMessage>> sendMessage({
    required DuoMatch match,
    required String senderId,
    required String plaintext,
    ChatMessageType type = ChatMessageType.text,
  });

  Stream<List<ChatMessage>> watchMessages(DuoMatch match);
}
