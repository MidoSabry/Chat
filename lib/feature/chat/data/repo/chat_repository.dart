import '../model/conversation_model.dart';
import '../model/message_model.dart';
import '../remote/chat_remote_data_source.dart';

abstract class ChatRepository {
  Future<void> connect({required int eventId, required int userId});
  Future<List<Message>> loadMessages({required int eventId, required int myUserId, required int otherUserId});
  /// ✅ NEW: fetch messages after last server id (for sync after reconnect)
  Future<List<Message>> getMessagesSince({ required int eventId,required int myUserId,required int otherUserId,required int afterId});

  Future<void> send({required int eventId, required int receiverId, required String messageText});
  Future<Map<int, int>> unreadCounts({required int eventId, required int myUserId});
  Future<void> markRead(Set<int> ids);

  void onMessage(int otherUserId, void Function(Message) handler);
  void offMessage(int otherUserId);
  void onUnreadChanged(void Function(int senderId, int count) handler);
  void onAnyMessage(void Function(Message msg) handler);
   /// ✅ callback يتنادي بعد SignalR reconnect
  void onReconnected(void Function() handler);
  Future<void> registerPushToken({required int userId, required String token});

  Future<List<Conversation>> conversations({required int eventId, required int myUserId});


  Future<void> disconnect();
}

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remote;
  ChatRepositoryImpl(this.remote);

  @override
  Future<void> connect({required int eventId, required int userId}) => remote.connect(eventId: eventId, userId: userId);

  @override
  Future<List<Message>> loadMessages({required int eventId, required int myUserId, required int otherUserId}) =>
      remote.getChatMessages(eventId: eventId, myUserId: myUserId, otherSideId: otherUserId);

   @override
  Future<List<Message>> getMessagesSince({
    required int eventId,
    required int myUserId,
    required int otherUserId,
    required int afterId,
  }) =>
      remote.getMessagesSince(
        eventId: eventId,
        myUserId: myUserId,
        otherSideId: otherUserId,
        afterId: afterId,
      );

  @override
  Future<void> send({required int eventId, required int receiverId, required String messageText}) =>
      remote.sendMessage(eventId: eventId, receiverId: receiverId, messageText: messageText);

  @override
  Future<Map<int, int>> unreadCounts({required int eventId, required int myUserId}) =>
      remote.getUnreadCounts(eventId: eventId, myUserId: myUserId);

  @override
  Future<void> markRead(Set<int> ids) => remote.markMessagesAsRead(ids);

  @override
  void onMessage(int otherUserId, void Function(Message) handler) => remote.registerMessageHandler(otherUserId, handler);

  @override
  void offMessage(int otherUserId) => remote.unregisterMessageHandler(otherUserId);

  @override
  void onUnreadChanged(void Function(int senderId, int count) handler) => remote.registerUnreadChanged(handler);

  @override
void onAnyMessage(void Function(Message msg) handler) {
  remote.registerAnyMessageHandler(handler);
}


@override
  void onReconnected(void Function() handler) =>
      remote.registerOnReconnected(handler);


@override
Future<void> registerPushToken({required int userId, required String token}) =>
    remote.registerPushToken(userId: userId, token: token);


  @override
Future<List<Conversation>> conversations({required int eventId, required int myUserId}) =>
    remote.getMyConversations(eventId: eventId, myUserId: myUserId);


  @override
  Future<void> disconnect() => remote.disconnect();
}
