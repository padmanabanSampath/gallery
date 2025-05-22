import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gallery/features/performance_insights/presentation/bloc/performance_bloc.dart';

class PerformanceDisplayWidget extends StatelessWidget {
  final String? modelId; // To potentially fetch performance for a specific model

  const PerformanceDisplayWidget({super.key, this.modelId});

  @override
  Widget build(BuildContext context) {
    // If modelId is provided, dispatch an event to load performance for that model
    if (modelId != null && modelId!.isNotEmpty) {
      // Ensure PerformanceBloc is available in the context.
      // This might mean PerformanceBloc needs to be provided higher up if this widget
      // is used in multiple places without a local BlocProvider.
      // For now, assuming it's provided or we create it here if it's self-contained.
      // Let's make it self-contained for simplicity in this example,
      // but in a real app, it might share data or be influenced by ModelSelectionBloc.
      
      // context.read<PerformanceBloc>().add(LoadPerformanceMetricsEvent(modelId!));
      // For this example, we'll have PerformanceBloc provided where this widget is used.
      // Or, for a quick test, we can provide it here temporarily, but that's not ideal.
    }


    return BlocBuilder<PerformanceBloc, PerformanceState>(
      builder: (context, state) {
        if (state is PerformanceLoading) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        if (state is PerformanceError) {
           return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: Text('Error loading performance: ${state.message}', style: TextStyle(color: Colors.red.shade700))),
          );
        }
        if (state is PerformanceLoaded) {
          return Card(
            margin: const EdgeInsets.all(8.0),
            elevation: 2.0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min, // So it doesn't take full screen height if embedded
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Performance Insights${modelId != null && modelId!.isNotEmpty ? " for ${state.modelName}" : ""}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12.0),
                  _buildMetricRow(context, 'Time To First Token (TTFT):', '${state.ttft.toStringAsFixed(2)} ms', Icons.timer_outlined),
                  const Divider(),
                  _buildMetricRow(context, 'Decode Speed:', '${state.decodeSpeed.toStringAsFixed(1)} tokens/sec', Icons.speed_outlined),
                  const Divider(),
                  _buildMetricRow(context, 'Total Latency:', '${state.latency.toStringAsFixed(2)} ms', Icons.network_check_outlined),
                  if (state.additionalMetrics.isNotEmpty) ...[
                    const Divider(),
                    ...state.additionalMetrics.entries.map((entry) =>
                      _buildMetricRow(context, '${entry.key}:', entry.value.toString(), Icons.info_outline)
                    ).toList()
                  ]
                ],
              ),
            ),
          );
        }
        // Initial state or if no model is selected to show insights for.
        return Card( // Ensure this also has some constraints or defined behavior for small screens
            margin: const EdgeInsets.all(8.0),
            elevation: 1.0,
            child: Container( // Use container to control height if needed
              padding: const EdgeInsets.all(16.0),
              constraints: const BoxConstraints(minHeight: 100), // Ensure it's not too small
              child: Center(
                child: Text(
                  'Performance insights will appear here.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
      },
    );
  }

  Widget _buildMetricRow(BuildContext context, String label, String value, IconData icon) {
    // Using LayoutBuilder to make text size potentially responsive or wrap better.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Increased padding slightly
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align items to the start for wrapped text
        children: <Widget>[
          Icon(icon, size: 22.0, color: Theme.of(context).primaryColorDark), // Slightly larger icon
          const SizedBox(width: 12.0),
          Expanded( // Allow label to take space and wrap
            flex: 2, // Give more space to label
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey[800]),
              softWrap: true,
            ),
          ),
          const SizedBox(width: 8.0), // Spacing between label and value
          Expanded( // Allow value to take space and wrap, align to right
            flex: 3, // Give more space to value
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right, // Align value to the right
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}
