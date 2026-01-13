import AppKit
import ServiceManagement

/// Controller for managing the menu bar status item
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var recordingState: RecordingState = .idle
    
    // Callback for when recording state changes
    var onRecordingStateChanged: ((RecordingState) -> Void)?
    
    // Reference to audio manager for device selection
    weak var audioManager: AudioManager?
    
    override init() {
        super.init()
        setupStatusItem()
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
        
        // Settings item
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Audio Input Device submenu
        let audioDeviceItem = NSMenuItem(title: "Audio Input", action: nil, keyEquivalent: "")
        let audioDeviceSubmenu = NSMenu()
        audioDeviceItem.submenu = audioDeviceSubmenu
        menu.addItem(audioDeviceItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Launch at login item
        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchAtLoginItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit item
        let quitItem = NSMenuItem(title: "Quit WispFlow", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
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
    
    // MARK: - Icon Management
    
    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        
        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = NSImage(systemSymbolName: recordingState.iconName, accessibilityDescription: recordingState.accessibilityLabel)
        button.image = image?.withSymbolConfiguration(configuration)
        button.toolTip = recordingState.accessibilityLabel
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
        // For now, just print. Settings window will be implemented in US-007
        print("Settings clicked - Settings window not yet implemented")
        
        // Open System Settings for WispFlow (placeholder behavior)
        // In the future, this will open our custom settings window
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
