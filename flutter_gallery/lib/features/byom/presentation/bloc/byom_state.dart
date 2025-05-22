part of 'byom_bloc.dart';

abstract class ByomState extends Equatable {
  const ByomState();

  @override
  List<Object?> get props => [];
}

class ByomInitial extends ByomState {
  final List<CustomModel> models;
  final String currentName;
  final String currentPath;

  const ByomInitial({
    this.models = const [],
    this.currentName = '',
    this.currentPath = '',
  });

  @override
  List<Object?> get props => [models, currentName, currentPath];
}

class ByomLoading extends ByomState {
  final List<CustomModel> models; // Keep current models to display while loading
  final String currentName;
  final String currentPath;

  const ByomLoading({
    required this.models,
    required this.currentName,
    required this.currentPath,
  });

  @override
  List<Object?> get props => [models, currentName, currentPath];
}

// State when form fields are being updated, or after loading.
// Could also be merged with ByomInitial if no distinct loading state is needed for just form changes.
class ByomFormState extends ByomState {
  final List<CustomModel> models;
  final String currentName;
  final String currentPath;

  const ByomFormState({
    required this.models,
    required this.currentName,
    required this.currentPath,
  });

  @override
  List<Object?> get props => [models, currentName, currentPath];
}


class ByomSuccess extends ByomState {
  final List<CustomModel> models;
  final String message; // e.g., "Model added successfully"

  const ByomSuccess({required this.models, required this.message});

  @override
  List<Object?> get props => [models, message];
}

class ByomError extends ByomState {
  final List<CustomModel> models; // Keep models to display even if an error occurs
  final String message;
  final String currentName; // Keep form data to allow user to correct it
  final String currentPath;

  const ByomError({
    required this.models,
    required this.message,
    required this.currentName,
    required this.currentPath,
  });

  @override
  List<Object?> get props => [models, message, currentName, currentPath];
}
