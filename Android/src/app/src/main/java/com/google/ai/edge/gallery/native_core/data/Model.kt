package com.google.ai.edge.gallery.native_core.data

import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient
import android.content.Context // Required for modelFromImportedInfo if it uses context
import java.util.Locale // For uppercase in Accelerator

// --- Enums and Data Classes for Model Configuration ---
enum class ConfigKey(val label: String) {
    MAX_TOKENS("Max Tokens"),
    TOP_K("Top K"),
    TOP_P("Top P"),
    TEMPERATURE("Temperature"),
    ACCELERATOR("Accelerator"),
    // For addCustomModel default values
    COMPATIBLE_ACCELERATORS("Compatible Accelerators"), // String, e.g., "CPU,GPU"
    DEFAULT_MAX_TOKENS("Default Max Tokens"),    // Int
    DEFAULT_TOPK("Default TopK"),                // Int
    DEFAULT_TOPP("Default TopP"),                // Float
    DEFAULT_TEMPERATURE("Default Temperature"),    // Float
    SUPPORT_IMAGE("Support Image")               // Boolean
}

enum class Accelerator {
    CPU, GPU, NNAPI, HEXAGON, EDGETPU;

    val displayName: String
        get() = name.uppercase(Locale.getDefault())
}

enum class ConfigValueType {
    INT, FLOAT, STRING, ENUM, BOOLEAN
}

@Serializable
data class ModelConfig(
    val key: ConfigKey,
    val name: String,
    val description: String,
    val type: ConfigValueType,
    var currentValue: String, // Stored as string, converted based on type
    val defaultValue: String,
    val options: List<String>? = null, // For ENUM type
    val range: Pair<Float, Float>? = null // For FLOAT or INT types (min, max)
)

/** Model information. */
@Serializable
data class Model(
    val name: String,
    val info: String, // Description
    var version: String = "1.0", // Added
    var downloadFileName: String? = null, // Added: e.g., gemini_nano.bin or path for imported
    var url: String? = null, // Added: Original path for imported, or download URL
    var sizeInBytes: Long = 0, // Added
    var configs: List<ModelConfig> = emptyList(), // Added
    val llmSupportImage: Boolean = false,
    val llmSupportVideo: Boolean = false,
    val llmSupportAudio: Boolean = false,
    val llmSupportText: Boolean = true,
    val imported: Boolean = false,
    var path: String? = null, // Actual local path after download/copy for imported
    val dateAdded: Long? = null,
    val allowlisted: Boolean = true
) {
    @Transient
    var instance: LlmModelInstance? = null

    @Transient
    val configValues: MutableMap<ConfigKey, Any> = mutableMapOf()

    // Call this after configs are populated
    fun preProcess() {
        configs.forEach { config ->
            configValues[config.key] = when (config.type) {
                ConfigValueType.INT -> config.currentValue.toIntOrNull() ?: config.defaultValue.toInt()
                ConfigValueType.FLOAT -> config.currentValue.toFloatOrNull() ?: config.defaultValue.toFloat()
                ConfigValueType.BOOLEAN -> config.currentValue.toBooleanStrictOrNull() ?: config.defaultValue.toBoolean()
                else -> config.currentValue
            }
        }
        // Default accelerator if not set by specific model config
        if (!configValues.containsKey(ConfigKey.ACCELERATOR)) {
            configValues[ConfigKey.ACCELERATOR] = Accelerator.CPU.displayName
        }
    }
}

/** Model allowlist from GCS. */
@Serializable
data class ModelAllowlist(
    val models: List<AllowedModel> = listOf(),
)

/** Individual model in allowlist. */
@Serializable
data class AllowedModel(
    val name: String = "",
    val info: String = "",
    val version: String = "N/A",
    val downloadFileName: String? = null,
    val url: String? = null,
    val sizeInBytes: Long = 0,
    val llmSupportImage: Boolean = false,
    val llmSupportVideo: Boolean = false,
    val llmSupportAudio: Boolean = false,
    val llmSupportText: Boolean = true,
    // Placeholder for default configs if they come from allowlist directly
    val defaultMaxTokens: Int = 1024,
    val defaultTopK: Int = 40,
    val defaultTopP: Float = 0.9f,
    val defaultTemperature: Float = 0.7f
) {
    fun toModel(): Model {
        val model = Model(
            name = name,
            info = info,
            version = version,
            downloadFileName = downloadFileName,
            url = url,
            sizeInBytes = sizeInBytes,
            llmSupportImage = llmSupportImage,
            llmSupportVideo = llmSupportVideo,
            llmSupportAudio = llmSupportAudio,
            llmSupportText = llmSupportText,
            imported = false,
            allowlisted = true,
            // Path will be set after download by ModelManager or similar
            configs = createLlmChatConfigs(
                defaultMaxToken = defaultMaxTokens,
                defaultTopK = defaultTopK,
                defaultTopP = defaultTopP,
                defaultTemperature = defaultTemperature
            )
        )
        model.preProcess()
        return model
    }
}

/** User imported model information stored in DataStore. */
@Serializable
data class ImportedModelInfo(
    val id: String,
    val fileName: String, // User-defined name for the model
    val path: String,     // Original path provided by user
    val fileSize: Long,
    val dateAdded: Long,
    val defaultValues: Map<String, String>, // Store all as string, parse when creating ModelConfig
    val description: String? = null,
    var isNativeConfirmed: Boolean = false // Added from previous step, useful for tracking
) {
    fun toModel(context: Context): Model { // Context might not be needed if path handling is external
        val model = Model(
            name = fileName,
            info = description ?: "User imported model.",
            version = "1.0_imported", // Or derive if possible
            downloadFileName = path, // Store original path here for reference
            url = path, // Store original path as URL for consistency
            sizeInBytes = fileSize,
            llmSupportImage = defaultValues[ConfigKey.SUPPORT_IMAGE.label]?.toBooleanStrictOrNull() ?: false,
            llmSupportVideo = false, // Default for imported
            llmSupportAudio = false, // Default for imported
            llmSupportText = true,   // Assume text support for imported
            imported = true,
            path = path, // This path is the one provided by user, might need to be copied to app-specific dir
            dateAdded = dateAdded,
            allowlisted = false, // Imported models are not from main allowlist
            configs = createLlmChatConfigs(
                defaultMaxToken = defaultValues[ConfigKey.DEFAULT_MAX_TOKENS.label]?.toIntOrNull() ?: 1024,
                defaultTopK = defaultValues[ConfigKey.DEFAULT_TOPK.label]?.toIntOrNull() ?: 40,
                defaultTopP = defaultValues[ConfigKey.DEFAULT_TOPP.label]?.toFloatOrNull() ?: 0.9f,
                defaultTemperature = defaultValues[ConfigKey.DEFAULT_TEMPERATURE.label]?.toFloatOrNull() ?: 0.7f,
                // Assuming imported models initially support CPU/GPU, actual compatibility is complex
                accelerators = (defaultValues[ConfigKey.COMPATIBLE_ACCELERATORS.label]?.split(",")
                    ?.mapNotNull { accName -> Accelerator.values().find { it.name == accName.trim().uppercase() } }
                    ?: listOf(Accelerator.CPU, Accelerator.GPU))
            )
        )
        model.preProcess()
        return model
    }
}


// Helper function, can be part of Model.kt or a utility file
fun createLlmChatConfigs(
    defaultMaxToken: Int = 1024,
    defaultTopK: Int = 1, // Default in some MP tasks
    defaultTopP: Float = 0.8f, // Default in some MP tasks
    defaultTemperature: Float = 0.8f, // Default in some MP tasks
    accelerators: List<Accelerator> = listOf(Accelerator.CPU, Accelerator.GPU)
): List<ModelConfig> {
    return listOf(
        ModelConfig(
            ConfigKey.MAX_TOKENS, "Max Tokens",
            "Maximum number of tokens to generate in the response.",
            ConfigValueType.INT, defaultMaxToken.toString(), defaultMaxToken.toString(),
            range = Pair(1f, 8192f) // Example range
        ),
        ModelConfig(
            ConfigKey.TOP_K, "Top K",
            "Selects the next token from the top K most probable tokens.",
            ConfigValueType.INT, defaultTopK.toString(), defaultTopK.toString(),
            range = Pair(1f, 100f)
        ),
        ModelConfig(
            ConfigKey.TOP_P, "Top P",
            "Selects the next token from the smallest set of tokens whose cumulative probability exceeds P.",
            ConfigValueType.FLOAT, defaultTopP.toString(), defaultTopP.toString(),
            range = Pair(0.0f, 1.0f)
        ),
        ModelConfig(
            ConfigKey.TEMPERATURE, "Temperature",
            "Controls the randomness of the output. Higher values mean more randomness.",
            ConfigValueType.FLOAT, defaultTemperature.toString(), defaultTemperature.toString(),
            range = Pair(0.0f, 1.0f) // Often 0.0 to 2.0, but 1.0 is common max for some UIs
        ),
        ModelConfig(
            ConfigKey.ACCELERATOR, "Accelerator",
            "Hardware accelerator to use for inference.",
            ConfigValueType.ENUM, accelerators.firstOrNull()?.displayName ?: Accelerator.CPU.displayName,
            accelerators.firstOrNull()?.displayName ?: Accelerator.CPU.displayName,
            options = accelerators.map { it.displayName }
        )
    )
}
