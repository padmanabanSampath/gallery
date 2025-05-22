import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gallery/features/model_selection/presentation/bloc/model_selection_bloc.dart';
import 'package:flutter_gallery/features/model_selection/domain/entities/model_info.dart';
import 'package:flutter_gallery/features/performance_insights/presentation/widgets/performance_display_widget.dart';
import 'package:flutter_gallery/features/performance_insights/presentation/bloc/performance_bloc.dart';


class ModelSelectionScreen extends StatelessWidget {
  const ModelSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dispatch LoadModelsEvent when the screen is built.
    // ModelSelectionBloc is already provided by MultiBlocProvider in main.dart
    context.read<ModelSelectionBloc>().add(LoadModelsEvent());

    // PerformanceBloc is also provided by MultiBlocProvider and it listens to ModelSelectionBloc.
    // So, we don't need to explicitly pass modelId to PerformanceDisplayWidget here
    // if PerformanceBloc correctly updates based on ModelSelectionBloc's state.

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Model & View Insights'),
      ),
      body: Column( // Use Column to layout ListView and PerformanceDisplayWidget
        children: [
          Expanded( // Model selection list takes available space
            child: BlocConsumer<ModelSelectionBloc, ModelSelectionState>(
              listener: (context, state) {
                if (state is ModelSelectionError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error: ${state.message}'),
                        backgroundColor: Colors.redAccent),
                  );
                }
                if (state is ModelSelectionLoaded && state.selectedModelId != null) {
                   final selectedModel = state.models.firstWhere((m) => m.id == state.selectedModelId, orElse: () => state.models.first);
                   ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Remove previous selection snackbar
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('${selectedModel.name} selected.'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: Theme.of(context).primaryColorDark),
                  );
                }
              },
              builder: (context, state) {
                if (state is ModelSelectionLoading || state is ModelSelectionInitial) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is ModelSelectionLoaded) {
                  if (state.models.isEmpty) {
                    return const Center(child: Text('No models available.'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: state.models.length,
                    itemBuilder: (context, index) {
                      final model = state.models[index];
                      return Card(
                        elevation: model.isSelected ? 5.0 : 2.0,
                        shadowColor: model.isSelected ? Theme.of(context).primaryColor.withAlpha(100) : null,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: model.isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade300,
                            width: model.isSelected ? 2.2 : 1.0,
                          ),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: ListTile(
                          title: Text(model.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5.0),
                            child: Text(model.description, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                          ),
                          trailing: model.isSelected
                              ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor, size: 28)
                              : const Icon(Icons.radio_button_unchecked, size: 28),
                          onTap: () {
                            context
                                .read<ModelSelectionBloc>()
                                .add(SelectModelEvent(model.id));
                          },
                          contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                        ),
                      );
                    },
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                  );
                }
                return const Center(child: Text('Something went wrong.')); // Fallback
              },
            ),
          ),
          // Performance Insights Widget at the bottom
          const PerformanceDisplayWidget(), // PerformanceBloc is already provided
        ],
      ),
    );
  }
}
