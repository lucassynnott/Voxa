import AVFoundation
import AppKit
import Combine

/// Manages audio capture using AVAudioEngine with support for device selection
/// Handles microphone permissions, audio input device enumeration, and audio buffering
final class AudioManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide access
    /// US-701: Added for SettingsContentView in MainWindow
    static let shared = AudioManager()
    
    // MARK: - Types
    
    /// Represents an available audio input device
    struct AudioInputDevice: Equatable, Identifiable {
        let id: AudioDeviceID
        let uid: String
        let name: String
        let isDefault: Bool
        let sampleRate: Float64  // US-501: Sample rate for quality scoring
        
        static func == (lhs: AudioInputDevice, rhs: AudioInputDevice) -> Bool {
            return lhs.uid == rhs.uid
        }
    }
    
    // MARK: - US-501: Device Quality Scoring
    
    /// Device quality category for scoring
    enum DeviceQuality: Int, Comparable {
        case bluetooth = 0      // Lowest priority - AirPods, Beats, etc.
        case lowSampleRate = 1  // Deprioritized - ≤16kHz
        case builtIn = 2        // Medium priority - MacBook microphone
        case usb = 3            // High priority - external USB mics
        case professional = 4   // Highest priority - professional audio interfaces
        
        static func < (lhs: DeviceQuality, rhs: DeviceQuality) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    /// Keywords that indicate low-quality Bluetooth devices
    private static let lowQualityKeywords = [
        "airpods", "airpod", "beats", "bluetooth", "hfp", "headset", "wireless"
    ]
    
    /// Keywords that indicate built-in microphones
    private static let builtInKeywords = [
        "built-in", "macbook", "imac", "mac mini", "mac studio", "mac pro"
    ]
    
    /// Keywords that indicate USB/external microphones (high quality)
    private static let usbKeywords = [
        "usb", "yeti", "blue", "rode", "shure", "audio-technica", "at2020",
        "samson", "focusrite", "scarlett", "apollo", "universal audio"
    ]
    
    /// Audio capture completion result
    struct AudioCaptureResult {
        let audioData: Data
        let duration: TimeInterval
        let sampleRate: Double
        let peakLevel: Float    // Peak level in dB
        let sampleCount: Int    // Total number of samples
        let wasSilent: Bool     // True if audio appeared silent (peak < -55dB and >95% near-zero samples)
        let measuredDbLevel: Float  // Actual measured dB level for error messages
    }
    
    /// Audio buffer statistics for debugging
    struct AudioBufferStats {
        let sampleCount: Int
        let duration: TimeInterval
        let peakLevel: Float    // dB
        let rmsLevel: Float     // dB
        let minSample: Float
        let maxSample: Float
        let nearZeroPercentage: Float  // Percentage of samples that are near-zero (< 1e-7)
    }
    
    /// Permission status for microphone access
    enum MicrophonePermissionStatus {
        case authorized
        case denied
        case notDetermined
        case restricted
    }
    
    // MARK: - US-602: Audio Format Negotiation
    
    /// Represents a supported audio format for a device
    struct AudioFormatInfo {
        let sampleRate: Float64
        let channelCount: UInt32
        let bitsPerChannel: UInt32
        let formatID: AudioFormatID
        let formatFlags: AudioFormatFlags
        
        /// Human-readable description of the format
        var description: String {
            let rateStr = sampleRate >= 1000 ? "\(Int(sampleRate / 1000))kHz" : "\(Int(sampleRate))Hz"
            let channelStr = channelCount == 1 ? "mono" : channelCount == 2 ? "stereo" : "\(channelCount)ch"
            let formatStr = formatIDDescription
            return "\(rateStr) \(channelStr) \(bitsPerChannel)-bit \(formatStr)"
        }
        
        /// Format ID as readable string
        private var formatIDDescription: String {
            switch formatID {
            case kAudioFormatLinearPCM:
                return "PCM"
            case kAudioFormatAC3:
                return "AC3"
            case kAudioFormatMPEG4AAC:
                return "AAC"
            default:
                // Convert FourCC to string
                let chars: [Character] = [
                    Character(UnicodeScalar((formatID >> 24) & 0xFF) ?? "?"),
                    Character(UnicodeScalar((formatID >> 16) & 0xFF) ?? "?"),
                    Character(UnicodeScalar((formatID >> 8) & 0xFF) ?? "?"),
                    Character(UnicodeScalar(formatID & 0xFF) ?? "?")
                ]
                return String(chars)
            }
        }
        
        /// Check if format is suitable for voice capture (standard formats preferred)
        var isStandardFormat: Bool {
            // Preferred sample rates for voice capture
            let preferredRates: [Float64] = [44100, 48000, 16000, 22050, 32000, 96000]
            let isPreferredRate = preferredRates.contains(where: { abs($0 - sampleRate) < 1 })
            
            // Must be PCM format
            let isPCM = formatID == kAudioFormatLinearPCM
            
            // Must have reasonable channel count (1-2 channels preferred)
            let hasReasonableChannels = channelCount >= 1 && channelCount <= 2
            
            return isPCM && isPreferredRate && hasReasonableChannels
        }
        
        /// Priority score for format selection (higher is better)
        var priorityScore: Int {
            var score = 0
            
            // Prefer PCM format (required)
            if formatID == kAudioFormatLinearPCM {
                score += 100
            }
            
            // Prefer standard sample rates (48kHz > 44.1kHz > others)
            switch Int(sampleRate) {
            case 48000: score += 50
            case 44100: score += 45
            case 96000: score += 40
            case 32000: score += 30
            case 22050: score += 25
            case 16000: score += 20
            default: break
            }
            
            // Prefer mono or stereo
            switch channelCount {
            case 1: score += 15  // Mono is ideal for voice
            case 2: score += 10  // Stereo is acceptable
            default: break
            }
            
            // Prefer 16-bit or higher
            if bitsPerChannel >= 16 {
                score += 5
            }
            
            return score
        }
    }
    
    /// US-602: Standard sample rates to prefer (in order of preference)
    private static let preferredSampleRates: [Float64] = [48000, 44100, 96000, 32000, 22050, 16000]
    
    // MARK: - Constants
    
    private struct Constants {
        static let targetSampleRate: Double = 16000.0 // Whisper prefers 16kHz
        static let selectedDeviceKey = "selectedAudioInputDeviceUID"
        static let silenceThresholdDB: Float = -55.0  // Below this is considered silence (lowered from -40dB for more permissive detection)
        static let minimumRecordingDuration: TimeInterval = 0.5 // Minimum 0.5s recording
        
        // US-603: Recording Timeout Safety - prevent runaway recordings
        static let maxRecordingDurationKey = "maxRecordingDuration"
        static let defaultMaxRecordingDuration: TimeInterval = 300.0 // 5 minutes default
        static let warningOffsetFromMax: TimeInterval = 60.0 // Warning 1 minute before max (at 4 minutes)
        
        // US-604: Audio Level Calibration
        static let calibrationDuration: TimeInterval = 3.0 // Measure ambient noise over 3 seconds
        static let calibrationDataKey = "audioCalibrationData" // UserDefaults key for calibration data
        static let defaultSilenceThresholdOffset: Float = 5.0 // Add 5dB margin above ambient noise

        // US-006: Muted/Silent Input Detection
        static let silenceWarningDurationKey = "silenceWarningDuration"
        static let defaultSilenceWarningDuration: TimeInterval = 3.0 // Warn after 3 seconds of silence
        static let silenceCheckInterval: TimeInterval = 0.5 // Check every 0.5 seconds
    }
    
    // MARK: - US-604: Audio Level Calibration
    
    /// Calibration state for tracking calibration progress
    enum CalibrationState: Equatable {
        case idle
        case calibrating(progress: Double)
        case completed(ambientLevel: Float)
        case failed(message: String)
    }
    
    /// Calibration data for a specific device
    struct DeviceCalibration: Codable {
        let deviceUID: String
        let deviceName: String
        let ambientNoiseLevel: Float  // Measured ambient noise in dB
        let silenceThreshold: Float   // Calculated silence threshold in dB
        let calibrationDate: Date
        
        /// Human-readable description
        var description: String {
            return "Ambient: \(String(format: "%.1f", ambientNoiseLevel))dB, Threshold: \(String(format: "%.1f", silenceThreshold))dB"
        }
    }
    
    // MARK: - Properties
    
    private let audioEngine = AVAudioEngine()
    /// Muted sink to keep the input node actively rendering so taps receive data
    private let inputMixerNode = AVAudioMixerNode()
    
    /// UNIFIED AUDIO BUFFER (US-301): Single masterBuffer is the ONLY audio storage
    /// Both level meter and transcription read from this same buffer
    private var masterBuffer: [Float] = []
    
    /// Lock for thread-safe access to masterBuffer
    private let bufferLock = NSLock()
    
    /// Track sample count for logging at each stage
    private var tapCallbackCount: Int = 0
    private var samplesAddedThisCallback: Int = 0
    
    /// US-302: Timer to alert if no tap callbacks received within 2 seconds
    private var noCallbackAlertTimer: Timer?
    private var emptyCallbackCount: Int = 0  // Track callbacks with empty/zero data
    
    // US-603: Recording Timeout Timers
    private var recordingTimeoutWarningTimer: Timer?
    private var recordingTimeoutMaxTimer: Timer?
    private var hasShownTimeoutWarning: Bool = false
    private var zeroDataCallbackCount: Int = 0  // Track callbacks where all samples are zero

    // US-006: Muted/Silent Input Detection
    private var silenceMonitorTimer: Timer?
    private var continuousSilenceDuration: TimeInterval = 0
    private var hasShownSilenceWarning: Bool = false
    
    private var isCapturing = false
    private var captureStartTime: Date?
    
    // Audio level tracking for real-time meter
    @Published var currentAudioLevel: Float = -60.0  // Current audio level in dB (updated during recording)
    private var peakLevelDuringRecording: Float = -Float.infinity  // Track highest peak during recording
    
    // Device tracking
    private var availableInputDevices: [AudioInputDevice] = []
    private var selectedDeviceUID: String?
    
    // Callbacks
    var onPermissionDenied: (() -> Void)?
    var onCaptureError: ((Error) -> Void)?
    var onDevicesChanged: (([AudioInputDevice]) -> Void)?
    var onSilenceDetected: ((Float) -> Void)?  // Called if recording stops with only silence, passes measured dB level
    var onRecordingTooShort: (() -> Void)?  // Called if recording is below minimum duration
    var onNoTapCallbacks: (() -> Void)?  // US-302: Called if no tap callbacks received within 2 seconds
    
    // MARK: - US-603: Recording Timeout Safety Callbacks
    
    /// Called when recording approaches the maximum duration (warning at 4 minutes by default)
    var onRecordingTimeoutWarning: ((TimeInterval) -> Void)?
    
    /// Called when recording reaches the maximum duration and will auto-stop
    var onRecordingTimeoutReached: (() -> Void)?
    var onLowQualityDeviceSelected: ((AudioInputDevice) -> Void)?  // US-501: Called when only a low-quality (Bluetooth) device is available

    // MARK: - US-006: Muted/Silent Input Detection Callbacks

    /// Called when prolonged silence is detected during recording (microphone appears muted or silent)
    /// Parameters: (measuredDbLevel: Float, silenceDuration: TimeInterval, deviceName: String)
    var onProlongedSilenceDetected: ((Float, TimeInterval, String) -> Void)?
    
    // MARK: - US-601: Audio Device Hot-Plug Support
    
    /// Called when the active audio device is disconnected during recording
    /// Parameters: (disconnectedDeviceName: String, newDeviceName: String)
    var onDeviceDisconnectedDuringRecording: ((String, String) -> Void)?
    
    /// Called when an audio device change occurs (not during recording)
    /// Parameters: (oldDeviceName: String?, newDeviceName: String, reason: String)
    var onDeviceChanged: ((String?, String, String) -> Void)?
    
    /// Called when the user's preferred device is reconnected
    /// Parameter: (deviceName: String)
    var onPreferredDeviceReconnected: ((String) -> Void)?

    /// US-003: Called when a new audio device is connected, offering switch option
    /// Parameters: (newDeviceUID: String, newDeviceName: String, currentDeviceName: String)
    var onNewDeviceConnected: ((String, String, String) -> Void)?

    /// The user's preferred device UID - stored separately from selected device
    /// This allows us to detect when the preferred device is reconnected
    private var preferredDeviceUID: String?
    
    /// Key for storing preferred device UID in UserDefaults
    private static let preferredDeviceKey = "preferredAudioInputDeviceUID"
    
    /// Track the device that was active when recording started
    /// Used to detect device changes during recording
    private var recordingStartDevice: AudioInputDevice?
    
    // MARK: - US-502: Audio Device Caching
    
    /// In-memory cache of the last successfully used audio device
    /// This enables fast-path device selection on subsequent recordings (~10-20ms vs ~100-200ms)
    private var cachedSuccessfulDevice: AudioInputDevice?
    
    /// Flag to track if cache was used in the current capture session
    private var usedCachedDeviceForCapture: Bool = false
    
    // MARK: - US-604: Audio Level Calibration Properties
    
    /// Published calibration state for UI binding
    @Published var calibrationState: CalibrationState = .idle
    
    /// Timer for calibration progress updates
    private var calibrationTimer: Timer?
    
    /// Sample buffer for calibration measurement
    private var calibrationSamples: [Float] = []
    
    /// Start time of current calibration
    private var calibrationStartTime: Date?
    
    /// Dictionary of device calibrations stored per device UID
    private var deviceCalibrations: [String: DeviceCalibration] = [:]
    
    /// Callback when calibration completes successfully
    var onCalibrationCompleted: ((DeviceCalibration) -> Void)?
    
    /// Callback when calibration fails
    var onCalibrationFailed: ((String) -> Void)?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        loadSelectedDevice()
        loadPreferredDevice()  // US-601: Load preferred device UID
        loadCalibrationData()  // US-604: Load calibration data
        refreshAvailableDevices()
        setupDeviceChangeListener()
    }
    
    deinit {
        _ = stopCapturing()
        removeDeviceChangeListener()
    }
    
    // MARK: - Microphone Permission
    
    /// Check current microphone permission status
    var permissionStatus: MicrophonePermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .notDetermined
        }
    }
    
    /// Request microphone permission with completion handler
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch permissionStatus {
        case .authorized:
            completion(true)
        case .denied, .restricted:
            completion(false)
            onPermissionDenied?()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        completion(true)
                    } else {
                        self?.onPermissionDenied?()
                        completion(false)
                    }
                }
            }
        }
    }
    
    /// Show alert and open System Preferences for microphone access
    func showMicrophonePermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Microphone Access Required"
            alert.informativeText = "Voxa needs microphone access to capture your voice. Please enable microphone access in System Settings > Privacy & Security > Microphone."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn {
                self.openMicrophoneSettings()
            }
        }
    }
    
    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Audio Device Management
    
    /// Get list of available audio input devices
    var inputDevices: [AudioInputDevice] {
        return availableInputDevices
    }
    
    /// Get currently selected device (or best available if none selected)
    var currentDevice: AudioInputDevice? {
        if let selectedUID = selectedDeviceUID {
            if let device = availableInputDevices.first(where: { $0.uid == selectedUID }) {
                return device
            }
        }
        // US-501: Use smart device selection when no device is manually selected
        let (bestDevice, _) = selectBestDevice()
        return bestDevice
    }
    
    /// Select an audio input device by UID
    /// Note: This is called when user manually selects a device, which invalidates the cache (US-502)
    func selectDevice(uid: String) {
        guard availableInputDevices.contains(where: { $0.uid == uid }) else {
            print("AudioManager: Device with UID '\(uid)' not found")
            return
        }
        
        selectedDeviceUID = uid
        saveSelectedDevice()
        
        // US-601: Store as preferred device when user explicitly selects
        preferredDeviceUID = uid
        savePreferredDevice()
        
        // US-502: Invalidate cache when user manually changes device
        invalidateDeviceCache(reason: "User manually changed device selection")
        
        print("AudioManager: [US-601] Selected device '\(uid)' as preferred device")
        
        // If currently capturing, restart with new device
        if isCapturing {
            _ = stopCapturing()
            do {
                try startCapturing()
            } catch {
                print("AudioManager: Failed to restart capture with new device: \(error)")
                onCaptureError?(error)
            }
        }
    }
    
    /// Select an audio input device
    func selectDevice(_ device: AudioInputDevice) {
        selectDevice(uid: device.uid)
    }
    
    /// Refresh the list of available audio input devices
    /// US-601: Enhanced to handle device hot-plug during recording and preferred device reconnection
    func refreshAvailableDevices() {
        let previousDevices = availableInputDevices
        availableInputDevices = enumerateAudioInputDevices()
        
        let previousDeviceUIDs = Set(previousDevices.map { $0.uid })
        let currentDeviceUIDs = Set(availableInputDevices.map { $0.uid })
        let disconnectedUIDs = previousDeviceUIDs.subtracting(currentDeviceUIDs)
        let connectedUIDs = currentDeviceUIDs.subtracting(previousDeviceUIDs)
        
        // US-601: Log device changes
        if !disconnectedUIDs.isEmpty || !connectedUIDs.isEmpty {
            print("╔═══════════════════════════════════════════════════════════════╗")
            print("║          US-601: AUDIO DEVICE HOT-PLUG DETECTED               ║")
            print("╠═══════════════════════════════════════════════════════════════╣")
            for uid in disconnectedUIDs {
                if let device = previousDevices.first(where: { $0.uid == uid }) {
                    print("║ DISCONNECTED: \(device.name.prefix(46).padding(toLength: 46, withPad: " ", startingAt: 0))   ║")
                }
            }
            for uid in connectedUIDs {
                if let device = availableInputDevices.first(where: { $0.uid == uid }) {
                    print("║ CONNECTED:    \(device.name.prefix(46).padding(toLength: 46, withPad: " ", startingAt: 0))   ║")
                }
            }
            print("╚═══════════════════════════════════════════════════════════════╝")
        }
        
        // US-601: Check if device was disconnected DURING recording
        if isCapturing, let startDevice = recordingStartDevice,
           disconnectedUIDs.contains(startDevice.uid) {
            print("AudioManager: [US-601] ⚠️ DEVICE DISCONNECTED DURING RECORDING: \(startDevice.name)")
            handleDeviceDisconnectedDuringRecording(disconnectedDevice: startDevice)
        }
        
        // US-601: Check if preferred device was reconnected
        if let preferredUID = preferredDeviceUID,
           connectedUIDs.contains(preferredUID),
           let preferredDevice = availableInputDevices.first(where: { $0.uid == preferredUID }) {
            print("AudioManager: [US-601] ✓ Preferred device reconnected: \(preferredDevice.name)")
            handlePreferredDeviceReconnected(preferredDevice)
        }

        // US-003: Notify about newly connected devices (except preferred device which is handled above)
        // Only notify when not recording and there's a current device to compare against
        if !isCapturing, !connectedUIDs.isEmpty {
            let currentDeviceName = currentDevice?.name ?? "System Default"
            for uid in connectedUIDs {
                // Skip preferred device - it's handled by handlePreferredDeviceReconnected
                if uid == preferredDeviceUID { continue }
                if let newDevice = availableInputDevices.first(where: { $0.uid == uid }) {
                    print("AudioManager: [US-003] New device connected: \(newDevice.name)")
                    DispatchQueue.main.async { [weak self] in
                        self?.onNewDeviceConnected?(uid, newDevice.name, currentDeviceName)
                    }
                }
            }
        }

        // Validate selected device still exists
        if let selectedUID = selectedDeviceUID,
           !availableInputDevices.contains(where: { $0.uid == selectedUID }) {
            let previousDevice = previousDevices.first(where: { $0.uid == selectedUID })
            print("AudioManager: [US-601] Previously selected device no longer available, falling back to default")
            selectedDeviceUID = nil
            saveSelectedDevice()
            
            // US-601: Select the system default device as fallback
            let (fallbackDevice, _) = selectBestDevice()
            
            // US-601: Notify about device change (not during recording - that's handled above)
            if !isCapturing, let fallback = fallbackDevice {
                onDeviceChanged?(previousDevice?.name, fallback.name, "Selected device disconnected")
            }
        }
        
        // US-502: Invalidate cache if cached device is no longer available
        if let cachedDevice = cachedSuccessfulDevice,
           !availableInputDevices.contains(where: { $0.uid == cachedDevice.uid }) {
            invalidateDeviceCache(reason: "Cached device '\(cachedDevice.name)' disconnected")
        }
        
        // US-501: Enhanced logging with sample rate and quality info
        print("AudioManager: Found \(availableInputDevices.count) audio input device(s)")
        for device in availableInputDevices {
            let quality = calculateDeviceQuality(device)
            let isPreferred = device.uid == preferredDeviceUID ? " [PREFERRED]" : ""
            let isSelected = device.uid == selectedDeviceUID ? " [SELECTED]" : ""
            print("  - \(device.name) (default: \(device.isDefault), rate: \(device.sampleRate)Hz, quality: \(quality))\(isPreferred)\(isSelected)")
        }
        
        onDevicesChanged?(availableInputDevices)
    }
    
    // MARK: - US-601: Device Hot-Plug Handling
    
    /// Handle device disconnection during an active recording session
    /// Falls back to system default device and notifies the user
    private func handleDeviceDisconnectedDuringRecording(disconnectedDevice: AudioInputDevice) {
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║    US-601: HANDLING DEVICE DISCONNECT DURING RECORDING        ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ Disconnected: \(disconnectedDevice.name.prefix(46).padding(toLength: 46, withPad: " ", startingAt: 0))   ║")
        
        // Find the system default device as fallback
        let defaultDevice = availableInputDevices.first(where: { $0.isDefault }) ?? availableInputDevices.first
        
        if let fallback = defaultDevice {
            print("║ Falling back to: \(fallback.name.prefix(43).padding(toLength: 43, withPad: " ", startingAt: 0))   ║")
            print("╚═══════════════════════════════════════════════════════════════╝")
            
            // Update selected device to fallback
            selectedDeviceUID = fallback.uid
            saveSelectedDevice()
            recordingStartDevice = fallback
            
            // Try to switch to the new device without stopping the recording
            // This allows the recording to continue with the fallback device
            do {
                try setAudioInputDevice(fallback)
                print("AudioManager: [US-601] ✓ Successfully switched to fallback device during recording")
            } catch {
                print("AudioManager: [US-601] ⚠️ Failed to switch to fallback device: \(error)")
                // The recording will likely fail, but we'll let it continue and see what happens
            }
            
            // Notify callback on main thread
            DispatchQueue.main.async { [weak self] in
                self?.onDeviceDisconnectedDuringRecording?(disconnectedDevice.name, fallback.name)
            }
        } else {
            print("║ No fallback device available!                                 ║")
            print("╚═══════════════════════════════════════════════════════════════╝")
            // No fallback available - recording will likely fail
        }
    }
    
    /// Handle reconnection of the user's preferred device
    /// Switches back to the preferred device and notifies the user
    private func handlePreferredDeviceReconnected(_ device: AudioInputDevice) {
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║       US-601: PREFERRED DEVICE RECONNECTED                    ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ Device: \(device.name.prefix(52).padding(toLength: 52, withPad: " ", startingAt: 0))   ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        // Only auto-switch if not currently recording
        if !isCapturing {
            let previousDevice = currentDevice
            selectedDeviceUID = device.uid
            saveSelectedDevice()
            
            // Notify callback on main thread
            DispatchQueue.main.async { [weak self] in
                self?.onPreferredDeviceReconnected?(device.name)
                // Also notify about device change
                self?.onDeviceChanged?(previousDevice?.name, device.name, "Preferred device reconnected")
            }
        } else {
            print("AudioManager: [US-601] Preferred device reconnected but currently recording - will switch after recording stops")
        }
    }
    
    // MARK: - US-601: Preferred Device Persistence
    
    /// Load the preferred device UID from UserDefaults
    private func loadPreferredDevice() {
        preferredDeviceUID = UserDefaults.standard.string(forKey: Self.preferredDeviceKey)
        if let uid = preferredDeviceUID {
            print("AudioManager: [US-601] Loaded preferred device UID: \(uid)")
        }
    }
    
    /// Save the preferred device UID to UserDefaults
    private func savePreferredDevice() {
        if let uid = preferredDeviceUID {
            UserDefaults.standard.set(uid, forKey: Self.preferredDeviceKey)
            print("AudioManager: [US-601] Saved preferred device UID: \(uid)")
        } else {
            UserDefaults.standard.removeObject(forKey: Self.preferredDeviceKey)
        }
    }
    
    private func enumerateAudioInputDevices() -> [AudioInputDevice] {
        var devices: [AudioInputDevice] = []
        
        // Get the default input device ID
        var defaultDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultDeviceID
        )
        
        // Get all audio devices
        propertyAddress.mSelector = kAudioHardwarePropertyDevices
        propertySize = 0
        
        AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        )
        
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )
        
        // Filter to only input devices and get their properties
        for deviceID in deviceIDs {
            // Check if device has input streams
            var inputStreamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var streamSize: UInt32 = 0
            let streamResult = AudioObjectGetPropertyDataSize(
                deviceID,
                &inputStreamAddress,
                0,
                nil,
                &streamSize
            )
            
            // Skip if no input streams
            if streamResult != noErr || streamSize == 0 {
                continue
            }
            
            // Get device UID
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var uidRef: Unmanaged<CFString>?
            var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            AudioObjectGetPropertyData(
                deviceID,
                &uidAddress,
                0,
                nil,
                &uidSize,
                &uidRef
            )
            
            // Get device name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var nameRef: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            AudioObjectGetPropertyData(
                deviceID,
                &nameAddress,
                0,
                nil,
                &nameSize,
                &nameRef
            )
            
            if let uidCF = uidRef?.takeRetainedValue(), let nameCF = nameRef?.takeRetainedValue() {
                let uid = uidCF as String
                let name = nameCF as String
                
                // US-501: Get device sample rate for quality scoring
                let sampleRate = getDeviceSampleRate(deviceID: deviceID)
                
                let device = AudioInputDevice(
                    id: deviceID,
                    uid: uid,
                    name: name,
                    isDefault: deviceID == defaultDeviceID,
                    sampleRate: sampleRate
                )
                devices.append(device)
            }
        }
        
        return devices
    }
    
    // MARK: - US-501: Smart Device Selection
    
    /// Get the nominal sample rate for an audio device
    private func getDeviceSampleRate(deviceID: AudioDeviceID) -> Float64 {
        var sampleRateAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var sampleRate: Float64 = 0
        var sampleRateSize = UInt32(MemoryLayout<Float64>.size)
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &sampleRateAddress,
            0,
            nil,
            &sampleRateSize,
            &sampleRate
        )
        
        if status != noErr {
            print("AudioManager: [US-501] Could not get sample rate for device \(deviceID), defaulting to 0")
            return 0
        }
        
        return sampleRate
    }
    
    // MARK: - US-602: Audio Format Negotiation Methods
    
    /// US-602: Query supported audio formats for a device
    /// Returns an array of AudioFormatInfo representing all supported formats
    func querySupportedFormats(deviceID: AudioDeviceID) -> [AudioFormatInfo] {
        var formats: [AudioFormatInfo] = []
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║       US-602: QUERYING DEVICE SUPPORTED FORMATS               ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ Device ID: \(String(format: "%-50d", deviceID))   ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        // Get the input stream configuration to understand the device's input capabilities
        var streamConfigAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var streamConfigSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            deviceID,
            &streamConfigAddress,
            0,
            nil,
            &streamConfigSize
        )
        
        if status == noErr && streamConfigSize > 0 {
            // Allocate buffer for stream configuration
            let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(streamConfigSize) / MemoryLayout<AudioBufferList>.size + 1)
            defer { bufferList.deallocate() }
            
            status = AudioObjectGetPropertyData(
                deviceID,
                &streamConfigAddress,
                0,
                nil,
                &streamConfigSize,
                bufferList
            )
            
            if status == noErr {
                let numberOfBuffers = Int(bufferList.pointee.mNumberBuffers)
                print("AudioManager: [US-602] Stream configuration: \(numberOfBuffers) buffer(s)")
                
                // Log buffer details
                if numberOfBuffers > 0 {
                    let buffer = bufferList.pointee.mBuffers
                    print("AudioManager: [US-602] Buffer channels: \(buffer.mNumberChannels)")
                }
            }
        }
        
        // Get available input streams
        var streamsAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var streamsSize: UInt32 = 0
        status = AudioObjectGetPropertyDataSize(
            deviceID,
            &streamsAddress,
            0,
            nil,
            &streamsSize
        )
        
        guard status == noErr && streamsSize > 0 else {
            print("AudioManager: [US-602] No input streams found for device")
            // Fall back to nominal format
            return getFallbackFormat(deviceID: deviceID)
        }
        
        let streamCount = Int(streamsSize) / MemoryLayout<AudioStreamID>.size
        var streamIDs = [AudioStreamID](repeating: 0, count: streamCount)
        
        status = AudioObjectGetPropertyData(
            deviceID,
            &streamsAddress,
            0,
            nil,
            &streamsSize,
            &streamIDs
        )
        
        guard status == noErr else {
            print("AudioManager: [US-602] Failed to get stream IDs (status: \(status))")
            return getFallbackFormat(deviceID: deviceID)
        }
        
        print("AudioManager: [US-602] Found \(streamCount) input stream(s)")
        
        // Query each stream for its available physical formats
        for streamID in streamIDs {
            let streamFormats = queryStreamFormats(streamID: streamID)
            formats.append(contentsOf: streamFormats)
        }
        
        // Log all discovered formats
        logSupportedFormats(formats)
        
        return formats
    }
    
    /// US-602: Query available physical formats for a specific stream
    private func queryStreamFormats(streamID: AudioStreamID) -> [AudioFormatInfo] {
        var formats: [AudioFormatInfo] = []
        
        // Try to get available physical formats (most detailed)
        var physicalFormatsAddress = AudioObjectPropertyAddress(
            mSelector: kAudioStreamPropertyAvailablePhysicalFormats,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var formatListSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            streamID,
            &physicalFormatsAddress,
            0,
            nil,
            &formatListSize
        )
        
        if status == noErr && formatListSize > 0 {
            let formatCount = Int(formatListSize) / MemoryLayout<AudioStreamRangedDescription>.size
            var formatDescriptions = [AudioStreamRangedDescription](repeating: AudioStreamRangedDescription(), count: formatCount)
            
            status = AudioObjectGetPropertyData(
                streamID,
                &physicalFormatsAddress,
                0,
                nil,
                &formatListSize,
                &formatDescriptions
            )
            
            if status == noErr {
                print("AudioManager: [US-602] Stream \(streamID) has \(formatCount) physical format(s)")
                
                for rangedDesc in formatDescriptions {
                    let asbd = rangedDesc.mFormat
                    let formatInfo = AudioFormatInfo(
                        sampleRate: asbd.mSampleRate,
                        channelCount: asbd.mChannelsPerFrame,
                        bitsPerChannel: asbd.mBitsPerChannel,
                        formatID: asbd.mFormatID,
                        formatFlags: asbd.mFormatFlags
                    )
                    
                    // Handle ranged formats (min/max sample rate)
                    if rangedDesc.mSampleRateRange.mMinimum != rangedDesc.mSampleRateRange.mMaximum {
                        // Add preferred sample rates within the range
                        for preferredRate in Self.preferredSampleRates {
                            if preferredRate >= rangedDesc.mSampleRateRange.mMinimum &&
                               preferredRate <= rangedDesc.mSampleRateRange.mMaximum {
                                let rangedFormat = AudioFormatInfo(
                                    sampleRate: preferredRate,
                                    channelCount: asbd.mChannelsPerFrame,
                                    bitsPerChannel: asbd.mBitsPerChannel,
                                    formatID: asbd.mFormatID,
                                    formatFlags: asbd.mFormatFlags
                                )
                                formats.append(rangedFormat)
                            }
                        }
                    } else {
                        formats.append(formatInfo)
                    }
                }
            }
        }
        
        // If no physical formats found, try virtual formats
        if formats.isEmpty {
            var virtualFormatsAddress = AudioObjectPropertyAddress(
                mSelector: kAudioStreamPropertyAvailableVirtualFormats,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            status = AudioObjectGetPropertyDataSize(
                streamID,
                &virtualFormatsAddress,
                0,
                nil,
                &formatListSize
            )
            
            if status == noErr && formatListSize > 0 {
                let formatCount = Int(formatListSize) / MemoryLayout<AudioStreamRangedDescription>.size
                var formatDescriptions = [AudioStreamRangedDescription](repeating: AudioStreamRangedDescription(), count: formatCount)
                
                status = AudioObjectGetPropertyData(
                    streamID,
                    &virtualFormatsAddress,
                    0,
                    nil,
                    &formatListSize,
                    &formatDescriptions
                )
                
                if status == noErr {
                    print("AudioManager: [US-602] Stream \(streamID) has \(formatCount) virtual format(s)")
                    
                    for rangedDesc in formatDescriptions {
                        let asbd = rangedDesc.mFormat
                        let formatInfo = AudioFormatInfo(
                            sampleRate: asbd.mSampleRate,
                            channelCount: asbd.mChannelsPerFrame,
                            bitsPerChannel: asbd.mBitsPerChannel,
                            formatID: asbd.mFormatID,
                            formatFlags: asbd.mFormatFlags
                        )
                        formats.append(formatInfo)
                    }
                }
            }
        }
        
        return formats
    }
    
    /// US-602: Get fallback format using device's nominal sample rate
    private func getFallbackFormat(deviceID: AudioDeviceID) -> [AudioFormatInfo] {
        let sampleRate = getDeviceSampleRate(deviceID: deviceID)
        
        if sampleRate > 0 {
            print("AudioManager: [US-602] Using fallback format with nominal sample rate: \(sampleRate)Hz")
            
            // Return basic formats at the nominal sample rate
            return [
                AudioFormatInfo(
                    sampleRate: sampleRate,
                    channelCount: 1,
                    bitsPerChannel: 32,
                    formatID: kAudioFormatLinearPCM,
                    formatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
                ),
                AudioFormatInfo(
                    sampleRate: sampleRate,
                    channelCount: 2,
                    bitsPerChannel: 32,
                    formatID: kAudioFormatLinearPCM,
                    formatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
                )
            ]
        }
        
        // Absolute fallback - use 44.1kHz
        print("AudioManager: [US-602] ⚠️ Using absolute fallback format (44.1kHz)")
        return [
            AudioFormatInfo(
                sampleRate: 44100,
                channelCount: 1,
                bitsPerChannel: 32,
                formatID: kAudioFormatLinearPCM,
                formatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
            )
        ]
    }
    
    /// US-602: Log all supported formats for debugging
    private func logSupportedFormats(_ formats: [AudioFormatInfo]) {
        guard !formats.isEmpty else {
            print("AudioManager: [US-602] No supported formats to log")
            return
        }
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║       US-602: SUPPORTED AUDIO FORMATS (DETAILED)              ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ Count: \(String(format: "%-54d", formats.count))   ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        
        // Group and sort formats for better readability
        let sortedFormats = formats.sorted { $0.priorityScore > $1.priorityScore }
        
        for (index, format) in sortedFormats.enumerated() {
            let marker = format.isStandardFormat ? "★" : " "
            let desc = format.description.padding(toLength: 45, withPad: " ", startingAt: 0)
            let score = String(format: "%3d", format.priorityScore)
            print("║ \(marker) \(index + 1). \(desc) [\(score)]   ║")
        }
        
        print("╠═══════════════════════════════════════════════════════════════╣")
        
        let standardCount = formats.filter { $0.isStandardFormat }.count
        if standardCount > 0 {
            print("║ ★ = Standard format (preferred)                              ║")
            print("║ \(String(format: "%-61d", standardCount)) standard format(s) found   ║")
        } else {
            print("║ ⚠️  No standard formats found - will use best available       ║")
        }
        
        print("╚═══════════════════════════════════════════════════════════════╝")
    }
    
    /// US-602: Select the best format from available formats
    /// Prefers standard formats (44.1kHz, 48kHz stereo/mono) as per acceptance criteria
    func selectBestFormat(from formats: [AudioFormatInfo]) -> AudioFormatInfo? {
        guard !formats.isEmpty else {
            print("AudioManager: [US-602] ❌ No formats available to select from")
            return nil
        }
        
        // Sort formats by priority score (highest first)
        let sortedFormats = formats.sorted { $0.priorityScore > $1.priorityScore }
        
        // Try to find a standard format first
        if let standardFormat = sortedFormats.first(where: { $0.isStandardFormat }) {
            print("AudioManager: [US-602] ✓ Selected standard format: \(standardFormat.description) (score: \(standardFormat.priorityScore))")
            return standardFormat
        }
        
        // Fall back to the highest scored format
        if let bestFormat = sortedFormats.first {
            print("AudioManager: [US-602] ⚠️ No standard format available, using best match: \(bestFormat.description) (score: \(bestFormat.priorityScore))")
            return bestFormat
        }
        
        return nil
    }
    
    /// US-602: Check if device has any compatible format for capture
    /// Returns nil if no compatible format found, otherwise returns error message
    func checkFormatCompatibility(deviceID: AudioDeviceID) -> String? {
        let formats = querySupportedFormats(deviceID: deviceID)
        
        if formats.isEmpty {
            return "No audio formats could be queried from this device. The device may not be properly configured or may not support audio input."
        }
        
        // Check if any format is PCM (required for capture)
        let pcmFormats = formats.filter { $0.formatID == kAudioFormatLinearPCM }
        if pcmFormats.isEmpty {
            return "This device does not support PCM audio format, which is required for voice capture. Available formats: \(formats.map { $0.description }.joined(separator: ", "))"
        }
        
        // Check if any format has a reasonable sample rate
        let reasonableFormats = pcmFormats.filter { $0.sampleRate >= 8000 && $0.sampleRate <= 192000 }
        if reasonableFormats.isEmpty {
            return "This device does not support a compatible sample rate (8kHz-192kHz). Available rates: \(Set(pcmFormats.map { Int($0.sampleRate) }).sorted().map { "\($0)Hz" }.joined(separator: ", "))"
        }
        
        // All checks passed
        print("AudioManager: [US-602] ✓ Device has compatible formats for capture")
        return nil
    }
    
    /// Calculate quality score for an audio device (US-501)
    /// Higher score = better quality device
    func calculateDeviceQuality(_ device: AudioInputDevice) -> DeviceQuality {
        let nameLower = device.name.lowercased()
        
        // Check for Bluetooth/low-quality devices first (lowest priority)
        for keyword in Self.lowQualityKeywords {
            if nameLower.contains(keyword) {
                print("AudioManager: [US-501] Device '\(device.name)' matched low-quality keyword '\(keyword)' → Quality: bluetooth")
                return .bluetooth
            }
        }
        
        // Check for low sample rate (≤16kHz is deprioritized)
        if device.sampleRate > 0 && device.sampleRate <= 16000 {
            print("AudioManager: [US-501] Device '\(device.name)' has low sample rate (\(device.sampleRate)Hz) → Quality: lowSampleRate")
            return .lowSampleRate
        }
        
        // Check for USB/external professional microphones (high priority)
        for keyword in Self.usbKeywords {
            if nameLower.contains(keyword) {
                // Differentiate between professional and consumer USB mics
                let professionalKeywords = ["focusrite", "scarlett", "apollo", "universal audio", "shure", "rode"]
                for proKeyword in professionalKeywords {
                    if nameLower.contains(proKeyword) {
                        print("AudioManager: [US-501] Device '\(device.name)' matched professional keyword '\(proKeyword)' → Quality: professional")
                        return .professional
                    }
                }
                print("AudioManager: [US-501] Device '\(device.name)' matched USB keyword '\(keyword)' → Quality: usb")
                return .usb
            }
        }
        
        // Check for built-in microphones (medium priority)
        for keyword in Self.builtInKeywords {
            if nameLower.contains(keyword) {
                print("AudioManager: [US-501] Device '\(device.name)' matched built-in keyword '\(keyword)' → Quality: builtIn")
                return .builtIn
            }
        }
        
        // Default: assume built-in if no other matches (safe default for Mac)
        print("AudioManager: [US-501] Device '\(device.name)' no keyword match, assuming built-in → Quality: builtIn")
        return .builtIn
    }
    
    /// Check if a device is considered low-quality (Bluetooth/low sample rate)
    func isLowQualityDevice(_ device: AudioInputDevice) -> Bool {
        let quality = calculateDeviceQuality(device)
        return quality == .bluetooth || quality == .lowSampleRate
    }
    
    /// Select the best available audio input device automatically (US-501)
    /// Returns the selected device and whether it's the only option (for warning toast)
    @discardableResult
    func selectBestDevice() -> (device: AudioInputDevice?, isOnlyOption: Bool) {
        guard !availableInputDevices.isEmpty else {
            print("AudioManager: [US-501] No input devices available")
            return (nil, false)
        }
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║        US-501: SMART AUDIO DEVICE SELECTION                   ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        
        // Score all devices and sort by quality (highest first)
        let scoredDevices = availableInputDevices.map { device -> (device: AudioInputDevice, quality: DeviceQuality) in
            let quality = calculateDeviceQuality(device)
            return (device, quality)
        }.sorted { $0.quality > $1.quality }
        
        // Log all devices with their scores
        print("║ Available devices (sorted by quality):                        ║")
        for (index, scored) in scoredDevices.enumerated() {
            let marker = index == 0 ? "→" : " "
            let qualityStr = String(describing: scored.quality).padding(toLength: 12, withPad: " ", startingAt: 0)
            let nameStr = scored.device.name.prefix(35).padding(toLength: 35, withPad: " ", startingAt: 0)
            print("║ \(marker) [\(qualityStr)] \(nameStr)   ║")
        }
        
        // Select the best device
        guard let bestScored = scoredDevices.first else {
            print("║ Status: No suitable device found                              ║")
            print("╚═══════════════════════════════════════════════════════════════╝")
            return (nil, false)
        }
        
        let bestDevice = bestScored.device
        let bestQuality = bestScored.quality
        
        // Check if this is the only option (all devices are low quality)
        let nonBluetoothDevices = scoredDevices.filter { $0.quality > .bluetooth }
        let isOnlyOption = nonBluetoothDevices.isEmpty
        
        if isOnlyOption {
            print("║                                                               ║")
            print("║ ⚠️  WARNING: Only low-quality (Bluetooth) device available     ║")
            print("║    Recording will proceed but quality may be degraded.        ║")
        }
        
        // Select the device
        selectedDeviceUID = bestDevice.uid
        saveSelectedDevice()
        
        print("║                                                               ║")
        print("║ Selected: \(bestDevice.name.prefix(48).padding(toLength: 48, withPad: " ", startingAt: 0))   ║")
        print("║ Quality:  \(String(describing: bestQuality).padding(toLength: 48, withPad: " ", startingAt: 0))   ║")
        print("║ Sample Rate: \(String(format: "%.0f Hz", bestDevice.sampleRate).padding(toLength: 45, withPad: " ", startingAt: 0))   ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        // Fire callback if only low-quality device is available
        if isOnlyOption && bestQuality == .bluetooth {
            onLowQualityDeviceSelected?(bestDevice)
        }
        
        return (bestDevice, isOnlyOption)
    }
    
    // MARK: - US-502: Device Caching for Fast Recording Start
    
    /// Invalidate the cached device (US-502)
    /// Called when:
    /// - User manually changes device in Settings
    /// - Cached device is disconnected
    private func invalidateDeviceCache(reason: String) {
        if let cachedDevice = cachedSuccessfulDevice {
            print("╔═══════════════════════════════════════════════════════════════╗")
            print("║           US-502: DEVICE CACHE INVALIDATED                    ║")
            print("╠═══════════════════════════════════════════════════════════════╣")
            print("║ Previous cached device: \(cachedDevice.name.prefix(36).padding(toLength: 36, withPad: " ", startingAt: 0))   ║")
            print("║ Reason: \(reason.prefix(51).padding(toLength: 51, withPad: " ", startingAt: 0))   ║")
            print("╚═══════════════════════════════════════════════════════════════╝")
            cachedSuccessfulDevice = nil
        }
    }
    
    /// Cache a device after successful recording (US-502)
    /// Called when recording completes successfully
    private func cacheSuccessfulDevice(_ device: AudioInputDevice) {
        cachedSuccessfulDevice = device
        print("AudioManager: [US-502] Cached successful device: '\(device.name)'")
    }
    
    /// Try to get cached device for fast-path selection (US-502)
    /// Returns the cached device if it's still available and valid
    private func getCachedDeviceIfAvailable() -> AudioInputDevice? {
        guard let cachedDevice = cachedSuccessfulDevice else {
            print("AudioManager: [US-502] No cached device available (first recording or cache invalidated)")
            return nil
        }
        
        // Verify the cached device is still connected
        guard availableInputDevices.contains(where: { $0.uid == cachedDevice.uid }) else {
            print("AudioManager: [US-502] Cached device '\(cachedDevice.name)' no longer available")
            cachedSuccessfulDevice = nil
            return nil
        }
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║           US-502: FAST-PATH DEVICE SELECTION                  ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ Using cached device: \(cachedDevice.name.prefix(39).padding(toLength: 39, withPad: " ", startingAt: 0))   ║")
        print("║ Skipping full device enumeration (~10-20ms vs ~100-200ms)     ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        return cachedDevice
    }
    
    /// Get the device for the current recording session (US-502)
    /// Uses cached device if available for fast-path, otherwise falls back to standard selection
    private func getDeviceForRecording() -> AudioInputDevice? {
        // Check if user has manually selected a device
        if let selectedUID = selectedDeviceUID,
           let manualDevice = availableInputDevices.first(where: { $0.uid == selectedUID }) {
            print("AudioManager: [US-502] Using user-selected device: '\(manualDevice.name)'")
            return manualDevice
        }
        
        // US-502: Try cached device first for fast-path
        if let cachedDevice = getCachedDeviceIfAvailable() {
            usedCachedDeviceForCapture = true
            return cachedDevice
        }
        
        // Fall back to smart device selection (full enumeration)
        usedCachedDeviceForCapture = false
        let (bestDevice, _) = selectBestDevice()
        return bestDevice
    }
    
    // MARK: - Device Persistence
    
    private func loadSelectedDevice() {
        selectedDeviceUID = UserDefaults.standard.string(forKey: Constants.selectedDeviceKey)
        if let uid = selectedDeviceUID {
            print("AudioManager: Loaded saved device UID: \(uid)")
        }
    }
    
    private func saveSelectedDevice() {
        if let uid = selectedDeviceUID {
            UserDefaults.standard.set(uid, forKey: Constants.selectedDeviceKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Constants.selectedDeviceKey)
        }
    }
    
    // MARK: - Device Change Listener
    
    private var deviceChangeListenerProc: AudioObjectPropertyListenerProc?
    
    private func setupDeviceChangeListener() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Use a static function to handle the callback
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            nil
        ) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.refreshAvailableDevices()
            }
        }
        
        if status != noErr {
            print("AudioManager: Failed to set up device change listener: \(status)")
        }
    }
    
    private func removeDeviceChangeListener() {
        // Note: We can't easily remove the block listener added in setupDeviceChangeListener,
        // but it will be cleaned up when the AudioManager is deallocated.
        // This is acceptable for this use case since AudioManager typically lives
        // for the entire app lifecycle.
    }
    
    // MARK: - Audio Capture
    
    /// Start capturing audio from the microphone
    func startCapturing() throws {
        guard !isCapturing else {
            print("AudioManager: Already capturing")
            return
        }
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║            AUDIO PIPELINE STAGE 1: CAPTURE START              ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        // Check permission first
        guard permissionStatus == .authorized else {
            print("AudioManager: [STAGE 1] ✗ Microphone permission denied")
            showMicrophonePermissionAlert()
            throw AudioCaptureError.microphonePermissionDenied
        }
        print("AudioManager: [STAGE 1] ✓ Microphone permission authorized")
        
        // Clear previous buffers (US-301: Clear unified masterBuffer)
        // US-303: Log buffer clear event
        bufferLock.lock()
        let previousCount = masterBuffer.count
        masterBuffer.removeAll()
        bufferLock.unlock()
        tapCallbackCount = 0
        samplesAddedThisCallback = 0
        emptyCallbackCount = 0  // US-302: Reset empty callback counter
        zeroDataCallbackCount = 0  // US-302: Reset zero data callback counter
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║         US-303: BUFFER INTEGRITY - MASTER BUFFER CLEARED      ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ Previous sample count:   \(String(format: "%10d", previousCount)) samples                      ║")
        print("║ Current sample count:    \(String(format: "%10d", 0)) samples                      ║")
        print("║ Status:                  Buffer ready for new recording        ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        // Stop any previous engine run before reconfiguring
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        // Reset the audio engine to clear any cached state from previous recordings
        // This is important to ensure we get fresh format readings after device changes
        audioEngine.reset()
        print("AudioManager: [STAGE 1] ✓ Audio engine reset")
        
        // IMPORTANT: First access the inputNode to initialize the audio graph
        // This is required before we can set a custom input device
        let inputNode = audioEngine.inputNode
        
        // Prepare the audio engine to ensure the audio unit is available
        audioEngine.prepare()
        print("AudioManager: [STAGE 1] ✓ Audio engine prepared")
        
        // US-503: Check if any input devices are available BEFORE attempting to set one
        // This ensures a clear error message rather than silent failure
        guard !availableInputDevices.isEmpty else {
            print("╔═══════════════════════════════════════════════════════════════╗")
            print("║     ✗ US-503: NO INPUT DEVICES AVAILABLE                       ║")
            print("╠═══════════════════════════════════════════════════════════════╣")
            print("║ Error: No audio input devices found on this system.           ║")
            print("║ Please connect a microphone and try again.                    ║")
            print("╚═══════════════════════════════════════════════════════════════╝")
            throw AudioCaptureError.noInputDevicesAvailable
        }
        
        // US-502: Use getDeviceForRecording() for cached fast-path or smart selection
        // This will try cached device first (~10-20ms) before falling back to full enumeration (~100-200ms)
        var selectedDevice: AudioInputDevice?
        if let device = getDeviceForRecording() {
            selectedDevice = device
            do {
                try setAudioInputDevice(device)
                print("AudioManager: [STAGE 1] ✓ Input device set: \(device.name) (cached: \(usedCachedDeviceForCapture))")
            } catch {
                print("AudioManager: [STAGE 1] ⚠️ Failed to set input device: \(error.localizedDescription)")
                print("AudioManager: [STAGE 1] ⚠️ Continuing with default input device")
                // US-502: Invalidate cache if device setting failed
                if usedCachedDeviceForCapture {
                    invalidateDeviceCache(reason: "Failed to set cached device")
                }
            }
        }
        
        // US-602: Query and log supported formats for the selected device
        // This improves compatibility by verifying device supports audio capture
        if let device = selectedDevice {
            // Check format compatibility before attempting capture
            if let compatibilityError = checkFormatCompatibility(deviceID: device.id) {
                print("╔═══════════════════════════════════════════════════════════════╗")
                print("║     ✗ US-602: NO COMPATIBLE AUDIO FORMAT FOUND                ║")
                print("╠═══════════════════════════════════════════════════════════════╣")
                print("║ Device: \(device.name.prefix(52).padding(toLength: 52, withPad: " ", startingAt: 0))   ║")
                print("║ Error: \(compatibilityError.prefix(53).padding(toLength: 53, withPad: " ", startingAt: 0))   ║")
                print("║                                                               ║")
                print("║ Suggestion: Try selecting a different audio device or check   ║")
                print("║ your audio settings in System Settings > Sound > Input.       ║")
                print("╚═══════════════════════════════════════════════════════════════╝")
                throw AudioCaptureError.noCompatibleFormat(compatibilityError)
            }
            
            // Query and select the best format for this device
            let supportedFormats = querySupportedFormats(deviceID: device.id)
            if let bestFormat = selectBestFormat(from: supportedFormats) {
                print("AudioManager: [US-602] ✓ Best format selected: \(bestFormat.description)")
                print("AudioManager: [US-602]   Sample rate: \(bestFormat.sampleRate)Hz, Channels: \(bestFormat.channelCount)")
            }
        }
        
        // Get the input format AFTER setting the device to ensure we get the correct format
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // US-503: Validate the input format with clear error message
        // Invalid format (0 sample rate or 0 channels) indicates a device or configuration issue
        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            print("╔═══════════════════════════════════════════════════════════════╗")
            print("║     ✗ US-503: INVALID AUDIO INPUT FORMAT                       ║")
            print("╠═══════════════════════════════════════════════════════════════╣")
            print("║ Sample rate: \(String(format: "%10.0f", inputFormat.sampleRate)) Hz (expected: > 0)              ║")
            print("║ Channels:    \(String(format: "%10d", inputFormat.channelCount)) (expected: > 0)                    ║")
            print("║                                                               ║")
            print("║ This may indicate:                                            ║")
            print("║   - Audio device is not configured correctly                  ║")
            print("║   - Device was disconnected during initialization             ║")
            print("║   - System audio settings need to be checked                  ║")
            print("╚═══════════════════════════════════════════════════════════════╝")
            throw AudioCaptureError.invalidInputFormat(sampleRate: inputFormat.sampleRate, channels: inputFormat.channelCount)
        }
        
        print("AudioManager: [STAGE 1] Input format - Sample rate: \(inputFormat.sampleRate), Channels: \(inputFormat.channelCount)")
        
        // Create a mono format at the device's sample rate for the tap
        // This handles devices that report many channels (like virtual audio devices)
        // We only need mono audio for transcription
        guard let monoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: inputFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            print("AudioManager: [STAGE 1] ✗ Failed to create mono format")
            throw AudioCaptureError.formatCreationFailed
        }
        print("AudioManager: [STAGE 1] ✓ Mono format created at \(monoFormat.sampleRate)Hz")

        // Note: Skipping mixer sink connection for better compatibility with virtual devices
        // The tap alone should be sufficient to receive audio data
        print("AudioManager: [STAGE 1] ✓ Skipping mixer sink (direct tap mode for virtual device compatibility)")
        
        // Create format for Whisper (16kHz mono)
        guard let whisperFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Constants.targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            print("AudioManager: [STAGE 1] ✗ Failed to create Whisper format")
            throw AudioCaptureError.formatCreationFailed
        }
        print("AudioManager: [STAGE 1] ✓ Whisper format created (16kHz mono Float32)")
        
        // Create converter if sample rates differ (from mono format to whisper format)
        let converter: AVAudioConverter?
        if monoFormat.sampleRate != Constants.targetSampleRate {
            converter = AVAudioConverter(from: monoFormat, to: whisperFormat)
            print("AudioManager: [STAGE 1] ✓ Audio converter created: \(monoFormat.sampleRate)Hz → \(Constants.targetSampleRate)Hz")
        } else {
            converter = nil
            print("AudioManager: [STAGE 1] ✓ No conversion needed (already 16kHz mono)")
        }
        
        // Reset audio level tracking
        peakLevelDuringRecording = -Float.infinity
        currentAudioLevel = -60.0
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║            AUDIO PIPELINE STAGE 2: TAP INSTALLED              ║")
        print("║         US-301: Unified masterBuffer Architecture             ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        // Install tap on input node - US-301: All audio goes to single masterBuffer
        // Use mono format to ensure compatibility with multi-channel virtual devices
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: monoFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            self.tapCallbackCount += 1
            
            // US-301: Convert samples and append to masterBuffer
            var samplesToAdd: [Float] = []
            
            if let converter = converter {
                // Convert to target format (16kHz mono)
                // Use buffer.format.sampleRate since monoFormat is not accessible in closure
                let frameCapacity = AVAudioFrameCount(
                    Double(buffer.frameLength) * Constants.targetSampleRate / buffer.format.sampleRate
                )
                
                guard let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: whisperFormat,
                    frameCapacity: frameCapacity
                ) else {
                    print("AudioManager: [STAGE 2] ⚠️ Failed to create converted buffer")
                    return
                }
                
                var error: NSError?
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                
                converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
                
                if let error = error {
                    print("AudioManager: [STAGE 2] ⚠️ Audio conversion error: \(error.localizedDescription)")
                    return
                }
                
                // Extract Float samples from converted buffer
                if let channelData = convertedBuffer.floatChannelData {
                    let frameLength = Int(convertedBuffer.frameLength)
                    samplesToAdd = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
                }
                
                // US-302: Log first callback with FULL details (format, sample count)
                if self.tapCallbackCount == 1 {
                    let format = convertedBuffer.format
                    let inputBufferFrames = buffer.frameLength
                    let outputFrames = convertedBuffer.frameLength
                    print("╔═══════════════════════════════════════════════════════════════╗")
                    print("║           US-302: FIRST TAP CALLBACK - FULL DETAILS           ║")
                    print("╠═══════════════════════════════════════════════════════════════╣")
                    print("║ Input buffer (mono):                                          ║")
                    print("║   - Frame count: \(String(format: "%10d", inputBufferFrames)) frames                         ║")
                    print("║   - Sample rate: \(String(format: "%10.0f", buffer.format.sampleRate)) Hz                            ║")
                    print("║   - Channels:    \(String(format: "%10d", buffer.format.channelCount))                                ║")
                    print("║ Converted buffer:                                             ║")
                    print("║   - Frame count: \(String(format: "%10d", outputFrames)) frames                         ║")
                    print("║   - Sample rate: \(String(format: "%10.0f", format.sampleRate)) Hz (target: \(Constants.targetSampleRate))         ║")
                    print("║   - Channels:    \(String(format: "%10d", format.channelCount)) (expected: 1)                     ║")
                    print("║   - Format:      \(format.commonFormat == .pcmFormatFloat32 ? "   Float32 ✓" : "     Other")                                ║")
                    print("║ Sample count:    \(String(format: "%10d", samplesToAdd.count)) samples extracted                ║")
                    print("║ US-301: Level meter AND transcription use SAME masterBuffer   ║")
                    print("╚═══════════════════════════════════════════════════════════════╝")
                }
            } else {
                // No conversion needed - already at target format
                if let channelData = buffer.floatChannelData {
                    let frameLength = Int(buffer.frameLength)
                    samplesToAdd = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
                }
                
                // US-302: Log first callback with FULL details (no conversion case)
                if self.tapCallbackCount == 1 {
                    let bufferFrames = buffer.frameLength
                    let format = buffer.format
                    print("╔═══════════════════════════════════════════════════════════════╗")
                    print("║           US-302: FIRST TAP CALLBACK - FULL DETAILS           ║")
                    print("╠═══════════════════════════════════════════════════════════════╣")
                    print("║ Buffer (no conversion needed):                                ║")
                    print("║   - Frame count: \(String(format: "%10d", bufferFrames)) frames                         ║")
                    print("║   - Sample rate: \(String(format: "%10.0f", format.sampleRate)) Hz                            ║")
                    print("║   - Channels:    \(String(format: "%10d", format.channelCount))                                ║")
                    print("║   - Format:      \(format.commonFormat == .pcmFormatFloat32 ? "   Float32 ✓" : "     Other")                                ║")
                    print("║ Sample count:    \(String(format: "%10d", samplesToAdd.count)) samples extracted                ║")
                    print("║ US-301: Level meter AND transcription use SAME masterBuffer   ║")
                    print("╚═══════════════════════════════════════════════════════════════╝")
                }
            }
            
            // US-302: Log if callback receives empty/zero data
            guard !samplesToAdd.isEmpty else {
                self.emptyCallbackCount += 1
                // Log first empty callback immediately, then every 10th
                if self.emptyCallbackCount == 1 || self.emptyCallbackCount % 10 == 0 {
                    print("AudioManager: [US-302] ⚠️ EMPTY DATA: Tap callback #\(self.tapCallbackCount) received empty buffer (empty count: \(self.emptyCallbackCount))")
                }
                return
            }
            
            // US-302: Check if ALL samples are zero (problematic data)
            let zeroThreshold: Float = 1e-7
            let allZero = samplesToAdd.allSatisfy { abs($0) < zeroThreshold }
            if allZero {
                self.zeroDataCallbackCount += 1
                // Log first zero-data callback immediately, then every 10th
                if self.zeroDataCallbackCount == 1 || self.zeroDataCallbackCount % 10 == 0 {
                    print("AudioManager: [US-302] ⚠️ ZERO DATA: Tap callback #\(self.tapCallbackCount) has \(samplesToAdd.count) samples that are all near-zero (zero-data count: \(self.zeroDataCallbackCount))")
                }
            }
            
            // US-301: Calculate level from samples JUST ADDED to masterBuffer (same data!)
            let level = self.calculatePeakLevelFromSamples(samplesToAdd)
            
            // US-301: Append samples to unified masterBuffer
            self.bufferLock.lock()
            let countBefore = self.masterBuffer.count
            self.masterBuffer.append(contentsOf: samplesToAdd)
            let countAfter = self.masterBuffer.count
            self.bufferLock.unlock()
            
            self.samplesAddedThisCallback = samplesToAdd.count
            
            // Update audio level on main thread (calculated from SAME samples added to buffer)
            DispatchQueue.main.async {
                self.currentAudioLevel = level
                if level > self.peakLevelDuringRecording {
                    self.peakLevelDuringRecording = level
                }
            }
            
            // US-303: Log every append with sample count and running total
            // Log every callback for the first 5, then every 10th to avoid spam while maintaining traceability
            if self.tapCallbackCount <= 5 || self.tapCallbackCount % 10 == 0 {
                print("AudioManager: [US-303] APPEND #\(self.tapCallbackCount): +\(samplesToAdd.count) samples | masterBuffer: \(countBefore) → \(countAfter) total | level: \(String(format: "%.1f", level))dB")
            }
        }
        
        // Start the audio engine
        try audioEngine.start()
        
        isCapturing = true
        captureStartTime = Date()
        
        // US-601: Track the device we started recording with
        recordingStartDevice = currentDevice
        if let device = recordingStartDevice {
            print("AudioManager: [US-601] Recording started with device: \(device.name)")
        }
        
        // US-302: Start timer to alert if no tap callbacks received within 2 seconds
        startNoCallbackAlertTimer()
        
        // US-603: Start recording timeout timers (warning at 4 min, auto-stop at 5 min)
        startRecordingTimeoutTimers()

        // US-006: Start silence monitor timer for muted/silent input detection
        startSilenceMonitorTimer()

        print("AudioManager: [STAGE 1] ✓ Audio engine started - capturing audio")
        print("AudioManager: [US-302] 2-second no-callback alert timer started")
        print("AudioManager: [US-603] Recording timeout timers started (warning: \(Self.warningDuration)s, max: \(Self.maxRecordingDuration)s)")
        print("AudioManager: [US-006] Silence monitor started (warn after: \(Self.silenceWarningDuration)s)")
    }
    
    /// Stop capturing audio and return the result
    func stopCapturing() -> AudioCaptureResult? {
        guard isCapturing else {
            return nil
        }
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║            AUDIO PIPELINE STAGE 3: CAPTURE STOP               ║")
        print("║         US-301: Unified masterBuffer Architecture             ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        // US-302: Stop the no-callback alert timer
        stopNoCallbackAlertTimer()

        // US-603: Stop the recording timeout timers
        stopRecordingTimeoutTimers()

        // US-006: Stop the silence monitor timer
        stopSilenceMonitorTimer()

        // Stop engine and remove tap
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        print("AudioManager: [STAGE 3] ✓ Audio engine stopped, tap removed")
        
        isCapturing = false
        
        // US-601: Clear recording start device
        let previousRecordingDevice = recordingStartDevice
        recordingStartDevice = nil
        
        // US-601: If preferred device was reconnected during recording, switch to it now
        if let preferredUID = preferredDeviceUID,
           preferredUID != selectedDeviceUID,
           availableInputDevices.contains(where: { $0.uid == preferredUID }) {
            print("AudioManager: [US-601] Switching to preferred device after recording completed")
            if let preferredDevice = availableInputDevices.first(where: { $0.uid == preferredUID }) {
                let oldDevice = currentDevice
                selectedDeviceUID = preferredUID
                saveSelectedDevice()
                DispatchQueue.main.async { [weak self] in
                    self?.onDeviceChanged?(oldDevice?.name, preferredDevice.name, "Switched to preferred device after recording")
                }
            }
        }
        _ = previousRecordingDevice  // Silence unused warning
        
        // Calculate duration
        let duration = captureStartTime.map { Date().timeIntervalSince($0) } ?? 0
        captureStartTime = nil
        
        // US-302: Log tap callback statistics
        logTapCallbackStats(duration: duration)
        
        // US-301: Log sample counts - masterBuffer is the ONLY audio storage
        bufferLock.lock()
        let sampleCount = masterBuffer.count
        bufferLock.unlock()
        print("AudioManager: [STAGE 3] Recording duration: \(String(format: "%.2f", duration))s, masterBuffer samples: \(sampleCount), tap callbacks: \(tapCallbackCount)")
        
        // US-303: Compare final buffer count to expected count (duration * 16000)
        let expectedSampleCount = Int(duration * Constants.targetSampleRate)
        let sampleCountDifference = sampleCount - expectedSampleCount
        let differencePercentage = expectedSampleCount > 0 ? (Float(abs(sampleCountDifference)) / Float(expectedSampleCount)) * 100.0 : 0.0
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║     US-303: BUFFER INTEGRITY - EXPECTED VS ACTUAL COUNT       ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ Duration:                \(String(format: "%10.2f", duration)) seconds                  ║")
        print("║ Target sample rate:      \(String(format: "%10.0f", Constants.targetSampleRate)) Hz                       ║")
        print("║ Expected samples:        \(String(format: "%10d", expectedSampleCount)) (duration × rate)         ║")
        print("║ Actual samples:          \(String(format: "%10d", sampleCount))                           ║")
        print("║ Difference:              \(String(format: "%+10d", sampleCountDifference)) samples                  ║")
        print("║ Variance:                \(String(format: "%10.1f", differencePercentage))%                            ║")
        if differencePercentage > 10.0 {
            print("║ Status:                  ⚠️ MISMATCH > 10% - possible data loss ║")
        } else if sampleCount == 0 {
            print("║ Status:                  ❌ NO SAMPLES - audio capture failed   ║")
        } else {
            print("║ Status:                  ✓ Within acceptable variance           ║")
        }
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        // Check minimum recording duration
        if duration < Constants.minimumRecordingDuration {
            print("AudioManager: [STAGE 3] ✗ Recording too short (\(String(format: "%.2f", duration))s < \(Constants.minimumRecordingDuration)s minimum)")
            bufferLock.lock()
            masterBuffer.removeAll()
            bufferLock.unlock()
            currentAudioLevel = -60.0
            onRecordingTooShort?()
            return nil
        }
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║            AUDIO PIPELINE STAGE 4: BUFFER PROCESSING          ║")
        print("║   US-301: getAudioBuffer() returns masterBuffer directly      ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        // US-301: Get audio directly from masterBuffer (no combining needed!)
        let (audioData, stats) = getMasterBufferDataWithStats()
        print("AudioManager: [STAGE 4] ✓ masterBuffer converted to \(audioData.count) bytes (\(stats.sampleCount) samples)")
        
        // Log detailed audio buffer statistics
        logAudioBufferStatistics(stats: stats, duration: duration)
        
        // Check for silence - must BOTH be below threshold AND have >95% near-zero samples
        // This prevents rejecting audio that has brief speech surrounded by silence
        let isPeakBelowThreshold = stats.peakLevel < Constants.silenceThresholdDB
        let isMostlyZeroSamples = stats.nearZeroPercentage > 95.0
        let wasSilent = isPeakBelowThreshold && isMostlyZeroSamples
        
        if wasSilent {
            print("AudioManager: [STAGE 4] ⚠️ WARNING - Audio appears silent:")
            print("AudioManager: [STAGE 4]   - Peak level: \(String(format: "%.1f", stats.peakLevel))dB (threshold: \(Constants.silenceThresholdDB)dB)")
            print("AudioManager: [STAGE 4]   - Near-zero samples: \(String(format: "%.1f", stats.nearZeroPercentage))% (threshold: 95%)")
            onSilenceDetected?(stats.peakLevel)
        } else if isPeakBelowThreshold {
            // Peak is low but there's some audio content
            print("AudioManager: [STAGE 4] ⚠️ Note: Audio level is quiet (\(String(format: "%.1f", stats.peakLevel))dB) but contains \(String(format: "%.1f", 100 - stats.nearZeroPercentage))% non-zero samples - proceeding with transcription")
        } else {
            print("AudioManager: [STAGE 4] ✓ Audio level check passed (peak \(String(format: "%.1f", stats.peakLevel))dB)")
        }
        
        print("AudioManager: [STAGE 4] ✓ Audio ready for transcription - Duration: \(String(format: "%.2f", duration))s, Data size: \(audioData.count) bytes, Peak: \(String(format: "%.1f", stats.peakLevel))dB")
        
        // US-502: Cache the device used for this successful recording
        // This enables fast-path device selection on the next recording
        if !wasSilent, let device = currentDevice {
            cacheSuccessfulDevice(device)
        }
        
        // US-301 & US-303: Clear masterBuffer after use and log the event
        bufferLock.lock()
        let clearedSampleCount = masterBuffer.count
        masterBuffer.removeAll()
        bufferLock.unlock()
        currentAudioLevel = -60.0
        print("AudioManager: [US-303] masterBuffer cleared after read (was \(clearedSampleCount) samples, now 0)")
        
        return AudioCaptureResult(
            audioData: audioData,
            duration: duration,
            sampleRate: Constants.targetSampleRate,
            peakLevel: stats.peakLevel,
            sampleCount: stats.sampleCount,
            wasSilent: wasSilent,
            measuredDbLevel: stats.peakLevel
        )
    }
    
    /// Get the last recorded audio statistics (for debug display)
    var lastRecordingStats: AudioBufferStats? {
        didSet {
            // Can be used to display stats after recording stops
        }
    }
    
    /// Log detailed audio buffer statistics
    private func logAudioBufferStatistics(stats: AudioBufferStats, duration: TimeInterval) {
        // Determine silence status using the improved criteria
        let isPeakBelowThreshold = stats.peakLevel < Constants.silenceThresholdDB
        let isMostlyZeroSamples = stats.nearZeroPercentage > 95.0
        let isSilent = isPeakBelowThreshold && isMostlyZeroSamples
        
        print("AudioManager: [STAGE 4] ╔═══════════════════════════════════════════════════════════════╗")
        print("AudioManager: [STAGE 4] ║              AUDIO BUFFER STATISTICS (COMBINED)               ║")
        print("AudioManager: [STAGE 4] ╠═══════════════════════════════════════════════════════════════╣")
        print("AudioManager: [STAGE 4] ║ Sample Count:    \(String(format: "%10d", stats.sampleCount)) samples                        ║")
        print("AudioManager: [STAGE 4] ║ Duration:        \(String(format: "%10.2f", duration)) seconds                        ║")
        print("AudioManager: [STAGE 4] ║ Sample Rate:     \(String(format: "%10.0f", Constants.targetSampleRate)) Hz                            ║")
        print("AudioManager: [STAGE 4] ║ Peak Level:      \(String(format: "%10.1f", stats.peakLevel)) dB                             ║")
        print("AudioManager: [STAGE 4] ║ RMS Level:       \(String(format: "%10.1f", stats.rmsLevel)) dB                             ║")
        print("AudioManager: [STAGE 4] ║ Min Sample:      \(String(format: "%10.4f", stats.minSample))                                ║")
        print("AudioManager: [STAGE 4] ║ Max Sample:      \(String(format: "%10.4f", stats.maxSample))                                ║")
        print("AudioManager: [STAGE 4] ║ Near-Zero:       \(String(format: "%10.1f", stats.nearZeroPercentage))%                              ║")
        print("AudioManager: [STAGE 4] ║ Silent:          \(isSilent ? "       YES ⚠️" : "        NO ✓")                                ║")
        print("AudioManager: [STAGE 4] ╚═══════════════════════════════════════════════════════════════╝")
        
        // Store for potential debug display
        lastRecordingStats = stats
    }
    
    /// Cancel capturing and discard audio
    func cancelCapturing() {
        guard isCapturing else { return }

        // US-302: Stop the no-callback alert timer
        stopNoCallbackAlertTimer()

        // US-603: Stop the recording timeout timers
        stopRecordingTimeoutTimers()

        // US-006: Stop the silence monitor timer
        stopSilenceMonitorTimer()

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        
        isCapturing = false
        captureStartTime = nil
        
        // US-601: Clear recording start device
        recordingStartDevice = nil
        
        // US-301 & US-303: Clear unified masterBuffer and log the event
        bufferLock.lock()
        let discardedSampleCount = masterBuffer.count
        masterBuffer.removeAll()
        bufferLock.unlock()
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║      US-303: BUFFER INTEGRITY - CAPTURE CANCELLED             ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ Discarded samples:       \(String(format: "%10d", discardedSampleCount)) samples                      ║")
        print("║ Tap callbacks received:  \(String(format: "%10d", tapCallbackCount))                           ║")
        print("║ Status:                  Buffer cleared (recording discarded) ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
    }
    
    /// Check if currently capturing
    var isCurrentlyCapturing: Bool {
        return isCapturing
    }
    
    // MARK: - US-302: Audio Tap Verification
    
    /// US-302: Start timer to alert if no tap callbacks received within 2 seconds of starting
    private func startNoCallbackAlertTimer() {
        // Invalidate any existing timer
        noCallbackAlertTimer?.invalidate()
        
        // Start a new timer that fires after 2 seconds
        noCallbackAlertTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            if self.tapCallbackCount == 0 && self.isCapturing {
                print("╔═══════════════════════════════════════════════════════════════╗")
                print("║     ⚠️ US-302 ALERT: NO TAP CALLBACKS RECEIVED IN 2 SECONDS    ║")
                print("╠═══════════════════════════════════════════════════════════════╣")
                print("║ The audio tap callback has not been called since recording    ║")
                print("║ started. This indicates a problem with audio capture.         ║")
                print("║                                                               ║")
                print("║ Possible causes:                                              ║")
                print("║   - Audio device not providing data                           ║")
                print("║   - Audio engine not running properly                         ║")
                print("║   - System audio permission issue                             ║")
                print("║   - Audio hardware disconnected                               ║")
                print("╚═══════════════════════════════════════════════════════════════╝")
                
                self.onNoTapCallbacks?()
            }
        }
    }
    
    /// US-302: Stop the no-callback alert timer
    private func stopNoCallbackAlertTimer() {
        noCallbackAlertTimer?.invalidate()
        noCallbackAlertTimer = nil
    }
    
    // MARK: - US-603: Recording Timeout Timer Methods
    
    /// US-603: Start timers for recording timeout warning and auto-stop
    private func startRecordingTimeoutTimers() {
        // Invalidate any existing timers
        stopRecordingTimeoutTimers()
        hasShownTimeoutWarning = false
        
        let maxDuration = Self.maxRecordingDuration
        let warningDuration = Self.warningDuration
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║       US-603: RECORDING TIMEOUT TIMERS STARTED                ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ Warning at:              \(String(format: "%10.0f", warningDuration)) seconds (\(String(format: "%.1f", warningDuration / 60.0)) min)       ║")
        print("║ Auto-stop at:            \(String(format: "%10.0f", maxDuration)) seconds (\(String(format: "%.1f", maxDuration / 60.0)) min)       ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        // Start warning timer (fires at 4 minutes by default)
        if warningDuration > 0 {
            recordingTimeoutWarningTimer = Timer.scheduledTimer(withTimeInterval: warningDuration, repeats: false) { [weak self] _ in
                guard let self = self, self.isCapturing, !self.hasShownTimeoutWarning else { return }
                
                self.hasShownTimeoutWarning = true
                let remaining = Self.maxRecordingDuration - (self.captureStartTime.map { Date().timeIntervalSince($0) } ?? 0)
                
                print("╔═══════════════════════════════════════════════════════════════╗")
                print("║     ⚠️ US-603: RECORDING TIMEOUT WARNING                        ║")
                print("╠═══════════════════════════════════════════════════════════════╣")
                print("║ Recording has reached \(String(format: "%.0f", warningDuration / 60.0)) minutes.                                 ║")
                print("║ \(String(format: "%.0f", remaining / 60.0)) minute(s) remaining until auto-stop.                      ║")
                print("╚═══════════════════════════════════════════════════════════════╝")
                
                DispatchQueue.main.async {
                    self.onRecordingTimeoutWarning?(remaining)
                }
            }
        }
        
        // Start max timer (fires at 5 minutes by default - auto-stops recording)
        recordingTimeoutMaxTimer = Timer.scheduledTimer(withTimeInterval: maxDuration, repeats: false) { [weak self] _ in
            guard let self = self, self.isCapturing else { return }
            
            print("╔═══════════════════════════════════════════════════════════════╗")
            print("║     ⛔ US-603: RECORDING TIMEOUT REACHED - AUTO-STOPPING       ║")
            print("╠═══════════════════════════════════════════════════════════════╣")
            print("║ Recording has reached the maximum duration of \(String(format: "%.0f", maxDuration / 60.0)) minutes.      ║")
            print("║ Auto-stopping and triggering transcription.                   ║")
            print("╚═══════════════════════════════════════════════════════════════╝")
            
            DispatchQueue.main.async {
                self.onRecordingTimeoutReached?()
            }
        }
    }
    
    /// US-603: Stop recording timeout timers
    private func stopRecordingTimeoutTimers() {
        recordingTimeoutWarningTimer?.invalidate()
        recordingTimeoutWarningTimer = nil
        recordingTimeoutMaxTimer?.invalidate()
        recordingTimeoutMaxTimer = nil
        hasShownTimeoutWarning = false
    }

    // MARK: - US-006: Muted/Silent Input Detection Timer Methods

    /// US-006: Start timer to monitor for prolonged silence during recording
    private func startSilenceMonitorTimer() {
        stopSilenceMonitorTimer()
        continuousSilenceDuration = 0
        hasShownSilenceWarning = false

        let checkInterval = Constants.silenceCheckInterval
        let warningThreshold = Self.silenceWarningDuration

        print("AudioManager: [US-006] Starting silence monitor (check: \(checkInterval)s, warn: \(warningThreshold)s)")

        silenceMonitorTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.isCapturing else { return }

            // Check if current audio level indicates silence
            let currentLevel = self.currentAudioLevel
            let silenceThreshold = self.effectiveSilenceThreshold

            if currentLevel < silenceThreshold {
                // Audio is silent, accumulate duration
                self.continuousSilenceDuration += checkInterval

                if self.continuousSilenceDuration >= warningThreshold && !self.hasShownSilenceWarning {
                    // Prolonged silence detected - fire callback
                    self.hasShownSilenceWarning = true
                    let deviceName = self.currentDevice?.name ?? "Unknown"

                    print("╔═══════════════════════════════════════════════════════════════╗")
                    print("║     ⚠️ US-006: PROLONGED SILENCE DETECTED DURING RECORDING     ║")
                    print("╠═══════════════════════════════════════════════════════════════╣")
                    print("║ Silence duration: \(String(format: "%.1f", self.continuousSilenceDuration))s (threshold: \(String(format: "%.1f", warningThreshold))s)                    ║")
                    print("║ Current level: \(String(format: "%.1f", currentLevel))dB (threshold: \(String(format: "%.1f", silenceThreshold))dB)                ║")
                    print("║ Device: \(deviceName.prefix(52).padding(toLength: 52, withPad: " ", startingAt: 0))   ║")
                    print("╚═══════════════════════════════════════════════════════════════╝")

                    DispatchQueue.main.async {
                        self.onProlongedSilenceDetected?(currentLevel, self.continuousSilenceDuration, deviceName)
                    }
                }
            } else {
                // Audio detected, reset silence tracking
                if self.continuousSilenceDuration > 0 {
                    print("AudioManager: [US-006] Audio detected (\(String(format: "%.1f", currentLevel))dB), resetting silence counter")
                }
                self.continuousSilenceDuration = 0
                self.hasShownSilenceWarning = false
            }
        }
    }

    /// US-006: Stop the silence monitor timer
    private func stopSilenceMonitorTimer() {
        silenceMonitorTimer?.invalidate()
        silenceMonitorTimer = nil
        continuousSilenceDuration = 0
        hasShownSilenceWarning = false
    }

    /// US-006: Configurable silence warning duration (how long silence must persist before warning)
    static var silenceWarningDuration: TimeInterval {
        get {
            let stored = UserDefaults.standard.double(forKey: Constants.silenceWarningDurationKey)
            return stored > 0 ? stored : Constants.defaultSilenceWarningDuration
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.silenceWarningDurationKey)
            print("AudioManager: [US-006] Silence warning duration set to \(newValue) seconds")
        }
    }

    /// US-302: Log callback statistics summary after capture stops
    private func logTapCallbackStats(duration: TimeInterval) {
        let callbacksPerSecond = duration > 0 ? Double(tapCallbackCount) / duration : 0
        let expectedCallbacks = duration > 0 ? Int(duration * Constants.targetSampleRate / 4096.0) : 0
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║              US-302: TAP CALLBACK STATISTICS                  ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ Total tap callbacks:     \(String(format: "%10d", tapCallbackCount))                        ║")
        print("║ Duration:                \(String(format: "%10.2f", duration)) seconds                  ║")
        print("║ Callbacks per second:    \(String(format: "%10.1f", callbacksPerSecond))                        ║")
        print("║ Expected (approx):       \(String(format: "%10d", expectedCallbacks))                        ║")
        print("║ Empty callbacks:         \(String(format: "%10d", emptyCallbackCount))                        ║")
        print("║ Zero-data callbacks:     \(String(format: "%10d", zeroDataCallbackCount))                        ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
    }
    
    // MARK: - Private Helpers
    
    private func setAudioInputDevice(_ device: AudioInputDevice) throws {
        // Set the device on the audio engine's input node
        // This is done by setting the kAudioOutputUnitProperty_CurrentDevice property
        
        #if os(macOS)
        let audioUnit = audioEngine.inputNode.audioUnit
        guard let au = audioUnit else {
            print("AudioManager: audioUnit is nil - cannot set input device")
            print("AudioManager: This usually means the audio engine has not been prepared yet")
            throw AudioCaptureError.audioUnitNotAvailable
        }
        
        var deviceID = device.id
        print("AudioManager: Setting input device to ID \(deviceID) (\(device.name))")
        
        let status = AudioUnitSetProperty(
            au,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        
        if status != noErr {
            print("AudioManager: Failed to set input device: OSStatus \(status)")
            throw AudioCaptureError.deviceSelectionFailed(status)
        }
        
        // Verify the device was set by reading it back
        var verifyDeviceID: AudioDeviceID = 0
        var verifySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let verifyStatus = AudioUnitGetProperty(
            au,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &verifyDeviceID,
            &verifySize
        )
        
        if verifyStatus == noErr {
            if verifyDeviceID == deviceID {
                print("AudioManager: ✓ Verified input device set to '\(device.name)' (ID: \(verifyDeviceID))")
            } else {
                print("AudioManager: ⚠️ Device ID mismatch: requested \(deviceID), got \(verifyDeviceID)")
            }
        } else {
            print("AudioManager: ⚠️ Could not verify device setting (status: \(verifyStatus))")
        }
        #endif
    }
    

    /// Ensure the input node is connected to a muted mixer sink so taps receive data
    private func configureInputGraph(inputNode: AVAudioInputNode, format: AVAudioFormat) {
        if !audioEngine.attachedNodes.contains(inputMixerNode) {
            audioEngine.attach(inputMixerNode)
        }
        inputMixerNode.outputVolume = 0
        audioEngine.disconnectNodeOutput(inputNode)
        audioEngine.disconnectNodeInput(inputMixerNode)
        audioEngine.disconnectNodeOutput(inputMixerNode)
        audioEngine.connect(inputNode, to: inputMixerNode, format: format)
        audioEngine.connect(inputMixerNode, to: audioEngine.mainMixerNode, format: nil)
        print("AudioManager: [STAGE 1] ✓ Input graph configured with muted mixer sink (sample rate: \(format.sampleRate), channels: \(format.channelCount))")
    }

    // MARK: - US-301: Unified Buffer Access
    
    /// US-301: Get audio buffer directly - returns masterBuffer contents
    /// This is the ONLY way to access audio data, ensuring level meter and transcription use same data
    func getAudioBuffer() -> [Float] {
        bufferLock.lock()
        let buffer = masterBuffer
        bufferLock.unlock()
        print("AudioManager: [US-301] getAudioBuffer() returning \(buffer.count) samples from masterBuffer")
        return buffer
    }
    
    /// US-301: Get masterBuffer data with statistics (for transcription)
    private func getMasterBufferDataWithStats() -> (Data, AudioBufferStats) {
        // US-303: Log when buffer is read for transcription
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║       US-303: BUFFER INTEGRITY - READING FOR TRANSCRIPTION    ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        // US-301: Get samples directly from masterBuffer (the ONLY audio storage)
        bufferLock.lock()
        let allSamples = masterBuffer
        bufferLock.unlock()
        
        // US-303: Log if buffer is empty when read
        if allSamples.isEmpty {
            print("╔═══════════════════════════════════════════════════════════════╗")
            print("║  ⚠️ US-303 WARNING: BUFFER IS EMPTY WHEN READ FOR TRANSCRIPTION ║")
            print("╠═══════════════════════════════════════════════════════════════╣")
            print("║ masterBuffer has 0 samples despite recording being active.    ║")
            print("║ Possible causes:                                              ║")
            print("║   - Audio tap callback never received data                    ║")
            print("║   - All callbacks had empty/zero buffers                      ║")
            print("║   - Buffer was unexpectedly cleared                           ║")
            print("║ Check tap callback count and empty callback count above.      ║")
            print("╚═══════════════════════════════════════════════════════════════╝")
        } else {
            print("AudioManager: [US-303] Buffer read: \(allSamples.count) samples retrieved from masterBuffer")
        }
        
        // [STAGE 4] Log actual sample values BEFORE silence check
        if !allSamples.isEmpty {
            let firstSamples = Array(allSamples.prefix(10))
            let lastSamples = Array(allSamples.suffix(10))
            
            print("AudioManager: [STAGE 4] ┌─ SAMPLE VALUES FROM masterBuffer ────────────────────────")
            print("AudioManager: [STAGE 4] │ First 10 samples: \(firstSamples.map { String(format: "%.6f", $0) }.joined(separator: ", "))")
            print("AudioManager: [STAGE 4] │ Last 10 samples:  \(lastSamples.map { String(format: "%.6f", $0) }.joined(separator: ", "))")
            
            // Count zero vs non-zero samples
            let zeroThreshold: Float = 1e-7
            let zeroCount = allSamples.filter { abs($0) < zeroThreshold }.count
            let nonZeroCount = allSamples.count - zeroCount
            let zeroPercentage = Float(zeroCount) / Float(allSamples.count) * 100
            let nonZeroPercentage = Float(nonZeroCount) / Float(allSamples.count) * 100
            print("AudioManager: [STAGE 4] │ Zero samples: \(String(format: "%.1f", zeroPercentage))% (\(zeroCount)/\(allSamples.count))")
            print("AudioManager: [STAGE 4] │ Non-zero samples: \(String(format: "%.1f", nonZeroPercentage))% (\(nonZeroCount)/\(allSamples.count))")
            print("AudioManager: [STAGE 4] └──────────────────────────────────────────────────────────────")
        }
        
        // Normalize samples to [-1.0, 1.0] range if necessary
        let normalizedSamples = normalizeAudioSamples(allSamples)
        
        // Calculate statistics from normalized samples
        let stats = calculateBufferStatistics(samples: normalizedSamples)
        
        // Convert normalized Float32 samples to Data
        var combinedData = Data()
        combinedData.reserveCapacity(normalizedSamples.count * MemoryLayout<Float>.size)
        
        for sample in normalizedSamples {
            var sampleValue = sample
            withUnsafeBytes(of: &sampleValue) { bytes in
                combinedData.append(contentsOf: bytes)
            }
        }
        
        return (combinedData, stats)
    }
    
    /// Normalize audio samples to [-1.0, 1.0] range
    /// - Parameter samples: Input audio samples
    /// - Returns: Normalized audio samples
    private func normalizeAudioSamples(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return samples }
        
        // Find peak amplitude
        var peakAmplitude: Float = 0
        for sample in samples {
            let absValue = abs(sample)
            if absValue > peakAmplitude {
                peakAmplitude = absValue
            }
        }
        
        // If already in range [-1.0, 1.0] or silent, no normalization needed
        if peakAmplitude <= 1.0 {
            if peakAmplitude > 0.0001 {
                print("AudioManager: ✓ Audio samples already in [-1.0, 1.0] range (peak: \(String(format: "%.4f", peakAmplitude)))")
            }
            return samples
        }
        
        // Normalize by dividing by peak amplitude
        let normalizationFactor = 1.0 / peakAmplitude
        print("AudioManager: ⚠️ Normalizing audio samples (peak: \(String(format: "%.4f", peakAmplitude)) -> 1.0, factor: \(String(format: "%.4f", normalizationFactor)))")
        
        return samples.map { $0 * normalizationFactor }
    }
    
    /// Calculate statistics from audio samples
    private func calculateBufferStatistics(samples: [Float]) -> AudioBufferStats {
        guard !samples.isEmpty else {
            return AudioBufferStats(
                sampleCount: 0,
                duration: 0,
                peakLevel: -Float.infinity,
                rmsLevel: -Float.infinity,
                minSample: 0,
                maxSample: 0,
                nearZeroPercentage: 100.0
            )
        }
        
        var minSample: Float = Float.infinity
        var maxSample: Float = -Float.infinity
        var sumSquares: Float = 0
        var zeroCount: Int = 0
        let zeroThreshold: Float = 1e-7
        
        for sample in samples {
            minSample = min(minSample, sample)
            maxSample = max(maxSample, sample)
            sumSquares += sample * sample
            if abs(sample) < zeroThreshold {
                zeroCount += 1
            }
        }
        
        // Peak level is max absolute value converted to dB
        let peakAmplitude = max(abs(minSample), abs(maxSample))
        let peakLevel = amplitudeToDecibels(peakAmplitude)
        
        // RMS level
        let rms = sqrt(sumSquares / Float(samples.count))
        let rmsLevel = amplitudeToDecibels(rms)
        
        let duration = TimeInterval(samples.count) / Constants.targetSampleRate
        
        // Calculate near-zero percentage
        let nearZeroPercentage = Float(zeroCount) / Float(samples.count) * 100.0
        
        return AudioBufferStats(
            sampleCount: samples.count,
            duration: duration,
            peakLevel: peakLevel,
            rmsLevel: rmsLevel,
            minSample: minSample,
            maxSample: maxSample,
            nearZeroPercentage: nearZeroPercentage
        )
    }
    
    /// Calculate peak level from an audio buffer (for real-time metering)
    private func calculatePeakLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else {
            return -60.0
        }
        
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            return -60.0
        }
        
        let dataPointer = channelData[0]
        var maxAmplitude: Float = 0
        
        for i in 0..<frameLength {
            let amplitude = abs(dataPointer[i])
            if amplitude > maxAmplitude {
                maxAmplitude = amplitude
            }
        }
        
        return amplitudeToDecibels(maxAmplitude)
    }
    
    /// US-301: Calculate peak level from Float samples array (for unified buffer level metering)
    private func calculatePeakLevelFromSamples(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else {
            return -60.0
        }
        
        var maxAmplitude: Float = 0
        for sample in samples {
            let amplitude = abs(sample)
            if amplitude > maxAmplitude {
                maxAmplitude = amplitude
            }
        }
        
        return amplitudeToDecibels(maxAmplitude)
    }
    
    /// Convert linear amplitude to decibels
    /// Uses the formula: 20 * log10(max(amplitude, 1e-10)) to safely handle zero values
    private func amplitudeToDecibels(_ amplitude: Float) -> Float {
        // Use 1e-10 floor to avoid log10(0) = -Infinity or NaN
        let safeAmplitude = max(amplitude, 1e-10)
        // 20 * log10(amplitude)
        let db = 20.0 * log10(safeAmplitude)
        // Clamp to reasonable range (-100dB to 0dB)
        return max(-100.0, min(0.0, db))
    }
    
    /// Silence threshold in dB
    static var silenceThreshold: Float {
        return Constants.silenceThresholdDB
    }
    
    /// Minimum recording duration in seconds
    static var minimumDuration: TimeInterval {
        return Constants.minimumRecordingDuration
    }
    
    // MARK: - US-603: Recording Timeout Configuration
    
    /// Maximum recording duration in seconds (configurable, default 5 minutes)
    static var maxRecordingDuration: TimeInterval {
        get {
            let stored = UserDefaults.standard.double(forKey: Constants.maxRecordingDurationKey)
            return stored > 0 ? stored : Constants.defaultMaxRecordingDuration
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.maxRecordingDurationKey)
            print("AudioManager: [US-603] Max recording duration set to \(newValue) seconds (\(newValue / 60.0) minutes)")
        }
    }
    
    /// Warning duration (time at which warning is shown, e.g., 4 minutes)
    static var warningDuration: TimeInterval {
        return maxRecordingDuration - Constants.warningOffsetFromMax
    }
    
    /// Get the elapsed recording time (returns 0 if not recording)
    var elapsedRecordingTime: TimeInterval {
        guard let startTime = captureStartTime, isCapturing else {
            return 0
        }
        return Date().timeIntervalSince(startTime)
    }
    
    /// Get the remaining recording time until max limit (returns nil if not recording)
    var remainingRecordingTime: TimeInterval? {
        guard isCapturing else {
            return nil
        }
        let elapsed = elapsedRecordingTime
        let remaining = Self.maxRecordingDuration - elapsed
        return max(0, remaining)
    }
    
    // MARK: - US-604: Audio Level Calibration Methods
    
    /// Start calibrating the microphone for the current device
    /// Measures ambient noise level over 3 seconds
    func startCalibration() {
        guard !isCapturing else {
            print("AudioManager: [US-604] Cannot start calibration while recording is in progress")
            calibrationState = .failed(message: "Cannot calibrate while recording")
            onCalibrationFailed?("Cannot calibrate while recording is in progress")
            return
        }
        
        guard let device = currentDevice else {
            print("AudioManager: [US-604] No audio device available for calibration")
            calibrationState = .failed(message: "No audio device selected")
            onCalibrationFailed?("No audio device selected")
            return
        }
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║       US-604: STARTING AUDIO LEVEL CALIBRATION                ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ Device: \(device.name.prefix(52).padding(toLength: 52, withPad: " ", startingAt: 0))   ║")
        print("║ Duration: \(String(format: "%.0f", Constants.calibrationDuration).padding(toLength: 49, withPad: " ", startingAt: 0))s   ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        // Reset calibration state
        calibrationSamples.removeAll()
        calibrationStartTime = Date()
        calibrationState = .calibrating(progress: 0.0)
        
        // Start audio capture for calibration
        do {
            try startCapturing()
            
            // Start timer to update progress and collect samples
            calibrationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                guard let startTime = self.calibrationStartTime else {
                    timer.invalidate()
                    return
                }
                
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(elapsed / Constants.calibrationDuration, 1.0)
                
                // Collect current audio level
                self.calibrationSamples.append(self.currentAudioLevel)
                
                // Update progress
                DispatchQueue.main.async {
                    self.calibrationState = .calibrating(progress: progress)
                }
                
                // Check if calibration is complete
                if elapsed >= Constants.calibrationDuration {
                    timer.invalidate()
                    self.finishCalibration()
                }
            }
        } catch {
            print("AudioManager: [US-604] Failed to start calibration: \(error)")
            calibrationState = .failed(message: error.localizedDescription)
            onCalibrationFailed?(error.localizedDescription)
        }
    }
    
    /// Cancel an in-progress calibration
    func cancelCalibration() {
        print("AudioManager: [US-604] Calibration cancelled")
        calibrationTimer?.invalidate()
        calibrationTimer = nil
        calibrationSamples.removeAll()
        calibrationStartTime = nil
        cancelCapturing()
        calibrationState = .idle
    }
    
    /// Finish calibration and calculate results
    private func finishCalibration() {
        calibrationTimer?.invalidate()
        calibrationTimer = nil
        
        // Stop audio capture
        cancelCapturing()
        
        guard let device = currentDevice else {
            print("AudioManager: [US-604] No device available to save calibration")
            calibrationState = .failed(message: "Device unavailable")
            onCalibrationFailed?("Device unavailable")
            return
        }
        
        guard !calibrationSamples.isEmpty else {
            print("AudioManager: [US-604] No samples collected during calibration")
            calibrationState = .failed(message: "No audio samples collected")
            onCalibrationFailed?("No audio samples collected")
            return
        }
        
        // Calculate average ambient noise level from samples
        // Filter out extremely low readings that might be silence
        let validSamples = calibrationSamples.filter { $0 > -80.0 }
        
        let ambientLevel: Float
        if validSamples.isEmpty {
            // All samples were very quiet, use the max of all samples
            ambientLevel = calibrationSamples.max() ?? Constants.silenceThresholdDB
        } else {
            // Use the average of valid samples
            ambientLevel = validSamples.reduce(0, +) / Float(validSamples.count)
        }
        
        // Calculate silence threshold: ambient noise + offset
        // This ensures we only detect voice that's clearly above the ambient noise floor
        let silenceThreshold = ambientLevel + Constants.defaultSilenceThresholdOffset
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║       US-604: CALIBRATION COMPLETE                            ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ Device: \(device.name.prefix(52).padding(toLength: 52, withPad: " ", startingAt: 0))   ║")
        print("║ Samples collected: \(String(calibrationSamples.count).padding(toLength: 41, withPad: " ", startingAt: 0))   ║")
        print("║ Valid samples: \(String(validSamples.count).padding(toLength: 45, withPad: " ", startingAt: 0))   ║")
        print("║ Ambient noise level: \(String(format: "%.1f dB", ambientLevel).padding(toLength: 39, withPad: " ", startingAt: 0))   ║")
        print("║ Calculated threshold: \(String(format: "%.1f dB", silenceThreshold).padding(toLength: 38, withPad: " ", startingAt: 0))   ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        // Create and save calibration data
        let calibration = DeviceCalibration(
            deviceUID: device.uid,
            deviceName: device.name,
            ambientNoiseLevel: ambientLevel,
            silenceThreshold: silenceThreshold,
            calibrationDate: Date()
        )
        
        deviceCalibrations[device.uid] = calibration
        saveCalibrationData()
        
        // Update state
        DispatchQueue.main.async { [weak self] in
            self?.calibrationState = .completed(ambientLevel: ambientLevel)
            self?.onCalibrationCompleted?(calibration)
        }
        
        calibrationSamples.removeAll()
        calibrationStartTime = nil
    }
    
    /// Get calibration data for the current device
    func getCalibrationForCurrentDevice() -> DeviceCalibration? {
        guard let device = currentDevice else { return nil }
        return deviceCalibrations[device.uid]
    }
    
    /// Get calibration data for a specific device UID
    func getCalibration(forDeviceUID uid: String) -> DeviceCalibration? {
        return deviceCalibrations[uid]
    }
    
    /// Check if the current device has been calibrated
    var isCurrentDeviceCalibrated: Bool {
        guard let device = currentDevice else { return false }
        return deviceCalibrations[device.uid] != nil
    }
    
    /// Get the effective silence threshold for the current device
    /// Returns calibrated threshold if available, otherwise default
    var effectiveSilenceThreshold: Float {
        if let device = currentDevice,
           let calibration = deviceCalibrations[device.uid] {
            return calibration.silenceThreshold
        }
        return Constants.silenceThresholdDB
    }
    
    /// Reset calibration for the current device to defaults
    func resetCalibrationForCurrentDevice() {
        guard let device = currentDevice else {
            print("AudioManager: [US-604] No device available to reset calibration")
            return
        }
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║       US-604: RESETTING CALIBRATION TO DEFAULTS               ║")
        print("╠═══════════════════════════════════════════════════════════════╣")
        print("║ Device: \(device.name.prefix(52).padding(toLength: 52, withPad: " ", startingAt: 0))   ║")
        print("║ Default threshold: \(String(format: "%.1f dB", Constants.silenceThresholdDB).padding(toLength: 41, withPad: " ", startingAt: 0))   ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        deviceCalibrations.removeValue(forKey: device.uid)
        saveCalibrationData()
        calibrationState = .idle
    }
    
    /// Reset all device calibrations to defaults
    func resetAllCalibrations() {
        print("AudioManager: [US-604] Resetting all device calibrations")
        deviceCalibrations.removeAll()
        saveCalibrationData()
        calibrationState = .idle
    }
    
    // MARK: - US-604: Calibration Data Persistence
    
    /// Load calibration data from UserDefaults
    private func loadCalibrationData() {
        guard let data = UserDefaults.standard.data(forKey: Constants.calibrationDataKey) else {
            print("AudioManager: [US-604] No calibration data found in UserDefaults")
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode([String: DeviceCalibration].self, from: data)
            deviceCalibrations = decoded
            print("AudioManager: [US-604] Loaded calibration data for \(decoded.count) device(s)")
            for (uid, cal) in decoded {
                print("AudioManager: [US-604]   - \(cal.deviceName): \(cal.description)")
            }
        } catch {
            print("AudioManager: [US-604] Failed to decode calibration data: \(error)")
            deviceCalibrations = [:]
        }
    }
    
    /// Save calibration data to UserDefaults
    private func saveCalibrationData() {
        do {
            let encoded = try JSONEncoder().encode(deviceCalibrations)
            UserDefaults.standard.set(encoded, forKey: Constants.calibrationDataKey)
            print("AudioManager: [US-604] Saved calibration data for \(deviceCalibrations.count) device(s)")
        } catch {
            print("AudioManager: [US-604] Failed to encode calibration data: \(error)")
        }
    }
}

// MARK: - Errors

enum AudioCaptureError: LocalizedError {
    case microphonePermissionDenied
    case formatCreationFailed
    case deviceSelectionFailed(OSStatus)
    case audioUnitNotAvailable
    case noInputDevicesAvailable
    case invalidInputFormat(sampleRate: Double, channels: UInt32)
    case noCompatibleFormat(String)  // US-602: No compatible audio format found
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission was denied"
        case .formatCreationFailed:
            return "Failed to create audio format"
        case .deviceSelectionFailed(let status):
            return "Failed to select audio device (error: \(status))"
        case .audioUnitNotAvailable:
            return "Audio unit is not available"
        case .noInputDevicesAvailable:
            return "No audio input devices available. Please connect a microphone and try again."
        case .invalidInputFormat(let sampleRate, let channels):
            return "Invalid audio input format: sample rate = \(sampleRate) Hz, channels = \(channels). Expected sample rate > 0 and channels > 0."
        case .noCompatibleFormat(let reason):
            return "No compatible audio format found: \(reason)"
        }
    }
}
