import SwiftUI
import AppKit

// MARK: - Toast Types

/// Toast notification types with corresponding colors and icons
enum ToastType {
    case success
    case error
    case warning  // US-501: Warning toast type for low-quality device notifications
    case info
    
    /// Background color for the toast type
    var backgroundColor: Color {
        switch self {
        case .success:
            return Color.Wispflow.success
        case .error:
            return Color.Wispflow.accent  // Coral for errors per PRD
        case .warning:
            return Color.Wispflow.warning  // Orange for warnings
        case .info:
            return Color.Wispflow.textSecondary
        }
    }
    
    /// Light background color for frosted glass effect
    var lightBackgroundColor: Color {
        switch self {
        case .success:
            return Color.Wispflow.successLight
        case .error:
            return Color.Wispflow.accentLight
        case .warning:
            return Color.Wispflow.warning.opacity(0.2)
        case .info:
            return Color.Wispflow.border
        }
    }
    
    /// Default icon for the toast type
    var defaultIcon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
}

// MARK: - Toast Item

/// Individual toast item with all configuration
struct ToastItem: Identifiable, Equatable {
    let id: UUID
    let type: ToastType
    let title: String
    let message: String?
    let icon: String?
    let actionTitle: String?
    let action: (() -> Void)?
    let duration: TimeInterval
    
    init(
        id: UUID = UUID(),
        type: ToastType,
        title: String,
        message: String? = nil,
        icon: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        duration: TimeInterval = 3.0
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
        self.duration = duration
    }
    
    static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Toast Manager

/// Observable object that manages toast notifications with queue support
final class ToastManager: ObservableObject {
    /// Singleton instance for app-wide toast notifications
    static let shared = ToastManager()
    
    /// Currently visible toasts
    @Published private(set) var activeToasts: [ToastItem] = []
    
    /// Maximum number of concurrent toasts
    private let maxVisibleToasts = 3
    
    /// Queue for toasts waiting to be shown
    private var toastQueue: [ToastItem] = []
    
    /// Timer references for auto-dismiss
    private var dismissTimers: [UUID: Timer] = [:]
    
    private init() {}
    
    // MARK: - Public API
    
    /// Show a success toast
    func showSuccess(
        _ title: String,
        message: String? = nil,
        icon: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        duration: TimeInterval = 3.0
    ) {
        let toast = ToastItem(
            type: .success,
            title: title,
            message: message,
            icon: icon,
            actionTitle: actionTitle,
            action: action,
            duration: duration
        )
        show(toast)
    }
    
    /// Show an error toast
    func showError(
        _ title: String,
        message: String? = nil,
        icon: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        duration: TimeInterval = 4.0
    ) {
        let toast = ToastItem(
            type: .error,
            title: title,
            message: message,
            icon: icon,
            actionTitle: actionTitle,
            action: action,
            duration: duration
        )
        show(toast)
    }
    
    /// Show an info toast
    func showInfo(
        _ title: String,
        message: String? = nil,
        icon: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        duration: TimeInterval = 3.0
    ) {
        let toast = ToastItem(
            type: .info,
            title: title,
            message: message,
            icon: icon,
            actionTitle: actionTitle,
            action: action,
            duration: duration
        )
        show(toast)
    }
    
    /// US-501: Show a warning toast
    func showWarning(
        _ title: String,
        message: String? = nil,
        icon: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        duration: TimeInterval = 4.0
    ) {
        let toast = ToastItem(
            type: .warning,
            title: title,
            message: message,
            icon: icon,
            actionTitle: actionTitle,
            action: action,
            duration: duration
        )
        show(toast)
    }
    
    /// Show a custom toast
    func show(_ toast: ToastItem) {
        DispatchQueue.main.async {
            if self.activeToasts.count < self.maxVisibleToasts {
                self.displayToast(toast)
            } else {
                self.toastQueue.append(toast)
            }
        }
    }
    
    /// Dismiss a specific toast
    func dismiss(_ toast: ToastItem) {
        dismiss(id: toast.id)
    }
    
    /// Dismiss a toast by ID
    func dismiss(id: UUID) {
        DispatchQueue.main.async {
            // Cancel timer
            self.dismissTimers[id]?.invalidate()
            self.dismissTimers.removeValue(forKey: id)
            
            // Remove from active toasts with animation
            withAnimation(WispflowAnimation.slide) {
                self.activeToasts.removeAll { $0.id == id }
            }
            
            // Show next queued toast if available
            self.showNextQueuedToast()
        }
    }
    
    /// Dismiss all toasts
    func dismissAll() {
        DispatchQueue.main.async {
            // Cancel all timers
            self.dismissTimers.values.forEach { $0.invalidate() }
            self.dismissTimers.removeAll()
            
            // Clear queue and active toasts
            self.toastQueue.removeAll()
            withAnimation(WispflowAnimation.slide) {
                self.activeToasts.removeAll()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func displayToast(_ toast: ToastItem) {
        withAnimation(WispflowAnimation.slide) {
            activeToasts.insert(toast, at: 0)
        }
        
        // Schedule auto-dismiss
        let timer = Timer.scheduledTimer(withTimeInterval: toast.duration, repeats: false) { [weak self] _ in
            self?.dismiss(id: toast.id)
        }
        dismissTimers[toast.id] = timer
    }
    
    private func showNextQueuedToast() {
        guard !toastQueue.isEmpty, activeToasts.count < maxVisibleToasts else { return }
        
        let nextToast = toastQueue.removeFirst()
        displayToast(nextToast)
    }
}

// MARK: - WispflowToast View Component

/// Individual toast view with frosted glass effect and slide-in animation
struct WispflowToast: View {
    let toast: ToastItem
    let onDismiss: () -> Void
    
    @State private var isHovering = false
    @State private var progress: Double = 1.0
    @State private var progressTimer: Timer?
    @State private var showCheckmark = false
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon - use animated checkmark for success type
            ZStack {
                if toast.type == .success && showCheckmark {
                    // Animated checkmark for success
                    AnimatedCheckmark(
                        size: 36,
                        strokeWidth: 3,
                        color: toast.type.backgroundColor
                    )
                } else {
                    Circle()
                        .fill(toast.type.backgroundColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: toast.icon ?? toast.type.defaultIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(toast.type.backgroundColor)
                }
            }
            .onAppear {
                // Trigger animated checkmark for success toasts
                if toast.type == .success {
                    withAnimation {
                        showCheckmark = true
                    }
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(toast.title)
                    .font(Font.Wispflow.body)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.Wispflow.textPrimary)
                    .lineLimit(2)
                
                if let message = toast.message {
                    Text(message)
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer(minLength: Spacing.sm)
            
            // Action button (optional)
            if let actionTitle = toast.actionTitle, let action = toast.action {
                Button(action: {
                    action()
                    onDismiss()
                }) {
                    Text(actionTitle)
                        .font(Font.Wispflow.caption)
                        .fontWeight(.medium)
                        .foregroundColor(toast.type.backgroundColor)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(toast.type.backgroundColor.opacity(0.15))
                        .cornerRadius(CornerRadius.small / 2)
                }
                .buttonStyle(.plain)
            }
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.Wispflow.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(isHovering ? Color.Wispflow.border.opacity(0.5) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .frame(minWidth: 280, maxWidth: 380)
        .background(
            ZStack {
                // Frosted glass effect background
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(.ultraThinMaterial)
                
                // Warm tint overlay for design system compliance
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color.Wispflow.background.opacity(0.7))
                
                // Subtle colored border based on type
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(toast.type.backgroundColor.opacity(0.3), lineWidth: 1)
            }
        )
        .overlay(
            // Auto-dismiss progress bar
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(toast.type.backgroundColor.opacity(0.5))
                        .frame(width: geometry.size.width * CGFloat(progress), height: 2)
                        .animation(.linear, value: progress)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        )
        .wispflowShadow(.floating)
        .onHover { hovering in
            isHovering = hovering
            
            // Pause/resume progress on hover
            if hovering {
                progressTimer?.invalidate()
            } else {
                startProgressTimer()
            }
        }
        .onAppear {
            startProgressTimer()
        }
        .onDisappear {
            progressTimer?.invalidate()
        }
    }
    
    private func startProgressTimer() {
        let updateInterval = 0.05
        let decrementAmount = updateInterval / toast.duration
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
            if progress > 0 {
                progress -= decrementAmount
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Toast Container View

/// Container view that displays all active toasts with proper positioning and animations
struct ToastContainerView: View {
    @ObservedObject var toastManager: ToastManager
    
    var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.sm) {
            ForEach(toastManager.activeToasts) { toast in
                WispflowToast(
                    toast: toast,
                    onDismiss: {
                        toastManager.dismiss(toast)
                    }
                )
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    )
                )
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}

// MARK: - Toast Window Controller

/// NSWindow-based controller for displaying toasts above all other windows
final class ToastWindowController {
    private var toastWindow: NSWindow?
    private var hostingController: NSHostingController<ToastContainerView>?
    
    static let shared = ToastWindowController()
    
    private init() {
        setupWindow()
    }
    
    private func setupWindow() {
        // Create a borderless, transparent window that floats above everything
        let window = NSWindow(
            contentRect: NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        // CRITICAL: Must ignore mouse events so clicks pass through to other windows
        // The toast content itself handles its own mouse events via SwiftUI
        window.ignoresMouseEvents = true
        window.hasShadow = false
        
        // Allow click-through except for toast content
        window.isMovableByWindowBackground = false
        
        // Set up the hosting controller with toast container
        let containerView = ToastContainerView(toastManager: ToastManager.shared)
        hostingController = NSHostingController(rootView: containerView)
        
        if let hostingView = hostingController?.view {
            hostingView.frame = window.contentView?.bounds ?? .zero
            hostingView.autoresizingMask = [.width, .height]
            window.contentView?.addSubview(hostingView)
        }
        
        toastWindow = window
        window.orderFront(nil)
    }
    
    /// Show the toast window (automatically shown on first toast)
    func show() {
        toastWindow?.orderFront(nil)
    }
    
    /// Hide the toast window
    func hide() {
        toastWindow?.orderOut(nil)
    }
    
    /// Update window frame to match screen
    func updateFrame() {
        if let screen = NSScreen.main {
            toastWindow?.setFrame(screen.visibleFrame, display: true)
        }
    }
}

// MARK: - View Extension for Toast Integration

extension View {
    /// Add toast overlay to any view
    func toastContainer() -> some View {
        self.overlay(
            ToastContainerView(toastManager: ToastManager.shared)
        )
    }
}

// MARK: - Convenience Extensions for Common Toasts

extension ToastManager {
    /// Show toast for successful transcription
    func showTranscriptionSuccess(wordCount: Int = 0) {
        let message = wordCount > 0 ? "\(wordCount) words transcribed" : nil
        showSuccess("Transcription Complete", message: message, icon: "waveform")
    }
    
    /// Show toast for transcription error
    func showTranscriptionError(_ error: String? = nil) {
        showError(
            "Transcription Failed",
            message: error ?? "An error occurred during transcription",
            icon: "waveform.slash",
            actionTitle: "Settings",
            action: {
                // This will be connected to open settings in integration
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }
        )
    }
    
    /// Show toast for model download complete
    func showModelDownloadComplete(modelName: String) {
        showSuccess(
            "Model Downloaded",
            message: "\(modelName) is ready to use",
            icon: "arrow.down.circle.fill"
        )
    }
    
    /// Show toast for model loading
    func showModelLoading(modelName: String) {
        showInfo(
            "Loading Model",
            message: "\(modelName) is being loaded...",
            icon: "cpu",
            duration: 2.0
        )
    }
    
    /// Show toast for clipboard copy
    func showCopiedToClipboard() {
        showSuccess("Copied to Clipboard", icon: "doc.on.clipboard", duration: 2.0)
    }
    
    /// Show toast for audio export
    func showAudioExported(path: String) {
        showSuccess(
            "Audio Exported",
            message: "Saved to \(path)",
            icon: "square.and.arrow.up",
            actionTitle: "Show",
            action: {
                if let url = URL(string: "file://\(path)") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
        )
    }
    
    /// US-501: Show warning toast for low-quality audio device
    func showLowQualityDeviceWarning(deviceName: String) {
        showWarning(
            "Low-Quality Microphone",
            message: "Using \(deviceName). For best results, connect a better microphone.",
            icon: "mic.badge.exclamationmark",
            actionTitle: "Settings",
            action: {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            },
            duration: 5.0
        )
    }
    
    /// US-515: Show toast prompting user to manually paste
    /// Used as fallback when automatic paste simulation fails
    func showManualPasteRequired() {
        showInfo(
            "Text copied",
            message: "Press Cmd+V to paste",
            icon: "doc.on.clipboard",
            duration: 5.0
        )
    }
    
    // MARK: - US-601: Audio Device Hot-Plug Toast Notifications
    
    /// Show toast when audio device is disconnected during recording
    /// Informs user that recording has been switched to a fallback device
    func showDeviceDisconnectedDuringRecording(disconnectedName: String, fallbackName: String) {
        showWarning(
            "Audio Device Changed",
            message: "\(disconnectedName) disconnected. Switched to \(fallbackName).",
            icon: "cable.connector.slash",
            duration: 5.0
        )
    }
    
    /// Show toast when audio device changes (not during recording)
    func showDeviceChanged(from oldDevice: String?, to newDevice: String, reason: String) {
        let message: String
        if let old = oldDevice {
            message = "Changed from \(old) to \(newDevice)"
        } else {
            message = "Now using \(newDevice)"
        }
        showInfo(
            "Audio Device Changed",
            message: message,
            icon: "mic.fill",
            duration: 4.0
        )
    }
    
    /// Show toast when the user's preferred audio device is reconnected
    func showPreferredDeviceReconnected(deviceName: String) {
        showSuccess(
            "Preferred Device Connected",
            message: "\(deviceName) is now active",
            icon: "checkmark.circle.fill",
            duration: 4.0
        )
    }
    
    // MARK: - US-603: Recording Timeout Toast Notifications
    
    /// Show warning toast when recording approaches the maximum duration
    /// Parameter remainingSeconds: Time remaining until auto-stop (typically 60 seconds)
    func showRecordingTimeoutWarning(remainingSeconds: TimeInterval) {
        let minutes = Int(remainingSeconds / 60)
        let seconds = Int(remainingSeconds.truncatingRemainder(dividingBy: 60))
        let timeString = minutes > 0 ? "\(minutes) minute\(minutes > 1 ? "s" : "")" : "\(seconds) seconds"
        
        showWarning(
            "Recording Limit Approaching",
            message: "\(timeString) remaining until auto-stop",
            icon: "clock.badge.exclamationmark",
            duration: 6.0
        )
    }
    
    /// Show info toast when recording auto-stops due to reaching maximum duration
    func showRecordingAutoStopped() {
        showInfo(
            "Recording Auto-Stopped",
            message: "Maximum duration reached. Transcribing...",
            icon: "stop.circle.fill",
            duration: 4.0
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openSettings = Notification.Name("WispFlow.openSettings")
}
