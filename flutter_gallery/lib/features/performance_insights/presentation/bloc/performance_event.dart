part of 'performance_bloc.dart';

abstract class PerformanceEvent extends Equatable {
  const PerformanceEvent();

  @override
  List<Object?> get props => [];
}

class LoadPerformanceMetricsEvent extends PerformanceEvent {
  final String? modelId; // Optional: if metrics are model-specific

  const LoadPerformanceMetricsEvent({this.modelId});

  @override
  List<Object?> get props => [modelId];
}

// Event to be triggered when the selected model changes
class SelectedModelChangedEvent extends PerformanceEvent {
  final String? modelId;

  const SelectedModelChangedEvent({this.modelId});

  @override
  List<Object?> get props => [modelId];
}
