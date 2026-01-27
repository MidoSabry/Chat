// chat_state.dart
import '../../data/model/message_model.dart';

enum ChatStatus { initial, loading, ready, error }

class ChatState {
  final ChatStatus status;
  final List<Message> messages;
  final String? error;

  // ✅ typing indicator
  final bool otherTyping;

  ChatState({
    this.status = ChatStatus.initial,
    this.messages = const [],
    this.error,
    this.otherTyping = false,
  });

  ChatState copyWith({
  ChatStatus? status,
  List<Message>? messages,
  String? error,
  bool? otherTyping,
}) {
  return ChatState(
    status: status ?? this.status,
    messages: messages ?? this.messages,
    error: error,
    otherTyping: otherTyping ?? this.otherTyping,
  );
}

}
