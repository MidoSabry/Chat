class Conversation {
  final int userId;
  final String lastMessage;
  final String lastMessageTime;
  final int unreadCount;

  Conversation({
    required this.userId,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
  });

  static int _toInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      userId: _toInt(json['UserId'] ?? json['userId']),
      lastMessage: (json['LastMessage'] ?? json['lastMessage'] ?? '').toString(),
      lastMessageTime: (json['LastMessageTime'] ?? json['lastMessageTime'] ?? '').toString(),
      unreadCount: _toInt(json['UnreadCount'] ?? json['unreadCount']),
    );
  }
}
