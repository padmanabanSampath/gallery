part of 'ai_chat_bloc.dart';

abstract class AiChatState extends Equatable {
  final List<ChatMessage> messages;

  final List<ChatMessage> messages;
  final double? lastResponseLatencyMs; // Latency of the last AI response

  const AiChatState({this.messages = const [], this.lastResponseLatencyMs});

  @override
  List<Object?> get props => [messages, lastResponseLatencyMs];
}

class AiChatInitial extends AiChatState {
  const AiChatInitial() : super(messages: const [], lastResponseLatencyMs: null);
}

class AiChatLoading extends AiChatState {
  const AiChatLoading({required List<ChatMessage> messages, double? lastResponseLatencyMs})
      : super(messages: messages, lastResponseLatencyMs: lastResponseLatencyMs);
}

class AiChatLoaded extends AiChatState {
  const AiChatLoaded({required List<ChatMessage> messages, double? lastResponseLatencyMs})
      : super(messages: messages, lastResponseLatencyMs: lastResponseLatencyMs);
}

class AiChatError extends AiChatState {
  final String message;

  const AiChatError({
    required this.message,
    List<ChatMessage> messages = const [],
    double? lastResponseLatencyMs,
  }) : super(messages: messages, lastResponseLatencyMs: lastResponseLatencyMs);

  @override
  List<Object?> get props => [message, messages, lastResponseLatencyMs];
}
