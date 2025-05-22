import 'package:flutter/services.dart'; // Required for MethodChannel
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_gallery/features/model_selection/presentation/bloc/model_selection_bloc.dart'; // To get selected model
import 'dart:async';

part 'ask_image_event.dart';
part 'ask_image_state.dart';

class AskImageBloc extends Bloc<AskImageEvent, AskImageState> {
  final ImagePicker _picker = ImagePicker();
  final ModelSelectionBloc _modelSelectionBloc; // Inject ModelSelectionBloc

  static const MethodChannel _channel =
      MethodChannel('com.google.ai.edge.gallery/ask_image');

  AskImageBloc({required ModelSelectionBloc modelSelectionBloc})
      : _modelSelectionBloc = modelSelectionBloc,
        super(AskImageInitial()) {
    on<PickImageEvent>(_onPickImage);
    on<AskQuestionEvent>(_onAskQuestion);
    on<ClearImageAndAnswerEvent>(_onClearImageAndAnswer);
  }

  Future<void> _onPickImage(
      PickImageEvent event, Emitter<AskImageState> emit) async {
    try {
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        // If there was a question before, keep it, otherwise null
        String? previousQuestion;
        if (state is AskImageLoaded) {
          previousQuestion = (state as AskImageLoaded).question;
        }
        emit(AskImageLoaded(image: pickedFile, question: previousQuestion, answer: null));
      }
    } catch (e) {
      emit(AskImageError('Failed to pick image: ${e.toString()}'));
    }
  }

  Future<void> _onAskQuestion(
      AskQuestionEvent event, Emitter<AskImageState> emit) async {
    if (state is AskImageLoaded) {
      final currentState = state as AskImageLoaded;
      if (currentState.image == null) {
        emit(const AskImageError('Please pick an image first.'));
        // Re-emit the current state to ensure UI consistency if needed,
        // or emit a specific state indicating an error for this operation
        emit(AskImageLoaded(image: currentState.image, question: event.question, answer: null));
        return;
      }
      emit(AskImageLoading());

      final selectedModel = _modelSelectionBloc.getSelectedModel();
      final String? modelId = selectedModel?.id;

      if (modelId == null || modelId.isEmpty) {
        emit(const AskImageError('No model selected. Please select a model first.'));
        // Re-emit previous state to avoid losing image/question
        emit(AskImageLoaded(image: currentState.image, question: event.question, answer: null, latencyMs: null));
        return;
      }

      try {
        final result = await _channel.invokeMethod('processImageQuery', {
          'imagePath': currentState.image!.path,
          'question': event.question,
          'modelId': modelId,
        });

        if (result is Map) {
          final String answer = result['answer'] as String? ?? 'No answer received.';
          final double latencyMs = result['latencyMs'] as double? ?? 0.0;
          emit(AskImageLoaded(
            image: currentState.image,
            question: event.question,
            answer: answer,
            latencyMs: latencyMs,
          ));
        } else {
          emit(AskImageError('Unexpected response type from platform: ${result.runtimeType}'));
        }
      } on PlatformException catch (e) {
        emit(AskImageError('Platform Error: ${e.message} (Code: ${e.code})'));
        // Re-emit previous state to avoid losing image/question but show error
         emit(AskImageLoaded(image: currentState.image, question: event.question, answer: null, latencyMs: null));
      } catch (e) {
        emit(AskImageError('Failed to process question: ${e.toString()}'));
         emit(AskImageLoaded(image: currentState.image, question: event.question, answer: null, latencyMs: null));
      }
    } else {
      // This case should ideally not be reached if UI enables 'Ask Question' button correctly
      emit(const AskImageError('Cannot process question: No image loaded or invalid state.'));
    }
  }

  void _onClearImageAndAnswer(
    ClearImageAndAnswerEvent event, Emitter<AskImageState> emit) {
    emit(AskImageInitial()); // Reset to initial state, or AskImageLoaded with null image/answer
    // Alternatively, to keep the UI structure for AskImageLoaded:
    // emit(const AskImageLoaded(image: null, answer: null, question: null));
    // For a full clear, AskImageInitial is better.
  }
}
