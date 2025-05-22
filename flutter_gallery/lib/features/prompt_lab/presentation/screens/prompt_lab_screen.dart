import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/prompt_lab_bloc.dart';

class PromptLabScreen extends StatefulWidget {
  const PromptLabScreen({super.key});

  @override
  State<PromptLabScreen> createState() => _PromptLabScreenState();
}

class _PromptLabScreenState extends State<PromptLabScreen> {
  final TextEditingController _promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Optional: Initialize controller if needed from BLoC state,
    // but typically BLoC builder handles initial state rendering.
  }

  @override
  Widget build(BuildContext context) {
    // Access ModelSelectionBloc from the context (it's provided globally in main.dart)
    final modelSelectionBloc = BlocProvider.of<ModelSelectionBloc>(context);

    return BlocProvider(
      create: (context) => PromptLabBloc(modelSelectionBloc: modelSelectionBloc),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Prompt Lab'),
          actions: [
            BlocBuilder<PromptLabBloc, PromptLabState>(
              builder: (context, state) {
                // Show clear button only if there's something to clear
                bool canClear = false;
                if (state is PromptLabInitial && (state.prompt.isNotEmpty)) {
                  canClear = true;
                } else if (state is PromptLabResponseReceived && (state.prompt.isNotEmpty || state.response.isNotEmpty)) {
                  canClear = true;
                } else if (state is PromptLabError && (state.prompt.isNotEmpty)) {
                  canClear = true;
                }

                if (canClear) {
                  return IconButton(
                    icon: const Icon(Icons.clear_all),
                    tooltip: 'Clear All',
                    onPressed: () {
                      _promptController.clear();
                      context.read<PromptLabBloc>().add(ClearPromptLabEvent());
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: BlocConsumer<PromptLabBloc, PromptLabState>(
          listener: (context, state) {
            if (state is PromptLabError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Error: ${state.message}'),
                    backgroundColor: Colors.redAccent),
              );
            }
            // Update text controller if BLoC state's prompt changes externally
            // (e.g. after clearing or loading state)
            if (_promptController.text != _getCurrentPrompt(state)) {
                 _promptController.text = _getCurrentPrompt(state);
            }
          },
          builder: (context, state) {
            String currentPrompt = _getCurrentPrompt(state);
            String currentTaskType = _getCurrentTaskType(state);
            String? response;
            bool isLoading = state is PromptLabLoading;

            if (state is PromptLabResponseReceived) {
              response = state.response;
            }

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Task Type Selector
                    Card(
                      elevation: 2.0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Select Task Type',
                            border: InputBorder.none, // Remove border from form field itself
                          ),
                          value: currentTaskType,
                          isExpanded: true,
                          items: PromptLabBloc.taskTypes
                              .map((String value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  ))
                              .toList(),
                          onChanged: isLoading
                              ? null
                              : (String? newValue) {
                                  if (newValue != null) {
                                    context
                                        .read<PromptLabBloc>()
                                        .add(TaskTypeChangedEvent(newValue));
                                  }
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Prompt Input Field
                    TextField(
                      controller: _promptController,
                      decoration: InputDecoration(
                        labelText: 'Enter your prompt',
                        hintText: 'e.g., "Summarize the following text..."',
                        border: const OutlineInputBorder(),
                        suffixIcon: _promptController.text.isEmpty ? null : IconButton( // Show clear only if text is present
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                             _promptController.clear();
                             context.read<PromptLabBloc>().add(const PromptChangedEvent(''));
                          }
                        )
                      ),
                      maxLines: null, // Allow it to expand vertically as needed
                      minLines: 2, // Start with a smaller minimum
                      keyboardType: TextInputType.multiline, // Ensure multiline keyboard
                      enabled: !isLoading,
                      onChanged: (text) {
                        // Update suffix icon visibility based on text
                        setState(() {});
                        context.read<PromptLabBloc>().add(PromptChangedEvent(text));
                      },
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 16),

                    // Execute Prompt Button
                    ElevatedButton.icon(
                      icon: isLoading
                          ? Container(
                              width: 24,
                              height: 24,
                              padding: const EdgeInsets.all(2.0),
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Icon(Icons.play_arrow_outlined),
                      label: Text(isLoading ? 'Processing...' : 'Execute Prompt'),
                      onPressed: currentPrompt.isEmpty || isLoading
                          ? null
                          : () {
                              context.read<PromptLabBloc>().add(ExecutePromptEvent());
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Response Area
                    if (response != null)
                      ConstrainedBox( // Ensure the card doesn't become excessively tall
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.4, // Max 40% of screen height
                        ),
                        child: Card(
                          elevation: 2.0,
                          color: Colors.blueGrey[50],
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SingleChildScrollView( // Make response scrollable if it's long
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Response:',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    response,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                              if (state is PromptLabResponseReceived && state.latencyMs != null && state.latencyMs! > 0) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Latency: ${state.latencyMs!.toStringAsFixed(0)} ms',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                )
                              ]
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (isLoading)
                        const Center(child: Text("Waiting for response..."))
                    else if (state is PromptLabInitial && currentPrompt.isNotEmpty)
                         Center(child: Text("Press 'Execute Prompt' to get a response.", style: TextStyle(color: Colors.grey[600])))
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _getCurrentPrompt(PromptLabState state) {
    if (state is PromptLabInitial) return state.prompt;
    if (state is PromptLabLoading) return state.prompt;
    if (state is PromptLabResponseReceived) return state.prompt;
    if (state is PromptLabError) return state.prompt;
    return '';
  }

  String _getCurrentTaskType(PromptLabState state) {
    if (state is PromptLabInitial) return state.taskType;
    if (state is PromptLabLoading) return state.taskType;
    if (state is PromptLabResponseReceived) return state.taskType;
    if (state is PromptLabError) return state.taskType;
    return PromptLabBloc.taskTypes.first;
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }
}
