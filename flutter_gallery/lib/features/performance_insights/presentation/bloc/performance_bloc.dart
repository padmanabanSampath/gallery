import 'package:flutter/services.dart'; // Required for MethodChannel
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_gallery/features/model_selection/presentation/bloc/model_selection_bloc.dart';
import 'package:flutter_gallery/features/model_selection/domain/entities/model_info.dart';
import 'dart:async';

part 'performance_event.dart';
part 'performance_state.dart';

class PerformanceBloc extends Bloc<PerformanceEvent, PerformanceState> {
  final ModelSelectionBloc modelSelectionBloc;
  StreamSubscription? _modelSelectionSubscription;

  static const MethodChannel _channel =
      MethodChannel('com.google.ai.edge.gallery/performance');

  PerformanceBloc({required this.modelSelectionBloc}) : super(PerformanceInitial()) {
    on<LoadPerformanceMetricsEvent>(_onLoadPerformanceMetrics);
    on<SelectedModelChangedEvent>(_onSelectedModelChanged);

    _modelSelectionSubscription = modelSelectionBloc.stream.listen((modelState) {
      if (modelState is ModelSelectionLoaded) {
        add(SelectedModelChangedEvent(modelId: modelState.selectedModelId));
      } else if (modelState is ModelSelectionInitial ||
                 (modelState is ModelSelectionLoaded && modelState.selectedModelId == null)) {
        add(const SelectedModelChangedEvent(modelId: null));
      }
    });

    // Initial load based on current selection in ModelSelectionBloc
    // This ensures that if a model is already selected when PerformanceBloc is initialized,
    // its metrics are loaded.
    final initialSelectedModel = modelSelectionBloc.getSelectedModel();
    if (initialSelectedModel != null) {
      add(LoadPerformanceMetricsEvent(modelId: initialSelectedModel.id));
    }
  }

  Future<void> _onLoadPerformanceMetrics(
      LoadPerformanceMetricsEvent event, Emitter<PerformanceState> emit) async {
    if (event.modelId == null || event.modelId!.isEmpty) {
      emit(PerformanceInitial());
      return;
    }
    emit(PerformanceLoading(modelId: event.modelId));

    final currentModelInfo = modelSelectionBloc.getSelectedModel();
    final String modelName = currentModelInfo?.name ?? 'Unknown Model';


    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMapMethod<dynamic, dynamic>(
          'getPerformanceMetrics', {'modelId': event.modelId!});

      if (result != null) {
        final metrics = Map<String, dynamic>.from(result);
        emit(PerformanceLoaded(
          modelName: modelName, // Use name from ModelSelectionBloc's cache
          ttft: metrics['ttftMs'] as double? ?? 0.0,
          decodeSpeed: metrics['decodeSpeedTokensPerSec'] as double? ?? 0.0,
          latency: metrics['overallLatencyMs'] as double? ?? 0.0,
          additionalMetrics: Map<String, dynamic>.from(metrics)
            ..remove('ttftMs')
            ..remove('decodeSpeedTokensPerSec')
            ..remove('overallLatencyMs'),
        ));
      } else {
        emit(PerformanceError('Failed to get performance metrics: No data returned.'));
      }
    } on PlatformException catch (e) {
      emit(PerformanceError(
          'Platform Error loading performance: ${e.message} (Code: ${e.code})'));
    } catch (e) {
      emit(PerformanceError('Error loading performance metrics: ${e.toString()}'));
    }
  }

  void _onSelectedModelChanged(SelectedModelChangedEvent event, Emitter<PerformanceState> emit) {
    if (event.modelId == null || event.modelId!.isEmpty) {
      emit(PerformanceInitial());
    } else {
      add(LoadPerformanceMetricsEvent(modelId: event.modelId));
    }
  }

  @override
  Future<void> close() {
    _modelSelectionSubscription?.cancel();
    return super.close();
  }
}
