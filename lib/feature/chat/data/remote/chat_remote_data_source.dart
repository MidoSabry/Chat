import '../../../../core/services/chat_service.dart';
import '../model/conversation_model.dart';
import '../model/message_model.dart';

abstract class ChatRemoteDataSource {
  Future<void> connect({required int eventId, required int userId});
  Future<List<Message>> getChatMessages({required int eventId, required int myUserId, required int otherSideId});
  /// ✅ NEW: fetch messages after last server id (for sync after reconnect)
  Future<List<Message>> getMessagesSince({required int eventId,required int myUserId,required int otherSideId,required int afterId});
  Future<void> sendMessage({required int eventId, required int receiverId, required String messageText});
  Future<Map<int, int>> getUnreadCounts({required int eventId, required int myUserId});
  Future<void> markMessagesAsRead(Set<int> ids);

  void registerMessageHandler(int otherUserId, void Function(Message) handler);
  void unregisterMessageHandler(int otherUserId);
  void registerUnreadChanged(void Function(int senderId, int count) handler);
  void registerAnyMessageHandler(void Function(Message msg) handler);
  /// ✅ callback يتنادي بعد SignalR reconnect
  void registerOnReconnected(void Function() handler);
  Future<void> registerPushToken({required int userId, required String token});
  Future<List<Conversation>> getMyConversations({required int eventId, required int myUserId});


  Future<void> disconnect();
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final ChatService service;
  ChatRemoteDataSourceImpl(this.service);

  @override
  Future<void> connect({required int eventId, required int userId}) => service.connect(eventId: eventId, userId: userId);

  @override
  Future<List<Message>> getChatMessages({required int eventId, required int myUserId, required int otherSideId}) =>
      service.getChatMessages(eventId: eventId, myUserId: myUserId, otherSideId: otherSideId);

  @override
  Future<List<Message>> getMessagesSince({
    required int eventId,
    required int myUserId,
    required int otherSideId,
    required int afterId,
  }) =>
      service.getMessagesSince(
        eventId: eventId,
        myUserId: myUserId,
        otherSideId: otherSideId,
        afterId: afterId,
      );

  @override
  Future<void> sendMessage({required int eventId, required int receiverId, required String messageText}) =>
      service.sendMessage(eventId: eventId, receiverId: receiverId, messageText: messageText);

  @override
  Future<Map<int, int>> getUnreadCounts({required int eventId, required int myUserId}) =>
      service.getUnreadCounts(eventId: eventId, myUserId: myUserId);

  @override
  Future<void> markMessagesAsRead(Set<int> ids) => service.markMessagesAsRead(ids);

  @override
  void registerMessageHandler(int otherUserId, void Function(Message) handler) => service.registerMessageHandler(otherUserId, handler);

  @override
  void unregisterMessageHandler(int otherUserId) => service.unregisterMessageHandler(otherUserId);

  @override
  void registerUnreadChanged(void Function(int senderId, int count) handler) => service.registerUnreadChanged(handler);

  @override
  Future<void> disconnect() => service.disconnect();

    @override
  void registerAnyMessageHandler(void Function(Message msg) handler) =>
      service.registerAnyMessageHandler(handler);

   @override
  void registerOnReconnected(void Function() handler) =>
      service.setOnReconnected(handler);


  @override
Future<void> registerPushToken({required int userId, required String token}) =>
    service.registerPushToken(userId: userId, token: token);

  

  @override
Future<List<Conversation>> getMyConversations({required int eventId, required int myUserId}) =>
    service.getMyConversations(eventId: eventId, myUserId: myUserId);

}
