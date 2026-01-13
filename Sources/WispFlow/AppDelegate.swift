import AppKit

/// Main application delegate that manages the menu bar app lifecycle
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var hotkeyManager: HotkeyManager?
    private var recordingIndicator: RecordingIndicatorWindow?
    private var audioManager: AudioManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the audio manager first
        setupAudioManager()
        
        // Initialize the status bar controller
        statusBarController = StatusBarController()
        
        // Provide audio manager to status bar controller for device selection
        statusBarController?.audioManager = audioManager
        
        // Set up recording state change handler
        statusBarController?.onRecordingStateChanged = { [weak self] state in
            self?.handleRecordingStateChange(state)
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
                // Future: Process transcription with Whisper (US-004)
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
