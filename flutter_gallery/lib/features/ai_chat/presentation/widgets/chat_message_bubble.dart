import 'package:flutter/material.dart';
import 'package:flutter_gallery/features/ai_chat/domain/entities/chat_message.dart';
import 'package:intl/intl.dart'; // For date formatting

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final bool isUserMessage = message.sender == MessageSender.user;
    final alignment =
        isUserMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = isUserMessage ? Colors.blue[600] : Colors.grey[700];
    final textColor = Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: <Widget>[
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18.0),
                topRight: const Radius.circular(18.0),
                bottomLeft: isUserMessage ? const Radius.circular(18.0) : const Radius.circular(0),
                bottomRight: isUserMessage ? const Radius.circular(0) : const Radius.circular(18.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              message.text,
              style: TextStyle(color: textColor, fontSize: 16.0),
              softWrap: true,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            DateFormat('hh:mm a').format(message.timestamp), // Example: 10:30 AM
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 10.0,
            ),
          ),
        ],
      ),
    );
  }
}
