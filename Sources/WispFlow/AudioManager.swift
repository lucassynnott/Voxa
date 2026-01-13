import AVFoundation
import AppKit

/// Manages audio capture using AVAudioEngine with support for device selection
/// Handles microphone permissions, audio input device enumeration, and audio buffering
final class AudioManager: NSObject {
    
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
    }
    
    // MARK: - Properties
    
    private let audioEngine = AVAudioEngine()
    private var audioBuffers: [AVAudioPCMBuffer] = []
    private var isCapturing = false
    private var captureStartTime: Date?
    
    // Device tracking
    private var availableInputDevices: [AudioInputDevice] = []
    private var selectedDeviceUID: String?
    
    // Callbacks
    var onPermissionDenied: (() -> Void)?
    var onCaptureError: ((Error) -> Void)?
    var onDevicesChanged: (([AudioInputDevice]) -> Void)?
    
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
        
        // Check permission first
        guard permissionStatus == .authorized else {
            showMicrophonePermissionAlert()
            throw AudioCaptureError.microphonePermissionDenied
        }
        
        // Set the input device if one is selected
        if let device = currentDevice {
            try setAudioInputDevice(device)
        }
        
        // Clear previous buffers
        audioBuffers.removeAll()
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        print("AudioManager: Input format - Sample rate: \(inputFormat.sampleRate), Channels: \(inputFormat.channelCount)")
        
        // Create format for Whisper (16kHz mono)
        guard let whisperFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Constants.targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioCaptureError.formatCreationFailed
        }
        
        // Create converter if sample rates differ
        let converter: AVAudioConverter?
        if inputFormat.sampleRate != Constants.targetSampleRate || inputFormat.channelCount != 1 {
            converter = AVAudioConverter(from: inputFormat, to: whisperFormat)
            print("AudioManager: Created converter from \(inputFormat.sampleRate)Hz to \(Constants.targetSampleRate)Hz")
        } else {
            converter = nil
        }
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            if let converter = converter {
                // Convert to target format
                let frameCapacity = AVAudioFrameCount(
                    Double(buffer.frameLength) * Constants.targetSampleRate / inputFormat.sampleRate
                )
                
                guard let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: whisperFormat,
                    frameCapacity: frameCapacity
                ) else {
                    return
                }
                
                var error: NSError?
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                
                converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
                
                if error == nil {
                    self.audioBuffers.append(convertedBuffer)
                }
            } else {
                self.audioBuffers.append(buffer)
            }
        }
        
        // Start the audio engine
        try audioEngine.start()
        
        isCapturing = true
        captureStartTime = Date()
        print("AudioManager: Started capturing audio")
    }
    
    /// Stop capturing audio and return the result
    func stopCapturing() -> AudioCaptureResult? {
        guard isCapturing else {
            return nil
        }
        
        // Stop engine and remove tap
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        
        isCapturing = false
        
        // Calculate duration
        let duration = captureStartTime.map { Date().timeIntervalSince($0) } ?? 0
        captureStartTime = nil
        
        // Combine buffers into single data
        let audioData = combineBuffersToData()
        
        print("AudioManager: Stopped capturing - Duration: \(String(format: "%.2f", duration))s, Data size: \(audioData.count) bytes")
        
        audioBuffers.removeAll()
        
        return AudioCaptureResult(
            audioData: audioData,
            duration: duration,
            sampleRate: Constants.targetSampleRate
        )
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
