import AppKit
import ServiceManagement
import Combine

/// Controller for managing the menu bar status item
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var recordingState: RecordingState = .idle
    
    // Model status observation
    private var modelStatusObserver: AnyCancellable?
    private var currentModelStatus: WhisperManager.ModelStatus = .notDownloaded
    
    // Animation timer for recording pulse effect
    private var pulseTimer: Timer?
    private var pulsePhase: CGFloat = 0
    
    // Callback for when recording state changes
    var onRecordingStateChanged: ((RecordingState) -> Void)?
    
    // Callback for opening settings
    var onOpenSettings: (() -> Void)?
    
    // Callback for opening main window (US-632)
    var onOpenMainWindow: (() -> Void)?
    
    // Reference to audio manager for device selection
    weak var audioManager: AudioManager?
    
    // Reference to whisper manager for model status
    weak var whisperManager: WhisperManager? {
        didSet {
            setupModelStatusObserver()
        }
    }
    
    override init() {
        super.init()
        setupStatusItem()
    }
    
    deinit {
        stopPulseAnimation()
    }
    
    // MARK: - Setup
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let statusItem = statusItem,
              let button = statusItem.button else {
            return
        }
        
        // Configure the button appearance
        updateIcon()
        
        // Set up click handling
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        // Set up the menu for right-click
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self
        
        // Apply warm appearance to menu
        applyWarmMenuAppearance(to: menu)
        
        // Model status item (non-clickable, just shows status)
        let modelStatusItem = NSMenuItem(title: "Model: Loading...", action: nil, keyEquivalent: "")
        modelStatusItem.tag = 100 // Tag to identify for updates
        modelStatusItem.isEnabled = false
        menu.addItem(modelStatusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // US-632: Open Main Window item with app icon
        let mainWindowItem = NSMenuItem(title: "Open Voxa", action: #selector(openMainWindow), keyEquivalent: "o")
        mainWindowItem.target = self
        mainWindowItem.image = createMenuIcon(systemName: "rectangle.grid.1x2", tint: NSColor.Voxa.accent)
        menu.addItem(mainWindowItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings item with gear icon
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = createMenuIcon(systemName: "gearshape", tint: NSColor.Voxa.textSecondary)
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Audio Input Device submenu with speaker icon
        let audioDeviceItem = NSMenuItem(title: "Audio Input", action: nil, keyEquivalent: "")
        audioDeviceItem.image = createMenuIcon(systemName: "mic", tint: NSColor.Voxa.textSecondary)
        let audioDeviceSubmenu = NSMenu()
        audioDeviceItem.submenu = audioDeviceSubmenu
        menu.addItem(audioDeviceItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Launch at login item with checkmark icon when enabled
        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        launchAtLoginItem.image = createMenuIcon(systemName: "arrow.counterclockwise.circle", tint: NSColor.Voxa.textSecondary)
        menu.addItem(launchAtLoginItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit item with power icon
        let quitItem = NSMenuItem(title: "Quit Voxa", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = createMenuIcon(systemName: "power", tint: NSColor.Voxa.textSecondary)
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    /// Apply warm ivory background tint to menu (limited by macOS API)
    private func applyWarmMenuAppearance(to menu: NSMenu) {
        // Note: NSMenu background customization is limited in macOS
        // We apply tinting to menu item icons instead for warm feel
        // The menu will use system appearance but icons use our warm palette
    }
    
    /// Create a tinted SF Symbol image for menu items
    private func createMenuIcon(systemName: String, tint: NSColor, pointSize: CGFloat = 13) -> NSImage? {
        guard let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) else {
            return nil
        }
        
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        let configuredImage = image.withSymbolConfiguration(config)
        
        // Create a tinted version of the image
        let tintedImage = configuredImage?.copy() as? NSImage
        tintedImage?.lockFocus()
        tint.set()
        let imageRect = NSRect(origin: .zero, size: tintedImage?.size ?? .zero)
        imageRect.fill(using: .sourceAtop)
        tintedImage?.unlockFocus()
        
        return tintedImage
    }
    
    /// Update the model status menu item
    private func updateModelStatusMenuItem() {
        guard let menu = statusItem?.menu,
              let modelStatusItem = menu.item(withTag: 100) else { return }
        
        let statusText: String
        let statusIcon: String
        
        switch currentModelStatus {
        case .notDownloaded:
            statusText = "Model: Not Downloaded"
            statusIcon = "⚪"
        case .downloading(let progress):
            statusText = "Model: Downloading \(Int(progress * 100))%"
            statusIcon = "🔄"
        case .downloaded:
            statusText = "Model: Downloaded (Not Loaded)"
            statusIcon = "🔵"
        case .loading:
            statusText = "Model: Loading..."
            statusIcon = "🔄"
        case .ready:
            statusText = "Model: Ready ✓"
            statusIcon = "🟢"
        case .error:
            statusText = "Model: Error"
            statusIcon = "🔴"
        }
        
        modelStatusItem.title = "\(statusIcon) \(statusText)"
    }
    
    /// Populate the audio devices submenu with available devices
    private func populateAudioDevicesMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        
        guard let audioManager = audioManager else {
            let noDevicesItem = NSMenuItem(title: "No audio manager", action: nil, keyEquivalent: "")
            noDevicesItem.isEnabled = false
            menu.addItem(noDevicesItem)
            return
        }
        
        let devices = audioManager.inputDevices
        let currentDevice = audioManager.currentDevice
        
        if devices.isEmpty {
            let noDevicesItem = NSMenuItem(title: "No input devices", action: nil, keyEquivalent: "")
            noDevicesItem.isEnabled = false
            menu.addItem(noDevicesItem)
            return
        }
        
        for device in devices {
            let deviceItem = NSMenuItem(
                title: device.name + (device.isDefault ? " (System Default)" : ""),
                action: #selector(selectAudioDevice(_:)),
                keyEquivalent: ""
            )
            deviceItem.target = self
            deviceItem.representedObject = device.uid
            deviceItem.state = (currentDevice?.uid == device.uid) ? .on : .off
            menu.addItem(deviceItem)
        }
    }
    
    @objc private func selectAudioDevice(_ sender: NSMenuItem) {
        guard let uid = sender.representedObject as? String else { return }
        audioManager?.selectDevice(uid: uid)
        print("Selected audio device: \(sender.title)")
    }
    
    // MARK: - Model Status Observation
    
    private func setupModelStatusObserver() {
        // Cancel any existing observer
        modelStatusObserver?.cancel()
        
        guard let whisperManager = whisperManager else { return }
        
        // Observe model status changes on the main thread
        // Access the publisher from the main thread since WhisperManager is MainActor-isolated
        Task { @MainActor in
            self.modelStatusObserver = whisperManager.$modelStatus
                .receive(on: DispatchQueue.main)
                .sink { [weak self] status in
                    self?.currentModelStatus = status
                    self?.updateIcon()
                    self?.updateModelStatusMenuItem()
                    print("StatusBarController: Model status changed to \(self?.modelStatusText(status) ?? "unknown")")
                }
        }
    }
    
    // MARK: - Icon Management
    
    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        
        // Try to load custom menubar icon from bundle
        if let customIcon = loadMenubarIcon() {
            // Use custom icon when not recording
            if recordingState != .recording {
                stopPulseAnimation()
                button.image = customIcon
                button.image?.isTemplate = true  // Allow system to tint for dark/light mode
                button.toolTip = "Voxa - Ready"
                return
            }
        }
        
        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        
        // Determine the icon based on recording state and model status
        let iconName: String
        let tooltip: String
        let iconTint: NSColor
        
        if recordingState == .recording {
            // When recording, use recording icon with coral accent
            iconName = recordingState.iconName
            tooltip = recordingState.accessibilityLabel
            iconTint = NSColor.Voxa.accent
            
            // Start pulsing animation for recording state
            startPulseAnimation()
        } else {
            // Stop pulsing animation when not recording
            stopPulseAnimation()
            
            // When idle, show model status in icon
            switch currentModelStatus {
            case .notDownloaded, .downloaded:
                iconName = "waveform.slash"
                tooltip = "Voxa - Model not loaded"
                iconTint = NSColor.Voxa.textSecondary
            case .downloading(let progress):
                iconName = "arrow.down.circle"
                tooltip = "Voxa - Downloading model (\(Int(progress * 100))%)"
                iconTint = NSColor.Voxa.accent
            case .loading:
                iconName = "arrow.clockwise.circle"
                tooltip = "Voxa - Loading model..."
                iconTint = NSColor.Voxa.accent
            case .ready:
                iconName = "waveform"
                tooltip = "Voxa - Ready"
                iconTint = NSColor.Voxa.textPrimary  // Warm charcoal for ready state
            case .error(let message):
                iconName = "exclamationmark.triangle"
                tooltip = "Voxa - Error: \(message)"
                iconTint = NSColor.Voxa.error
            }
        }
        
        // Create and apply the tinted icon
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: tooltip) {
            button.image = createTintedStatusIcon(image: image, tint: iconTint, configuration: configuration)
        }
        button.toolTip = tooltip
    }
    
    /// Load custom menubar icon from app bundle
    private func loadMenubarIcon() -> NSImage? {
        guard let bundle = Bundle.main.resourceURL else { return nil }
        
        // Try @2x version first for retina displays
        let icon2xPath = bundle.appendingPathComponent("menubar@2x.png")
        let iconPath = bundle.appendingPathComponent("menubar.png")
        
        var image: NSImage?
        if FileManager.default.fileExists(atPath: icon2xPath.path) {
            image = NSImage(contentsOf: icon2xPath)
        } else if FileManager.default.fileExists(atPath: iconPath.path) {
            image = NSImage(contentsOf: iconPath)
        }
        
        // Resize for menu bar (18px width as requested)
        if let img = image {
            let targetWidth: CGFloat = 18
            let aspectRatio = img.size.height / img.size.width
            let targetHeight = targetWidth * aspectRatio
            img.size = NSSize(width: targetWidth, height: targetHeight)
        }
        
        return image
    }
    
    /// Create a tinted status bar icon
    private func createTintedStatusIcon(image: NSImage, tint: NSColor, configuration: NSImage.SymbolConfiguration) -> NSImage? {
        guard let configuredImage = image.withSymbolConfiguration(configuration) else {
            return image
        }
        
        // Create a template image and apply tint
        let tintedImage = configuredImage.copy() as? NSImage
        tintedImage?.isTemplate = false
        
        guard let size = tintedImage?.size, size.width > 0, size.height > 0 else {
            return tintedImage
        }
        
        tintedImage?.lockFocus()
        tint.set()
        let imageRect = NSRect(origin: .zero, size: size)
        imageRect.fill(using: .sourceAtop)
        tintedImage?.unlockFocus()
        
        return tintedImage
    }
    
    // MARK: - Pulse Animation for Recording State
    
    /// Start the pulsing glow animation for recording state
    private func startPulseAnimation() {
        // Don't start if already running
        guard pulseTimer == nil else { return }
        
        pulsePhase = 0
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updatePulseEffect()
        }
    }
    
    /// Stop the pulsing animation
    private func stopPulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        pulsePhase = 0
        
        // Reset button appearance
        statusItem?.button?.alphaValue = 1.0
    }
    
    /// Update the pulse effect (coral pulsing glow)
    private func updatePulseEffect() {
        guard let button = statusItem?.button else { return }
        
        // Increment phase for smooth sine wave animation
        pulsePhase += 0.1
        
        // Calculate alpha value: oscillate between 0.7 and 1.0 for subtle pulse
        let alpha = 0.85 + 0.15 * sin(pulsePhase)
        button.alphaValue = CGFloat(alpha)
        
        // Re-tint the icon with varying intensity for glow effect
        updateRecordingIconWithPulse(intensity: CGFloat(alpha))
    }
    
    /// Update the recording icon with pulse intensity
    private func updateRecordingIconWithPulse(intensity: CGFloat) {
        guard let button = statusItem?.button,
              recordingState == .recording else { return }
        
        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let iconName = recordingState.iconName
        
        // Create coral color with varying brightness for pulse effect
        let pulseColor = NSColor(
            calibratedRed: NSColor.Voxa.accent.redComponent * intensity + 0.1 * (1 - intensity),
            green: NSColor.Voxa.accent.greenComponent * intensity,
            blue: NSColor.Voxa.accent.blueComponent * intensity,
            alpha: 1.0
        )
        
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Recording") {
            button.image = createTintedStatusIcon(image: image, tint: pulseColor, configuration: configuration)
        }
    }
    
    /// Get human-readable text for model status
    private func modelStatusText(_ status: WhisperManager.ModelStatus) -> String {
        switch status {
        case .notDownloaded:
            return "Not Downloaded"
        case .downloading(let progress):
            return "Downloading (\(Int(progress * 100))%)"
        case .downloaded:
            return "Downloaded"
        case .loading:
            return "Loading"
        case .ready:
            return "Ready"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    // MARK: - Actions
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // Right-click: show menu
            // Menu is already attached, so it will show automatically
            // But we need to temporarily remove the action to let the menu show
            statusItem?.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 5), in: sender)
        } else {
            // Left-click: toggle recording
            toggleRecording()
        }
    }
    
    private func toggleRecording() {
        recordingState.toggle()
        updateIcon()
        onRecordingStateChanged?(recordingState)
        
        // Log state change for debugging
        print("Recording state changed to: \(recordingState.rawValue)")
    }
    
    @objc private func openSettings() {
        // US-708: Settings menu now opens main window with Settings tab selected
        print("Settings clicked - opening main window with Settings tab")
        onOpenSettings?()
    }
    
    /// US-632: Open the main application window
    @objc private func openMainWindow() {
        print("Open Voxa clicked - opening main window")
        onOpenMainWindow?()
    }
    
    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let newState = sender.state == .off
        setLaunchAtLogin(enabled: newState)
        sender.state = newState ? .on : .off
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Launch at Login
    
    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    print("Launch at login enabled")
                } else {
                    try SMAppService.mainApp.unregister()
                    print("Launch at login disabled")
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        }
    }
    
    // MARK: - Public API
    
    /// Returns the current recording state
    var currentState: RecordingState {
        return recordingState
    }
    
    /// Returns the current model status
    var modelStatus: WhisperManager.ModelStatus {
        return currentModelStatus
    }
    
    /// Check if model is ready for transcription
    var isModelReady: Bool {
        return currentModelStatus == .ready
    }
    
    /// Programmatically toggle the recording state (for testing or hotkey integration)
    func toggle() {
        toggleRecording()
    }
    
    /// Set the recording state directly (for external control)
    func setRecordingState(_ state: RecordingState) {
        guard recordingState != state else { return }
        recordingState = state
        updateIcon()
        onRecordingStateChanged?(recordingState)
    }
}

// MARK: - NSMenuDelegate

extension StatusBarController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Update model status in menu
        updateModelStatusMenuItem()
        
        // Find the Audio Input submenu and populate it with current devices
        for item in menu.items {
            if item.title == "Audio Input", let submenu = item.submenu {
                populateAudioDevicesMenu(submenu)
            }
            
            // Update launch at login state
            if item.title == "Launch at Login" {
                item.state = isLaunchAtLoginEnabled() ? .on : .off
            }
        }
    }
}
