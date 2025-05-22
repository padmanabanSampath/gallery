part of 'byom_bloc.dart';

abstract class ByomEvent extends Equatable {
  const ByomEvent();

  @override
  List<Object?> get props => [];
}

class LoadCustomModelsEvent extends ByomEvent {}

class AddCustomModelEvent extends ByomEvent {
  final String name;
  final String path;

  const AddCustomModelEvent({required this.name, required this.path});

  @override
  List<Object?> get props => [name, path];
}

class RemoveCustomModelEvent extends ByomEvent {
  final String modelId;

  const RemoveCustomModelEvent(this.modelId);

  @override
  List<Object?> get props => [modelId];
}

// Event to update the form fields in the state
class ByomFormChangedEvent extends ByomEvent {
  final String? name;
  final String? path;

  const ByomFormChangedEvent({this.name, this.path});

  @override
  List<Object?> get props => [name, path];
}
