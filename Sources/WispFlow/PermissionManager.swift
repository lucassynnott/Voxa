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
    
    // MARK: - US-507: Automatic Permission Prompting
    
    /// Request microphone permission with system dialog (US-507)
    /// - If .notDetermined: Shows system permission dialog
    /// - If .denied: Opens System Settings directly
    /// - Returns: True if permission is granted after request
    func requestMicrophonePermission() async -> Bool {
        refreshMicrophoneStatus()
        
        switch microphoneStatus {
        case .authorized:
            print("PermissionManager: [US-507] Microphone already authorized")
            return true
            
        case .notDetermined:
            print("PermissionManager: [US-507] Requesting microphone permission (showing system dialog)")
            // Request access using system dialog (not custom alert)
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            refreshMicrophoneStatus()
            print("PermissionManager: [US-507] Microphone permission request result: \(granted)")
            return granted
            
        case .denied, .restricted:
            print("PermissionManager: [US-507] Microphone permission denied - opening System Settings")
            openMicrophoneSettings()
            return false
        }
    }
    
    /// Request accessibility permission with system dialog (US-507)
    /// - If not trusted: Shows system prompt via AXIsProcessTrustedWithOptions
    /// - Returns: True if permission is currently granted (may need re-check after user action)
    func requestAccessibilityPermission() -> Bool {
        refreshAccessibilityStatus()
        
        if accessibilityStatus.isGranted {
            print("PermissionManager: [US-507] Accessibility already authorized")
            return true
        }
        
        print("PermissionManager: [US-507] Requesting accessibility permission (showing system dialog)")
        
        // AXIsProcessTrustedWithOptions with kAXTrustedCheckOptionPrompt shows the system dialog
        // This is the correct way to request accessibility permission on macOS
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        refreshAccessibilityStatus()
        print("PermissionManager: [US-507] Accessibility permission check result: \(trusted)")
        
        // If still not trusted after prompt, open System Settings
        if !trusted {
            print("PermissionManager: [US-507] User needs to manually enable in System Settings")
            openAccessibilitySettings()
        }
        
        return trusted
    }
    
    // MARK: - US-507 & US-508: Open System Settings Helpers
    
    /// Open System Settings to Microphone permission pane (US-507/US-508)
    /// Uses URL scheme: x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone
    func openMicrophoneSettings() {
        print("PermissionManager: [US-508] Opening System Settings > Privacy & Security > Microphone")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback to general Privacy settings if specific pane fails
            print("PermissionManager: [US-508] Falling back to general Privacy settings")
            if let fallbackUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                NSWorkspace.shared.open(fallbackUrl)
            }
        }
    }
    
    /// Open System Settings to Accessibility permission pane (US-507/US-508)
    /// Uses URL scheme: x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility
    func openAccessibilitySettings() {
        print("PermissionManager: [US-508] Opening System Settings > Privacy & Security > Accessibility")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback to general Privacy settings if specific pane fails
            print("PermissionManager: [US-508] Falling back to general Privacy settings")
            if let fallbackUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                NSWorkspace.shared.open(fallbackUrl)
            }
        }
    }
    
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
