part of 'ask_image_bloc.dart';

abstract class AskImageState extends Equatable {
  const AskImageState();

  @override
  List<Object?> get props => [];
}

class AskImageInitial extends AskImageState {}

class AskImageLoading extends AskImageState {}

class AskImageLoaded extends AskImageState {
  final XFile? image; // Using XFile from image_picker
  final String? answer;
  final String? question; // To keep track of the asked question
  final double? latencyMs; // To store latency from platform channel

  const AskImageLoaded({this.image, this.answer, this.question, this.latencyMs});

  @override
  List<Object?> get props => [image, answer, question, latencyMs];
}

class AskImageError extends AskImageState {
  final String message;

  const AskImageError(this.message);

  @override
  List<Object?> get props => [message];
}
