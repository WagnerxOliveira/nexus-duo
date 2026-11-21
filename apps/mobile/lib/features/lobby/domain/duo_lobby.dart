enum LobbyMode {
  casual('Casual'),
  ranked('Ranked'),
  coop('Co-op'),
  chill('Chill');

  const LobbyMode(this.label);
  final String label;
}

enum VoicePreference {
  discord('Discord Call'),
  inGame('Voz no Jogo'),
  textOnly('Só Chat');

  const VoicePreference(this.label);
  final String label;
}

/// Ephemeral 2-hour "Duo Agora" Lobby entry.
class DuoLobby {
  const DuoLobby({
    required this.id,
    required this.hostId,
    required this.hostDisplayName,
    required this.hostUsername,
    required this.hostVerified,
    required this.gameTitle,
    required this.mode,
    required this.voicePreference,
    required this.notes,
    required this.expiresAt,
    required this.compatibilityScore,
    this.discordHandle,
  });

  final String id;
  final String hostId;
  final String hostDisplayName;
  final String hostUsername;
  final bool hostVerified;
  final String gameTitle;
  final LobbyMode mode;
  final VoicePreference voicePreference;
  final String notes;
  final DateTime expiresAt;
  final int compatibilityScore;
  final String? discordHandle;

  Duration remainingAt(DateTime now) {
    final diff = expiresAt.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  bool isActiveAt(DateTime now) => expiresAt.isAfter(now);
}
