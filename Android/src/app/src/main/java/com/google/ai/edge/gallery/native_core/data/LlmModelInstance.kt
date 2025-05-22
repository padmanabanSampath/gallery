package com.google.ai.edge.gallery.native_core.data

// This class will hold the actual initialized model instance.
// The exact type of 'instance' will depend on the specific AI SDK being used.
// For MediaPipe GenAI, it might be 'TextGenerator', 'ImageGenerator', etc.
// For this placeholder, 'Any' is used.
data class LlmModelInstance(
    val modelName: String, // To identify which model this instance belongs to
    val instance: Any,     // The actual native model object
    // Add any other relevant properties, e.g., capabilities, session IDs, etc.
    val capabilities: List<String> = emptyList()
) {
    // Optional: Add methods to interact with the instance if it's a common interface,
    // or cast 'instance' to its specific type where used.
}
