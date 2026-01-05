import '../../data/model/message_model.dart';

enum ChatStatus { initial, loading, ready, error }

class ChatState {
  final ChatStatus status;
  final List<Message> messages;
  final String? error;

  ChatState({
    this.status = ChatStatus.initial,
    this.messages = const [],
    this.error,
  });

  ChatState copyWith({
    ChatStatus? status,
    List<Message>? messages,
    String? error,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      error: error,
    );
  }
}
