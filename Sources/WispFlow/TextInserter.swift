import AppKit
import Foundation

/// Manages text insertion into the active application using pasteboard and simulated keystrokes
/// Requires accessibility permissions to simulate Cmd+V keystroke
@MainActor
final class TextInserter: ObservableObject {
    
    // MARK: - Types
    
    /// Insertion result
    enum InsertionResult {
        case success
        case noAccessibilityPermission
        case insertionFailed(String)
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
        static let defaultRestoreDelay: Double = 0.5  // seconds
        static let keystrokeDelay: UInt32 = 50_000    // 50ms in microseconds
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
    
    // MARK: - Callbacks
    
    /// Called when insertion completes successfully
    var onInsertionComplete: (() -> Void)?
    
    /// Called when an error occurs
    var onError: ((String) -> Void)?
    
    // MARK: - Private Properties
    
    /// Stored clipboard contents for restoration
    private var savedClipboardItems: [NSPasteboardItem]?
    
    // MARK: - Initialization
    
    init() {
        // Load saved preferences
        preserveClipboard = UserDefaults.standard.object(forKey: Constants.preserveClipboardKey) as? Bool ?? true
        clipboardRestoreDelay = UserDefaults.standard.object(forKey: Constants.clipboardRestoreDelayKey) as? Double ?? Constants.defaultRestoreDelay
        
        print("TextInserter initialized (preserveClipboard: \(preserveClipboard), restoreDelay: \(clipboardRestoreDelay)s)")
    }
    
    // MARK: - Accessibility Permissions
    
    /// Check if accessibility permissions are granted
    var hasAccessibilityPermission: Bool {
        return AXIsProcessTrusted()
    }
    
    /// Request accessibility permissions
    /// - Parameter showPrompt: If true, shows the system prompt for enabling accessibility
    /// - Returns: True if permissions are already granted
    func requestAccessibilityPermission(showPrompt: Bool = true) -> Bool {
        let options: [String: Any]
        if showPrompt {
            options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        } else {
            options = [:]
        }
        
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !trusted {
            print("Accessibility permission not granted")
            showAccessibilityPermissionAlert()
        }
        
        return trusted
    }
    
    /// Show an alert guiding the user to enable accessibility permissions
    private func showAccessibilityPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "WispFlow needs accessibility permission to insert text into other applications.\n\nPlease enable WispFlow in System Settings > Privacy & Security > Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        
        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
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
        // Check accessibility permission first
        guard hasAccessibilityPermission else {
            print("TextInserter: No accessibility permission")
            _ = requestAccessibilityPermission(showPrompt: true)
            insertionStatus = .error("Accessibility permission required")
            statusMessage = "Please grant accessibility permission"
            onError?("Accessibility permission required")
            return .noAccessibilityPermission
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
        
        // Small delay to ensure pasteboard is ready
        usleep(Constants.keystrokeDelay)
        
        // Simulate Cmd+V keystroke
        let result = simulatePaste()
        
        switch result {
        case .success:
            insertionStatus = .completed
            statusMessage = "Text inserted successfully"
            print("TextInserter: Text inserted successfully")
            onInsertionComplete?()
            
            // Restore clipboard if needed (with delay)
            if preserveClipboard {
                scheduleClipboardRestore()
            }
            
        case .insertionFailed(let message):
            insertionStatus = .error(message)
            statusMessage = message
            onError?(message)
            
            // Still restore clipboard on failure if we saved it
            if preserveClipboard {
                restoreClipboardContents()
            }
            
        case .noAccessibilityPermission:
            // Should not happen since we checked above
            break
        }
        
        return result
    }
    
    /// Simulate Cmd+V (paste) keystroke
    private func simulatePaste() -> InsertionResult {
        // Create key down event for 'V' with Command modifier
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true) else {
            print("TextInserter: Failed to create key down event")
            return .insertionFailed("Failed to create keyboard event")
        }
        
        // Create key up event for 'V'
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false) else {
            print("TextInserter: Failed to create key up event")
            return .insertionFailed("Failed to create keyboard event")
        }
        
        // Set Command modifier
        keyDownEvent.flags = .maskCommand
        keyUpEvent.flags = .maskCommand
        
        // Post the events
        keyDownEvent.post(tap: .cghidEventTap)
        
        // Small delay between key down and key up
        usleep(Constants.keystrokeDelay)
        
        keyUpEvent.post(tap: .cghidEventTap)
        
        return .success
    }
    
    // MARK: - Clipboard Preservation
    
    /// Save the current clipboard contents
    private func saveClipboardContents() {
        let pasteboard = NSPasteboard.general
        
        // Get all items on the pasteboard
        guard let items = pasteboard.pasteboardItems else {
            savedClipboardItems = nil
            print("TextInserter: No clipboard items to save")
            return
        }
        
        // Create copies of the items
        savedClipboardItems = items.compactMap { item -> NSPasteboardItem? in
            let newItem = NSPasteboardItem()
            
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                }
            }
            
            return newItem.types.isEmpty ? nil : newItem
        }
        
        print("TextInserter: Saved \(savedClipboardItems?.count ?? 0) clipboard items")
    }
    
    /// Schedule clipboard restoration after a delay
    private func scheduleClipboardRestore() {
        let delay = clipboardRestoreDelay
        
        Task {
            // Wait for the delay
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            // Restore on main actor
            await MainActor.run {
                restoreClipboardContents()
            }
        }
    }
    
    /// Restore the previously saved clipboard contents
    private func restoreClipboardContents() {
        guard let items = savedClipboardItems, !items.isEmpty else {
            print("TextInserter: No clipboard items to restore")
            savedClipboardItems = nil
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
        
        print("TextInserter: Restored \(items.count) clipboard items")
        savedClipboardItems = nil
    }
    
    // MARK: - Status
    
    /// Reset insertion status to idle
    func resetStatus() {
        insertionStatus = .idle
        statusMessage = "Ready"
    }
}
