import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/chat_route_tracker.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../core/services/push_service.dart';
import '../../data/model/conversation_model.dart';
import '../cubit/chat_cubit.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  // Demo values
  final int eventId = 1;

  late final int myUserId;

  Future<List<Conversation>>? _future;

  // ✅ علشان ما نركبش listeners أكتر من مرة لو حصل rebuild/عودة للشاشة
  bool _wiredAnyMessage = false;

  @override
  void initState() {
    super.initState();

    // Demo: userId حسب المنصة
    if (Platform.isAndroid) {
      myUserId = 1;
    } else if (Platform.isIOS) {
      myUserId = 2;
    } else {
      myUserId = 1;
    }

    _boot();
  }

  Future<void> _boot() async {
    final cubit = context.read<ChatCubit>();

    // ✅ خليها await (مفيد عشان SignalR يبدأ قبل ما تعتمد عليه)
    await cubit.repo.connect(eventId: eventId, userId: myUserId);

    // ✅ Listener واحد فقط لإشعارات foreground من SignalR
    if (!_wiredAnyMessage) {
      _wiredAnyMessage = true;

      cubit.repo.onAnyMessage((msg) {
        // لو الرسالة مني تجاهل
        if (msg.senderId == myUserId) return;

        // ✅ لو نفس الشات مفتوح متطلعش Notification
        if (ChatRouteTracker.shouldSuppressNotification(
          eventId: msg.eventId,
          senderId: msg.senderId,
          receiverId: msg.receiverId,
        )) {
          debugPrint('🚫 [SignalR] Suppressing notification - chat is open');
          return;
        }

        debugPrint('🔔 [SignalR] Showing notification from ${msg.senderId}');

        LocalNotificationService.showMessage(
          id: msg.id, // server message id
          title: 'New message from ${msg.senderId}',
          body: msg.messageText,
          payload: jsonEncode({
            'eventId': msg.eventId,
            'senderId': msg.senderId,
            'receiverId': msg.receiverId,
          }),
        );
      });
    }

    // ✅ Register token + token refresh
    await _initPushToken();
    _listenTokenRefresh();

    // Load conversations
    _reload();
  }

  Future<void> _initPushToken() async {
    final token = await PushService.getToken();
    if (token == null || token.isEmpty) return;

    final cubit = context.read<ChatCubit>();
    await cubit.repo.registerPushToken(userId: myUserId, token: token);
  }

  void _listenTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (newToken.isEmpty) return;
      final cubit = context.read<ChatCubit>();
      await cubit.repo.registerPushToken(userId: myUserId, token: newToken);
      debugPrint('✅ FCM token refreshed & registered');
    });
  }

  void _reload() {
    final cubit = context.read<ChatCubit>();
    _future = cubit.repo.conversations(eventId: eventId, myUserId: myUserId);
    setState(() {});
  }

  Future<int?> _askUserId(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Start chat with userId'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'e.g. 1'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final id = int.tryParse(controller.text.trim());
              Navigator.pop(context, id);
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  Future<void> _openChatWith(int otherUserId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ChatCubit>(),
          child: ChatScreen(
            eventId: eventId,
            myUserId: myUserId,
            otherUserId: otherUserId,
          ),
        ),
      ),
    );

    // Refresh after returning
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Conversations (me=$myUserId)'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final otherId = await _askUserId(context);
          if (otherId == null) return;
          if (otherId == myUserId) return;
          await _openChatWith(otherId);
        },
      ),
      body: FutureBuilder<List<Conversation>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: ${snap.error}'),
              ),
            );
          }

          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('No conversations yet'));
          }

          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final c = list[i];
              return ListTile(
                title: Text('User ${c.userId}'),
                subtitle: Text(
                  c.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: c.unreadCount > 0
                    ? CircleAvatar(
                        radius: 12,
                        child: Text(
                          '${c.unreadCount}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      )
                    : null,
                onTap: () => _openChatWith(c.userId),
              );
            },
          );
        },
      ),
    );
  }
}
