import 'dart:async';
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
  final String baseUrl;
  late final ApiClient api;

  HubConnection? _hub;
  bool _connected = false;

  int? _myUserId;
  int? _eventId;

  // key = otherUserId (conversation)
  final Map<int, void Function(Message)> _messageHandlers = {};

  void Function(int senderId, int count)? _onUnreadChanged;

  // Optional: callback for notifications
  void Function(Message msg)? _onAnyMessage;

  // ✅ callback after reconnect
  void Function()? _onReconnected;

  ChatService(this.baseUrl) {
    api = ApiClient(baseUrl);
  }

  // ✅ expose setter (Repo/RemoteDataSource هينده عليه)
  void setOnReconnected(void Function() cb) {
    _onReconnected = cb;
  }

  int _toInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  String _toStr(dynamic v) => (v ?? '').toString();

  Future<void> connect({required int eventId, required int userId}) async {
    // لو already connected لنفس اليوزر/الإيفنت خلاص
    if (_connected && _hub?.state == HubConnectionState.Connected) {
      _eventId = eventId;
      _myUserId = userId;
      return;
    }

    _eventId = eventId;
    _myUserId = userId;

    _hub = HubConnectionBuilder()
        .withUrl('$baseUrl/Chat')
        .withAutomaticReconnect()
        .build();

    // IMPORTANT: بعد reconnect لازم نعمل RegisterUser تاني + نعمل sync
    _hub!.onreconnected(({connectionId}) async {
      try {
        if (_eventId != null && _myUserId != null) {
          await _hub!.invoke(
            SignalREvents.registerUser,
            args: [_eventId!, _myUserId!],
          );
        }
      } catch (_) {
        // ignore register errors on reconnect (هنحاول تاني تلقائيًا)
      }

      // ✅ notify upper layers (ChatCubit) to sync missed messages
      _onReconnected?.call();
    });

    _hub!.on(SignalREvents.receiveMessage, (arguments) {
      if (arguments == null || arguments.isEmpty) return;

      final args = arguments;

      final int eventId = _toInt(args![0]);
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

      // 1) callback عام (تستخدمه للـ Notification)
      _onAnyMessage?.call(msg);

      // 2) توجيه الرسالة للمحادثة الصح
      final myId = _myUserId;
      if (myId != null) {
        final otherUserId = (senderId == myId) ? receiverId : senderId;
        _messageHandlers[otherUserId]?.call(msg);
      }
    });

    _hub!.on(SignalREvents.unReadMessageCount, (arguments) {
      if (arguments == null || arguments.length < 4) return;
      final senderId = _toInt(arguments![1]);
      final count = _toInt(arguments[3]);
      _onUnreadChanged?.call(senderId, count);
    });

    await _hub!.start();
    _connected = true;

    // backend expects RegisterUser(eventId, userId)
    await _hub!.invoke(SignalREvents.registerUser, args: [eventId, userId]);
  }

  Future<void> sendMessage({
    required int eventId,
    required int receiverId,
    required String messageText,
  }) async {
    await _hub!.invoke(
      SignalREvents.sendMessage,
      args: [eventId, receiverId, messageText],
    );
  }

  Future<List<Message>> getChatMessages({
    required int eventId,
    required int myUserId,
    required int otherSideId,
  }) async {
    final data = await api.getJson(
      '/Chat/getChatMessages?eventId=$eventId&myUserId=$myUserId&otherSideId=$otherSideId',
    );
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return items.map((e) => Message.fromJson(e)).toList();
  }

  Future<List<Message>> getMessagesSince({
    required int eventId,
    required int myUserId,
    required int otherSideId,
    required int afterId,
  }) async {
    final data = await api.getJson(
      '/Chat/GetMessagesSince?eventId=$eventId&myUserId=$myUserId&otherSideId=$otherSideId&afterId=$afterId',
    );
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return items.map((e) => Message.fromJson(e)).toList();
  }

  Future<Map<int, int>> getUnreadCounts({
    required int eventId,
    required int myUserId,
  }) async {
    final data = await api.getJson(
      '/Chat/GetUnReadMessagesCountForEvent?eventId=$eventId&myUserId=$myUserId',
    );
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    final map = <int, int>{};
    for (final it in items) {
      map[_toInt(it['UserId'])] = _toInt(it['Count']);
    }
    return map;
  }

  Future<List<Conversation>> getMyConversations({
    required int eventId,
    required int myUserId,
  }) async {
    final data = await api.getJson(
      '/Chat/GetMyConversations?eventId=$eventId&myUserId=$myUserId',
    );
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return items.map((e) => Conversation.fromJson(e)).toList();
  }

  Future<void> markMessagesAsRead(Set<int> ids) async {
    if (ids.isEmpty) return;
    await _hub!.invoke(
      SignalREvents.deleteUnReadMessages,
      args: [ids.toList()],
    );
  }

  // handler للمحادثة مع مستخدم معين
  void registerMessageHandler(int otherUserId, void Function(Message) handler) {
    _messageHandlers[otherUserId] = handler;
  }

  void unregisterMessageHandler(int otherUserId) {
    _messageHandlers.remove(otherUserId);
  }

  void registerUnreadChanged(void Function(int senderId, int count) handler) {
    _onUnreadChanged = handler;
  }

  void registerAnyMessageHandler(void Function(Message msg) handler) {
    _onAnyMessage = handler;
  }

  Future<void> registerPushToken({
    required int userId,
    required String token,
  }) async {
    await api.postJson('/Push/RegisterToken', {
      'UserId': userId,
      'Token': token,
    });
  }

  Future<void> disconnect() async {
    _messageHandlers.clear();
    _connected = false;
    _onAnyMessage = null;
    _onUnreadChanged = null;
    _onReconnected = null;

    if (_hub != null) {
      await _hub!.stop();
      _hub = null;
    }
  }
}
