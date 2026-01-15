import AppKit
import Foundation

/// Manages text insertion into the active application using pasteboard and simulated keystrokes
/// Requires accessibility permissions to simulate Cmd+V keystroke
@MainActor
final class TextInserter: ObservableObject {
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide access
    /// US-701: Added for SettingsContentView in MainWindow
    static let shared = TextInserter()
    
    // MARK: - Types
    
    /// Insertion result
    enum InsertionResult {
        case success
        case noAccessibilityPermission
        case insertionFailed(String)
        /// US-515: Paste simulation failed but text is on clipboard for manual paste
        case fallbackToManualPaste(String)
    }
    
    /// Insertion status for UI feedback
    enum InsertionStatus: Equatable {
        case idle
        case inserting
        case completed
        case error(String)
    }
    
    // MARK: - Constants
    
    private struct Constants {
        static let preserveClipboardKey = "preserveClipboard"
        static let clipboardRestoreDelayKey = "clipboardRestoreDelay"
        static let defaultRestoreDelay: Double = 0.8  // US-513: 800ms as per acceptance criteria
        static let keystrokeDelay: UInt32 = 10_000    // US-514: 10ms in microseconds between key down and key up
        static let pasteboardReadyDelay: UInt32 = 50_000  // 50ms to ensure pasteboard is ready before paste
        static let permissionPollingInterval: TimeInterval = 1.0  // 1 second polling
    }
    
    // MARK: - Properties
    
    /// Whether to preserve and restore clipboard contents after insertion
    @Published var preserveClipboard: Bool {
        didSet {
            UserDefaults.standard.set(preserveClipboard, forKey: Constants.preserveClipboardKey)
        }
    }
    
    /// Delay before restoring clipboard contents (in seconds)
    @Published var clipboardRestoreDelay: Double {
        didSet {
            UserDefaults.standard.set(clipboardRestoreDelay, forKey: Constants.clipboardRestoreDelayKey)
        }
    }
    
    /// Current insertion status
    @Published private(set) var insertionStatus: InsertionStatus = .idle
    
    /// Status message for UI display
    @Published private(set) var statusMessage: String = "Ready"
    
    /// Current accessibility permission status (updated reactively)
    @Published private(set) var hasAccessibilityPermission: Bool = false
    
    // MARK: - Callbacks
    
    /// Called when insertion completes successfully
    var onInsertionComplete: (() -> Void)?
    
    /// Called when an error occurs
    var onError: ((String) -> Void)?
    
    /// Called when permission status changes from denied to granted
    var onPermissionGranted: (() -> Void)?
    
    // MARK: - Private Properties
    
    /// Stored clipboard contents for restoration
    private var savedClipboardItems: [NSPasteboardItem]?
    
    /// Timer for polling permission status when not granted
    private var permissionPollingTimer: Timer?
    
    /// Observer for app activation to re-check permissions
    private var appActivationObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    
    init() {
        // Load saved preferences
        preserveClipboard = UserDefaults.standard.object(forKey: Constants.preserveClipboardKey) as? Bool ?? true
        clipboardRestoreDelay = UserDefaults.standard.object(forKey: Constants.clipboardRestoreDelayKey) as? Double ?? Constants.defaultRestoreDelay
        
        // Check initial permission status
        hasAccessibilityPermission = AXIsProcessTrusted()
        
        // Set up app activation observer to re-check permissions when user returns from System Settings
        setupAppActivationObserver()
        
        // NOTE: Disabled automatic polling to prevent potential main thread blocking
        // Permissions will be refreshed when app becomes active or manually checked
        // if !hasAccessibilityPermission {
        //     startPermissionPolling()
        // }
        
        print("TextInserter initialized (preserveClipboard: \(preserveClipboard), restoreDelay: \(clipboardRestoreDelay)s, permission: \(hasAccessibilityPermission))")
    }
    
    deinit {
        // Invalidate timer directly without calling the main actor method
        permissionPollingTimer?.invalidate()
        if let observer = appActivationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Permission Monitoring
    
    /// Set up observer for app activation to re-check permissions
    private func setupAppActivationObserver() {
        appActivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Use Task to safely dispatch to MainActor
            Task { @MainActor in
                self?.recheckPermission()
            }
        }
    }
    
    /// Start polling for permission status
    private func startPermissionPolling() {
        guard permissionPollingTimer == nil else { return }
        
        print("TextInserter: Starting permission polling (every \(Constants.permissionPollingInterval)s)")
        
        // Timer fires on main thread, use Task to dispatch to MainActor
        permissionPollingTimer = Timer.scheduledTimer(withTimeInterval: Constants.permissionPollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recheckPermission()
            }
        }
    }
    
    /// Stop polling for permission status
    private func stopPermissionPolling() {
        if let timer = permissionPollingTimer {
            timer.invalidate()
            permissionPollingTimer = nil
            print("TextInserter: Stopped permission polling")
        }
    }
    
    /// Re-check accessibility permission status (fresh check, not cached)
    func recheckPermission() {
        let previousStatus = hasAccessibilityPermission
        let currentStatus = AXIsProcessTrusted()
        
        if currentStatus != previousStatus {
            hasAccessibilityPermission = currentStatus
            print("TextInserter: Permission status changed: \(previousStatus) -> \(currentStatus)")
            
            if currentStatus {
                // Permission was just granted
                stopPermissionPolling()
                onPermissionGranted?()
            } else {
                // Permission was revoked (rare but possible)
                startPermissionPolling()
            }
        }
    }
    
    // MARK: - Accessibility Permissions
    
    /// Request accessibility permissions
    /// - Parameter showPrompt: If true, shows the system prompt for enabling accessibility
    /// - Returns: True if permissions are already granted
    func requestAccessibilityPermission(showPrompt: Bool = true) -> Bool {
        let options: [String: Any]
        if showPrompt {
            // AXIsProcessTrustedWithOptions with kAXTrustedCheckOptionPrompt shows the SYSTEM dialog
            // We should NOT show our own alert on top of it
            options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        } else {
            options = [:]
        }
        
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !trusted {
            print("Accessibility permission not granted")
            // NOTE: Don't show our own alert - the system dialog is already shown (if showPrompt=true)
            // or onboarding/settings will guide the user
        }
        
        return trusted
    }
    
    /// Open System Settings to the Accessibility pane
    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Text Insertion
    
    /// Insert text into the active application
    /// - Parameter text: The text to insert
    /// - Returns: The result of the insertion attempt
    func insertText(_ text: String) async -> InsertionResult {
        // US-507: Check accessibility permission first and prompt automatically if needed
        // If not granted, use PermissionManager for consistent prompting behavior
        if !hasAccessibilityPermission {
            print("TextInserter: [US-507] No accessibility permission on first text insertion attempt")
            
            // Use PermissionManager for automatic prompting (shows system dialog)
            // This ensures consistent behavior with microphone permission prompting
            _ = PermissionManager.shared.requestAccessibilityPermission()
            
            // Re-check our local status after the prompt
            recheckPermission()
            
            if !hasAccessibilityPermission {
                print("TextInserter: [US-507] Accessibility permission still not granted after prompt")
                insertionStatus = .error("Accessibility permission required")
                statusMessage = "Please grant accessibility permission in System Settings"
                onError?("Accessibility permission required")
                return .noAccessibilityPermission
            }
            
            print("TextInserter: [US-507] Accessibility permission granted, proceeding with insertion")
        }
        
        insertionStatus = .inserting
        statusMessage = "Inserting text..."
        
        // Save current clipboard if needed
        if preserveClipboard {
            saveClipboardContents()
        }
        
        // Copy text to pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        
        guard success else {
            insertionStatus = .error("Failed to copy to clipboard")
            statusMessage = "Failed to copy text to clipboard"
            onError?("Failed to copy text to clipboard")
            return .insertionFailed("Failed to copy text to clipboard")
        }
        
        // Small delay to ensure pasteboard is ready before simulating paste
        usleep(Constants.pasteboardReadyDelay)
        
        // Simulate Cmd+V keystroke
        let simulationResult = simulatePaste()
        
        switch simulationResult {
        case .success:
            insertionStatus = .completed
            statusMessage = "Text inserted successfully"
            print("TextInserter: Text inserted successfully")
            onInsertionComplete?()
            
            // Restore clipboard if needed (with delay)
            if preserveClipboard {
                scheduleClipboardRestore()
            }
            return .success
            
        case .insertionFailed(let message):
            // US-515: Fallback - text is already on clipboard, show toast for manual paste
            print("TextInserter: [US-515] Paste simulation failed, falling back to manual paste")
            print("TextInserter: [US-515] Error details: \(message)")
            
            // Log detailed error
            logSimulationError(message, phase: "pasteSimulation")
            
            // Update status to indicate fallback
            insertionStatus = .error("Paste failed - use Cmd+V manually")
            statusMessage = "Text copied - press Cmd+V to paste"
            
            // US-515: Show toast notification to user
            // Text is already on clipboard from the earlier setString call
            DispatchQueue.main.async {
                ToastManager.shared.showManualPasteRequired()
            }
            
            // US-515: Do NOT restore original clipboard - user needs to paste manually
            // Clear the saved items so they don't get restored
            savedClipboardItems = nil
            
            // Notify error handler but with context that fallback is in effect
            onError?("Paste simulation failed - text copied to clipboard for manual paste")
            
            return .fallbackToManualPaste(message)
            
        case .noAccessibilityPermission:
            // Should not happen since we checked above
            return .noAccessibilityPermission
            
        case .fallbackToManualPaste:
            // Should not happen from simulatePaste()
            return simulationResult
        }
    }
    
    /// US-514: Simulate Cmd+V (paste) keystroke using CGEvent
    /// US-515: Returns detailed error information for fallback handling
    /// 
    /// Implementation details per US-514 acceptance criteria:
    /// - Uses CGEvent for key simulation (not AppleScript)
    /// - Key down event with Command modifier
    /// - Small delay between down and up (10ms)
    /// - Key up event with Command modifier  
    /// - Events posted to HID event tap location (.cghidEventTap)
    /// - Works in all applications including Electron apps
    ///
    /// The virtual key code 0x09 corresponds to 'V' on ANSI keyboards (kVK_ANSI_V).
    /// CGEvent posting at .cghidEventTap level ensures events are processed by the
    /// window server and delivered to any focused application, including:
    /// - Native macOS apps (AppKit, SwiftUI)
    /// - Electron-based apps (VS Code, Slack, Discord, etc.)
    /// - Cross-platform apps (Java, Qt, etc.)
    ///
    /// US-515: If simulation fails, returns a detailed error for fallback handling
    private func simulatePaste() -> InsertionResult {
        print("TextInserter: [US-514] Simulating Cmd+V using CGEvent")
        
        // US-514: Create key down event for 'V' with Command modifier
        // Virtual key code 0x09 = kVK_ANSI_V (the 'V' key on ANSI keyboards)
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true) else {
            let errorMsg = "Failed to create key down event - CGEvent initialization returned nil"
            print("TextInserter: [US-515] \(errorMsg)")
            logSimulationError(errorMsg, phase: "keyDownCreation")
            return .insertionFailed(errorMsg)
        }
        
        // US-514: Create key up event for 'V'
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false) else {
            let errorMsg = "Failed to create key up event - CGEvent initialization returned nil"
            print("TextInserter: [US-515] \(errorMsg)")
            logSimulationError(errorMsg, phase: "keyUpCreation")
            return .insertionFailed(errorMsg)
        }
        
        // US-514: Set Command modifier flag on both events
        keyDownEvent.flags = .maskCommand
        keyUpEvent.flags = .maskCommand
        
        // US-514: Post key down event to HID event tap location
        // .cghidEventTap ensures events are processed like real keyboard input,
        // making it work in all applications including Electron apps
        keyDownEvent.post(tap: .cghidEventTap)
        
        // US-514: Small delay between key down and key up (10ms)
        // This delay ensures the target application properly registers the key press
        usleep(Constants.keystrokeDelay)  // 10,000 microseconds = 10ms
        
        // US-514: Post key up event to HID event tap location
        keyUpEvent.post(tap: .cghidEventTap)
        
        print("TextInserter: [US-514] Cmd+V simulated successfully via CGEvent at .cghidEventTap")
        return .success
    }
    
    /// US-515: Log detailed error information when keyboard simulation fails
    private func logSimulationError(_ message: String, phase: String) {
        print("""
        ╔════════════════════════════════════════════════════════════╗
        ║ [US-515] KEYBOARD SIMULATION ERROR                         ║
        ╠════════════════════════════════════════════════════════════╣
        ║ Phase: \(phase.padding(toLength: 50, withPad: " ", startingAt: 0)) ║
        ║ Error: \(message.prefix(50).padding(toLength: 50, withPad: " ", startingAt: 0)) ║
        ║ Accessibility: \(hasAccessibilityPermission ? "granted" : "denied").padding(toLength: 43, withPad: " ", startingAt: 0) ║
        ║ Timestamp: \(ISO8601DateFormatter().string(from: Date()).padding(toLength: 47, withPad: " ", startingAt: 0)) ║
        ╚════════════════════════════════════════════════════════════╝
        """)
    }
    
    // MARK: - Clipboard Preservation
    
    /// Save the current clipboard contents
    /// US-513: Saves clipboard before text insertion so it can be restored after paste
    private func saveClipboardContents() {
        let pasteboard = NSPasteboard.general
        
        // Get all items on the pasteboard
        guard let items = pasteboard.pasteboardItems else {
            savedClipboardItems = nil
            print("TextInserter: [US-513] No clipboard items to save (pasteboard empty)")
            return
        }
        
        // Create copies of the items (deep copy to preserve data)
        savedClipboardItems = items.compactMap { item -> NSPasteboardItem? in
            let newItem = NSPasteboardItem()
            
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                }
            }
            
            return newItem.types.isEmpty ? nil : newItem
        }
        
        // Log what was saved for debugging
        let itemCount = savedClipboardItems?.count ?? 0
        if itemCount > 0 {
            // Get a preview of saved content for debugging
            let preview = pasteboard.string(forType: .string)?.prefix(50) ?? "(non-text content)"
            print("TextInserter: [US-513] Saved \(itemCount) clipboard items (preview: \(preview))")
        } else {
            print("TextInserter: [US-513] No clipboard items to save")
        }
    }
    
    /// Schedule clipboard restoration after a delay
    /// US-513: Restoration happens in background thread to avoid blocking main thread
    private func scheduleClipboardRestore() {
        let delay = clipboardRestoreDelay
        let itemsToRestore = savedClipboardItems
        
        // Clear our reference since background thread will handle restoration
        savedClipboardItems = nil
        
        guard let items = itemsToRestore, !items.isEmpty else {
            print("TextInserter: [US-513] No items to schedule for restoration")
            return
        }
        
        // US-513: Use background thread for the delay, then dispatch to main for pasteboard access
        // Use @Sendable closure to satisfy Swift concurrency requirements
        DispatchQueue.global(qos: .utility).async { [items] in
            // Wait for the configured delay (800ms by default)
            Thread.sleep(forTimeInterval: delay)
            
            // Pasteboard operations must happen on main thread
            DispatchQueue.main.async {
                self.restoreClipboardContentsSync(items: items)
            }
        }
    }
    
    /// Restore clipboard contents synchronously (called from main thread after background delay)
    /// US-513: This is the actual restoration logic, separated for clarity
    private func restoreClipboardContentsSync(items: [NSPasteboardItem]?) {
        guard let items = items, !items.isEmpty else {
            print("TextInserter: [US-513] No clipboard items to restore")
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
        
        print("TextInserter: [US-513] Restored \(items.count) clipboard items after delay")
    }
    
    /// Restore the previously saved clipboard contents (immediate, used on error)
    /// US-513: Called immediately on insertion failure to restore clipboard
    private func restoreClipboardContents() {
        guard let items = savedClipboardItems, !items.isEmpty else {
            print("TextInserter: [US-513] No clipboard items to restore (immediate)")
            savedClipboardItems = nil
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
        
        print("TextInserter: [US-513] Restored \(items.count) clipboard items (immediate, on error)")
        savedClipboardItems = nil
    }
    
    // MARK: - Status
    
    /// Reset insertion status to idle
    func resetStatus() {
        insertionStatus = .idle
        statusMessage = "Ready"
    }
}
