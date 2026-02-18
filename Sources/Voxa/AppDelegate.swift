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
    // US-708: settingsWindowController removed - settings now displayed in main window
    // Onboarding now integrated into main window
    private var debugManager: DebugManager?
    private var toastWindowController: ToastWindowController?
    private var mainWindowController: MainWindowController?
    private var updateManager: UpdateManager?
    
    // Store last audio data for retry functionality
    private var lastAudioData: Data?
    private var lastAudioSampleRate: Double = 16000.0
    
    // US-633: Track last recording duration for stats
    private var lastRecordingDuration: Double = 0.0
    
    // US-608: Timer to clear audio buffer after timeout (30 seconds)
    private var audioBufferClearTimer: Timer?
    private static let audioBufferTimeoutSeconds: TimeInterval = 30.0
    
    // Track transcription timing for debug
    private var transcriptionStartTime: Date?

    // US-051: Track startup timing for optimization
    private var startupStartTime: CFAbsoluteTime = 0

    // US-054: App Nap activity token to prevent App Nap during recording
    private var appNapActivity: NSObjectProtocol?

    // US-054: Track idle state for battery optimization
    private var isAppIdle: Bool = true

    // Flag to prevent showing model not ready alert repeatedly
    private var hasShownModelNotReadyAlert: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // US-051: Start timing app startup
        startupStartTime = CFAbsoluteTimeGetCurrent()

        // Apply saved appearance mode
        AppearanceManager.shared.applyAppearance()

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
        
        // US-632: Set up callback for opening main window
        statusBarController?.onOpenMainWindow = { [weak self] in
            self?.openMainWindow()
        }

        // US-030: Set up callback for opening clipboard history
        statusBarController?.onOpenClipboardHistory = { [weak self] in
            self?.openClipboardHistory()
        }

        statusBarController?.onCheckForUpdates = { [weak self] in
            Task { @MainActor in
                self?.updateManager?.checkForUpdates()
            }
        }

        // Initialize and start the hotkey manager
        setupHotkeyManager()

        // US-022: Provide hotkey manager to status bar controller for mode indicator
        statusBarController?.hotkeyManager = hotkeyManager

        // Initialize the recording indicator (but don't show it yet)
        setupRecordingIndicator()
        
        // Initialize the toast notification system (US-409)
        setupToastSystem()
        
        print("Voxa started successfully")
        print("Global hotkey: \(hotkeyManager?.hotkeyDisplayString ?? "unknown")")
        
        // NOTE: Don't request microphone permission here - let onboarding handle it
        // Permission will be requested during the onboarding microphone step (US-518)
        // or when the user first tries to record
        
        // Initialize Whisper manager, text cleanup manager, LLM manager, text inserter, and auto-load models on main actor
        Task { @MainActor in
            setupUpdateManager()
            setupWhisperManager()
            setupTextCleanupManager()
            setupLLMManager()
            setupTextInserter()
            setupDebugManager()
            
            // Provide whisper manager to status bar controller
            statusBarController?.whisperManager = whisperManager
            
            // Connect LLM manager to text cleanup manager
            textCleanupManager?.llmManager = llmManager
            
            // US-708: Settings window controller removed - settings now displayed in main window

            // US-051: Defer Whisper model loading until first recording attempt
            // This significantly improves startup time (from 2-10s to <1s)
            // Model will be loaded on-demand when user tries to record
            print("US-051: Whisper model loading deferred for faster startup")

            // Auto-download small Whisper model only if no models are present on disk
            if let whisper = whisperManager {
                if whisper.getDownloadedModels().isEmpty {
                    print("AppDelegate: No Whisper model downloaded - auto-downloading small model")
                    // Select small model and start download
                    await whisper.selectModel(.small)
                    print("AppDelegate: Auto-download of small model initiated")
                }
            }

            // Text cleanup is ready immediately (rule-based, no model download needed)
            print("Text cleanup ready with mode: \(textCleanupManager?.selectedMode.rawValue ?? "unknown")")
            
            // US-051: LLM model loading also deferred until first use
            // LLM will be loaded when AI-powered cleanup is triggered
            if textCleanupManager?.selectedMode == .aiPowered {
                print("US-051: LLM model loading deferred for faster startup (AI cleanup mode selected)")
            }
            
            // Check accessibility permission on launch (without prompt)
            if let inserter = textInserter {
                if inserter.hasAccessibilityPermission {
                    print("Accessibility permission already granted")
                } else {
                    print("Accessibility permission not granted - will prompt on first text insertion")
                }
            }
            
            // Listen for accessibility permission changes to restart hotkey manager
            PermissionManager.shared.onAccessibilityStatusChanged = { [weak self] status in
                if status.isGranted {
                    print("AppDelegate: Accessibility permission granted - restarting hotkey manager")
                    self?.hotkeyManager?.start()
                }
            }
            
            // US-517: Show onboarding wizard on first launch
            setupOnboarding()

            // US-051: Log startup timing
            let startupDuration = CFAbsoluteTimeGetCurrent() - startupStartTime
            print("US-051: App startup completed in \(String(format: "%.2f", startupDuration * 1000))ms (model loading deferred)")
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Stop any active recording
        audioManager?.cancelCapturing()

        // Stop the hotkey manager
        hotkeyManager?.stop()

        // Hide the recording indicator if visible
        recordingIndicator?.orderOut(nil)

        // US-054: End any active App Nap prevention
        if let activity = appNapActivity {
            ProcessInfo.processInfo.endActivity(activity)
            appNapActivity = nil
        }

        print("Voxa shutting down")
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Setup

    @MainActor
    private func setupUpdateManager() {
        updateManager = UpdateManager.shared
        updateManager?.refreshConfiguration()
    }

    private func setupAudioManager() {
        // US-701: Use shared singleton instance
        audioManager = AudioManager.shared
        
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

        // US-003: Handle new device connected - disabled toast notifications per user request
        // Device changes are still logged but no longer show intrusive toasts
        audioManager?.onNewDeviceConnected = { _, newDeviceName, currentDeviceName in
            print("AppDelegate: [US-003] New device connected: \(newDeviceName) (current: \(currentDeviceName))")
            ErrorLogger.shared.log(
                "New audio device connected",
                category: .audio,
                severity: .info,
                context: [
                    "newDevice": newDeviceName,
                    "currentDevice": currentDeviceName
                ]
            )
            // Toast notification disabled - users can change devices via Settings > Audio
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

        // US-006: Handle prolonged silence detected during recording (muted/silent input)
        audioManager?.onProlongedSilenceDetected = { measuredDbLevel, silenceDuration, deviceName in
            print("AppDelegate: [US-006] Prolonged silence detected - \(String(format: "%.1f", silenceDuration))s at \(String(format: "%.1f", measuredDbLevel))dB on \(deviceName)")
            ErrorLogger.shared.log(
                "Prolonged silence detected during recording",
                category: .audio,
                severity: .warning,
                context: [
                    "measuredLevel": "\(String(format: "%.1f", measuredDbLevel))dB",
                    "silenceDuration": "\(String(format: "%.1f", silenceDuration))s",
                    "device": deviceName
                ]
            )
            DispatchQueue.main.async {
                ToastManager.shared.showProlongedSilenceWarning(
                    measuredDbLevel: measuredDbLevel,
                    deviceName: deviceName
                )
            }
        }
    }
    
    private func showSilenceWarning(measuredDbLevel: Float) {
        DispatchQueue.main.async {
            // Show a toast notification instead of blocking alert
            ToastManager.shared.showWarning(
                "No Audio Detected",
                message: "Check your microphone connection",
                icon: "mic.slash"
            )
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
        // US-701: Use shared singleton instance
        whisperManager = WhisperManager.shared
        
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
        // US-701: Use shared singleton instance
        textCleanupManager = TextCleanupManager.shared
        
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
        // US-701: Use shared singleton instance
        llmManager = LLMManager.shared
        
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
        // US-701: Use shared singleton instance
        textInserter = TextInserter.shared
        
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
            message: "Voxa initialized",
            details: "Audio: \(audioManager != nil ? "OK" : "Missing"), Whisper: \(whisperManager != nil ? "OK" : "Missing")"
        )
    }
    
    /// US-708: Open the main window with Settings selected
    private func openSettings() {
        openMainWindow(initialNavItem: .settings)
    }

    /// US-030: Open the main window with History selected (for clipboard history access)
    private func openClipboardHistory() {
        openMainWindow(initialNavItem: .history)
    }

    private func setupHotkeyManager() {
        // US-701: Use shared singleton instance
        hotkeyManager = HotkeyManager.shared
        
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

        // US-016: Handle cancel hotkey to discard recording
        hotkeyManager?.onCancelHotkeyPressed = { [weak self] in
            print("AppDelegate: [US-016] Cancel hotkey pressed")
            DispatchQueue.main.async {
                self?.cancelRecordingWithFeedback()
            }
        }

        // US-017: Handle insert last transcription hotkey
        hotkeyManager?.onInsertHotkeyPressed = { [weak self] in
            print("AppDelegate: [US-017] Insert hotkey pressed")
            DispatchQueue.main.async {
                self?.insertLastTranscription()
            }
        }

        // US-026: Handle undo transcription hotkey
        hotkeyManager?.onUndoHotkeyPressed = { [weak self] in
            print("AppDelegate: [US-026] Undo hotkey pressed")
            DispatchQueue.main.async {
                self?.undoLastTranscription()
            }
        }

        // US-027: Handle redo transcription hotkey
        hotkeyManager?.onRedoHotkeyPressed = { [weak self] in
            print("AppDelegate: [US-027] Redo hotkey pressed")
            DispatchQueue.main.async {
                self?.redoLastTranscription()
            }
        }

        // US-020: Handle push-to-talk key release to stop recording
        hotkeyManager?.onHotkeyReleased = { [weak self] in
            print("AppDelegate: [US-020] Push-to-talk hotkey released")
            DispatchQueue.main.async {
                self?.stopRecordingFromPushToTalk()
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
        alert.informativeText = "Voxa needs accessibility permission to detect global hotkeys and insert text.\n\nPlease grant permission in System Settings > Privacy & Security > Accessibility, then restart Voxa."
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

        // Observe requestOpenSettings notification from toast actions and external sources
        // Note: .openSettings is for internal MainWindowView navigation only (avoids recursive loops)
        NotificationCenter.default.addObserver(
            forName: .requestOpenSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.openSettings()
        }

        // US-802: Observe toggleRecording notification from Start Recording button
        NotificationCenter.default.addObserver(
            forName: .toggleRecording,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.toggleRecordingFromHotkey()
        }

        // US-632: Initialize main window controller
        mainWindowController = MainWindowController()

        // Configure with managers for onboarding integration
        if let audio = audioManager, let hotkey = hotkeyManager {
            mainWindowController?.configure(audioManager: audio, hotkeyManager: hotkey)
        }

        // US-053: Set up memory pressure observer
        setupMemoryPressureObserver()

        // US-054: Initialize battery efficiency manager for adaptive power management
        _ = BatteryEfficiencyManager.shared
        print("US-054: Battery efficiency manager initialized")
    }

    // MARK: - US-053: Memory Pressure Handling

    /// Set up observer for system memory pressure notifications
    private func setupMemoryPressureObserver() {
        // Listen for memory pressure warnings using dispatch source
        let memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )

        memoryPressureSource.setEventHandler { [weak self] in
            let event = memoryPressureSource.data
            Task { @MainActor in
                if event.contains(.critical) {
                    print("US-053: Critical memory pressure - performing aggressive cleanup")
                    self?.handleMemoryPressure(critical: true)
                } else if event.contains(.warning) {
                    print("US-053: Memory pressure warning - performing cleanup")
                    self?.handleMemoryPressure(critical: false)
                }
            }
        }

        memoryPressureSource.resume()
    }

    /// Handle memory pressure by cleaning up non-essential data
    /// - Parameter critical: If true, perform more aggressive cleanup
    @MainActor
    private func handleMemoryPressure(critical: Bool) {
        // Clear retained audio data immediately
        lastAudioData = nil
        audioBufferClearTimer?.invalidate()
        audioBufferClearTimer = nil

        // Trim clipboard history to reduce memory footprint
        if critical {
            // Under critical pressure, keep only recent entries
            ClipboardHistoryManager.shared.trimToCount(10)
        } else {
            // Under warning, trim to half the max
            let currentMax = ClipboardHistoryManager.shared.maxEntries
            ClipboardHistoryManager.shared.trimToCount(currentMax / 2)
        }

        // Clear undo stack under memory pressure
        if critical {
            UndoStackManager.shared.clearStack()
        }

        ErrorLogger.shared.log(
            "Memory pressure cleanup performed",
            category: .general,
            severity: critical ? .warning : .info,
            context: [
                "criticalPressure": "\(critical)",
                "clearedAudioBuffer": "true"
            ]
        )
    }
    
    /// US-632: Open the main application window
    /// - Parameter initialNavItem: Optional navigation item to select when window opens
    private func openMainWindow(initialNavItem: NavigationItem? = nil) {
        mainWindowController?.showMainWindow(initialNavItem: initialNavItem)
    }
    
    /// US-517: Set up onboarding (now integrated into main window)
    @MainActor
    private func setupOnboarding() {
        // Onboarding is now integrated into the main window
        // Just open the main window - it will show onboarding overlay if first launch
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        if !hasCompletedOnboarding {
            print("AppDelegate: [US-517] First launch - opening main window with onboarding")
            // App starts as .regular for permission dialogs to work
            openMainWindow()
        } else {
            print("AppDelegate: [US-517] Onboarding already completed")
            // Switch to accessory mode (menu bar only, no dock icon)
            NSApp.setActivationPolicy(.accessory)
            // Start hotkey manager since onboarding is done
            hotkeyManager?.start()
        }
    }
    
    // MARK: - Recording Control
    
    private func toggleRecordingFromHotkey() {
        print("Hotkey triggered - toggling recording")

        // Block recording if trying to START and model is not ready
        // Use Task to access MainActor-isolated whisperManager
        Task { @MainActor in
            if statusBarController?.currentState == .idle {
                // About to start recording, check if model is ready
                guard let whisper = whisperManager else {
                    print("Cannot start recording - whisper manager not initialized")
                    showModelNotReadyAlert()
                    return
                }

                // US-051: Handle deferred model loading for faster startup
                // If model is downloaded but not loaded, trigger loading now
                if case .downloaded = whisper.modelStatus {
                    print("US-051: Model downloaded but not loaded - loading now on first recording attempt")
                    ToastManager.shared.showInfo(
                        "Loading Whisper Model",
                        message: "Please wait while the model loads...",
                        icon: "cpu"
                    )
                    await whisper.loadModel()

                    // Check if load succeeded
                    if !whisper.isReady {
                        print("US-051: Model loading failed")
                        showModelNotReadyAlert()
                        return
                    }
                    print("US-051: Model loaded successfully, proceeding with recording")
                    ToastManager.shared.showSuccess(
                        "Model Ready",
                        message: "Press the hotkey again to start recording"
                    )
                    return  // User needs to press hotkey again after loading
                }

                // For other non-ready states, show the alert
                guard whisper.isReady else {
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
        // Prevent showing alert multiple times in quick succession
        guard !hasShownModelNotReadyAlert else {
            print("AppDelegate: Model not ready alert already shown, skipping duplicate")
            return
        }

        hasShownModelNotReadyAlert = true

        // Reset the flag after a delay to allow showing again later if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.hasShownModelNotReadyAlert = false
        }

        let alert = NSAlert()

        // Determine message based on model status
        var detailMessage = "Please wait for the Whisper model to finish loading."
        if let whisper = whisperManager {
            switch whisper.modelStatus {
            case .notDownloaded:
                detailMessage = "No Whisper model is downloaded. Please open Settings and download a model."
            case .downloading(let progress):
                detailMessage = "Model is downloading (\(Int(progress * 100))%). Please wait for the download to complete."
            case .switching(let toModel, let progress):
                // US-008: Model switch in progress - current model still available
                detailMessage = "Switching to \(toModel) (\(Int(progress * 100))%). The current model remains available for transcription."
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

    /// US-016: Cancel recording with visual feedback (only when recording is active)
    private func cancelRecordingWithFeedback() {
        // Only cancel if we're currently recording
        guard statusBarController?.currentState == .recording else {
            print("AppDelegate: [US-016] Cancel hotkey ignored - not currently recording")
            return
        }

        print("AppDelegate: [US-016] Cancelling recording with feedback")

        // Disconnect audio level meter from indicator
        recordingIndicator?.disconnectAudioManager()

        // Cancel audio capture (discards recorded audio)
        audioManager?.cancelCapturing()

        // Update indicator to show cancellation feedback briefly
        recordingIndicator?.updateStatus("Cancelled")

        // Show a brief animation and then hide
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.recordingIndicator?.hideWithAnimation()
        }

        // Force state to idle
        statusBarController?.setRecordingState(.idle)

        // Show toast notification for visual feedback
        ToastManager.shared.showInfo(
            "Recording Cancelled",
            message: "Audio discarded",
            icon: "xmark.circle"
        )

        // US-020: Reset push-to-talk state if enabled
        hotkeyManager?.resetPushToTalkState()
    }

    /// US-020: Stop recording when push-to-talk key is released
    private func stopRecordingFromPushToTalk() {
        // Only stop if we're currently recording
        guard statusBarController?.currentState == .recording else {
            print("AppDelegate: [US-020] Push-to-talk release ignored - not currently recording")
            return
        }

        print("AppDelegate: [US-020] Stopping recording from push-to-talk release")

        // Set state to idle - this triggers the normal stop recording flow
        // which will process transcription automatically
        statusBarController?.setRecordingState(.idle)
    }

    /// US-017: Insert last transcription at cursor position
    @MainActor
    private func insertLastTranscription() {
        // Get the most recent transcription from history
        let entries = UsageStatsManager.shared.recentEntries

        guard let lastEntry = entries.first else {
            print("AppDelegate: [US-017] No transcription history available")
            ToastManager.shared.showWarning(
                "No Transcription",
                message: "No recent transcription to insert"
            )
            return
        }

        print("AppDelegate: [US-017] Inserting last transcription (\(lastEntry.wordCount) words)")

        // Insert the text at cursor position
        Task {
            await performTextInsertion(lastEntry.fullText)
        }
    }

    /// US-026: Undo last transcription insertion
    @MainActor
    private func undoLastTranscription() {
        // Check if there's anything to undo
        guard UndoStackManager.shared.canUndo else {
            print("AppDelegate: [US-026] No transcription to undo")
            ToastManager.shared.showWarning(
                "Nothing to Undo",
                message: "No recent transcription to undo"
            )
            return
        }

        guard let entry = UndoStackManager.shared.topEntry else {
            return
        }

        print("AppDelegate: [US-026] Undoing transcription (\(entry.characterCount) characters)")

        // Perform the undo
        Task {
            await performUndo(entry: entry)
        }
    }

    /// US-026: Perform the actual undo operation
    @MainActor
    private func performUndo(entry: UndoEntry) async {
        guard let inserter = textInserter else {
            print("AppDelegate: [US-026] TextInserter not available")
            return
        }

        let result = await inserter.undoText(characterCount: entry.characterCount)

        switch result {
        case .success:
            // Remove the entry from the undo stack
            UndoStackManager.shared.popTopEntry()

            // Show success feedback
            ToastManager.shared.showSuccess(
                "Undo Complete",
                message: "\(entry.characterCount) characters removed",
                icon: "arrow.uturn.backward"
            )
            print("AppDelegate: [US-026] Undo successful")

        case .noAccessibilityPermission:
            print("AppDelegate: [US-026] Undo failed - no accessibility permission")
            showAccessibilityPermissionAlert()

        case .undoFailed(let message):
            print("AppDelegate: [US-026] Undo failed: \(message)")
            ToastManager.shared.showError(
                "Undo Failed",
                message: "Could not remove the text",
                icon: "exclamationmark.triangle"
            )
        }

        // Reset inserter status
        inserter.resetStatus()
    }

    /// US-027: Redo last undone transcription
    @MainActor
    private func redoLastTranscription() {
        // Check if there's anything to redo
        guard UndoStackManager.shared.canRedo else {
            print("AppDelegate: [US-027] No transcription to redo")
            ToastManager.shared.showWarning(
                "Nothing to Redo",
                message: "No undone transcription to redo"
            )
            return
        }

        guard let entry = UndoStackManager.shared.topRedoEntry else {
            return
        }

        print("AppDelegate: [US-027] Redoing transcription (\(entry.characterCount) characters)")

        // Perform the redo (re-insert the text)
        Task {
            await performRedo(entry: entry)
        }
    }

    /// US-027: Perform the actual redo operation (re-insert text)
    @MainActor
    private func performRedo(entry: UndoEntry) async {
        guard let inserter = textInserter else {
            print("AppDelegate: [US-027] TextInserter not available")
            return
        }

        let result = await inserter.insertText(entry.text)

        switch result {
        case .success:
            // Move entry from redo stack back to undo stack
            UndoStackManager.shared.popRedoEntry()

            // Show success feedback
            ToastManager.shared.showSuccess(
                "Redo Complete",
                message: "\(entry.characterCount) characters restored",
                icon: "arrow.uturn.forward"
            )
            print("AppDelegate: [US-027] Redo successful")

        case .noAccessibilityPermission:
            print("AppDelegate: [US-027] Redo failed - no accessibility permission")
            showAccessibilityPermissionAlert()

        case .insertionFailed(let message):
            print("AppDelegate: [US-027] Redo failed: \(message)")
            ToastManager.shared.showError(
                "Redo Failed",
                message: "Could not restore the text",
                icon: "exclamationmark.triangle"
            )

        case .fallbackToManualPaste(let message):
            // Text is on clipboard, user can paste manually
            // Still move entry from redo to undo since text will be inserted
            UndoStackManager.shared.popRedoEntry()
            print("AppDelegate: [US-027] Redo fallback to manual paste: \(message)")
            ToastManager.shared.showWarning(
                "Manual Paste Required",
                message: "Press ⌘V to paste the text",
                icon: "doc.on.clipboard"
            )
        }

        // Reset inserter status
        inserter.resetStatus()
    }

    // MARK: - Recording State Handling
    
    private func handleRecordingStateChange(_ state: RecordingState) {
        // US-802: Post notification so Start Recording button can update its state
        NotificationCenter.default.post(name: .recordingStateChanged, object: state)

        // US-054: Manage App Nap based on recording state
        updateAppNapState(for: state)

        switch state {
        case .idle:
            // US-054: Mark app as idle for battery optimization
            isAppIdle = true

            // Disconnect audio level meter
            recordingIndicator?.disconnectAudioManager()

            // Switch to processing state (shows loading animation)
            recordingIndicator?.showProcessing()

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
                
                // US-633: Store recording duration for stats tracking
                self.lastRecordingDuration = result.duration
                
                // Process transcription on MainActor where we can check DebugManager
                let audioData = result.audioData
                let sampleRate = result.sampleRate
                let wasSilent = result.wasSilent
                let duration = result.duration
                
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
                        self?.processTranscription(audioData: audioData, sampleRate: sampleRate, recordingDuration: duration)
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
            // US-054: Mark app as active (not idle) during recording
            isAppIdle = false

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

        case .processing:
            // US-054: Mark app as active during processing
            isAppIdle = false
            // US-034: Processing state - menu bar icon shows processing animation
            // The processing state is managed by StatusBarController, no additional action needed here
            print("Processing transcription...")

        case .error:
            // US-034: Error state - menu bar icon shows error indicator
            // The error state is managed by StatusBarController, no additional action needed here
            print("Error state active")
        }
    }

    // MARK: - US-054: App Nap Management

    /// Update App Nap state based on recording activity
    /// Prevents App Nap during recording/processing to ensure reliable audio capture
    private func updateAppNapState(for state: RecordingState) {
        switch state {
        case .recording, .processing:
            // Disable App Nap during recording and processing
            if appNapActivity == nil {
                appNapActivity = ProcessInfo.processInfo.beginActivity(
                    options: [.userInitiated, .latencyCritical],
                    reason: "Voxa is recording or processing audio"
                )
                print("US-054: App Nap disabled for \(state.rawValue)")
            }

        case .idle, .error:
            // Re-enable App Nap when idle or in error state
            if let activity = appNapActivity {
                ProcessInfo.processInfo.endActivity(activity)
                appNapActivity = nil
                print("US-054: App Nap re-enabled")
            }
        }
    }
    
    @MainActor
    private func processTranscription(audioData: Data, sampleRate: Double, recordingDuration: Double? = nil) {
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
        
        // US-608: Store audio data for potential retry
        lastAudioData = audioData
        lastAudioSampleRate = sampleRate
        
        // US-633: Store recording duration if provided
        if let duration = recordingDuration {
            lastRecordingDuration = duration
        }
        
        // US-608: Start buffer clear timer (30 seconds to allow retry)
        startAudioBufferClearTimer()
        
        // Track transcription start time for debug
        transcriptionStartTime = Date()

        // US-034: Update menu bar icon to show processing state
        statusBarController?.setRecordingState(.processing)

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
                    // US-633: Include recording duration for stats tracking
                    await processTextCleanup(transcribedText, rawTranscription: transcribedText, recordingDuration: lastRecordingDuration)
                } else {
                    // Empty transcription (no speech) - don't clear audio data yet (allows retry)
                    recordingIndicator?.hideWithAnimation()
                    // US-034: Return to idle state
                    statusBarController?.setRecordingState(.idle)
                }
            } else {
                // Transcription failed - keep audio data for retry
                recordingIndicator?.hideWithAnimation()
                print("Transcription failed or returned empty")
                // US-034: Return to idle state on failure
                statusBarController?.setRecordingState(.idle)
            }

            // Reset whisper status
            whisper.resetStatus()
        }
    }
    
    // MARK: - Error Handling
    
    @MainActor
    private func handleTranscriptionError(_ error: WhisperManager.TranscriptionError, audioData: Data?, sampleRate: Double) {
        recordingIndicator?.hideWithAnimation()

        // US-034: Show error state in menu bar icon briefly
        statusBarController?.setRecordingState(.error)

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
                // US-034: Return to idle state after error is dismissed
                statusBarController?.setRecordingState(.idle)
            default:
                // Cancel - do nothing
                // US-034: Return to idle state after error is dismissed
                statusBarController?.setRecordingState(.idle)
            }
        } else if case .modelNotLoaded = error {
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "OK")

            if alert.runModal() == .alertFirstButtonReturn {
                openSettings()
            }
            // US-034: Return to idle state after error is dismissed
            statusBarController?.setRecordingState(.idle)
        } else {
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open Settings")

            if alert.runModal() == .alertSecondButtonReturn {
                openSettings()
            }
            // US-034: Return to idle state after error is dismissed
            statusBarController?.setRecordingState(.idle)
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
    
    // MARK: - US-608: Audio Buffer Clear Timer
    
    /// Start timer to clear audio buffer after timeout (30 seconds)
    /// This allows retry for that window, then clears memory
    @MainActor
    private func startAudioBufferClearTimer() {
        // Invalidate any existing timer
        stopAudioBufferClearTimer()
        
        // Create new timer
        audioBufferClearTimer = Timer.scheduledTimer(
            withTimeInterval: Self.audioBufferTimeoutSeconds,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.clearAudioBuffer()
            }
        }
        
        print("[US-608] Audio buffer clear timer started (\(Self.audioBufferTimeoutSeconds)s)")
    }
    
    /// Stop the audio buffer clear timer
    @MainActor
    private func stopAudioBufferClearTimer() {
        audioBufferClearTimer?.invalidate()
        audioBufferClearTimer = nil
    }
    
    /// Clear the stored audio buffer
    @MainActor
    private func clearAudioBuffer() {
        if lastAudioData != nil {
            print("[US-608] Clearing audio buffer after timeout")
            lastAudioData = nil
        }
        stopAudioBufferClearTimer()
    }
    
    @MainActor
    private func processTextCleanup(_ transcribedText: String, rawTranscription: String? = nil, recordingDuration: Double = 0) async {
        guard let cleanup = textCleanupManager else {
            print("TextCleanupManager not available, using raw text")
            recordingIndicator?.hideWithAnimation()
            // Insert raw text directly
            await performTextInsertion(transcribedText)
            // US-633: Still record stats even without cleanup
            UsageStatsManager.shared.recordTranscription(text: transcribedText, durationSeconds: recordingDuration)
            // US-034: Return to idle state
            statusBarController?.setRecordingState(.idle)
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
        
        // US-633: Record transcription to usage stats for dashboard
        UsageStatsManager.shared.recordTranscription(text: cleanedText, durationSeconds: recordingDuration)
        
        // Hide the indicator after insertion
        recordingIndicator?.hideWithAnimation()

        // US-034: Return to idle state after processing complete
        statusBarController?.setRecordingState(.idle)

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
            // US-026: Record the insertion for undo functionality
            UndoStackManager.shared.recordInsertion(text)
            // US-030: Record to clipboard history
            ClipboardHistoryManager.shared.recordEntry(text)

        case .noAccessibilityPermission:
            print("Text insertion failed: No accessibility permission")
            showAccessibilityPermissionAlert()
            
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
    
    private func showAccessibilityPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "Voxa needs accessibility permission to insert transcribed text.\n\nPlease grant permission in System Settings > Privacy & Security > Accessibility, then try again."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn {
                PermissionManager.shared.openAccessibilitySettings()
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
