import SwiftUI
import UniformTypeIdentifiers

/// Settings window for WispFlow configuration
/// Includes model management, audio settings, and general preferences
struct SettingsView: View {
    @ObservedObject var whisperManager: WhisperManager
    @ObservedObject var textCleanupManager: TextCleanupManager
    @ObservedObject var llmManager: LLMManager
    @ObservedObject var textInserter: TextInserter
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var debugManager: DebugManager
    var onOpenDebugWindow: (() -> Void)?
    @State private var isLoadingWhisperModel = false
    @State private var isLoadingCleanupModel = false
    @State private var isLoadingLLMModel = false
    @State private var showDeleteConfirmation = false
    @State private var showLLMDeleteConfirmation = false
    @State private var modelToDelete: WhisperManager.ModelSize?
    @State private var llmModelToDelete: LLMManager.ModelSize?
    
    var body: some View {
        TabView {
            // General tab (hotkey, launch at login)
            GeneralSettingsView(hotkeyManager: hotkeyManager)
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            // Transcription tab
            TranscriptionSettingsView(
                whisperManager: whisperManager,
                isLoadingModel: $isLoadingWhisperModel,
                showDeleteConfirmation: $showDeleteConfirmation,
                modelToDelete: $modelToDelete
            )
            .tabItem {
                Label("Transcription", systemImage: "waveform")
            }
            
            // Text Cleanup tab
            TextCleanupSettingsView(
                textCleanupManager: textCleanupManager,
                llmManager: llmManager,
                isLoadingModel: $isLoadingCleanupModel,
                isLoadingLLMModel: $isLoadingLLMModel,
                showLLMDeleteConfirmation: $showLLMDeleteConfirmation,
                llmModelToDelete: $llmModelToDelete
            )
            .tabItem {
                Label("Text Cleanup", systemImage: "text.badge.checkmark")
            }
            
            // Text Insertion tab
            TextInsertionSettingsView(textInserter: textInserter)
            .tabItem {
                Label("Text Insertion", systemImage: "doc.on.clipboard")
            }
            
            // Debug tab
            DebugSettingsView(debugManager: debugManager, onOpenDebugWindow: onOpenDebugWindow)
            .tabItem {
                Label("Debug", systemImage: "ladybug")
            }
        }
        .frame(width: 520, height: 580)
        .alert("Delete Model?", isPresented: $showDeleteConfirmation, presenting: modelToDelete) { model in
            Button("Delete", role: .destructive) {
                Task {
                    await whisperManager.deleteModel(model)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { model in
            Text("Are you sure you want to delete the \(model.displayName) model? You can re-download it later.")
        }
        .alert("Delete LLM Model?", isPresented: $showLLMDeleteConfirmation, presenting: llmModelToDelete) { model in
            Button("Delete", role: .destructive) {
                llmManager.deleteModel(model)
            }
            Button("Cancel", role: .cancel) {}
        } message: { model in
            Text("Are you sure you want to delete the \(model.displayName) model? You can re-download it later.")
        }
    }
}

// MARK: - Debug Settings

struct DebugSettingsView: View {
    @ObservedObject var debugManager: DebugManager
    var onOpenDebugWindow: (() -> Void)?
    @State private var showExportSuccess = false
    @State private var exportMessage = ""
    @State private var exportedFilePath: String? = nil
    @State private var isPlayingAudio = false
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Debug Mode toggle
                    Text("Debug Mode")
                        .font(.headline)
                    
                    Toggle("Enable Debug Mode", isOn: $debugManager.isDebugModeEnabled)
                        .toggleStyle(.switch)
                    
                    Text("When enabled, WispFlow will log detailed information about audio capture, transcription, and text cleanup. Use this to troubleshoot transcription issues.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Silence detection override (only available in debug mode)
                    if debugManager.isDebugModeEnabled {
                        Divider()
                        
                        Toggle("Disable Silence Detection", isOn: $debugManager.isSilenceDetectionDisabled)
                            .toggleStyle(.switch)
                        
                        Text("When enabled, audio will not be rejected for being too quiet. Useful for testing with silent or near-silent recordings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // US-306: Auto-save recordings toggle
                        Divider()
                        
                        Toggle("Auto-Save Recordings", isOn: $debugManager.isAutoSaveEnabled)
                            .toggleStyle(.switch)
                        
                        Text("When enabled, each recording will be automatically saved to Documents/WispFlow/DebugRecordings/ for later analysis.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if debugManager.isAutoSaveEnabled {
                            Button(action: {
                                AudioExporter.shared.openDebugRecordingsFolder()
                            }) {
                                HStack {
                                    Image(systemName: "folder")
                                    Text("Open Recordings Folder")
                                }
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 4)
                        }
                    }
                }
            }
            
            Divider()
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Debug window button
                    Text("Debug Tools")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            onOpenDebugWindow?()
                        }) {
                            HStack {
                                Image(systemName: "rectangle.and.text.magnifyingglass")
                                Text("Open Debug Window")
                            }
                            .frame(minWidth: 140)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!debugManager.isDebugModeEnabled)
                        
                        Button(action: exportLastAudio) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export Audio")
                            }
                            .frame(minWidth: 100)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!debugManager.isDebugModeEnabled || debugManager.lastRawAudioData == nil)
                    }
                    
                    // US-306: Quick export to Documents
                    if debugManager.isDebugModeEnabled && debugManager.lastRawAudioData != nil {
                        HStack(spacing: 12) {
                            Button(action: quickExportToDocuments) {
                                HStack {
                                    Image(systemName: "doc.badge.arrow.up")
                                    Text("Quick Export")
                                }
                                .frame(minWidth: 100)
                            }
                            .buttonStyle(.bordered)
                            .help("Export to Documents/WispFlow/DebugRecordings/")
                            
                            // US-306: Playback button (only if there's an exported file)
                            if AudioExporter.shared.lastExportedURL != nil {
                                Button(action: togglePlayback) {
                                    HStack {
                                        Image(systemName: isPlayingAudio ? "stop.fill" : "play.fill")
                                        Text(isPlayingAudio ? "Stop" : "Play")
                                    }
                                    .frame(minWidth: 80)
                                }
                                .buttonStyle(.bordered)
                                .tint(isPlayingAudio ? .red : .green)
                                
                                Button(action: {
                                    AudioExporter.shared.revealLastExportInFinder()
                                }) {
                                    HStack {
                                        Image(systemName: "folder.badge.questionmark")
                                        Text("Show in Finder")
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    
                    if !debugManager.isDebugModeEnabled {
                        Text("Enable Debug Mode to access debug tools")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // US-306: Show last export path if available
                    if let path = exportedFilePath {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Export:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(path)
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            
            Divider()
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Debug Features")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        DebugFeatureRow(icon: "waveform", text: "Audio waveform visualization")
                        DebugFeatureRow(icon: "doc.text", text: "Raw transcription before cleanup")
                        DebugFeatureRow(icon: "square.and.arrow.up", text: "Export audio as WAV file")
                        DebugFeatureRow(icon: "play.circle", text: "Playback exported audio")
                        DebugFeatureRow(icon: "list.bullet.rectangle", text: "Detailed real-time logs")
                        DebugFeatureRow(icon: "chart.bar", text: "Audio level statistics")
                    }
                }
            }
            
            Divider()
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    // Last recording info
                    Text("Last Recording")
                        .font(.headline)
                    
                    if let audioData = debugManager.lastAudioData {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Duration:")
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f seconds", audioData.duration))
                            }
                            .font(.caption)
                            
                            HStack {
                                Text("Peak Level:")
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f dB", audioData.peakLevel))
                                    .foregroundColor(audioData.peakLevel > -55 ? .green : .orange)
                            }
                            .font(.caption)
                            
                            HStack {
                                Text("Samples:")
                                    .foregroundColor(.secondary)
                                Text("\(audioData.samples.count)")
                            }
                            .font(.caption)
                            
                            // Mini waveform
                            CompactWaveformView(
                                samples: audioData.samples,
                                sampleRate: audioData.sampleRate
                            )
                            .frame(height: 40)
                            .padding(.top, 4)
                        }
                    } else {
                        Text("No recording data available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .alert("Export Result", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) {}
            if let _ = exportedFilePath {
                Button("Show in Finder") {
                    AudioExporter.shared.revealLastExportInFinder()
                }
                Button("Play Audio") {
                    togglePlayback()
                }
            }
        } message: {
            Text(exportMessage)
        }
        .onAppear {
            // Set up playback completion callback
            AudioExporter.shared.onPlaybackComplete = {
                isPlayingAudio = false
            }
            // Load last exported path if available
            if let url = AudioExporter.shared.lastExportedURL {
                exportedFilePath = url.path
            }
        }
    }
    
    // US-306: Toggle audio playback
    private func togglePlayback() {
        if isPlayingAudio {
            AudioExporter.shared.stopPlayback()
            isPlayingAudio = false
        } else {
            if AudioExporter.shared.playLastExport() {
                isPlayingAudio = true
            }
        }
    }
    
    // US-306: Quick export to Documents folder
    private func quickExportToDocuments() {
        guard let audioData = debugManager.lastRawAudioData else {
            exportMessage = "No audio data available to export"
            showExportSuccess = true
            return
        }
        
        let result = AudioExporter.shared.exportToDocuments(
            audioData: audioData,
            sampleRate: debugManager.lastRawAudioSampleRate
        )
        
        switch result {
        case .success(let url):
            exportMessage = "Audio exported successfully to:\n\(url.path)"
            exportedFilePath = url.path
        case .noAudioData:
            exportMessage = "No audio data available to export"
        case .exportFailed(let error):
            exportMessage = "Export failed: \(error)"
        }
        showExportSuccess = true
    }
    
    private func exportLastAudio() {
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
                    exportedFilePath = url.path
                case .noAudioData:
                    exportMessage = "No audio data available to export"
                case .exportFailed(let error):
                    exportMessage = "Export failed: \(error)"
                }
                showExportSuccess = true
            }
        }
    }
}

struct DebugFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Transcription Settings

struct TranscriptionSettingsView: View {
    @ObservedObject var whisperManager: WhisperManager
    @Binding var isLoadingModel: Bool
    @Binding var showDeleteConfirmation: Bool
    @Binding var modelToDelete: WhisperManager.ModelSize?
    @State private var showErrorAlert: Bool = false
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Model selection
                    Text("Whisper Model")
                        .font(.headline)
                    
                    Text("Select a model size. Larger models are more accurate but slower and use more memory.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Model Size", selection: Binding(
                        get: { whisperManager.selectedModel },
                        set: { model in
                            Task {
                                await whisperManager.selectModel(model)
                            }
                        }
                    )) {
                        ForEach(WhisperManager.ModelSize.allCases) { model in
                            HStack {
                                Text(model.displayName)
                                if whisperManager.isModelDownloaded(model) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }
                            .tag(model)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    
                    // Model description
                    Text(whisperManager.selectedModel.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                }
            }
            
            Divider()
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    // Status display
                    HStack {
                        Text("Status:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        StatusBadge(status: whisperManager.modelStatus)
                    }
                    
                    Text(whisperManager.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // US-304: Download progress bar (shown during download)
                    if case .downloading(let progress) = whisperManager.modelStatus {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: progress, total: 1.0)
                                .progressViewStyle(.linear)
                                .frame(maxWidth: 300)
                            Text("\(Int(progress * 100))% complete")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        // Load/Download button
                        Button(action: {
                            Task {
                                isLoadingModel = true
                                await whisperManager.loadModel()
                                isLoadingModel = false
                                // US-304: Show error alert if download failed
                                if case .error = whisperManager.modelStatus {
                                    showErrorAlert = true
                                }
                            }
                        }) {
                            HStack {
                                if isLoadingModel {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: buttonIconName)
                                }
                                Text(buttonTitle)
                            }
                            .frame(minWidth: 120)
                        }
                        .disabled(isLoadingModel || whisperManager.modelStatus == .ready)
                        .buttonStyle(.borderedProminent)
                        
                        // US-304: Retry button (shown when there's an error)
                        if case .error = whisperManager.modelStatus {
                            Button(action: {
                                Task {
                                    isLoadingModel = true
                                    await whisperManager.retryLoadModel()
                                    isLoadingModel = false
                                    // Show error alert if retry also failed
                                    if case .error = whisperManager.modelStatus {
                                        showErrorAlert = true
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry Download")
                                }
                            }
                            .disabled(isLoadingModel)
                            .buttonStyle(.bordered)
                            
                            // Show error details button
                            Button(action: {
                                showErrorAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "info.circle")
                                    Text("Error Details")
                                }
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                        
                        // Delete button (if model is downloaded)
                        if whisperManager.isModelDownloaded(whisperManager.selectedModel) {
                            Button(action: {
                                modelToDelete = whisperManager.selectedModel
                                showDeleteConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete")
                                }
                            }
                            .disabled(isLoadingModel)
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            
            Divider()
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Downloaded Models")
                        .font(.headline)
                    
                    let downloadedModels = whisperManager.getDownloadedModels()
                    if downloadedModels.isEmpty {
                        Text("No models downloaded yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(downloadedModels) { model in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(model.displayName)
                                    .font(.caption)
                                Spacer()
                                if model == whisperManager.selectedModel && whisperManager.modelStatus == .ready {
                                    Text("Active")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        // US-304: Error alert with detailed message
        .alert("Download Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let errorMessage = whisperManager.lastErrorMessage {
                Text(errorMessage)
            } else {
                Text(whisperManager.statusMessage)
            }
        }
    }
    
    private var buttonTitle: String {
        switch whisperManager.modelStatus {
        case .ready:
            return "Model Loaded"
        case .loading:
            return "Loading..."
        case .downloading:
            return "Downloading..."
        case .notDownloaded:
            return whisperManager.isModelDownloaded(whisperManager.selectedModel) ? "Load Model" : "Download & Load"
        case .downloaded:
            return "Load Model"
        case .error:
            return "Retry"
        }
    }
    
    private var buttonIconName: String {
        switch whisperManager.modelStatus {
        case .ready:
            return "checkmark.circle"
        case .loading, .downloading:
            return "arrow.clockwise"
        case .notDownloaded:
            return whisperManager.isModelDownloaded(whisperManager.selectedModel) ? "play.circle" : "arrow.down.circle"
        case .downloaded:
            return "play.circle"
        case .error:
            return "arrow.clockwise"
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: WhisperManager.ModelStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .notDownloaded:
            return .gray
        case .downloading, .loading:
            return .orange
        case .downloaded:
            return .blue
        case .ready:
            return .green
        case .error:
            return .red
        }
    }
    
    private var statusText: String {
        switch status {
        case .notDownloaded:
            return "Not Downloaded"
        case .downloading(let progress):
            return "Downloading \(Int(progress * 100))%"
        case .downloaded:
            return "Downloaded"
        case .loading:
            return "Loading"
        case .ready:
            return "Ready"
        case .error:
            return "Error"
        }
    }
}

// MARK: - Text Cleanup Settings

struct TextCleanupSettingsView: View {
    @ObservedObject var textCleanupManager: TextCleanupManager
    @ObservedObject var llmManager: LLMManager
    @Binding var isLoadingModel: Bool
    @Binding var isLoadingLLMModel: Bool
    @Binding var showLLMDeleteConfirmation: Bool
    @Binding var llmModelToDelete: LLMManager.ModelSize?
    
    // US-305: Error handling state
    @State private var showLLMErrorAlert = false
    @State private var showFilePicker = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Cleanup toggle section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable Text Cleanup", isOn: Binding(
                            get: { textCleanupManager.isCleanupEnabled },
                            set: { textCleanupManager.isCleanupEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        
                        Text("When enabled, transcribed text will be cleaned up to remove filler words, fix grammar, and improve formatting.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Mode selection section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cleanup Mode")
                            .font(.headline)
                        
                        Text("Select a cleanup mode. AI-Powered uses a local LLM for intelligent cleanup.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Cleanup Mode", selection: $textCleanupManager.selectedMode) {
                            ForEach(TextCleanupManager.CleanupMode.allCases) { mode in
                                HStack {
                                    Text(mode.displayName)
                                    if mode == .aiPowered {
                                        if llmManager.modelStatus == .ready {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.caption)
                                        } else if llmManager.isModelDownloaded(llmManager.selectedModel) {
                                            Image(systemName: "circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.caption)
                                        }
                                    }
                                }
                                .tag(mode)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .disabled(!textCleanupManager.isCleanupEnabled)
                        
                        Text(textCleanupManager.selectedMode.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }
                }
                
                // LLM Settings (only shown when AI-Powered mode is selected)
                if textCleanupManager.selectedMode == .aiPowered {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Local LLM Settings")
                                .font(.headline)
                            
                            // LLM Model selection
                            Picker("LLM Model", selection: Binding(
                                get: { llmManager.selectedModel },
                                set: { llmManager.selectModel($0) }
                            )) {
                                ForEach(LLMManager.ModelSize.allCases) { model in
                                    HStack {
                                        Text(model.displayName)
                                        if llmManager.isModelDownloaded(model) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.caption)
                                        }
                                    }
                                    .tag(model)
                                }
                            }
                            .pickerStyle(.radioGroup)
                            
                            Text(llmManager.selectedModel.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                            
                            Divider()
                            
                            // LLM Status
                            HStack {
                                Text("LLM Status:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                LLMStatusBadge(status: llmManager.modelStatus)
                            }
                            
                            Text(llmManager.statusMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // US-305: Download progress bar
                            if case .downloading(let progress) = llmManager.modelStatus {
                                VStack(alignment: .leading, spacing: 4) {
                                    ProgressView(value: progress)
                                        .progressViewStyle(.linear)
                                    Text("\(Int(progress * 100))% downloaded")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Action buttons
                            HStack(spacing: 12) {
                                // Main action button (Download/Load/Retry)
                                if case .error = llmManager.modelStatus {
                                    // US-305: Retry button for failed downloads
                                    Button(action: {
                                        Task {
                                            isLoadingLLMModel = true
                                            await llmManager.retryDownload()
                                            isLoadingLLMModel = false
                                            // Show error alert if retry also failed
                                            if case .error = llmManager.modelStatus {
                                                showLLMErrorAlert = true
                                            }
                                        }
                                    }) {
                                        HStack {
                                            if isLoadingLLMModel {
                                                ProgressView()
                                                    .scaleEffect(0.7)
                                                    .frame(width: 16, height: 16)
                                            } else {
                                                Image(systemName: "arrow.clockwise")
                                            }
                                            Text("Retry Download")
                                        }
                                        .frame(minWidth: 140)
                                    }
                                    .disabled(isLoadingLLMModel)
                                    .buttonStyle(.borderedProminent)
                                    .tint(.orange)
                                    
                                    // Error details button
                                    Button(action: {
                                        showLLMErrorAlert = true
                                    }) {
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle")
                                            Text("Error Details")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                } else {
                                    Button(action: {
                                        Task {
                                            isLoadingLLMModel = true
                                            await llmManager.loadModel()
                                            isLoadingLLMModel = false
                                            // Show error alert if download failed
                                            if case .error = llmManager.modelStatus {
                                                showLLMErrorAlert = true
                                            }
                                        }
                                    }) {
                                        HStack {
                                            if isLoadingLLMModel {
                                                ProgressView()
                                                    .scaleEffect(0.7)
                                                    .frame(width: 16, height: 16)
                                            } else {
                                                Image(systemName: llmButtonIconName)
                                            }
                                            Text(llmButtonTitle)
                                        }
                                        .frame(minWidth: 140)
                                    }
                                    .disabled(isLoadingLLMModel || llmManager.modelStatus == .ready)
                                    .buttonStyle(.borderedProminent)
                                }
                                
                                // Delete button (if model is downloaded)
                                if llmManager.isModelDownloaded(llmManager.selectedModel) {
                                    Button(action: {
                                        llmModelToDelete = llmManager.selectedModel
                                        showLLMDeleteConfirmation = true
                                    }) {
                                        HStack {
                                            Image(systemName: "trash")
                                            Text("Delete")
                                        }
                                    }
                                    .disabled(isLoadingLLMModel)
                                    .buttonStyle(.bordered)
                                }
                            }
                            
                            // US-305: Manual model path option as fallback
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Manual Model Path (Fallback)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("If automatic downloads fail, you can manually download a GGUF model file and specify its path here.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Toggle("Use custom model path", isOn: $llmManager.useCustomModelPath)
                                    .toggleStyle(.switch)
                                
                                if llmManager.useCustomModelPath {
                                    HStack {
                                        TextField("Path to .gguf file", text: $llmManager.customModelPath)
                                            .textFieldStyle(.roundedBorder)
                                        
                                        Button("Browse...") {
                                            showFilePicker = true
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                    
                                    if !llmManager.customModelPath.isEmpty {
                                        Button(action: {
                                            Task {
                                                isLoadingLLMModel = true
                                                await llmManager.loadModelFromCustomPath()
                                                isLoadingLLMModel = false
                                                if case .error = llmManager.modelStatus {
                                                    showLLMErrorAlert = true
                                                }
                                            }
                                        }) {
                                            HStack {
                                                if isLoadingLLMModel {
                                                    ProgressView()
                                                        .scaleEffect(0.7)
                                                        .frame(width: 16, height: 16)
                                                } else {
                                                    Image(systemName: "play.circle")
                                                }
                                                Text("Load Custom Model")
                                            }
                                        }
                                        .disabled(isLoadingLLMModel || llmManager.modelStatus == .ready)
                                        .buttonStyle(.borderedProminent)
                                    }
                                }
                            }
                        }
                    }
                    // US-305: Error alert
                    .alert("LLM Download Error", isPresented: $showLLMErrorAlert) {
                        Button("OK", role: .cancel) { }
                        Button("Retry") {
                            Task {
                                isLoadingLLMModel = true
                                await llmManager.retryDownload()
                                isLoadingLLMModel = false
                            }
                        }
                    } message: {
                        Text(llmManager.lastErrorMessage.isEmpty ? "An error occurred while downloading the model." : llmManager.lastErrorMessage)
                    }
                    // US-305: File picker for manual model path
                    .fileImporter(
                        isPresented: $showFilePicker,
                        allowedContentTypes: [.data],
                        allowsMultipleSelection: false
                    ) { result in
                        switch result {
                        case .success(let urls):
                            if let url = urls.first {
                                // Check if it's a .gguf file
                                if url.pathExtension.lowercased() == "gguf" {
                                    llmManager.customModelPath = url.path
                                } else {
                                    // Show error for non-gguf files
                                    llmManager.lastErrorMessage = "Please select a .gguf model file"
                                    showLLMErrorAlert = true
                                }
                            }
                        case .failure(let error):
                            llmManager.lastErrorMessage = "Failed to select file: \(error.localizedDescription)"
                            showLLMErrorAlert = true
                        }
                    }
                }
                
                // Status section
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Rule-based Status:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            CleanupStatusBadge(status: textCleanupManager.modelStatus)
                        }
                        
                        Text(textCleanupManager.statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Feature list section
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What Text Cleanup Does")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            CleanupFeatureRow(icon: "minus.circle", text: "Removes filler words (um, uh, like, you know)")
                            CleanupFeatureRow(icon: "checkmark.circle", text: "Fixes grammar and punctuation")
                            CleanupFeatureRow(icon: "textformat", text: "Proper capitalization")
                            CleanupFeatureRow(icon: "text.alignleft", text: "Natural text formatting")
                            if textCleanupManager.selectedMode == .aiPowered {
                                CleanupFeatureRow(icon: "brain", text: "AI-powered intelligent cleanup")
                                CleanupFeatureRow(icon: "arrow.uturn.backward", text: "Automatic fallback if LLM unavailable")
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var llmButtonTitle: String {
        switch llmManager.modelStatus {
        case .ready:
            return "LLM Loaded"
        case .loading:
            return "Loading..."
        case .downloading:
            return "Downloading..."
        case .notDownloaded:
            return llmManager.isModelDownloaded(llmManager.selectedModel) ? "Load LLM" : "Download & Load"
        case .downloaded:
            return "Load LLM"
        case .error:
            return "Retry"
        }
    }
    
    private var llmButtonIconName: String {
        switch llmManager.modelStatus {
        case .ready:
            return "checkmark.circle"
        case .loading, .downloading:
            return "arrow.clockwise"
        case .notDownloaded:
            return llmManager.isModelDownloaded(llmManager.selectedModel) ? "play.circle" : "arrow.down.circle"
        case .downloaded:
            return "play.circle"
        case .error:
            return "arrow.clockwise"
        }
    }
}

// MARK: - LLM Status Badge

struct LLMStatusBadge: View {
    let status: LLMManager.ModelStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .notDownloaded:
            return .gray
        case .downloading, .loading:
            return .orange
        case .downloaded:
            return .blue
        case .ready:
            return .green
        case .error:
            return .red
        }
    }
    
    private var statusText: String {
        switch status {
        case .notDownloaded:
            return "Not Downloaded"
        case .downloading(let progress):
            return "Downloading \(Int(progress * 100))%"
        case .downloaded:
            return "Downloaded"
        case .loading:
            return "Loading"
        case .ready:
            return "Ready"
        case .error:
            return "Error"
        }
    }
}

// MARK: - Cleanup Status Badge

struct CleanupStatusBadge: View {
    let status: TextCleanupManager.ModelStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .notDownloaded:
            return .gray
        case .downloading, .loading:
            return .orange
        case .downloaded:
            return .blue
        case .ready:
            return .green
        case .error:
            return .red
        }
    }
    
    private var statusText: String {
        switch status {
        case .notDownloaded:
            return "Not Downloaded"
        case .downloading(let progress):
            return "Downloading \(Int(progress * 100))%"
        case .downloaded:
            return "Downloaded"
        case .loading:
            return "Loading"
        case .ready:
            return "Ready"
        case .error:
            return "Error"
        }
    }
}

// MARK: - Cleanup Feature Row

struct CleanupFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Text Insertion Settings

struct TextInsertionSettingsView: View {
    @ObservedObject var textInserter: TextInserter
    @State private var showPermissionGrantedMessage = false
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Accessibility permission status
                    Text("Accessibility Permission")
                        .font(.headline)
                    
                    // Status indicator with checkmark/x icon
                    HStack(spacing: 8) {
                        Image(systemName: textInserter.hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(textInserter.hasAccessibilityPermission ? .green : .red)
                            .font(.system(size: 16))
                        Text(textInserter.hasAccessibilityPermission ? "Permission Granted" : "Permission Not Granted")
                            .font(.subheadline)
                            .foregroundColor(textInserter.hasAccessibilityPermission ? .green : .red)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((textInserter.hasAccessibilityPermission ? Color.green : Color.red).opacity(0.1))
                    .cornerRadius(8)
                    
                    // Show success message when permission is granted
                    if showPermissionGrantedMessage {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("Permission Granted!")
                                .font(.caption)
                                .foregroundColor(.green)
                                .bold()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(8)
                        .transition(.opacity.combined(with: .scale))
                    }
                    
                    if !textInserter.hasAccessibilityPermission {
                        // Step-by-step instructions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How to grant permission:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .bold()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text("1.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 16, alignment: .trailing)
                                    Text("Click \"Open System Settings\" below")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                HStack(alignment: .top, spacing: 8) {
                                    Text("2.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 16, alignment: .trailing)
                                    Text("Find WispFlow in the list and enable the toggle")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                HStack(alignment: .top, spacing: 8) {
                                    Text("3.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 16, alignment: .trailing)
                                    Text("Return to WispFlow - permission will be detected automatically")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        
                        // Action buttons
                        HStack(spacing: 12) {
                            Button(action: {
                                openAccessibilitySettings()
                            }) {
                                HStack {
                                    Image(systemName: "gear")
                                    Text("Open System Settings")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button(action: {
                                textInserter.recheckPermission()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Check Again")
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Text("Text insertion is enabled. Transcribed text will be automatically inserted into the active text field.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear {
                // Set up callback to show success message when permission is granted
                textInserter.onPermissionGranted = {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showPermissionGrantedMessage = true
                    }
                    // Hide the message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showPermissionGrantedMessage = false
                        }
                    }
                }
            }
            
            Divider()
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Clipboard preservation toggle
                    Text("Clipboard Options")
                        .font(.headline)
                    
                    Toggle("Preserve Clipboard Contents", isOn: $textInserter.preserveClipboard)
                        .toggleStyle(.switch)
                    
                    Text("When enabled, the original clipboard contents will be restored after text insertion.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if textInserter.preserveClipboard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Restore Delay: \(String(format: "%.1f", textInserter.clipboardRestoreDelay))s")
                                .font(.caption)
                            
                            Slider(value: $textInserter.clipboardRestoreDelay, in: 0.2...2.0, step: 0.1)
                                .frame(width: 200)
                            
                            Text("Time to wait before restoring the clipboard. Increase if the inserted text is getting cut off.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 20)
                    }
                }
            }
            
            Divider()
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How Text Insertion Works")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        InsertionFeatureRow(icon: "doc.on.clipboard", text: "Text is copied to the clipboard")
                        InsertionFeatureRow(icon: "command", text: "Cmd+V is simulated to paste")
                        InsertionFeatureRow(icon: "arrow.uturn.backward", text: "Original clipboard is restored (optional)")
                        InsertionFeatureRow(icon: "checkmark.circle", text: "Works in any text field")
                    }
                }
            }
        }
        .padding()
    }
    
    /// Open System Settings to the Accessibility pane
    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Insertion Feature Row

struct InsertionFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @State private var isRecordingHotkey = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Hotkey configuration
                    Text("Global Hotkey")
                        .font(.headline)
                    
                    Text("Press this keyboard shortcut from any app to start/stop voice recording.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        // Current hotkey display
                        HotkeyRecorderView(
                            hotkeyManager: hotkeyManager,
                            isRecording: $isRecordingHotkey
                        )
                        
                        // Reset to default button
                        Button(action: {
                            hotkeyManager.resetToDefault()
                        }) {
                            Text("Reset")
                        }
                        .disabled(hotkeyManager.configuration == .defaultHotkey)
                    }
                    
                    if isRecordingHotkey {
                        Text("Press your desired key combination...")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Divider()
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Launch at Login
                    Text("Startup")
                        .font(.headline)
                    
                    Toggle("Launch WispFlow at Login", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { _, newValue in
                            setLaunchAtLogin(enabled: newValue)
                        }
                    
                    Text("Automatically start WispFlow when you log in to your Mac.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About WispFlow")
                        .font(.headline)
                    
                    Text("Version 0.1 (MVP)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Voice-to-text dictation with AI-powered transcription and auto-editing. All processing happens locally on your device.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .onAppear {
            // Refresh launch at login status
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                print("Launch at login enabled")
            } else {
                try SMAppService.mainApp.unregister()
                print("Launch at login disabled")
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            // Revert the toggle on failure
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Hotkey Recorder View

struct HotkeyRecorderView: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @Binding var isRecording: Bool
    @State private var localEventMonitor: Any?
    
    var body: some View {
        Button(action: {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }) {
            HStack {
                if isRecording {
                    Image(systemName: "keyboard")
                        .foregroundColor(.orange)
                    Text("Recording...")
                        .foregroundColor(.orange)
                } else {
                    Text(hotkeyManager.hotkeyDisplayString)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .frame(minWidth: 120)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .onDisappear {
            stopRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        
        // Install a local event monitor to capture key presses
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            // Ignore modifier-only key presses (flagsChanged)
            if event.type == .keyDown {
                handleKeyEvent(event)
                return nil // Consume the event
            }
            return event
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        // Get modifiers (excluding caps lock, function, etc.)
        let relevantFlags: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let modifiers = event.modifierFlags.intersection(relevantFlags)
        
        // Require at least one modifier key
        guard !modifiers.isEmpty else {
            print("HotkeyRecorder: Hotkey must include at least one modifier (Cmd, Shift, Option, or Control)")
            return
        }
        
        // Ignore Escape key (cancel)
        if event.keyCode == 53 { // kVK_Escape
            stopRecording()
            return
        }
        
        // Create new configuration
        let newConfig = HotkeyManager.HotkeyConfiguration(
            keyCode: event.keyCode,
            modifierFlags: modifiers
        )
        
        // Update the hotkey manager (this persists automatically)
        hotkeyManager.updateConfiguration(newConfig)
        
        // Stop recording
        stopRecording()
        
        print("HotkeyRecorder: New hotkey set to \(newConfig.displayString)")
    }
}

import ServiceManagement

// MARK: - Settings Window Controller

final class SettingsWindowController: NSObject {
    private var settingsWindow: NSWindow?
    private let whisperManager: WhisperManager
    private let textCleanupManager: TextCleanupManager
    private let llmManager: LLMManager
    private let textInserter: TextInserter
    private let hotkeyManager: HotkeyManager
    private let debugManager: DebugManager
    private var debugLogWindowController: DebugLogWindowController?
    
    init(whisperManager: WhisperManager, textCleanupManager: TextCleanupManager, llmManager: LLMManager, textInserter: TextInserter, hotkeyManager: HotkeyManager, debugManager: DebugManager) {
        self.whisperManager = whisperManager
        self.textCleanupManager = textCleanupManager
        self.llmManager = llmManager
        self.textInserter = textInserter
        self.hotkeyManager = hotkeyManager
        self.debugManager = debugManager
        self.debugLogWindowController = DebugLogWindowController(debugManager: debugManager)
        super.init()
    }
    
    func showSettings() {
        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView(
            whisperManager: whisperManager,
            textCleanupManager: textCleanupManager,
            llmManager: llmManager,
            textInserter: textInserter,
            hotkeyManager: hotkeyManager,
            debugManager: debugManager,
            onOpenDebugWindow: { [weak self] in
                self?.showDebugWindow()
            }
        )
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "WispFlow Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        
        // Handle window close
        window.delegate = self
        
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func showDebugWindow() {
        debugLogWindowController?.showDebugWindow()
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        settingsWindow = nil
    }
}

// Import SwiftUI hosting controller
import AppKit
