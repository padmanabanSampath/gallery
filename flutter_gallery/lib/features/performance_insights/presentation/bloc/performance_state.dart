part of 'performance_bloc.dart';

abstract class PerformanceState extends Equatable {
  const PerformanceState();

  @override
  List<Object?> get props => [];
}

class PerformanceInitial extends PerformanceState {}

class PerformanceLoading extends PerformanceState {
  final String? modelId;
  const PerformanceLoading({this.modelId});

  @override
  List<Object?> get props => [modelId];
}

class PerformanceLoaded extends PerformanceState {
  final String modelName; // Name of the model for which metrics are shown
  final double ttft; // Time To First Token in ms
  final double decodeSpeed; // Tokens per second
  final double latency; // Total latency in ms
  final Map<String, dynamic> additionalMetrics; // For any other metrics

  const PerformanceLoaded({
    required this.modelName,
    required this.ttft,
    required this.decodeSpeed,
    required this.latency,
    this.additionalMetrics = const {},
  });

  @override
  List<Object?> get props => [modelName, ttft, decodeSpeed, latency, additionalMetrics];
}

class PerformanceError extends PerformanceState {
  final String message;

  const PerformanceError(this.message);

  @override
  List<Object?> get props => [message];
}
