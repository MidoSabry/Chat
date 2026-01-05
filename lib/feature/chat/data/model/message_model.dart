class Message {
  final int id;
  final int eventId;
  final int senderId;
  final int receiverId;
  final String messageText;
  final String timestamp;
  final bool isRead;

  Message({
    required this.id,
    required this.eventId,
    required this.senderId,
    required this.receiverId,
    required this.messageText,
    required this.timestamp,
    required this.isRead,
  });

  static int _toInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static bool _toBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is num) return v.toInt() != 0;
    final s = v.toString().toLowerCase();
    if (s == 'true') return true;
    if (s == 'false') return false;
    return fallback;
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: _toInt(json['Id']),
      eventId: _toInt(json['EventId']),
      senderId: _toInt(json['SenderId']),
      receiverId: _toInt(json['ReceiverId']), // ✅ safe even if null
      messageText: (json['MessageText'] ?? '').toString(),
      timestamp: (json['Timestamp'] ?? DateTime.now().toIso8601String()).toString(),
      isRead: _toBool(json['IsRead']),
    );
  }
}
