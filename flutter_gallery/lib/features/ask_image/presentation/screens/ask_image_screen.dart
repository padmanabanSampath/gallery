import 'dart:io'; // Required for File type
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart'; // Required for XFile
import '../bloc/ask_image_bloc.dart';

class AskImageScreen extends StatefulWidget {
  const AskImageScreen({super.key});

  @override
  State<AskImageScreen> createState() => _AskImageScreenState();
}

class _AskImageScreenState extends State<AskImageScreen> {
  final TextEditingController _questionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // Access ModelSelectionBloc from the context (it's provided globally in main.dart)
    final modelSelectionBloc = BlocProvider.of<ModelSelectionBloc>(context);

    return BlocProvider(
      create: (context) => AskImageBloc(modelSelectionBloc: modelSelectionBloc),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ask Image'),
          actions: [
            // Moved clear button to AppBar for better UX
            BlocBuilder<AskImageBloc, AskImageState>(
              builder: (context, state) {
                if (state is AskImageLoaded && (state.image != null || state.answer != null || state.question != null)) {
                  return IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear Image & Answer',
                    onPressed: () {
                      _questionController.clear();
                      context.read<AskImageBloc>().add(ClearImageAndAnswerEvent());
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: BlocConsumer<AskImageBloc, AskImageState>(
          listener: (context, state) {
            if (state is AskImageError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${state.message}')),
              );
            }
            if (state is AskImageLoaded) {
              // If a question was asked and an answer is received,
              // we might want to keep the question in the text field
              // or clear it, depending on desired UX.
              // For now, let's keep it.
              // if (state.question != null && _questionController.text.isEmpty) {
              //   _questionController.text = state.question!;
              // }
            }
          },
          builder: (context, state) {
            XFile? selectedImage;
            String? answer;
            String? question;

            if (state is AskImageLoaded) {
              selectedImage = state.image;
              answer = state.answer;
              question = state.question;
            } else if (state is AskImageLoading && context.read<AskImageBloc>().state is AskImageLoaded) {
              // If loading, but previous state was AskImageLoaded, retain image and question
              final prevState = context.read<AskImageBloc>().state as AskImageLoaded;
              selectedImage = prevState.image;
              question = prevState.question;
            }


            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Image display area - Make height responsive
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Adjust height based on screen width, but with min/max
                        double idealHeight = constraints.maxWidth * 0.5; // e.g., 1:2 aspect ratio
                        double imageHeight = idealHeight.clamp(150.0, 300.0); // Min 150, Max 300
                        if (MediaQuery.of(context).orientation == Orientation.landscape) {
                          imageHeight = (MediaQuery.of(context).size.height * 0.3).clamp(100.0, 200.0) ; // Smaller height in landscape
                        }
                        return Container(
                          height: imageHeight,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(11), // slightly less than container to avoid overflow
                              child: Image.file(
                                File(selectedImage.path),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(child: Text('Error loading image'));
                                },
                              ),
                            )
                          : const Center(child: Text('No image selected.')),
                    ),
                    const SizedBox(height: 16),

                    // Pick Image Button
                    ElevatedButton.icon(
                      icon: const Icon(Icons.image_search),
                      label: const Text('Pick Image from Gallery'),
                      onPressed: state is AskImageLoading
                          ? null // Disable button when loading
                          : () {
                              context.read<AskImageBloc>().add(PickImageEvent());
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Question Text Input
                    TextField(
                      controller: _questionController,
                      decoration: InputDecoration(
                        hintText: 'Ask a question about the image...',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _questionController.clear(),
                        )
                      ),
                      enabled: selectedImage != null && !(state is AskImageLoading),
                      onSubmitted: (_) {
                        if (_questionController.text.isNotEmpty && selectedImage != null) {
                          context.read<AskImageBloc>().add(AskQuestionEvent(_questionController.text));
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Ask Question Button
                    ElevatedButton.icon(
                      icon: const Icon(Icons.question_answer_outlined),
                      label: const Text('Ask Question'),
                      onPressed: selectedImage == null || _questionController.text.isEmpty || state is AskImageLoading
                          ? null // Disable if no image, no question, or loading
                          : () {
                              context.read<AskImageBloc>().add(AskQuestionEvent(_questionController.text));
                            },
                       style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Loading Indicator
                    if (state is AskImageLoading)
                      const Center(child: CircularProgressIndicator()),

                    // Answer Display Area
                    if (answer != null)
                      Card(
                        elevation: 1,
                        color: Colors.blue[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.blue.shade200)
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (question != null) ...[
                                 SelectableText(
                                  'Q: $question',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                              ],
                              SelectableText(
                                'A: $answer',
                                style: const TextStyle(fontSize: 16),
                              ),
                              if (state is AskImageLoaded && state.latencyMs != null && state.latencyMs! > 0) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Latency: ${state.latencyMs!.toStringAsFixed(0)} ms',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                )
                              ]
                            ],
                          ),
                            ),
                          ],
                        ),
                      )
                    else if (state is! AskImageLoading && question != null && selectedImage != null)
                       Padding(
                         padding: const EdgeInsets.symmetric(vertical: 8.0),
                         child: Center(child: Text('Ask a question to get an answer.', style: TextStyle(color: Colors.grey[600]))),
                       ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }
}
