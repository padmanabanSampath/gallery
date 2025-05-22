part of 'prompt_lab_bloc.dart';

abstract class PromptLabState extends Equatable {
  const PromptLabState();

  @override
  List<Object?> get props => [];
}

class PromptLabInitial extends PromptLabState {
  final String prompt;
  final String taskType;

  const PromptLabInitial({this.prompt = '', this.taskType = 'Freeform'});

  @override
  List<Object?> get props => [prompt, taskType];
}

class PromptLabLoading extends PromptLabState {
  final String prompt;
  final String taskType;

  const PromptLabLoading({required this.prompt, required this.taskType});

  @override
  List<Object?> get props => [prompt, taskType];
}

class PromptLabResponseReceived extends PromptLabState {
  final String prompt;
  final String taskType;
  final String response;
  final double? latencyMs; // To store latency from platform channel

  const PromptLabResponseReceived(
      {required this.prompt,
      required this.taskType,
      required this.response,
      this.latencyMs});

  @override
  List<Object?> get props => [prompt, taskType, response, latencyMs];
}

class PromptLabError extends PromptLabState {
  final String message;
  final String prompt;
  final String taskType;

  const PromptLabError(
      {required this.message, required this.prompt, required this.taskType});

  @override
  List<Object?> get props => [message, prompt, taskType];
}
