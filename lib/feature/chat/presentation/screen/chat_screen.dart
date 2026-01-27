import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/chat_route_tracker.dart';
import '../../../../core/services/ios_active_chat_channel.dart';
import '../cubit/chat_cubit.dart';
import '../cubit/chat_state.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final int eventId;
  final int myUserId;
  final int otherUserId;

  const ChatScreen({
    super.key,
    required this.eventId,
    required this.myUserId,
    required this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  late final ChatCubit _chatCubit;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await IOSActiveChat.setActiveChat(
        eventId: widget.eventId,
        myUserId: widget.myUserId,
        otherUserId: widget.otherUserId,
      );
    });

    _chatCubit = context.read<ChatCubit>();

    // ✅ قلنا إن الشات ده مفتوح
    ChatRouteTracker.setOpenChat(
      eventId: widget.eventId,
      myUserId: widget.myUserId,
      otherUserId: widget.otherUserId,
    );

    _chatCubit.openChat(
      eventId: widget.eventId,
      myUserId: widget.myUserId,
      otherUserId: widget.otherUserId,
    );

    IOSActiveChat.setActiveChat(
      eventId: widget.eventId,
      myUserId: widget.myUserId,
      otherUserId: widget.otherUserId,
    );
  }

  @override
  void dispose() {
    ChatRouteTracker.clear();
    _chatCubit.closeChat(widget.otherUserId);

    _controller.dispose();
    _scroll.dispose();
    IOSActiveChat.clearActiveChat();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios), // شكل iOS
                onPressed: () {
                  Navigator.pop(context);
                },
              )
            : null,
        title: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Chat with ${widget.otherUserId}'),
    BlocBuilder<ChatCubit, ChatState>(
      buildWhen: (p, n) => p.otherTyping != n.otherTyping,
      builder: (_, st) => st.otherTyping
          ? const Text('typing...', style: TextStyle(fontSize: 12))
          : const SizedBox.shrink(),
    ),
  ],
),

      ),

      body: BlocConsumer<ChatCubit, ChatState>(
        listener: (_, state) {
          if (state.status == ChatStatus.ready) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _scrollToBottom(),
            );
          }
        },
        builder: (context, state) {
          if (state.status == ChatStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == ChatStatus.error) {
            return Center(child: Text(state.error ?? 'Error'));
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  itemCount: state.messages.length,
                  itemBuilder: (_, i) {
                    final m = state.messages[i];
                    final isMe = m.senderId == widget.myUserId;
                   final pending = isMe && m.id < 0;     // optimistic
final read = isMe && m.id > 0 && m.isRead;

return MessageBubble(
  text: m.messageText,
  isMe: isMe,
  pending: pending,
  read: read,
);


                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          onChanged: (v) => context.read<ChatCubit>().onTextChanged(v),

                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () async {
                          final text = _controller.text;
                          _controller.clear();
                          await context.read<ChatCubit>().send(
                            eventId: widget.eventId,
                            myUserId: widget.myUserId,
                            otherUserId: widget.otherUserId,
                            text: text,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
