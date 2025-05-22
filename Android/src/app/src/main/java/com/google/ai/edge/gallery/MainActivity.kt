package com.google.ai.edge.gallery

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.google.ai.edge.gallery.native_core.NativeAiHub
import com.google.ai.edge.gallery.native_core.DataStoreRepository

class MainActivity : FlutterActivity() {
    private val MODEL_MANAGEMENT_CHANNEL = "com.google.ai.edge.gallery/model_management"
    private val PERFORMANCE_CHANNEL = "com.google.ai.edge.gallery/performance"
    private val ASK_IMAGE_CHANNEL = "com.google.ai.edge.gallery/ask_image"
    private val PROMPT_LAB_CHANNEL = "com.google.ai.edge.gallery/prompt_lab"
    private val AI_CHAT_CHANNEL = "com.google.ai.edge.gallery/ai_chat"

    private lateinit var nativeAiHub: NativeAiHub

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val dataStoreRepository = DataStoreRepository(applicationContext)
        nativeAiHub = NativeAiHub(applicationContext, dataStoreRepository)

        // Model Management Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MODEL_MANAGEMENT_CHANNEL).setMethodCallHandler { call, result ->
            handleModelManagementCalls(call, result)
        }

        // Performance Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERFORMANCE_CHANNEL).setMethodCallHandler { call, result ->
            handlePerformanceCalls(call, result)
        }
        
        // Ask Image Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ASK_IMAGE_CHANNEL).setMethodCallHandler { call, result ->
            handleAskImageCalls(call, result)
        }

        // Prompt Lab Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PROMPT_LAB_CHANNEL).setMethodCallHandler { call, result ->
            handlePromptLabCalls(call, result)
        }

        // AI Chat Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AI_CHAT_CHANNEL).setMethodCallHandler { call, result ->
            handleAiChatCalls(call, result)
        }
    }

    private fun handleModelManagementCalls(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getAvailableModels" -> nativeAiHub.getAvailableModels(result)
            "addCustomModel" -> {
                val name = call.argument<String>("name")
                val path = call.argument<String>("path")
                if (name != null && path != null) {
                    nativeAiHub.addCustomModel(name, path, result)
                } else {
                    result.error("INVALID_ARGUMENT", "name or path is null for addCustomModel", null)
                }
            }
            "notifyModelSelected" -> {
                 val modelId = call.argument<String>("modelId")
                 nativeAiHub.notifyModelSelected(modelId, result) // modelId can be null if selection is cleared
            }
            else -> result.notImplemented()
        }
    }

    private fun handlePerformanceCalls(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPerformanceMetrics" -> {
                val modelId = call.argument<String>("modelId")
                if (modelId != null) {
                    nativeAiHub.getPerformanceMetrics(modelId, result)
                } else {
                    result.error("INVALID_ARGUMENT", "modelId cannot be null for getPerformanceMetrics", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun handleAskImageCalls(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "processImageQuery" -> {
                val imagePath = call.argument<String>("imagePath")
                val question = call.argument<String>("question")
                val modelId = call.argument<String>("modelId")
                if (imagePath != null && question != null && modelId != null) {
                    nativeAiHub.processImageQuery(imagePath, question, modelId, result)
                } else {
                    result.error("INVALID_ARGUMENT", "imagePath, question, or modelId is null for processImageQuery", null)
                }
            }
            else -> result.notImplemented()
        }
    }

     private fun handlePromptLabCalls(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "processPrompt" -> {
                val prompt = call.argument<String>("prompt")
                val taskType = call.argument<String>("taskType")
                val modelId = call.argument<String>("modelId") // Optional
                 if (prompt != null && taskType != null) {
                    nativeAiHub.processPrompt(prompt, taskType, modelId, result)
                } else {
                    result.error("INVALID_ARGUMENT", "prompt or taskType is null for processPrompt", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun handleAiChatCalls(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getNextChatResponse" -> {
                val message = call.argument<String>("message")
                val history = call.argument<List<Map<String, String>>>("history")
                val modelId = call.argument<String>("modelId") // Optional
                if (message != null && history != null) {
                    nativeAiHub.getNextChatResponse(message, history, modelId, result)
                } else {
                    result.error("INVALID_ARGUMENT", "message or history is null for getNextChatResponse", null)
                }
            }
            else -> result.notImplemented()
        }
    }
}
