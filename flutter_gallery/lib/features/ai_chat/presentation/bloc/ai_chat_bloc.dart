import 'package:flutter/services.dart'; // Required for MethodChannel
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_gallery/features/ai_chat/domain/entities/chat_message.dart';
import 'package:flutter_gallery/features/model_selection/presentation/bloc/model_selection_bloc.dart'; // To get selected model
import 'package:uuid/uuid.dart';
import 'dart:async';

part 'ai_chat_event.dart';
part 'ai_chat_state.dart';

class AiChatBloc extends Bloc<AiChatEvent, AiChatState> {
  final Uuid _uuid = const Uuid();
  final ModelSelectionBloc _modelSelectionBloc;

  static const MethodChannel _channel =
      MethodChannel('com.google.ai.edge.gallery/ai_chat');

  AiChatBloc({required ModelSelectionBloc modelSelectionBloc})
      : _modelSelectionBloc = modelSelectionBloc,
        super(const AiChatInitial()) {
    on<SendMessageEvent>(_onSendMessage);
    on<ClearChatEvent>(_onClearChat);
    // Note: _ReceiveMessageEvent is removed as AI response is handled directly in _onSendMessage
  }

  Future<void> _onSendMessage(
      SendMessageEvent event, Emitter<AiChatState> emit) async {
    if (event.text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      text: event.text.trim(),
      sender: MessageSender.user,
    );

    // Current messages before adding the new user message will form the history
    final List<Map<String, String>> history = state.messages.map((msg) {
      return {
        'sender': msg.sender == MessageSender.user ? 'user' : 'ai',
        'text': msg.text,
      };
    }).toList();

    // Add user message to the list for UI update and emit loading state
    final updatedMessagesForUi = List<ChatMessage>.from(state.messages)..add(userMessage);
    emit(AiChatLoading(messages: updatedMessagesForUi, lastResponseLatencyMs: state.lastResponseLatencyMs));

    final selectedModel = _modelSelectionBloc.getSelectedModel();
    final String? modelId = selectedModel?.id;

    try {
      final result = await _channel.invokeMethod('getNextChatResponse', {
        'message': userMessage.text,
        'history': history,
        'modelId': modelId, // Optional, can be null
      });

      if (result is Map) {
        final String responseText = result['response'] as String? ?? 'No response from AI.';
        final double? latencyMs = result['latencyMs'] as double?;

        final aiMessage = ChatMessage(
          text: responseText,
          sender: MessageSender.ai,
        );
        final finalMessages = List<ChatMessage>.from(updatedMessagesForUi)..add(aiMessage);
        emit(AiChatLoaded(messages: finalMessages, lastResponseLatencyMs: latencyMs));
      } else {
        emit(AiChatError(
            message: 'Unexpected response type from platform: ${result.runtimeType}',
            messages: updatedMessagesForUi, // Keep UI messages
            lastResponseLatencyMs: state.lastResponseLatencyMs
            ));
      }
    } on PlatformException catch (e) {
      emit(AiChatError(
          message: 'Platform Error: ${e.message} (Code: ${e.code})',
          messages: updatedMessagesForUi,
          lastResponseLatencyMs: state.lastResponseLatencyMs
          ));
    } catch (e) {
      emit(AiChatError(
          message: 'Failed to get chat response: ${e.toString()}',
          messages: updatedMessagesForUi,
          lastResponseLatencyMs: state.lastResponseLatencyMs
          ));
    }
  }

  void _onClearChat(ClearChatEvent event, Emitter<AiChatState> emit) {
    emit(const AiChatInitial());
  }
}
