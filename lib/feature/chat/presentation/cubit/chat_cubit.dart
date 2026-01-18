import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/model/message_model.dart';
import '../../data/repo/chat_repository.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  final ChatRepository repo;

  ChatCubit(this.repo) : super(ChatState());

  final Set<int> _unreadIds = {};
  final Set<int> _seenServerIds = {};

  Message? _pendingOptimistic;

  // ✅ لتفادي التداخل أثناء sync
  bool _syncing = false;

  Future<void> openChat({
    required int eventId,
    required int myUserId,
    required int otherUserId,
  }) async {
    emit(state.copyWith(status: ChatStatus.loading));

    try {
      await repo.connect(eventId: eventId, userId: myUserId);

      // ✅ 1) Load first
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

      // ✅ 2) Listen realtime (للمحادثة دي فقط)
      repo.onMessage(otherUserId, (msg) {
        if (_seenServerIds.contains(msg.id)) return;
        _seenServerIds.add(msg.id);

        // ✅ لو دي echo لرسالتي optimistic: استبدلها
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

      // ✅ 3) Sync after reconnect (لو النت قطع ورجع)
      repo.onReconnected(() async {
         debugPrint('🔄 Reconnected! Syncing missed messages...');
        await _syncMissedMessages(
          eventId: eventId,
          myUserId: myUserId,
          otherUserId: otherUserId,
        );
      });
    } catch (e) {
      emit(state.copyWith(status: ChatStatus.error, error: e.toString()));
    }
  }

  Future<void> _syncMissedMessages({
    required int eventId,
    required int myUserId,
    required int otherUserId,
  }) async {
    if (_syncing){
      debugPrint('⚠️ Already syncing, skipping...');
      return;
    } 
    _syncing = true;

try {
    int lastServerId = 0;
    for (final m in state.messages) {
      if (m.id > 0 && m.id > lastServerId) {
        lastServerId = m.id;
      }
    }

      debugPrint('📥 Fetching messages after ID: $lastServerId');

      final newer = await repo.getMessagesSince(
        eventId: eventId,
        myUserId: myUserId,
        otherUserId: otherUserId,
        afterId: lastServerId,
      );

      if (newer.isEmpty) {
      debugPrint('✅ No new messages');
      return;
    }

    debugPrint('✅ Found ${newer.length} new messages');

      final list = [...state.messages];
      int addedCount = 0;

      for (final m in newer) {
        if (_seenServerIds.contains(m.id)) continue;
        _seenServerIds.add(m.id);

        // لو رسالة جديدة تخصني كـ receiver
        if (m.receiverId == myUserId && !m.isRead) {
          _unreadIds.add(m.id);
        }

        list.add(m);
        addedCount++;
      }

     if (addedCount > 0) {
      list.sort((a, b) => a.id.compareTo(b.id));
      emit(state.copyWith(messages: list, status: ChatStatus.ready));
      debugPrint('✅ [Sync] Updated UI with $addedCount new messages');
    }
    } catch (e) {
      debugPrint('❌ Sync error:$e');
      // ignore sync errors (هنحاول تاني على reconnect آخر)
    } finally {
      _syncing = false;
    }
  }

  Future<void> send({
    required int eventId,
    required int myUserId,
    required int otherUserId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    // ✅ optimistic id سالب
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
    _syncing = false;
  }
}
