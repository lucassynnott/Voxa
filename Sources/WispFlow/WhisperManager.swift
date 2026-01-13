import Foundation
import WhisperKit

/// Manages Whisper model loading and audio transcription
/// Handles model download, selection, and transcription pipeline
@MainActor
final class WhisperManager: ObservableObject {
    
    // MARK: - Types
    
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
        static let modelRepo = "argmaxinc/whisperkit-coreml"
        static let expectedSampleRate: Double = 16000.0
        static let minimumDuration: Double = 0.5    // seconds
        static let maximumDuration: Double = 120.0  // seconds
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
    
    /// Called when an error occurs
    var onError: ((String) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        // Load saved model preference
        if let savedModel = UserDefaults.standard.string(forKey: Constants.selectedModelKey),
           let model = ModelSize(rawValue: savedModel) {
            selectedModel = model
        } else {
            selectedModel = .base // Default to base model
        }
        
        print("WhisperManager initialized with model: \(selectedModel.rawValue)")
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
        
        // Check if model is downloaded
        let isDownloaded = isModelDownloaded(selectedModel)
        
        if isDownloaded {
            modelStatus = .loading
            statusMessage = "Loading \(selectedModel.displayName)..."
        } else {
            modelStatus = .downloading(progress: 0.0)
            downloadProgress = 0.0
            statusMessage = "Downloading \(selectedModel.displayName)..."
        }
        
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
                // Set to downloading state while WhisperKit initializes
                // Note: WhisperKit doesn't expose progress callbacks directly,
                // so we simulate progress stages during the download
                modelStatus = .downloading(progress: 0.1)
                downloadProgress = 0.1
                statusMessage = "Downloading \(selectedModel.displayName)..."
            }
            
            whisperKit = try await WhisperKit(config)
            
            // Update progress after successful download/load
            downloadProgress = 1.0
            modelStatus = .ready
            statusMessage = "\(selectedModel.displayName) ready"
            print("WhisperManager: Model loaded successfully")
            
        } catch {
            let errorMessage = "Failed to load model: \(error.localizedDescription)"
            modelStatus = .error(errorMessage)
            statusMessage = errorMessage
            downloadProgress = 0.0
            print("WhisperManager: \(errorMessage)")
            onError?(errorMessage)
        }
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
        
        for sample in samples {
            minSample = min(minSample, sample)
            maxSample = max(maxSample, sample)
            sumSquares += sample * sample
            if abs(sample) > 0.99 {
                clippedCount += 1
            }
        }
        
        let peakAmplitude = max(abs(minSample), abs(maxSample))
        let peakDb = peakAmplitude > 0 ? 20.0 * log10(peakAmplitude) : -Float.infinity
        let rms = samples.isEmpty ? 0 : sqrt(sumSquares / Float(samples.count))
        let rmsDb = rms > 0 ? 20.0 * log10(rms) : -Float.infinity
        let duration = Double(samples.count) / sampleRate
        let clippingPercent = samples.isEmpty ? 0 : (Double(clippedCount) / Double(samples.count)) * 100
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║               WHISPER AUDIO DIAGNOSTICS                       ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ Byte Count:      \(String(format: "%10d", audioData.count)) bytes                        ║")
        print("║ Sample Count:    \(String(format: "%10d", samples.count)) samples                       ║")
        print("║ Sample Rate:     \(String(format: "%10.0f", sampleRate)) Hz                            ║")
        print("║ Duration:        \(String(format: "%10.2f", duration)) seconds                        ║")
        print("║ Peak Amplitude:  \(String(format: "%10.4f", peakAmplitude)) (linear)                       ║")
        print("║ Peak Level:      \(String(format: "%10.1f", peakDb)) dB                             ║")
        print("║ RMS Level:       \(String(format: "%10.1f", rmsDb)) dB                             ║")
        print("║ Sample Range:    [\(String(format: "%.4f", minSample)), \(String(format: "%.4f", maxSample))]                        ║")
        print("║ Clipping:        \(String(format: "%10.2f", clippingPercent))%                              ║")
        print("║ Format:          Float32 mono PCM                             ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
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
            onError?("Model not loaded")
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
            onError?(errorMessage)
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
            
            // Perform transcription
            let results = try await whisper.transcribe(audioArray: samples)
            
            // Extract text from results (WhisperKit returns an array of TranscriptionResult)
            let transcribedText = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Handle BLANK_AUDIO response from WhisperKit
            if isBlankAudioResponse(transcribedText) {
                let errorMessage = createBlankAudioErrorMessage(audioData: audioData, sampleRate: sampleRate)
                statusMessage = "No speech detected"
                transcriptionStatus = .error(errorMessage)
                print("WhisperManager: Received BLANK_AUDIO - \(errorMessage)")
                // Return empty string instead of showing BLANK_AUDIO to user
                return ""
            }
            
            if transcribedText.isEmpty {
                transcriptionStatus = .completed("")
                statusMessage = "No speech detected"
                print("WhisperManager: No speech detected in audio")
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
            onError?(errorMessage)
            return nil
        }
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
        
        if peakDb < -40 {
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
