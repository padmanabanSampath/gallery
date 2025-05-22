import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class CustomModel extends Equatable {
  final String id; // Can be initially Flutter-generated, then updated from native
  final String name;
  final String path; // Path to the local model file
  final DateTime dateAdded;
  final bool isNativeConfirmed; // To track if this model is confirmed by native side

  CustomModel({
    String? id, // ID might come from native side later
    required this.name,
    required this.path,
    DateTime? dateAdded,
    this.isNativeConfirmed = false,
  })  : this.id = id ?? const Uuid().v4(), // Default to Flutter-generated if not provided
        this.dateAdded = dateAdded ?? DateTime.now();

  @override
  List<Object?> get props => [id, name, path, dateAdded, isNativeConfirmed];

  CustomModel copyWith({
    String? id,
    String? name,
    String? path,
    DateTime? dateAdded,
    bool? isNativeConfirmed,
  }) {
    return CustomModel(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      dateAdded: dateAdded ?? this.dateAdded,
      isNativeConfirmed: isNativeConfirmed ?? this.isNativeConfirmed,
    );
  }
}
