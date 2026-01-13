import AVFoundation
import AppKit
import Combine

/// Manages audio capture using AVAudioEngine with support for device selection
/// Handles microphone permissions, audio input device enumeration, and audio buffering
final class AudioManager: NSObject, ObservableObject {
    
    // MARK: - Types
    
    /// Represents an available audio input device
    struct AudioInputDevice: Equatable, Identifiable {
        let id: AudioDeviceID
        let uid: String
        let name: String
        let isDefault: Bool
        
        static func == (lhs: AudioInputDevice, rhs: AudioInputDevice) -> Bool {
            return lhs.uid == rhs.uid
        }
    }
    
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
    
    // MARK: - Constants
    
    private struct Constants {
        static let targetSampleRate: Double = 16000.0 // Whisper prefers 16kHz
        static let selectedDeviceKey = "selectedAudioInputDeviceUID"
        static let silenceThresholdDB: Float = -55.0  // Below this is considered silence (lowered from -40dB for more permissive detection)
        static let minimumRecordingDuration: TimeInterval = 0.5 // Minimum 0.5s recording
    }
    
    // MARK: - Properties
    
    private let audioEngine = AVAudioEngine()
    private var audioBuffers: [AVAudioPCMBuffer] = []
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
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        loadSelectedDevice()
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
            alert.informativeText = "WispFlow needs microphone access to capture your voice. Please enable microphone access in System Settings > Privacy & Security > Microphone."
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
    
    /// Get currently selected device (or default if none selected)
    var currentDevice: AudioInputDevice? {
        if let selectedUID = selectedDeviceUID {
            return availableInputDevices.first { $0.uid == selectedUID }
        }
        return availableInputDevices.first { $0.isDefault } ?? availableInputDevices.first
    }
    
    /// Select an audio input device by UID
    func selectDevice(uid: String) {
        guard availableInputDevices.contains(where: { $0.uid == uid }) else {
            print("AudioManager: Device with UID '\(uid)' not found")
            return
        }
        
        selectedDeviceUID = uid
        saveSelectedDevice()
        print("AudioManager: Selected device '\(uid)'")
        
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
    func refreshAvailableDevices() {
        availableInputDevices = enumerateAudioInputDevices()
        
        // Validate selected device still exists
        if let selectedUID = selectedDeviceUID,
           !availableInputDevices.contains(where: { $0.uid == selectedUID }) {
            print("AudioManager: Previously selected device no longer available, using default")
            selectedDeviceUID = nil
            saveSelectedDevice()
        }
        
        print("AudioManager: Found \(availableInputDevices.count) audio input device(s)")
        for device in availableInputDevices {
            print("  - \(device.name) (default: \(device.isDefault))")
        }
        
        onDevicesChanged?(availableInputDevices)
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
                let device = AudioInputDevice(
                    id: deviceID,
                    uid: uid,
                    name: name,
                    isDefault: deviceID == defaultDeviceID
                )
                devices.append(device)
            }
        }
        
        return devices
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
        
        // Set the input device if one is selected
        if let device = currentDevice {
            try setAudioInputDevice(device)
            print("AudioManager: [STAGE 1] ✓ Input device set: \(device.name)")
        }
        
        // Clear previous buffers
        audioBuffers.removeAll()
        print("AudioManager: [STAGE 1] ✓ Audio buffers cleared")
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        print("AudioManager: [STAGE 1] Input format - Sample rate: \(inputFormat.sampleRate), Channels: \(inputFormat.channelCount)")
        
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
        
        // Create converter if sample rates differ
        let converter: AVAudioConverter?
        if inputFormat.sampleRate != Constants.targetSampleRate || inputFormat.channelCount != 1 {
            converter = AVAudioConverter(from: inputFormat, to: whisperFormat)
            print("AudioManager: [STAGE 1] ✓ Audio converter created: \(inputFormat.sampleRate)Hz → \(Constants.targetSampleRate)Hz")
        } else {
            converter = nil
            print("AudioManager: [STAGE 1] ✓ No conversion needed (already 16kHz mono)")
        }
        
        // Reset audio level tracking
        peakLevelDuringRecording = -Float.infinity
        currentAudioLevel = -60.0
        
        // Track buffer statistics for verification
        var bufferAppendCount = 0
        var totalFramesAppended: AVAudioFrameCount = 0
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║            AUDIO PIPELINE STAGE 2: TAP INSTALLED              ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // [STAGE 2] Calculate audio level from raw input buffer for real-time meter
            // NOTE: This level meter and transcription buffer use THE SAME input buffer
            let level = self.calculatePeakLevel(buffer: buffer)
            
            // Update current audio level on main thread
            DispatchQueue.main.async {
                self.currentAudioLevel = level
                // Track peak level during entire recording
                if level > self.peakLevelDuringRecording {
                    self.peakLevelDuringRecording = level
                }
            }
            
            if let converter = converter {
                // [STAGE 2] Convert to target format (16kHz mono)
                let frameCapacity = AVAudioFrameCount(
                    Double(buffer.frameLength) * Constants.targetSampleRate / inputFormat.sampleRate
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
                } else if convertedBuffer.frameLength > 0 {
                    // Verify the converted buffer format matches expected format
                    if self.audioBuffers.isEmpty {
                        // Log format verification on first buffer
                        let format = convertedBuffer.format
                        print("AudioManager: [STAGE 2] ✓ First converted buffer format verified:")
                        print("  - Sample rate: \(format.sampleRate) Hz (expected: \(Constants.targetSampleRate))")
                        print("  - Channels: \(format.channelCount) (expected: 1)")
                        print("  - Format: \(format.commonFormat == .pcmFormatFloat32 ? "Float32" : "Other")")
                        print("  - Level meter source: same input buffer as transcription buffer")
                    }
                    
                    // [STAGE 2] Append converted buffer to audioBuffers
                    self.audioBuffers.append(convertedBuffer)
                    
                    // Log buffer append confirmation (every 10th buffer to avoid log spam)
                    bufferAppendCount += 1
                    totalFramesAppended += convertedBuffer.frameLength
                    if bufferAppendCount % 10 == 0 {
                        print("AudioManager: [STAGE 2] Buffer append #\(bufferAppendCount) - frames: \(convertedBuffer.frameLength), total frames: \(totalFramesAppended)")
                    }
                }
            } else {
                // No conversion needed - already at target format
                if self.audioBuffers.isEmpty {
                    print("AudioManager: [STAGE 2] ✓ Audio already at target format (16kHz mono Float32)")
                    print("  - Level meter source: same input buffer as transcription buffer")
                }
                self.audioBuffers.append(buffer)
                
                // Log buffer append confirmation (every 10th buffer)
                bufferAppendCount += 1
                totalFramesAppended += buffer.frameLength
                if bufferAppendCount % 10 == 0 {
                    print("AudioManager: [STAGE 2] Buffer append #\(bufferAppendCount) - frames: \(buffer.frameLength), total frames: \(totalFramesAppended)")
                }
            }
        }
        
        // Start the audio engine
        try audioEngine.start()
        
        isCapturing = true
        captureStartTime = Date()
        print("AudioManager: [STAGE 1] ✓ Audio engine started - capturing audio")
    }
    
    /// Stop capturing audio and return the result
    func stopCapturing() -> AudioCaptureResult? {
        guard isCapturing else {
            return nil
        }
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║            AUDIO PIPELINE STAGE 3: CAPTURE STOP               ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        // Stop engine and remove tap
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        print("AudioManager: [STAGE 3] ✓ Audio engine stopped, tap removed")
        
        isCapturing = false
        
        // Calculate duration
        let duration = captureStartTime.map { Date().timeIntervalSince($0) } ?? 0
        captureStartTime = nil
        print("AudioManager: [STAGE 3] Recording duration: \(String(format: "%.2f", duration))s, Buffers collected: \(audioBuffers.count)")
        
        // Check minimum recording duration
        if duration < Constants.minimumRecordingDuration {
            print("AudioManager: [STAGE 3] ✗ Recording too short (\(String(format: "%.2f", duration))s < \(Constants.minimumRecordingDuration)s minimum)")
            audioBuffers.removeAll()
            currentAudioLevel = -60.0
            onRecordingTooShort?()
            return nil
        }
        
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║            AUDIO PIPELINE STAGE 4: BUFFER COMBINE             ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        
        // Combine buffers into single data and compute statistics
        let (audioData, stats) = combineBuffersToDataWithStats()
        print("AudioManager: [STAGE 4] ✓ Buffers combined into \(audioData.count) bytes")
        
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
        
        audioBuffers.removeAll()
        currentAudioLevel = -60.0
        
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
        
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        
        isCapturing = false
        captureStartTime = nil
        audioBuffers.removeAll()
        
        print("AudioManager: Cancelled capturing")
    }
    
    /// Check if currently capturing
    var isCurrentlyCapturing: Bool {
        return isCapturing
    }
    
    // MARK: - Private Helpers
    
    private func setAudioInputDevice(_ device: AudioInputDevice) throws {
        // Set the device on the audio engine's input node
        // This is done by setting the kAudioOutputUnitProperty_CurrentDevice property
        
        #if os(macOS)
        let audioUnit = audioEngine.inputNode.audioUnit
        guard let au = audioUnit else {
            throw AudioCaptureError.audioUnitNotAvailable
        }
        
        var deviceID = device.id
        let status = AudioUnitSetProperty(
            au,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        
        if status != noErr {
            print("AudioManager: Failed to set input device: \(status)")
            throw AudioCaptureError.deviceSelectionFailed(status)
        }
        
        print("AudioManager: Set input device to '\(device.name)'")
        #endif
    }
    
    private func combineBuffersToData() -> Data {
        var combinedData = Data()
        
        for buffer in audioBuffers {
            guard let channelData = buffer.floatChannelData else { continue }
            
            let frameLength = Int(buffer.frameLength)
            let dataPointer = channelData[0]
            
            // Convert Float32 samples to Data
            let byteSize = frameLength * MemoryLayout<Float>.size
            combinedData.append(Data(bytes: dataPointer, count: byteSize))
        }
        
        return combinedData
    }
    
    /// Combine buffers, normalize to [-1.0, 1.0] range, and compute statistics
    private func combineBuffersToDataWithStats() -> (Data, AudioBufferStats) {
        var allSamples: [Float] = []
        
        // Track expected sample count from individual buffers for verification
        var expectedSampleCount: Int = 0
        
        // First pass: collect all samples
        for buffer in audioBuffers {
            guard let channelData = buffer.floatChannelData else { continue }
            
            let frameLength = Int(buffer.frameLength)
            let dataPointer = channelData[0]
            
            expectedSampleCount += frameLength
            
            for i in 0..<frameLength {
                allSamples.append(dataPointer[i])
            }
        }
        
        // Buffer sample count verification
        if allSamples.count != expectedSampleCount {
            print("AudioManager: ⚠️ SAMPLE COUNT MISMATCH - collected: \(allSamples.count), expected: \(expectedSampleCount)")
        } else {
            print("AudioManager: ✓ Buffer sample count verified: \(allSamples.count) samples from \(audioBuffers.count) buffers")
        }
        
        // [STAGE 4] Log actual sample values BEFORE silence check
        if !allSamples.isEmpty {
            let firstSamples = Array(allSamples.prefix(10))
            let lastSamples = Array(allSamples.suffix(10))
            
            print("AudioManager: [STAGE 4] ┌─ SAMPLE VALUES BEFORE SILENCE CHECK ────────────────────────")
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
}

// MARK: - Errors

enum AudioCaptureError: LocalizedError {
    case microphonePermissionDenied
    case formatCreationFailed
    case deviceSelectionFailed(OSStatus)
    case audioUnitNotAvailable
    
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
        }
    }
}
