part of 'model_selection_bloc.dart';

abstract class ModelSelectionEvent extends Equatable {
  const ModelSelectionEvent();

  @override
  List<Object?> get props => [];
}

class LoadModelsEvent extends ModelSelectionEvent {}

class SelectModelEvent extends ModelSelectionEvent {
  final String modelId;

  const SelectModelEvent(this.modelId);

  @override
  List<Object?> get props => [modelId];
}
