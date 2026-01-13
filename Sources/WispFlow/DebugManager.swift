import Foundation
import Combine

/// Manages debug mode state and provides shared access to debug functionality
/// Handles debug mode persistence and provides debug data storage
@MainActor
final class DebugManager: ObservableObject {
    
    // MARK: - Types
    
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
    
    // MARK: - Constants
    
    private struct Constants {
        static let debugModeKey = "debugModeEnabled"
        static let silenceDetectionDisabledKey = "silenceDetectionDisabled"
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
}
