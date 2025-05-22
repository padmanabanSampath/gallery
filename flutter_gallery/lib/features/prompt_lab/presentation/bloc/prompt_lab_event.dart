part of 'prompt_lab_bloc.dart';

abstract class PromptLabEvent extends Equatable {
  const PromptLabEvent();

  @override
  List<Object?> get props => [];
}

class PromptChangedEvent extends PromptLabEvent {
  final String prompt;

  const PromptChangedEvent(this.prompt);

  @override
  List<Object?> get props => [prompt];
}

class TaskTypeChangedEvent extends PromptLabEvent {
  final String taskType; // For simplicity, using String. Could be an enum.

  const TaskTypeChangedEvent(this.taskType);

  @override
  List<Object?> get props => [taskType];
}

class ExecutePromptEvent extends PromptLabEvent {}

class ClearPromptLabEvent extends PromptLabEvent {}
