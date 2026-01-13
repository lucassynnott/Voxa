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
        ZStack {
            // Warm ivory background
            Color.Wispflow.background
                .ignoresSafeArea()
            
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
            .background(Color.Wispflow.background)
        }
        .frame(width: 620, height: 560)
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
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Debug Mode toggle card
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Debug Mode")
                        .font(Font.Wispflow.headline)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    Toggle("Enable Debug Mode", isOn: $debugManager.isDebugModeEnabled)
                        .toggleStyle(WispflowToggleStyle())
                        .font(Font.Wispflow.body)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    Text("When enabled, WispFlow will log detailed information about audio capture, transcription, and text cleanup. Use this to troubleshoot transcription issues.")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                    
                    // Silence detection override (only available in debug mode)
                    if debugManager.isDebugModeEnabled {
                        Divider()
                            .background(Color.Wispflow.border)
                        
                        Toggle("Disable Silence Detection", isOn: $debugManager.isSilenceDetectionDisabled)
                            .toggleStyle(WispflowToggleStyle())
                            .font(Font.Wispflow.body)
                            .foregroundColor(Color.Wispflow.textPrimary)
                        
                        Text("When enabled, audio will not be rejected for being too quiet. Useful for testing with silent or near-silent recordings.")
                            .font(Font.Wispflow.caption)
                            .foregroundColor(Color.Wispflow.textSecondary)
                        
                        // US-306: Auto-save recordings toggle
                        Divider()
                            .background(Color.Wispflow.border)
                        
                        Toggle("Auto-Save Recordings", isOn: $debugManager.isAutoSaveEnabled)
                            .toggleStyle(WispflowToggleStyle())
                            .font(Font.Wispflow.body)
                            .foregroundColor(Color.Wispflow.textPrimary)
                        
                        Text("When enabled, each recording will be automatically saved to Documents/WispFlow/DebugRecordings/ for later analysis.")
                            .font(Font.Wispflow.caption)
                            .foregroundColor(Color.Wispflow.textSecondary)
                        
                        if debugManager.isAutoSaveEnabled {
                            Button(action: {
                                AudioExporter.shared.openDebugRecordingsFolder()
                            }) {
                                HStack {
                                    Image(systemName: "folder")
                                    Text("Open Recordings Folder")
                                }
                            }
                            .buttonStyle(WispflowButtonStyle.secondary)
                            .padding(.top, Spacing.xs)
                        }
                    }
                }
                .wispflowCard()
                
                // Debug Tools card
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Debug Tools")
                        .font(Font.Wispflow.headline)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    HStack(spacing: Spacing.md) {
                        Button(action: {
                            onOpenDebugWindow?()
                        }) {
                            HStack {
                                Image(systemName: "rectangle.and.text.magnifyingglass")
                                Text("Open Debug Window")
                            }
                        }
                        .buttonStyle(WispflowButtonStyle.primary)
                        .disabled(!debugManager.isDebugModeEnabled)
                        
                        Button(action: exportLastAudio) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export Audio")
                            }
                        }
                        .buttonStyle(WispflowButtonStyle.secondary)
                        .disabled(!debugManager.isDebugModeEnabled || debugManager.lastRawAudioData == nil)
                    }
                    
                    // US-306: Quick export to Documents
                    if debugManager.isDebugModeEnabled && debugManager.lastRawAudioData != nil {
                        HStack(spacing: Spacing.md) {
                            Button(action: quickExportToDocuments) {
                                HStack {
                                    Image(systemName: "doc.badge.arrow.up")
                                    Text("Quick Export")
                                }
                            }
                            .buttonStyle(WispflowButtonStyle.secondary)
                            .help("Export to Documents/WispFlow/DebugRecordings/")
                            
                            // US-306: Playback button (only if there's an exported file)
                            if AudioExporter.shared.lastExportedURL != nil {
                                Button(action: togglePlayback) {
                                    HStack {
                                        Image(systemName: isPlayingAudio ? "stop.fill" : "play.fill")
                                        Text(isPlayingAudio ? "Stop" : "Play")
                                    }
                                }
                                .buttonStyle(WispflowButtonStyle(variant: isPlayingAudio ? .ghost : .secondary))
                                
                                Button(action: {
                                    AudioExporter.shared.revealLastExportInFinder()
                                }) {
                                    HStack {
                                        Image(systemName: "folder.badge.questionmark")
                                        Text("Show in Finder")
                                    }
                                }
                                .buttonStyle(WispflowButtonStyle.secondary)
                            }
                        }
                    }
                    
                    if !debugManager.isDebugModeEnabled {
                        Text("Enable Debug Mode to access debug tools")
                            .font(Font.Wispflow.caption)
                            .foregroundColor(Color.Wispflow.textSecondary)
                    }
                    
                    // US-306: Show last export path if available
                    if let path = exportedFilePath {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Last Export:")
                                .font(Font.Wispflow.caption)
                                .foregroundColor(Color.Wispflow.textSecondary)
                            Text(path)
                                .font(Font.Wispflow.small)
                                .foregroundColor(Color.Wispflow.accent)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                        .padding(.top, Spacing.sm)
                    }
                }
                .wispflowCard()
                
                // Debug Features card
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Debug Features")
                        .font(Font.Wispflow.headline)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        DebugFeatureRow(icon: "waveform", text: "Audio waveform visualization")
                        DebugFeatureRow(icon: "doc.text", text: "Raw transcription before cleanup")
                        DebugFeatureRow(icon: "square.and.arrow.up", text: "Export audio as WAV file")
                        DebugFeatureRow(icon: "play.circle", text: "Playback exported audio")
                        DebugFeatureRow(icon: "list.bullet.rectangle", text: "Detailed real-time logs")
                        DebugFeatureRow(icon: "chart.bar", text: "Audio level statistics")
                    }
                }
                .wispflowCard()
                
                // Last Recording card
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Last Recording")
                        .font(Font.Wispflow.headline)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    if let audioData = debugManager.lastAudioData {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            HStack {
                                Text("Duration:")
                                    .foregroundColor(Color.Wispflow.textSecondary)
                                Text(String(format: "%.2f seconds", audioData.duration))
                                    .foregroundColor(Color.Wispflow.textPrimary)
                            }
                            .font(Font.Wispflow.caption)
                            
                            HStack {
                                Text("Peak Level:")
                                    .foregroundColor(Color.Wispflow.textSecondary)
                                Text(String(format: "%.1f dB", audioData.peakLevel))
                                    .foregroundColor(audioData.peakLevel > -55 ? Color.Wispflow.success : Color.Wispflow.warning)
                            }
                            .font(Font.Wispflow.caption)
                            
                            HStack {
                                Text("Samples:")
                                    .foregroundColor(Color.Wispflow.textSecondary)
                                Text("\(audioData.samples.count)")
                                    .foregroundColor(Color.Wispflow.textPrimary)
                            }
                            .font(Font.Wispflow.caption)
                            
                            // Mini waveform
                            CompactWaveformView(
                                samples: audioData.samples,
                                sampleRate: audioData.sampleRate
                            )
                            .frame(height: 40)
                            .padding(.top, Spacing.xs)
                        }
                    } else {
                        Text("No recording data available")
                            .font(Font.Wispflow.caption)
                            .foregroundColor(Color.Wispflow.textSecondary)
                    }
                }
                .wispflowCard()
                
                Spacer()
            }
            .padding(Spacing.xl)
        }
        .background(Color.Wispflow.background)
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
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(Color.Wispflow.textSecondary)
                .frame(width: 16)
            Text(text)
                .font(Font.Wispflow.caption)
                .foregroundColor(Color.Wispflow.textSecondary)
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
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Model selection card
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Whisper Model")
                        .font(Font.Wispflow.headline)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    Text("Select a model size. Larger models are more accurate but slower and use more memory.")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                    
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
                                    .foregroundColor(Color.Wispflow.textPrimary)
                                if whisperManager.isModelDownloaded(model) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color.Wispflow.success)
                                        .font(.caption)
                                }
                            }
                            .tag(model)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    
                    // Model description
                    Text(whisperManager.selectedModel.description)
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .padding(.leading, Spacing.xl)
                }
                .wispflowCard()
                
                // Status and Actions card
                VStack(alignment: .leading, spacing: Spacing.md) {
                    // Status display
                    HStack {
                        Text("Status:")
                            .font(Font.Wispflow.body)
                            .foregroundColor(Color.Wispflow.textSecondary)
                        
                        StatusBadge(status: whisperManager.modelStatus)
                    }
                    
                    Text(whisperManager.statusMessage)
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                    
                    // US-304: Download progress bar (shown during download)
                    if case .downloading(let progress) = whisperManager.modelStatus {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            // Custom gradient progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: CornerRadius.small / 2)
                                        .fill(Color.Wispflow.border)
                                    RoundedRectangle(cornerRadius: CornerRadius.small / 2)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.Wispflow.accent.opacity(0.8), Color.Wispflow.accent],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * CGFloat(progress))
                                }
                            }
                            .frame(height: 8)
                            .frame(maxWidth: 300)
                            
                            Text("\(Int(progress * 100))% complete")
                                .font(Font.Wispflow.small)
                                .foregroundColor(Color.Wispflow.textSecondary)
                        }
                        .padding(.top, Spacing.xs)
                    }
                    
                    // Action buttons
                    HStack(spacing: Spacing.md) {
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
                        }
                        .disabled(isLoadingModel || whisperManager.modelStatus == .ready)
                        .buttonStyle(WispflowButtonStyle.primary)
                        
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
                            .buttonStyle(WispflowButtonStyle.secondary)
                            
                            // Show error details button
                            Button(action: {
                                showErrorAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "info.circle")
                                    Text("Error Details")
                                }
                            }
                            .buttonStyle(WispflowButtonStyle.ghost)
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
                            .buttonStyle(WispflowButtonStyle.secondary)
                        }
                    }
                }
                .wispflowCard()
                
                // Downloaded Models card
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Downloaded Models")
                        .font(Font.Wispflow.headline)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    let downloadedModels = whisperManager.getDownloadedModels()
                    if downloadedModels.isEmpty {
                        Text("No models downloaded yet")
                            .font(Font.Wispflow.caption)
                            .foregroundColor(Color.Wispflow.textSecondary)
                    } else {
                        ForEach(downloadedModels) { model in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color.Wispflow.success)
                                Text(model.displayName)
                                    .font(Font.Wispflow.caption)
                                    .foregroundColor(Color.Wispflow.textPrimary)
                                Spacer()
                                if model == whisperManager.selectedModel && whisperManager.modelStatus == .ready {
                                    Text("Active")
                                        .font(Font.Wispflow.small)
                                        .padding(.horizontal, Spacing.sm)
                                        .padding(.vertical, Spacing.xs)
                                        .background(Color.Wispflow.accentLight)
                                        .foregroundColor(Color.Wispflow.accent)
                                        .cornerRadius(CornerRadius.small / 2)
                                }
                            }
                        }
                    }
                }
                .wispflowCard()
                
                Spacer()
            }
            .padding(Spacing.xl)
        }
        .background(Color.Wispflow.background)
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
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(Font.Wispflow.caption)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(statusColor.opacity(0.15))
        .cornerRadius(CornerRadius.small)
    }
    
    private var statusColor: Color {
        switch status {
        case .notDownloaded:
            return Color.Wispflow.textSecondary
        case .downloading, .loading:
            return Color.Wispflow.warning
        case .downloaded:
            return Color.Wispflow.accent
        case .ready:
            return Color.Wispflow.success
        case .error:
            return Color.Wispflow.error
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
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Cleanup toggle card
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Toggle("Enable Text Cleanup", isOn: Binding(
                        get: { textCleanupManager.isCleanupEnabled },
                        set: { textCleanupManager.isCleanupEnabled = $0 }
                    ))
                    .toggleStyle(WispflowToggleStyle())
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.textPrimary)
                    
                    Text("When enabled, transcribed text will be cleaned up to remove filler words, fix grammar, and improve formatting.")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                }
                .wispflowCard()
                
                // Mode selection card
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Cleanup Mode")
                        .font(Font.Wispflow.headline)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    Text("Select a cleanup mode. AI-Powered uses a local LLM for intelligent cleanup.")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                    
                    Picker("Cleanup Mode", selection: $textCleanupManager.selectedMode) {
                        ForEach(TextCleanupManager.CleanupMode.allCases) { mode in
                            HStack {
                                Text(mode.displayName)
                                    .foregroundColor(Color.Wispflow.textPrimary)
                                if mode == .aiPowered {
                                    if llmManager.modelStatus == .ready {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color.Wispflow.success)
                                            .font(.caption)
                                    } else if llmManager.isModelDownloaded(llmManager.selectedModel) {
                                        Image(systemName: "circle.fill")
                                            .foregroundColor(Color.Wispflow.accent)
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
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .padding(.leading, Spacing.xl)
                }
                .wispflowCard()
                
                // LLM Settings (only shown when AI-Powered mode is selected)
                if textCleanupManager.selectedMode == .aiPowered {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Local LLM Settings")
                            .font(Font.Wispflow.headline)
                            .foregroundColor(Color.Wispflow.textPrimary)
                        
                        // LLM Model selection
                        Picker("LLM Model", selection: Binding(
                            get: { llmManager.selectedModel },
                            set: { llmManager.selectModel($0) }
                        )) {
                            ForEach(LLMManager.ModelSize.allCases) { model in
                                HStack {
                                    Text(model.displayName)
                                        .foregroundColor(Color.Wispflow.textPrimary)
                                    if llmManager.isModelDownloaded(model) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color.Wispflow.success)
                                            .font(.caption)
                                    }
                                }
                                .tag(model)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        
                        Text(llmManager.selectedModel.description)
                            .font(Font.Wispflow.caption)
                            .foregroundColor(Color.Wispflow.textSecondary)
                            .padding(.leading, Spacing.xl)
                        
                        Divider()
                            .background(Color.Wispflow.border)
                        
                        // LLM Status
                        HStack {
                            Text("LLM Status:")
                                .font(Font.Wispflow.body)
                                .foregroundColor(Color.Wispflow.textSecondary)
                            
                            LLMStatusBadge(status: llmManager.modelStatus)
                        }
                        
                        Text(llmManager.statusMessage)
                            .font(Font.Wispflow.caption)
                            .foregroundColor(Color.Wispflow.textSecondary)
                        
                        // US-305: Download progress bar
                        if case .downloading(let progress) = llmManager.modelStatus {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                // Custom gradient progress bar
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: CornerRadius.small / 2)
                                            .fill(Color.Wispflow.border)
                                        RoundedRectangle(cornerRadius: CornerRadius.small / 2)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.Wispflow.accent.opacity(0.8), Color.Wispflow.accent],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geometry.size.width * CGFloat(progress))
                                    }
                                }
                                .frame(height: 8)
                                .frame(maxWidth: 300)
                                
                                Text("\(Int(progress * 100))% downloaded")
                                    .font(Font.Wispflow.small)
                                    .foregroundColor(Color.Wispflow.textSecondary)
                            }
                        }
                        
                        // Action buttons
                        HStack(spacing: Spacing.md) {
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
                                }
                                .disabled(isLoadingLLMModel)
                                .buttonStyle(WispflowButtonStyle(variant: .primary))
                                
                                // Error details button
                                Button(action: {
                                    showLLMErrorAlert = true
                                }) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle")
                                        Text("Error Details")
                                    }
                                }
                                .buttonStyle(WispflowButtonStyle.ghost)
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
                                }
                                .disabled(isLoadingLLMModel || llmManager.modelStatus == .ready)
                                .buttonStyle(WispflowButtonStyle.primary)
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
                                .buttonStyle(WispflowButtonStyle.secondary)
                            }
                        }
                        
                        // US-305: Manual model path option as fallback
                        Divider()
                            .background(Color.Wispflow.border)
                        
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Manual Model Path (Fallback)")
                                .font(Font.Wispflow.body)
                                .fontWeight(.medium)
                                .foregroundColor(Color.Wispflow.textPrimary)
                            
                            Text("If automatic downloads fail, you can manually download a GGUF model file and specify its path here.")
                                .font(Font.Wispflow.caption)
                                .foregroundColor(Color.Wispflow.textSecondary)
                            
                            Toggle("Use custom model path", isOn: $llmManager.useCustomModelPath)
                                .toggleStyle(WispflowToggleStyle())
                                .font(Font.Wispflow.body)
                                .foregroundColor(Color.Wispflow.textPrimary)
                            
                            if llmManager.useCustomModelPath {
                                HStack {
                                    TextField("Path to .gguf file", text: $llmManager.customModelPath)
                                        .textFieldStyle(.roundedBorder)
                                    
                                    Button("Browse...") {
                                        showFilePicker = true
                                    }
                                    .buttonStyle(WispflowButtonStyle.secondary)
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
                                    .buttonStyle(WispflowButtonStyle.primary)
                                }
                            }
                        }
                    }
                    .wispflowCard()
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
                
                // Status card
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Text("Rule-based Status:")
                            .font(Font.Wispflow.body)
                            .foregroundColor(Color.Wispflow.textSecondary)
                        
                        CleanupStatusBadge(status: textCleanupManager.modelStatus)
                    }
                    
                    Text(textCleanupManager.statusMessage)
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                }
                .wispflowCard()
                
                // Feature list card
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("What Text Cleanup Does")
                        .font(Font.Wispflow.headline)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    VStack(alignment: .leading, spacing: Spacing.xs) {
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
                .wispflowCard()
                
                Spacer()
            }
            .padding(Spacing.xl)
        }
        .background(Color.Wispflow.background)
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
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(Font.Wispflow.caption)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(statusColor.opacity(0.15))
        .cornerRadius(CornerRadius.small)
    }
    
    private var statusColor: Color {
        switch status {
        case .notDownloaded:
            return Color.Wispflow.textSecondary
        case .downloading, .loading:
            return Color.Wispflow.warning
        case .downloaded:
            return Color.Wispflow.accent
        case .ready:
            return Color.Wispflow.success
        case .error:
            return Color.Wispflow.error
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
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(Font.Wispflow.caption)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(statusColor.opacity(0.15))
        .cornerRadius(CornerRadius.small)
    }
    
    private var statusColor: Color {
        switch status {
        case .notDownloaded:
            return Color.Wispflow.textSecondary
        case .downloading, .loading:
            return Color.Wispflow.warning
        case .downloaded:
            return Color.Wispflow.accent
        case .ready:
            return Color.Wispflow.success
        case .error:
            return Color.Wispflow.error
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
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(Color.Wispflow.textSecondary)
                .frame(width: 16)
            Text(text)
                .font(Font.Wispflow.caption)
                .foregroundColor(Color.Wispflow.textSecondary)
        }
    }
}

// MARK: - Text Insertion Settings

struct TextInsertionSettingsView: View {
    @ObservedObject var textInserter: TextInserter
    @State private var showPermissionGrantedMessage = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Accessibility Permission card
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Accessibility Permission")
                        .font(Font.Wispflow.headline)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    // Status indicator with checkmark/x icon
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: textInserter.hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(textInserter.hasAccessibilityPermission ? Color.Wispflow.success : Color.Wispflow.error)
                            .font(.system(size: 16))
                        Text(textInserter.hasAccessibilityPermission ? "Permission Granted" : "Permission Not Granted")
                            .font(Font.Wispflow.body)
                            .foregroundColor(textInserter.hasAccessibilityPermission ? Color.Wispflow.success : Color.Wispflow.error)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background((textInserter.hasAccessibilityPermission ? Color.Wispflow.success : Color.Wispflow.error).opacity(0.1))
                    .cornerRadius(CornerRadius.small)
                    
                    // Show success message when permission is granted
                    if showPermissionGrantedMessage {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(Color.Wispflow.success)
                            Text("Permission Granted!")
                                .font(Font.Wispflow.caption)
                                .foregroundColor(Color.Wispflow.success)
                                .bold()
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.Wispflow.successLight)
                        .cornerRadius(CornerRadius.small)
                        .transition(.opacity.combined(with: .scale))
                    }
                    
                    if !textInserter.hasAccessibilityPermission {
                        // Step-by-step instructions
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("How to grant permission:")
                                .font(Font.Wispflow.caption)
                                .foregroundColor(Color.Wispflow.textSecondary)
                                .bold()
                            
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                HStack(alignment: .top, spacing: Spacing.sm) {
                                    Text("1.")
                                        .font(Font.Wispflow.caption)
                                        .foregroundColor(Color.Wispflow.textSecondary)
                                        .frame(width: 16, alignment: .trailing)
                                    Text("Click \"Open System Settings\" below")
                                        .font(Font.Wispflow.caption)
                                        .foregroundColor(Color.Wispflow.textSecondary)
                                }
                                HStack(alignment: .top, spacing: Spacing.sm) {
                                    Text("2.")
                                        .font(Font.Wispflow.caption)
                                        .foregroundColor(Color.Wispflow.textSecondary)
                                        .frame(width: 16, alignment: .trailing)
                                    Text("Find WispFlow in the list and enable the toggle")
                                        .font(Font.Wispflow.caption)
                                        .foregroundColor(Color.Wispflow.textSecondary)
                                }
                                HStack(alignment: .top, spacing: Spacing.sm) {
                                    Text("3.")
                                        .font(Font.Wispflow.caption)
                                        .foregroundColor(Color.Wispflow.textSecondary)
                                        .frame(width: 16, alignment: .trailing)
                                    Text("Return to WispFlow - permission will be detected automatically")
                                        .font(Font.Wispflow.caption)
                                        .foregroundColor(Color.Wispflow.textSecondary)
                                }
                            }
                        }
                        .padding(.vertical, Spacing.xs)
                        
                        // Action buttons
                        HStack(spacing: Spacing.md) {
                            Button(action: {
                                openAccessibilitySettings()
                            }) {
                                HStack {
                                    Image(systemName: "gear")
                                    Text("Open System Settings")
                                }
                            }
                            .buttonStyle(WispflowButtonStyle.primary)
                            
                            Button(action: {
                                textInserter.recheckPermission()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Check Again")
                                }
                            }
                            .buttonStyle(WispflowButtonStyle.secondary)
                        }
                    } else {
                        Text("Text insertion is enabled. Transcribed text will be automatically inserted into the active text field.")
                            .font(Font.Wispflow.caption)
                            .foregroundColor(Color.Wispflow.textSecondary)
                    }
                }
                .wispflowCard()
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
                
                // Clipboard Options card
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Clipboard Options")
                        .font(Font.Wispflow.headline)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    Toggle("Preserve Clipboard Contents", isOn: $textInserter.preserveClipboard)
                        .toggleStyle(WispflowToggleStyle())
                        .font(Font.Wispflow.body)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    Text("When enabled, the original clipboard contents will be restored after text insertion.")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                    
                    if textInserter.preserveClipboard {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Restore Delay: \(String(format: "%.1f", textInserter.clipboardRestoreDelay))s")
                                .font(Font.Wispflow.caption)
                                .foregroundColor(Color.Wispflow.textPrimary)
                            
                            Slider(value: $textInserter.clipboardRestoreDelay, in: 0.2...2.0, step: 0.1)
                                .frame(width: 200)
                                .tint(Color.Wispflow.accent)
                            
                            Text("Time to wait before restoring the clipboard. Increase if the inserted text is getting cut off.")
                                .font(Font.Wispflow.small)
                                .foregroundColor(Color.Wispflow.textSecondary)
                        }
                        .padding(.leading, Spacing.xl)
                    }
                }
                .wispflowCard()
                
                // How Text Insertion Works card
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("How Text Insertion Works")
                        .font(Font.Wispflow.headline)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        InsertionFeatureRow(icon: "doc.on.clipboard", text: "Text is copied to the clipboard")
                        InsertionFeatureRow(icon: "command", text: "Cmd+V is simulated to paste")
                        InsertionFeatureRow(icon: "arrow.uturn.backward", text: "Original clipboard is restored (optional)")
                        InsertionFeatureRow(icon: "checkmark.circle", text: "Works in any text field")
                    }
                }
                .wispflowCard()
                
                Spacer()
            }
            .padding(Spacing.xl)
        }
        .background(Color.Wispflow.background)
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
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(Color.Wispflow.textSecondary)
                .frame(width: 16)
            Text(text)
                .font(Font.Wispflow.caption)
                .foregroundColor(Color.Wispflow.textSecondary)
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @State private var isRecordingHotkey = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    
    /// Get the app version from the bundle
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.5"
    }
    
    /// Get the build number from the bundle
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // About WispFlow card - Hero section with logo
                VStack(spacing: Spacing.lg) {
                    // Logo and branding
                    VStack(spacing: Spacing.md) {
                        // App Icon representation using SF Symbols
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.Wispflow.accent.opacity(0.15), Color.Wispflow.accent.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 44, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.Wispflow.accent, Color.Wispflow.accent.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        // App name with design system typography
                        Text("WispFlow")
                            .font(Font.Wispflow.largeTitle)
                            .foregroundColor(Color.Wispflow.textPrimary)
                        
                        // Version display with subtle styling
                        Text("Version \(appVersion)")
                            .font(Font.Wispflow.caption)
                            .foregroundColor(Color.Wispflow.textSecondary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .background(Color.Wispflow.border.opacity(0.5))
                            .cornerRadius(CornerRadius.small / 2)
                    }
                    
                    // Tagline
                    Text("Voice-to-text dictation with AI-powered transcription and auto-editing. All processing happens locally on your device.")
                        .font(Font.Wispflow.body)
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Links styled as subtle buttons
                    HStack(spacing: Spacing.md) {
                        SubtleLinkButton(
                            title: "GitHub",
                            icon: "chevron.left.forwardslash.chevron.right",
                            url: "https://github.com"
                        )
                        
                        SubtleLinkButton(
                            title: "Website",
                            icon: "globe",
                            url: "https://wispflow.app"
                        )
                        
                        SubtleLinkButton(
                            title: "Support",
                            icon: "questionmark.circle",
                            url: "https://wispflow.app/support"
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .wispflowCard()
                
                // Hotkey configuration card
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "keyboard")
                            .foregroundColor(Color.Wispflow.accent)
                            .font(.system(size: 16, weight: .medium))
                        Text("Global Hotkey")
                            .font(Font.Wispflow.headline)
                            .foregroundColor(Color.Wispflow.textPrimary)
                    }
                    
                    Text("Press this keyboard shortcut from any app to start/stop voice recording.")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                    
                    HStack(spacing: Spacing.md) {
                        // Current hotkey display
                        HotkeyRecorderView(
                            hotkeyManager: hotkeyManager,
                            isRecording: $isRecordingHotkey
                        )
                        
                        // Reset to default button
                        Button(action: {
                            hotkeyManager.resetToDefault()
                        }) {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset")
                            }
                        }
                        .buttonStyle(WispflowButtonStyle.secondary)
                        .disabled(hotkeyManager.configuration == .defaultHotkey)
                    }
                    
                    if isRecordingHotkey {
                        HStack(spacing: Spacing.sm) {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                            Text("Press your desired key combination...")
                                .font(Font.Wispflow.caption)
                                .foregroundColor(Color.Wispflow.accent)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .wispflowCard()
                .animation(.easeInOut(duration: 0.2), value: isRecordingHotkey)
                
                // Launch at Login card
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "power")
                            .foregroundColor(Color.Wispflow.accent)
                            .font(.system(size: 16, weight: .medium))
                        Text("Startup")
                            .font(Font.Wispflow.headline)
                            .foregroundColor(Color.Wispflow.textPrimary)
                    }
                    
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Toggle("Launch WispFlow at Login", isOn: $launchAtLogin)
                            .toggleStyle(WispflowToggleStyle())
                            .font(Font.Wispflow.body)
                            .foregroundColor(Color.Wispflow.textPrimary)
                            .onChange(of: launchAtLogin) { _, newValue in
                                setLaunchAtLogin(enabled: newValue)
                            }
                        
                        Text("Automatically start WispFlow when you log in to your Mac. WispFlow runs quietly in the menu bar.")
                            .font(Font.Wispflow.caption)
                            .foregroundColor(Color.Wispflow.textSecondary)
                            .padding(.leading, Spacing.xxl + Spacing.md) // Align with toggle label
                    }
                }
                .wispflowCard()
                
                Spacer()
            }
            .padding(Spacing.xl)
        }
        .background(Color.Wispflow.background)
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

// MARK: - Subtle Link Button

/// A subtle button-styled link for the About section
struct SubtleLinkButton: View {
    let title: String
    let icon: String
    let url: String
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: {
            if let linkURL = URL(string: url) {
                NSWorkspace.shared.open(linkURL)
            }
        }) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(Font.Wispflow.caption)
            }
            .foregroundColor(isHovering ? Color.Wispflow.accent : Color.Wispflow.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(isHovering ? Color.Wispflow.accentLight : Color.Wispflow.border.opacity(0.3))
            .cornerRadius(CornerRadius.small)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Hotkey Recorder View

struct HotkeyRecorderView: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @Binding var isRecording: Bool
    @State private var localEventMonitor: Any?
    @State private var isHovering = false
    @State private var pulseAnimation = false
    
    var body: some View {
        Button(action: {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }) {
            HStack(spacing: Spacing.sm) {
                if isRecording {
                    // Animated recording indicator
                    Circle()
                        .fill(Color.Wispflow.accent)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                        .opacity(pulseAnimation ? 1.0 : 0.6)
                    
                    Text("Recording...")
                        .font(Font.Wispflow.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Wispflow.accent)
                } else {
                    // Keyboard icon with subtle styling
                    Image(systemName: "command")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isHovering ? Color.Wispflow.accent : Color.Wispflow.textSecondary)
                    
                    Text(hotkeyManager.hotkeyDisplayString)
                        .font(Font.Wispflow.mono)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Wispflow.textPrimary)
                }
            }
            .frame(minWidth: 160)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(
                ZStack {
                    // Base background
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(isRecording ? Color.Wispflow.accentLight : (isHovering ? Color.Wispflow.border.opacity(0.3) : Color.Wispflow.surface))
                    
                    // Subtle inner shadow for depth
                    if !isRecording {
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(Color.Wispflow.border.opacity(0.5), lineWidth: 1)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        isRecording ? Color.Wispflow.accent : (isHovering ? Color.Wispflow.accent.opacity(0.5) : Color.Wispflow.border),
                        lineWidth: isRecording ? 2 : 1
                    )
            )
            .shadow(
                color: isRecording ? Color.Wispflow.accent.opacity(0.4) : (isHovering ? Color.Wispflow.accent.opacity(0.15) : Color.clear),
                radius: isRecording ? 12 : 6,
                x: 0,
                y: 0
            )
            .scaleEffect(isRecording ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onDisappear {
            stopRecording()
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                // Start pulse animation when recording
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            } else {
                // Stop pulse animation
                withAnimation(.easeOut(duration: 0.2)) {
                    pulseAnimation = false
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
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
