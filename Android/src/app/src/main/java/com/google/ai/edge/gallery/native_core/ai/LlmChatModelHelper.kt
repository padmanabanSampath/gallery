package com.google.ai.edge.gallery.native_core.ai

import android.content.Context
import android.graphics.Bitmap // Added for image input
import android.util.Log
import com.google.ai.edge.gallery.native_core.data.Model
import com.google.ai.edge.gallery.native_core.data.LlmModelInstance
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import com.google.mediapipe.tasks.genai.llminference.LlmInference.LlmInferenceOptions
// import java.io.File // Not used directly here but often in full path management
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
// import kotlinx.coroutines.cancel // Not explicitly used, but good practice if jobs are managed more complexly
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext


typealias ResultListener = (partialResult: String, done: Boolean) -> Unit
typealias ErrorListener = (error: Throwable) -> Unit


object LlmChatModelHelper {
    private const val TAG = "LlmChatModelHelper_NativeCore"
    private var inferenceJob: Job? = null

    fun initialize(
        context: Context,
        model: Model,
        onDone: (String) -> Unit // Callback with error message, empty if success
    ) {
        if (model.instance != null && (model.instance as LlmModelInstance).instance is LlmInference) {
            Log.d(TAG, "Model ${model.name} already has an LlmInference instance. Assuming initialized.")
            onDone("")
            return
        }

        Log.d(TAG, "Initializing model: ${model.name} with path: ${model.path}")
        if (model.path == null) {
            Log.e(TAG, "Model path is null for ${model.name}. Cannot initialize.")
            onDone("Model path is null for ${model.name}")
            return
        }

        try {
            val options = LlmInferenceOptions.builder()
                .setModelPath(model.path)
                .setMaxTokens(1024)
                .build()

            val llmInference = LlmInference.createFromOptions(context, options)
            Log.d(TAG, "LlmInference created for ${model.name}")

            model.instance = LlmModelInstance(
                modelName = model.name, 
                instance = llmInference,
                capabilities = if (model.llmSupportImage) listOf("text", "image") else listOf("text")
            )
            Log.i(TAG, "Model ${model.name} initialized successfully.")
            onDone("") // Success
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing LlmInference for ${model.name}: ${e.message}", e)
            model.instance = null
            onDone("Failed to initialize model ${model.name}: ${e.localizedMessage}")
        }
    }
    
    fun resetSession(model: Model?) {
        val currentInstance = model?.instance as? LlmModelInstance
        val llmInference = currentInstance?.instance as? LlmInference
        if (llmInference != null) {
            try {
                // For MediaPipe LlmInference, generateResponse is stateless.
                // If the underlying SDK had a session, it would be reset here.
                Log.d(TAG, "Session reset for ${model.name} (conceptual, LlmInference is stateless for single queries).")
            } catch (e: Exception) {
                Log.e(TAG, "Error during (conceptual) session reset for ${model.name}: ${e.message}", e)
            }
        } else {
            Log.w(TAG, "Cannot reset session: Model ${model?.name} or its LlmInference instance is null.")
        }
    }

    fun runInference(
        model: Model,
        input: String,
        image: Bitmap? = null, // Added Bitmap parameter, optional
        resultListener: ResultListener,
        errorListener: ErrorListener
    ) {
        inferenceJob?.cancel() 
        inferenceJob = CoroutineScope(Dispatchers.IO).launch {
            val llmModelInstance = model.instance as? LlmModelInstance
            val llmInference = llmModelInstance?.instance as? LlmInference

            if (llmInference == null) {
                Log.e(TAG, "LlmInference instance is null for model ${model.name}. Cannot run inference.")
                withContext(Dispatchers.Main) {
                    errorListener(IllegalStateException("Model ${model.name} not initialized or instance is not LlmInference."))
                }
                return@launch
            }

            try {
                Log.d(TAG, "Running inference for model ${model.name}. Input: $input. Image provided: ${image != null}")
                
                val fullResponse: String = if (image != null) {
                    // Check if model actually supports images based on its own properties
                    if (!model.llmSupportImage) {
                         throw IllegalArgumentException("Model ${model.name} was called with an image but does not support image input.")
                    }
                    llmInference.generateResponse(input, image)
                } else {
                    llmInference.generateResponse(input)
                }
                Log.d(TAG, "Full response received from LlmInference for ${model.name}")

                withContext(Dispatchers.Main) {
                    resultListener(fullResponse, true) // Single chunk, done = true
                }

            } catch (e: Exception) {
                Log.e(TAG, "Error during inference for ${model.name}: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    errorListener(e)
                }
            }
        }
    }

    fun sizeInTokens(model: Model, text: String): Int {
        val llmModelInstance = model.instance as? LlmModelInstance
        val llmInference = llmModelInstance?.instance as? LlmInference
        return if (llmInference != null) {
            try {
                llmInference.sizeInTokens(text)
            } catch (e: Exception) {
                Log.e(TAG, "Error getting sizeInTokens for model ${model.name}: ${e.message}", e)
                0 
            }
        } else {
            Log.w(TAG, "Cannot get sizeInTokens: Model ${model.name} or LlmInference instance is null.")
            0 
        }
    }

    fun cleanUp(model: Model?) {
        inferenceJob?.cancel() 
        inferenceJob = null
        if (model?.instance != null) {
            val llmModelInstance = model.instance as? LlmModelInstance
            val llmInference = llmModelInstance?.instance as? LlmInference
            try {
                llmInference?.close()
                Log.d(TAG, "Cleaned up model: ${model.name}")
            } catch (e: Exception) {
                Log.e(TAG, "Error cleaning up model ${model.name}: ${e.message}", e)
            }
            model.instance = null
        }
    }

    fun isModelInitialized(model: Model?): Boolean {
        return model?.instance != null && (model.instance as? LlmModelInstance)?.instance is LlmInference
    }
}
