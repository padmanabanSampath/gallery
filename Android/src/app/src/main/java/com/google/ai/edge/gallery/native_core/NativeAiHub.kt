package com.google.ai.edge.gallery.native_core

import android.content.Context
import android.graphics.BitmapFactory 
import io.flutter.plugin.common.MethodChannel
import com.google.ai.edge.gallery.native_core.data.ModelAllowlist
import com.google.ai.edge.gallery.native_core.data.ImportedModelInfo
import com.google.ai.edge.gallery.native_core.data.Model
import com.google.ai.edge.gallery.native_core.data.LlmModelInstance
import com.google.ai.edge.gallery.native_core.data.ConfigKey
import com.google.ai.edge.gallery.native_core.data.Accelerator
import com.google.ai.edge.gallery.native_core.data.createLlmChatConfigs // Import the helper
import com.google.ai.edge.gallery.native_core.ai.LlmChatModelHelper
import kotlinx.serialization.json.Json
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.net.URL
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.Job
import kotlinx.coroutines.CompletableDeferred
import android.util.Log

class PlaceholderDataStoreRepository(private val context: Context) {
    private val _importedModels = mutableListOf<ImportedModelInfo>()

    init {
        _importedModels.addAll(
            listOf(
                ImportedModelInfo(
                    id = "custom_model_id_1_repo",
                    fileName = "My Custom Text Model (Imported)", 
                    path = "/data/user/0/com.google.aiedge.gallery/files/my_custom_model.tflite", 
                    fileSize = 12345678L,
                    dateAdded = System.currentTimeMillis() - 100000000,
                    description = "A user-added text generation model from placeholder.",
                    defaultValues = mapOf(
                        ConfigKey.COMPATIBLE_ACCELERATORS.label to "CPU,GPU",
                        ConfigKey.DEFAULT_MAX_TOKENS.label to "2048",
                        ConfigKey.DEFAULT_TOPK.label to "30",
                        ConfigKey.DEFAULT_TOPP.label to "0.95",
                        ConfigKey.DEFAULT_TEMPERATURE.label to "0.75",
                        ConfigKey.SUPPORT_IMAGE.label to "false"
                    ),
                    isNativeConfirmed = true 
                )
            )
        )
    }

    suspend fun readImportedModels(): List<ImportedModelInfo> {
        Log.d(NativeAiHub.TAG, "PlaceholderDataStoreRepository: Reading ${_importedModels.size} imported models.")
        return _importedModels.toList()
    }

    suspend fun saveImportedModels(models: List<ImportedModelInfo>) {
        Log.d(NativeAiHub.TAG, "PlaceholderDataStoreRepository: Saving ${models.size} imported models.")
        _importedModels.clear()
        _importedModels.addAll(models)
    }

     fun isModelAllowlisted(modelId: String): Boolean { 
        Log.d(NativeAiHub.TAG, "PlaceholderDataStoreRepository: Checking allowlist for $modelId")
        val currentInstance = NativeAiHub.INSTANCE 
        val knownIds = currentInstance?.getModelsInternal()?.map { it.name }?.toSet() ?: emptySet() +
                       setOf("model_001_native", "model_002_native", "gemini_pro_native", "gemini_nano_native") 
        return knownIds.contains(modelId) || modelId.startsWith("custom_native_")
    }
}


class NativeAiHub private constructor(
    private val context: Context,
    private val dataStoreRepository: PlaceholderDataStoreRepository
) {
    private val json = Json {
        ignoreUnknownKeys = true
        allowComments = true
        allowTrailingComma = true
        isLenient = true
    }

    private val coroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var loadModelsJob: Job? = null

    private var internalModelsList: List<Model> = emptyList()
    private var selectedModelInstance: LlmModelInstance? = null
    private var currentSelectedModel: Model? = null


    companion object {
        internal const val TAG = "NativeAiHub"
        private const val MODEL_ALLOWLIST_URL = "https://storage.googleapis.com/download.tensorflow.org/models/tflite/flutter_apps/gallery/model_allowlist.json"
        private const val MODEL_ALLOWLIST_FILENAME = "model_allowlist.json"
        private const val ASSET_MODEL_ALLOWLIST_PATH = "model_allowlist.json"

        @Volatile
        internal var INSTANCE: NativeAiHub? = null 

        fun getInstance(context: Context): NativeAiHub {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: NativeAiHub(
                    context.applicationContext, 
                    PlaceholderDataStoreRepository(context.applicationContext)
                ).also { INSTANCE = it; it.loadInitialModels() } 
            }
        }
    }
    
    private fun loadInitialModels() {
        if (loadModelsJob?.isActive == true) {
            Log.d(TAG, "Model loading already in progress.")
            return
        }
        Log.d(TAG, "Starting initial model load...")
        loadModelsJob = coroutineScope.launch { // This is the job
            try {
                val allowlist = fetchAndParseAllowlist()
                val allowlistModels: List<Model> = allowlist.models.map { it.toModel() }
                Log.d(TAG, "Loaded ${allowlistModels.size} models from allowlist.")

                val importedModelInfos = dataStoreRepository.readImportedModels()
                val importedModels: List<Model> = importedModelInfos.map { modelFromImportedInfo(it, context) }
                Log.d(TAG, "Loaded ${importedModels.size} imported models.")
                
                internalModelsList = (allowlistModels + importedModels).distinctBy { it.name }
                Log.i(TAG, "Initial models loaded. Total unique models: ${internalModelsList.size}")

                if (currentSelectedModel == null && internalModelsList.isNotEmpty()) {
                    var defaultModel = internalModelsList.firstOrNull { 
                        it.allowlisted && it.path != null && (it.path!!.startsWith("/") && File(it.path!!).exists() || it.path!!.startsWith("http")) && it.llmSupportText
                    }
                    if (defaultModel == null) {
                        defaultModel = internalModelsList.firstOrNull { it.path != null && (it.path!!.startsWith("/") && File(it.path!!).exists() || it.path!!.startsWith("http")) && it.llmSupportText }
                    }

                    if (defaultModel != null) {
                        Log.d(TAG, "Attempting to pre-select and initialize default text model: ${defaultModel.name}")
                        // Call notifyModelSelectedInternal with isPreselection = true
                        val success = notifyModelSelectedInternal(defaultModel.name, isPreselection = true)
                        if (success) {
                            Log.i(TAG, "Default text model ${defaultModel.name} pre-selected and initialized.")
                        } else {
                            Log.w(TAG, "Failed to pre-select or initialize default text model ${defaultModel.name}.")
                        }
                    } else {
                         Log.w(TAG, "No suitable default text model found for pre-selection (no existing file paths or text support).")
                    }
                }

            } catch (e: Exception) {
                Log.e(TAG, "Error during initial model load: ${e.message}", e)
                internalModelsList = emptyList()
            }
        }
    }
        
    internal fun getModelsInternal(): List<Model> {
        return internalModelsList
    }
    
    private suspend fun fetchAndParseAllowlist(): ModelAllowlist { 
        return withContext(Dispatchers.IO) {
            var jsonString: String? = null
            val cacheFile = File(context.getExternalFilesDir(null), MODEL_ALLOWLIST_FILENAME)
            try {
                Log.d(TAG, "Attempting to fetch allowlist from Network: $MODEL_ALLOWLIST_URL")
                jsonString = URL(MODEL_ALLOWLIST_URL).readText()
                cacheFile.writeText(jsonString)
                Log.d(TAG, "Successfully fetched and cached allowlist from Network.")
            } catch (e: Exception) {
                Log.w(TAG, "Network fetch failed: ${e.message}. Trying cache.")
                if (cacheFile.exists()) {
                    try {
                        jsonString = cacheFile.readText()
                        Log.d(TAG, "Successfully loaded allowlist from cache.")
                    } catch (cacheEx: Exception) {
                        Log.w(TAG, "Failed to read cache: ${cacheEx.message}. Trying assets.")
                        jsonString = null
                    }
                } else {
                    Log.d(TAG, "Cache file does not exist. Trying assets.")
                }
            }
            if (jsonString == null) {
                try {
                    Log.d(TAG, "Loading allowlist from assets: $ASSET_MODEL_ALLOWLIST_PATH")
                    val inputStream: InputStream = context.assets.open(ASSET_MODEL_ALLOWLIST_PATH)
                    jsonString = inputStream.bufferedReader().use { it.readText() }
                    Log.d(TAG, "Successfully loaded allowlist from assets.")
                } catch (assetEx: IOException) {
                    Log.e(TAG, "Failed to load allowlist from assets: ${assetEx.message}")
                    throw IOException("Failed to load model allowlist from all sources.", assetEx)
                }
            }
            if (jsonString.isNullOrEmpty()) {
                Log.e(TAG, "Allowlist JSON string is null or empty.")
                return@withContext ModelAllowlist(emptyList())
            }
            try {
                return@withContext json.decodeFromString<ModelAllowlist>(jsonString)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to parse allowlist JSON: ${e.message}")
                throw e
            }
        }
    }

    fun getAvailableModels(result: MethodChannel.Result) {
        coroutineScope.launch {
            loadModelsJob?.join() 
            val flutterModels = internalModelsList.map { model ->
                mapOf(
                    "id" to model.name, "name" to model.name, "description" to model.info,
                    "isImported" to model.imported, "llmSupportImage" to model.llmSupportImage,
                    "llmSupportVideo" to model.llmSupportVideo, "llmSupportAudio" to model.llmSupportAudio,
                    "llmSupportText" to model.llmSupportText,
                )
            }
            withContext(Dispatchers.Main) { result.success(flutterModels) }
        }
    }
    
    fun notifyModelSelected(modelId: String?, flutterResult: MethodChannel.Result) {
        Log.d(TAG, "notifyModelSelected (Flutter -> Native) called with modelId: $modelId")
        coroutineScope.launch {
            // Default isPreselection to false when called from Flutter
            val success = notifyModelSelectedInternal(modelId, isPreselection = false)
            withContext(Dispatchers.Main) {
                if (success) {
                    flutterResult.success(true)
                } else {
                    if (modelId != null) {
                         flutterResult.error("MODEL_SELECTION_FAILED", "Failed to select or initialize model $modelId.", null)
                    } else {
                         flutterResult.success(true) // Successful deselection (modelId was null)
                    }
                }
            }
        }
    }

    // Added isPreselection parameter, defaulting to false
    private suspend fun notifyModelSelectedInternal(modelId: String?, isPreselection: Boolean = false): Boolean {
        Log.d(TAG, "notifyModelSelectedInternal called with modelId: $modelId, isPreselection: $isPreselection")
        if (modelId == null) {
            Log.w(TAG, "Internal model selection cleared or modelId is null.")
            LlmChatModelHelper.cleanUp(currentSelectedModel)
            currentSelectedModel = null
            selectedModelInstance = null
            return true 
        }

        // Only join if not a preselection call (where list is already guaranteed to be populated)
        if (!isPreselection) {
            loadModelsJob?.join()
        }
        
        val modelToSelect = internalModelsList.find { it.name == modelId }
        if (modelToSelect == null) {
            Log.e(TAG, "Model with ID $modelId not found in internalModelsList.")
            return false
        }
        
        if (currentSelectedModel?.name != modelToSelect.name) {
            Log.d(TAG, "Switching model from ${currentSelectedModel?.name} to ${modelToSelect.name}.")
            LlmChatModelHelper.cleanUp(currentSelectedModel) 
            currentSelectedModel = modelToSelect
            selectedModelInstance = null 
            return initializeSelectedModelInternal(context)
        } else if (selectedModelInstance == null && currentSelectedModel != null) {
            Log.d(TAG, "Model ${currentSelectedModel!!.name} is already selected but not initialized. Initializing now.")
            return initializeSelectedModelInternal(context)
        } else {
            Log.d(TAG, "Model ${modelToSelect.name} is already selected and initialized.")
            return true 
        }
    }

    private suspend fun initializeSelectedModelInternal(context: Context): Boolean {
        val modelToInitialize = currentSelectedModel
        if (modelToInitialize == null) {
            Log.e(TAG, "No model is currently selected for internal initialization.")
            return false
        }
        Log.d(TAG, "Attempting to internally initialize model: ${modelToInitialize.name}")
        if (modelToInitialize.instance != null ) {
            Log.i(TAG, "Model ${modelToInitialize.name} appears to be initialized (instance exists).")
        }

        if (modelToInitialize.path == null) {
            Log.e(TAG, "Model path is null for ${modelToInitialize.name}. Cannot initialize.")
            if (currentSelectedModel == modelToInitialize) currentSelectedModel = null
            return false
        }
        
        Log.d(TAG, "Calling LlmChatModelHelper.initialize for ${modelToInitialize.name} with path ${modelToInitialize.path}")
        val initializationDeferred = CompletableDeferred<Boolean>()
        LlmChatModelHelper.initialize(context, modelToInitialize) { errorMessage ->
            if (errorMessage.isEmpty()) {
                selectedModelInstance = modelToInitialize.instance 
                Log.i(TAG, "Model ${modelToInitialize.name} initialized successfully via LlmChatModelHelper.")
                initializationDeferred.complete(true)
            } else {
                Log.e(TAG, "Failed to initialize model ${modelToInitialize.name}: $errorMessage")
                modelToInitialize.instance = null
                if (currentSelectedModel == modelToInitialize) currentSelectedModel = null
                selectedModelInstance = null
                initializationDeferred.complete(false)
            }
        }
        return initializationDeferred.await()
    }

    private fun modelFromImportedInfo(info: ImportedModelInfo, context: Context): Model {
        val model = Model(
            name = info.fileName, 
            info = info.description ?: "User imported model.",
            version = "1.0_imported", 
            downloadFileName = info.path, 
            url = info.path, 
            sizeInBytes = info.fileSize,
            imported = true,
            path = info.path, 
            dateAdded = info.dateAdded,
            allowlisted = false, 
            llmSupportImage = info.defaultValues[ConfigKey.SUPPORT_IMAGE.label]?.toBooleanStrictOrNull() ?: false,
            llmSupportText = true,   
            configs = createLlmChatConfigs(
                defaultMaxToken = info.defaultValues[ConfigKey.DEFAULT_MAX_TOKENS.label]?.toIntOrNull() ?: 1024,
                defaultTopK = info.defaultValues[ConfigKey.DEFAULT_TOPK.label]?.toIntOrNull() ?: 40,
                defaultTopP = info.defaultValues[ConfigKey.DEFAULT_TOPP.label]?.toFloatOrNull() ?: 0.9f,
                defaultTemperature = info.defaultValues[ConfigKey.DEFAULT_TEMPERATURE.label]?.toFloatOrNull() ?: 0.7f,
                accelerators = info.defaultValues[ConfigKey.COMPATIBLE_ACCELERATORS.label]?.split(',')
                    ?.mapNotNull { accName -> Accelerator.values().find { it.name == accName.trim().uppercase() } }
                    ?: listOf(Accelerator.CPU, Accelerator.GPU)
            )
        )
        model.preProcess()
        return model
    }

    fun addCustomModel(name: String, path: String, result: MethodChannel.Result) {
        Log.d(TAG, "NativeAiHub: addCustomModel called with Name: $name, Path: $path")
        var resultSent = false
        coroutineScope.launch {
            // Ensure initial models are loaded before checking for collisions
            if (!isPreselection) { // Assuming addCustomModel is not part of preselection
                 loadModelsJob?.join()
            }

            if (internalModelsList.any { it.name.equals(name, ignoreCase = true) }) {
                Log.w(TAG, "addCustomModel: Model with name '$name' already exists.")
                withContext(Dispatchers.Main) {
                    result.error("MODEL_ALREADY_EXISTS", "A model with this name already exists.", null)
                    resultSent = true
                }
                return@launch
            }

            val modelFile = File(path)
            if (!modelFile.exists() || !modelFile.isFile) { 
                 if (!path.startsWith("http://") && !path.startsWith("https://")) {
                    withContext(Dispatchers.Main) {
                        result.error("FILE_NOT_FOUND", "File not found or is not a valid file at path: $path", null)
                        resultSent = true
                    }
                    return@launch
                 }
                 Log.d(TAG, "Path $path looks like a URL, skipping direct file existence check.")
            }

            val fileSize = if (modelFile.exists() && modelFile.isFile) modelFile.length() else 0L 

            val defaultValues = mapOf(
                ConfigKey.COMPATIBLE_ACCELERATORS.label to "CPU,GPU",
                ConfigKey.DEFAULT_MAX_TOKENS.label to "1024", 
                ConfigKey.DEFAULT_TOPK.label to "40",
                ConfigKey.DEFAULT_TOPP.label to "0.9",
                ConfigKey.DEFAULT_TEMPERATURE.label to "0.7",
                ConfigKey.SUPPORT_IMAGE.label to "false" 
            )

            val nativeGeneratedId = "custom_native_${System.currentTimeMillis()}"
            val importedInfo = ImportedModelInfo(
                id = nativeGeneratedId, 
                fileName = name, 
                path = path,
                fileSize = fileSize,
                dateAdded = System.currentTimeMillis(),
                defaultValues = defaultValues,
                description = "User added on ${java.text.SimpleDateFormat.getDateInstance().format(java.util.Date())}",
                isNativeConfirmed = true 
            )

            try {
                val currentImported = dataStoreRepository.readImportedModels().toMutableList()
                currentImported.add(importedInfo)
                dataStoreRepository.saveImportedModels(currentImported)
                Log.i(TAG, "Custom model info saved to (placeholder) DataStore: $name")

                val newInternalModel = modelFromImportedInfo(importedInfo, context)
                synchronized(internalModelsList) {
                    internalModelsList = (internalModelsList + listOf(newInternalModel)).distinctBy { it.name }
                }
                Log.i(TAG, "Added $name to internalModelsList. Total models: ${internalModelsList.size}")

                withContext(Dispatchers.Main) {
                    if(!resultSent) {
                        result.success(mapOf("modelId" to newInternalModel.name)) 
                        resultSent = true
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "addCustomModel: Error saving or updating internal list for $name: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    if(!resultSent) {
                         result.error("SAVE_FAILED", "Failed to save custom model: ${e.message}", e.localizedMessage)
                         resultSent = true
                    }
                }
            }
        }
    }
    
    fun getPerformanceMetrics(modelIdFromFlutter: String?, result: MethodChannel.Result) {
        Log.d(TAG, "NativeAiHub: getPerformanceMetrics for modelId: $modelIdFromFlutter")
        coroutineScope.launch {
            if (modelIdFromFlutter != null && !isPreselection) { // Assuming getPerformanceMetrics is not part of preselection
                 loadModelsJob?.join() 
            }

            if (modelIdFromFlutter != null) {
                val model = internalModelsList.find { it.name == modelIdFromFlutter }
                if (model == null) {
                    withContext(Dispatchers.Main) {
                        result.error("MODEL_NOT_FOUND", "Model $modelIdFromFlutter not found when fetching performance metrics.", null)
                    }
                    return@launch
                }
                 if (model.instance == null && model.path != null) { 
                     Log.w(TAG, "Performance metrics for $modelIdFromFlutter requested, but model not initialized. Returning static placeholders.")
                 }
            } else {
                 Log.d(TAG, "modelIdFromFlutter is null, returning generic static performance placeholders.")
            }

            val metricsMap = mapOf(
                "ttftMs" to 0.0, 
                "decodeSpeedTokensPerSec" to 0.0, 
                "overallLatencyMs" to 0.0, 
                "notes" to "Detailed, model-specific metrics are provided with each inference result. These are general placeholders."
            )
            withContext(Dispatchers.Main) {
                result.success(metricsMap)
            }
        }
    }

    fun processImageQuery(imagePath: String, question: String, modelIdFromFlutter: String, result: MethodChannel.Result) {
        Log.d(TAG, "processImageQuery called. Flutter modelId: $modelIdFromFlutter, Image: $imagePath, Question: $question")
        var resultSent = false
        coroutineScope.launch {
            // Not a preselection call, so ensure models are loaded
            if (!isPreselection) { loadModelsJob?.join() }

            var activeModel = currentSelectedModel
            if (modelIdFromFlutter != activeModel?.name || activeModel?.instance == null) {
                Log.i(TAG, "processImageQuery: Requested $modelIdFromFlutter, current is ${activeModel?.name}. Switching/initializing model.")
                if (!notifyModelSelectedInternal(modelIdFromFlutter, isPreselection = false)) { // Pass false here
                    Log.e(TAG, "processImageQuery: Failed to switch to and initialize $modelIdFromFlutter.")
                    withContext(Dispatchers.Main) { if(!resultSent){ result.error("MODEL_INIT_FAILED", "Failed to initialize requested model: $modelIdFromFlutter for image query", null); resultSent = true } }
                    return@launch
                }
                activeModel = currentSelectedModel
            }
            // ... rest of the method remains the same
            if (activeModel == null || activeModel.instance == null) {
                Log.e(TAG, "processImageQuery: Model not ready after selection attempt.")
                withContext(Dispatchers.Main) { if (!resultSent) { result.error("MODEL_NOT_READY", "Model $modelIdFromFlutter could not be made ready.", null); resultSent = true } }
                return@launch
            }
            if (!activeModel.llmSupportImage) {
                Log.e(TAG, "processImageQuery: Model ${activeModel.name} does not support image input.")
                withContext(Dispatchers.Main) { if (!resultSent) { result.error("UNSUPPORTED_OPERATION", "Selected model ${activeModel.name} does not support image input.", null); resultSent = true } }
                return@launch
            }
            val bitmap = BitmapFactory.decodeFile(imagePath)
            if (bitmap == null) {
                Log.e(TAG, "processImageQuery: Failed to load image from path: $imagePath")
                withContext(Dispatchers.Main) { if (!resultSent) { result.error("IMAGE_LOAD_FAILED", "Failed to load image from path: $imagePath", null); resultSent = true } }
                return@launch
            }
            Log.d(TAG, "processImageQuery: Bitmap loaded successfully from $imagePath.")
            Log.d(TAG, "processImageQuery: Resetting session for model ${activeModel.name}.")
            LlmChatModelHelper.resetSession(activeModel)
            var startTime = 0L
            var firstTokenTime = 0L
            var tokensForPrefill = 0
            var decodedTokens = 0
            val responseAggregator = StringBuilder()
            try {
                tokensForPrefill = LlmChatModelHelper.sizeInTokens(activeModel, question)
                Log.d(TAG, "processImageQuery: tokensForPrefill (question text only) = $tokensForPrefill")
                startTime = System.currentTimeMillis()
                Log.d(TAG, "processImageQuery: Starting inference for model ${activeModel.name}.")
                LlmChatModelHelper.runInference(
                    model = activeModel, input = question, image = bitmap,
                    resultListener = { partialResult, done ->
                        if (resultSent) return@runInference
                        val currentTime = System.currentTimeMillis()
                        if (firstTokenTime == 0L) {
                            firstTokenTime = currentTime
                        }
                        responseAggregator.append(partialResult)
                        decodedTokens++ 
                        if (done) {
                            val endTime = System.currentTimeMillis()
                            val ttftMs = if (firstTokenTime > 0L && firstTokenTime >= startTime) firstTokenTime - startTime else endTime - startTime
                            val totalLatencyMs = endTime - startTime
                            val prefillTimeSec = if (ttftMs > 0) ttftMs / 1000.0 else 0.0
                            val prefillSpeed = if (prefillTimeSec > 0 && tokensForPrefill > 0) tokensForPrefill / prefillTimeSec else 0.0
                            val decodeTimeMs = if (firstTokenTime > 0L && endTime > firstTokenTime) endTime - firstTokenTime else 0L
                            val numDecodedTokensAfterPrefill = if (decodedTokens > 0) decodedTokens -1 else 0
                            val decodeTimeSec = if (decodeTimeMs > 0) decodeTimeMs / 1000.0 else 0.0
                            val decodeSpeed = if (decodeTimeSec > 0 && numDecodedTokensAfterPrefill > 0) numDecodedTokensAfterPrefill / decodeTimeSec else 0.0
                            Log.i(TAG, "processImageQuery Metrics: TTFT=${ttftMs}ms, TotalLatency=${totalLatencyMs}ms, PrefillTokens=${tokensForPrefill}, PrefillSpeed=${String.format("%.2f", prefillSpeed)}t/s, DecodedChunks=${decodedTokens}, DecodeSpeed=${String.format("%.2f", decodeSpeed)}t/s")
                            val responseMap = mapOf(
                                "answer" to responseAggregator.toString(),
                                "latencyMs" to totalLatencyMs.toDouble(),
                                "ttftMs" to ttftMs.toDouble(),
                                "prefillSpeedTokensPerSec" to prefillSpeed.toDouble(),
                                "decodeSpeedTokensPerSec" to decodeSpeed.toDouble(),
                                "promptTokenCount" to tokensForPrefill,
                                "outputTokenCount" to decodedTokens 
                            )
                            if (!resultSent) {
                                result.success(responseMap)
                                resultSent = true
                            }
                        }
                    },
                    errorListener = { error ->
                        if (resultSent) return@runInference
                        Log.e(TAG, "processImageQuery: Inference error for model ${activeModel.name}: ${error.message}", error)
                        result.error("INFERENCE_ERROR", "Inference error for image query: ${error.message}", error.localizedMessage)
                        resultSent = true
                    }
                )
            } catch (e: Exception) {
                Log.e(TAG, "processImageQuery: Exception during inference setup for ${activeModel.name}: ${e.message}", e)
                if (!resultSent) {
                     result.error("IMAGE_INFERENCE_SETUP_FAILED", "Failed to setup image inference: ${e.message}", e.localizedMessage)
                     resultSent = true
                }
            }
        }
    }

    fun processPrompt(prompt: String, taskType: String, modelIdFromFlutter: String?, result: MethodChannel.Result) {
        Log.d(TAG, "processPrompt called. Flutter modelId: $modelIdFromFlutter, Current selected: ${currentSelectedModel?.name}")
        var resultSent = false 
        coroutineScope.launch {
            if (!isPreselection) { loadModelsJob?.join() }

            var activeModel = currentSelectedModel
            val targetModelName = modelIdFromFlutter ?: activeModel?.name ?: internalModelsList.firstOrNull { it.llmSupportText && it.path != null }?.name
            if (targetModelName == null) {
                Log.e(TAG, "No suitable model available for prompt processing.")
                withContext(Dispatchers.Main) { if(!resultSent){ result.error("NO_MODEL_AVAILABLE", "No model suitable for this prompt is available or initialized.", null); resultSent = true } }
                return@launch
            }
            if (targetModelName != activeModel?.name || activeModel?.instance == null) {
                Log.i(TAG, "processPrompt: Target $targetModelName, current is ${activeModel?.name}. Switching/initializing model.")
                if (!notifyModelSelectedInternal(targetModelName, isPreselection = false)) { // Pass false
                    Log.e(TAG, "processPrompt: Failed to switch to and initialize $targetModelName.")
                    withContext(Dispatchers.Main) { if(!resultSent){ result.error("MODEL_INIT_FAILED", "Failed to initialize requested model: $targetModelName", null); resultSent = true} }
                    return@launch
                }
                activeModel = currentSelectedModel
            }
            // ... rest of the method remains the same
            if (activeModel == null || activeModel.instance == null) {
                Log.e(TAG, "processPrompt: Model not ready (activeModel or activeInstance is null).")
                withContext(Dispatchers.Main) { if (!resultSent) {result.error("MODEL_NOT_READY", "A model must be selected and initialized.", null); resultSent = true} }
                return@launch
            }
            if (!activeModel.llmSupportText) {
                 Log.e(TAG, "processPrompt: Model ${activeModel.name} does not support text generation.")
                withContext(Dispatchers.Main) { if (!resultSent) {result.error("UNSUPPORTED_OPERATION", "Model ${activeModel.name} does not support text generation.", null); resultSent = true} }
                return@launch
            }
            Log.d(TAG, "processPrompt: Resetting session for model ${activeModel.name}.")
            LlmChatModelHelper.resetSession(activeModel)
            var startTime = 0L
            var firstTokenTime = 0L
            var tokensForPrefill = 0
            var decodedTokens = 0 
            val responseAggregator = StringBuilder()
            try {
                tokensForPrefill = LlmChatModelHelper.sizeInTokens(activeModel, prompt)
                Log.d(TAG, "processPrompt: tokensForPrefill = $tokensForPrefill")
                startTime = System.currentTimeMillis()
                Log.d(TAG, "processPrompt: Starting inference for model ${activeModel.name}.")
                LlmChatModelHelper.runInference(
                    model = activeModel, input = prompt, image = null,
                    resultListener = { partialResult, done ->
                        if (resultSent) return@runInference
                        val currentTime = System.currentTimeMillis()
                        if (firstTokenTime == 0L) {
                            firstTokenTime = currentTime
                        }
                        responseAggregator.append(partialResult)
                        decodedTokens++ 
                        if (done) {
                            val endTime = System.currentTimeMillis()
                            val ttftMs = if (firstTokenTime > 0L && firstTokenTime >= startTime) firstTokenTime - startTime else endTime - startTime
                            val totalLatencyMs = endTime - startTime
                            val prefillTimeSec = if (ttftMs > 0) ttftMs / 1000.0 else 0.0
                            val prefillSpeed = if (prefillTimeSec > 0 && tokensForPrefill > 0) tokensForPrefill / prefillTimeSec else 0.0
                            val decodeTimeMs = if (firstTokenTime > 0L && endTime > firstTokenTime) endTime - firstTokenTime else 0L
                            val numDecodedTokensAfterPrefill = if (decodedTokens > 0) decodedTokens -1 else 0
                            val decodeTimeSec = if (decodeTimeMs > 0) decodeTimeMs / 1000.0 else 0.0
                            val decodeSpeed = if (decodeTimeSec > 0 && numDecodedTokensAfterPrefill > 0) numDecodedTokensAfterPrefill / decodeTimeSec else 0.0
                            Log.i(TAG, "processPrompt Metrics: TTFT=${ttftMs}ms, TotalLatency=${totalLatencyMs}ms, PrefillTokens=${tokensForPrefill}, PrefillSpeed=${String.format("%.2f", prefillSpeed)}t/s, DecodedChunks=${decodedTokens}, DecodeSpeed=${String.format("%.2f", decodeSpeed)}t/s")
                            val responseMap = mapOf(
                                "response" to responseAggregator.toString(),
                                "latencyMs" to totalLatencyMs.toDouble(),
                                "ttftMs" to ttftMs.toDouble(),
                                "prefillSpeedTokensPerSec" to prefillSpeed.toDouble(),
                                "decodeSpeedTokensPerSec" to decodeSpeed.toDouble(),
                                "promptTokenCount" to tokensForPrefill, 
                                "outputTokenCount" to decodedTokens 
                            )
                            if (!resultSent) {
                                result.success(responseMap)
                                resultSent = true
                            }
                        }
                    },
                    errorListener = { error ->
                        if (resultSent) return@runInference
                        Log.e(TAG, "processPrompt: Inference error for model ${activeModel.name}: ${error.message}", error)
                        result.error("INFERENCE_ERROR", "Inference error: ${error.message}", error.localizedMessage)
                        resultSent = true
                    }
                )
            } catch (e: Exception) { 
                Log.e(TAG, "processPrompt: Exception during inference setup for ${activeModel.name}: ${e.message}", e)
                if (!resultSent) {
                     result.error("INFERENCE_SETUP_FAILED", "Failed to setup inference: ${e.message}", e.localizedMessage)
                     resultSent = true
                }
            }
        }
    }
    
    fun getNextChatResponse(message: String, history: List<Map<String, String>>, modelIdFromFlutter: String?, result: MethodChannel.Result) {
        Log.d(TAG, "getNextChatResponse called. Flutter modelId: $modelIdFromFlutter, Current selected: ${currentSelectedModel?.name}, History items: ${history.size}")
        var resultSent = false
        coroutineScope.launch {
             if (!isPreselection) { loadModelsJob?.join() } // Assuming not preselection context

            var activeModel = currentSelectedModel
            var sessionResetNeeded = false
            val targetModelName = modelIdFromFlutter ?: activeModel?.name ?: internalModelsList.firstOrNull { it.llmSupportText && it.path != null }?.name
            if (targetModelName == null) {
                Log.e(TAG, "Chat: No suitable model available.")
                withContext(Dispatchers.Main) { if(!resultSent) {result.error("NO_MODEL_AVAILABLE", "No model suitable for chat is available or initialized.", null); resultSent = true} }
                return@launch
            }
            if (targetModelName != activeModel?.name || activeModel?.instance == null) {
                Log.i(TAG, "Chat: Target model $targetModelName. Current: ${activeModel?.name}. Instance null? ${activeModel?.instance == null}. Attempting to set/initialize.")
                sessionResetNeeded = true 
                if (!notifyModelSelectedInternal(targetModelName, isPreselection = false)) { // Pass false
                    Log.e(TAG, "Chat: Failed to switch/initialize model $targetModelName.")
                    withContext(Dispatchers.Main) { if(!resultSent) {result.error("MODEL_INIT_FAILED", "Failed to initialize model: $targetModelName for chat", null); resultSent = true} }
                    return@launch
                }
                activeModel = currentSelectedModel 
            }
            // ... rest of the method remains the same
            if (activeModel == null || activeModel.instance == null) {
                 withContext(Dispatchers.Main) { if(!resultSent) {result.error("MODEL_NOT_READY", "Model $targetModelName could not be made ready for chat.", null); resultSent = true} }
                return@launch
            }
            if (!activeModel.llmSupportText) {
                Log.e(TAG, "Chat: Model ${activeModel.name} does not support text.")
                withContext(Dispatchers.Main) { if(!resultSent) {result.error("UNSUPPORTED_OPERATION", "Model ${activeModel.name} does not support text chat.", null); resultSent = true} }
                return@launch
            }
            if (sessionResetNeeded) {
                Log.d(TAG, "Chat: Resetting session for newly selected/initialized model ${activeModel.name}.")
                LlmChatModelHelper.resetSession(activeModel)
            } else {
                Log.d(TAG, "Chat: Continuing session with current model ${activeModel.name}.")
            }
            Log.d(TAG, "Chat: Input message: '$message'. History (from Flutter, for context): ${history.size} items.")
            history.forEachIndexed { index, item ->
                Log.d(TAG, "History[$index]: ${item["sender"]} - ${item["text"]}")
            }
            var startTime = 0L
            var firstTokenTime = 0L
            var tokensForPrefill = 0
            var decodedTokens = 0
            val responseAggregator = StringBuilder()
            try {
                tokensForPrefill = LlmChatModelHelper.sizeInTokens(activeModel, message)
                Log.d(TAG, "Chat: tokensForPrefill (current message only) = $tokensForPrefill")
                startTime = System.currentTimeMillis()
                Log.d(TAG, "Chat: Starting inference for model ${activeModel.name}.")
                LlmChatModelHelper.runInference(
                    model = activeModel, input = message, image = null,
                    resultListener = { partialResult, done ->
                        if (resultSent) return@runInference
                        val currentTime = System.currentTimeMillis()
                        if (firstTokenTime == 0L) {
                            firstTokenTime = currentTime
                        }
                        responseAggregator.append(partialResult)
                        decodedTokens++
                        if (done) {
                            val endTime = System.currentTimeMillis()
                            val ttftMs = if (firstTokenTime > 0L && firstTokenTime >= startTime) firstTokenTime - startTime else endTime - startTime
                            val totalLatencyMs = endTime - startTime
                            val prefillTimeSec = if (ttftMs > 0) ttftMs / 1000.0 else 0.0
                            val prefillSpeed = if (prefillTimeSec > 0 && tokensForPrefill > 0) tokensForPrefill / prefillTimeSec else 0.0
                            val decodeTimeMs = if (firstTokenTime > 0L && endTime > firstTokenTime) endTime - firstTokenTime else 0L
                            val numDecodedTokensAfterPrefill = if (decodedTokens > 0) decodedTokens -1 else 0
                            val decodeTimeSec = if (decodeTimeMs > 0) decodeTimeMs / 1000.0 else 0.0
                            val decodeSpeed = if (decodeTimeSec > 0 && numDecodedTokensAfterPrefill > 0) numDecodedTokensAfterPrefill / decodeTimeSec else 0.0
                            Log.i(TAG, "Chat Metrics: TTFT=${ttftMs}ms, TotalLatency=${totalLatencyMs}ms, PrefillTokens=${tokensForPrefill}, PrefillSpeed=${String.format("%.2f", prefillSpeed)}t/s, DecodedChunks=${decodedTokens}, DecodeSpeed=${String.format("%.2f", decodeSpeed)}t/s")
                            val responseMap = mapOf(
                                "response" to responseAggregator.toString(),
                                "latencyMs" to totalLatencyMs.toDouble(),
                                "ttftMs" to ttftMs.toDouble(),
                                "prefillSpeedTokensPerSec" to prefillSpeed.toDouble(),
                                "decodeSpeedTokensPerSec" to decodeSpeed.toDouble(),
                                "promptTokenCount" to tokensForPrefill,
                                "outputTokenCount" to decodedTokens 
                            )
                            if (!resultSent) {
                                result.success(responseMap)
                                resultSent = true
                            }
                        }
                    },
                    errorListener = { error ->
                        if (resultSent) return@runInference
                        Log.e(TAG, "Chat: Inference error for model ${activeModel.name}: ${error.message}", error)
                        result.error("INFERENCE_ERROR", "Chat inference error: ${error.message}", error.localizedMessage)
                        resultSent = true
                    }
                )
            } catch (e: Exception) {
                Log.e(TAG, "Chat: Exception during inference setup for ${activeModel.name}: ${e.message}", e)
                if (!resultSent) {
                     result.error("CHAT_SETUP_FAILED", "Failed to setup chat inference: ${e.message}", e.localizedMessage)
                     resultSent = true
                }
            }
        }
    }

    // Dummy isPreselection variable for methods that might need it
    private val isPreselection: Boolean = false
}
