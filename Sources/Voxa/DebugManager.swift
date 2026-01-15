import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

/// Manages debug mode state and provides shared access to debug functionality
/// Handles debug mode persistence and provides debug data storage
@MainActor
final class DebugManager: ObservableObject {
    
    // MARK: - Types
    
    /// US-707: Log level for debug output filtering
    enum LogLevel: String, CaseIterable, Identifiable {
        case verbose = "Verbose"
        case info = "Info"
        case warning = "Warning"
        case error = "Error"
        
        var id: String { rawValue }
        
        /// Icon for this log level
        var icon: String {
            switch self {
            case .verbose: return "text.alignleft"
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            }
        }
        
        /// Color for this log level
        var colorName: String {
            switch self {
            case .verbose: return "textTertiary"
            case .info: return "info"
            case .warning: return "warning"
            case .error: return "error"
            }
        }
        
        /// Description for this log level
        var description: String {
            switch self {
            case .verbose: return "All debug output including detailed traces"
            case .info: return "General information and progress messages"
            case .warning: return "Warnings and potential issues"
            case .error: return "Errors and critical failures only"
            }
        }
        
        /// Numeric priority (lower = more verbose)
        var priority: Int {
            switch self {
            case .verbose: return 0
            case .info: return 1
            case .warning: return 2
            case .error: return 3
            }
        }
    }
    
    /// Debug log entry for display
    struct LogEntry: Identifiable, Equatable {
        let id = UUID()
        let timestamp: Date
        let category: Category
        let message: String
        let details: String?
        
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
        static let logLevelKey = "debugLogLevel"  // US-707
        static let maxLogEntries = 500
    }
    
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
    
    /// US-707: Selected log level for filtering debug output
    @Published var selectedLogLevel: LogLevel {
        didSet {
            UserDefaults.standard.set(selectedLogLevel.rawValue, forKey: Constants.logLevelKey)
            addLogEntry(category: .system, message: "Log level changed to \(selectedLogLevel.rawValue)")
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
    
    /// Date formatter for log entries
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    // MARK: - Initialization
    
    private init() {
        isDebugModeEnabled = UserDefaults.standard.bool(forKey: Constants.debugModeKey)
        isSilenceDetectionDisabled = UserDefaults.standard.bool(forKey: Constants.silenceDetectionDisabledKey)
        isAutoSaveEnabled = UserDefaults.standard.bool(forKey: Constants.autoSaveRecordingsKey)
        
        // US-707: Load log level from UserDefaults
        if let logLevelString = UserDefaults.standard.string(forKey: Constants.logLevelKey),
           let logLevel = LogLevel(rawValue: logLevelString) {
            selectedLogLevel = logLevel
        } else {
            selectedLogLevel = .info
        }
        
        // Add initial log entry
        addLogEntry(category: .system, message: "Debug manager initialized")
    }
    
    // MARK: - Log Management
    
    /// Add a log entry
    func addLogEntry(category: LogEntry.Category, message: String, details: String? = nil) {
        let entry = LogEntry(
            timestamp: Date(),
            category: category,
            message: message,
            details: details
        )
        
        logEntries.append(entry)
        
        // Trim old entries if needed
        if logEntries.count > Constants.maxLogEntries {
            logEntries.removeFirst(logEntries.count - Constants.maxLogEntries)
        }
        
        // Also log to console
        print("[Debug] [\(category.rawValue)] \(message)")
        if let details = details {
            print("        Details: \(details)")
        }
    }
    
    /// Clear all log entries
    func clearLog() {
        logEntries.removeAll()
        addLogEntry(category: .system, message: "Log cleared")
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
            message: "Transcription complete in \(String(format: "%.2f", processingTime))s",
            details: "Model: \(model)\nRaw: \(raw.prefix(100))\(raw.count > 100 ? "..." : "")"
        )
    }
    
    /// Log raw transcription result (before cleanup)
    func logRawTranscription(_ text: String, model: String) {
        guard isDebugModeEnabled else { return }
        
        addLogEntry(
            category: .transcription,
            message: "Raw transcription (before cleanup)",
            details: "Model: \(model)\nText: \(text)"
        )
    }
    
    /// Log cleaned transcription result
    func logCleanedTranscription(_ text: String, mode: String) {
        guard isDebugModeEnabled else { return }
        
        addLogEntry(
            category: .transcription,
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
            message: status,
            details: "Model: \(model)"
        )
    }
    
    // MARK: - Formatted Log Output
    
    /// Get formatted log output for display
    func formatLogEntry(_ entry: LogEntry) -> String {
        let time = dateFormatter.string(from: entry.timestamp)
        var text = "[\(time)] [\(entry.category.rawValue)] \(entry.message)"
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
