import Foundation
import WhisperKit

/// Manages Whisper model loading and audio transcription
/// Handles model download, selection, and transcription pipeline
@MainActor
final class WhisperManager: ObservableObject {
    
    // MARK: - Types
    
    /// User-friendly error types for transcription failures
    enum TranscriptionError: LocalizedError {
        case modelNotLoaded
        case noSpeechDetected(details: String)
        case audioValidationFailed(String)
        case whisperKitError(underlying: Error)
        case blankAudioResult(details: String)
        case unknownError(String)
        
        var errorDescription: String? {
            switch self {
            case .modelNotLoaded:
                return "Model Not Loaded"
            case .noSpeechDetected:
                return "No Speech Detected"
            case .audioValidationFailed:
                return "Audio Validation Failed"
            case .whisperKitError:
                return "Transcription Error"
            case .blankAudioResult:
                return "No Speech Detected"
            case .unknownError:
                return "Transcription Error"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .modelNotLoaded:
                return "Please open Settings and load a Whisper model before recording."
            case .noSpeechDetected(let details):
                return details
            case .audioValidationFailed(let message):
                return message
            case .whisperKitError(let error):
                return "WhisperKit error: \(error.localizedDescription)\n\nTry recording again. If the problem persists, try reloading the model in Settings."
            case .blankAudioResult(let details):
                return details
            case .unknownError(let message):
                return message
            }
        }
        
        /// Whether this error is retryable
        var isRetryable: Bool {
            switch self {
            case .modelNotLoaded:
                return false
            case .noSpeechDetected, .blankAudioResult:
                return true // User can try speaking again
            case .audioValidationFailed:
                return true
            case .whisperKitError:
                return true
            case .unknownError:
                return true
            }
        }
    }
    
    /// Available Whisper model sizes
    enum ModelSize: String, CaseIterable, Identifiable {
        case tiny = "tiny"
        case base = "base"
        case small = "small"
        case medium = "medium"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .tiny: return "Tiny (~75MB, fastest)"
            case .base: return "Base (~145MB, fast)"
            case .small: return "Small (~485MB, balanced)"
            case .medium: return "Medium (~1.5GB, accurate)"
            }
        }
        
        var description: String {
            switch self {
            case .tiny: return "Fastest, lower accuracy. Good for quick notes."
            case .base: return "Fast with decent accuracy. Good balance for most uses."
            case .small: return "Good accuracy, moderate speed. Recommended for general use."
            case .medium: return "High accuracy, slower. Best for important transcriptions."
            }
        }
        
        /// The model name pattern for WhisperKit
        var modelPattern: String {
            return "openai_whisper-\(rawValue)"
        }
    }
    
    /// Transcription status
    enum TranscriptionStatus: Equatable {
        case idle
        case loading
        case transcribing
        case completed(String)
        case error(String)
        
        var isProcessing: Bool {
            switch self {
            case .loading, .transcribing:
                return true
            default:
                return false
            }
        }
    }
    
    /// Model status
    enum ModelStatus: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case downloaded
        case loading
        case ready
        case error(String)
    }
    
    // MARK: - Constants
    
    private struct Constants {
        static let selectedModelKey = "selectedWhisperModel"
        static let selectedLanguageKey = "selectedTranscriptionLanguage"  // US-606
        static let modelRepo = "argmaxinc/whisperkit-coreml"
        static let expectedSampleRate: Double = 16000.0
        static let minimumDuration: Double = 0.5    // seconds
        static let maximumDuration: Double = 120.0  // seconds
    }
    
    // MARK: - US-606: Transcription Language
    
    /// Supported transcription languages
    /// "auto" means auto-detect (nil language hint to WhisperKit)
    enum TranscriptionLanguage: String, CaseIterable, Identifiable {
        case automatic = "auto"
        case english = "en"
        case spanish = "es"
        case french = "fr"
        case german = "de"
        case italian = "it"
        case portuguese = "pt"
        case japanese = "ja"
        case chinese = "zh"
        case korean = "ko"
        case russian = "ru"
        case arabic = "ar"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .automatic: return "Auto-Detect"
            case .english: return "English"
            case .spanish: return "Spanish"
            case .french: return "French"
            case .german: return "German"
            case .italian: return "Italian"
            case .portuguese: return "Portuguese"
            case .japanese: return "Japanese"
            case .chinese: return "Chinese"
            case .korean: return "Korean"
            case .russian: return "Russian"
            case .arabic: return "Arabic"
            }
        }
        
        var flag: String {
            switch self {
            case .automatic: return "🌐"
            case .english: return "🇺🇸"
            case .spanish: return "🇪🇸"
            case .french: return "🇫🇷"
            case .german: return "🇩🇪"
            case .italian: return "🇮🇹"
            case .portuguese: return "🇵🇹"
            case .japanese: return "🇯🇵"
            case .chinese: return "🇨🇳"
            case .korean: return "🇰🇷"
            case .russian: return "🇷🇺"
            case .arabic: return "🇸🇦"
            }
        }
        
        /// Returns the language code to pass to WhisperKit, or nil for auto-detect
        var whisperLanguageCode: String? {
            switch self {
            case .automatic:
                return nil  // nil tells WhisperKit to auto-detect
            default:
                return rawValue
            }
        }
    }
    
    /// Audio validation error types
    enum AudioValidationError: LocalizedError {
        case emptyAudioData
        case durationTooShort(actual: Double, minimum: Double)
        case durationTooLong(actual: Double, maximum: Double)
        case samplesOutOfRange(min: Float, max: Float)
        case invalidSampleRate(expected: Double, actual: Double)
        
        var errorDescription: String? {
            switch self {
            case .emptyAudioData:
                return "No audio data provided"
            case .durationTooShort(let actual, let minimum):
                return "Audio too short: \(String(format: "%.2f", actual))s (minimum: \(String(format: "%.1f", minimum))s)"
            case .durationTooLong(let actual, let maximum):
                return "Audio too long: \(String(format: "%.2f", actual))s (maximum: \(String(format: "%.1f", maximum))s)"
            case .samplesOutOfRange(let min, let max):
                return "Audio samples out of expected range [-1.0, 1.0]: found [\(String(format: "%.4f", min)), \(String(format: "%.4f", max))]"
            case .invalidSampleRate(let expected, let actual):
                return "Invalid sample rate: expected \(Int(expected))Hz, got \(Int(actual))Hz"
            }
        }
    }
    
    // MARK: - Properties
    
    /// The WhisperKit pipeline instance
    private var whisperKit: WhisperKit?
    
    /// Currently selected model size
    @Published private(set) var selectedModel: ModelSize
    
    /// Status of the current model
    @Published private(set) var modelStatus: ModelStatus = .notDownloaded
    
    /// Current transcription status
    @Published private(set) var transcriptionStatus: TranscriptionStatus = .idle
    
    /// Download progress for current model (0.0 to 1.0)
    @Published private(set) var downloadProgress: Double = 0.0
    
    /// Status messages for UI display
    @Published private(set) var statusMessage: String = "No model loaded"
    
    /// Last error message for UI display (detailed)
    @Published private(set) var lastErrorMessage: String?
    
    /// US-606: Currently selected transcription language
    @Published var selectedLanguage: TranscriptionLanguage {
        didSet {
            // Persist language preference when changed
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: Constants.selectedLanguageKey)
            print("WhisperManager: [US-606] Language changed to \(selectedLanguage.displayName) (\(selectedLanguage.rawValue))")
        }
    }
    
    /// Model download and caching directory
    private var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDir = appSupport.appendingPathComponent("WispFlow/Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        return modelsDir
    }
    
    // MARK: - Callbacks
    
    /// Called when transcription completes
    var onTranscriptionComplete: ((String) -> Void)?
    
    /// Called when an error occurs (legacy - simple string)
    var onError: ((String) -> Void)?
    
    /// Called when a transcription error occurs (detailed - with retry support)
    var onTranscriptionError: ((TranscriptionError, Data?, Double) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        // Load saved model preference
        if let savedModel = UserDefaults.standard.string(forKey: Constants.selectedModelKey),
           let model = ModelSize(rawValue: savedModel) {
            selectedModel = model
        } else {
            selectedModel = .base // Default to base model
        }
        
        // US-606: Load saved language preference
        if let savedLanguage = UserDefaults.standard.string(forKey: Constants.selectedLanguageKey),
           let language = TranscriptionLanguage(rawValue: savedLanguage) {
            selectedLanguage = language
        } else {
            selectedLanguage = .automatic // Default to auto-detect
        }
        
        print("WhisperManager initialized with model: \(selectedModel.rawValue), language: \(selectedLanguage.rawValue)")
    }
    
    // MARK: - Model Management
    
    /// Select a different model size
    func selectModel(_ model: ModelSize) async {
        guard model != selectedModel || modelStatus != .ready else { return }
        
        selectedModel = model
        UserDefaults.standard.set(model.rawValue, forKey: Constants.selectedModelKey)
        
        // Unload current model
        whisperKit = nil
        modelStatus = .notDownloaded
        statusMessage = "Model changed to \(model.displayName)"
        
        print("WhisperManager: Selected model \(model.rawValue)")
    }
    
    /// Load the selected model (downloads if necessary)
    func loadModel() async {
        guard modelStatus != .ready && modelStatus != .loading else {
            print("WhisperManager: Model already loaded or loading")
            return
        }
        
        // Clear any previous error
        lastErrorMessage = nil
        
        // Check if model is downloaded
        let isDownloaded = isModelDownloaded(selectedModel)
        
        // US-304: Verify model directory exists and is writable before download
        if !verifyModelsDirectory() {
            let errorMsg = "Cannot access model storage directory. Please check disk permissions."
            modelStatus = .error(errorMsg)
            statusMessage = errorMsg
            lastErrorMessage = "Model directory issue:\n\(modelsDirectory.path)\n\nThe directory could not be created or is not writable. This may be due to disk permissions or space issues."
            print("╔═══════════════════════════════════════════════════════════════╗")
            print("║ [US-304] MODEL DIRECTORY ERROR                                ║")
            print("╠═══════════════════════════════════════════════════════════════╣")
            print("║ Directory: \(modelsDirectory.path)")
            print("║ Error: Directory not writable or cannot be created")
            print("╚═══════════════════════════════════════════════════════════════╝")
            ErrorLogger.shared.log(
                "Model directory verification failed",
                category: .model,
                severity: .error,
                context: [
                    "directory": modelsDirectory.path,
                    "exists": FileManager.default.fileExists(atPath: modelsDirectory.path),
                    "isWritable": FileManager.default.isWritableFile(atPath: modelsDirectory.path)
                ]
            )
            return
        }
        
        if isDownloaded {
            modelStatus = .loading
            statusMessage = "Loading \(selectedModel.displayName)..."
        } else {
            modelStatus = .downloading(progress: 0.0)
            downloadProgress = 0.0
            statusMessage = "Connecting to model repository..."
        }
        
        // US-304: Log comprehensive model load start info
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║ [US-304] WHISPER MODEL DOWNLOAD/LOAD START                    ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ Model: \(selectedModel.rawValue) (\(selectedModel.modelPattern))")
        print("║ Model Directory: \(modelsDirectory.path)")
        print("║ Already Downloaded: \(isDownloaded)")
        print("║ Repository: \(Constants.modelRepo)")
        print("║ Expected Download URL: https://huggingface.co/\(Constants.modelRepo)")
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        do {
            print("WhisperManager: Starting model load for \(selectedModel.rawValue)")
            
            // Configure WhisperKit with progress callback
            let config = WhisperKitConfig(
                model: selectedModel.modelPattern,
                downloadBase: modelsDirectory,
                verbose: true,
                prewarm: true
            )
            
            // Initialize WhisperKit (this downloads if needed)
            // WhisperKit downloads models automatically if not present
            // Update status to loading once download would start
            if !isDownloaded {
                // US-304: Show intermediate status messages during download
                // Note: WhisperKit doesn't expose progress callbacks directly,
                // so we show status stages during the download
                modelStatus = .downloading(progress: 0.1)
                downloadProgress = 0.1
                statusMessage = "Downloading model files from Hugging Face..."
                
                // Update status message after a brief delay to show progress
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    if case .downloading = self.modelStatus {
                        self.modelStatus = .downloading(progress: 0.3)
                        self.downloadProgress = 0.3
                        self.statusMessage = "Downloading \(self.selectedModel.displayName) (~\(self.getEstimatedSize()))..."
                    }
                }
                
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    if case .downloading = self.modelStatus {
                        self.modelStatus = .downloading(progress: 0.5)
                        self.downloadProgress = 0.5
                        self.statusMessage = "Still downloading... this may take a few minutes"
                    }
                }
            }
            
            whisperKit = try await WhisperKit(config)
            
            // US-304: Verify model files exist after download
            let verificationResult = verifyModelFilesAfterDownload()
            if !verificationResult.success {
                print("╔═══════════════════════════════════════════════════════════════╗")
                print("║ [US-304] WARNING: Model verification incomplete               ║")
                print("╠═══════════════════════════════════════════════════════════════╣")
                print("║ \(verificationResult.message)")
                print("╚═══════════════════════════════════════════════════════════════╝")
            } else {
                print("╔═══════════════════════════════════════════════════════════════╗")
                print("║ [US-304] MODEL VERIFICATION SUCCESS                           ║")
                print("╠═══════════════════════════════════════════════════════════════╣")
                print("║ \(verificationResult.message)")
                print("╚═══════════════════════════════════════════════════════════════╝")
            }
            
            // Update progress after successful download/load
            downloadProgress = 1.0
            modelStatus = .ready
            statusMessage = "\(selectedModel.displayName) ready"
            print("WhisperManager: Model loaded successfully")
            
        } catch {
            // US-304: Enhanced error logging with full context
            let errorMessage = "Failed to load model: \(error.localizedDescription)"
            let detailedError = createDetailedErrorMessage(error: error)
            
            modelStatus = .error(errorMessage)
            statusMessage = errorMessage
            lastErrorMessage = detailedError
            downloadProgress = 0.0
            
            print("╔═══════════════════════════════════════════════════════════════╗")
            print("║ [US-304] MODEL DOWNLOAD/LOAD FAILED                           ║")
            print("╠═══════════════════════════════════════════════════════════════╣")
            print("║ Model: \(selectedModel.rawValue)")
            print("║ Error Type: \(type(of: error))")
            print("║ Error: \(error.localizedDescription)")
            print("║ Models Directory: \(modelsDirectory.path)")
            print("║ Directory Exists: \(FileManager.default.fileExists(atPath: modelsDirectory.path))")
            print("║ Directory Writable: \(FileManager.default.isWritableFile(atPath: modelsDirectory.path))")
            print("╚═══════════════════════════════════════════════════════════════╝")
            
            // Log model loading error with comprehensive context
            ErrorLogger.shared.logModelError(error, modelInfo: [
                "model": selectedModel.rawValue,
                "modelPattern": selectedModel.modelPattern,
                "modelsDirectory": modelsDirectory.path,
                "directoryExists": FileManager.default.fileExists(atPath: modelsDirectory.path),
                "directoryWritable": FileManager.default.isWritableFile(atPath: modelsDirectory.path),
                "wasDownloaded": isDownloaded,
                "errorType": String(describing: type(of: error)),
                "fullError": String(describing: error)
            ])
            
            onError?(errorMessage)
        }
    }
    
    /// Get estimated model size for display
    private func getEstimatedSize() -> String {
        switch selectedModel {
        case .tiny: return "75MB"
        case .base: return "145MB"
        case .small: return "485MB"
        case .medium: return "1.5GB"
        }
    }
    
    /// Verify model directory exists and is writable
    /// - Returns: true if directory is ready for use
    private func verifyModelsDirectory() -> Bool {
        let fm = FileManager.default
        
        // Try to create directory if it doesn't exist
        if !fm.fileExists(atPath: modelsDirectory.path) {
            do {
                try fm.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
                print("[US-304] Created model directory: \(modelsDirectory.path)")
            } catch {
                print("[US-304] Failed to create model directory: \(error)")
                return false
            }
        }
        
        // Check if writable
        return fm.isWritableFile(atPath: modelsDirectory.path)
    }
    
    /// Verify model files exist after download
    /// - Returns: Tuple with success flag and descriptive message
    private func verifyModelFilesAfterDownload() -> (success: Bool, message: String) {
        let modelPath = modelsDirectory.appendingPathComponent(selectedModel.modelPattern)
        let fm = FileManager.default
        
        guard fm.fileExists(atPath: modelPath.path) else {
            return (false, "Model directory not found at: \(modelPath.path)")
        }
        
        // List files in model directory
        do {
            let contents = try fm.contentsOfDirectory(atPath: modelPath.path)
            if contents.isEmpty {
                return (false, "Model directory is empty: \(modelPath.path)")
            }
            
            // Calculate total size
            var totalSize: UInt64 = 0
            for file in contents {
                let filePath = modelPath.appendingPathComponent(file)
                if let attrs = try? fm.attributesOfItem(atPath: filePath.path),
                   let fileSize = attrs[.size] as? UInt64 {
                    totalSize += fileSize
                }
            }
            
            let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
            return (true, "Model verified: \(contents.count) files, total size: \(sizeStr)")
        } catch {
            return (false, "Failed to verify model directory: \(error.localizedDescription)")
        }
    }
    
    /// Create a detailed error message for UI display
    /// - Parameter error: The error that occurred
    /// - Returns: User-friendly detailed error message
    private func createDetailedErrorMessage(error: Error) -> String {
        let errorString = String(describing: error).lowercased()
        
        var message = "Failed to download/load the \(selectedModel.displayName) model.\n\n"
        
        // Detect specific error types
        if errorString.contains("network") || errorString.contains("connection") || errorString.contains("url") || errorString.contains("nsurlerror") {
            message += "Cause: Network connection issue\n\n"
            message += "Suggestions:\n"
            message += "• Check your internet connection\n"
            message += "• Verify you can access huggingface.co\n"
            message += "• Try again in a few minutes\n"
            message += "• Check if a firewall is blocking the connection"
        } else if errorString.contains("space") || errorString.contains("disk") || errorString.contains("storage") {
            message += "Cause: Insufficient disk space\n\n"
            message += "Suggestions:\n"
            message += "• Free up disk space\n"
            message += "• Try a smaller model (Tiny or Base)\n"
            message += "• Check available space in ~/Library/Application Support/WispFlow"
        } else if errorString.contains("permission") || errorString.contains("access denied") {
            message += "Cause: Permission denied\n\n"
            message += "Suggestions:\n"
            message += "• Check file permissions for ~/Library/Application Support/WispFlow\n"
            message += "• Try restarting the application\n"
            message += "• Run as administrator if needed"
        } else if errorString.contains("timeout") {
            message += "Cause: Download timed out\n\n"
            message += "Suggestions:\n"
            message += "• Check your internet connection speed\n"
            message += "• Try a smaller model first\n"
            message += "• Retry the download when network is faster"
        } else {
            message += "Cause: \(error.localizedDescription)\n\n"
            message += "Suggestions:\n"
            message += "• Restart the application and try again\n"
            message += "• Check your internet connection\n"
            message += "• Try deleting the model and re-downloading\n"
            message += "• Check Console.app for detailed error logs"
        }
        
        message += "\n\nModel directory: \(modelsDirectory.path)"
        
        return message
    }
    
    /// Retry loading the model after an error
    func retryLoadModel() async {
        // Reset status before retry
        modelStatus = .notDownloaded
        statusMessage = "Retrying..."
        lastErrorMessage = nil
        downloadProgress = 0.0
        
        await loadModel()
    }
    
    /// Check if a model is downloaded
    func isModelDownloaded(_ model: ModelSize) -> Bool {
        let modelPath = modelsDirectory.appendingPathComponent(model.modelPattern)
        return FileManager.default.fileExists(atPath: modelPath.path)
    }
    
    /// Delete a downloaded model
    func deleteModel(_ model: ModelSize) async {
        let modelPath = modelsDirectory.appendingPathComponent(model.modelPattern)
        
        do {
            if FileManager.default.fileExists(atPath: modelPath.path) {
                try FileManager.default.removeItem(at: modelPath)
                print("WhisperManager: Deleted model \(model.rawValue)")
                
                // If this was the active model, reset status
                if model == selectedModel {
                    whisperKit = nil
                    modelStatus = .notDownloaded
                    statusMessage = "Model deleted"
                }
            }
        } catch {
            print("WhisperManager: Failed to delete model: \(error)")
        }
    }
    
    /// Get list of downloaded models
    func getDownloadedModels() -> [ModelSize] {
        return ModelSize.allCases.filter { isModelDownloaded($0) }
    }
    
    // MARK: - Audio Validation
    
    /// Validate audio data before transcription
    /// - Parameters:
    ///   - audioData: Raw audio data (Float32 samples)
    ///   - sampleRate: Sample rate of the audio
    /// - Returns: Validation error if invalid, nil if valid
    private func validateAudioData(_ audioData: Data, sampleRate: Double) -> AudioValidationError? {
        // Check for empty data
        guard !audioData.isEmpty else {
            return .emptyAudioData
        }
        
        // Convert to Float samples for analysis
        let samples = audioData.withUnsafeBytes { buffer -> [Float] in
            let floatBuffer = buffer.bindMemory(to: Float.self)
            return Array(floatBuffer)
        }
        
        guard samples.count > 0 else {
            return .emptyAudioData
        }
        
        // Check sample rate
        if abs(sampleRate - Constants.expectedSampleRate) > 0.01 {
            return .invalidSampleRate(expected: Constants.expectedSampleRate, actual: sampleRate)
        }
        
        // Check duration
        let duration = Double(samples.count) / sampleRate
        if duration < Constants.minimumDuration {
            return .durationTooShort(actual: duration, minimum: Constants.minimumDuration)
        }
        if duration > Constants.maximumDuration {
            return .durationTooLong(actual: duration, maximum: Constants.maximumDuration)
        }
        
        // Check sample range
        var minSample: Float = Float.infinity
        var maxSample: Float = -Float.infinity
        for sample in samples {
            minSample = min(minSample, sample)
            maxSample = max(maxSample, sample)
        }
        
        // Allow small tolerance beyond [-1.0, 1.0] but warn for significant overflow
        let rangeTolerance: Float = 1.1
        if minSample < -rangeTolerance || maxSample > rangeTolerance {
            return .samplesOutOfRange(min: minSample, max: maxSample)
        }
        
        return nil
    }
    
    /// Log detailed audio diagnostics before transcription
    /// - Parameters:
    ///   - audioData: Raw audio data (Float32 samples)
    ///   - sampleRate: Sample rate of the audio
    private func logAudioDiagnostics(audioData: Data, sampleRate: Double) {
        // Convert to Float samples
        let samples = audioData.withUnsafeBytes { buffer -> [Float] in
            let floatBuffer = buffer.bindMemory(to: Float.self)
            return Array(floatBuffer)
        }
        
        // Calculate statistics
        var minSample: Float = Float.infinity
        var maxSample: Float = -Float.infinity
        var sumSquares: Float = 0
        var clippedCount = 0
        var zeroCount = 0
        let zeroThreshold: Float = 1e-7
        
        for sample in samples {
            minSample = min(minSample, sample)
            maxSample = max(maxSample, sample)
            sumSquares += sample * sample
            if abs(sample) > 0.99 {
                clippedCount += 1
            }
            if abs(sample) < zeroThreshold {
                zeroCount += 1
            }
        }
        
        let peakAmplitude = max(abs(minSample), abs(maxSample))
        let peakDb = peakAmplitude > 0 ? 20.0 * log10(peakAmplitude) : -Float.infinity
        let rms = samples.isEmpty ? 0 : sqrt(sumSquares / Float(samples.count))
        let rmsDb = rms > 0 ? 20.0 * log10(rms) : -Float.infinity
        let duration = Double(samples.count) / sampleRate
        let clippingPercent = samples.isEmpty ? 0 : (Double(clippedCount) / Double(samples.count)) * 100
        let zeroPercent = samples.isEmpty ? 0 : (Double(zeroCount) / Double(samples.count)) * 100
        
        // Get first and last 10 samples for verification
        let firstSamples = Array(samples.prefix(10))
        let lastSamples = Array(samples.suffix(10))
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║      AUDIO PIPELINE STAGE 5: TRANSCRIPTION HANDOFF            ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ Byte Count:      \(String(format: "%10d", audioData.count)) bytes                        ║")
        print("║ Sample Count:    \(String(format: "%10d", samples.count)) samples                       ║")
        print("║ Sample Rate:     \(String(format: "%10.0f", sampleRate)) Hz                            ║")
        print("║ Duration:        \(String(format: "%10.2f", duration)) seconds                        ║")
        print("║ Peak Amplitude:  \(String(format: "%10.4f", peakAmplitude)) (linear)                       ║")
        print("║ Peak Level:      \(String(format: "%10.1f", peakDb)) dB                             ║")
        print("║ RMS Level:       \(String(format: "%10.1f", rmsDb)) dB                             ║")
        print("║ Sample Range:    [\(String(format: "%.4f", minSample)), \(String(format: "%.4f", maxSample))]                        ║")
        print("║ Zero Samples:    \(String(format: "%10.1f", zeroPercent))% (\(zeroCount)/\(samples.count))                   ║")
        print("║ Clipping:        \(String(format: "%10.2f", clippingPercent))%                              ║")
        print("║ Format:          Float32 mono PCM                             ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ First 10 samples: \(firstSamples.map { String(format: "%.4f", $0) }.joined(separator: ", "))")
        print("║ Last 10 samples:  \(lastSamples.map { String(format: "%.4f", $0) }.joined(separator: ", "))")
        print("╚═══════════════════════════════════════════════════════════════╝")
        print("WhisperManager: [STAGE 5] ✓ Audio data ready for WhisperKit transcription")
    }
    
    // MARK: - Transcription
    
    /// Transcribe audio data
    /// - Parameters:
    ///   - audioData: Raw audio data (Float32 samples at 16kHz)
    ///   - sampleRate: Sample rate of the audio (should be 16000)
    /// - Returns: Transcribed text or nil if failed
    func transcribe(audioData: Data, sampleRate: Double = 16000.0) async -> String? {
        // Ensure model is loaded
        guard let whisper = whisperKit else {
            statusMessage = "Model not loaded"
            transcriptionStatus = .error("Model not loaded. Please load a model first.")
            
            let error = TranscriptionError.modelNotLoaded
            ErrorLogger.shared.log(
                "Transcription attempted without loaded model",
                category: .model,
                severity: .error,
                context: ["modelStatus": String(describing: modelStatus)]
            )
            
            onError?("Model not loaded")
            onTranscriptionError?(error, audioData, sampleRate)
            return nil
        }
        
        // Log audio diagnostics before transcription
        logAudioDiagnostics(audioData: audioData, sampleRate: sampleRate)
        
        // Validate audio data before transcription
        if let validationError = validateAudioData(audioData, sampleRate: sampleRate) {
            let errorMessage = "Audio validation failed: \(validationError.localizedDescription)"
            statusMessage = "Invalid audio"
            transcriptionStatus = .error(errorMessage)
            print("WhisperManager: \(errorMessage)")
            
            let error = TranscriptionError.audioValidationFailed(validationError.localizedDescription)
            ErrorLogger.shared.log(
                errorMessage,
                category: .audio,
                severity: .error,
                context: [
                    "validationError": String(describing: validationError),
                    "audioDataSize": audioData.count,
                    "sampleRate": sampleRate
                ]
            )
            
            onError?(errorMessage)
            onTranscriptionError?(error, audioData, sampleRate)
            return nil
        }
        
        transcriptionStatus = .transcribing
        statusMessage = "Transcribing..."
        
        do {
            // Convert Data to [Float] samples
            var samples = audioData.withUnsafeBytes { buffer -> [Float] in
                let floatBuffer = buffer.bindMemory(to: Float.self)
                return Array(floatBuffer)
            }
            
            // Normalize samples to [-1.0, 1.0] range if needed
            samples = normalizeAudioSamples(samples)
            
            print("WhisperManager: Transcribing \(samples.count) samples (\(String(format: "%.2f", Double(samples.count) / sampleRate))s)")
            
            // US-606: Create decoding options with language hint
            let languageCode = selectedLanguage.whisperLanguageCode
            let detectLanguage = selectedLanguage == .automatic
            
            let decodingOptions = DecodingOptions(
                task: .transcribe,
                language: languageCode,  // nil for auto-detect
                usePrefillPrompt: true,
                detectLanguage: detectLanguage  // true for auto-detect, false when specific language is set
            )
            
            print("WhisperManager: [US-606] Using language: \(languageCode ?? "auto-detect"), detectLanguage: \(detectLanguage)")
            
            // Perform transcription with language options
            let results = try await whisper.transcribe(audioArray: samples, decodeOptions: decodingOptions)
            
            // Extract text from results (WhisperKit returns an array of TranscriptionResult)
            let transcribedText = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Handle BLANK_AUDIO response from WhisperKit
            if isBlankAudioResponse(transcribedText) {
                let errorDetails = createBlankAudioErrorMessage(audioData: audioData, sampleRate: sampleRate)
                statusMessage = "No speech detected"
                transcriptionStatus = .error(errorDetails)
                print("WhisperManager: Received BLANK_AUDIO - \(errorDetails)")
                
                let error = TranscriptionError.blankAudioResult(details: errorDetails)
                let audioStats = getAudioStats(audioData: audioData, sampleRate: sampleRate)
                ErrorLogger.shared.logBlankAudioResult(audioStats: audioStats)
                
                onTranscriptionError?(error, audioData, sampleRate)
                // Return empty string instead of showing BLANK_AUDIO to user
                return ""
            }
            
            if transcribedText.isEmpty {
                transcriptionStatus = .completed("")
                statusMessage = "No speech detected"
                print("WhisperManager: No speech detected in audio")
                
                let errorDetails = "The recording was successfully processed, but no speech was detected. Try speaking more clearly or check your microphone position."
                let error = TranscriptionError.noSpeechDetected(details: errorDetails)
                onTranscriptionError?(error, audioData, sampleRate)
                return ""
            }
            
            transcriptionStatus = .completed(transcribedText)
            statusMessage = "Transcription complete"
            print("WhisperManager: Transcription result: \(transcribedText)")
            
            onTranscriptionComplete?(transcribedText)
            return transcribedText
            
        } catch {
            let errorMessage = "Transcription failed: \(error.localizedDescription)"
            transcriptionStatus = .error(errorMessage)
            statusMessage = errorMessage
            print("WhisperManager: \(errorMessage)")
            
            let transcriptionError = TranscriptionError.whisperKitError(underlying: error)
            let audioStats = getAudioStats(audioData: audioData, sampleRate: sampleRate)
            ErrorLogger.shared.logTranscriptionError(error, audioInfo: audioStats)
            
            onError?(errorMessage)
            onTranscriptionError?(transcriptionError, audioData, sampleRate)
            return nil
        }
    }
    
    /// Get audio statistics for logging
    private func getAudioStats(audioData: Data, sampleRate: Double) -> [String: Any] {
        let samples = audioData.withUnsafeBytes { buffer -> [Float] in
            let floatBuffer = buffer.bindMemory(to: Float.self)
            return Array(floatBuffer)
        }
        
        var peakAmplitude: Float = 0
        var sumSquares: Float = 0
        for sample in samples {
            let absValue = abs(sample)
            if absValue > peakAmplitude {
                peakAmplitude = absValue
            }
            sumSquares += sample * sample
        }
        let rms = samples.isEmpty ? 0 : sqrt(sumSquares / Float(samples.count))
        let peakDb = peakAmplitude > 0 ? 20.0 * log10(peakAmplitude) : -60.0
        let rmsDb = rms > 0 ? 20.0 * log10(rms) : -60.0
        let duration = Double(samples.count) / sampleRate
        
        return [
            "sampleCount": samples.count,
            "duration": String(format: "%.2fs", duration),
            "peakDb": String(format: "%.1f", peakDb),
            "rmsDb": String(format: "%.1f", rmsDb),
            "sampleRate": Int(sampleRate),
            "model": selectedModel.rawValue
        ]
    }
    
    /// Normalize audio samples to [-1.0, 1.0] range
    /// - Parameter samples: Input audio samples
    /// - Returns: Normalized audio samples
    private func normalizeAudioSamples(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return samples }
        
        // Find current peak amplitude
        var peakAmplitude: Float = 0
        for sample in samples {
            let absValue = abs(sample)
            if absValue > peakAmplitude {
                peakAmplitude = absValue
            }
        }
        
        // If already in range or silent, no normalization needed
        if peakAmplitude <= 1.0 || peakAmplitude < 0.0001 {
            return samples
        }
        
        // Normalize by dividing by peak amplitude
        let normalizationFactor = 1.0 / peakAmplitude
        print("WhisperManager: Normalizing audio (peak=\(String(format: "%.4f", peakAmplitude)), factor=\(String(format: "%.4f", normalizationFactor)))")
        
        return samples.map { $0 * normalizationFactor }
    }
    
    /// Check if transcription result is a BLANK_AUDIO response
    /// - Parameter text: Transcription result text
    /// - Returns: True if the response indicates blank audio
    private func isBlankAudioResponse(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return lowercased.contains("[blank_audio]") ||
               lowercased.contains("[blank audio]") ||
               lowercased.contains("blank_audio") ||
               lowercased == "[blank]" ||
               lowercased == "blank"
    }
    
    /// Create a meaningful error message for BLANK_AUDIO responses
    /// - Parameters:
    ///   - audioData: The audio data that caused the issue
    ///   - sampleRate: The sample rate used
    /// - Returns: A user-friendly error message with possible causes
    private func createBlankAudioErrorMessage(audioData: Data, sampleRate: Double) -> String {
        // Convert to samples for analysis
        let samples = audioData.withUnsafeBytes { buffer -> [Float] in
            let floatBuffer = buffer.bindMemory(to: Float.self)
            return Array(floatBuffer)
        }
        
        // Analyze audio to determine likely cause
        var peakAmplitude: Float = 0
        var sumSquares: Float = 0
        for sample in samples {
            let absValue = abs(sample)
            if absValue > peakAmplitude {
                peakAmplitude = absValue
            }
            sumSquares += sample * sample
        }
        let rms = samples.isEmpty ? 0 : sqrt(sumSquares / Float(samples.count))
        let peakDb = peakAmplitude > 0 ? 20.0 * log10(peakAmplitude) : -60.0
        
        var message = "No speech was detected in your recording. "
        
        if peakDb < -55 {
            message += "The audio appears to be very quiet or silent. Check that your microphone is working and positioned correctly."
        } else if peakDb < -20 {
            message += "The audio level is low. Try speaking closer to the microphone."
        } else if rms < 0.01 {
            message += "Very little audio variation detected. This may indicate background noise only without speech."
        } else {
            message += "The audio was captured but no speech was recognized. Try speaking more clearly or check for background noise."
        }
        
        return message
    }
    
    /// Reset transcription status to idle
    func resetStatus() {
        transcriptionStatus = .idle
        if modelStatus == .ready {
            statusMessage = "\(selectedModel.displayName) ready"
        }
    }
    
    // MARK: - Status
    
    /// Check if the manager is ready to transcribe
    var isReady: Bool {
        return modelStatus == .ready && whisperKit != nil
    }
}
