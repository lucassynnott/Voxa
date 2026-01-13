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
    @ObservedObject var audioManager: AudioManager
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
                
                // Audio tab (US-406)
                AudioSettingsView(audioManager: audioManager)
                .tabItem {
                    Label("Audio", systemImage: "speaker.wave.2")
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

// MARK: - Transcription Settings (US-407 Polish)

struct TranscriptionSettingsView: View {
    @ObservedObject var whisperManager: WhisperManager
    @Binding var isLoadingModel: Bool
    @Binding var showDeleteConfirmation: Bool
    @Binding var modelToDelete: WhisperManager.ModelSize?
    @State private var showErrorAlert: Bool = false
    @State private var selectedLanguage: TranscriptionLanguage = .automatic
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Hero section with current status
                TranscriptionStatusHero(
                    whisperManager: whisperManager,
                    isLoadingModel: isLoadingModel
                )
                
                // Model Selection card - Card-based picker (US-407)
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "cpu")
                            .foregroundColor(Color.Wispflow.accent)
                            .font(.system(size: 16, weight: .medium))
                        Text("Whisper Model")
                            .font(Font.Wispflow.headline)
                            .foregroundColor(Color.Wispflow.textPrimary)
                    }
                    
                    Text("Select a model size. Larger models are more accurate but slower and use more memory.")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                    
                    // Card-based model picker (US-407)
                    VStack(spacing: Spacing.sm) {
                        ForEach(WhisperManager.ModelSize.allCases) { model in
                            ModelSelectionCard(
                                model: model,
                                isSelected: whisperManager.selectedModel == model,
                                isDownloaded: whisperManager.isModelDownloaded(model),
                                isActive: model == whisperManager.selectedModel && whisperManager.modelStatus == .ready,
                                onSelect: {
                                    Task {
                                        await whisperManager.selectModel(model)
                                    }
                                }
                            )
                        }
                    }
                }
                .wispflowCard()
                
                // Download & Load Actions card
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(Color.Wispflow.accent)
                            .font(.system(size: 16, weight: .medium))
                        Text("Model Actions")
                            .font(Font.Wispflow.headline)
                            .foregroundColor(Color.Wispflow.textPrimary)
                    }
                    
                    // Status message
                    Text(whisperManager.statusMessage)
                        .font(Font.Wispflow.body)
                        .foregroundColor(Color.Wispflow.textSecondary)
                    
                    // Download progress bar with gradient (US-407)
                    if case .downloading(let progress) = whisperManager.modelStatus {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            // Progress percentage header
                            HStack {
                                Text("Downloading \(whisperManager.selectedModel.displayName.components(separatedBy: " ").first ?? "model")...")
                                    .font(Font.Wispflow.body)
                                    .foregroundColor(Color.Wispflow.textPrimary)
                                Spacer()
                                Text("\(Int(progress * 100))%")
                                    .font(Font.Wispflow.mono)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color.Wispflow.accent)
                            }
                            
                            // Gradient progress bar (US-407)
                            GradientProgressBar(progress: progress)
                                .frame(height: 10)
                            
                            // Estimated time/status
                            Text("Please wait, this may take a few minutes...")
                                .font(Font.Wispflow.small)
                                .foregroundColor(Color.Wispflow.textSecondary)
                        }
                        .padding(Spacing.md)
                        .background(Color.Wispflow.accentLight.opacity(0.5))
                        .cornerRadius(CornerRadius.small)
                    }
                    
                    // Action buttons
                    HStack(spacing: Spacing.md) {
                        // Load/Download button
                        Button(action: {
                            Task {
                                isLoadingModel = true
                                await whisperManager.loadModel()
                                isLoadingModel = false
                                if case .error = whisperManager.modelStatus {
                                    showErrorAlert = true
                                }
                            }
                        }) {
                            HStack {
                                if isLoadingModel && whisperManager.modelStatus != .downloading(progress: 0) {
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
                        
                        // Retry button (shown when there's an error)
                        if case .error = whisperManager.modelStatus {
                            Button(action: {
                                Task {
                                    isLoadingModel = true
                                    await whisperManager.retryLoadModel()
                                    isLoadingModel = false
                                    if case .error = whisperManager.modelStatus {
                                        showErrorAlert = true
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry")
                                }
                            }
                            .disabled(isLoadingModel)
                            .buttonStyle(WispflowButtonStyle.secondary)
                            
                            Button(action: {
                                showErrorAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                    Text("Details")
                                }
                            }
                            .buttonStyle(WispflowButtonStyle.ghost)
                        }
                        
                        // Delete button (if model is downloaded)
                        if whisperManager.isModelDownloaded(whisperManager.selectedModel) && whisperManager.modelStatus != .downloading(progress: 0) {
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
                
                // Language Selection card (US-407)
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "globe")
                            .foregroundColor(Color.Wispflow.accent)
                            .font(.system(size: 16, weight: .medium))
                        Text("Transcription Language")
                            .font(Font.Wispflow.headline)
                            .foregroundColor(Color.Wispflow.textPrimary)
                    }
                    
                    Text("Select the language for speech recognition. Auto-detect works best for most cases.")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                    
                    // Language picker with flags (US-407)
                    LanguagePicker(selectedLanguage: $selectedLanguage)
                }
                .wispflowCard()
                
                // About Whisper card
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("About Whisper")
                        .font(Font.Wispflow.headline)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        TranscriptionFeatureRow(icon: "brain", text: "OpenAI's Whisper model for accurate speech recognition")
                        TranscriptionFeatureRow(icon: "lock.shield", text: "All transcription happens locally on your device")
                        TranscriptionFeatureRow(icon: "bolt", text: "Optimized for Apple Silicon with WhisperKit")
                        TranscriptionFeatureRow(icon: "globe", text: "Supports 99+ languages and accents")
                    }
                }
                .wispflowCard()
                
                Spacer()
            }
            .padding(Spacing.xl)
        }
        .background(Color.Wispflow.background)
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

// MARK: - Transcription Status Hero (US-407)

/// Hero section showing current transcription model status at a glance
struct TranscriptionStatusHero: View {
    @ObservedObject var whisperManager: WhisperManager
    let isLoadingModel: Bool
    
    var body: some View {
        HStack(spacing: Spacing.lg) {
            // Status icon with animation
            ZStack {
                Circle()
                    .fill(statusBackgroundColor.opacity(0.15))
                    .frame(width: 64, height: 64)
                
                if isLoadingModel || whisperManager.modelStatus == .loading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: statusIconName)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(statusBackgroundColor)
                }
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(statusTitle)
                    .font(Font.Wispflow.title)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Text(statusSubtitle)
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.textSecondary)
                
                // Model badge
                ModelStatusBadge(status: whisperManager.modelStatus)
                    .padding(.top, Spacing.xs)
            }
            
            Spacer()
        }
        .wispflowCard()
    }
    
    private var statusTitle: String {
        switch whisperManager.modelStatus {
        case .ready:
            return "Ready to Transcribe"
        case .loading:
            return "Loading Model..."
        case .downloading:
            return "Downloading Model..."
        case .downloaded:
            return "Model Downloaded"
        case .notDownloaded:
            return "No Model Loaded"
        case .error:
            return "Model Error"
        }
    }
    
    private var statusSubtitle: String {
        switch whisperManager.modelStatus {
        case .ready:
            return "Using \(whisperManager.selectedModel.displayName.components(separatedBy: " ").first ?? "Whisper") model"
        case .loading:
            return "Please wait..."
        case .downloading(let progress):
            return "\(Int(progress * 100))% complete"
        case .downloaded:
            return "Ready to load"
        case .notDownloaded:
            return "Select and download a model to begin"
        case .error:
            return "Failed to load model"
        }
    }
    
    private var statusIconName: String {
        switch whisperManager.modelStatus {
        case .ready:
            return "checkmark.circle.fill"
        case .loading, .downloading:
            return "arrow.down.circle"
        case .downloaded:
            return "checkmark.circle"
        case .notDownloaded:
            return "arrow.down.circle"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var statusBackgroundColor: Color {
        switch whisperManager.modelStatus {
        case .ready:
            return Color.Wispflow.success
        case .loading, .downloading, .downloaded:
            return Color.Wispflow.accent
        case .notDownloaded:
            return Color.Wispflow.textSecondary
        case .error:
            return Color.Wispflow.error
        }
    }
}

// MARK: - Model Selection Card (US-407)

/// Card-based model picker item with elegant design
struct ModelSelectionCard: View {
    let model: WhisperManager.ModelSize
    let isSelected: Bool
    let isDownloaded: Bool
    let isActive: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    // Model metadata
    private var modelInfo: (size: String, speed: String, accuracy: String, icon: String) {
        switch model {
        case .tiny:
            return ("~75 MB", "Fastest", "Basic", "hare")
        case .base:
            return ("~140 MB", "Fast", "Good", "tortoise")
        case .small:
            return ("~460 MB", "Medium", "Great", "gauge.with.dots.needle.33percent")
        case .medium:
            return ("~1.5 GB", "Slower", "Best", "gauge.with.dots.needle.67percent")
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                // Model icon
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(isSelected ? Color.Wispflow.accentLight : Color.Wispflow.border.opacity(0.3))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: modelInfo.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? Color.Wispflow.accent : Color.Wispflow.textSecondary)
                }
                
                // Model info
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.sm) {
                        Text(model.displayName.components(separatedBy: " (").first ?? model.rawValue.capitalized)
                            .font(Font.Wispflow.body)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Wispflow.textPrimary)
                        
                        // Status badge (US-407)
                        if isActive {
                            ModelCardBadge(text: "Active", color: Color.Wispflow.success)
                        } else if isDownloaded {
                            ModelCardBadge(text: "Downloaded", color: Color.Wispflow.accent)
                        }
                    }
                    
                    // Model specs
                    HStack(spacing: Spacing.md) {
                        ModelSpec(icon: "internaldrive", text: modelInfo.size)
                        ModelSpec(icon: "speedometer", text: modelInfo.speed)
                        ModelSpec(icon: "star", text: modelInfo.accuracy)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.Wispflow.accent : Color.Wispflow.border, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.Wispflow.accent)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(isHovering ? Color.Wispflow.border.opacity(0.2) : Color.Wispflow.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(isSelected ? Color.Wispflow.accent : Color.Wispflow.border.opacity(0.5), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(
                color: isSelected ? Color.Wispflow.accent.opacity(0.15) : Color.clear,
                radius: 8,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Model Card Badge (US-407)

/// Small badge for model card status indicators
struct ModelCardBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(Font.Wispflow.small)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(CornerRadius.small / 2)
    }
}

// MARK: - Model Spec (US-407)

/// Small spec indicator for model cards
struct ModelSpec: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Color.Wispflow.textSecondary)
            Text(text)
                .font(Font.Wispflow.small)
                .foregroundColor(Color.Wispflow.textSecondary)
        }
    }
}

// MARK: - Model Status Badge (US-407)

/// Enhanced status badge for transcription model
struct ModelStatusBadge: View {
    let status: WhisperManager.ModelStatus
    
    var body: some View {
        HStack(spacing: Spacing.xs) {
            // Animated dot for certain states
            if case .downloading = status {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .opacity(0.8)
            } else if status == .loading {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            
            Text(statusText)
                .font(Font.Wispflow.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(statusColor.opacity(0.12))
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

// MARK: - Gradient Progress Bar (US-407)

/// Elegant gradient progress bar for downloads
struct GradientProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.Wispflow.border)
                
                // Gradient fill
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.Wispflow.accent.opacity(0.7),
                                Color.Wispflow.accent,
                                Color.Wispflow.accent.opacity(0.9)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geometry.size.width * CGFloat(progress)))
                    .animation(.easeOut(duration: 0.3), value: progress)
                
                // Shimmer effect overlay (subtle)
                if progress > 0 && progress < 1 {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geometry.size.width * CGFloat(progress)))
                }
            }
        }
    }
}

// MARK: - Transcription Language (US-407)

/// Supported transcription languages with flags
enum TranscriptionLanguage: String, CaseIterable, Identifiable {
    case automatic = "auto"
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case japanese = "ja"
    case chinese = "zh"
    case korean = "ko"
    case russian = "ru"
    case arabic = "ar"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .automatic: return "Auto-Detect"
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .japanese: return "Japanese"
        case .chinese: return "Chinese"
        case .korean: return "Korean"
        case .russian: return "Russian"
        case .arabic: return "Arabic"
        }
    }
    
    var flag: String {
        switch self {
        case .automatic: return "🌐"
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇵🇹"
        case .japanese: return "🇯🇵"
        case .chinese: return "🇨🇳"
        case .korean: return "🇰🇷"
        case .russian: return "🇷🇺"
        case .arabic: return "🇸🇦"
        }
    }
}

// MARK: - Language Picker (US-407)

/// Elegant language picker with flags
struct LanguagePicker: View {
    @Binding var selectedLanguage: TranscriptionLanguage
    @State private var isExpanded = false
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Selected language display / dropdown trigger
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: Spacing.md) {
                    // Flag
                    Text(selectedLanguage.flag)
                        .font(.system(size: 24))
                    
                    // Language name
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedLanguage.displayName)
                            .font(Font.Wispflow.body)
                            .foregroundColor(Color.Wispflow.textPrimary)
                        
                        if selectedLanguage == .automatic {
                            Text("Recommended for mixed-language content")
                                .font(Font.Wispflow.small)
                                .foregroundColor(Color.Wispflow.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Dropdown indicator
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(isHovering ? Color.Wispflow.border.opacity(0.3) : Color.Wispflow.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(isExpanded ? Color.Wispflow.accent : Color.Wispflow.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            
            // Dropdown list
            if isExpanded {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(TranscriptionLanguage.allCases) { language in
                            LanguageRow(
                                language: language,
                                isSelected: language == selectedLanguage,
                                onSelect: {
                                    selectedLanguage = language
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        isExpanded = false
                                    }
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 250)
                .background(Color.Wispflow.surface)
                .cornerRadius(CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.Wispflow.border, lineWidth: 1)
                )
                .wispflowShadow(.card)
                .padding(.top, Spacing.xs)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }
}

// MARK: - Language Row (US-407)

/// Single row in the language picker
struct LanguageRow: View {
    let language: TranscriptionLanguage
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                // Flag
                Text(language.flag)
                    .font(.system(size: 20))
                
                // Language name
                Text(language.displayName)
                    .font(Font.Wispflow.body)
                    .foregroundColor(isSelected ? Color.Wispflow.accent : Color.Wispflow.textPrimary)
                
                if language == .automatic {
                    Text("Recommended")
                        .font(Font.Wispflow.small)
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Color.Wispflow.border.opacity(0.5))
                        .cornerRadius(CornerRadius.small / 2)
                }
                
                Spacer()
                
                // Selected checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Wispflow.accent)
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(isHovering ? Color.Wispflow.accentLight : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Transcription Feature Row (US-407)

/// Feature row for the About Whisper section
struct TranscriptionFeatureRow: View {
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

// MARK: - Audio Settings (US-406)

/// Audio Settings Tab - Device picker with level preview and input configuration
struct AudioSettingsView: View {
    @ObservedObject var audioManager: AudioManager
    @State private var isPreviewingAudio = false
    @State private var previewTimer: Timer?
    @State private var currentLevel: Float = -60.0
    @State private var inputGain: Double = 1.0
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Audio Input Device card
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "mic")
                            .foregroundColor(Color.Wispflow.accent)
                            .font(.system(size: 16, weight: .medium))
                        Text("Audio Input Device")
                            .font(Font.Wispflow.headline)
                            .foregroundColor(Color.Wispflow.textPrimary)
                    }
                    
                    Text("Select the microphone or audio input device to use for voice recording.")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                    
                    // Elegant device picker
                    AudioDevicePicker(
                        devices: audioManager.inputDevices,
                        selectedDevice: audioManager.currentDevice,
                        onDeviceSelected: { device in
                            audioManager.selectDevice(device)
                        }
                    )
                    
                    // Refresh devices button
                    HStack {
                        Spacer()
                        Button(action: {
                            audioManager.refreshAvailableDevices()
                        }) {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh Devices")
                            }
                        }
                        .buttonStyle(WispflowButtonStyle.ghost)
                    }
                }
                .wispflowCard()
                
                // Audio Level Preview card
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "waveform")
                            .foregroundColor(Color.Wispflow.accent)
                            .font(.system(size: 16, weight: .medium))
                        Text("Audio Level Preview")
                            .font(Font.Wispflow.headline)
                            .foregroundColor(Color.Wispflow.textPrimary)
                    }
                    
                    Text("Test your microphone to ensure it's working correctly. Speak into your microphone to see the input level.")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                    
                    // Live audio level meter
                    AudioLevelMeterView(
                        level: isPreviewingAudio ? currentLevel : -60.0,
                        isActive: isPreviewingAudio
                    )
                    .frame(height: 44)
                    .animation(.easeOut(duration: 0.1), value: currentLevel)
                    
                    // Level indicator text
                    HStack {
                        Text("Current Level:")
                            .font(Font.Wispflow.caption)
                            .foregroundColor(Color.Wispflow.textSecondary)
                        
                        Text(isPreviewingAudio ? String(format: "%.1f dB", currentLevel) : "—")
                            .font(Font.Wispflow.mono)
                            .foregroundColor(levelColor(for: currentLevel))
                        
                        Spacer()
                        
                        // Level status indicator
                        if isPreviewingAudio {
                            HStack(spacing: Spacing.xs) {
                                Circle()
                                    .fill(levelColor(for: currentLevel))
                                    .frame(width: 8, height: 8)
                                Text(levelStatus(for: currentLevel))
                                    .font(Font.Wispflow.caption)
                                    .foregroundColor(levelColor(for: currentLevel))
                            }
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(levelColor(for: currentLevel).opacity(0.15))
                            .cornerRadius(CornerRadius.small)
                        }
                    }
                    
                    // Preview toggle button
                    HStack {
                        Button(action: {
                            togglePreview()
                        }) {
                            HStack {
                                Image(systemName: isPreviewingAudio ? "stop.fill" : "mic.fill")
                                Text(isPreviewingAudio ? "Stop Preview" : "Start Preview")
                            }
                        }
                        .buttonStyle(WispflowButtonStyle(variant: isPreviewingAudio ? .secondary : .primary))
                        
                        Spacer()
                    }
                }
                .wispflowCard()
                
                // Input Gain Settings card
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(Color.Wispflow.accent)
                            .font(.system(size: 16, weight: .medium))
                        Text("Input Level Sensitivity")
                            .font(Font.Wispflow.headline)
                            .foregroundColor(Color.Wispflow.textPrimary)
                    }
                    
                    Text("Adjust the sensitivity for audio level detection. This affects the visual meter display only.")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                    
                    // Custom styled slider for gain
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Text("Sensitivity")
                                .font(Font.Wispflow.body)
                                .foregroundColor(Color.Wispflow.textPrimary)
                            Spacer()
                            Text(String(format: "%.0f%%", inputGain * 100))
                                .font(Font.Wispflow.mono)
                                .foregroundColor(Color.Wispflow.accent)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)
                                .background(Color.Wispflow.accentLight)
                                .cornerRadius(CornerRadius.small / 2)
                        }
                        
                        // Custom slider
                        CustomSlider(value: $inputGain, range: 0.5...2.0)
                            .frame(height: 8)
                        
                        HStack {
                            Text("Low")
                                .font(Font.Wispflow.small)
                                .foregroundColor(Color.Wispflow.textSecondary)
                            Spacer()
                            Text("High")
                                .font(Font.Wispflow.small)
                                .foregroundColor(Color.Wispflow.textSecondary)
                        }
                    }
                    
                    // Reset to default
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                inputGain = 1.0
                            }
                        }) {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset to Default")
                            }
                        }
                        .buttonStyle(WispflowButtonStyle.ghost)
                        .disabled(inputGain == 1.0)
                    }
                }
                .wispflowCard()
                
                // Audio Info card
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("About Audio Capture")
                        .font(Font.Wispflow.headline)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        AudioInfoRow(icon: "waveform.path.ecg", text: "Audio is captured at 16kHz for optimal transcription")
                        AudioInfoRow(icon: "lock.shield", text: "All audio is processed locally on your device")
                        AudioInfoRow(icon: "trash", text: "Audio data is discarded after transcription")
                        AudioInfoRow(icon: "hand.raised", text: "No audio is ever sent to external servers")
                    }
                }
                .wispflowCard()
                
                Spacer()
            }
            .padding(Spacing.xl)
        }
        .background(Color.Wispflow.background)
        .onDisappear {
            stopPreview()
        }
    }
    
    // MARK: - Preview Control
    
    private func togglePreview() {
        if isPreviewingAudio {
            stopPreview()
        } else {
            startPreview()
        }
    }
    
    private func startPreview() {
        // Start audio capture for preview
        do {
            try audioManager.startCapturing()
            isPreviewingAudio = true
            
            // Start timer to read audio level
            previewTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                // Apply gain to the visual level display
                let rawLevel = audioManager.currentAudioLevel
                currentLevel = rawLevel + Float(20 * log10(inputGain)) // Convert gain to dB adjustment
            }
        } catch {
            print("Failed to start audio preview: \(error)")
        }
    }
    
    private func stopPreview() {
        previewTimer?.invalidate()
        previewTimer = nil
        audioManager.cancelCapturing()
        isPreviewingAudio = false
        currentLevel = -60.0
    }
    
    // MARK: - Level Helpers
    
    private func levelColor(for level: Float) -> Color {
        if level > -10 {
            return Color.Wispflow.error // Clipping/too loud
        } else if level > -30 {
            return Color.Wispflow.success // Good level
        } else if level > -50 {
            return Color.Wispflow.warning // Quiet
        } else {
            return Color.Wispflow.textSecondary // Very quiet/silent
        }
    }
    
    private func levelStatus(for level: Float) -> String {
        if level > -10 {
            return "Too Loud"
        } else if level > -30 {
            return "Good"
        } else if level > -50 {
            return "Quiet"
        } else {
            return "Silent"
        }
    }
}

// MARK: - Audio Device Picker

/// Elegant dropdown picker for audio input devices with device icons
struct AudioDevicePicker: View {
    let devices: [AudioManager.AudioInputDevice]
    let selectedDevice: AudioManager.AudioInputDevice?
    let onDeviceSelected: (AudioManager.AudioInputDevice) -> Void
    
    @State private var isExpanded = false
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Selected device display / dropdown trigger
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: Spacing.md) {
                    // Device icon
                    Image(systemName: deviceIcon(for: selectedDevice))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.Wispflow.accent)
                        .frame(width: 24)
                    
                    // Device name
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedDevice?.name ?? "No device selected")
                            .font(Font.Wispflow.body)
                            .foregroundColor(Color.Wispflow.textPrimary)
                        
                        if let device = selectedDevice, device.isDefault {
                            Text("System Default")
                                .font(Font.Wispflow.small)
                                .foregroundColor(Color.Wispflow.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Dropdown indicator
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(isHovering ? Color.Wispflow.border.opacity(0.3) : Color.Wispflow.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(isExpanded ? Color.Wispflow.accent : Color.Wispflow.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            
            // Dropdown list
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(devices) { device in
                        AudioDeviceRow(
                            device: device,
                            isSelected: device.uid == selectedDevice?.uid,
                            onSelect: {
                                onDeviceSelected(device)
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    isExpanded = false
                                }
                            }
                        )
                    }
                }
                .background(Color.Wispflow.surface)
                .cornerRadius(CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.Wispflow.border, lineWidth: 1)
                )
                .wispflowShadow(.card)
                .padding(.top, Spacing.xs)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }
    
    private func deviceIcon(for device: AudioManager.AudioInputDevice?) -> String {
        guard let device = device else { return "mic.slash" }
        let name = device.name.lowercased()
        
        if name.contains("airpod") {
            return "airpodspro"
        } else if name.contains("bluetooth") || name.contains("wireless") {
            return "wave.3.right"
        } else if name.contains("usb") {
            return "cable.connector"
        } else if name.contains("built-in") || name.contains("macbook") || name.contains("internal") {
            return "laptopcomputer"
        } else if name.contains("headphone") || name.contains("headset") {
            return "headphones"
        } else {
            return "mic"
        }
    }
}

/// Single row in the audio device picker dropdown
struct AudioDeviceRow: View {
    let device: AudioManager.AudioInputDevice
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                // Device icon
                Image(systemName: deviceIcon(for: device))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? Color.Wispflow.accent : Color.Wispflow.textSecondary)
                    .frame(width: 20)
                
                // Device name
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(Font.Wispflow.body)
                        .foregroundColor(isSelected ? Color.Wispflow.accent : Color.Wispflow.textPrimary)
                    
                    if device.isDefault {
                        Text("System Default")
                            .font(Font.Wispflow.small)
                            .foregroundColor(Color.Wispflow.textSecondary)
                    }
                }
                
                Spacer()
                
                // Selected checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Wispflow.accent)
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(isHovering ? Color.Wispflow.accentLight : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
    
    private func deviceIcon(for device: AudioManager.AudioInputDevice) -> String {
        let name = device.name.lowercased()
        
        if name.contains("airpod") {
            return "airpodspro"
        } else if name.contains("bluetooth") || name.contains("wireless") {
            return "wave.3.right"
        } else if name.contains("usb") {
            return "cable.connector"
        } else if name.contains("built-in") || name.contains("macbook") || name.contains("internal") {
            return "laptopcomputer"
        } else if name.contains("headphone") || name.contains("headset") {
            return "headphones"
        } else {
            return "mic"
        }
    }
}

// MARK: - Audio Level Meter View

/// Visual audio level meter with smooth animation
struct AudioLevelMeterView: View {
    let level: Float
    let isActive: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color.Wispflow.border)
                
                // Segmented level indicator
                HStack(spacing: 2) {
                    ForEach(0..<30, id: \.self) { index in
                        let segmentLevel = -60.0 + (Double(index) * 2.0) // Each segment = 2dB
                        let isLit = isActive && Double(level) >= segmentLevel
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(segmentColor(for: Float(segmentLevel), isLit: isLit))
                            .opacity(isLit ? 1.0 : 0.15)
                    }
                }
                .padding(Spacing.xs)
            }
        }
    }
    
    private func segmentColor(for segmentLevel: Float, isLit: Bool) -> Color {
        if segmentLevel > -10 {
            return Color.Wispflow.error
        } else if segmentLevel > -30 {
            return Color.Wispflow.success
        } else {
            return Color.Wispflow.accent
        }
    }
}

// MARK: - Custom Slider

/// Custom styled slider with coral accent
struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let thumbPosition = width * CGFloat(normalizedValue)
            
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.Wispflow.border)
                    .frame(height: 8)
                
                // Filled track
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [Color.Wispflow.accent.opacity(0.7), Color.Wispflow.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, thumbPosition), height: 8)
                
                // Thumb
                Circle()
                    .fill(Color.Wispflow.surface)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.Wispflow.accent, lineWidth: 2)
                    )
                    .shadow(color: Color.Wispflow.accent.opacity(isDragging ? 0.4 : 0.2), radius: isDragging ? 8 : 4)
                    .scaleEffect(isDragging ? 1.1 : 1.0)
                    .offset(x: thumbPosition - 10)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * Double(gesture.location.x / width)
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDragging)
        }
    }
}

// MARK: - Audio Info Row

/// Info row for the Audio settings info section
struct AudioInfoRow: View {
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

// MARK: - Settings Window Controller

final class SettingsWindowController: NSObject {
    private var settingsWindow: NSWindow?
    private let whisperManager: WhisperManager
    private let textCleanupManager: TextCleanupManager
    private let llmManager: LLMManager
    private let textInserter: TextInserter
    private let hotkeyManager: HotkeyManager
    private let debugManager: DebugManager
    private let audioManager: AudioManager
    private var debugLogWindowController: DebugLogWindowController?
    
    init(whisperManager: WhisperManager, textCleanupManager: TextCleanupManager, llmManager: LLMManager, textInserter: TextInserter, hotkeyManager: HotkeyManager, debugManager: DebugManager, audioManager: AudioManager) {
        self.whisperManager = whisperManager
        self.textCleanupManager = textCleanupManager
        self.llmManager = llmManager
        self.textInserter = textInserter
        self.hotkeyManager = hotkeyManager
        self.debugManager = debugManager
        self.audioManager = audioManager
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
            audioManager: audioManager,
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
