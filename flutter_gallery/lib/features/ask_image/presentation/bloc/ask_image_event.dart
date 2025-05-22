part of 'ask_image_bloc.dart';

abstract class AskImageEvent extends Equatable {
  const AskImageEvent();

  @override
  List<Object?> get props => [];
}

class PickImageEvent extends AskImageEvent {}

class AskQuestionEvent extends AskImageEvent {
  final String question;

  const AskQuestionEvent(this.question);

  @override
  List<Object?> get props => [question];
}

// Event to clear the selected image and answer
class ClearImageAndAnswerEvent extends AskImageEvent {}
