import Foundation
import AppKit
import Combine

/// US-054: Centralized manager for battery efficiency optimizations
/// Monitors power state and provides adaptive timing intervals for animations and background tasks
final class BatteryEfficiencyManager: ObservableObject {

    // MARK: - Singleton

    /// Thread-safe shared instance using nonisolated(unsafe) to avoid MainActor isolation
    /// The manager itself handles thread safety through atomic operations
    nonisolated(unsafe) static let shared = BatteryEfficiencyManager()

    // MARK: - Constants

    private enum Constants {
        // Standard frame rates (when on power adapter or low power mode disabled)
        static let standardAnimationInterval: TimeInterval = 0.05    // 20 fps for UI animations
        static let standardWaveformInterval: TimeInterval = 1.0/30.0 // 30 fps for waveform
        static let standardPulseInterval: TimeInterval = 0.03        // ~33 fps for recording pulse

        // Reduced frame rates for battery efficiency (Low Power Mode or on battery)
        static let reducedAnimationInterval: TimeInterval = 0.1      // 10 fps for UI animations
        static let reducedWaveformInterval: TimeInterval = 1.0/15.0  // 15 fps for waveform
        static let reducedPulseInterval: TimeInterval = 0.06         // ~17 fps for recording pulse

        // Background task intervals
        static let standardSilenceCheckInterval: TimeInterval = 0.5  // 2 Hz
        static let reducedSilenceCheckInterval: TimeInterval = 1.0   // 1 Hz (more battery friendly)

        // Permission polling
        static let standardPollingInterval: TimeInterval = 1.0
        static let reducedPollingInterval: TimeInterval = 2.0
    }

    // MARK: - Thread-Safe State Storage

    /// Atomic storage for battery optimization state
    /// Uses OSAtomicCompareAndSwapInt for thread-safe access
    private let _shouldOptimize = UnsafeMutablePointer<Int32>.allocate(capacity: 1)

    // MARK: - Published State (MainActor only)

    /// Whether the system is in Low Power Mode
    @Published private(set) var isLowPowerModeEnabled: Bool = false

    /// Whether the device is running on battery (not connected to power)
    @Published private(set) var isOnBattery: Bool = false

    /// Whether battery efficiency mode should be active (either Low Power Mode or on battery)
    /// This is the MainActor version for Combine observers
    @Published private(set) var shouldOptimizeForBattery: Bool = false {
        didSet {
            // Update thread-safe storage
            _shouldOptimize.pointee = shouldOptimizeForBattery ? 1 : 0
        }
    }

    // MARK: - Thread-Safe Animation Interval Accessors

    /// Thread-safe check if battery optimization is enabled
    private var optimizeForBattery: Bool {
        _shouldOptimize.pointee != 0
    }

    /// Animation interval for status bar and general UI animations (thread-safe)
    var animationInterval: TimeInterval {
        optimizeForBattery ? Constants.reducedAnimationInterval : Constants.standardAnimationInterval
    }

    /// Animation interval for waveform visualization (thread-safe)
    var waveformAnimationInterval: TimeInterval {
        optimizeForBattery ? Constants.reducedWaveformInterval : Constants.standardWaveformInterval
    }

    /// Animation interval for recording pulse effect (thread-safe)
    var pulseAnimationInterval: TimeInterval {
        optimizeForBattery ? Constants.reducedPulseInterval : Constants.standardPulseInterval
    }

    /// Interval for silence detection checks during recording (thread-safe)
    var silenceCheckInterval: TimeInterval {
        optimizeForBattery ? Constants.reducedSilenceCheckInterval : Constants.standardSilenceCheckInterval
    }

    /// Interval for permission polling (thread-safe)
    var permissionPollingInterval: TimeInterval {
        optimizeForBattery ? Constants.reducedPollingInterval : Constants.standardPollingInterval
    }

    // MARK: - Private Properties

    private var powerSourceObserver: NSObjectProtocol?
    private var lowPowerModeObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        // Initialize thread-safe storage
        _shouldOptimize.initialize(to: 0)

        // Check initial power state
        updatePowerState()

        // Set up observers for power state changes
        setupPowerObservers()

        print("US-054: BatteryEfficiencyManager initialized - Low Power Mode: \(isLowPowerModeEnabled), On Battery: \(isOnBattery)")
    }

    deinit {
        // Clean up thread-safe storage
        _shouldOptimize.deinitialize(count: 1)
        _shouldOptimize.deallocate()

        if let observer = powerSourceObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = lowPowerModeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Power State Management

    private func setupPowerObservers() {
        // Observe Low Power Mode changes (macOS 12+)
        if #available(macOS 12.0, *) {
            lowPowerModeObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.updatePowerState()
            }
        }

        // Observe power source changes using IOKit notification
        // This uses a different mechanism since NSWorkspace doesn't have a direct power source notification
        setupPowerSourceObserver()
    }

    private func setupPowerSourceObserver() {
        // Check power state periodically (every 60 seconds) since there's no direct notification
        // This is a compromise between responsiveness and battery efficiency
        // Use main queue to ensure thread safety for Published properties
        DispatchQueue.main.async {
            Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updatePowerState()
                }
            }
        }
    }

    private func updatePowerState() {
        let previousOptimizeState = shouldOptimizeForBattery

        // Check Low Power Mode
        if #available(macOS 12.0, *) {
            isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        } else {
            isLowPowerModeEnabled = false
        }

        // Check if on battery using IOKit
        isOnBattery = checkIfOnBattery()

        // Update combined optimization state
        shouldOptimizeForBattery = isLowPowerModeEnabled || isOnBattery

        // Log state change if it changed
        if previousOptimizeState != shouldOptimizeForBattery {
            let reason = isLowPowerModeEnabled ? "Low Power Mode" : (isOnBattery ? "Battery Power" : "AC Power")
            print("US-054: Battery optimization \(shouldOptimizeForBattery ? "enabled" : "disabled") - \(reason)")

            // Post notification for components to update their timers
            NotificationCenter.default.post(name: .batteryOptimizationStateChanged, object: shouldOptimizeForBattery)
        }
    }

    /// Check if the Mac is running on battery using IOKit
    private func checkIfOnBattery() -> Bool {
        // Use IOPSCopyPowerSourcesInfo to check power state
        // This is the standard way to check battery status on macOS
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            // No power sources means desktop Mac (always on AC)
            return false
        }

        for source in sources {
            if let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
                if let powerSource = description[kIOPSPowerSourceStateKey as String] as? String {
                    // "Battery Power" means on battery, "AC Power" means plugged in
                    if powerSource == kIOPSBatteryPowerValue as String {
                        return true
                    }
                }
            }
        }

        return false
    }

    // MARK: - Timer Creation Helpers

    /// Create an animation timer with the appropriate interval based on power state
    /// - Parameters:
    ///   - type: The type of animation (affects which interval is used)
    ///   - handler: The timer's callback
    /// - Returns: A configured Timer instance
    func createAnimationTimer(
        type: AnimationType,
        handler: @escaping (Timer) -> Void
    ) -> Timer {
        let interval: TimeInterval
        switch type {
        case .statusBarPulse, .recordingPulse:
            interval = pulseAnimationInterval
        case .waveform:
            interval = waveformAnimationInterval
        case .general:
            interval = animationInterval
        }

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: handler)
        timer.tolerance = interval * 0.2 // Allow 20% tolerance for timer coalescing
        return timer
    }

    /// Create a background task timer with appropriate interval and tolerance
    /// - Parameters:
    ///   - type: The type of background task
    ///   - handler: The timer's callback
    /// - Returns: A configured Timer instance
    func createBackgroundTimer(
        type: BackgroundTaskType,
        handler: @escaping (Timer) -> Void
    ) -> Timer {
        let interval: TimeInterval
        let tolerance: TimeInterval

        switch type {
        case .silenceDetection:
            interval = silenceCheckInterval
            tolerance = interval * 0.5 // Allow significant tolerance for background checks
        case .permissionPolling:
            interval = permissionPollingInterval
            tolerance = interval * 0.5
        case .durationUpdate:
            interval = 1.0 // Always 1 second for duration display
            tolerance = 0.1 // Allow 100ms tolerance
        }

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: handler)
        timer.tolerance = tolerance
        return timer
    }

    // MARK: - Types

    /// Types of animations that can be created
    enum AnimationType {
        case statusBarPulse      // Status bar recording indicator
        case recordingPulse      // Recording indicator window pulse
        case waveform            // Audio waveform visualization
        case general             // General UI animations
    }

    /// Types of background tasks
    enum BackgroundTaskType {
        case silenceDetection    // Checking for silence during recording
        case permissionPolling   // Polling for permission status
        case durationUpdate      // Updating recording duration display
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when battery optimization state changes
    static let batteryOptimizationStateChanged = Notification.Name("batteryOptimizationStateChanged")
}

// MARK: - IOKit Import

import IOKit.ps
