import Foundation
import LlamaSwift

/// Manages local LLM loading and text generation for text cleanup
/// Uses llama.cpp backend for inference via llama.swift
@MainActor
final class LLMManager: ObservableObject {
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide access
    /// US-701: Added for SettingsContentView in MainWindow
    static let shared = LLMManager()
    
    // MARK: - Types
    
    /// Available LLM model sizes
    enum ModelSize: String, CaseIterable, Identifiable {
        case qwen1_5b = "qwen1.5b"
        case phi3_mini = "phi3-mini"
        case gemma2b = "gemma-2b"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .qwen1_5b: return "Qwen 2.5 1.5B (~1GB)"
            case .phi3_mini: return "Phi-3 Mini 3.8B (~2GB)"
            case .gemma2b: return "Gemma 2B (~1.4GB)"
            }
        }
        
        var description: String {
            switch self {
            case .qwen1_5b: return "Small but capable model. Good balance of speed and quality."
            case .phi3_mini: return "High quality model from Microsoft. Excellent for text cleanup."
            case .gemma2b: return "Google's Gemma model. Fast and efficient."
            }
        }
        
        /// Hugging Face model ID
        var huggingFaceID: String {
            switch self {
            case .qwen1_5b: return "Qwen/Qwen2.5-1.5B-Instruct-GGUF"
            case .phi3_mini: return "microsoft/Phi-3-mini-4k-instruct-gguf"
            case .gemma2b: return "google/gemma-2b-it-GGUF"
            }
        }
        
        /// GGUF filename
        var ggufFilename: String {
            switch self {
            case .qwen1_5b: return "qwen2.5-1.5b-instruct-q4_k_m.gguf"
            case .phi3_mini: return "Phi-3-mini-4k-instruct-q4.gguf"
            case .gemma2b: return "gemma-2b-it.Q4_K_M.gguf"
            }
        }
        
        /// Expected file size in bytes (approximate, for validation)
        /// These are minimum expected sizes - actual may be larger
        var expectedMinimumSizeBytes: Int64 {
            switch self {
            case .qwen1_5b: return 900_000_000   // ~900MB minimum
            case .phi3_mini: return 1_800_000_000 // ~1.8GB minimum
            case .gemma2b: return 1_300_000_000   // ~1.3GB minimum
            }
        }
        
        /// Human-readable expected size
        var expectedSizeDescription: String {
            switch self {
            case .qwen1_5b: return "~1GB"
            case .phi3_mini: return "~2GB"
            case .gemma2b: return "~1.4GB"
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
        
        var isAvailable: Bool {
            if case .ready = self { return true }
            return false
        }
    }
    
    /// Cleanup status
    enum CleanupStatus: Equatable {
        case idle
        case processing
        case completed(String)
        case error(String)
    }
    
    // MARK: - Constants
    
    private struct Constants {
        static let selectedModelKey = "selectedLLMModel"
        static let llmEnabledKey = "llmCleanupEnabled"
        static let contextSize: UInt32 = 2048
        static let batchSize: Int32 = 512
        static let maxTokens: Int = 256
    }
    
    /// System prompt for text cleanup
    static let cleanupSystemPrompt = """
    You are a text cleanup assistant. Your task is to improve transcribed speech by:
    1. Removing filler words (um, uh, like, you know, etc.)
    2. Fixing grammar and punctuation
    3. Maintaining the original meaning and intent
    4. Keeping a natural conversational tone
    5. NOT adding new information or changing the meaning
    
    Important rules:
    - Only return the cleaned text, nothing else
    - Do not add explanations or commentary
    - If the input is very short, just clean it and return
    - Preserve technical terms and proper nouns
    """
    
    // MARK: - Properties
    
    /// Currently selected model size
    @Published var selectedModel: ModelSize {
        didSet {
            UserDefaults.standard.set(selectedModel.rawValue, forKey: Constants.selectedModelKey)
        }
    }
    
    /// Status of the current model
    @Published private(set) var modelStatus: ModelStatus = .notDownloaded
    
    /// Current cleanup status
    @Published private(set) var cleanupStatus: CleanupStatus = .idle
    
    /// Download progress for current model (0.0 to 1.0)
    @Published private(set) var downloadProgress: Double = 0.0
    
    /// Status messages for UI display
    @Published private(set) var statusMessage: String = "No LLM model loaded"
    
    /// Detailed error message for UI display (includes suggestions)
    @Published var lastErrorMessage: String = ""
    
    /// Custom model path (for manual fallback option)
    @Published var customModelPath: String = "" {
        didSet {
            UserDefaults.standard.set(customModelPath, forKey: "customLLMModelPath")
        }
    }
    
    /// Whether to use custom model path instead of downloaded model
    @Published var useCustomModelPath: Bool = false {
        didSet {
            UserDefaults.standard.set(useCustomModelPath, forKey: "useLLMCustomModelPath")
        }
    }
    
    /// Whether LLM cleanup is enabled
    @Published var isLLMEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isLLMEnabled, forKey: Constants.llmEnabledKey)
        }
    }
    
    /// llama.cpp model instance (opaque pointer)
    private var llamaModel: OpaquePointer?
    
    /// llama.cpp context instance (opaque pointer)
    private var llamaContext: OpaquePointer?
    
    /// LLM models directory
    private var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDir = appSupport.appendingPathComponent("Voxa/LLMModels", isDirectory: true)
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        return modelsDir
    }
    
    // MARK: - Callbacks
    
    /// Called when cleanup completes
    var onCleanupComplete: ((String) -> Void)?
    
    /// Called when an error occurs
    var onError: ((String) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        // Load saved preferences
        if let savedModel = UserDefaults.standard.string(forKey: Constants.selectedModelKey),
           let model = ModelSize(rawValue: savedModel) {
            selectedModel = model
        } else {
            selectedModel = .qwen1_5b // Default to Qwen 1.5B
        }
        
        // Load LLM enabled preference (default to true)
        isLLMEnabled = UserDefaults.standard.object(forKey: Constants.llmEnabledKey) as? Bool ?? true
        
        // Load custom model path preferences
        customModelPath = UserDefaults.standard.string(forKey: "customLLMModelPath") ?? ""
        useCustomModelPath = UserDefaults.standard.bool(forKey: "useLLMCustomModelPath")
        
        // Check if model is already downloaded
        if isModelDownloaded(selectedModel) {
            modelStatus = .downloaded
            statusMessage = "\(selectedModel.displayName) available"
        }
        
        print("LLMManager initialized with model: \(selectedModel.rawValue), enabled: \(isLLMEnabled)")
    }
    
    deinit {
        // Free llama resources directly in deinit (can't call actor-isolated methods)
        if let context = llamaContext {
            llama_free(context)
        }
        if let model = llamaModel {
            llama_model_free(model)
        }
    }
    
    // MARK: - Model Management
    
    /// Select a different model
    func selectModel(_ model: ModelSize) {
        guard model != selectedModel else { return }
        
        selectedModel = model
        
        // Unload current model
        unloadModel()
        
        // Check if new model is downloaded
        if isModelDownloaded(model) {
            modelStatus = .downloaded
            statusMessage = "\(model.displayName) available"
        } else {
            modelStatus = .notDownloaded
            statusMessage = "Model not downloaded"
        }
        
        print("LLMManager: Selected model \(model.rawValue)")
    }
    
    /// Unload the current model and free resources
    private func unloadModel() {
        if let context = llamaContext {
            llama_free(context)
            llamaContext = nil
        }
        if let model = llamaModel {
            llama_model_free(model)
            llamaModel = nil
        }
    }
    
    /// Check if a model is downloaded
    func isModelDownloaded(_ model: ModelSize) -> Bool {
        let modelPath = modelsDirectory.appendingPathComponent(model.ggufFilename)
        return FileManager.default.fileExists(atPath: modelPath.path)
    }
    
    /// Get the local path for a model
    func modelPath(for model: ModelSize) -> URL {
        return modelsDirectory.appendingPathComponent(model.ggufFilename)
    }
    
    /// Download the selected model from Hugging Face
    func downloadModel() async {
        guard modelStatus != .downloading(progress: 0), modelStatus != .loading else {
            print("LLMManager: Model is already downloading or loading")
            return
        }
        
        // Clear previous error
        lastErrorMessage = ""
        
        modelStatus = .downloading(progress: 0)
        downloadProgress = 0
        statusMessage = "Checking network connectivity..."
        
        // Construct Hugging Face download URL
        let urlString = "https://huggingface.co/\(selectedModel.huggingFaceID)/resolve/main/\(selectedModel.ggufFilename)"
        
        // Log download URL with boxed output
        logDownloadStart(urlString: urlString, model: selectedModel)
        
        guard let url = URL(string: urlString) else {
            let errorMsg = createDetailedErrorMessage(
                error: NSError(domain: "LLMManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL"]),
                httpStatusCode: nil,
                downloadURL: urlString
            )
            handleDownloadError(errorMsg)
            return
        }
        
        // Check network connectivity before starting download
        statusMessage = "Checking network connectivity..."
        let connectivityResult = await checkNetworkConnectivity(to: url)
        if !connectivityResult.isReachable {
            let errorMsg = createDetailedErrorMessage(
                error: NSError(domain: "LLMManager", code: -1, userInfo: [NSLocalizedDescriptionKey: connectivityResult.message]),
                httpStatusCode: nil,
                downloadURL: urlString
            )
            handleDownloadError(errorMsg)
            return
        }
        
        statusMessage = "Downloading \(selectedModel.displayName) (\(selectedModel.expectedSizeDescription))..."
        
        do {
            let destinationURL = modelPath(for: selectedModel)
            
            // Remove existing file if present (in case of interrupted download)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Download the file with progress tracking using URLSessionDownloadDelegate
            let (tempURL, response) = try await downloadWithProgress(from: url)
            
            // Check for valid response with specific error messages
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "LLMManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
            }
            
            if httpResponse.statusCode != 200 {
                let errorMsg = createDetailedErrorMessage(
                    error: NSError(domain: "LLMManager", code: httpResponse.statusCode, userInfo: [:]),
                    httpStatusCode: httpResponse.statusCode,
                    downloadURL: urlString
                )
                handleDownloadError(errorMsg)
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempURL)
                return
            }
            
            // Move downloaded file to destination
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
            
            // Verify the downloaded file
            let verificationResult = verifyDownloadedModel(at: destinationURL, expectedModel: selectedModel)
            if !verificationResult.isValid {
                // Log the verification failure
                logVerificationFailure(result: verificationResult, destinationURL: destinationURL)
                
                // Still mark as downloaded but with warning
                modelStatus = .downloaded
                downloadProgress = 1.0
                statusMessage = "⚠️ Download complete but file size may indicate partial download"
                print("LLMManager: WARNING - \(verificationResult.message)")
            } else {
                modelStatus = .downloaded
                downloadProgress = 1.0
                statusMessage = "\(selectedModel.displayName) downloaded"
                logDownloadSuccess(destinationURL: destinationURL, fileSize: verificationResult.actualSize)
            }
            
        } catch {
            let errorMsg = createDetailedErrorMessage(
                error: error,
                httpStatusCode: nil,
                downloadURL: urlString
            )
            handleDownloadError(errorMsg)
        }
    }
    
    /// Retry downloading the model (resets error state and tries again)
    func retryDownload() async {
        // Reset error state
        lastErrorMessage = ""
        modelStatus = .notDownloaded
        statusMessage = "Retrying download..."
        
        // Try downloading again
        await downloadModel()
    }
    
    /// Download file with progress tracking
    private func downloadWithProgress(from url: URL) async throws -> (URL, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = DownloadProgressDelegate { [weak self] progress, bytesWritten, totalBytes in
                Task { @MainActor in
                    self?.downloadProgress = progress
                    self?.modelStatus = .downloading(progress: progress)
                    let bytesStr = self?.formatBytes(totalBytes) ?? ""
                    let downloadedStr = self?.formatBytes(bytesWritten) ?? ""
                    self?.statusMessage = "Downloading... \(Int(progress * 100))% (\(downloadedStr) / \(bytesStr))"
                }
            }
            
            // Configure session with timeout
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30  // 30 seconds for initial connection
            config.timeoutIntervalForResource = 3600  // 1 hour for full download (large files)
            
            let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
            let task = session.downloadTask(with: url) { tempURL, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let tempURL = tempURL, let response = response {
                    // Copy temp file to a stable location before returning
                    let stableURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    do {
                        try FileManager.default.copyItem(at: tempURL, to: stableURL)
                        continuation.resume(returning: (stableURL, response))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume(throwing: NSError(domain: "LLMManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unknown download error"]))
                }
            }
            task.resume()
        }
    }
    
    // MARK: - Network & Download Helpers
    
    /// Check network connectivity to a URL before attempting download
    private func checkNetworkConnectivity(to url: URL) async -> (isReachable: Bool, message: String) {
        // Try a HEAD request to check if the URL is reachable
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10  // 10 second timeout for connectivity check
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    return (true, "Connected")
                case 401, 403:
                    return (false, "Access denied. The model may require authentication or is not publicly available.")
                case 404:
                    return (false, "Model not found. The download URL may have changed or the model was removed.")
                case 500...599:
                    return (false, "Hugging Face server error. Please try again later.")
                default:
                    return (false, "Server returned status \(httpResponse.statusCode)")
                }
            }
            return (true, "Connected")
        } catch let error as NSError {
            if error.domain == NSURLErrorDomain {
                switch error.code {
                case NSURLErrorNotConnectedToInternet:
                    return (false, "No internet connection. Please check your network settings.")
                case NSURLErrorTimedOut:
                    return (false, "Connection timed out. The server may be slow or unreachable.")
                case NSURLErrorCannotFindHost:
                    return (false, "Cannot reach huggingface.co. Please check your internet connection.")
                case NSURLErrorNetworkConnectionLost:
                    return (false, "Network connection lost. Please check your connection and try again.")
                case NSURLErrorSecureConnectionFailed:
                    return (false, "Secure connection failed. There may be a network security issue.")
                default:
                    return (false, "Network error: \(error.localizedDescription)")
                }
            }
            return (false, "Connection check failed: \(error.localizedDescription)")
        }
    }
    
    /// Create a detailed error message based on the error type and HTTP status code
    private func createDetailedErrorMessage(error: Error, httpStatusCode: Int?, downloadURL: String) -> String {
        var message = ""
        var suggestion = ""
        
        if let statusCode = httpStatusCode {
            switch statusCode {
            case 401:
                message = "Authentication required (HTTP 401)"
                suggestion = "This model may require a Hugging Face account. Try using the manual model path option instead."
            case 403:
                message = "Access denied (HTTP 403)"
                suggestion = "You don't have permission to download this model. It may be restricted or require acceptance of terms. Try using the manual model path option."
            case 404:
                message = "Model not found (HTTP 404)"
                suggestion = "The model file doesn't exist at the expected URL. The model name or URL may have changed. Try a different model or use the manual model path option."
            case 429:
                message = "Too many requests (HTTP 429)"
                suggestion = "Rate limit exceeded. Please wait a few minutes and try again."
            case 500...599:
                message = "Server error (HTTP \(statusCode))"
                suggestion = "Hugging Face is experiencing issues. Please try again later."
            default:
                message = "Download failed (HTTP \(statusCode))"
                suggestion = "An unexpected HTTP error occurred. Check your network connection and try again."
            }
        } else {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorNotConnectedToInternet:
                    message = "No internet connection"
                    suggestion = "Please connect to the internet and try again."
                case NSURLErrorTimedOut:
                    message = "Download timed out"
                    suggestion = "The download took too long. Check your internet speed and try again, or use the manual model path option."
                case NSURLErrorCannotFindHost:
                    message = "Cannot reach download server"
                    suggestion = "Unable to connect to huggingface.co. Check your internet connection and firewall settings."
                case NSURLErrorNetworkConnectionLost:
                    message = "Network connection lost"
                    suggestion = "The connection was interrupted. Please check your network and try again."
                case NSURLErrorCancelled:
                    message = "Download cancelled"
                    suggestion = "The download was cancelled. Click retry to start again."
                default:
                    message = "Network error: \(error.localizedDescription)"
                    suggestion = "Check your internet connection and try again."
                }
            } else {
                message = "Download failed: \(error.localizedDescription)"
                suggestion = "Try again or use the manual model path option."
            }
        }
        
        return """
        \(message)
        
        Download URL: \(downloadURL)
        
        Suggestion: \(suggestion)
        """
    }
    
    /// Handle download error - update state and log
    private func handleDownloadError(_ errorMessage: String) {
        lastErrorMessage = errorMessage
        modelStatus = .error("Download failed")
        statusMessage = "Download failed - tap for details"
        downloadProgress = 0
        
        // Log error with boxed output
        print("""
        ╔═══════════════════════════════════════════════════════════════════╗
        ║  [US-305] LLM DOWNLOAD ERROR                                      ║
        ╠═══════════════════════════════════════════════════════════════════╣
        ║  Model: \(selectedModel.displayName.padding(toLength: 52, withPad: " ", startingAt: 0)) ║
        ╠═══════════════════════════════════════════════════════════════════╣
        \(errorMessage.split(separator: "\n").map { "║  \(String($0).padding(toLength: 63, withPad: " ", startingAt: 0)) ║" }.joined(separator: "\n"))
        ╚═══════════════════════════════════════════════════════════════════╝
        """)
        
        // Log to ErrorLogger
        let downloadError = NSError(domain: "LLMDownload", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        ErrorLogger.shared.logModelError(downloadError, modelInfo: [
            "model": selectedModel.rawValue,
            "huggingFaceID": selectedModel.huggingFaceID,
            "ggufFilename": selectedModel.ggufFilename
        ])
        
        onError?(errorMessage)
    }
    
    /// Verify downloaded model file exists and has expected size
    private func verifyDownloadedModel(at url: URL, expectedModel: ModelSize) -> (isValid: Bool, message: String, actualSize: Int64) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return (false, "Model file not found after download", 0)
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            if fileSize < expectedModel.expectedMinimumSizeBytes {
                let expectedStr = formatBytes(expectedModel.expectedMinimumSizeBytes)
                let actualStr = formatBytes(fileSize)
                return (false, "Downloaded file is too small (\(actualStr)). Expected at least \(expectedStr). The download may be incomplete.", fileSize)
            }
            
            return (true, "Model file verified successfully", fileSize)
        } catch {
            return (false, "Could not verify file: \(error.localizedDescription)", 0)
        }
    }
    
    /// Format bytes into human-readable string
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Log download start with boxed output
    private func logDownloadStart(urlString: String, model: ModelSize) {
        print("""
        ╔═══════════════════════════════════════════════════════════════════╗
        ║  [US-305] LLM MODEL DOWNLOAD STARTING                             ║
        ╠═══════════════════════════════════════════════════════════════════╣
        ║  Model: \(model.displayName.padding(toLength: 52, withPad: " ", startingAt: 0)) ║
        ║  Expected Size: \(model.expectedSizeDescription.padding(toLength: 44, withPad: " ", startingAt: 0)) ║
        ╠═══════════════════════════════════════════════════════════════════╣
        ║  Download URL:                                                    ║
        ║  \(urlString.padding(toLength: 63, withPad: " ", startingAt: 0)) ║
        ╚═══════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// Log download success
    private func logDownloadSuccess(destinationURL: URL, fileSize: Int64) {
        let sizeStr = formatBytes(fileSize)
        print("""
        ╔═══════════════════════════════════════════════════════════════════╗
        ║  [US-305] LLM MODEL DOWNLOAD SUCCESS ✓                            ║
        ╠═══════════════════════════════════════════════════════════════════╣
        ║  File: \(destinationURL.lastPathComponent.padding(toLength: 53, withPad: " ", startingAt: 0)) ║
        ║  Size: \(sizeStr.padding(toLength: 53, withPad: " ", startingAt: 0)) ║
        ║  Path: \(destinationURL.path.prefix(53).padding(toLength: 53, withPad: " ", startingAt: 0)) ║
        ╚═══════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// Log verification failure
    private func logVerificationFailure(result: (isValid: Bool, message: String, actualSize: Int64), destinationURL: URL) {
        print("""
        ╔═══════════════════════════════════════════════════════════════════╗
        ║  [US-305] LLM MODEL VERIFICATION WARNING ⚠️                        ║
        ╠═══════════════════════════════════════════════════════════════════╣
        ║  File: \(destinationURL.lastPathComponent.padding(toLength: 53, withPad: " ", startingAt: 0)) ║
        ║  Issue: \(result.message.prefix(52).padding(toLength: 52, withPad: " ", startingAt: 0)) ║
        ║  Actual Size: \(formatBytes(result.actualSize).padding(toLength: 47, withPad: " ", startingAt: 0)) ║
        ╚═══════════════════════════════════════════════════════════════════╝
        """)
    }
    
    /// Load model from custom path (manual fallback option)
    func loadModelFromCustomPath() async {
        guard !customModelPath.isEmpty else {
            let errorMsg = "No custom model path specified"
            lastErrorMessage = errorMsg
            modelStatus = .error(errorMsg)
            statusMessage = errorMsg
            onError?(errorMsg)
            return
        }
        
        let customURL = URL(fileURLWithPath: customModelPath)
        
        // Verify the file exists
        guard FileManager.default.fileExists(atPath: customURL.path) else {
            let errorMsg = "Custom model file not found at: \(customModelPath)"
            lastErrorMessage = errorMsg
            modelStatus = .error(errorMsg)
            statusMessage = errorMsg
            onError?(errorMsg)
            return
        }
        
        // Verify it's a GGUF file
        guard customURL.pathExtension.lowercased() == "gguf" else {
            let errorMsg = "Invalid file type. Please select a .gguf model file."
            lastErrorMessage = errorMsg
            modelStatus = .error(errorMsg)
            statusMessage = errorMsg
            onError?(errorMsg)
            return
        }
        
        print("""
        ╔═══════════════════════════════════════════════════════════════════╗
        ║  [US-305] LOADING CUSTOM LLM MODEL                                ║
        ╠═══════════════════════════════════════════════════════════════════╣
        ║  Path: \(customURL.path.prefix(53).padding(toLength: 53, withPad: " ", startingAt: 0)) ║
        ╚═══════════════════════════════════════════════════════════════════╝
        """)
        
        modelStatus = .loading
        statusMessage = "Loading custom model..."
        
        do {
            // Load model on background thread
            let result = try await Task.detached {
                return try self.loadLlamaModel(at: customURL)
            }.value
            
            self.llamaModel = result.model
            self.llamaContext = result.context
            
            modelStatus = .ready
            statusMessage = "Custom model ready"
            print("LLMManager: Custom model loaded successfully from \(customURL.path)")
            
        } catch {
            let errorMessage = "Failed to load custom model: \(error.localizedDescription)"
            lastErrorMessage = errorMessage
            modelStatus = .error(errorMessage)
            statusMessage = errorMessage
            unloadModel()
            print("LLMManager: \(errorMessage)")
            onError?(errorMessage)
        }
    }
    
    /// Load the selected model
    func loadModel() async {
        guard modelStatus != .loading else {
            print("LLMManager: Model is already loading")
            return
        }
        
        // Download if not available
        if !isModelDownloaded(selectedModel) {
            await downloadModel()
        }
        
        guard isModelDownloaded(selectedModel) else {
            let errorMessage = "Model not downloaded"
            modelStatus = .error(errorMessage)
            statusMessage = errorMessage
            onError?(errorMessage)
            return
        }
        
        modelStatus = .loading
        statusMessage = "Loading \(selectedModel.displayName)..."
        
        // Run heavy loading on background thread
        let modelURL = modelPath(for: selectedModel)
        
        do {
            // Load model on background thread
            let result = try await Task.detached {
                return try self.loadLlamaModel(at: modelURL)
            }.value
            
            self.llamaModel = result.model
            self.llamaContext = result.context
            
            modelStatus = .ready
            statusMessage = "\(selectedModel.displayName) ready"
            print("LLMManager: Model loaded successfully")
            
        } catch {
            let errorMessage = "Failed to load model: \(error.localizedDescription)"
            modelStatus = .error(errorMessage)
            statusMessage = errorMessage
            unloadModel()
            print("LLMManager: \(errorMessage)")
            onError?(errorMessage)
        }
    }
    
    /// Load llama.cpp model (runs on background thread)
    private nonisolated func loadLlamaModel(at url: URL) throws -> (model: OpaquePointer, context: OpaquePointer) {
        // Initialize llama backend
        llama_backend_init()
        
        // Load model
        var modelParams = llama_model_default_params()
        guard let model = llama_model_load_from_file(url.path, modelParams) else {
            throw NSError(domain: "LLMManager", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to load model file"])
        }
        
        // Create context
        var contextParams = llama_context_default_params()
        contextParams.n_ctx = Constants.contextSize
        contextParams.n_batch = UInt32(Constants.batchSize)
        
        guard let context = llama_init_from_model(model, contextParams) else {
            llama_model_free(model)
            throw NSError(domain: "LLMManager", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to create model context"])
        }
        
        return (model, context)
    }
    
    /// Delete a downloaded model
    func deleteModel(_ model: ModelSize) {
        let modelPath = self.modelPath(for: model)
        
        do {
            if FileManager.default.fileExists(atPath: modelPath.path) {
                try FileManager.default.removeItem(at: modelPath)
                print("LLMManager: Deleted model \(model.rawValue)")
                
                // If this was the active model, reset status
                if model == selectedModel {
                    unloadModel()
                    modelStatus = .notDownloaded
                    statusMessage = "Model deleted"
                }
            }
        } catch {
            print("LLMManager: Failed to delete model: \(error)")
        }
    }
    
    /// Get list of downloaded models
    func getDownloadedModels() -> [ModelSize] {
        return ModelSize.allCases.filter { isModelDownloaded($0) }
    }
    
    // MARK: - Text Cleanup
    
    /// Clean up transcribed text using the LLM
    /// - Parameter text: Raw transcribed text
    /// - Returns: Cleaned text or nil if LLM unavailable
    func cleanupText(_ text: String) async -> String? {
        guard isLLMEnabled else {
            print("LLMManager: LLM cleanup disabled")
            return nil
        }
        
        guard let model = llamaModel, let context = llamaContext, modelStatus == .ready else {
            print("LLMManager: Model not ready for cleanup")
            return nil
        }
        
        // Skip very short text
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.count > 5 else {
            print("LLMManager: Text too short for LLM cleanup")
            return nil
        }
        
        cleanupStatus = .processing
        statusMessage = "Cleaning up text..."
        
        print("LLMManager: Starting LLM cleanup for: \(trimmedText)")
        
        // Create prompt
        let prompt = """
        <|system|>
        \(Self.cleanupSystemPrompt)
        </s>
        <|user|>
        Clean up this transcribed speech:
        
        \(trimmedText)
        </s>
        <|assistant|>
        """
        
        do {
            // Run generation on background thread
            let result = try await Task.detached { [model, context] in
                return try self.generateText(prompt: prompt, model: model, context: context)
            }.value
            
            // Clean up the result
            let cleanedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Validate result
            guard !cleanedResult.isEmpty, cleanedResult.count > 2 else {
                print("LLMManager: LLM returned empty or invalid result")
                cleanupStatus = .error("Invalid LLM response")
                return nil
            }
            
            cleanupStatus = .completed(cleanedResult)
            statusMessage = "Cleanup complete"
            print("LLMManager: Cleanup result: \(cleanedResult)")
            
            onCleanupComplete?(cleanedResult)
            return cleanedResult
            
        } catch {
            let errorMessage = "LLM cleanup failed: \(error.localizedDescription)"
            cleanupStatus = .error(errorMessage)
            statusMessage = errorMessage
            print("LLMManager: \(errorMessage)")
            onError?(errorMessage)
            return nil
        }
    }
    
    /// Generate text using llama.cpp (runs on background thread)
    private nonisolated func generateText(prompt: String, model: OpaquePointer, context: OpaquePointer) throws -> String {
        let vocab = llama_model_get_vocab(model)
        
        // Tokenize the prompt
        let utf8Count = prompt.utf8.count
        let maxTokenCount = utf8Count + 1
        var tokens = [llama_token](repeating: 0, count: maxTokenCount)
        
        let tokenCount = llama_tokenize(
            vocab,
            prompt,
            Int32(utf8Count),
            &tokens,
            Int32(maxTokenCount),
            true,  // add BOS
            true   // special tokens
        )
        
        guard tokenCount > 0 else {
            throw NSError(domain: "LLMManager", code: 20, userInfo: [NSLocalizedDescriptionKey: "Failed to tokenize prompt"])
        }
        
        let promptTokens = Array(tokens.prefix(Int(tokenCount)))
        
        // Create batch
        var batch = llama_batch_init(Int32(Constants.batchSize), 0, 1)
        defer { llama_batch_free(batch) }
        
        // Prepare batch with prompt tokens
        batch.n_tokens = Int32(promptTokens.count)
        
        for i in 0..<promptTokens.count {
            batch.token[i] = promptTokens[i]
            batch.pos[i] = Int32(i)
            batch.n_seq_id[i] = 1
            
            if let seq_ids = batch.seq_id, let seq_id = seq_ids[i] {
                seq_id[0] = 0
            }
            
            batch.logits[i] = 0
        }
        
        // Only compute logits for the last token
        if batch.n_tokens > 0 {
            batch.logits[Int(batch.n_tokens) - 1] = 1
        }
        
        // Decode the prompt
        guard llama_decode(context, batch) == 0 else {
            throw NSError(domain: "LLMManager", code: 21, userInfo: [NSLocalizedDescriptionKey: "llama_decode failed"])
        }
        
        // Generate tokens
        var generatedText = ""
        var n_cur = batch.n_tokens
        let eosToken = llama_vocab_eos(vocab)
        
        for _ in 0..<Constants.maxTokens {
            // Get logits for the last token
            guard let logits = llama_get_logits_ith(context, batch.n_tokens - 1) else {
                break
            }
            
            // Simple greedy sampling
            let vocabSize = llama_vocab_n_tokens(vocab)
            var maxLogit = logits[0]
            var nextToken: llama_token = 0
            
            for i in 1..<Int(vocabSize) {
                if logits[i] > maxLogit {
                    maxLogit = logits[i]
                    nextToken = llama_token(i)
                }
            }
            
            // Check for EOS
            if nextToken == eosToken {
                break
            }
            
            // Convert token to text
            var buffer = [CChar](repeating: 0, count: 32)
            let length = llama_token_to_piece(
                vocab,
                nextToken,
                &buffer,
                Int32(buffer.count),
                0,
                false
            )
            
            if length > 0 {
                let tokenText = String(cString: buffer)
                generatedText += tokenText
            }
            
            // Prepare batch for next token
            batch.n_tokens = 1
            batch.token[0] = nextToken
            batch.pos[0] = n_cur
            batch.n_seq_id[0] = 1
            
            if let seq_ids = batch.seq_id, let seq_id = seq_ids[0] {
                seq_id[0] = 0
            }
            
            batch.logits[0] = 1
            n_cur += 1
            
            // Decode
            guard llama_decode(context, batch) == 0 else {
                break
            }
        }
        
        return generatedText
    }
    
    /// Reset cleanup status to idle
    func resetStatus() {
        cleanupStatus = .idle
        if modelStatus == .ready {
            statusMessage = "\(selectedModel.displayName) ready"
        }
    }
    
    // MARK: - Status
    
    /// Check if the manager is ready for text cleanup
    var isReady: Bool {
        return modelStatus == .ready && llamaModel != nil && llamaContext != nil && isLLMEnabled
    }
}

// MARK: - Download Progress Delegate

private class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    /// Progress handler with progress percentage, bytes written, and total bytes
    private let progressHandler: (Double, Int64, Int64) -> Void
    
    init(progressHandler: @escaping (Double, Int64, Int64) -> Void) {
        self.progressHandler = progressHandler
        super.init()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            progressHandler(progress, totalBytesWritten, totalBytesExpectedToWrite)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled in the completion handler
    }
}
