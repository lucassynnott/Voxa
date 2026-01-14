import AVFoundation
import AppKit
import Combine

/// US-506: Manages permission status tracking for microphone and accessibility
/// Provides real-time permission status with published properties that trigger UI updates
@MainActor
final class PermissionManager: ObservableObject {
    
    // MARK: - Types
    
    /// Unified permission status enum matching system states
    /// Maps directly to AVAuthorizationStatus for microphone and boolean for accessibility
    enum PermissionStatus: String, Equatable {
        case authorized = "authorized"
        case denied = "denied"
        case notDetermined = "notDetermined"
        case restricted = "restricted"  // iOS only but included for completeness
        
        /// Human-readable description for UI display
        var displayName: String {
            switch self {
            case .authorized:
                return "Granted"
            case .denied:
                return "Denied"
            case .notDetermined:
                return "Not Requested"
            case .restricted:
                return "Restricted"
            }
        }
        
        /// Whether the permission allows the feature to work
        var isGranted: Bool {
            return self == .authorized
        }
    }
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide permission tracking
    static let shared = PermissionManager()
    
    // MARK: - Published Properties (trigger UI updates)
    
    /// Current microphone permission status - checked via AVCaptureDevice.authorizationStatus
    @Published private(set) var microphoneStatus: PermissionStatus = .notDetermined
    
    /// Current accessibility permission status - checked via AXIsProcessTrusted()
    @Published private(set) var accessibilityStatus: PermissionStatus = .notDetermined
    
    // MARK: - Private Properties
    
    /// Observer for app activation to re-check permissions
    private var appActivationObserver: NSObjectProtocol?
    
    /// Timer for polling permissions when not all granted
    private var pollingTimer: Timer?
    
    /// Polling interval in seconds
    private let pollingInterval: TimeInterval = 1.0
    
    // MARK: - Callbacks
    
    /// Called when microphone permission status changes
    var onMicrophoneStatusChanged: ((PermissionStatus) -> Void)?
    
    /// Called when accessibility permission status changes
    var onAccessibilityStatusChanged: ((PermissionStatus) -> Void)?
    
    /// Called when all required permissions are granted
    var onAllPermissionsGranted: (() -> Void)?
    
    // MARK: - Initialization
    
    init() {
        // Check initial permission states
        refreshMicrophoneStatus()
        refreshAccessibilityStatus()
        
        // Set up app activation observer to re-check permissions when user returns from System Settings
        setupAppActivationObserver()
        
        // Start polling if any permission is not yet granted
        if !allPermissionsGranted {
            startPolling()
        }
        
        print("PermissionManager: Initialized - Microphone: \(microphoneStatus.rawValue), Accessibility: \(accessibilityStatus.rawValue)")
    }
    
    deinit {
        pollingTimer?.invalidate()
        if let observer = appActivationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public API
    
    /// Check if all required permissions are granted
    var allPermissionsGranted: Bool {
        return microphoneStatus.isGranted && accessibilityStatus.isGranted
    }
    
    /// Refresh all permission statuses
    func refreshAllStatuses() {
        refreshMicrophoneStatus()
        refreshAccessibilityStatus()
    }
    
    /// Refresh microphone permission status
    /// Uses AVCaptureDevice.authorizationStatus(for: .audio) as required by US-506
    func refreshMicrophoneStatus() {
        let previousStatus = microphoneStatus
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        let newStatus: PermissionStatus
        switch authStatus {
        case .authorized:
            newStatus = .authorized
        case .denied:
            newStatus = .denied
        case .notDetermined:
            newStatus = .notDetermined
        case .restricted:
            newStatus = .restricted
        @unknown default:
            newStatus = .notDetermined
        }
        
        if newStatus != previousStatus {
            microphoneStatus = newStatus
            print("PermissionManager: Microphone status changed: \(previousStatus.rawValue) -> \(newStatus.rawValue)")
            onMicrophoneStatusChanged?(newStatus)
            checkAllPermissionsGranted()
        }
    }
    
    /// Refresh accessibility permission status
    /// Uses AXIsProcessTrusted() as required by US-506
    func refreshAccessibilityStatus() {
        let previousStatus = accessibilityStatus
        let isTrusted = AXIsProcessTrusted()
        
        let newStatus: PermissionStatus = isTrusted ? .authorized : .denied
        
        if newStatus != previousStatus {
            accessibilityStatus = newStatus
            print("PermissionManager: Accessibility status changed: \(previousStatus.rawValue) -> \(newStatus.rawValue)")
            onAccessibilityStatusChanged?(newStatus)
            checkAllPermissionsGranted()
        }
    }
    
    // MARK: - App Activation Observer
    
    /// Set up observer for app activation to re-check permissions (US-506)
    /// This is critical for detecting when user returns from System Settings
    private func setupAppActivationObserver() {
        appActivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                print("PermissionManager: App became active - refreshing permission statuses")
                self.refreshAllStatuses()
            }
        }
    }
    
    // MARK: - Polling
    
    /// Start polling for permission status changes
    private func startPolling() {
        guard pollingTimer == nil else { return }
        
        print("PermissionManager: Starting permission polling (every \(pollingInterval)s)")
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAllStatuses()
            }
        }
    }
    
    /// Stop polling for permission status changes
    private func stopPolling() {
        if let timer = pollingTimer {
            timer.invalidate()
            pollingTimer = nil
            print("PermissionManager: Stopped permission polling")
        }
    }
    
    /// Check if all permissions are granted and stop polling if so
    private func checkAllPermissionsGranted() {
        if allPermissionsGranted {
            stopPolling()
            onAllPermissionsGranted?()
        } else if pollingTimer == nil {
            // Restart polling if permissions were revoked
            startPolling()
        }
    }
}
