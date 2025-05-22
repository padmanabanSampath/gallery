import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

enum MessageSender { user, ai }

class ChatMessage extends Equatable {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  ChatMessage({
    String? id,
    required this.text,
    required this.sender,
    DateTime? timestamp,
  })  : this.id = id ?? const Uuid().v4(),
        this.timestamp = timestamp ?? DateTime.now();

  @override
  List<Object?> get props => [id, text, sender, timestamp];
}
