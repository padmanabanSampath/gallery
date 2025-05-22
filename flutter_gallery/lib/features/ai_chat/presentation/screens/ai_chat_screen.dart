import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gallery/features/ai_chat/presentation/bloc/ai_chat_bloc.dart';
import 'package:flutter_gallery/features/ai_chat/presentation/widgets/chat_message_bubble.dart';
import 'package:flutter_gallery/features/ai_chat/domain/entities/chat_message.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(BuildContext context) {
    if (_textController.text.trim().isNotEmpty) {
      context.read<AiChatBloc>().add(SendMessageEvent(_textController.text.trim()));
      _textController.clear();
      // Scroll to bottom after sending a message
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    // Needs a slight delay for the ListView to update
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Access ModelSelectionBloc from the context (it's provided globally in main.dart)
    final modelSelectionBloc = BlocProvider.of<ModelSelectionBloc>(context);

    return BlocProvider(
      create: (context) => AiChatBloc(modelSelectionBloc: modelSelectionBloc),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI Chat'),
          actions: [
            BlocBuilder<AiChatBloc, AiChatState>(
              builder: (context, state) {
                if (state.messages.isNotEmpty) {
                  return IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Clear Chat',
                    onPressed: () {
                      // Show confirmation dialog
                      showDialog(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            title: const Text('Confirm Clear'),
                            content: const Text('Are you sure you want to clear the entire chat history?'),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('Cancel'),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                },
                              ),
                              TextButton(
                                child: const Text('Clear'),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                onPressed: () {
                                  context.read<AiChatBloc>().add(ClearChatEvent());
                                  Navigator.of(dialogContext).pop();
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: BlocConsumer<AiChatBloc, AiChatState>(
          listener: (context, state) {
            if (state is AiChatError) {
              ScaffoldMessenger.of(context).removeCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${state.message}'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            } else if (state is AiChatLoaded) {
              if (state.lastResponseLatencyMs != null && state.lastResponseLatencyMs! > 0) {
                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('AI response latency: ${state.lastResponseLatencyMs!.toStringAsFixed(0)} ms'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
              _scrollToBottom();
            } else if (state is AiChatLoading && state.messages.isNotEmpty) {
              _scrollToBottom();
            }
          },
          builder: (context, state) {
            return Column(
              children: <Widget>[
                // Chat messages area
                Expanded(
                  child: state.messages.isEmpty && state is! AiChatLoading
                      ? Center(
                          child: Text(
                          'No messages yet. Start a conversation!',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8.0),
                          itemCount: state.messages.length,
                          itemBuilder: (context, index) {
                            final message = state.messages[index];
                            return ChatMessageBubble(message: message);
                          },
                        ),
                ),

                // Loading indicator (subtle, below messages, above input)
                if (state is AiChatLoading && state.messages.isNotEmpty) // Only show if already messages exist
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),


                // Input area
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            hintText: 'Type your message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.0),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[200],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                          ),
                          onSubmitted: (text) => _sendMessage(context),
                          textInputAction: TextInputAction.send,
                          enabled: state is! AiChatLoading, // Disable input when loading new message
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: state is AiChatLoading ? null : () => _sendMessage(context),
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12.0)
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
