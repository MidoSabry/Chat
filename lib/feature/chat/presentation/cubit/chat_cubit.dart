import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/model/message_model.dart';
import '../../data/repo/chat_repository.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  final ChatRepository repo;

  ChatCubit(this.repo) : super(ChatState());

  final Set<int> _unreadIds = {};

  // لمنع تكرار رسائل السيرفر
  final Set<int> _seenServerIds = {};

  // آخر رسالة optimistic علشان نستبدلها برسالة السيرفر (echo)
  Message? _pendingOptimistic;

  Future<void> openChat({
    required int eventId,
    required int myUserId,
    required int otherUserId,
  }) async {
    emit(state.copyWith(status: ChatStatus.loading));

    try {
      await repo.connect(eventId: eventId, userId: myUserId);

      // ✅ 1) Load first (علشان ما يحصلش duplicate بين load و realtime)
      final messages = await repo.loadMessages(
        eventId: eventId,
        myUserId: myUserId,
        otherUserId: otherUserId,
      );

      _seenServerIds.clear();
      _unreadIds.clear();

      for (final m in messages) {
        _seenServerIds.add(m.id);
        if (m.receiverId == myUserId && !m.isRead) {
          _unreadIds.add(m.id);
        }
      }

      emit(state.copyWith(messages: messages, status: ChatStatus.ready));

      // ✅ 2) Then listen realtime
      repo.onMessage(otherUserId, (msg) {
        // ✅ Dedup by server messageId
        if (_seenServerIds.contains(msg.id)) return;
        _seenServerIds.add(msg.id);

        // ✅ لو دي echo لرسالتي optimistic: استبدلها بدل ما تضيفها
        if (_pendingOptimistic != null &&
            msg.senderId == myUserId &&
            msg.receiverId == otherUserId &&
            msg.messageText == _pendingOptimistic!.messageText) {
          final list = [...state.messages];
          list.removeWhere((x) => x.id == _pendingOptimistic!.id);
          list.add(msg);
          _pendingOptimistic = null;
          emit(state.copyWith(messages: list, status: ChatStatus.ready));
          return;
        }

        final updated = [...state.messages, msg];

        if (msg.receiverId == myUserId && !msg.isRead) {
          _unreadIds.add(msg.id);
        }

        emit(state.copyWith(messages: updated, status: ChatStatus.ready));
      });
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

    // ✅ optimistic id سالب عشان ما يتلخبطش مع ids السيرفر
    final temp = Message(
      id: -DateTime.now().millisecondsSinceEpoch,
      eventId: eventId,
      senderId: myUserId,
      receiverId: otherUserId,
      messageText: text,
      timestamp: DateTime.now().toIso8601String(),
      isRead: true,
    );

    _pendingOptimistic = temp;
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
    _pendingOptimistic = null;
  }
}
