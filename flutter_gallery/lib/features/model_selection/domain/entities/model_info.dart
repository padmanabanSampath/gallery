import 'package:equatable/equatable.dart';

class ModelInfo extends Equatable {
  final String id;
  final String name;
  final String description;
  final bool isSelected; // To manage selection state in the UI

  const ModelInfo({
    required this.id,
    required this.name,
    required this.description,
    this.isSelected = false,
  });

  ModelInfo copyWith({
    String? id,
    String? name,
    String? description,
    bool? isSelected,
  }) {
    return ModelInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  List<Object?> get props => [id, name, description, isSelected];
}
