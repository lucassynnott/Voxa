import SwiftUI
import AppKit

/// Debug window that shows real-time logs, audio waveform, and transcription details
/// Only available when debug mode is enabled
struct DebugLogView: View {
    @ObservedObject var debugManager: DebugManager
    @State private var autoScroll = true
    @State private var selectedTab = 0
    @State private var showExportSuccess = false
    @State private var exportMessage = ""
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Logs tab
            logsTab
                .tabItem {
                    Label("Logs", systemImage: "list.bullet.rectangle")
                }
                .tag(0)
            
            // Audio tab
            audioTab
                .tabItem {
                    Label("Audio", systemImage: "waveform")
                }
                .tag(1)
            
            // Transcription tab
            transcriptionTab
                .tabItem {
                    Label("Transcription", systemImage: "text.bubble")
                }
                .tag(2)
        }
        .frame(minWidth: 500, minHeight: 400)
        .alert("Export Result", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage)
        }
    }
    
    // MARK: - Logs Tab
    
    private var logsTab: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                
                Spacer()
                
                Button(action: {
                    debugManager.clearLog()
                }) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                
                Button(action: copyLogsToClipboard) {
                    Label("Copy All", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            
            Divider()
            
            // Log entries
            ScrollViewReader { proxy in
                List {
                    ForEach(debugManager.logEntries) { entry in
                        LogEntryRow(entry: entry)
                            .id(entry.id)
                    }
                }
                .listStyle(.plain)
                .onChange(of: debugManager.logEntries.count) { _, _ in
                    if autoScroll, let lastEntry = debugManager.logEntries.last {
                        withAnimation {
                            proxy.scrollTo(lastEntry.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Audio Tab
    
    private var audioTab: some View {
        VStack(spacing: 16) {
            if let audioData = debugManager.lastAudioData {
                // Audio statistics
                GroupBox("Recording Statistics") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            StatRow(label: "Duration", value: String(format: "%.2f seconds", audioData.duration))
                            Spacer()
                            StatRow(label: "Sample Rate", value: "\(Int(audioData.sampleRate)) Hz")
                        }
                        HStack {
                            StatRow(label: "Samples", value: "\(audioData.samples.count)")
                            Spacer()
                            StatRow(label: "Peak Level", value: String(format: "%.1f dB", audioData.peakLevel))
                        }
                        HStack {
                            StatRow(label: "RMS Level", value: String(format: "%.1f dB", audioData.rmsLevel))
                            Spacer()
                            StatRow(label: "Quality", value: audioData.peakLevel > -55 ? "Good ✓" : "Quiet ⚠️")
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Waveform visualization
                GroupBox("Waveform") {
                    AudioWaveformView(
                        samples: audioData.samples,
                        sampleRate: audioData.sampleRate,
                        barCount: 150,
                        height: 100
                    )
                    .padding(.vertical, 4)
                }
                
                // Export button
                HStack {
                    Spacer()
                    Button(action: exportAudio) {
                        Label("Export as WAV", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
                
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "waveform.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No audio recorded yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Record audio to see waveform visualization")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Transcription Tab
    
    private var transcriptionTab: some View {
        VStack(spacing: 16) {
            if let transcriptionData = debugManager.lastTranscriptionData {
                // Processing info
                GroupBox("Processing Info") {
                    HStack {
                        StatRow(label: "Model", value: transcriptionData.modelUsed)
                        Spacer()
                        StatRow(label: "Processing Time", value: String(format: "%.2f seconds", transcriptionData.processingTime))
                    }
                    .padding(.vertical, 4)
                }
                
                // Raw transcription
                GroupBox("Raw Transcription (before cleanup)") {
                    ScrollView {
                        Text(transcriptionData.rawText.isEmpty ? "(empty)" : transcriptionData.rawText)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(height: 80)
                }
                
                // Cleaned transcription
                GroupBox("Cleaned Transcription (after cleanup)") {
                    ScrollView {
                        Text(transcriptionData.cleanedText.isEmpty ? "(empty)" : transcriptionData.cleanedText)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(height: 80)
                }
                
                // Comparison
                if transcriptionData.rawText != transcriptionData.cleanedText {
                    GroupBox("Changes Made") {
                        Text(describeChanges(raw: transcriptionData.rawText, cleaned: transcriptionData.cleanedText))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No transcription data yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Record and transcribe audio to see results")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func copyLogsToClipboard() {
        let text = debugManager.getAllLogsFormatted()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    private func exportAudio() {
        guard let audioData = debugManager.lastRawAudioData else {
            exportMessage = "No audio data available to export"
            showExportSuccess = true
            return
        }
        
        AudioExporter.shared.exportWithSavePanel(
            audioData: audioData,
            sampleRate: debugManager.lastRawAudioSampleRate
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    exportMessage = "Audio exported successfully to:\n\(url.path)"
                case .noAudioData:
                    exportMessage = "No audio data available to export"
                case .exportFailed(let error):
                    exportMessage = "Export failed: \(error)"
                }
                showExportSuccess = true
            }
        }
    }
    
    private func describeChanges(raw: String, cleaned: String) -> String {
        var changes: [String] = []
        
        // Check for removed words
        let rawWords = Set(raw.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let cleanedWords = Set(cleaned.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let removedWords = rawWords.subtracting(cleanedWords)
        
        if !removedWords.isEmpty {
            let fillerWords = ["um", "uh", "like", "you know", "actually", "basically", "so", "well"]
            let removedFillers = removedWords.filter { fillerWords.contains($0) }
            if !removedFillers.isEmpty {
                changes.append("• Removed filler words: \(removedFillers.joined(separator: ", "))")
            }
        }
        
        // Check for capitalization changes
        if raw.first?.isLowercase == true && cleaned.first?.isUppercase == true {
            changes.append("• Fixed sentence capitalization")
        }
        
        // Check for punctuation changes
        if !raw.hasSuffix(".") && !raw.hasSuffix("!") && !raw.hasSuffix("?") &&
           (cleaned.hasSuffix(".") || cleaned.hasSuffix("!") || cleaned.hasSuffix("?")) {
            changes.append("• Added ending punctuation")
        }
        
        // Length change
        let lengthDiff = raw.count - cleaned.count
        if lengthDiff > 0 {
            changes.append("• Reduced length by \(lengthDiff) characters")
        } else if lengthDiff < 0 {
            changes.append("• Increased length by \(-lengthDiff) characters")
        }
        
        return changes.isEmpty ? "No specific changes identified" : changes.joined(separator: "\n")
    }
}

// MARK: - Supporting Views

struct LogEntryRow: View {
    let entry: DebugManager.LogEntry
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: entry.category.icon)
                    .foregroundColor(colorForCategory(entry.category))
                    .frame(width: 16)
                
                Text(dateFormatter.string(from: entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(entry.category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(colorForCategory(entry.category))
                
                Spacer()
            }
            
            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
            
            if let details = entry.details {
                Text(details)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func colorForCategory(_ category: DebugManager.LogEntry.Category) -> Color {
        switch category {
        case .audio: return .blue
        case .transcription: return .green
        case .model: return .orange
        case .system: return .gray
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Window Controller

final class DebugLogWindowController: NSObject {
    private var debugWindow: NSWindow?
    private let debugManager: DebugManager
    
    init(debugManager: DebugManager) {
        self.debugManager = debugManager
        super.init()
    }
    
    func showDebugWindow() {
        if let existingWindow = debugWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let debugView = DebugLogView(debugManager: debugManager)
        let hostingController = NSHostingController(rootView: debugView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Voxa Debug Log"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 600, height: 500))
        window.center()
        window.setFrameAutosaveName("DebugLogWindow")
        
        // Handle window close
        window.delegate = self
        
        debugWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeDebugWindow() {
        debugWindow?.close()
        debugWindow = nil
    }
}

extension DebugLogWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        debugWindow = nil
    }
}
