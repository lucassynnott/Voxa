import AppKit
import Carbon.HIToolbox

/// US-510: Manager for handling global keyboard shortcuts
/// Uses CGEvent tap at kCGSessionEventTap level for reliable global hotkey detection
/// that works regardless of which app is focused and even when Voxa window is not visible.
final class HotkeyManager: ObservableObject {
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide access
    /// US-701: Added for SettingsContentView in MainWindow
    static let shared = HotkeyManager()
    
    // MARK: - Constants

    private struct Constants {
        static let hotkeyKeyCodeKey = "hotkeyKeyCode"
        static let hotkeyModifiersKey = "hotkeyModifiers"
        // US-015: Stop hotkey configuration keys
        static let stopHotkeyKeyCodeKey = "stopHotkeyKeyCode"
        static let stopHotkeyModifiersKey = "stopHotkeyModifiers"
        static let useSameHotkeyForStopKey = "useSameHotkeyForStop"
    }
    
    // MARK: - US-512: System Shortcut Conflicts
    
    /// Represents a known system shortcut that may conflict with user-defined hotkeys
    struct SystemShortcut: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let keyCode: UInt16
        let modifierFlags: NSEvent.ModifierFlags
        let description: String
        
        /// Check if this shortcut matches the given configuration
        func matches(_ config: HotkeyConfiguration) -> Bool {
            return keyCode == config.keyCode && modifierFlags == config.modifiers
        }
    }
    
    /// US-512: List of common system shortcuts that may conflict with user hotkeys
    static let systemShortcuts: [SystemShortcut] = [
        // Spotlight
        SystemShortcut(
            name: "Spotlight",
            keyCode: UInt16(kVK_Space),
            modifierFlags: [.command],
            description: "Opens Spotlight search"
        ),
        // App Switcher
        SystemShortcut(
            name: "App Switcher",
            keyCode: UInt16(kVK_Tab),
            modifierFlags: [.command],
            description: "Switches between apps"
        ),
        // Hide Application
        SystemShortcut(
            name: "Hide App",
            keyCode: UInt16(kVK_ANSI_H),
            modifierFlags: [.command],
            description: "Hides current application"
        ),
        // Hide Others
        SystemShortcut(
            name: "Hide Others",
            keyCode: UInt16(kVK_ANSI_H),
            modifierFlags: [.command, .option],
            description: "Hides all other applications"
        ),
        // Minimize
        SystemShortcut(
            name: "Minimize",
            keyCode: UInt16(kVK_ANSI_M),
            modifierFlags: [.command],
            description: "Minimizes current window"
        ),
        // Force Quit
        SystemShortcut(
            name: "Force Quit",
            keyCode: UInt16(kVK_Escape),
            modifierFlags: [.command, .option],
            description: "Opens Force Quit dialog"
        ),
        // Screenshot (full screen)
        SystemShortcut(
            name: "Screenshot",
            keyCode: UInt16(kVK_ANSI_3),
            modifierFlags: [.command, .shift],
            description: "Takes full screen screenshot"
        ),
        // Screenshot (selection)
        SystemShortcut(
            name: "Screenshot Selection",
            keyCode: UInt16(kVK_ANSI_4),
            modifierFlags: [.command, .shift],
            description: "Takes screenshot of selection"
        ),
        // Screenshot menu
        SystemShortcut(
            name: "Screenshot Menu",
            keyCode: UInt16(kVK_ANSI_5),
            modifierFlags: [.command, .shift],
            description: "Opens screenshot menu"
        ),
        // Mission Control
        SystemShortcut(
            name: "Mission Control",
            keyCode: UInt16(kVK_UpArrow),
            modifierFlags: [.control],
            description: "Opens Mission Control"
        ),
        // Application Windows
        SystemShortcut(
            name: "Application Windows",
            keyCode: UInt16(kVK_DownArrow),
            modifierFlags: [.control],
            description: "Shows application windows"
        ),
        // Move Left Space
        SystemShortcut(
            name: "Move Left Space",
            keyCode: UInt16(kVK_LeftArrow),
            modifierFlags: [.control],
            description: "Moves to left space"
        ),
        // Move Right Space
        SystemShortcut(
            name: "Move Right Space",
            keyCode: UInt16(kVK_RightArrow),
            modifierFlags: [.control],
            description: "Moves to right space"
        ),
        // Quit
        SystemShortcut(
            name: "Quit",
            keyCode: UInt16(kVK_ANSI_Q),
            modifierFlags: [.command],
            description: "Quits current application"
        ),
        // Close Window
        SystemShortcut(
            name: "Close Window",
            keyCode: UInt16(kVK_ANSI_W),
            modifierFlags: [.command],
            description: "Closes current window"
        ),
        // Select All
        SystemShortcut(
            name: "Select All",
            keyCode: UInt16(kVK_ANSI_A),
            modifierFlags: [.command],
            description: "Selects all content"
        ),
        // Copy
        SystemShortcut(
            name: "Copy",
            keyCode: UInt16(kVK_ANSI_C),
            modifierFlags: [.command],
            description: "Copies to clipboard"
        ),
        // Paste
        SystemShortcut(
            name: "Paste",
            keyCode: UInt16(kVK_ANSI_V),
            modifierFlags: [.command],
            description: "Pastes from clipboard"
        ),
        // Cut
        SystemShortcut(
            name: "Cut",
            keyCode: UInt16(kVK_ANSI_X),
            modifierFlags: [.command],
            description: "Cuts to clipboard"
        ),
        // Undo
        SystemShortcut(
            name: "Undo",
            keyCode: UInt16(kVK_ANSI_Z),
            modifierFlags: [.command],
            description: "Undoes last action"
        ),
        // Redo
        SystemShortcut(
            name: "Redo",
            keyCode: UInt16(kVK_ANSI_Z),
            modifierFlags: [.command, .shift],
            description: "Redoes last action"
        ),
        // Find
        SystemShortcut(
            name: "Find",
            keyCode: UInt16(kVK_ANSI_F),
            modifierFlags: [.command],
            description: "Opens find dialog"
        ),
        // New
        SystemShortcut(
            name: "New",
            keyCode: UInt16(kVK_ANSI_N),
            modifierFlags: [.command],
            description: "Creates new item"
        ),
        // Open
        SystemShortcut(
            name: "Open",
            keyCode: UInt16(kVK_ANSI_O),
            modifierFlags: [.command],
            description: "Opens file dialog"
        ),
        // Save
        SystemShortcut(
            name: "Save",
            keyCode: UInt16(kVK_ANSI_S),
            modifierFlags: [.command],
            description: "Saves current document"
        ),
        // Print
        SystemShortcut(
            name: "Print",
            keyCode: UInt16(kVK_ANSI_P),
            modifierFlags: [.command],
            description: "Opens print dialog"
        ),
        // Siri (on supported Macs)
        SystemShortcut(
            name: "Siri",
            keyCode: UInt16(kVK_Space),
            modifierFlags: [.command, .option],
            description: "Activates Siri"
        ),
    ]
    
    /// US-512: Check if a hotkey configuration conflicts with known system shortcuts
    /// - Parameter config: The hotkey configuration to check
    /// - Returns: Array of conflicting system shortcuts, empty if no conflicts
    static func checkForConflicts(_ config: HotkeyConfiguration) -> [SystemShortcut] {
        return systemShortcuts.filter { $0.matches(config) }
    }
    
    /// US-512: Check if a hotkey configuration conflicts with system shortcuts
    /// - Parameter config: The hotkey configuration to check
    /// - Returns: True if there are any conflicts
    static func hasConflicts(_ config: HotkeyConfiguration) -> Bool {
        return !checkForConflicts(config).isEmpty
    }
    
    /// Default hotkey: Option+Cmd+R (US-014)
    struct HotkeyConfiguration: Codable, Equatable {
        var keyCode: UInt16
        var modifierFlags: UInt

        /// Get NSEvent.ModifierFlags from the stored UInt
        var modifiers: NSEvent.ModifierFlags {
            return NSEvent.ModifierFlags(rawValue: modifierFlags)
        }

        /// Get CGEventFlags from the stored UInt (for CGEvent tap matching)
        var cgEventFlags: CGEventFlags {
            var flags = CGEventFlags()
            let nsFlags = modifiers
            if nsFlags.contains(.command) { flags.insert(.maskCommand) }
            if nsFlags.contains(.shift) { flags.insert(.maskShift) }
            if nsFlags.contains(.option) { flags.insert(.maskAlternate) }
            if nsFlags.contains(.control) { flags.insert(.maskControl) }
            return flags
        }

        /// Create from NSEvent.ModifierFlags
        init(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
            self.keyCode = keyCode
            self.modifierFlags = modifierFlags.rawValue
        }

        /// Create from raw values
        init(keyCode: UInt16, modifierFlags: UInt) {
            self.keyCode = keyCode
            self.modifierFlags = modifierFlags
        }

        /// US-014: Default hotkey is Option+Command+R (⌥⌘R)
        static let defaultHotkey = HotkeyConfiguration(
            keyCode: UInt16(kVK_ANSI_R),
            modifierFlags: [.command, .option]
        )
        
        /// Human-readable string for the hotkey
        var displayString: String {
            var parts: [String] = []
            let flags = modifiers
            if flags.contains(.control) { parts.append("⌃") }
            if flags.contains(.option) { parts.append("⌥") }
            if flags.contains(.shift) { parts.append("⇧") }
            if flags.contains(.command) { parts.append("⌘") }
            parts.append(keyCodeToString(keyCode))
            return parts.joined()
        }
        
        private func keyCodeToString(_ keyCode: UInt16) -> String {
            switch Int(keyCode) {
            case kVK_Space: return "Space"
            case kVK_Return: return "↩"
            case kVK_Tab: return "⇥"
            case kVK_Delete: return "⌫"
            case kVK_Escape: return "⎋"
            case kVK_ANSI_A...kVK_ANSI_Z:
                // Letter key code mapping
                let keyMap: [Int: String] = [
                    kVK_ANSI_A: "A", kVK_ANSI_S: "S", kVK_ANSI_D: "D",
                    kVK_ANSI_F: "F", kVK_ANSI_H: "H", kVK_ANSI_G: "G",
                    kVK_ANSI_Z: "Z", kVK_ANSI_X: "X", kVK_ANSI_C: "C",
                    kVK_ANSI_V: "V", kVK_ANSI_B: "B", kVK_ANSI_Q: "Q",
                    kVK_ANSI_W: "W", kVK_ANSI_E: "E", kVK_ANSI_R: "R",
                    kVK_ANSI_Y: "Y", kVK_ANSI_T: "T", kVK_ANSI_O: "O",
                    kVK_ANSI_U: "U", kVK_ANSI_I: "I", kVK_ANSI_P: "P",
                    kVK_ANSI_L: "L", kVK_ANSI_J: "J", kVK_ANSI_K: "K",
                    kVK_ANSI_N: "N", kVK_ANSI_M: "M"
                ]
                return keyMap[Int(keyCode)] ?? "?"
            default:
                return "Key\(keyCode)"
            }
        }
    }
    
    // MARK: - Properties

    /// CGEvent tap for global hotkey detection (US-510)
    private var eventTap: CFMachPort?

    /// Run loop source for the event tap
    private var runLoopSource: CFRunLoopSource?

    /// Current hotkey configuration for start recording
    @Published private(set) var configuration: HotkeyConfiguration

    /// US-015: Stop recording hotkey configuration (separate from start)
    @Published private(set) var stopConfiguration: HotkeyConfiguration

    /// US-015: Whether to use the same hotkey for both start and stop (toggle behavior)
    @Published var useSameHotkeyForStop: Bool {
        didSet {
            saveStopConfiguration()
            print("HotkeyManager: [US-015] useSameHotkeyForStop set to \(useSameHotkeyForStop)")
        }
    }

    /// Callback triggered when the start hotkey is pressed
    var onHotkeyPressed: (() -> Void)?

    /// US-015: Callback triggered when the stop hotkey is pressed
    var onStopHotkeyPressed: (() -> Void)?

    /// Callback triggered when accessibility permission is needed (US-510)
    var onAccessibilityPermissionNeeded: (() -> Void)?

    /// Whether the event tap is currently active
    @Published private(set) var isActive: Bool = false
    
    // MARK: - Initialization

    init(configuration: HotkeyConfiguration? = nil) {
        // Load saved configuration or use default
        if let saved = configuration {
            self.configuration = saved
        } else {
            self.configuration = Self.loadConfiguration()
        }
        // US-015: Load stop hotkey configuration
        let (stopConfig, useSame) = Self.loadStopConfiguration()
        self.stopConfiguration = stopConfig
        self.useSameHotkeyForStop = useSame
        print("HotkeyManager: [US-510] Initialized with start hotkey: \(self.configuration.displayString)")
        print("HotkeyManager: [US-015] Stop hotkey: \(useSame ? "same as start" : self.stopConfiguration.displayString)")
    }
    
    // MARK: - Persistence
    
    /// Load hotkey configuration from UserDefaults
    private static func loadConfiguration() -> HotkeyConfiguration {
        let defaults = UserDefaults.standard
        
        // Check if we have saved values
        if defaults.object(forKey: Constants.hotkeyKeyCodeKey) != nil {
            let keyCode = UInt16(defaults.integer(forKey: Constants.hotkeyKeyCodeKey))
            let modifiers = UInt(defaults.integer(forKey: Constants.hotkeyModifiersKey))
            let config = HotkeyConfiguration(keyCode: keyCode, modifierFlags: modifiers)
            print("HotkeyManager: [US-510] Loaded saved hotkey configuration: \(config.displayString)")
            return config
        }
        
        print("HotkeyManager: [US-014] Using default hotkey configuration (Option+Cmd+R)")
        return .defaultHotkey
    }
    
    /// Save hotkey configuration to UserDefaults
    private func saveConfiguration() {
        let defaults = UserDefaults.standard
        defaults.set(Int(configuration.keyCode), forKey: Constants.hotkeyKeyCodeKey)
        defaults.set(Int(configuration.modifierFlags), forKey: Constants.hotkeyModifiersKey)
        print("HotkeyManager: [US-510] Saved hotkey configuration: \(configuration.displayString)")
    }

    // MARK: - US-015: Stop Hotkey Persistence

    /// Load stop hotkey configuration from UserDefaults
    private static func loadStopConfiguration() -> (HotkeyConfiguration, Bool) {
        let defaults = UserDefaults.standard

        // Check if we have the "use same hotkey" preference (defaults to true for toggle behavior)
        let useSame = defaults.object(forKey: Constants.useSameHotkeyForStopKey) == nil
            ? true
            : defaults.bool(forKey: Constants.useSameHotkeyForStopKey)

        // Check if we have saved stop hotkey values
        if defaults.object(forKey: Constants.stopHotkeyKeyCodeKey) != nil {
            let keyCode = UInt16(defaults.integer(forKey: Constants.stopHotkeyKeyCodeKey))
            let modifiers = UInt(defaults.integer(forKey: Constants.stopHotkeyModifiersKey))
            let config = HotkeyConfiguration(keyCode: keyCode, modifierFlags: modifiers)
            print("HotkeyManager: [US-015] Loaded saved stop hotkey configuration: \(config.displayString)")
            return (config, useSame)
        }

        // Default stop hotkey is same as start hotkey default
        print("HotkeyManager: [US-015] Using default stop hotkey configuration")
        return (.defaultHotkey, useSame)
    }

    /// Save stop hotkey configuration to UserDefaults
    private func saveStopConfiguration() {
        let defaults = UserDefaults.standard
        defaults.set(Int(stopConfiguration.keyCode), forKey: Constants.stopHotkeyKeyCodeKey)
        defaults.set(Int(stopConfiguration.modifierFlags), forKey: Constants.stopHotkeyModifiersKey)
        defaults.set(useSameHotkeyForStop, forKey: Constants.useSameHotkeyForStopKey)
        print("HotkeyManager: [US-015] Saved stop hotkey configuration: \(stopConfiguration.displayString), useSame: \(useSameHotkeyForStop)")
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public API
    
    /// Start listening for global hotkey events using CGEvent tap (US-510)
    /// - Parameter showPermissionPrompt: If false, silently fails when permission not granted (for app launch).
    ///   If true, triggers onAccessibilityPermissionNeeded callback (for user-initiated actions).
    /// Requires accessibility permission to actually install the event tap.
    func start(showPermissionPrompt: Bool = false) {
        // Stop any existing event tap first
        stop()
        
        // Check accessibility permission before creating event tap (US-510)
        if !AXIsProcessTrusted() {
            print("HotkeyManager: [US-510] Accessibility permission not granted - cannot install event tap")
            if showPermissionPrompt {
                print("HotkeyManager: [US-510] Showing permission prompt...")
                onAccessibilityPermissionNeeded?()
            } else {
                print("HotkeyManager: [US-510] Silently waiting for permission (onboarding will handle)")
            }
            return
        }
        
        // Create CGEvent tap at kCGSessionEventTap level (US-510)
        // This ensures hotkeys work regardless of which app is focused
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        
        // Create the event tap with callback
        // Use .listenOnly to avoid blocking other apps - we just want to observe the hotkey
        // .defaultTap can cause system-wide blocking issues
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,  // US-510: Session level for global events
            place: .headInsertEventTap,
            options: .listenOnly,  // Changed from .defaultTap to prevent system blocking
            eventsOfInterest: eventMask,
            callback: HotkeyManager.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("HotkeyManager: [US-510] Failed to create CGEvent tap - accessibility permission may not be granted")
            if showPermissionPrompt {
                onAccessibilityPermissionNeeded?()
            }
            return
        }
        
        eventTap = tap
        
        // Create a run loop source and add it to the current run loop
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        guard let source = runLoopSource else {
            print("HotkeyManager: [US-510] Failed to create run loop source")
            stop()
            return
        }
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        
        // Enable the event tap
        CGEvent.tapEnable(tap: tap, enable: true)
        
        isActive = true
        print("HotkeyManager: [US-510] Started - listening for \(configuration.displayString) via CGEvent tap at kCGSessionEventTap level")
        print("HotkeyManager: [US-510] Hotkey works when any application is focused")
    }
    
    /// Stop listening for global hotkey events
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
                runLoopSource = nil
            }
            
            // Note: CFMachPort doesn't have an explicit close method; 
            // setting to nil allows ARC to clean up
            eventTap = nil
        }
        
        isActive = false
        print("HotkeyManager: [US-510] Stopped")
    }
    
    /// Update the hotkey configuration and save to UserDefaults
    func updateConfiguration(_ newConfig: HotkeyConfiguration) {
        configuration = newConfig
        saveConfiguration()
        // Restart hotkey registration with new configuration
        if isActive || eventTap != nil {
            start()
        }
    }

    /// US-015: Update the stop hotkey configuration and save to UserDefaults
    func updateStopConfiguration(_ newConfig: HotkeyConfiguration) {
        stopConfiguration = newConfig
        saveStopConfiguration()
        print("HotkeyManager: [US-015] Stop hotkey updated to \(newConfig.displayString)")
    }

    /// Reset hotkey to default and save
    func resetToDefault() {
        updateConfiguration(.defaultHotkey)
    }

    /// US-015: Reset stop hotkey to default and save
    func resetStopToDefault() {
        updateStopConfiguration(.defaultHotkey)
        useSameHotkeyForStop = true
    }

    /// Get current hotkey display string
    var hotkeyDisplayString: String {
        return configuration.displayString
    }

    /// US-015: Get current stop hotkey display string
    var stopHotkeyDisplayString: String {
        return useSameHotkeyForStop ? configuration.displayString : stopConfiguration.displayString
    }

    /// US-015: Get the effective stop configuration (either same as start or separate)
    var effectiveStopConfiguration: HotkeyConfiguration {
        return useSameHotkeyForStop ? configuration : stopConfiguration
    }
    
    /// Check if accessibility permission is granted (US-510)
    var hasAccessibilityPermission: Bool {
        return AXIsProcessTrusted()
    }
    
    // MARK: - CGEvent Tap Callback (US-510)
    
    /// Static callback for CGEvent tap
    /// This is called for every key down event when the tap is active
    private static let eventTapCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
        // Handle tap disabled events (system can disable taps if they take too long)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            print("HotkeyManager: [US-510] Event tap was disabled by system, re-enabling...")
            // Re-enable the tap
            if let userInfo = userInfo {
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
                if let tap = manager.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
            return Unmanaged.passUnretained(event)
        }
        
        // Only process key down events
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }
        
        guard let userInfo = userInfo else {
            return Unmanaged.passUnretained(event)
        }
        
        let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
        
        // Get key code from the event
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        // Get modifier flags from the event (US-510: detect Command, Shift, Option, Control)
        let eventFlags = event.flags
        
        // Compare modifier flags (mask out non-modifier flags like caps lock indicator)
        let modifierMask: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        let eventModifiers = eventFlags.intersection(modifierMask)

        // US-015: Check for start hotkey match
        let startKeyCode = Int64(manager.configuration.keyCode)
        let startModifiers = manager.configuration.cgEventFlags.intersection(modifierMask)

        if keyCode == startKeyCode && eventModifiers == startModifiers {
            // Start hotkey matched!
            print("HotkeyManager: [US-510] Start hotkey detected: \(manager.configuration.displayString)")

            // Call the callback on the main thread
            DispatchQueue.main.async {
                manager.onHotkeyPressed?()
            }

            return Unmanaged.passUnretained(event)
        }

        // US-015: Check for stop hotkey match (only if using different hotkey)
        if !manager.useSameHotkeyForStop {
            let stopKeyCode = Int64(manager.stopConfiguration.keyCode)
            let stopModifiers = manager.stopConfiguration.cgEventFlags.intersection(modifierMask)

            if keyCode == stopKeyCode && eventModifiers == stopModifiers {
                // Stop hotkey matched!
                print("HotkeyManager: [US-015] Stop hotkey detected: \(manager.stopConfiguration.displayString)")

                // Call the stop callback on the main thread
                DispatchQueue.main.async {
                    manager.onStopHotkeyPressed?()
                }

                return Unmanaged.passUnretained(event)
            }
        }

        // Always pass the event through - we're using .listenOnly mode
        // so we can only observe events, not consume them
        return Unmanaged.passUnretained(event)
    }
}
