import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/model/message_model.dart';
import '../../data/repo/chat_repository.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  final ChatRepository repo;

  ChatCubit(this.repo) : super(ChatState());

  final Set<int> _unreadIds = {};

  Future<void> openChat({
    required int eventId,
    required int myUserId,
    required int otherUserId,
  }) async {
    emit(state.copyWith(status: ChatStatus.loading));

    try {
      await repo.connect(eventId: eventId, userId: myUserId);

      repo.onMessage(otherUserId, (msg) {
        final updated = [...state.messages, msg];
        if (msg.receiverId == myUserId && !msg.isRead) {
          _unreadIds.add(msg.id);
        }
        emit(state.copyWith(messages: updated, status: ChatStatus.ready));
      });

      final messages = await repo.loadMessages(eventId: eventId, myUserId: myUserId, otherUserId: otherUserId);
      emit(state.copyWith(messages: messages, status: ChatStatus.ready));
    } catch (e) {
      emit(state.copyWith(status: ChatStatus.error, error: e.toString()));
    }
  }

  Future<void> send({
    required int eventId,
    required int myUserId,
    required int otherUserId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    // optimistic local add
    final temp = Message(
      id: DateTime.now().millisecondsSinceEpoch,
      eventId: eventId,
      senderId: myUserId,
      receiverId: otherUserId,
      messageText: text,
      timestamp: DateTime.now().toIso8601String(),
      isRead: true,
    );

    emit(state.copyWith(messages: [...state.messages, temp]));

    await repo.send(eventId: eventId, receiverId: otherUserId, messageText: text);
  }

  Future<void> markRead() async {
    if (_unreadIds.isEmpty) return;
    await repo.markRead(_unreadIds);
    _unreadIds.clear();
  }

  Future<void> closeChat(int otherUserId) async {
    repo.offMessage(otherUserId);
  }
}
