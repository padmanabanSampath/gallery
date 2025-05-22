import 'package:flutter/services.dart'; // Required for MethodChannel
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_gallery/features/model_selection/presentation/bloc/model_selection_bloc.dart'; // To get selected model
import 'dart:async';

part 'prompt_lab_event.dart';
part 'prompt_lab_state.dart';

class PromptLabBloc extends Bloc<PromptLabEvent, PromptLabState> {
  final ModelSelectionBloc _modelSelectionBloc; // Inject ModelSelectionBloc

  static const MethodChannel _channel =
      MethodChannel('com.google.ai.edge.gallery/prompt_lab');

  // Available task types
  static const List<String> taskTypes = [
    'Freeform',
    'Summarize',
    'Rewrite',
    'Generate Code',
    'Translate'
  ];

  PromptLabBloc({required ModelSelectionBloc modelSelectionBloc})
      : _modelSelectionBloc = modelSelectionBloc,
        super(PromptLabInitial(taskType: taskTypes.first)) {
    on<PromptChangedEvent>(_onPromptChanged);
    on<TaskTypeChangedEvent>(_onTaskTypeChanged);
    on<ExecutePromptEvent>(_onExecutePrompt);
    on<ClearPromptLabEvent>(_onClearPromptLab);
  }

  void _onPromptChanged(PromptChangedEvent event, Emitter<PromptLabState> emit) {
    final currentState = state;
    if (currentState is PromptLabInitial) {
      emit(PromptLabInitial(prompt: event.prompt, taskType: currentState.taskType));
    } else if (currentState is PromptLabResponseReceived) {
      emit(PromptLabInitial(prompt: event.prompt, taskType: currentState.taskType));
    } else if (currentState is PromptLabError) {
      emit(PromptLabInitial(prompt: event.prompt, taskType: currentState.taskType));
    } else if (currentState is PromptLabLoading) {
      // If loading, ideally we shouldn't be changing prompt, but if we do,
      // we might want to reset or handle accordingly. For now, just update.
      // Or, perhaps, prevent changes while loading through UI.
       emit(PromptLabLoading(prompt: event.prompt, taskType: currentState.taskType));
    }
  }

  void _onTaskTypeChanged(TaskTypeChangedEvent event, Emitter<PromptLabState> emit) {
    final currentState = state;
     if (currentState is PromptLabInitial) {
      emit(PromptLabInitial(prompt: currentState.prompt, taskType: event.taskType));
    } else if (currentState is PromptLabResponseReceived) {
      // When task type changes, we should probably clear the old response.
      emit(PromptLabInitial(prompt: currentState.prompt, taskType: event.taskType));
    } else if (currentState is PromptLabError) {
      emit(PromptLabInitial(prompt: currentState.prompt, taskType: event.taskType));
    } else if (currentState is PromptLabLoading) {
       emit(PromptLabLoading(prompt: currentState.prompt, taskType: event.taskType));
    }
  }

  Future<void> _onExecutePrompt(
      ExecutePromptEvent event, Emitter<PromptLabState> emit) async {
    final currentPrompt = state is PromptLabInitial ? (state as PromptLabInitial).prompt :
                           state is PromptLabResponseReceived ? (state as PromptLabResponseReceived).prompt :
                           state is PromptLabError ? (state as PromptLabError).prompt :
                           state is PromptLabLoading ? (state as PromptLabLoading).prompt : '';
    final currentTaskType = state is PromptLabInitial ? (state as PromptLabInitial).taskType :
                            state is PromptLabResponseReceived ? (state as PromptLabResponseReceived).taskType :
                            state is PromptLabError ? (state as PromptLabError).taskType :
                            state is PromptLabLoading ? (state as PromptLabLoading).taskType : taskTypes.first;

    if (currentPrompt.isEmpty) {
      emit(PromptLabError(
          message: 'Prompt cannot be empty.',
          prompt: currentPrompt,
          taskType: currentTaskType));
      return;
    }

    emit(PromptLabLoading(prompt: currentPrompt, taskType: currentTaskType));

    final selectedModel = _modelSelectionBloc.getSelectedModel();
    final String? modelId = selectedModel?.id; // Can be null

    // Note: The platform channel contract says modelId is optional.
    // If no model is selected, modelId will be null, and the native side should handle it (e.g. use a default model).

    try {
      final result = await _channel.invokeMethod('processPrompt', {
        'prompt': currentPrompt,
        'taskType': currentTaskType,
        'modelId': modelId, // Will be null if no model is selected
      });

      if (result is Map) {
        final String response = result['response'] as String? ?? 'No response received.';
        final double? latencyMs = result['latencyMs'] as double?; // Optional
        emit(PromptLabResponseReceived(
          prompt: currentPrompt,
          taskType: currentTaskType,
          response: response,
          latencyMs: latencyMs,
        ));
      } else {
        emit(PromptLabError(
            message: 'Unexpected response type from platform: ${result.runtimeType}',
            prompt: currentPrompt,
            taskType: currentTaskType));
      }
    } on PlatformException catch (e) {
      emit(PromptLabError(
          message: 'Platform Error: ${e.message} (Code: ${e.code})',
          prompt: currentPrompt,
          taskType: currentTaskType));
    } catch (e) {
      emit(PromptLabError(
          message: 'Failed to process prompt: ${e.toString()}',
          prompt: currentPrompt,
          taskType: currentTaskType));
    }
  }

  void _onClearPromptLab(ClearPromptLabEvent event, Emitter<PromptLabState> emit) {
    // Reset to initial state, keeping the currently selected task type or resetting it
    // For now, let's reset to the first task type.
    emit(PromptLabInitial(prompt: '', taskType: taskTypes.first));
  }
}
