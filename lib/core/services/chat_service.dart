import 'dart:async';
import 'dart:nativewrappers/_internal/vm/lib/ffi_allocation_patch.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';
import '../../feature/chat/data/model/conversation_model.dart';
import '../../feature/chat/data/model/message_model.dart';
import '../network/api_client.dart';

class SignalREvents {
  static const String receiveMessage = 'ReceiveMessage';
  static const String unReadMessageCount = 'UnReadMessageCountForUser';
  static const String sendMessage = 'SendMessage';
  static const String registerUser = 'RegisterUser';
  static const String deleteUnReadMessages = 'DeleteUnReadMessages';
}

class ChatService {
  final String baseUrl; // http://localhost:8080
  late final ApiClient api;

  HubConnection? _hub;
  bool _connected = false;

  final Map<int, void Function(Message)> _messageHandlers = {};
  void Function(int senderId, int count)? _onUnreadChanged;

  ChatService(this.baseUrl) {
    api = ApiClient(baseUrl);
  }

  Future<void> connect({required int eventId, required int userId}) async {
    if (_connected && _hub?.state == HubConnectionState.Connected) return;

    _hub = HubConnectionBuilder()
        .withUrl('$baseUrl/Chat')
        .withAutomaticReconnect()
        .build();

    _hub!.on(SignalREvents.receiveMessage, (arguments) {
      if (!(arguments?.isNotEmpty == true)) return;

      int _toInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

String _toStr(dynamic v) => (v ?? '').toString();

final args = arguments!;
final int eventId = _toInt(args[0]);
final int senderId = _toInt(args[1]);
final int receiverId = _toInt(args[2]);
final String messageText = _toStr(args[3]);
final int messageId = _toInt(args[4]);





      final msg = Message(
        id: messageId,
        eventId: eventId,
        senderId: senderId,
        receiverId: receiverId,
        messageText: messageText,
        timestamp: DateTime.now().toIso8601String(),
        isRead: false,
      );

      _messageHandlers[senderId]?.call(msg);
    });

    _hub!.on(SignalREvents.unReadMessageCount, (arguments) {
      if (arguments == null || arguments.length < 4) return;
      final int senderId = arguments[1] as int;
      final int count = arguments[3] as int;
      _onUnreadChanged?.call(senderId, count);
    });

    await _hub!.start();
    _connected = true;

    // IMPORTANT: our backend expects RegisterUser(eventId, userId)
    await _hub!.invoke(SignalREvents.registerUser, args: [eventId, userId]);
  }

  Future<void> sendMessage({
    required int eventId,
    required int receiverId,
    required String messageText,
  }) async {
    await _hub!.invoke(SignalREvents.sendMessage, args: [eventId, receiverId, messageText]);
  }

  Future<List<Message>> getChatMessages({
    required int eventId,
    required int myUserId,
    required int otherSideId,
  }) async {
    final data = await api.getJson('/Chat/getChatMessages?eventId=$eventId&myUserId=$myUserId&otherSideId=$otherSideId');
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return items.map((e) => Message.fromJson(e)).toList();
  }

  Future<Map<int, int>> getUnreadCounts({
    required int eventId,
    required int myUserId,
  }) async {
    final data = await api.getJson('/Chat/GetUnReadMessagesCountForEvent?eventId=$eventId&myUserId=$myUserId');
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    final map = <int, int>{};
    for (final it in items) {
      map[it['UserId'] as int] = it['Count'] as int;
    }
    return map;
  }


  Future<List<Conversation>> getMyConversations({
  required int eventId,
  required int myUserId,
}) async {
  final data = await api.getJson('/Chat/GetMyConversations?eventId=$eventId&myUserId=$myUserId');
  final items = (data['items'] as List).cast<Map<String, dynamic>>();
  return items.map((e) => Conversation.fromJson(e)).toList();
}


  Future<void> markMessagesAsRead(Set<int> ids) async {
    if (ids.isEmpty) return;
    await _hub!.invoke(SignalREvents.deleteUnReadMessages, args: [ids.toList()]);
  }

  void registerMessageHandler(int otherUserId, void Function(Message) handler) {
    _messageHandlers[otherUserId] = handler;
  }

  void unregisterMessageHandler(int otherUserId) {
    _messageHandlers.remove(otherUserId);
  }

  void registerUnreadChanged(void Function(int senderId, int count) handler) {
    _onUnreadChanged ??= handler;
  }

  Future<void> disconnect() async {
    _messageHandlers.clear();
    _connected = false;
    if (_hub != null) {
      await _hub!.stop();
      _hub = null;
    }
  }
}
