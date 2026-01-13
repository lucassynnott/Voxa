import AppKit
import Combine

/// Floating recording indicator window that shows when recording is active
/// Displays a pill-shaped overlay with recording status, audio level meter, and cancel button
final class RecordingIndicatorWindow: NSPanel {
    
    // MARK: - UI Components
    
    private let containerView = NSView()
    private let recordingIcon = NSImageView()
    private let audioLevelMeter = AudioLevelMeterView()
    private let statusLabel = NSTextField()
    private let cancelButton = NSButton()
    
    /// Callback when cancel button is clicked
    var onCancel: (() -> Void)?
    
    /// Audio level subscription
    private var audioLevelCancellable: AnyCancellable?
    
    // MARK: - Configuration
    
    private struct Constants {
        static let windowWidth: CGFloat = 200
        static let windowHeight: CGFloat = 44
        static let cornerRadius: CGFloat = 22
        static let padding: CGFloat = 12
        static let iconSize: CGFloat = 20
        static let levelMeterWidth: CGFloat = 40
        static let levelMeterHeight: CGFloat = 8
        static let animationDuration: TimeInterval = 0.2
    }
    
    // MARK: - Initialization
    
    init() {
        // Create a borderless, floating window
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Constants.windowWidth, height: Constants.windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupWindow() {
        // Window behavior
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        
        // Appearance
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        
        // Don't show in mission control or expose
        collectionBehavior.insert(.stationary)
        
        // Position window at top center of main screen
        positionWindow()
    }
    
    private func setupUI() {
        guard let contentView = self.contentView else { return }
        
        // Container view with pill shape
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = Constants.cornerRadius
        containerView.layer?.masksToBounds = true
        
        // Use visual effect view for blur background
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = Constants.cornerRadius
        visualEffect.layer?.masksToBounds = true
        
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(visualEffect)
        
        // Container inside visual effect
        containerView.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(containerView)
        
        // Recording icon (pulsing red circle)
        let recordingImage = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Recording")
        recordingIcon.image = recordingImage
        recordingIcon.contentTintColor = .systemRed
        recordingIcon.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(recordingIcon)
        
        // Audio level meter (shows real-time mic input level)
        audioLevelMeter.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(audioLevelMeter)
        
        // Status label
        statusLabel.stringValue = "Recording..."
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .labelColor
        statusLabel.backgroundColor = .clear
        statusLabel.isBordered = false
        statusLabel.isEditable = false
        statusLabel.isSelectable = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusLabel)
        
        // Cancel button
        let cancelImage = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Cancel recording")
        cancelButton.image = cancelImage
        cancelButton.imagePosition = .imageOnly
        cancelButton.isBordered = false
        cancelButton.contentTintColor = .secondaryLabelColor
        cancelButton.target = self
        cancelButton.action = #selector(cancelButtonClicked)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(cancelButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Visual effect fills content view
            visualEffect.topAnchor.constraint(equalTo: contentView.topAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Container fills visual effect
            containerView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            
            // Recording icon on the left
            recordingIcon.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Constants.padding),
            recordingIcon.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            recordingIcon.widthAnchor.constraint(equalToConstant: Constants.iconSize),
            recordingIcon.heightAnchor.constraint(equalToConstant: Constants.iconSize),
            
            // Audio level meter next to recording icon
            audioLevelMeter.leadingAnchor.constraint(equalTo: recordingIcon.trailingAnchor, constant: 6),
            audioLevelMeter.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            audioLevelMeter.widthAnchor.constraint(equalToConstant: Constants.levelMeterWidth),
            audioLevelMeter.heightAnchor.constraint(equalToConstant: Constants.levelMeterHeight),
            
            // Status label in the middle
            statusLabel.leadingAnchor.constraint(equalTo: audioLevelMeter.trailingAnchor, constant: 8),
            statusLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            // Cancel button on the right
            cancelButton.leadingAnchor.constraint(greaterThanOrEqualTo: statusLabel.trailingAnchor, constant: 8),
            cancelButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Constants.padding),
            cancelButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: Constants.iconSize),
            cancelButton.heightAnchor.constraint(equalToConstant: Constants.iconSize)
        ])
        
        // Start pulsing animation
        startPulsingAnimation()
    }
    
    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowX = screenFrame.midX - (Constants.windowWidth / 2)
        let windowY = screenFrame.maxY - Constants.windowHeight - 20 // 20px from top
        
        setFrameOrigin(NSPoint(x: windowX, y: windowY))
    }
    
    // MARK: - Animations
    
    private func startPulsingAnimation() {
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 0.4
        pulseAnimation.duration = 0.8
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        recordingIcon.layer?.add(pulseAnimation, forKey: "pulse")
    }
    
    private func stopPulsingAnimation() {
        recordingIcon.layer?.removeAnimation(forKey: "pulse")
    }
    
    // MARK: - Actions
    
    @objc private func cancelButtonClicked() {
        print("Cancel button clicked on recording indicator")
        onCancel?()
    }
    
    // MARK: - Public API
    
    /// Show the indicator with animation
    func showWithAnimation() {
        alphaValue = 0
        orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constants.animationDuration
            self.animator().alphaValue = 1
        }
        
        startPulsingAnimation()
        print("Recording indicator shown")
    }
    
    /// Hide the indicator with animation
    func hideWithAnimation(completion: (() -> Void)? = nil) {
        stopPulsingAnimation()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Constants.animationDuration
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            completion?()
        })
        
        print("Recording indicator hidden")
    }
    
    /// Update the status text
    func updateStatus(_ text: String) {
        statusLabel.stringValue = text
    }
    
    /// Update audio level meter (value in dB, typically -60 to 0)
    func updateAudioLevel(_ level: Float) {
        audioLevelMeter.updateLevel(level)
    }
    
    /// Connect to AudioManager for real-time level updates
    func connectAudioManager(_ audioManager: AudioManager) {
        audioLevelCancellable = audioManager.$currentAudioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevelMeter.updateLevel(level)
            }
    }
    
    /// Disconnect from AudioManager
    func disconnectAudioManager() {
        audioLevelCancellable?.cancel()
        audioLevelCancellable = nil
        audioLevelMeter.updateLevel(-60.0)
    }
    
    // MARK: - Window Behavior Overrides
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}

// MARK: - Audio Level Meter View

/// A simple horizontal bar that visualizes audio level in real-time
final class AudioLevelMeterView: NSView {
    
    private let levelBar = NSView()
    private var levelBarWidthConstraint: NSLayoutConstraint?
    
    private struct Constants {
        static let minDB: Float = -60.0
        static let maxDB: Float = 0.0
        static let silenceThreshold: Float = -55.0  // Matches AudioManager threshold (lowered from -40dB)
        static let cornerRadius: CGFloat = 2.0
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = Constants.cornerRadius
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.systemGray.withAlphaComponent(0.3).cgColor
        
        // Level bar (filled portion)
        levelBar.wantsLayer = true
        levelBar.layer?.cornerRadius = Constants.cornerRadius
        levelBar.layer?.backgroundColor = NSColor.systemGreen.cgColor
        levelBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(levelBar)
        
        // Create width constraint for animation
        levelBarWidthConstraint = levelBar.widthAnchor.constraint(equalToConstant: 0)
        
        NSLayoutConstraint.activate([
            levelBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            levelBar.topAnchor.constraint(equalTo: topAnchor),
            levelBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            levelBarWidthConstraint!
        ])
    }
    
    /// Update the level meter display
    /// - Parameter level: Audio level in dB (typically -60 to 0)
    func updateLevel(_ level: Float) {
        // Clamp level to valid range
        let clampedLevel = max(Constants.minDB, min(Constants.maxDB, level))
        
        // Convert dB to linear percentage (0 to 1)
        // Using a simple linear mapping from -60dB to 0dB
        let percentage = (clampedLevel - Constants.minDB) / (Constants.maxDB - Constants.minDB)
        
        // Calculate width based on percentage
        let newWidth = bounds.width * CGFloat(percentage)
        
        // Update color based on level
        let color: NSColor
        if clampedLevel < Constants.silenceThreshold {
            // Below silence threshold - show as dim/gray-ish
            color = .systemGray
        } else if clampedLevel < -20 {
            // Normal speaking level - green
            color = .systemGreen
        } else if clampedLevel < -6 {
            // Getting louder - yellow
            color = .systemYellow
        } else {
            // Very loud / near clipping - red
            color = .systemRed
        }
        
        // Animate the update
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.05  // Fast update for responsive metering
            context.allowsImplicitAnimation = true
            self.levelBarWidthConstraint?.constant = newWidth
            self.levelBar.layer?.backgroundColor = color.cgColor
            self.layoutSubtreeIfNeeded()
        }
    }
}
