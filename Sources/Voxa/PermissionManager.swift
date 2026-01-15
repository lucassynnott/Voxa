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
    
    // MARK: - UserDefaults Keys for Persistent Permission Tracking
    
    private enum PermissionKeys {
        static let accessibilityWasRequested = "PermissionManager.accessibilityWasRequested"
        static let accessibilityLastKnownStatus = "PermissionManager.accessibilityLastKnownStatus"
        static let microphoneLastKnownStatus = "PermissionManager.microphoneLastKnownStatus"
    }
    
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
    
    /// Track if accessibility permission was ever requested (persisted)
    private var accessibilityWasRequested: Bool {
        get { UserDefaults.standard.bool(forKey: PermissionKeys.accessibilityWasRequested) }
        set { UserDefaults.standard.set(newValue, forKey: PermissionKeys.accessibilityWasRequested) }
    }
    
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
    /// - Parameter openSettingsIfNeeded: If true and permission is denied, opens System Settings. Default false.
    /// - If not trusted: Shows system prompt via AXIsProcessTrustedWithOptions
    /// - Returns: True if permission is currently granted (may need re-check after user action)
    func requestAccessibilityPermission(openSettingsIfNeeded: Bool = false) -> Bool {
        refreshAccessibilityStatus()
        
        if accessibilityStatus.isGranted {
            print("PermissionManager: [US-507] Accessibility already authorized")
            return true
        }
        
        print("PermissionManager: [US-507] Requesting accessibility permission (showing system dialog)")
        
        // Mark that we've requested accessibility permission
        accessibilityWasRequested = true
        
        // AXIsProcessTrustedWithOptions with kAXTrustedCheckOptionPrompt shows the system dialog
        // This is the correct way to request accessibility permission on macOS
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        refreshAccessibilityStatus()
        print("PermissionManager: [US-507] Accessibility permission check result: \(trusted)")
        
        // Only open System Settings if explicitly requested AND not trusted
        // This prevents multiple windows/popups appearing at once
        if !trusted && openSettingsIfNeeded {
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
        // Load last known statuses from persistent storage for quick startup
        // This prevents the UI from briefly showing "not determined" before refreshing
        if let savedMicStatus = UserDefaults.standard.string(forKey: PermissionKeys.microphoneLastKnownStatus),
           let status = PermissionStatus(rawValue: savedMicStatus) {
            microphoneStatus = status
            print("PermissionManager: Loaded cached microphone status: \(status.rawValue)")
        }
        
        if let savedAccessStatus = UserDefaults.standard.string(forKey: PermissionKeys.accessibilityLastKnownStatus),
           let status = PermissionStatus(rawValue: savedAccessStatus) {
            accessibilityStatus = status
            print("PermissionManager: Loaded cached accessibility status: \(status.rawValue)")
        }
        
        // Now check actual permission states (will update if different from cached)
        refreshMicrophoneStatus()
        refreshAccessibilityStatus()
        
        // Set up app activation observer to re-check permissions when user returns from System Settings
        setupAppActivationObserver()
        
        // Start polling if permissions are not all granted to detect changes in real-time
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
        
        // Persist the status for quick startup
        UserDefaults.standard.set(newStatus.rawValue, forKey: PermissionKeys.microphoneLastKnownStatus)
        
        if newStatus != previousStatus {
            microphoneStatus = newStatus
            print("PermissionManager: Microphone status changed: \(previousStatus.rawValue) -> \(newStatus.rawValue)")
            onMicrophoneStatusChanged?(newStatus)
            checkAllPermissionsGranted()
        }
    }
    
    /// Refresh accessibility permission status
    /// Uses AXIsProcessTrusted() as required by US-506
    /// Note: AXIsProcessTrusted() only returns a boolean, so we use persistent storage
    /// to distinguish between "never requested" and "denied"
    func refreshAccessibilityStatus() {
        let previousStatus = accessibilityStatus
        let isTrusted = AXIsProcessTrusted()
        
        let newStatus: PermissionStatus
        if isTrusted {
            newStatus = .authorized
            // If granted, mark as requested (user may have granted via System Preferences directly)
            if !accessibilityWasRequested {
                accessibilityWasRequested = true
            }
        } else {
            // If not trusted and we've previously requested, it's denied
            // If never requested, it's not determined
            newStatus = accessibilityWasRequested ? .denied : .notDetermined
        }
        
        // Persist the status for quick startup
        UserDefaults.standard.set(newStatus.rawValue, forKey: PermissionKeys.accessibilityLastKnownStatus)
        
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
            // Use Task to safely dispatch to MainActor
            Task { @MainActor in
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
        
        // Create timer on main run loop since PermissionManager is @MainActor
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            // Use Task to safely dispatch to MainActor
            Task { @MainActor in
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
