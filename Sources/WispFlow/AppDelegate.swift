import AppKit

/// Main application delegate that manages the menu bar app lifecycle
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var hotkeyManager: HotkeyManager?
    private var recordingIndicator: RecordingIndicatorWindow?
    private var audioManager: AudioManager?
    private var whisperManager: WhisperManager?
    private var textCleanupManager: TextCleanupManager?
    private var llmManager: LLMManager?
    private var textInserter: TextInserter?
    private var settingsWindowController: SettingsWindowController?
    private var debugManager: DebugManager?
    private var toastWindowController: ToastWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    
    // Store last audio data for retry functionality
    private var lastAudioData: Data?
    private var lastAudioSampleRate: Double = 16000.0
    
    // US-608: Timer to clear audio buffer after timeout (30 seconds)
    private var audioBufferClearTimer: Timer?
    private static let audioBufferTimeoutSeconds: TimeInterval = 30.0
    
    // Track transcription timing for debug
    private var transcriptionStartTime: Date?
    
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
        
        // Initialize the toast notification system (US-409)
        setupToastSystem()
        
        print("WispFlow started successfully")
        print("Global hotkey: \(hotkeyManager?.hotkeyDisplayString ?? "unknown")")
        
        // NOTE: Don't request microphone permission here - let onboarding handle it
        // Permission will be requested during the onboarding microphone step (US-518)
        // or when the user first tries to record
        
        // Initialize Whisper manager, text cleanup manager, LLM manager, text inserter, and auto-load models on main actor
        Task { @MainActor in
            setupWhisperManager()
            setupTextCleanupManager()
            setupLLMManager()
            setupTextInserter()
            setupDebugManager()
            
            // Provide whisper manager to status bar controller
            statusBarController?.whisperManager = whisperManager
            
            // Connect LLM manager to text cleanup manager
            textCleanupManager?.llmManager = llmManager
            
            // Set up settings window controller with all managers
            if let whisper = whisperManager, let cleanup = textCleanupManager, let inserter = textInserter, let hotkey = hotkeyManager, let debug = debugManager, let llm = llmManager, let audio = audioManager {
                settingsWindowController = SettingsWindowController(
                    whisperManager: whisper,
                    textCleanupManager: cleanup,
                    llmManager: llm,
                    textInserter: inserter,
                    hotkeyManager: hotkey,
                    debugManager: debug,
                    audioManager: audio
                )
            }
            
            // Auto-load the selected Whisper model in background
            print("Auto-loading Whisper model...")
            await whisperManager?.loadModel()
            
            // Text cleanup is ready immediately (rule-based, no model download needed)
            print("Text cleanup ready with mode: \(textCleanupManager?.selectedMode.rawValue ?? "unknown")")
            
            // If AI-powered cleanup is selected and LLM model is downloaded, load it
            if textCleanupManager?.selectedMode == .aiPowered {
                if llmManager?.isModelDownloaded(llmManager?.selectedModel ?? .qwen1_5b) == true {
                    print("Auto-loading LLM model for AI-powered cleanup...")
                    await llmManager?.loadModel()
                }
            }
            
            // Check accessibility permission on launch (without prompt)
            if let inserter = textInserter {
                if inserter.hasAccessibilityPermission {
                    print("Accessibility permission already granted")
                } else {
                    print("Accessibility permission not granted - will prompt on first text insertion")
                }
            }
            
            // US-517: Show onboarding wizard on first launch
            setupOnboarding()
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
            ErrorLogger.shared.logAudioError(error, deviceInfo: nil)
        }
        
        // Log when devices change
        audioManager?.onDevicesChanged = { devices in
            print("Audio devices updated: \(devices.map { $0.name })")
        }
        
        // Handle silence detection warning
        audioManager?.onSilenceDetected = { [weak self] measuredDbLevel in
            // Access MainActor properties on main thread
            DispatchQueue.main.async {
                // Check if silence detection is bypassed in debug mode
                let bypassSilenceCheck = DebugManager.shared.isDebugModeEnabled && DebugManager.shared.isSilenceDetectionDisabled
                
                ErrorLogger.shared.log(
                    bypassSilenceCheck ? "Silent audio detected (bypassed in debug mode)" : "Silent audio detected - recording appears to have no audio input",
                    category: .audio,
                    severity: bypassSilenceCheck ? .info : .warning,
                    context: [
                        "threshold": "\(Int(AudioManager.silenceThreshold))dB",
                        "measuredLevel": "\(String(format: "%.1f", measuredDbLevel))dB",
                        "silenceDetectionBypassed": "\(bypassSilenceCheck)"
                    ]
                )
                
                // Only show warning if silence detection is not bypassed
                if !bypassSilenceCheck {
                    self?.showSilenceWarning(measuredDbLevel: measuredDbLevel)
                }
            }
        }
        
        // Handle recording too short
        audioManager?.onRecordingTooShort = { [weak self] in
            ErrorLogger.shared.log(
                "Recording too short - below minimum duration",
                category: .audio,
                severity: .info,
                context: ["minimumDuration": "\(AudioManager.minimumDuration)s"]
            )
            self?.showRecordingTooShortError()
        }
        
        // US-501: Handle low-quality device warning
        audioManager?.onLowQualityDeviceSelected = { device in
            print("AudioManager: [US-501] Only low-quality device available: \(device.name)")
            ErrorLogger.shared.log(
                "Low-quality audio device selected (only option available)",
                category: .audio,
                severity: .warning,
                context: [
                    "deviceName": device.name,
                    "deviceUID": device.uid,
                    "sampleRate": "\(device.sampleRate)Hz"
                ]
            )
            DispatchQueue.main.async {
                ToastManager.shared.showLowQualityDeviceWarning(deviceName: device.name)
            }
        }
        
        // US-601: Handle audio device disconnected during recording
        audioManager?.onDeviceDisconnectedDuringRecording = { disconnectedName, fallbackName in
            print("AppDelegate: [US-601] Device disconnected during recording: \(disconnectedName) → \(fallbackName)")
            ErrorLogger.shared.log(
                "Audio device disconnected during recording",
                category: .audio,
                severity: .warning,
                context: [
                    "disconnectedDevice": disconnectedName,
                    "fallbackDevice": fallbackName
                ]
            )
            DispatchQueue.main.async {
                ToastManager.shared.showDeviceDisconnectedDuringRecording(
                    disconnectedName: disconnectedName,
                    fallbackName: fallbackName
                )
            }
        }
        
        // US-601: Handle audio device change notification
        audioManager?.onDeviceChanged = { oldDevice, newDevice, reason in
            print("AppDelegate: [US-601] Audio device changed: \(oldDevice ?? "none") → \(newDevice) (\(reason))")
            ErrorLogger.shared.log(
                "Audio device changed",
                category: .audio,
                severity: .info,
                context: [
                    "previousDevice": oldDevice ?? "none",
                    "newDevice": newDevice,
                    "reason": reason
                ]
            )
            DispatchQueue.main.async {
                ToastManager.shared.showDeviceChanged(from: oldDevice, to: newDevice, reason: reason)
            }
        }
        
        // US-601: Handle preferred device reconnection
        audioManager?.onPreferredDeviceReconnected = { deviceName in
            print("AppDelegate: [US-601] Preferred device reconnected: \(deviceName)")
            ErrorLogger.shared.log(
                "Preferred audio device reconnected",
                category: .audio,
                severity: .info,
                context: ["deviceName": deviceName]
            )
            DispatchQueue.main.async {
                ToastManager.shared.showPreferredDeviceReconnected(deviceName: deviceName)
            }
        }
        
        // US-603: Handle recording timeout warning (shown at 4 minutes by default)
        audioManager?.onRecordingTimeoutWarning = { remainingSeconds in
            print("AppDelegate: [US-603] Recording timeout warning - \(remainingSeconds) seconds remaining")
            ErrorLogger.shared.log(
                "Recording timeout warning",
                category: .audio,
                severity: .warning,
                context: ["remainingSeconds": "\(remainingSeconds)"]
            )
            DispatchQueue.main.async {
                ToastManager.shared.showRecordingTimeoutWarning(remainingSeconds: remainingSeconds)
            }
        }
        
        // US-603: Handle recording timeout reached (auto-stop at 5 minutes by default)
        audioManager?.onRecordingTimeoutReached = { [weak self] in
            print("AppDelegate: [US-603] Recording timeout reached - auto-stopping and transcribing")
            ErrorLogger.shared.log(
                "Recording timeout reached - auto-stopping",
                category: .audio,
                severity: .warning,
                context: ["maxDuration": "\(AudioManager.maxRecordingDuration)"]
            )
            DispatchQueue.main.async {
                ToastManager.shared.showRecordingAutoStopped()
                // Trigger the same flow as pressing the hotkey to stop recording
                // This will stop capture, transcribe, and process the audio
                self?.statusBarController?.setRecordingState(.idle)
            }
        }
    }
    
    private func showSilenceWarning(measuredDbLevel: Float) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "No Audio Detected"
            // Use actual threshold from AudioManager and show measured level
            let threshold = AudioManager.silenceThreshold
            alert.informativeText = "The recording appears to be silent.\n\n• Measured level: \(String(format: "%.1f", measuredDbLevel))dB\n• Threshold: \(Int(threshold))dB\n\nPlease check that:\n• Your microphone is connected\n• The correct input device is selected in Settings\n• You're speaking into the microphone"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "OK")
            
            if alert.runModal() == .alertFirstButtonReturn {
                self.openSettings()
            }
        }
    }
    
    private func showRecordingTooShortError() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Recording Too Short"
            alert.informativeText = "The recording was shorter than the minimum required duration of \(AudioManager.minimumDuration) seconds. Please hold the recording key longer."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
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
        
        // Set up detailed transcription error callback with retry support
        whisperManager?.onTranscriptionError = { [weak self] error, audioData, sampleRate in
            DispatchQueue.main.async {
                self?.handleTranscriptionError(error, audioData: audioData, sampleRate: sampleRate)
            }
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
    private func setupLLMManager() {
        llmManager = LLMManager()
        
        // Set up callbacks
        llmManager?.onCleanupComplete = { text in
            print("LLM cleanup complete: \(text)")
        }
        
        llmManager?.onError = { error in
            print("LLM error: \(error)")
            ErrorLogger.shared.log(
                "LLM error: \(error)",
                category: .model,
                severity: .error,
                context: ["component": "LLMManager"]
            )
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
        
        // NOTE: Don't prompt for accessibility permission here - let onboarding handle it
        // Permission will be requested during the onboarding accessibility step (US-519)
        // or when the user first tries to insert text
    }
    
    @MainActor
    private func setupDebugManager() {
        debugManager = DebugManager.shared
        
        // Log initialization
        debugManager?.addLogEntry(
            category: .system,
            message: "WispFlow initialized",
            details: "Audio: \(audioManager != nil ? "OK" : "Missing"), Whisper: \(whisperManager != nil ? "OK" : "Missing")"
        )
    }
    
    private func openSettings() {
        settingsWindowController?.showSettings()
    }
    
    private func setupHotkeyManager() {
        hotkeyManager = HotkeyManager()
        
        hotkeyManager?.onHotkeyPressed = { [weak self] in
            self?.toggleRecordingFromHotkey()
        }
        
        // US-510: Handle accessibility permission prompt when hotkey pressed without permission
        hotkeyManager?.onAccessibilityPermissionNeeded = { [weak self] in
            print("AppDelegate: [US-510] Accessibility permission needed for global hotkeys")
            DispatchQueue.main.async {
                self?.showAccessibilityPermissionPrompt()
            }
        }
        
        // Only start hotkey manager immediately if onboarding has been completed
        // Otherwise, it will be started after onboarding completes (in setupOnboarding completion callback)
        // This prevents permission prompts from appearing before the user reaches the accessibility step
        // Note: Checking UserDefaults directly to avoid MainActor isolation issues
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if hasCompletedOnboarding {
            hotkeyManager?.start()
        } else {
            print("AppDelegate: Deferring hotkey manager start until after onboarding")
        }
    }
    
    /// US-510: Show accessibility permission prompt when hotkey is pressed without permission
    @MainActor
    private func showAccessibilityPermissionPrompt() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "WispFlow needs accessibility permission to detect global hotkeys and insert text.\n\nPlease grant permission in System Settings > Privacy & Security > Accessibility, then restart WispFlow."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // Open accessibility settings
            PermissionManager.shared.openAccessibilitySettings()
        }
    }
    
    private func setupRecordingIndicator() {
        recordingIndicator = RecordingIndicatorWindow()
        
        recordingIndicator?.onCancel = { [weak self] in
            self?.cancelRecording()
        }
    }
    
    /// Set up the toast notification system (US-409)
    private func setupToastSystem() {
        // Initialize the toast window controller for displaying toasts
        toastWindowController = ToastWindowController.shared
        
        // Observe openSettings notification from toast actions
        NotificationCenter.default.addObserver(
            forName: .openSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.openSettings()
        }
    }
    
    /// US-517: Set up and show onboarding wizard on first launch
    @MainActor
    private func setupOnboarding() {
        // US-520: Pass audioManager to onboarding for audio test step
        guard let audioMgr = audioManager else {
            print("AppDelegate: [US-517] Warning - audioManager not available for onboarding")
            return
        }
        
        // US-521: Pass hotkeyManager to onboarding for hotkey introduction step
        guard let hotkeyMgr = hotkeyManager else {
            print("AppDelegate: [US-521] Warning - hotkeyManager not available for onboarding")
            return
        }
        
        onboardingWindowController = OnboardingWindowController(audioManager: audioMgr, hotkeyManager: hotkeyMgr)
        
        // Set up completion callback
        onboardingWindowController?.onComplete = { [weak self] in
            print("AppDelegate: [US-517] Onboarding completed")
            // Onboarding is done, app is ready for use
            // The menu bar icon is already visible
            
            // Now that onboarding is complete and user has had a chance to grant permissions,
            // try to start the hotkey manager (if accessibility was granted)
            self?.hotkeyManager?.start()
        }
        
        // Show onboarding if this is first launch
        onboardingWindowController?.showOnboardingIfNeeded()
    }
    
    // MARK: - Recording Control
    
    private func toggleRecordingFromHotkey() {
        print("Hotkey triggered - toggling recording")
        
        // Block recording if trying to START and model is not ready
        // Use Task to access MainActor-isolated whisperManager
        Task { @MainActor in
            if statusBarController?.currentState == .idle {
                // About to start recording, check if model is ready
                guard let whisper = whisperManager, whisper.isReady else {
                    print("Cannot start recording - model not ready")
                    showModelNotReadyAlert()
                    return
                }
                
                // US-507: Check microphone permission before starting recording
                // If .notDetermined → show system dialog
                // If .denied → open System Settings directly
                let permissionManager = PermissionManager.shared
                let micStatus = permissionManager.microphoneStatus
                
                if !micStatus.isGranted {
                    print("AppDelegate: [US-507] Microphone permission not granted, requesting...")
                    
                    // Request permission (async - shows system dialog or opens Settings)
                    let granted = await permissionManager.requestMicrophonePermission()
                    
                    if !granted {
                        print("AppDelegate: [US-507] Microphone permission not granted, cannot start recording")
                        return
                    }
                    
                    print("AppDelegate: [US-507] Microphone permission granted, proceeding with recording")
                }
            }
            
            statusBarController?.toggle()
        }
    }
    
    @MainActor
    private func showModelNotReadyAlert() {
        let alert = NSAlert()
        
        // Determine message based on model status
        var detailMessage = "Please wait for the Whisper model to finish loading."
        if let whisper = whisperManager {
            switch whisper.modelStatus {
            case .notDownloaded:
                detailMessage = "No Whisper model is downloaded. Please open Settings and download a model."
            case .downloading(let progress):
                detailMessage = "Model is downloading (\(Int(progress * 100))%). Please wait for the download to complete."
            case .downloaded:
                detailMessage = "Model is downloaded but not loaded. Please open Settings and load the model."
            case .loading:
                detailMessage = "Model is currently loading. Please wait a moment."
            case .error(let message):
                detailMessage = "Model failed to load: \(message)\n\nPlease open Settings to retry."
            case .ready:
                detailMessage = "Model is ready." // Should not happen
            }
        }
        
        alert.messageText = "Model Not Ready"
        alert.informativeText = detailMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "OK")
        
        if alert.runModal() == .alertFirstButtonReturn {
            openSettings()
        }
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
            // Disconnect audio level meter
            recordingIndicator?.disconnectAudioManager()
            
            // Hide the recording indicator
            recordingIndicator?.hideWithAnimation()
            
            // Stop audio capture and get result
            if let result = audioManager?.stopCapturing() {
                // Show recording duration info
                print("Stopped recording - Duration: \(String(format: "%.2f", result.duration))s, Data: \(result.audioData.count) bytes, Peak: \(String(format: "%.1f", result.peakLevel))dB, Samples: \(result.sampleCount)")
                
                // Store audio data in debug manager for visualization
                Task { @MainActor in
                    debugManager?.storeAudioData(result.audioData, sampleRate: result.sampleRate)
                    
                    // US-306: Auto-save recording if enabled in debug mode
                    if DebugManager.shared.isDebugModeEnabled && DebugManager.shared.isAutoSaveEnabled {
                        let exportResult = AudioExporter.shared.exportToDocuments(
                            audioData: result.audioData,
                            sampleRate: result.sampleRate
                        )
                        switch exportResult {
                        case .success(let url):
                            DebugManager.shared.addLogEntry(
                                category: .audio,
                                message: "Auto-saved recording",
                                details: "Path: \(url.path)"
                            )
                        case .noAudioData:
                            DebugManager.shared.addLogEntry(
                                category: .audio,
                                message: "Auto-save failed: No audio data"
                            )
                        case .exportFailed(let error):
                            DebugManager.shared.addLogEntry(
                                category: .audio,
                                message: "Auto-save failed",
                                details: error
                            )
                        }
                    }
                }
                
                // Update indicator to show duration briefly
                recordingIndicator?.updateStatus(String(format: "%.1fs", result.duration))
                recordingIndicator?.showWithAnimation()
                
                // Process transcription on MainActor where we can check DebugManager
                let audioData = result.audioData
                let sampleRate = result.sampleRate
                let wasSilent = result.wasSilent
                
                Task { @MainActor [weak self] in
                    // Check if silence detection is disabled in debug mode
                    let bypassSilenceCheck = DebugManager.shared.isDebugModeEnabled && DebugManager.shared.isSilenceDetectionDisabled
                    
                    // If audio was silent (and silence detection is not bypassed), the callback already shows a warning
                    // Only proceed with transcription if we have valid audio OR silence detection is bypassed
                    if !wasSilent || bypassSilenceCheck {
                        if wasSilent && bypassSilenceCheck {
                            print("Audio is silent but silence detection is disabled in debug mode - proceeding with transcription")
                        }
                        // Process transcription with Whisper
                        self?.processTranscription(audioData: audioData, sampleRate: sampleRate)
                    } else {
                        // Hide indicator after showing duration for silent audio
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                            self?.recordingIndicator?.hideWithAnimation()
                        }
                    }
                }
            } else {
                print("Stopped recording (no audio captured or recording too short)")
            }
            
        case .recording:
            // Connect audio level meter to audio manager for real-time updates
            if let audio = audioManager {
                recordingIndicator?.connectAudioManager(audio)
            }
            
            // Show the recording indicator
            recordingIndicator?.showWithAnimation()
            
            // Start audio capture
            do {
                try audioManager?.startCapturing()
                print("Started recording")
                
                // US-505: Show warning toast if recording with low-quality device
                if let audio = audioManager, let device = audio.currentDevice, audio.isLowQualityDevice(device) {
                    print("AppDelegate: [US-505] Recording started with low-quality device: \(device.name)")
                    DispatchQueue.main.async {
                        ToastManager.shared.showLowQualityDeviceWarning(deviceName: device.name)
                    }
                }
            } catch {
                print("Failed to start audio capture: \(error.localizedDescription)")
                // Disconnect on failure
                recordingIndicator?.disconnectAudioManager()
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
        
        // Store audio data for potential retry
        lastAudioData = audioData
        lastAudioSampleRate = sampleRate
        
        // Track transcription start time for debug
        transcriptionStartTime = Date()
        
        // Update recording indicator to show transcribing status
        recordingIndicator?.updateStatus("Transcribing...")
        recordingIndicator?.showWithAnimation()
        
        // Process transcription in background
        Task { @MainActor in
            if let transcribedText = await whisper.transcribe(audioData: audioData, sampleRate: sampleRate) {
                print("Transcription result: \(transcribedText)")
                
                // Log raw transcription to debug manager
                debugManager?.logRawTranscription(transcribedText, model: whisper.selectedModel.rawValue)
                
                if !transcribedText.isEmpty {
                    // Clear stored audio data on successful transcription
                    lastAudioData = nil
                    // Pass to text cleanup (US-005), including raw text for debug comparison
                    await processTextCleanup(transcribedText, rawTranscription: transcribedText)
                } else {
                    // Empty transcription (no speech) - don't clear audio data yet (allows retry)
                    recordingIndicator?.hideWithAnimation()
                }
            } else {
                // Transcription failed - keep audio data for retry
                recordingIndicator?.hideWithAnimation()
                print("Transcription failed or returned empty")
            }
            
            // Reset whisper status
            whisper.resetStatus()
        }
    }
    
    // MARK: - Error Handling
    
    @MainActor
    private func handleTranscriptionError(_ error: WhisperManager.TranscriptionError, audioData: Data?, sampleRate: Double) {
        recordingIndicator?.hideWithAnimation()
        
        // Store audio data for retry if provided
        if let audioData = audioData {
            lastAudioData = audioData
            lastAudioSampleRate = sampleRate
        }
        
        let alert = NSAlert()
        alert.messageText = error.errorDescription ?? "Transcription Error"
        alert.informativeText = error.recoverySuggestion ?? "An unknown error occurred during transcription."
        
        // Set alert style based on error type
        switch error {
        case .modelNotLoaded:
            alert.alertStyle = .warning
        case .noSpeechDetected, .blankAudioResult:
            alert.alertStyle = .informational
        case .audioValidationFailed, .whisperKitError, .unknownError:
            alert.alertStyle = .warning
        }
        
        // Add buttons based on whether retry is possible
        if error.isRetryable && lastAudioData != nil {
            alert.addButton(withTitle: "Try Again")
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                // Retry transcription
                retryLastTranscription()
            case .alertSecondButtonReturn:
                // Open settings
                openSettings()
            default:
                // Cancel - do nothing
                break
            }
        } else if case .modelNotLoaded = error {
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "OK")
            
            if alert.runModal() == .alertFirstButtonReturn {
                openSettings()
            }
        } else {
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open Settings")
            
            if alert.runModal() == .alertSecondButtonReturn {
                openSettings()
            }
        }
    }
    
    @MainActor
    private func retryLastTranscription() {
        guard let audioData = lastAudioData else {
            print("No audio data available for retry")
            showTranscriptionError("No previous recording available to retry.")
            return
        }
        
        print("Retrying transcription with stored audio data...")
        processTranscription(audioData: audioData, sampleRate: lastAudioSampleRate)
    }
    
    @MainActor
    private func processTextCleanup(_ transcribedText: String, rawTranscription: String? = nil) async {
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
        } else {
            recordingIndicator?.updateStatus("Processing...")
        }
        
        // US-607: Use processText which includes both cleanup and post-processing options
        // Post-processing (capitalize, period, trim) is always applied based on settings
        let cleanedText = await cleanup.processText(transcribedText)
        
        print("Final text (after cleanup + post-processing): \(cleanedText)")
        
        // Log cleaned transcription to debug manager
        debugManager?.logCleanedTranscription(cleanedText, mode: cleanup.selectedMode.rawValue)
        
        // Calculate processing time and store transcription data for debug
        if let startTime = transcriptionStartTime {
            let processingTime = Date().timeIntervalSince(startTime)
            debugManager?.storeTranscriptionData(
                raw: rawTranscription ?? transcribedText,
                cleaned: cleanedText,
                processingTime: processingTime,
                model: whisperManager?.selectedModel.rawValue ?? "unknown"
            )
        }
        
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
            
        case .fallbackToManualPaste(let reason):
            // US-515: Fallback handled by TextInserter - toast already shown
            // Don't show an error alert, as the user just needs to press Cmd+V
            print("Text insertion using fallback: \(reason)")
            print("Text is on clipboard - user should press Cmd+V to paste")
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
