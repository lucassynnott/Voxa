import Foundation

/// Utility for logging errors to a file for debugging purposes
/// Logs errors with timestamps to ~/.ralph/errors.log
final class ErrorLogger {
    
    // MARK: - Types
    
    /// Categories of errors for better organization in logs
    enum ErrorCategory: String {
        case audio = "AUDIO"
        case transcription = "TRANSCRIPTION"
        case model = "MODEL"
        case textCleanup = "TEXT_CLEANUP"
        case textInsertion = "TEXT_INSERTION"
        case permission = "PERMISSION"
        case general = "GENERAL"
    }
    
    /// Error severity levels
    enum ErrorSeverity: String {
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
    }
    
    // MARK: - Singleton
    
    static let shared = ErrorLogger()
    
    // MARK: - Properties
    
    private let logFileURL: URL
    private let dateFormatter: DateFormatter
    private let fileManager = FileManager.default
    private let writeQueue = DispatchQueue(label: "com.voxa.errorlogger", qos: .utility)
    
    // MARK: - Initialization
    
    private init() {
        // Set up the log file path
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let ralphDirectory = homeDirectory.appendingPathComponent(".ralph", isDirectory: true)
        logFileURL = ralphDirectory.appendingPathComponent("errors.log")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: ralphDirectory.path) {
            try? fileManager.createDirectory(at: ralphDirectory, withIntermediateDirectories: true)
        }
        
        // Set up date formatter
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    }
    
    // MARK: - Logging Methods
    
    /// Log an error with category, severity, and message
    /// - Parameters:
    ///   - message: The error message to log
    ///   - category: Category of the error (audio, transcription, etc.)
    ///   - severity: Severity level (info, warning, error, critical)
    ///   - context: Optional additional context (dictionary of key-value pairs)
    func log(
        _ message: String,
        category: ErrorCategory = .general,
        severity: ErrorSeverity = .error,
        context: [String: Any]? = nil
    ) {
        writeQueue.async { [weak self] in
            guard let self = self else { return }
            
            let timestamp = self.dateFormatter.string(from: Date())
            var logEntry = "[\(timestamp)] [\(severity.rawValue)] [\(category.rawValue)] \(message)"
            
            // Add context if provided
            if let context = context, !context.isEmpty {
                let contextString = context.map { "  \($0.key): \($0.value)" }.joined(separator: "\n")
                logEntry += "\n  Context:\n\(contextString)"
            }
            
            logEntry += "\n"
            
            // Write to file
            self.appendToLogFile(logEntry)
            
            // Also print to console for debugging
            print("[ErrorLogger] \(logEntry)")
        }
    }
    
    /// Log a WhisperKit error with details
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - audioInfo: Optional info about the audio being transcribed
    func logTranscriptionError(_ error: Error, audioInfo: [String: Any]? = nil) {
        var context = audioInfo ?? [:]
        context["errorType"] = String(describing: type(of: error))
        context["localizedDescription"] = error.localizedDescription
        
        log(
            "Transcription failed: \(error.localizedDescription)",
            category: .transcription,
            severity: .error,
            context: context
        )
    }
    
    /// Log an audio capture error
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - deviceInfo: Optional info about the audio device
    func logAudioError(_ error: Error, deviceInfo: [String: Any]? = nil) {
        var context = deviceInfo ?? [:]
        context["errorType"] = String(describing: type(of: error))
        context["localizedDescription"] = error.localizedDescription
        
        log(
            "Audio capture error: \(error.localizedDescription)",
            category: .audio,
            severity: .error,
            context: context
        )
    }
    
    /// Log a model loading error
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - modelInfo: Optional info about the model being loaded
    func logModelError(_ error: Error, modelInfo: [String: Any]? = nil) {
        var context = modelInfo ?? [:]
        context["errorType"] = String(describing: type(of: error))
        context["localizedDescription"] = error.localizedDescription
        
        log(
            "Model error: \(error.localizedDescription)",
            category: .model,
            severity: .error,
            context: context
        )
    }
    
    /// Log a blank audio result
    /// - Parameters:
    ///   - audioStats: Statistics about the audio that produced blank result
    func logBlankAudioResult(audioStats: [String: Any]) {
        log(
            "Blank audio result received (no speech detected)",
            category: .transcription,
            severity: .warning,
            context: audioStats
        )
    }
    
    /// Log a permission error
    /// - Parameters:
    ///   - permissionType: Type of permission (microphone, accessibility, etc.)
    ///   - message: Additional message about the error
    func logPermissionError(permissionType: String, message: String) {
        log(
            "\(permissionType) permission error: \(message)",
            category: .permission,
            severity: .warning,
            context: ["permissionType": permissionType]
        )
    }
    
    // MARK: - File Operations
    
    private func appendToLogFile(_ entry: String) {
        guard let data = entry.data(using: .utf8) else { return }
        
        if fileManager.fileExists(atPath: logFileURL.path) {
            // Append to existing file
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            // Create new file with header
            let header = "# Voxa Error Log\n# Format: [timestamp] [severity] [category] message\n\n"
            let initialData = (header + entry).data(using: .utf8)
            fileManager.createFile(atPath: logFileURL.path, contents: initialData)
        }
    }
    
    /// Clear the log file (for testing or user action)
    func clearLog() {
        writeQueue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.logFileURL)
            print("[ErrorLogger] Log file cleared")
        }
    }
    
    /// Get the path to the log file
    var logFilePath: String {
        return logFileURL.path
    }
    
    /// Read recent log entries
    /// - Parameter count: Maximum number of entries to return
    /// - Returns: Array of recent log entries (most recent first)
    func recentEntries(count: Int = 50) -> [String] {
        guard let content = try? String(contentsOf: logFileURL, encoding: .utf8) else {
            return []
        }
        
        let entries = content.components(separatedBy: "\n\n")
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        
        return Array(entries.suffix(count).reversed())
    }
}
