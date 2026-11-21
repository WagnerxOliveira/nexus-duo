enum ChatMessageType { text, icebreaker, lobbyInvite, imageBlur }

/// Chat message carrying both E2EE wire payload (`ciphertextB64`, `nonceB64`)
/// and the decrypted plaintext rendered strictly on the client.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.ciphertextB64,
    required this.nonceB64,
    required this.plaintext,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.isImageRevealed = false,
  });

  final String id;
  final String matchId;
  final String senderId;
  final String ciphertextB64;
  final String nonceB64;
  final String plaintext;
  final ChatMessageType type;
  final DateTime createdAt;
  final bool isRead;
  final bool isImageRevealed;

  ChatMessage copyWith({bool? isRead, bool? isImageRevealed}) {
    return ChatMessage(
      id: id,
      matchId: matchId,
      senderId: senderId,
      ciphertextB64: ciphertextB64,
      nonceB64: nonceB64,
      plaintext: plaintext,
      type: type,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      isImageRevealed: isImageRevealed ?? this.isImageRevealed,
    );
  }
}
