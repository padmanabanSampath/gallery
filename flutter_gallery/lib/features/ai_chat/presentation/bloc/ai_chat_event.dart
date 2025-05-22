part of 'ai_chat_bloc.dart';

abstract class AiChatEvent extends Equatable {
  const AiChatEvent();

  @override
  List<Object?> get props => [];
}

class SendMessageEvent extends AiChatEvent {
  final String text;

  const SendMessageEvent(this.text);

  @override
  List<Object?> get props => [text];
}

class ClearChatEvent extends AiChatEvent {}

// Internal event for BLoC to add AI response
class _ReceiveMessageEvent extends AiChatEvent {
  final ChatMessage message;

  const _ReceiveMessageEvent(this.message);

  @override
  List<Object?> get props => [message];
}
