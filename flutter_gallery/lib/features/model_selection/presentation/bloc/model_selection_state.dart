part of 'model_selection_bloc.dart';

abstract class ModelSelectionState extends Equatable {
  const ModelSelectionState();

  @override
  List<Object?> get props => [];
}

class ModelSelectionInitial extends ModelSelectionState {}

class ModelSelectionLoading extends ModelSelectionState {}

class ModelSelectionLoaded extends ModelSelectionState {
  final List<ModelInfo> models;
  final String? selectedModelId;

  const ModelSelectionLoaded({
    required this.models,
    this.selectedModelId,
  });

  @override
  List<Object?> get props => [models, selectedModelId];
}

class ModelSelectionError extends ModelSelectionState {
  final String message;

  const ModelSelectionError(this.message);

  @override
  List<Object?> get props => [message];
}
