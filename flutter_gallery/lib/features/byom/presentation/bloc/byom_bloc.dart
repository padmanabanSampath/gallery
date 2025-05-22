import 'package:flutter/services.dart'; // Required for MethodChannel
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_gallery/features/byom/domain/entities/custom_model.dart';
// Uuid is already imported via custom_model.dart if needed there, or import here if used directly
import 'dart:async';

part 'byom_event.dart';
part 'byom_state.dart';

class ByomBloc extends Bloc<ByomEvent, ByomState> {
  static const MethodChannel _channel =
      MethodChannel('com.google.ai.edge.gallery/model_management');

  List<CustomModel> _customModels = [];
  String _currentName = '';
  String _currentPath = '';

  ByomBloc() : super(const ByomInitial()) {
    on<LoadCustomModelsEvent>(_onLoadCustomModels);
    on<AddCustomModelEvent>(_onAddCustomModel);
    on<RemoveCustomModelEvent>(_onRemoveCustomModel); // No platform channel for remove yet, local only
    on<ByomFormChangedEvent>(_onByomFormChanged);
  }

  void _onLoadCustomModels(
      LoadCustomModelsEvent event, Emitter<ByomState> emit) {
    // In a real app, load from storage (e.g., SharedPreferences, SQLite)
    emit(ByomLoading(models: _customModels, currentName: _currentName, currentPath: _currentPath));
    // Simulate loading delay
    // await Future.delayed(const Duration(milliseconds: 300));
    emit(ByomFormState(models: _customModels, currentName: _currentName, currentPath: _currentPath));
  }

  Future<void> _onAddCustomModel(
      AddCustomModelEvent event, Emitter<ByomState> emit) async {
    emit(ByomLoading(models: _customModels, currentName: event.name, currentPath: event.path));

    if (event.name.trim().isEmpty || event.path.trim().isEmpty) {
      emit(ByomError(
          models: _customModels,
          message: 'Model name and path cannot be empty.',
          currentName: event.name,
          currentPath: event.path));
      return;
    }

    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMapMethod(
          'addCustomModel', {'name': event.name.trim(), 'path': event.path.trim()});

      if (result != null) {
        final String nativeModelId = result['modelId'] as String;
        // Potentially other metadata like validatedName, etc.
        // String validatedName = result['name'] as String? ?? event.name.trim();

        final newModel = CustomModel(
          id: nativeModelId, // Use ID from native side
          name: event.name.trim(), // Or validatedName if provided
          path: event.path.trim(),
          isNativeConfirmed: true,
        );
        _customModels.add(newModel);
        _currentName = ''; // Clear form
        _currentPath = '';

        emit(ByomSuccess(
            models: _customModels,
            message: 'Model "${newModel.name}" added successfully with ID: $nativeModelId'));
        emit(ByomFormState(models: _customModels, currentName: _currentName, currentPath: _currentPath));
      } else {
        emit(ByomError(
            models: _customModels,
            message: 'Failed to add model: No confirmation from native side.',
            currentName: event.name,
            currentPath: event.path));
      }
    } on PlatformException catch (e) {
      emit(ByomError(
          models: _customModels,
          message: 'Platform Error adding model: ${e.message} (Code: ${e.code})',
          currentName: event.name,
          currentPath: event.path));
    } catch (e) {
      emit(ByomError(
          models: _customModels,
          message: 'Error adding model: ${e.toString()}',
          currentName: event.name,
          currentPath: event.path));
    }
  }

  void _onRemoveCustomModel(
      RemoveCustomModelEvent event, Emitter<ByomState> emit) {
    // Note: No platform channel call for remove specified in this task.
    // This remains a local removal. If native side needs to be informed,
    // a 'removeCustomModel' method would be needed on the channel.
    emit(ByomLoading(models: _customModels, currentName: _currentName, currentPath: _currentPath));
    _customModels.removeWhere((model) => model.id == event.modelId);
    emit(ByomFormState(models: _customModels, currentName: _currentName, currentPath: _currentPath));
  }

  void _onByomFormChanged(ByomFormChangedEvent event, Emitter<ByomState> emit) {
    _currentName = event.name ?? _currentName;
    _currentPath = event.path ?? _currentPath;
    emit(ByomFormState(models: _customModels, currentName: _currentName, currentPath: _currentPath));
  }
}
