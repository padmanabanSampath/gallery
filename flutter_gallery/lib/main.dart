import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gallery/features/ask_image/presentation/screens/ask_image_screen.dart';
import 'package:flutter_gallery/features/prompt_lab/presentation/screens/prompt_lab_screen.dart';
import 'package:flutter_gallery/features/ai_chat/presentation/screens/ai_chat_screen.dart';
import 'package:flutter_gallery/features/model_selection/presentation/screens/model_selection_screen.dart';
import 'package:flutter_gallery/features/model_selection/presentation/bloc/model_selection_bloc.dart';
import 'package:flutter_gallery/features/performance_insights/presentation/bloc/performance_bloc.dart';
import 'package:flutter_gallery/features/byom/presentation/screens/byom_screen.dart';
import 'package:flutter_gallery/features/byom/presentation/bloc/byom_bloc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ModelSelectionBloc>(
          create: (context) => ModelSelectionBloc(),
        ),
        BlocProvider<PerformanceBloc>(
          create: (context) => PerformanceBloc(
            modelSelectionBloc: BlocProvider.of<ModelSelectionBloc>(context),
          ),
        ),
        BlocProvider<ByomBloc>( // Provide ByomBloc globally
          create: (context) => ByomBloc(),
        ),
      ],
      child: MaterialApp(
        title: 'Flutter GenAI Gallery',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.light,
          colorSchemeSeed: Colors.blueAccent, // Optional: to influence overall color scheme
        ),
        home: const MyHomePage(),
        routes: {
          '/ask_image': (context) => const AskImageScreen(),
          '/prompt_lab': (context) => const PromptLabScreen(),
          '/ai_chat': (context) => const AiChatScreen(),
          '/model_selection': (context) => const ModelSelectionScreen(),
          '/byom': (context) => const ByomScreen(), // Add route for ByomScreen
        },
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter GenAI Gallery'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding( // Add padding for the title
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Welcome to Flutter GenAI Gallery!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              _buildFeatureButton(
                context,
                title: 'Ask Image Feature',
                routeName: '/ask_image',
                icon: Icons.image_search_outlined,
              ),
              const SizedBox(height: 12),
              _buildFeatureButton(
                context,
                title: 'Prompt Lab Feature',
                routeName: '/prompt_lab',
                icon: Icons.science_outlined,
              ),
              const SizedBox(height: 12),
              _buildFeatureButton(
                context,
                title: 'AI Chat Feature',
                routeName: '/ai_chat',
                icon: Icons.chat_bubble_outline_rounded,
              ),
              const SizedBox(height: 12),
              _buildFeatureButton(
                context,
                title: 'Model Selection & Insights',
                routeName: '/model_selection',
                icon: Icons.model_training_outlined,
              ),
              const SizedBox(height: 12),
              _buildFeatureButton(
                context,
                title: 'Bring Your Own Model',
                routeName: '/byom',
                icon: Icons.upload_file_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureButton(BuildContext context, {required String title, required String routeName, required IconData icon}) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 22), // Adjusted icon size
      label: Text(title, textAlign: TextAlign.center), // Center text in button
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56), // Slightly taller buttons
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), // Adjusted padding
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      onPressed: () {
        Navigator.pushNamed(context, routeName);
      },
    );
  }
}
