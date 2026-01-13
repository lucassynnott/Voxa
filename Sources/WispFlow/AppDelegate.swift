import AppKit

/// Main application delegate that manages the menu bar app lifecycle
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var hotkeyManager: HotkeyManager?
    private var recordingIndicator: RecordingIndicatorWindow?
    private var audioManager: AudioManager?
    private var whisperManager: WhisperManager?
    private var textCleanupManager: TextCleanupManager?
    private var textInserter: TextInserter?
    private var settingsWindowController: SettingsWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize audio manager
        setupAudioManager()
        
        // Initialize the status bar controller
        statusBarController = StatusBarController()
        
        // Provide audio manager to status bar controller
        statusBarController?.audioManager = audioManager
        
        // Set up callbacks
        statusBarController?.onRecordingStateChanged = { [weak self] state in
            self?.handleRecordingStateChange(state)
        }
        
        statusBarController?.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        
        // Initialize and start the hotkey manager
        setupHotkeyManager()
        
        // Initialize the recording indicator (but don't show it yet)
        setupRecordingIndicator()
        
        print("WispFlow started successfully")
        print("Global hotkey: \(hotkeyManager?.hotkeyDisplayString ?? "unknown")")
        
        // Request microphone permission on first launch
        audioManager?.requestMicrophonePermission { granted in
            if granted {
                print("Microphone permission granted")
            } else {
                print("Microphone permission denied - recording will not work")
            }
        }
        
        // Initialize Whisper manager, text cleanup manager, text inserter, and auto-load models on main actor
        Task { @MainActor in
            setupWhisperManager()
            setupTextCleanupManager()
            setupTextInserter()
            
            // Provide whisper manager to status bar controller
            statusBarController?.whisperManager = whisperManager
            
            // Set up settings window controller with all managers
            if let whisper = whisperManager, let cleanup = textCleanupManager, let inserter = textInserter {
                settingsWindowController = SettingsWindowController(
                    whisperManager: whisper,
                    textCleanupManager: cleanup,
                    textInserter: inserter
                )
            }
            
            // Auto-load the selected Whisper model in background
            print("Auto-loading Whisper model...")
            await whisperManager?.loadModel()
            
            // Text cleanup is ready immediately (rule-based, no model download needed)
            print("Text cleanup ready with mode: \(textCleanupManager?.selectedMode.rawValue ?? "unknown")")
            
            // Check accessibility permission on launch (without prompt)
            if let inserter = textInserter {
                if inserter.hasAccessibilityPermission {
                    print("Accessibility permission already granted")
                } else {
                    print("Accessibility permission not granted - will prompt on first text insertion")
                }
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Stop any active recording
        audioManager?.cancelCapturing()
        
        // Stop the hotkey manager
        hotkeyManager?.stop()
        
        // Hide the recording indicator if visible
        recordingIndicator?.orderOut(nil)
        
        print("WispFlow shutting down")
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Setup
    
    private func setupAudioManager() {
        audioManager = AudioManager()
        
        // Set up error handling
        audioManager?.onCaptureError = { error in
            print("Audio capture error: \(error.localizedDescription)")
        }
        
        // Log when devices change
        audioManager?.onDevicesChanged = { devices in
            print("Audio devices updated: \(devices.map { $0.name })")
        }
    }
    
    @MainActor
    private func setupWhisperManager() {
        whisperManager = WhisperManager()
        
        // Set up callbacks
        whisperManager?.onTranscriptionComplete = { text in
            print("Transcription complete: \(text)")
        }
        
        whisperManager?.onError = { error in
            print("Whisper error: \(error)")
        }
    }
    
    @MainActor
    private func setupTextCleanupManager() {
        textCleanupManager = TextCleanupManager()
        
        // Set up callbacks
        textCleanupManager?.onCleanupComplete = { text in
            print("Text cleanup complete: \(text)")
        }
        
        textCleanupManager?.onError = { error in
            print("Text cleanup error: \(error)")
        }
    }
    
    @MainActor
    private func setupTextInserter() {
        textInserter = TextInserter()
        
        // Set up callbacks
        textInserter?.onInsertionComplete = {
            print("Text insertion complete")
        }
        
        textInserter?.onError = { error in
            print("Text insertion error: \(error)")
        }
    }
    
    private func openSettings() {
        settingsWindowController?.showSettings()
    }
    
    private func setupHotkeyManager() {
        hotkeyManager = HotkeyManager()
        
        hotkeyManager?.onHotkeyPressed = { [weak self] in
            self?.toggleRecordingFromHotkey()
        }
        
        hotkeyManager?.start()
    }
    
    private func setupRecordingIndicator() {
        recordingIndicator = RecordingIndicatorWindow()
        
        recordingIndicator?.onCancel = { [weak self] in
            self?.cancelRecording()
        }
    }
    
    // MARK: - Recording Control
    
    private func toggleRecordingFromHotkey() {
        print("Hotkey triggered - toggling recording")
        statusBarController?.toggle()
    }
    
    private func cancelRecording() {
        print("Recording cancelled by user")
        // Cancel audio capture (discards recorded audio)
        audioManager?.cancelCapturing()
        // Force state to idle (even if already idle, this is safe)
        statusBarController?.setRecordingState(.idle)
    }
    
    // MARK: - Recording State Handling
    
    private func handleRecordingStateChange(_ state: RecordingState) {
        switch state {
        case .idle:
            // Hide the recording indicator
            recordingIndicator?.hideWithAnimation()
            
            // Stop audio capture and get result
            if let result = audioManager?.stopCapturing() {
                print("Stopped recording - Duration: \(String(format: "%.2f", result.duration))s, Data: \(result.audioData.count) bytes")
                
                // Process transcription with Whisper on MainActor
                let audioData = result.audioData
                let sampleRate = result.sampleRate
                Task { @MainActor in
                    processTranscription(audioData: audioData, sampleRate: sampleRate)
                }
            } else {
                print("Stopped recording (no audio captured)")
            }
            
        case .recording:
            // Show the recording indicator
            recordingIndicator?.showWithAnimation()
            
            // Start audio capture
            do {
                try audioManager?.startCapturing()
                print("Started recording")
            } catch {
                print("Failed to start audio capture: \(error.localizedDescription)")
                // Revert state if audio capture failed
                statusBarController?.setRecordingState(.idle)
            }
        }
    }
    
    @MainActor
    private func processTranscription(audioData: Data, sampleRate: Double) {
        guard let whisper = whisperManager else {
            print("WhisperManager not available")
            return
        }
        
        // Check if model is ready
        guard whisper.isReady else {
            print("Whisper model not loaded. Please load a model in Settings.")
            showTranscriptionError("Model not loaded. Please open Settings and load a Whisper model.")
            return
        }
        
        // Update recording indicator to show transcribing status
        recordingIndicator?.updateStatus("Transcribing...")
        recordingIndicator?.showWithAnimation()
        
        // Process transcription in background
        Task { @MainActor in
            if let transcribedText = await whisper.transcribe(audioData: audioData, sampleRate: sampleRate) {
                print("Transcription result: \(transcribedText)")
                
                if !transcribedText.isEmpty {
                    // Pass to text cleanup (US-005)
                    await processTextCleanup(transcribedText)
                } else {
                    recordingIndicator?.hideWithAnimation()
                }
            } else {
                recordingIndicator?.hideWithAnimation()
                print("Transcription failed or returned empty")
            }
            
            // Reset whisper status
            whisper.resetStatus()
        }
    }
    
    @MainActor
    private func processTextCleanup(_ transcribedText: String) async {
        guard let cleanup = textCleanupManager else {
            print("TextCleanupManager not available, using raw text")
            recordingIndicator?.hideWithAnimation()
            // Insert raw text directly
            await performTextInsertion(transcribedText)
            return
        }
        
        // Update indicator to show cleanup status
        if cleanup.isCleanupEnabled {
            recordingIndicator?.updateStatus("Cleaning up...")
        }
        
        // Perform text cleanup
        let cleanedText = await cleanup.cleanupText(transcribedText)
        
        print("Final text (after cleanup): \(cleanedText)")
        
        // Hide the indicator and perform text insertion
        recordingIndicator?.updateStatus("Inserting...")
        
        // Insert cleaned text into active application
        await performTextInsertion(cleanedText)
        
        // Hide the indicator after insertion
        recordingIndicator?.hideWithAnimation()
        
        // Reset cleanup status
        cleanup.resetStatus()
    }
    
    @MainActor
    private func performTextInsertion(_ text: String) async {
        guard let inserter = textInserter else {
            print("TextInserter not available")
            showTextInsertionError("Text insertion not available")
            return
        }
        
        // Skip empty text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("Skipping insertion of empty text")
            return
        }
        
        let result = await inserter.insertText(text)
        
        switch result {
        case .success:
            print("Text inserted successfully")
            
        case .noAccessibilityPermission:
            // Alert is already shown by TextInserter
            print("Text insertion failed: No accessibility permission")
            
        case .insertionFailed(let message):
            print("Text insertion failed: \(message)")
            showTextInsertionError(message)
        }
        
        // Reset inserter status
        inserter.resetStatus()
    }
    
    private func showTextInsertionError(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Text Insertion Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    private func showTranscriptionError(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Transcription Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "OK")
            
            if alert.runModal() == .alertFirstButtonReturn {
                self.openSettings()
            }
        }
    }
    
    // MARK: - Public API
    
    /// Access to the status bar controller for external control
    var statusBar: StatusBarController? {
        return statusBarController
    }
    
    /// Access to the hotkey manager for configuration
    var hotkey: HotkeyManager? {
        return hotkeyManager
    }
    
    /// Access to the audio manager for device selection
    var audio: AudioManager? {
        return audioManager
    }
}
