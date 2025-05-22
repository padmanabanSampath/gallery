import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gallery/features/byom/presentation/bloc/byom_bloc.dart';
import 'package:flutter_gallery/features/byom/domain/entities/custom_model.dart';
// For a real file picker, you would add a dependency like 'file_picker'
// import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart'; // For date formatting

class ByomScreen extends StatefulWidget {
  const ByomScreen({super.key});

  @override
  State<ByomScreen> createState() => _ByomScreenState();
}

class _ByomScreenState extends State<ByomScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load existing custom models when the screen is initialized
    context.read<ByomBloc>().add(LoadCustomModelsEvent());

    // Listen to BLoC state to update text controllers if needed
    // (e.g. after a successful add, form fields are cleared in BLoC)
    context.read<ByomBloc>().stream.listen((state) {
      if (state is ByomFormState || state is ByomInitial) {
        final currentName = state is ByomFormState ? state.currentName : (state as ByomInitial).currentName;
        final currentPath = state is ByomFormState ? state.currentPath : (state as ByomInitial).currentPath;
        if (_nameController.text != currentName) {
          _nameController.text = currentName;
        }
        if (_pathController.text != currentPath) {
          _pathController.text = currentPath;
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    // Placeholder for file picker logic
    // In a real app, use file_picker plugin:
    /*
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['task', 'tflite'], // Example file types
    );

    if (result != null) {
      context.read<ByomBloc>().add(ByomFormChangedEvent(path: result.files.single.path));
    } else {
      // User canceled the picker
    }
    */
    // For now, simulate picking a file by setting a dummy path
    // And show a snackbar to indicate this is a placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File picker is not implemented. Please enter path manually.'),
        duration: Duration(seconds: 2),
      ),
    );
    // You could set a dummy path for testing if you want:
    // context.read<ByomBloc>().add(const ByomFormChangedEvent(path: '/path/to/dummy/model.task'));
  }

  void _addModel() {
    if (_formKey.currentState!.validate()) {
      context.read<ByomBloc>().add(AddCustomModelEvent(
            name: _nameController.text,
            path: _pathController.text,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bring Your Own Model'),
      ),
      body: BlocConsumer<ByomBloc, ByomState>(
        listener: (context, state) {
          if (state is ByomError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Error: ${state.message}'),
                  backgroundColor: Colors.redAccent),
            );
          } else if (state is ByomSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green),
            );
            // _nameController.clear(); // Handled by BLoC state update now
            // _pathController.clear();
          }
        },
        builder: (context, state) {
          List<CustomModel> models = [];
          bool isLoading = false;

          if (state is ByomInitial) models = state.models;
          if (state is ByomLoading) {
            models = state.models;
            isLoading = true;
          }
          if (state is ByomFormState) models = state.models;
          if (state is ByomSuccess) models = state.models;
          if (state is ByomError) models = state.models;


          // Wrap the main content in a SingleChildScrollView for responsiveness
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Form for adding a new model
                Form(
                  key: _formKey,
                  child: Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text("Add New Model", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)), // Slightly adjust font size
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Model Name',
                              hintText: 'e.g., My Custom Model',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a model name';
                              }
                              return null;
                            },
                            onChanged: (value) => context.read<ByomBloc>().add(ByomFormChangedEvent(name: value)),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _pathController,
                            decoration: InputDecoration(
                              labelText: 'Model Path/URL',
                              hintText: 'e.g., /path/to/your/model.task or https://...',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.folder_open),
                                tooltip: 'Pick model file (Not implemented)',
                                onPressed: _pickFile,
                              )
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter the model path or URL';
                              }
                              // Basic path validation (can be more sophisticated)
                              if (!value.contains('/') && !value.contains(r'\')) {
                                 // return 'Please enter a valid path or URL';
                              }
                              return null;
                            },
                            onChanged: (value) => context.read<ByomBloc>().add(ByomFormChangedEvent(path: value)),
                          ),
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              icon: isLoading && (state is ByomLoading && state.currentName == _nameController.text) // Show loader only if this add is loading
                                  ? Container(
                                      width: 24,
                                      height: 24,
                                      padding: const EdgeInsets.all(2.0),
                                      child: const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : const Icon(Icons.add_circle_outline),
                              label: Text(isLoading && (state is ByomLoading && state.currentName == _nameController.text) ? 'Adding...' : 'Add Model'),
                              onPressed: isLoading ? null : _addModel,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // List of added models
                Text("Your Custom Models", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
                const SizedBox(height: 8),
                // The ListView.builder needs a constrained height when inside a SingleChildScrollView and Column.
                // Using shrinkWrap and physics or giving it a fixed/calculated height.
                // For simplicity, if the list is expected to be short, shrinkWrap is okay.
                // For potentially long lists, a fixed height or more complex layout is needed.
                // Given it's inside a SingleChildScrollView, shrinkWrap is appropriate here.
                models.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Center(
                            child: Text(
                          'No custom models added yet.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                        )),
                      )
                    : ListView.builder(
                        shrinkWrap: true, // Important for ListView inside SingleChildScrollView
                        physics: const NeverScrollableScrollPhysics(), // Disable ListView's own scrolling
                        itemCount: models.length,
                        itemBuilder: (context, index) {
                          final model = models[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6.0),
                            child: ListTile(
                              leading: const Icon(Icons.model_training_outlined, color: Colors.blueAccent, size: 36), // Larger icon
                              title: Text(model.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                              subtitle: Text(
                                'Path: ${model.path}\nAdded: ${DateFormat.yMMMd().add_jm().format(model.dateAdded)}',
                                style: TextStyle(color: Colors.grey[700], fontSize: 13),
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
                                tooltip: 'Remove Model',
                                onPressed: () {
                                  // Confirmation Dialog
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext dialogContext) {
                                      return AlertDialog(
                                        title: const Text('Confirm Removal'),
                                        content: Text('Are you sure you want to remove the model "${model.name}"?'),
                                        actions: <Widget>[
                                          TextButton(
                                            child: const Text('Cancel'),
                                            onPressed: () => Navigator.of(dialogContext).pop(),
                                          ),
                                          TextButton(
                                            child: const Text('Remove', style: TextStyle(color: Colors.red)),
                                            onPressed: () {
                                              context.read<ByomBloc>().add(RemoveCustomModelEvent(model.id));
                                              Navigator.of(dialogContext).pop();
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
