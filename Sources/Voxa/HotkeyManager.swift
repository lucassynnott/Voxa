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
        // US-016: Cancel hotkey configuration keys
        static let cancelHotkeyKeyCodeKey = "cancelHotkeyKeyCode"
        static let cancelHotkeyModifiersKey = "cancelHotkeyModifiers"
        // US-017: Insert last transcription hotkey configuration keys
        static let insertHotkeyKeyCodeKey = "insertHotkeyKeyCode"
        static let insertHotkeyModifiersKey = "insertHotkeyModifiers"
        // US-020: Push-to-talk mode configuration key
        static let pushToTalkEnabledKey = "pushToTalkEnabled"
        // US-026: Undo transcription hotkey configuration keys
        static let undoHotkeyKeyCodeKey = "undoHotkeyKeyCode"
        static let undoHotkeyModifiersKey = "undoHotkeyModifiers"
        static let undoHotkeyEnabledKey = "undoHotkeyEnabled"
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

        /// US-016: Default cancel hotkey is Escape (no modifiers)
        static let defaultCancelHotkey = HotkeyConfiguration(
            keyCode: UInt16(kVK_Escape),
            modifierFlags: []
        )

        /// US-017: Default insert last transcription hotkey is Option+Command+V (⌥⌘V)
        static let defaultInsertHotkey = HotkeyConfiguration(
            keyCode: UInt16(kVK_ANSI_V),
            modifierFlags: [.command, .option]
        )

        /// US-026: Default undo transcription hotkey is Command+Z (⌘Z)
        static let defaultUndoHotkey = HotkeyConfiguration(
            keyCode: UInt16(kVK_ANSI_Z),
            modifierFlags: [.command]
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

    /// US-016: Cancel recording hotkey configuration (discards audio)
    @Published private(set) var cancelConfiguration: HotkeyConfiguration

    /// US-017: Insert last transcription hotkey configuration
    @Published private(set) var insertConfiguration: HotkeyConfiguration

    /// US-026: Undo transcription hotkey configuration
    @Published private(set) var undoConfiguration: HotkeyConfiguration

    /// US-026: Whether undo transcription hotkey is enabled
    @Published var undoHotkeyEnabled: Bool {
        didSet {
            saveUndoConfiguration()
            print("HotkeyManager: [US-026] undoHotkeyEnabled set to \(undoHotkeyEnabled)")
        }
    }

    /// US-015: Whether to use the same hotkey for both start and stop (toggle behavior)
    @Published var useSameHotkeyForStop: Bool {
        didSet {
            saveStopConfiguration()
            print("HotkeyManager: [US-015] useSameHotkeyForStop set to \(useSameHotkeyForStop)")
        }
    }

    /// US-020: Whether push-to-talk mode is enabled (hold to record, release to stop)
    @Published var pushToTalkEnabled: Bool {
        didSet {
            savePushToTalkSetting()
            print("HotkeyManager: [US-020] pushToTalkEnabled set to \(pushToTalkEnabled)")
            // Restart event tap to add/remove key-up event handling
            if isActive {
                start()
            }
        }
    }

    /// Callback triggered when the start hotkey is pressed
    var onHotkeyPressed: (() -> Void)?

    /// US-015: Callback triggered when the stop hotkey is pressed
    var onStopHotkeyPressed: (() -> Void)?

    /// US-016: Callback triggered when the cancel hotkey is pressed
    var onCancelHotkeyPressed: (() -> Void)?

    /// US-017: Callback triggered when the insert last transcription hotkey is pressed
    var onInsertHotkeyPressed: (() -> Void)?

    /// US-026: Callback triggered when the undo transcription hotkey is pressed
    var onUndoHotkeyPressed: (() -> Void)?

    /// US-020: Callback triggered when the start hotkey is released (for push-to-talk mode)
    var onHotkeyReleased: (() -> Void)?

    /// Callback triggered when accessibility permission is needed (US-510)
    var onAccessibilityPermissionNeeded: (() -> Void)?

    /// Whether the event tap is currently active
    @Published private(set) var isActive: Bool = false

    /// US-020: Track if we're currently in a push-to-talk recording session
    /// This is used to detect when the key is released to stop recording
    private var isPushToTalkRecording: Bool = false

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
        // US-016: Load cancel hotkey configuration
        self.cancelConfiguration = Self.loadCancelConfiguration()
        // US-017: Load insert last transcription hotkey configuration
        self.insertConfiguration = Self.loadInsertConfiguration()
        // US-026: Load undo transcription hotkey configuration
        let (undoConfig, undoEnabled) = Self.loadUndoConfiguration()
        self.undoConfiguration = undoConfig
        self.undoHotkeyEnabled = undoEnabled
        // US-020: Load push-to-talk setting
        self.pushToTalkEnabled = Self.loadPushToTalkSetting()
        print("HotkeyManager: [US-510] Initialized with start hotkey: \(self.configuration.displayString)")
        print("HotkeyManager: [US-015] Stop hotkey: \(useSame ? "same as start" : self.stopConfiguration.displayString)")
        print("HotkeyManager: [US-016] Cancel hotkey: \(self.cancelConfiguration.displayString)")
        print("HotkeyManager: [US-017] Insert hotkey: \(self.insertConfiguration.displayString)")
        print("HotkeyManager: [US-026] Undo hotkey: \(undoEnabled ? self.undoConfiguration.displayString : "disabled")")
        print("HotkeyManager: [US-020] Push-to-talk mode: \(self.pushToTalkEnabled ? "enabled" : "disabled")")
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

    // MARK: - US-016: Cancel Hotkey Persistence

    /// Load cancel hotkey configuration from UserDefaults
    private static func loadCancelConfiguration() -> HotkeyConfiguration {
        let defaults = UserDefaults.standard

        // Check if we have saved cancel hotkey values
        if defaults.object(forKey: Constants.cancelHotkeyKeyCodeKey) != nil {
            let keyCode = UInt16(defaults.integer(forKey: Constants.cancelHotkeyKeyCodeKey))
            let modifiers = UInt(defaults.integer(forKey: Constants.cancelHotkeyModifiersKey))
            let config = HotkeyConfiguration(keyCode: keyCode, modifierFlags: modifiers)
            print("HotkeyManager: [US-016] Loaded saved cancel hotkey configuration: \(config.displayString)")
            return config
        }

        // Default cancel hotkey is Escape
        print("HotkeyManager: [US-016] Using default cancel hotkey configuration (Escape)")
        return .defaultCancelHotkey
    }

    /// Save cancel hotkey configuration to UserDefaults
    private func saveCancelConfiguration() {
        let defaults = UserDefaults.standard
        defaults.set(Int(cancelConfiguration.keyCode), forKey: Constants.cancelHotkeyKeyCodeKey)
        defaults.set(Int(cancelConfiguration.modifierFlags), forKey: Constants.cancelHotkeyModifiersKey)
        print("HotkeyManager: [US-016] Saved cancel hotkey configuration: \(cancelConfiguration.displayString)")
    }

    // MARK: - US-017: Insert Hotkey Persistence

    /// Load insert hotkey configuration from UserDefaults
    private static func loadInsertConfiguration() -> HotkeyConfiguration {
        let defaults = UserDefaults.standard

        // Check if we have saved insert hotkey values
        if defaults.object(forKey: Constants.insertHotkeyKeyCodeKey) != nil {
            let keyCode = UInt16(defaults.integer(forKey: Constants.insertHotkeyKeyCodeKey))
            let modifiers = UInt(defaults.integer(forKey: Constants.insertHotkeyModifiersKey))
            let config = HotkeyConfiguration(keyCode: keyCode, modifierFlags: modifiers)
            print("HotkeyManager: [US-017] Loaded saved insert hotkey configuration: \(config.displayString)")
            return config
        }

        // Default insert hotkey is Option+Command+V
        print("HotkeyManager: [US-017] Using default insert hotkey configuration (Option+Cmd+V)")
        return .defaultInsertHotkey
    }

    /// Save insert hotkey configuration to UserDefaults
    private func saveInsertConfiguration() {
        let defaults = UserDefaults.standard
        defaults.set(Int(insertConfiguration.keyCode), forKey: Constants.insertHotkeyKeyCodeKey)
        defaults.set(Int(insertConfiguration.modifierFlags), forKey: Constants.insertHotkeyModifiersKey)
        print("HotkeyManager: [US-017] Saved insert hotkey configuration: \(insertConfiguration.displayString)")
    }

    // MARK: - US-026: Undo Hotkey Persistence

    /// Load undo hotkey configuration from UserDefaults
    private static func loadUndoConfiguration() -> (HotkeyConfiguration, Bool) {
        let defaults = UserDefaults.standard

        // Check if undo hotkey is enabled (defaults to true)
        let enabled = defaults.object(forKey: Constants.undoHotkeyEnabledKey) == nil
            ? true
            : defaults.bool(forKey: Constants.undoHotkeyEnabledKey)

        // Check if we have saved undo hotkey values
        if defaults.object(forKey: Constants.undoHotkeyKeyCodeKey) != nil {
            let keyCode = UInt16(defaults.integer(forKey: Constants.undoHotkeyKeyCodeKey))
            let modifiers = UInt(defaults.integer(forKey: Constants.undoHotkeyModifiersKey))
            let config = HotkeyConfiguration(keyCode: keyCode, modifierFlags: modifiers)
            print("HotkeyManager: [US-026] Loaded saved undo hotkey configuration: \(config.displayString)")
            return (config, enabled)
        }

        // Default undo hotkey is Command+Z
        print("HotkeyManager: [US-026] Using default undo hotkey configuration (Cmd+Z)")
        return (.defaultUndoHotkey, enabled)
    }

    /// Save undo hotkey configuration to UserDefaults
    private func saveUndoConfiguration() {
        let defaults = UserDefaults.standard
        defaults.set(Int(undoConfiguration.keyCode), forKey: Constants.undoHotkeyKeyCodeKey)
        defaults.set(Int(undoConfiguration.modifierFlags), forKey: Constants.undoHotkeyModifiersKey)
        defaults.set(undoHotkeyEnabled, forKey: Constants.undoHotkeyEnabledKey)
        print("HotkeyManager: [US-026] Saved undo hotkey configuration: \(undoConfiguration.displayString), enabled: \(undoHotkeyEnabled)")
    }

    // MARK: - US-020: Push-to-Talk Persistence

    /// Load push-to-talk setting from UserDefaults
    private static func loadPushToTalkSetting() -> Bool {
        let defaults = UserDefaults.standard
        // Default is false (toggle mode, not push-to-talk)
        let enabled = defaults.bool(forKey: Constants.pushToTalkEnabledKey)
        print("HotkeyManager: [US-020] Loaded push-to-talk setting: \(enabled)")
        return enabled
    }

    /// Save push-to-talk setting to UserDefaults
    private func savePushToTalkSetting() {
        let defaults = UserDefaults.standard
        defaults.set(pushToTalkEnabled, forKey: Constants.pushToTalkEnabledKey)
        print("HotkeyManager: [US-020] Saved push-to-talk setting: \(pushToTalkEnabled)")
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
        // US-020: Include keyUp events when push-to-talk mode is enabled
        var eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        if pushToTalkEnabled {
            eventMask |= (1 << CGEventType.keyUp.rawValue)
            eventMask |= (1 << CGEventType.flagsChanged.rawValue) // For modifier key release detection
            print("HotkeyManager: [US-020] Push-to-talk enabled - also listening for keyUp and flagsChanged events")
        }

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
        if pushToTalkEnabled {
            print("HotkeyManager: [US-020] Push-to-talk mode active - hold to record, release to stop")
        }
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

    /// US-016: Update the cancel hotkey configuration and save to UserDefaults
    func updateCancelConfiguration(_ newConfig: HotkeyConfiguration) {
        cancelConfiguration = newConfig
        saveCancelConfiguration()
        print("HotkeyManager: [US-016] Cancel hotkey updated to \(newConfig.displayString)")
    }

    /// US-016: Reset cancel hotkey to default (Escape) and save
    func resetCancelToDefault() {
        updateCancelConfiguration(.defaultCancelHotkey)
    }

    /// US-017: Update the insert hotkey configuration and save to UserDefaults
    func updateInsertConfiguration(_ newConfig: HotkeyConfiguration) {
        insertConfiguration = newConfig
        saveInsertConfiguration()
        print("HotkeyManager: [US-017] Insert hotkey updated to \(newConfig.displayString)")
    }

    /// US-017: Reset insert hotkey to default (Option+Command+V) and save
    func resetInsertToDefault() {
        updateInsertConfiguration(.defaultInsertHotkey)
    }

    /// US-026: Update the undo hotkey configuration and save to UserDefaults
    func updateUndoConfiguration(_ newConfig: HotkeyConfiguration) {
        undoConfiguration = newConfig
        saveUndoConfiguration()
        print("HotkeyManager: [US-026] Undo hotkey updated to \(newConfig.displayString)")
    }

    /// US-026: Reset undo hotkey to default (Command+Z) and save
    func resetUndoToDefault() {
        updateUndoConfiguration(.defaultUndoHotkey)
        undoHotkeyEnabled = true
    }

    /// Get current hotkey display string
    var hotkeyDisplayString: String {
        return configuration.displayString
    }

    /// US-015: Get current stop hotkey display string
    var stopHotkeyDisplayString: String {
        return useSameHotkeyForStop ? configuration.displayString : stopConfiguration.displayString
    }

    /// US-016: Get current cancel hotkey display string
    var cancelHotkeyDisplayString: String {
        return cancelConfiguration.displayString
    }

    /// US-017: Get current insert hotkey display string
    var insertHotkeyDisplayString: String {
        return insertConfiguration.displayString
    }

    /// US-026: Get current undo hotkey display string
    var undoHotkeyDisplayString: String {
        return undoConfiguration.displayString
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
    /// This is called for every key down/up event when the tap is active
    /// US-020: Updated to handle key-up events for push-to-talk mode
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

        guard let userInfo = userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

        // Compare modifier flags (mask out non-modifier flags like caps lock indicator)
        let modifierMask: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]

        // US-020: Handle key-up and flagsChanged events for push-to-talk mode
        if manager.pushToTalkEnabled && manager.isPushToTalkRecording {
            if type == .keyUp || type == .flagsChanged {
                // Get key code and modifiers from the event
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let eventFlags = event.flags
                let eventModifiers = eventFlags.intersection(modifierMask)

                // Check if the start hotkey key was released or if modifiers no longer match
                let startKeyCode = Int64(manager.configuration.keyCode)
                let startModifiers = manager.configuration.cgEventFlags.intersection(modifierMask)

                // For keyUp: check if it's the same key
                // For flagsChanged: check if the required modifiers are no longer pressed
                var shouldStopRecording = false

                if type == .keyUp && keyCode == startKeyCode {
                    // The main key was released
                    shouldStopRecording = true
                    print("HotkeyManager: [US-020] Push-to-talk key released (keyUp)")
                } else if type == .flagsChanged {
                    // Check if any required modifier is no longer pressed
                    // A modifier is required if it's part of the hotkey configuration
                    if !startModifiers.isEmpty && !eventModifiers.contains(startModifiers) {
                        shouldStopRecording = true
                        print("HotkeyManager: [US-020] Push-to-talk modifier released (flagsChanged)")
                    }
                }

                if shouldStopRecording {
                    manager.isPushToTalkRecording = false
                    print("HotkeyManager: [US-020] Push-to-talk recording ended")

                    // Call the release callback on the main thread
                    DispatchQueue.main.async {
                        manager.onHotkeyReleased?()
                    }

                    return Unmanaged.passUnretained(event)
                }
            }
        }

        // Only process key down events for starting actions
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        // Get key code from the event
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Get modifier flags from the event (US-510: detect Command, Shift, Option, Control)
        let eventFlags = event.flags
        let eventModifiers = eventFlags.intersection(modifierMask)

        // US-015: Check for start hotkey match
        let startKeyCode = Int64(manager.configuration.keyCode)
        let startModifiers = manager.configuration.cgEventFlags.intersection(modifierMask)

        if keyCode == startKeyCode && eventModifiers == startModifiers {
            // Start hotkey matched!
            print("HotkeyManager: [US-510] Start hotkey detected: \(manager.configuration.displayString)")

            // US-020: In push-to-talk mode, track that we're now recording
            if manager.pushToTalkEnabled {
                // Only start if not already recording (prevent key repeat triggers)
                if !manager.isPushToTalkRecording {
                    manager.isPushToTalkRecording = true
                    print("HotkeyManager: [US-020] Push-to-talk recording started")

                    // Call the callback on the main thread
                    DispatchQueue.main.async {
                        manager.onHotkeyPressed?()
                    }
                }
            } else {
                // Normal toggle mode
                DispatchQueue.main.async {
                    manager.onHotkeyPressed?()
                }
            }

            return Unmanaged.passUnretained(event)
        }

        // US-015: Check for stop hotkey match (only if using different hotkey and not in push-to-talk mode)
        if !manager.useSameHotkeyForStop && !manager.pushToTalkEnabled {
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

        // US-016: Check for cancel hotkey match
        let cancelKeyCode = Int64(manager.cancelConfiguration.keyCode)
        let cancelModifiers = manager.cancelConfiguration.cgEventFlags.intersection(modifierMask)

        if keyCode == cancelKeyCode && eventModifiers == cancelModifiers {
            // Cancel hotkey matched!
            print("HotkeyManager: [US-016] Cancel hotkey detected: \(manager.cancelConfiguration.displayString)")

            // US-020: If in push-to-talk mode and recording, also clear the recording state
            if manager.pushToTalkEnabled && manager.isPushToTalkRecording {
                manager.isPushToTalkRecording = false
                print("HotkeyManager: [US-020] Push-to-talk recording cancelled")
            }

            // Call the cancel callback on the main thread
            DispatchQueue.main.async {
                manager.onCancelHotkeyPressed?()
            }

            return Unmanaged.passUnretained(event)
        }

        // US-017: Check for insert last transcription hotkey match
        let insertKeyCode = Int64(manager.insertConfiguration.keyCode)
        let insertModifiers = manager.insertConfiguration.cgEventFlags.intersection(modifierMask)

        if keyCode == insertKeyCode && eventModifiers == insertModifiers {
            // Insert hotkey matched!
            print("HotkeyManager: [US-017] Insert hotkey detected: \(manager.insertConfiguration.displayString)")

            // Call the insert callback on the main thread
            DispatchQueue.main.async {
                manager.onInsertHotkeyPressed?()
            }

            return Unmanaged.passUnretained(event)
        }

        // US-026: Check for undo transcription hotkey match (only if enabled)
        if manager.undoHotkeyEnabled {
            let undoKeyCode = Int64(manager.undoConfiguration.keyCode)
            let undoModifiers = manager.undoConfiguration.cgEventFlags.intersection(modifierMask)

            if keyCode == undoKeyCode && eventModifiers == undoModifiers {
                // Undo hotkey matched!
                print("HotkeyManager: [US-026] Undo hotkey detected: \(manager.undoConfiguration.displayString)")

                // Call the undo callback on the main thread
                DispatchQueue.main.async {
                    manager.onUndoHotkeyPressed?()
                }

                return Unmanaged.passUnretained(event)
            }
        }

        // Always pass the event through - we're using .listenOnly mode
        // so we can only observe events, not consume them
        return Unmanaged.passUnretained(event)
    }

    /// US-020: Reset push-to-talk recording state (called when recording is cancelled externally)
    func resetPushToTalkState() {
        isPushToTalkRecording = false
        print("HotkeyManager: [US-020] Push-to-talk state reset")
    }
}
