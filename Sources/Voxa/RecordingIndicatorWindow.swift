import AppKit
import Combine

/// Floating recording indicator window that shows when recording is active
/// Displays an elegant pill-shaped overlay with recording status, waveform visualization, and cancel button
/// Features frosted glass effect, warm colors, and smooth animations
final class RecordingIndicatorWindow: NSPanel {
    
    // MARK: - UI Components
    
    private let containerView = NSView()
    private let recordingDot = NSView()
    private let waveformView = LiveWaveformView()
    private let statusLabel = NSTextField()
    private let durationLabel = NSTextField()
    private let cancelButton = HoverGlowButton()
    private var trackingArea: NSTrackingArea?
    
    /// Callback when cancel button is clicked
    var onCancel: (() -> Void)?
    
    /// Audio level subscription
    private var audioLevelCancellable: AnyCancellable?
    
    /// Recording duration timer
    private var durationTimer: Timer?
    private var recordingStartTime: Date?

    /// Pulse animation for recording dot
    private var pulseTimer: Timer?
    private var pulsePhase: CGFloat = 0

    // US-054: Battery optimization observer
    private var batteryOptimizationObserver: NSObjectProtocol?
    
    // MARK: - Configuration
    
    private struct Constants {
        static let windowWidth: CGFloat = 240
        static let windowHeight: CGFloat = 52
        static let cornerRadius: CGFloat = 26
        static let padding: CGFloat = 16
        static let dotSize: CGFloat = 12
        static let waveformWidth: CGFloat = 60
        static let waveformHeight: CGFloat = 24
        static let cancelButtonSize: CGFloat = 22
        static let animationDuration: TimeInterval = 0.35
        static let slideOffset: CGFloat = 60
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
        setupBatteryOptimizationObserver()
    }

    // MARK: - US-054: Battery Optimization

    private func setupBatteryOptimizationObserver() {
        batteryOptimizationObserver = NotificationCenter.default.addObserver(
            forName: .batteryOptimizationStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Restart active animations with new intervals when battery state changes
            self?.restartActiveAnimationsWithNewIntervals()
        }
    }

    /// Restart any active animations with updated intervals based on battery state
    private func restartActiveAnimationsWithNewIntervals() {
        // If pulse animation is running, restart it with new interval
        if pulseTimer != nil {
            stopPulsingAnimation()
            startPulsingAnimation()
        }
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
        
        // Position window at top center of main screen (with offset for slide animation)
        positionWindow(withSlideOffset: true)
    }
    
    private func setupUI() {
        guard let contentView = self.contentView else { return }
        
        // Container view with pill shape
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = Constants.cornerRadius
        containerView.layer?.masksToBounds = true
        
        // Use visual effect view for frosted glass background with warm tint
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = Constants.cornerRadius
        visualEffect.layer?.masksToBounds = true
        
        // Apply warm ivory tint overlay for warmth
        let warmOverlay = NSView()
        warmOverlay.wantsLayer = true
        warmOverlay.layer?.backgroundColor = NSColor.Voxa.background.withAlphaComponent(0.3).cgColor
        warmOverlay.translatesAutoresizingMaskIntoConstraints = false
        
        // Add drop shadow layer for floating effect
        let shadowView = NSView()
        shadowView.wantsLayer = true
        shadowView.layer?.cornerRadius = Constants.cornerRadius
        shadowView.layer?.shadowColor = NSColor.Voxa.textPrimary.withAlphaComponent(0.2).cgColor
        shadowView.layer?.shadowOpacity = 1.0
        shadowView.layer?.shadowOffset = CGSize(width: 0, height: -4)
        shadowView.layer?.shadowRadius = 16
        shadowView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.01).cgColor
        shadowView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(shadowView)
        
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(visualEffect)
        
        // Add warm overlay inside visual effect
        visualEffect.addSubview(warmOverlay)
        
        // Container inside visual effect
        containerView.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(containerView)
        
        // Recording dot (warm coral pulsing circle)
        recordingDot.wantsLayer = true
        recordingDot.layer?.cornerRadius = Constants.dotSize / 2
        recordingDot.layer?.backgroundColor = NSColor.Voxa.accent.cgColor
        recordingDot.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(recordingDot)
        
        // Audio waveform visualization (smooth wave, not bars)
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(waveformView)
        
        // Status label with elegant typography
        statusLabel.stringValue = "Recording"
        statusLabel.font = NSFont.Voxa.caption
        statusLabel.textColor = NSColor.Voxa.textSecondary
        statusLabel.backgroundColor = .clear
        statusLabel.isBordered = false
        statusLabel.isEditable = false
        statusLabel.isSelectable = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusLabel)
        
        // Duration label with elegant typography
        durationLabel.stringValue = "0:00"
        durationLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        durationLabel.textColor = NSColor.Voxa.textPrimary
        durationLabel.backgroundColor = .clear
        durationLabel.isBordered = false
        durationLabel.isEditable = false
        durationLabel.isSelectable = false
        durationLabel.alignment = .left
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(durationLabel)
        
        // Cancel button with hover glow
        cancelButton.target = self
        cancelButton.action = #selector(cancelButtonClicked)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(cancelButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Shadow view fills content view
            shadowView.topAnchor.constraint(equalTo: contentView.topAnchor),
            shadowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            shadowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            shadowView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Visual effect fills content view
            visualEffect.topAnchor.constraint(equalTo: contentView.topAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Warm overlay fills visual effect
            warmOverlay.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            warmOverlay.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            warmOverlay.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
            warmOverlay.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            
            // Container fills visual effect
            containerView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            
            // Recording dot on the left
            recordingDot.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Constants.padding),
            recordingDot.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            recordingDot.widthAnchor.constraint(equalToConstant: Constants.dotSize),
            recordingDot.heightAnchor.constraint(equalToConstant: Constants.dotSize),
            
            // Audio waveform next to recording dot
            waveformView.leadingAnchor.constraint(equalTo: recordingDot.trailingAnchor, constant: 10),
            waveformView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            waveformView.widthAnchor.constraint(equalToConstant: Constants.waveformWidth),
            waveformView.heightAnchor.constraint(equalToConstant: Constants.waveformHeight),
            
            // Status label and duration stacked vertically
            statusLabel.leadingAnchor.constraint(equalTo: waveformView.trailingAnchor, constant: 10),
            statusLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            
            durationLabel.leadingAnchor.constraint(equalTo: waveformView.trailingAnchor, constant: 10),
            durationLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10),
            
            // Cancel button on the right
            cancelButton.leadingAnchor.constraint(greaterThanOrEqualTo: statusLabel.trailingAnchor, constant: 8),
            cancelButton.leadingAnchor.constraint(greaterThanOrEqualTo: durationLabel.trailingAnchor, constant: 8),
            cancelButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Constants.padding),
            cancelButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: Constants.cancelButtonSize),
            cancelButton.heightAnchor.constraint(equalToConstant: Constants.cancelButtonSize)
        ])
    }
    
    private func positionWindow(withSlideOffset: Bool = false) {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowX = screenFrame.midX - (Constants.windowWidth / 2)
        let baseY = screenFrame.maxY - Constants.windowHeight - 20 // 20px from top
        let windowY = withSlideOffset ? baseY + Constants.slideOffset : baseY
        
        setFrameOrigin(NSPoint(x: windowX, y: windowY))
    }
    
    // MARK: - Animations
    
    private func startPulsingAnimation() {
        // Stop any existing animation
        stopPulsingAnimation()

        // US-054: Use battery-efficient pulse animation interval
        let interval = BatteryEfficiencyManager.shared.pulseAnimationInterval
        // Gentle pulse animation using timer for smooth coral dot pulsing
        pulseTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // US-054: Adjust phase increment based on interval to maintain consistent animation speed
            let phaseIncrement = 0.05 * (0.03 / interval)
            self.pulsePhase += phaseIncrement
            if self.pulsePhase > CGFloat.pi * 2 {
                self.pulsePhase -= CGFloat.pi * 2
            }

            // Pulse opacity between 0.6 and 1.0
            let opacity = 0.8 + 0.2 * sin(self.pulsePhase)

            // Pulse scale between 0.9 and 1.1
            let scale = 1.0 + 0.1 * sin(self.pulsePhase)

            DispatchQueue.main.async {
                self.recordingDot.layer?.opacity = Float(opacity)
                self.recordingDot.layer?.transform = CATransform3DMakeScale(scale, scale, 1.0)
            }
        }
        // US-054: Allow timer coalescing for better battery efficiency
        pulseTimer?.tolerance = interval * 0.2
    }
    
    private func stopPulsingAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        recordingDot.layer?.opacity = 1.0
        recordingDot.layer?.transform = CATransform3DIdentity
    }
    
    private func startDurationTimer() {
        recordingStartTime = Date()
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDurationDisplay()
        }
        updateDurationDisplay()
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
        recordingStartTime = nil
        durationLabel.stringValue = "0:00"
    }
    
    private func updateDurationDisplay() {
        guard let startTime = recordingStartTime else { return }
        let elapsed = Int(Date().timeIntervalSince(startTime))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        durationLabel.stringValue = String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Actions
    
    @objc private func cancelButtonClicked() {
        print("Cancel button clicked on recording indicator")
        onCancel?()
    }
    
    // MARK: - Public API
    
    /// Show the indicator with smooth slide-down animation
    func showWithAnimation() {
        // Start with window above screen (for slide-down effect)
        positionWindow(withSlideOffset: true)
        alphaValue = 0
        orderFrontRegardless()
        
        // Animate slide down and fade in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constants.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }
        
        // Animate position separately for smooth slide
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let targetY = screenFrame.maxY - Constants.windowHeight - 20
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constants.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            let currentFrame = self.frame
            self.animator().setFrameOrigin(NSPoint(x: currentFrame.origin.x, y: targetY))
        }
        
        startPulsingAnimation()
        startDurationTimer()
        print("Recording indicator shown with slide-down animation")
    }
    
    /// Hide the indicator with smooth slide-up animation
    func hideWithAnimation(completion: (() -> Void)? = nil) {
        stopPulsingAnimation()
        stopDurationTimer()
        
        // Calculate slide-up target position
        guard let screen = NSScreen.main else {
            orderOut(nil)
            completion?()
            return
        }
        let screenFrame = screen.visibleFrame
        let targetY = screenFrame.maxY + Constants.slideOffset
        
        // Animate slide up and fade out
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Constants.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
            let currentFrame = self.frame
            self.animator().setFrameOrigin(NSPoint(x: currentFrame.origin.x, y: targetY))
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            // Reset position for next show
            self?.positionWindow(withSlideOffset: true)
            completion?()
        })
        
        print("Recording indicator hidden with slide-up animation")
    }
    
    /// Update the status text
    func updateStatus(_ text: String) {
        statusLabel.stringValue = text
    }
    
    /// Update audio waveform with current level (value in dB, typically -60 to 0)
    func updateAudioLevel(_ level: Float) {
        waveformView.updateLevel(level)
    }
    
    /// Connect to AudioManager for real-time level updates
    func connectAudioManager(_ audioManager: AudioManager) {
        audioLevelCancellable = audioManager.$currentAudioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.waveformView.updateLevel(level)
            }
    }
    
    /// Disconnect from AudioManager
    func disconnectAudioManager() {
        audioLevelCancellable?.cancel()
        audioLevelCancellable = nil
        waveformView.updateLevel(-60.0)
    }
    
    deinit {
        stopPulsingAnimation()
        stopDurationTimer()
        audioLevelCancellable?.cancel()
        // US-054: Remove battery optimization observer
        if let observer = batteryOptimizationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Window Behavior Overrides
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}

// MARK: - Live Waveform View

/// Smooth, animated waveform visualization that responds to audio level in real-time
/// Creates an elegant, flowing wave effect instead of harsh bars
final class LiveWaveformView: NSView {

    /// Number of wave points to render
    private let wavePointCount = 20

    /// Current audio level (0-1)
    private var currentLevel: CGFloat = 0

    /// Wave phase for animation
    private var wavePhase: CGFloat = 0

    /// Animation timer
    private var animationTimer: Timer?

    /// Wave shape layer
    private let waveLayer = CAShapeLayer()

    // US-054: Battery optimization observer
    private var batteryOptimizationObserver: NSObjectProtocol?

    private struct Constants {
        static let minDB: Float = -60.0
        static let maxDB: Float = 0.0
        static let silenceThreshold: Float = -55.0
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
        layer?.masksToBounds = true

        // Configure wave layer
        waveLayer.fillColor = NSColor.Voxa.accent.withAlphaComponent(0.4).cgColor
        waveLayer.strokeColor = NSColor.Voxa.accent.cgColor
        waveLayer.lineWidth = 2.0
        waveLayer.lineCap = .round
        waveLayer.lineJoin = .round
        layer?.addSublayer(waveLayer)

        // Start animation loop
        startAnimation()

        // US-054: Set up battery optimization observer
        setupBatteryOptimizationObserver()
    }

    // MARK: - US-054: Battery Optimization

    private func setupBatteryOptimizationObserver() {
        batteryOptimizationObserver = NotificationCenter.default.addObserver(
            forName: .batteryOptimizationStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Restart animation with new interval when battery state changes
            self?.restartAnimationWithNewInterval()
        }
    }

    private func restartAnimationWithNewInterval() {
        if animationTimer != nil {
            stopAnimation()
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // US-054: Use battery-efficient waveform animation interval
        let interval = BatteryEfficiencyManager.shared.waveformAnimationInterval
        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateWave()
        }
        // US-054: Allow timer coalescing for better battery efficiency
        animationTimer?.tolerance = interval * 0.2
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func updateWave() {
        wavePhase += 0.15
        if wavePhase > CGFloat.pi * 2 {
            wavePhase -= CGFloat.pi * 2
        }
        
        // Update the wave path
        let path = createWavePath()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        waveLayer.path = path.cgPath
        CATransaction.commit()
    }
    
    private func createWavePath() -> NSBezierPath {
        let path = NSBezierPath()
        let width = bounds.width
        let height = bounds.height
        let midY = height / 2
        
        // Base amplitude varies with audio level
        let baseAmplitude = height * 0.4 * currentLevel
        
        // Start at left middle
        path.move(to: NSPoint(x: 0, y: midY))
        
        // Create smooth wave using bezier curves
        let segmentWidth = width / CGFloat(wavePointCount - 1)
        
        for i in 0..<wavePointCount {
            let x = CGFloat(i) * segmentWidth
            
            // Multiple sine waves for organic feel
            let wave1 = sin(wavePhase + CGFloat(i) * 0.5) * baseAmplitude
            let wave2 = sin(wavePhase * 1.5 + CGFloat(i) * 0.3) * baseAmplitude * 0.5
            let wave3 = sin(wavePhase * 0.7 + CGFloat(i) * 0.7) * baseAmplitude * 0.3
            
            let y = midY + wave1 + wave2 + wave3
            
            if i == 0 {
                path.move(to: NSPoint(x: x, y: y))
            } else {
                // Use smooth curve to point
                let prevX = CGFloat(i - 1) * segmentWidth
                let controlX = (prevX + x) / 2
                path.curve(
                    to: NSPoint(x: x, y: y),
                    controlPoint1: NSPoint(x: controlX, y: path.currentPoint.y),
                    controlPoint2: NSPoint(x: controlX, y: y)
                )
            }
        }
        
        // Close the path to create fill
        path.line(to: NSPoint(x: width, y: midY))
        path.line(to: NSPoint(x: width, y: height))
        path.line(to: NSPoint(x: 0, y: height))
        path.close()
        
        return path
    }
    
    override func layout() {
        super.layout()
        waveLayer.frame = bounds
    }
    
    /// Update the waveform with current audio level (in dB)
    func updateLevel(_ level: Float) {
        // Clamp level to valid range
        let clampedLevel = max(Constants.minDB, min(Constants.maxDB, level))
        
        // Convert dB to linear percentage (0 to 1)
        var percentage = (clampedLevel - Constants.minDB) / (Constants.maxDB - Constants.minDB)
        
        // Apply some smoothing
        if clampedLevel < Constants.silenceThreshold {
            percentage *= 0.3 // Reduce visual when quiet
        }
        
        // Smooth transition to new level
        let targetLevel = CGFloat(percentage)
        currentLevel = currentLevel * 0.7 + targetLevel * 0.3
        
        // Update wave color based on level
        let color: NSColor
        if clampedLevel < Constants.silenceThreshold {
            color = NSColor.Voxa.textSecondary.withAlphaComponent(0.3)
        } else if clampedLevel < -20 {
            color = NSColor.Voxa.success
        } else if clampedLevel < -6 {
            color = NSColor.Voxa.accent
        } else {
            color = NSColor.Voxa.accent
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        waveLayer.strokeColor = color.cgColor
        waveLayer.fillColor = color.withAlphaComponent(0.3).cgColor
        CATransaction.commit()
    }
    
    deinit {
        stopAnimation()
        // US-054: Remove battery optimization observer
        if let observer = batteryOptimizationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Hover Glow Button

/// Cancel button with elegant hover glow effect
final class HoverGlowButton: NSButton {
    
    /// Glow layer for hover effect
    private let glowLayer = CALayer()
    
    /// Tracking area for hover
    private var hoverTrackingArea: NSTrackingArea?
    
    /// Whether button is hovered
    private var isHovered = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        wantsLayer = true
        isBordered = false
        
        // Configure button appearance
        let xImage = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Cancel recording")
        image = xImage
        imagePosition = .imageOnly
        contentTintColor = NSColor.Voxa.textSecondary
        
        // Configure glow layer
        glowLayer.backgroundColor = NSColor.Voxa.accent.withAlphaComponent(0.0).cgColor
        glowLayer.cornerRadius = 11
        layer?.insertSublayer(glowLayer, at: 0)
        
        updateTrackingAreas()
    }
    
    override func layout() {
        super.layout()
        glowLayer.frame = bounds.insetBy(dx: -4, dy: -4)
        glowLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    override func updateTrackingAreas() {
        if let area = hoverTrackingArea {
            removeTrackingArea(area)
        }
        
        hoverTrackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        
        if let area = hoverTrackingArea {
            addTrackingArea(area)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        animateHover(true)
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        animateHover(false)
    }
    
    private func animateHover(_ hover: Bool) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            
            if hover {
                contentTintColor = NSColor.Voxa.accent
                glowLayer.backgroundColor = NSColor.Voxa.accent.withAlphaComponent(0.2).cgColor
                glowLayer.shadowColor = NSColor.Voxa.accent.cgColor
                glowLayer.shadowOpacity = 0.5
                glowLayer.shadowRadius = 8
                glowLayer.shadowOffset = .zero
            } else {
                contentTintColor = NSColor.Voxa.textSecondary
                glowLayer.backgroundColor = NSColor.Voxa.accent.withAlphaComponent(0.0).cgColor
                glowLayer.shadowOpacity = 0
            }
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        // Scale down on press
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            self.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.9, y: 0.9))
        }
        super.mouseDown(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        // Scale back to normal
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            self.layer?.setAffineTransform(.identity)
        }
        super.mouseUp(with: event)
    }
}
