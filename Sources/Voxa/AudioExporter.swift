import Foundation
import AppKit
import AVFoundation
import Combine

/// Utility for exporting audio data to WAV file format
/// Converts Float32 PCM audio data to standard WAV format
/// US-306: Enhanced with auto-save, detailed logging, and playback support
final class AudioExporter: NSObject {
    
    // MARK: - Types
    
    /// WAV export result with detailed information
    enum ExportResult {
        case success(URL)
        case noAudioData
        case exportFailed(String)
        
        /// Get the URL if export was successful
        var url: URL? {
            if case .success(let url) = self {
                return url
            }
            return nil
        }
        
        /// Get error message if export failed
        var errorMessage: String? {
            switch self {
            case .noAudioData:
                return "No audio data available to export"
            case .exportFailed(let message):
                return message
            case .success:
                return nil
            }
        }
    }
    
    /// US-306: Export details for logging and display
    struct ExportDetails {
        let sampleCount: Int
        let duration: TimeInterval
        let sampleRate: Double
        let fileSizeBytes: Int
        let filePath: String
        let timestamp: Date
        
        /// Formatted file size string
        var formattedFileSize: String {
            if fileSizeBytes < 1024 {
                return "\(fileSizeBytes) B"
            } else if fileSizeBytes < 1024 * 1024 {
                return String(format: "%.1f KB", Double(fileSizeBytes) / 1024.0)
            } else {
                return String(format: "%.1f MB", Double(fileSizeBytes) / (1024.0 * 1024.0))
            }
        }
        
        /// Formatted duration string
        var formattedDuration: String {
            return String(format: "%.2f seconds", duration)
        }
    }
    
    // MARK: - WAV Header Constants
    
    private struct WAVHeader {
        static let riffChunkID: [UInt8] = [0x52, 0x49, 0x46, 0x46] // "RIFF"
        static let waveFormat: [UInt8] = [0x57, 0x41, 0x56, 0x45]   // "WAVE"
        static let fmtChunkID: [UInt8] = [0x66, 0x6D, 0x74, 0x20]   // "fmt "
        static let dataChunkID: [UInt8] = [0x64, 0x61, 0x74, 0x61]  // "data"
        static let pcmFormat: UInt16 = 1       // PCM = 1
        static let bitsPerSample: UInt16 = 16  // 16-bit audio
    }
    
    // MARK: - Singleton
    
    static let shared = AudioExporter()
    
    // MARK: - US-306: Properties for playback
    
    /// Audio player for playback of exported files
    private var audioPlayer: AVAudioPlayer?
    
    /// Callback when playback completes
    var onPlaybackComplete: (() -> Void)?
    
    /// Last export details (for display)
    @Published private(set) var lastExportDetails: ExportDetails?
    
    /// Last exported file URL (for playback)
    @Published private(set) var lastExportedURL: URL?
    
    /// Whether audio is currently playing
    @Published private(set) var isPlaying: Bool = false
    
    private override init() {
        super.init()
    }
    
    // MARK: - Export Methods
    
    /// Export Float32 audio data to WAV file
    /// - Parameters:
    ///   - audioData: Raw Float32 audio samples as Data
    ///   - sampleRate: Sample rate of the audio (e.g., 16000)
    ///   - url: Destination URL for the WAV file
    /// - Returns: Export result
    /// US-306: Enhanced with detailed logging
    func exportToWAV(audioData: Data, sampleRate: Double, to url: URL) -> ExportResult {
        // US-306: Log export attempt
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║              US-306: AUDIO EXPORT STARTED                     ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ Target path: \(url.path.prefix(55))...")
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        guard !audioData.isEmpty else {
            logExportFailure(reason: "No audio data available (empty Data)")
            return .noAudioData
        }
        
        // Convert Float32 samples to Int16 (16-bit PCM)
        let float32Samples = audioData.withUnsafeBytes { buffer -> [Float] in
            let floatBuffer = buffer.bindMemory(to: Float.self)
            return Array(floatBuffer)
        }
        
        guard !float32Samples.isEmpty else {
            logExportFailure(reason: "No samples extracted from audio data")
            return .noAudioData
        }
        
        // US-306: Log sample statistics
        let duration = Double(float32Samples.count) / sampleRate
        print("[US-306] Audio data: \(float32Samples.count) samples, \(String(format: "%.2f", duration))s, \(Int(sampleRate))Hz")
        
        // Convert to 16-bit signed integer samples
        let int16Samples = float32Samples.map { sample -> Int16 in
            // Clamp to [-1.0, 1.0] range
            let clampedSample = max(-1.0, min(1.0, sample))
            // Scale to Int16 range
            return Int16(clampedSample * Float(Int16.max))
        }
        
        // Create WAV data
        guard let wavData = createWAVData(samples: int16Samples, sampleRate: UInt32(sampleRate)) else {
            logExportFailure(reason: "Failed to create WAV data structure")
            return .exportFailed("Failed to create WAV data")
        }
        
        // Write to file
        do {
            // Ensure parent directory exists
            let parentDir = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
            
            try wavData.write(to: url)
            
            // US-306: Log successful export with details
            let fileSize = wavData.count
            logExportSuccess(
                sampleCount: float32Samples.count,
                duration: duration,
                sampleRate: sampleRate,
                fileSizeBytes: fileSize,
                filePath: url.path
            )
            
            // Store details for later access
            lastExportDetails = ExportDetails(
                sampleCount: float32Samples.count,
                duration: duration,
                sampleRate: sampleRate,
                fileSizeBytes: fileSize,
                filePath: url.path,
                timestamp: Date()
            )
            lastExportedURL = url
            
            return .success(url)
        } catch {
            logExportFailure(reason: "Failed to write WAV file: \(error.localizedDescription)")
            return .exportFailed("Failed to write WAV file: \(error.localizedDescription)")
        }
    }
    
    /// US-306: Log successful export with details
    private func logExportSuccess(sampleCount: Int, duration: TimeInterval, sampleRate: Double, fileSizeBytes: Int, filePath: String) {
        let formattedSize = formatFileSize(fileSizeBytes)
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║           US-306: AUDIO EXPORT SUCCESSFUL ✓                   ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ Sample count:     \(String(format: "%10d", sampleCount)) samples                       ║")
        print("║ Duration:         \(String(format: "%10.2f", duration)) seconds                       ║")
        print("║ Sample rate:      \(String(format: "%10.0f", sampleRate)) Hz                           ║")
        print("║ File size:        \(String(format: "%10s", formattedSize))                             ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ File path:                                                    ║")
        print("║   \(filePath)")
        print("╚═══════════════════════════════════════════════════════════════╝")
    }
    
    /// US-306: Log export failure
    private func logExportFailure(reason: String) {
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║           US-306: AUDIO EXPORT FAILED ✗                       ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ Reason: \(reason)")
        print("╚═══════════════════════════════════════════════════════════════╝")
    }
    
    /// Format file size for display
    private func formatFileSize(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
    
    /// Show save panel and export audio to WAV
    /// - Parameters:
    ///   - audioData: Raw Float32 audio samples as Data
    ///   - sampleRate: Sample rate of the audio
    ///   - completion: Called with the result
    func exportWithSavePanel(audioData: Data, sampleRate: Double, completion: @escaping (ExportResult) -> Void) {
        guard !audioData.isEmpty else {
            completion(.noAudioData)
            return
        }
        
        DispatchQueue.main.async {
            let savePanel = NSSavePanel()
            savePanel.title = "Export Audio as WAV"
            savePanel.nameFieldStringValue = self.generateDefaultFilename()
            savePanel.allowedContentTypes = [.wav]
            savePanel.canCreateDirectories = true
            savePanel.message = "Choose a location to save the audio recording"
            
            savePanel.begin { [weak self] response in
                guard let self = self else { return }
                
                if response == .OK, let url = savePanel.url {
                    let result = self.exportToWAV(audioData: audioData, sampleRate: sampleRate, to: url)
                    completion(result)
                } else {
                    // User cancelled
                    completion(.exportFailed("Export cancelled"))
                }
            }
        }
    }
    
    // MARK: - WAV Creation
    
    /// Create WAV file data from Int16 samples
    private func createWAVData(samples: [Int16], sampleRate: UInt32) -> Data? {
        let numChannels: UInt16 = 1  // Mono
        let bitsPerSample = WAVHeader.bitsPerSample
        let byteRate = sampleRate * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        
        // Calculate sizes
        let dataSize = UInt32(samples.count * Int(bitsPerSample / 8))
        let fmtChunkSize: UInt32 = 16  // PCM format chunk is always 16 bytes
        let riffChunkSize = 4 + (8 + fmtChunkSize) + (8 + dataSize)  // "WAVE" + fmt chunk + data chunk
        
        var data = Data()
        
        // RIFF header
        data.append(contentsOf: WAVHeader.riffChunkID)           // "RIFF"
        data.append(contentsOf: uint32ToBytes(riffChunkSize))    // File size - 8
        data.append(contentsOf: WAVHeader.waveFormat)            // "WAVE"
        
        // fmt subchunk
        data.append(contentsOf: WAVHeader.fmtChunkID)            // "fmt "
        data.append(contentsOf: uint32ToBytes(fmtChunkSize))     // Subchunk size (16 for PCM)
        data.append(contentsOf: uint16ToBytes(WAVHeader.pcmFormat)) // Audio format (1 = PCM)
        data.append(contentsOf: uint16ToBytes(numChannels))      // Number of channels
        data.append(contentsOf: uint32ToBytes(sampleRate))       // Sample rate
        data.append(contentsOf: uint32ToBytes(byteRate))         // Byte rate
        data.append(contentsOf: uint16ToBytes(blockAlign))       // Block align
        data.append(contentsOf: uint16ToBytes(bitsPerSample))    // Bits per sample
        
        // data subchunk
        data.append(contentsOf: WAVHeader.dataChunkID)           // "data"
        data.append(contentsOf: uint32ToBytes(dataSize))         // Data size
        
        // Audio samples
        for sample in samples {
            data.append(contentsOf: int16ToBytes(sample))
        }
        
        return data
    }
    
    // MARK: - Byte Conversion Helpers
    
    private func uint32ToBytes(_ value: UInt32) -> [UInt8] {
        return [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF)
        ]
    }
    
    private func uint16ToBytes(_ value: UInt16) -> [UInt8] {
        return [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF)
        ]
    }
    
    private func int16ToBytes(_ value: Int16) -> [UInt8] {
        return [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF)
        ]
    }
    
    // MARK: - Helpers
    
    /// Generate a default filename with timestamp
    private func generateDefaultFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        return "Voxa_Recording_\(timestamp).wav"
    }
    
    // MARK: - US-306: Auto-Save to Documents
    
    /// Get the debug recordings directory URL in Documents folder
    /// Creates the directory if it doesn't exist
    func getDebugRecordingsDirectory() -> URL? {
        let fileManager = FileManager.default
        
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[US-306] Error: Could not find Documents directory")
            return nil
        }
        
        let debugRecordingsDir = documentsDir
            .appendingPathComponent("Voxa", isDirectory: true)
            .appendingPathComponent("DebugRecordings", isDirectory: true)
        
        do {
            try fileManager.createDirectory(at: debugRecordingsDir, withIntermediateDirectories: true, attributes: nil)
            return debugRecordingsDir
        } catch {
            print("[US-306] Error creating debug recordings directory: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// US-306: Export to Documents/Voxa/DebugRecordings folder automatically
    /// - Parameters:
    ///   - audioData: Raw Float32 audio samples as Data
    ///   - sampleRate: Sample rate of the audio
    /// - Returns: Export result with file URL if successful
    func exportToDocuments(audioData: Data, sampleRate: Double) -> ExportResult {
        guard let debugDir = getDebugRecordingsDirectory() else {
            return .exportFailed("Could not create or access debug recordings directory")
        }
        
        let filename = generateDefaultFilename()
        let url = debugDir.appendingPathComponent(filename)
        
        print("[US-306] Auto-saving recording to Documents folder...")
        return exportToWAV(audioData: audioData, sampleRate: sampleRate, to: url)
    }
    
    // MARK: - US-306: Playback Support
    
    /// Play the last exported WAV file
    /// - Returns: true if playback started successfully
    @discardableResult
    func playLastExport() -> Bool {
        guard let url = lastExportedURL else {
            print("[US-306] No exported file available for playback")
            return false
        }
        
        return playFile(at: url)
    }
    
    /// Play a WAV file at the specified URL
    /// - Parameter url: URL of the WAV file to play
    /// - Returns: true if playback started successfully
    @discardableResult
    func playFile(at url: URL) -> Bool {
        // Stop any current playback
        stopPlayback()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            guard audioPlayer?.play() == true else {
                print("[US-306] Failed to start audio playback")
                return false
            }
            
            isPlaying = true
            print("[US-306] Playing audio: \(url.lastPathComponent)")
            return true
        } catch {
            print("[US-306] Error creating audio player: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Stop any current audio playback
    func stopPlayback() {
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
            print("[US-306] Audio playback stopped")
        }
        audioPlayer = nil
        isPlaying = false
    }
    
    /// Open the last exported file in Finder
    func revealLastExportInFinder() {
        guard let url = lastExportedURL else {
            print("[US-306] No exported file to reveal")
            return
        }
        
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        print("[US-306] Revealed file in Finder: \(url.path)")
    }
    
    /// Open the debug recordings folder in Finder
    func openDebugRecordingsFolder() {
        guard let url = getDebugRecordingsDirectory() else {
            print("[US-306] Could not access debug recordings directory")
            return
        }
        
        NSWorkspace.shared.open(url)
        print("[US-306] Opened debug recordings folder: \(url.path)")
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioExporter: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            if flag {
                print("[US-306] Audio playback completed successfully")
            } else {
                print("[US-306] Audio playback ended with an error")
            }
            self?.onPlaybackComplete?()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            print("[US-306] Audio decode error: \(error?.localizedDescription ?? "unknown")")
            self?.onPlaybackComplete?()
        }
    }
}
