// Hanagram — mesajlaşma modelleri
//
// MessageThread: sohbet listesi satırı
// ChatMessage: tek bir mesaj

/// Sohbet listesi satırı.
class MessageThread {
  const MessageThread({
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar = '',
    this.lastMessage = '',
    required this.lastAt,
    this.unreadCount = 0,
  });

  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserAvatar;
  final String lastMessage;
  final DateTime lastAt;
  final int unreadCount;

  factory MessageThread.fromJson(Map<String, dynamic> j) => MessageThread(
        conversationId: j['conversation_id'] as String? ?? '',
        otherUserId: j['other_user_id'] as String? ?? '',
        otherUserName: j['other_user_name'] as String? ?? '',
        otherUserAvatar: j['other_user_avatar'] as String? ?? '',
        lastMessage: j['last_message'] as String? ?? '',
        lastAt: DateTime.tryParse(j['last_at'] as String? ?? '') ??
            DateTime.now(),
        unreadCount: j['unread_count'] as int? ?? 0,
      );
}

/// Tek bir mesaj.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.content,
    this.type = 'text',
    required this.createdAt,
    required this.isMe,
  });

  final String id;
  final String senderId;
  final String content;
  final String type;
  final DateTime createdAt;
  final bool isMe;

  factory ChatMessage.fromJson(Map<String, dynamic> j,
          {required String currentUserId}) =>
      ChatMessage(
        id: j['id'] as String? ?? '',
        senderId: j['sender_id'] as String? ?? '',
        content: j['content'] as String? ?? '',
        type: j['type'] as String? ?? 'text',
        createdAt:
            DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
        isMe: j['sender_id'] == currentUserId,
      );
}
