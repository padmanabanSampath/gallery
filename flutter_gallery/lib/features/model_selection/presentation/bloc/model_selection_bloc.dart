import 'package:flutter/services.dart'; // Required for MethodChannel
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_gallery/features/model_selection/domain/entities/model_info.dart';
import 'dart:async';

part 'model_selection_event.dart';
part 'model_selection_state.dart';

class ModelSelectionBloc
    extends Bloc<ModelSelectionEvent, ModelSelectionState> {
  static const MethodChannel _channel =
      MethodChannel('com.google.ai.edge.gallery/model_management');

  List<ModelInfo> _cachedModels = []; // Cache for loaded models
  String? _currentlySelectedModelId;

  ModelSelectionBloc() : super(ModelSelectionInitial()) {
    on<LoadModelsEvent>(_onLoadModels);
    on<SelectModelEvent>(_onSelectModel);
  }

  Future<void> _onLoadModels(
      LoadModelsEvent event, Emitter<ModelSelectionState> emit) async {
    emit(ModelSelectionLoading());
    try {
      final List<dynamic>? result =
          await _channel.invokeListMethod<Map<dynamic, dynamic>>('getAvailableModels');

      if (result != null) {
        _cachedModels = result.map((modelMap) {
          final map = Map<String, dynamic>.from(modelMap); // Ensure correct map type
          return ModelInfo(
            id: map['id'] as String,
            name: map['name'] as String,
            description: map['description'] as String,
            isSelected: map['id'] as String == _currentlySelectedModelId,
          );
        }).toList();
        
        emit(ModelSelectionLoaded(
            models: _cachedModels,
            selectedModelId: _currentlySelectedModelId));
      } else {
        _cachedModels = []; // Clear cache if null result
        emit(ModelSelectionLoaded(models: _cachedModels, selectedModelId: _currentlySelectedModelId)); // Emit empty list
      }
    } on PlatformException catch (e) {
      emit(ModelSelectionError(
          'Failed to load models: ${e.message} (Code: ${e.code})'));
    } catch (e) {
      emit(ModelSelectionError('Failed to load models: ${e.toString()}'));
    }
  }

  Future<void> _onSelectModel(SelectModelEvent event, Emitter<ModelSelectionState> emit) async {
    final currentState = state;
    if (currentState is ModelSelectionLoaded || _cachedModels.isNotEmpty) {
      _currentlySelectedModelId = event.modelId;
      
      // Update isSelected status for all models in the cache
      _cachedModels = _cachedModels.map((model) {
        return model.copyWith(isSelected: model.id == event.modelId);
      }).toList();

      emit(ModelSelectionLoaded(
          models: _cachedModels, selectedModelId: event.modelId));

      try {
        await _channel.invokeMethod('notifyModelSelected', {'modelId': event.modelId});
        print('Native side notified of model selection: ${event.modelId}');
      } on PlatformException catch (e) {
        print(
            'Failed to notify native side of model selection: ${e.message} (Code: ${e.code})');
        // Optionally emit an error state or handle this more gracefully
      } catch (e) {
         print('Error notifying native side: ${e.toString()}');
      }
    } else {
       print('Attempted to select model, but models not loaded. Current state: $currentState');
       // Optionally, dispatch LoadModelsEvent first if models are not loaded
       // add(LoadModelsEvent()); 
       // then once loaded, the selection might need to be re-applied or handled.
    }
  }

  ModelInfo? getSelectedModel() {
    if (_currentlySelectedModelId == null || _cachedModels.isEmpty) return null;
    try {
      return _cachedModels.firstWhere((model) => model.id == _currentlySelectedModelId);
    } catch (e) {
      // This might happen if _currentlySelectedModelId is stale and not in _cachedModels
      print("Error finding selected model: $e. Resetting selection.");
      _currentlySelectedModelId = null; // Reset if problematic
      return null;
    }
  }
}
