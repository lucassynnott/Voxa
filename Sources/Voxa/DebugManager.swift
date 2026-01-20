import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

/// Manages debug mode state and provides shared access to debug functionality
/// Handles debug mode persistence and provides debug data storage
@MainActor
final class DebugManager: ObservableObject {
    
    // MARK: - Types

    /// US-046: Log level for debug output filtering
    enum LogLevel: String, CaseIterable, Identifiable {
        case verbose = "Verbose"
        case debug = "Debug"
        case info = "Info"
        case warning = "Warning"
        case error = "Error"

        var id: String { rawValue }

        /// Icon for this log level
        var icon: String {
            switch self {
            case .verbose: return "text.alignleft"
            case .debug: return "ladybug"
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            }
        }

        /// Color for this log level
        var colorName: String {
            switch self {
            case .verbose: return "textTertiary"
            case .debug: return "textSecondary"
            case .info: return "info"
            case .warning: return "warning"
            case .error: return "error"
            }
        }

        /// Description for this log level
        var description: String {
            switch self {
            case .verbose: return "All debug output including detailed traces"
            case .debug: return "Debug information and diagnostics"
            case .info: return "General information and progress messages"
            case .warning: return "Warnings and potential issues"
            case .error: return "Errors and critical failures only"
            }
        }

        /// Numeric priority (lower = more verbose)
        var priority: Int {
            switch self {
            case .verbose: return 0
            case .debug: return 1
            case .info: return 2
            case .warning: return 3
            case .error: return 4
            }
        }

        /// Short prefix for log file entries
        var prefix: String {
            switch self {
            case .verbose: return "VERBOSE"
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARN"
            case .error: return "ERROR"
            }
        }
    }
    
    /// Debug log entry for display
    struct LogEntry: Identifiable, Equatable {
        let id = UUID()
        let timestamp: Date
        let category: Category
        let level: LogLevel
        let message: String
        let details: String?

        /// US-046: Initialize with default info level for backwards compatibility
        init(timestamp: Date, category: Category, message: String, details: String? = nil) {
            self.timestamp = timestamp
            self.category = category
            self.level = .info
            self.message = message
            self.details = details
        }

        /// US-046: Initialize with explicit log level
        init(timestamp: Date, category: Category, level: LogLevel, message: String, details: String? = nil) {
            self.timestamp = timestamp
            self.category = category
            self.level = level
            self.message = message
            self.details = details
        }

        enum Category: String {
            case audio = "Audio"
            case transcription = "Transcription"
            case model = "Model"
            case system = "System"

            var icon: String {
                switch self {
                case .audio: return "waveform"
                case .transcription: return "text.bubble"
                case .model: return "cpu"
                case .system: return "gear"
                }
            }
        }
    }
    
    /// Audio debug data for waveform visualization
    struct AudioDebugData: Equatable {
        let samples: [Float]
        let sampleRate: Double
        let duration: TimeInterval
        let peakLevel: Float
        let rmsLevel: Float
        
        static func == (lhs: AudioDebugData, rhs: AudioDebugData) -> Bool {
            return lhs.duration == rhs.duration &&
                   lhs.peakLevel == rhs.peakLevel &&
                   lhs.rmsLevel == rhs.rmsLevel
        }
    }
    
    /// Transcription debug data for comparison
    struct TranscriptionDebugData: Equatable {
        let rawText: String
        let cleanedText: String
        let processingTime: TimeInterval
        let modelUsed: String
    }
    
    // MARK: - US-707: System Info
    
    /// System information for debugging
    struct SystemInfo {
        let appVersion: String
        let buildNumber: String
        let macOSVersion: String
        let machineModel: String
        let processorInfo: String
        let memorySize: String
        
        /// Get current system information
        static func current() -> SystemInfo {
            // App version
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
            
            // macOS version
            let osVersion = ProcessInfo.processInfo.operatingSystemVersion
            let macOSVersion = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
            
            // Machine model (e.g., "MacBookPro18,3")
            var machineModel = "Unknown"
            var size = 0
            sysctlbyname("hw.model", nil, &size, nil, 0)
            if size > 0 {
                var model = [CChar](repeating: 0, count: size)
                sysctlbyname("hw.model", &model, &size, nil, 0)
                machineModel = String(cString: model)
            }
            
            // Processor info
            var processorInfo = "Unknown"
            size = 0
            sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
            if size > 0 {
                var brand = [CChar](repeating: 0, count: size)
                sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
                processorInfo = String(cString: brand)
            }
            
            // Memory size
            let memoryBytes = ProcessInfo.processInfo.physicalMemory
            let memoryGB = Double(memoryBytes) / (1024 * 1024 * 1024)
            let memorySize = String(format: "%.0f GB", memoryGB)
            
            return SystemInfo(
                appVersion: appVersion,
                buildNumber: buildNumber,
                macOSVersion: macOSVersion,
                machineModel: machineModel,
                processorInfo: processorInfo,
                memorySize: memorySize
            )
        }
        
        /// Formatted string for clipboard/export
        var formattedString: String {
            return """
            Voxa v\(appVersion) (Build \(buildNumber))
            macOS \(macOSVersion)
            Model: \(machineModel)
            Processor: \(processorInfo)
            Memory: \(memorySize)
            """
        }
    }
    
    // MARK: - Constants

    private struct Constants {
        static let debugModeKey = "debugModeEnabled"
        static let silenceDetectionDisabledKey = "silenceDetectionDisabled"
        static let autoSaveRecordingsKey = "autoSaveRecordingsEnabled"
        static let logLevelKey = "debugLogLevel"
        static let fileLoggingEnabledKey = "debugFileLoggingEnabled"  // US-046
        static let maxLogEntries = 500
        static let maxLogFileSizeBytes = 10 * 1024 * 1024  // 10 MB max log file size
        // US-047: Log rotation settings
        static let maxRetainedLogFiles = 5  // Keep up to 5 rotated log files (debug.1.log through debug.5.log)
    }

    // MARK: - US-046: Sensitive Data Patterns

    /// Patterns that should be redacted from logs to protect sensitive data
    private static let sensitivePatterns: [(pattern: String, replacement: String)] = [
        // API keys and tokens
        ("(api[_-]?key|apikey|token|secret|password|credential)[\\s]*[:=][\\s]*[\"']?[A-Za-z0-9_\\-\\.]+[\"']?", "$1=[REDACTED]"),
        // Email addresses
        ("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}", "[EMAIL_REDACTED]"),
        // File paths that might contain usernames (but keep the filename)
        ("/Users/[^/]+/", "/Users/[USER]/"),
        // Bearer tokens
        ("Bearer\\s+[A-Za-z0-9_\\-\\.]+", "Bearer [REDACTED]"),
        // Common secret patterns
        ("(sk|pk|key)[_-][a-zA-Z0-9]{20,}", "[API_KEY_REDACTED]"),
    ]
    
    // MARK: - Singleton
    
    static let shared = DebugManager()
    
    // MARK: - Properties
    
    /// Whether debug mode is enabled
    @Published var isDebugModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDebugModeEnabled, forKey: Constants.debugModeKey)
            if isDebugModeEnabled {
                addLogEntry(category: .system, message: "Debug mode enabled")
            } else {
                addLogEntry(category: .system, message: "Debug mode disabled")
                // Re-enable silence detection when debug mode is disabled
                if isSilenceDetectionDisabled {
                    isSilenceDetectionDisabled = false
                }
            }
        }
    }
    
    /// Whether silence detection is disabled (only available in debug mode)
    @Published var isSilenceDetectionDisabled: Bool {
        didSet {
            UserDefaults.standard.set(isSilenceDetectionDisabled, forKey: Constants.silenceDetectionDisabledKey)
            if isSilenceDetectionDisabled {
                addLogEntry(category: .system, message: "Silence detection disabled (debug override)")
            } else {
                addLogEntry(category: .system, message: "Silence detection enabled")
            }
        }
    }
    
    /// US-306: Whether to automatically save recordings to Documents folder
    @Published var isAutoSaveEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAutoSaveEnabled, forKey: Constants.autoSaveRecordingsKey)
            if isAutoSaveEnabled {
                addLogEntry(category: .system, message: "Auto-save recordings enabled (saves to Documents/Voxa/DebugRecordings)")
            } else {
                addLogEntry(category: .system, message: "Auto-save recordings disabled")
            }
        }
    }
    
    /// US-046: Selected log level for filtering debug output
    @Published var selectedLogLevel: LogLevel {
        didSet {
            UserDefaults.standard.set(selectedLogLevel.rawValue, forKey: Constants.logLevelKey)
            addLogEntry(category: .system, message: "Log level changed to \(selectedLogLevel.rawValue)")
        }
    }

    /// US-046: Whether file logging is enabled
    @Published var isFileLoggingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isFileLoggingEnabled, forKey: Constants.fileLoggingEnabledKey)
            if isFileLoggingEnabled {
                addLogEntry(category: .system, message: "File logging enabled (\(logFileURL.path))")
            } else {
                addLogEntry(category: .system, message: "File logging disabled")
            }
        }
    }

    /// Log entries for the debug window
    @Published private(set) var logEntries: [LogEntry] = []

    /// Last recorded audio data for waveform visualization
    @Published private(set) var lastAudioData: AudioDebugData?

    /// Last transcription data for raw vs cleaned comparison
    @Published private(set) var lastTranscriptionData: TranscriptionDebugData?

    /// Raw audio data for WAV export
    private(set) var lastRawAudioData: Data?
    private(set) var lastRawAudioSampleRate: Double = 16000.0

    // MARK: - US-046: File Logging Properties

    /// URL for the debug log file
    private let logFileURL: URL

    /// Queue for async file writes
    private let fileWriteQueue = DispatchQueue(label: "com.voxa.debuglogger.filewrite", qos: .utility)

    /// File manager instance
    private let fileManager = FileManager.default

    /// Date formatter for log entries
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    // MARK: - Initialization

    private init() {
        // US-046: Set up log file path
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let ralphDirectory = homeDirectory.appendingPathComponent(".ralph", isDirectory: true)
        logFileURL = ralphDirectory.appendingPathComponent("debug.log")

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: ralphDirectory.path) {
            try? fileManager.createDirectory(at: ralphDirectory, withIntermediateDirectories: true)
        }

        // Load settings from UserDefaults
        isDebugModeEnabled = UserDefaults.standard.bool(forKey: Constants.debugModeKey)
        isSilenceDetectionDisabled = UserDefaults.standard.bool(forKey: Constants.silenceDetectionDisabledKey)
        isAutoSaveEnabled = UserDefaults.standard.bool(forKey: Constants.autoSaveRecordingsKey)
        isFileLoggingEnabled = UserDefaults.standard.bool(forKey: Constants.fileLoggingEnabledKey)

        // US-046: Load log level from UserDefaults
        if let logLevelString = UserDefaults.standard.string(forKey: Constants.logLevelKey),
           let logLevel = LogLevel(rawValue: logLevelString) {
            selectedLogLevel = logLevel
        } else {
            selectedLogLevel = .info
        }

        // Add initial log entry
        addLogEntry(category: .system, level: .info, message: "Debug manager initialized")
    }

    // MARK: - Log Management

    /// US-046: Add a log entry with explicit log level
    /// - Parameters:
    ///   - category: The category of the log entry
    ///   - level: The verbosity level of this log entry
    ///   - message: The log message
    ///   - details: Optional additional details
    func addLogEntry(category: LogEntry.Category, level: LogLevel = .info, message: String, details: String? = nil) {
        // US-046: Filter by log level - only log if this entry's level meets or exceeds the threshold
        guard level.priority >= selectedLogLevel.priority else { return }

        let entry = LogEntry(
            timestamp: Date(),
            category: category,
            level: level,
            message: message,
            details: details
        )

        logEntries.append(entry)

        // Trim old entries if needed
        if logEntries.count > Constants.maxLogEntries {
            logEntries.removeFirst(logEntries.count - Constants.maxLogEntries)
        }

        // Also log to console
        print("[Debug] [\(level.prefix)] [\(category.rawValue)] \(message)")
        if let details = details {
            print("        Details: \(details)")
        }

        // US-046: Write to file if file logging is enabled
        if isFileLoggingEnabled {
            writeToFile(entry: entry)
        }
    }

    /// Clear all log entries
    func clearLog() {
        logEntries.removeAll()
        addLogEntry(category: .system, level: .info, message: "Log cleared")
    }

    // MARK: - US-046: File Logging

    /// Write a log entry to the debug log file
    private func writeToFile(entry: LogEntry) {
        // Prepare data on main thread
        let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
        let redactedMessage = redactSensitiveData(entry.message)
        let redactedDetails = entry.details.map { redactSensitiveData($0) }
        let logFileURLCopy = logFileURL
        let maxSize = Constants.maxLogFileSizeBytes

        let maxRetained = Constants.maxRetainedLogFiles

        fileWriteQueue.async {
            // Format the log entry with sensitive data redacted
            var logLine = "[\(timestamp)] [\(entry.level.prefix)] [\(entry.category.rawValue)] \(redactedMessage)"
            if let details = redactedDetails {
                logLine += "\n  Details: \(details)"
            }
            logLine += "\n"

            // US-047: Rotate log file if needed (with retention limit)
            Self.rotateLogFileIfNeeded(at: logFileURLCopy, maxSize: maxSize, maxRetained: maxRetained)

            // Append to file
            Self.appendToLogFile(logLine, at: logFileURLCopy)
        }
    }

    /// Append a string to the log file (nonisolated for async file operations)
    private nonisolated static func appendToLogFile(_ content: String, at logFileURL: URL) {
        guard let data = content.data(using: .utf8) else { return }
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: logFileURL.path) {
            // Append to existing file
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                try? fileHandle.close()
            }
        } else {
            // Create new file with header
            let header = """
            # Voxa Debug Log
            # Format: [timestamp] [level] [category] message
            # Log levels: VERBOSE, DEBUG, INFO, WARN, ERROR
            # Sensitive data is automatically redacted
            #

            """
            let initialData = (header + content).data(using: .utf8)
            fileManager.createFile(atPath: logFileURL.path, contents: initialData)
        }
    }

    /// US-047: Rotate log file if it exceeds the maximum size (nonisolated for async file operations)
    /// Uses numbered rotation scheme: debug.log -> debug.1.log -> debug.2.log -> ... -> debug.N.log
    /// Old logs beyond maxRetained are automatically deleted
    /// - Parameters:
    ///   - logFileURL: The URL of the main log file
    ///   - maxSize: Maximum size in bytes before rotation
    ///   - maxRetained: Maximum number of rotated log files to keep
    private nonisolated static func rotateLogFileIfNeeded(at logFileURL: URL, maxSize: Int, maxRetained: Int) {
        let fileManager = FileManager.default
        guard let attributes = try? fileManager.attributesOfItem(atPath: logFileURL.path),
              let fileSize = attributes[.size] as? Int,
              fileSize > maxSize else {
            return
        }

        // Get the base name for rotated files (e.g., "debug" from "debug.log")
        let directory = logFileURL.deletingLastPathComponent()
        let baseName = logFileURL.deletingPathExtension().lastPathComponent

        // US-047: Delete the oldest log file if it exists (beyond retention limit)
        let oldestLogURL = directory.appendingPathComponent("\(baseName).\(maxRetained).log")
        try? fileManager.removeItem(at: oldestLogURL)

        // US-047: Rotate existing numbered log files (N-1 -> N, N-2 -> N-1, ..., 1 -> 2)
        // Work backwards to avoid overwriting files
        for i in stride(from: maxRetained - 1, through: 1, by: -1) {
            let sourceURL = directory.appendingPathComponent("\(baseName).\(i).log")
            let destURL = directory.appendingPathComponent("\(baseName).\(i + 1).log")
            if fileManager.fileExists(atPath: sourceURL.path) {
                try? fileManager.moveItem(at: sourceURL, to: destURL)
            }
        }

        // US-047: Move current log to .1.log
        let firstRotatedURL = directory.appendingPathComponent("\(baseName).1.log")
        try? fileManager.moveItem(at: logFileURL, to: firstRotatedURL)
    }

    /// US-046: Redact sensitive data from a string
    /// - Parameter text: The text to redact
    /// - Returns: The text with sensitive data replaced by placeholders
    private func redactSensitiveData(_ text: String) -> String {
        var result = text
        for (pattern, replacement) in Self.sensitivePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: replacement)
            }
        }
        return result
    }

    /// US-046: Get the path to the debug log file
    var debugLogFilePath: String {
        return logFileURL.path
    }

    /// US-046: Clear the debug log file
    func clearLogFile() {
        let logFileURLCopy = logFileURL
        fileWriteQueue.async {
            try? FileManager.default.removeItem(at: logFileURLCopy)
        }
        addLogEntry(category: .system, level: .info, message: "Log file cleared")
    }
    
    // MARK: - Audio Debug Data
    
    /// Store audio data for debug visualization
    func storeAudioData(_ audioData: Data, sampleRate: Double) {
        guard isDebugModeEnabled else { return }
        
        // Store raw data for WAV export
        lastRawAudioData = audioData
        lastRawAudioSampleRate = sampleRate
        
        // Convert to Float samples for analysis
        let samples = audioData.withUnsafeBytes { buffer -> [Float] in
            let floatBuffer = buffer.bindMemory(to: Float.self)
            return Array(floatBuffer)
        }
        
        guard !samples.isEmpty else { return }
        
        // Calculate statistics
        var peakAmplitude: Float = 0
        var sumSquares: Float = 0
        
        for sample in samples {
            let absValue = abs(sample)
            if absValue > peakAmplitude {
                peakAmplitude = absValue
            }
            sumSquares += sample * sample
        }
        
        let rms = sqrt(sumSquares / Float(samples.count))
        let peakDb = peakAmplitude > 0 ? 20.0 * log10(peakAmplitude) : -60.0
        let rmsDb = rms > 0 ? 20.0 * log10(rms) : -60.0
        let duration = Double(samples.count) / sampleRate
        
        lastAudioData = AudioDebugData(
            samples: samples,
            sampleRate: sampleRate,
            duration: duration,
            peakLevel: peakDb,
            rmsLevel: rmsDb
        )
        
        addLogEntry(
            category: .audio,
            level: .debug,
            message: "Audio captured: \(String(format: "%.2f", duration))s",
            details: "Peak: \(String(format: "%.1f", peakDb))dB, RMS: \(String(format: "%.1f", rmsDb))dB, Samples: \(samples.count)"
        )
    }

    // MARK: - Transcription Debug Data

    /// Store transcription data for debug comparison
    func storeTranscriptionData(raw: String, cleaned: String, processingTime: TimeInterval, model: String) {
        guard isDebugModeEnabled else { return }

        lastTranscriptionData = TranscriptionDebugData(
            rawText: raw,
            cleanedText: cleaned,
            processingTime: processingTime,
            modelUsed: model
        )

        addLogEntry(
            category: .transcription,
            level: .info,
            message: "Transcription complete in \(String(format: "%.2f", processingTime))s",
            details: "Model: \(model)\nRaw: \(raw.prefix(100))\(raw.count > 100 ? "..." : "")"
        )
    }

    /// Log raw transcription result (before cleanup)
    func logRawTranscription(_ text: String, model: String) {
        guard isDebugModeEnabled else { return }

        addLogEntry(
            category: .transcription,
            level: .verbose,
            message: "Raw transcription (before cleanup)",
            details: "Model: \(model)\nText: \(text)"
        )
    }

    /// Log cleaned transcription result
    func logCleanedTranscription(_ text: String, mode: String) {
        guard isDebugModeEnabled else { return }

        addLogEntry(
            category: .transcription,
            level: .verbose,
            message: "Cleaned transcription",
            details: "Mode: \(mode)\nText: \(text)"
        )
    }

    // MARK: - Model Debug

    /// Log model status change
    func logModelStatus(_ status: String, model: String) {
        guard isDebugModeEnabled else { return }

        addLogEntry(
            category: .model,
            level: .info,
            message: status,
            details: "Model: \(model)"
        )
    }

    // MARK: - US-046: Convenience Logging Methods

    /// Log a verbose message (most detailed)
    func verbose(_ message: String, category: LogEntry.Category = .system, details: String? = nil) {
        addLogEntry(category: category, level: .verbose, message: message, details: details)
    }

    /// Log a debug message
    func debug(_ message: String, category: LogEntry.Category = .system, details: String? = nil) {
        addLogEntry(category: category, level: .debug, message: message, details: details)
    }

    /// Log an info message
    func info(_ message: String, category: LogEntry.Category = .system, details: String? = nil) {
        addLogEntry(category: category, level: .info, message: message, details: details)
    }

    /// Log a warning message
    func warning(_ message: String, category: LogEntry.Category = .system, details: String? = nil) {
        addLogEntry(category: category, level: .warning, message: message, details: details)
    }

    /// Log an error message
    func error(_ message: String, category: LogEntry.Category = .system, details: String? = nil) {
        addLogEntry(category: category, level: .error, message: message, details: details)
    }

    // MARK: - Formatted Log Output

    /// Get formatted log output for display
    func formatLogEntry(_ entry: LogEntry) -> String {
        let time = dateFormatter.string(from: entry.timestamp)
        var text = "[\(time)] [\(entry.level.prefix)] [\(entry.category.rawValue)] \(entry.message)"
        if let details = entry.details {
            text += "\n  " + details.replacingOccurrences(of: "\n", with: "\n  ")
        }
        return text
    }
    
    /// Get all logs as formatted text
    func getAllLogsFormatted() -> String {
        return logEntries.map { formatLogEntry($0) }.joined(separator: "\n\n")
    }
    
    // MARK: - US-707: Export Logs
    
    /// Export error type for log export operations
    enum ExportError: Error, LocalizedError {
        case cancelled
        case writeFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .cancelled:
                return "Export cancelled"
            case .writeFailed(let message):
                return "Failed to export logs: \(message)"
            }
        }
    }
    
    /// Export all logs to a file with save panel
    /// - Parameter completion: Called with the result (file URL or error)
    func exportLogs(completion: @escaping (Result<URL, ExportError>) -> Void) {
        let logsContent = generateExportContent()
        
        DispatchQueue.main.async {
            let savePanel = NSSavePanel()
            savePanel.title = "Export Logs"
            savePanel.nameFieldStringValue = self.generateLogFilename()
            savePanel.allowedContentTypes = [.plainText]
            savePanel.canCreateDirectories = true
            savePanel.message = "Choose a location to save the debug logs"
            
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    do {
                        try logsContent.write(to: url, atomically: true, encoding: .utf8)
                        print("[US-707] Logs exported to: \(url.path)")
                        completion(.success(url))
                    } catch {
                        print("[US-707] Failed to export logs: \(error.localizedDescription)")
                        completion(.failure(.writeFailed(error.localizedDescription)))
                    }
                } else {
                    completion(.failure(.cancelled))
                }
            }
        }
    }
    
    /// Generate log filename with timestamp
    private func generateLogFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        return "Voxa_Logs_\(timestamp).txt"
    }
    
    /// Generate content for log export including system info
    private func generateExportContent() -> String {
        let systemInfo = SystemInfo.current()
        let header = """
        ═══════════════════════════════════════════════════════════════
                              WISPFLOW DEBUG LOG
        ═══════════════════════════════════════════════════════════════
        Export Date: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .medium))
        
        SYSTEM INFORMATION
        ───────────────────────────────────────────────────────────────
        \(systemInfo.formattedString)
        
        LOG ENTRIES (\(logEntries.count) total)
        ───────────────────────────────────────────────────────────────
        
        """
        
        let logsContent = getAllLogsFormatted()
        return header + logsContent
    }
    
    // MARK: - US-707: Reset All Settings
    
    /// Reset all Voxa settings to defaults
    /// This removes all UserDefaults keys used by Voxa
    func resetAllSettings() {
        print("[US-707] Resetting all settings to defaults...")
        
        // Debug settings
        UserDefaults.standard.removeObject(forKey: Constants.debugModeKey)
        UserDefaults.standard.removeObject(forKey: Constants.silenceDetectionDisabledKey)
        UserDefaults.standard.removeObject(forKey: Constants.autoSaveRecordingsKey)
        UserDefaults.standard.removeObject(forKey: Constants.logLevelKey)
        
        // Whisper model settings
        UserDefaults.standard.removeObject(forKey: "selectedWhisperModel")
        UserDefaults.standard.removeObject(forKey: "selectedTranscriptionLanguage")
        
        // Audio settings
        UserDefaults.standard.removeObject(forKey: "selectedAudioDeviceUID")
        UserDefaults.standard.removeObject(forKey: "preferredAudioDeviceUID")
        UserDefaults.standard.removeObject(forKey: "audioCalibrationData")
        UserDefaults.standard.removeObject(forKey: "maxRecordingDuration")
        
        // Text cleanup settings
        UserDefaults.standard.removeObject(forKey: "cleanupEnabled")
        UserDefaults.standard.removeObject(forKey: "cleanupMode")
        UserDefaults.standard.removeObject(forKey: "autoCapitalizeFirstLetter")
        UserDefaults.standard.removeObject(forKey: "addPeriodAtEnd")
        UserDefaults.standard.removeObject(forKey: "trimWhitespace")
        
        // LLM settings
        UserDefaults.standard.removeObject(forKey: "selectedLLMModel")
        UserDefaults.standard.removeObject(forKey: "useCustomModelPath")
        UserDefaults.standard.removeObject(forKey: "customModelPath")
        
        // Text insertion settings
        UserDefaults.standard.removeObject(forKey: "preserveClipboard")
        UserDefaults.standard.removeObject(forKey: "clipboardRestoreDelay")
        
        // Hotkey settings
        UserDefaults.standard.removeObject(forKey: "hotkeyConfiguration")
        
        // Onboarding settings
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        
        // Synchronize defaults
        UserDefaults.standard.synchronize()
        
        // Reset local state to defaults
        isDebugModeEnabled = false
        isSilenceDetectionDisabled = false
        isAutoSaveEnabled = false
        selectedLogLevel = .info
        
        // Clear log entries
        logEntries.removeAll()
        addLogEntry(category: .system, message: "All settings reset to defaults")
        
        print("[US-707] All settings have been reset to defaults")
    }
    
    // MARK: - US-707: Get System Info
    
    /// Get current system information
    func getSystemInfo() -> SystemInfo {
        return SystemInfo.current()
    }
}
