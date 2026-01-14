import SwiftUI
import AppKit

// MARK: - Onboarding Step Enum

/// Steps in the onboarding wizard flow
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case microphone = 1
    // Future steps will be added here:
    // case accessibility = 2
    // case audioTest = 3
    // case hotkey = 4
    // case completion = 5
    
    var title: String {
        switch self {
        case .welcome:
            return "Welcome to WispFlow"
        case .microphone:
            return "Microphone Permission"
        }
    }
    
    /// Get the next step in the onboarding flow, if any
    var nextStep: OnboardingStep? {
        guard let nextIndex = OnboardingStep.allCases.firstIndex(of: self)?.advanced(by: 1),
              nextIndex < OnboardingStep.allCases.count else {
            return nil
        }
        return OnboardingStep.allCases[nextIndex]
    }
}

// MARK: - Welcome Screen (US-517)

/// Welcome screen shown on first launch - explains what WispFlow does
/// US-517: Onboarding Welcome Screen
struct WelcomeView: View {
    /// Callback when user clicks "Get Started"
    var onGetStarted: () -> Void
    
    /// Callback when user clicks "Skip Setup"
    var onSkipSetup: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: Spacing.xxl)
            
            // App icon/logo displayed prominently
            appLogo
            
            Spacer()
                .frame(height: Spacing.xl)
            
            // Title
            Text("WispFlow")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(Color.Wispflow.textPrimary)
            
            Spacer()
                .frame(height: Spacing.sm)
            
            // Brief description: "Voice-to-text for your Mac"
            Text("Voice-to-text for your Mac")
                .font(Font.Wispflow.title)
                .foregroundColor(Color.Wispflow.textSecondary)
            
            Spacer()
                .frame(height: Spacing.xxl)
            
            // Key features listed (3-4 bullet points)
            featuresList
            
            Spacer()
                .frame(height: Spacing.xxl)
            
            // "Get Started" button advances to next step
            Button(action: onGetStarted) {
                Text("Get Started")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, Spacing.md)
                    .background(Color.Wispflow.accent)
                    .cornerRadius(CornerRadius.small)
            }
            .buttonStyle(InteractiveScaleStyle())
            
            Spacer()
                .frame(height: Spacing.lg)
            
            // "Skip Setup" link available (not prominent)
            Button(action: onSkipSetup) {
                Text("Skip Setup")
                    .font(Font.Wispflow.caption)
                    .foregroundColor(Color.Wispflow.textSecondary)
                    .underline()
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(0.7)
            .onHover { hovering in
                // Could add hover state if needed
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Wispflow.background)
    }
    
    // MARK: - App Logo
    
    /// App icon/logo displayed prominently
    private var appLogo: some View {
        ZStack {
            // Outer glow circle
            Circle()
                .fill(Color.Wispflow.accent.opacity(0.15))
                .frame(width: 120, height: 120)
            
            // Inner circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.Wispflow.accent.opacity(0.9), Color.Wispflow.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 90, height: 90)
                .shadow(color: Color.Wispflow.accent.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Microphone icon representing voice-to-text
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Features List
    
    /// Key features listed (3-4 bullet points)
    private var featuresList: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            FeatureRow(
                icon: "mic.fill",
                title: "Record with a Hotkey",
                description: "Press ⌘⇧Space to start recording anywhere"
            )
            
            FeatureRow(
                icon: "text.bubble.fill",
                title: "Instant Transcription",
                description: "Your voice becomes text in seconds"
            )
            
            FeatureRow(
                icon: "wand.and.stars",
                title: "Smart Text Cleanup",
                description: "Automatic punctuation and formatting"
            )
            
            FeatureRow(
                icon: "lock.shield.fill",
                title: "Private & Local",
                description: "All processing happens on your Mac"
            )
        }
        .padding(.horizontal, Spacing.xxl)
    }
}

// MARK: - Feature Row Component

/// A single feature row with icon, title, and description
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            // Icon in a rounded square
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color.Wispflow.accentLight)
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.Wispflow.accent)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Text(description)
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.textSecondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Microphone Permission Screen (US-518)

/// Microphone permission step - guides user through granting microphone access
/// US-518: Microphone Permission Step
struct MicrophonePermissionView: View {
    /// Permission manager for status tracking and requesting permission
    @ObservedObject var permissionManager: PermissionManager
    
    /// Callback when user clicks "Continue"
    var onContinue: () -> Void
    
    /// Callback when user clicks "Skip"
    var onSkip: () -> Void
    
    /// Whether a permission request is in progress
    @State private var isRequestingPermission = false
    
    /// Current microphone permission status (derived from permissionManager)
    private var isPermissionGranted: Bool {
        permissionManager.microphoneStatus.isGranted
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: Spacing.xxl)
            
            // Illustration/icon showing microphone
            microphoneIllustration
            
            Spacer()
                .frame(height: Spacing.xl)
            
            // Title
            Text("Microphone Access")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color.Wispflow.textPrimary)
            
            Spacer()
                .frame(height: Spacing.sm)
            
            // Screen explains why microphone access is needed
            Text("WispFlow needs microphone access to\nrecord and transcribe your voice.")
                .font(Font.Wispflow.body)
                .foregroundColor(Color.Wispflow.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            Spacer()
                .frame(height: Spacing.xxl)
            
            // Current permission status displayed
            permissionStatusCard
            
            Spacer()
                .frame(height: Spacing.xxl)
            
            // "Grant Access" button triggers system permission dialog
            if !isPermissionGranted {
                Button(action: requestPermission) {
                    HStack(spacing: Spacing.sm) {
                        if isRequestingPermission {
                            LoadingSpinner(size: 16, lineWidth: 2, color: .white)
                        }
                        Text("Grant Access")
                            .font(Font.Wispflow.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, Spacing.md)
                    .background(Color.Wispflow.accent)
                    .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(InteractiveScaleStyle())
                .disabled(isRequestingPermission)
            } else {
                // "Continue" enabled only after permission granted
                Button(action: onContinue) {
                    Text("Continue")
                        .font(Font.Wispflow.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: 200)
                        .padding(.vertical, Spacing.md)
                        .background(Color.Wispflow.success)
                        .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(InteractiveScaleStyle())
            }
            
            Spacer()
                .frame(height: Spacing.lg)
            
            // "Skip" always available
            Button(action: onSkip) {
                Text("Skip for now")
                    .font(Font.Wispflow.caption)
                    .foregroundColor(Color.Wispflow.textSecondary)
                    .underline()
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(0.7)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Wispflow.background)
        .onAppear {
            // Refresh status when view appears
            permissionManager.refreshMicrophoneStatus()
            print("OnboardingWindow: [US-518] Microphone permission view appeared, status: \(permissionManager.microphoneStatus.rawValue)")
        }
    }
    
    // MARK: - Microphone Illustration
    
    /// Illustration/icon showing microphone
    private var microphoneIllustration: some View {
        ZStack {
            // Outer glow circle
            Circle()
                .fill(Color.Wispflow.accent.opacity(0.15))
                .frame(width: 120, height: 120)
            
            // Inner circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.Wispflow.accent.opacity(0.9), Color.Wispflow.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 90, height: 90)
                .shadow(color: Color.Wispflow.accent.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Microphone icon
            Image(systemName: "mic.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Permission Status Card
    
    /// Current permission status displayed
    private var permissionStatusCard: some View {
        HStack(spacing: Spacing.md) {
            // Status icon
            ZStack {
                Circle()
                    .fill(isPermissionGranted ? Color.Wispflow.successLight : Color.Wispflow.errorLight)
                    .frame(width: 40, height: 40)
                
                Image(systemName: isPermissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isPermissionGranted ? Color.Wispflow.success : Color.Wispflow.error)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Microphone Permission")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                // Status text updates after permission granted
                Text(statusText)
                    .font(Font.Wispflow.caption)
                    .foregroundColor(isPermissionGranted ? Color.Wispflow.success : Color.Wispflow.textSecondary)
            }
            
            Spacer()
        }
        .padding(Spacing.lg)
        .background(Color.Wispflow.surface)
        .cornerRadius(CornerRadius.medium)
        .wispflowShadow(.card)
        .padding(.horizontal, Spacing.xxl)
        .animation(WispflowAnimation.smooth, value: isPermissionGranted)
    }
    
    /// Status text based on current permission state
    private var statusText: String {
        switch permissionManager.microphoneStatus {
        case .authorized:
            return "Access granted ✓"
        case .denied:
            return "Access denied - click Grant Access to open Settings"
        case .notDetermined:
            return "Not yet requested"
        case .restricted:
            return "Access restricted by system"
        }
    }
    
    // MARK: - Actions
    
    /// Request microphone permission
    private func requestPermission() {
        isRequestingPermission = true
        print("OnboardingWindow: [US-518] Requesting microphone permission")
        
        Task {
            let granted = await permissionManager.requestMicrophonePermission()
            print("OnboardingWindow: [US-518] Microphone permission result: \(granted)")
            
            await MainActor.run {
                isRequestingPermission = false
                // Status updates after permission granted (PermissionManager already updates)
            }
        }
    }
}

// MARK: - Onboarding Container View

/// Main container view for the onboarding wizard
/// Manages navigation between onboarding steps
struct OnboardingContainerView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    
    /// Permission manager for tracking microphone/accessibility permissions
    @ObservedObject var permissionManager: PermissionManager = PermissionManager.shared
    
    /// Current step in the onboarding flow
    @State private var currentStep: OnboardingStep = .welcome
    
    /// Callback when onboarding is complete (either finished or skipped)
    var onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            Color.Wispflow.background
                .ignoresSafeArea()
            
            // Current step content
            switch currentStep {
            case .welcome:
                WelcomeView(
                    onGetStarted: {
                        advanceToNextStep()
                    },
                    onSkipSetup: {
                        skipOnboarding()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                
            case .microphone:
                MicrophonePermissionView(
                    permissionManager: permissionManager,
                    onContinue: {
                        advanceToNextStep()
                    },
                    onSkip: {
                        advanceToNextStep()  // Skip just advances, doesn't exit
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(WispflowAnimation.smooth, value: currentStep)
    }
    
    // MARK: - Navigation
    
    /// Advance to the next step in the onboarding flow
    private func advanceToNextStep() {
        // US-518: Navigate to next step if available, otherwise complete
        if let nextStep = currentStep.nextStep {
            print("OnboardingWindow: [US-518] Advancing from \(currentStep.title) to \(nextStep.title)")
            currentStep = nextStep
        } else {
            // No more steps, complete onboarding
            completeOnboarding()
        }
    }
    
    /// Skip the onboarding entirely
    private func skipOnboarding() {
        print("OnboardingWindow: [US-517] User skipped onboarding")
        onboardingManager.markOnboardingSkipped()
        onComplete()
    }
    
    /// Complete the onboarding wizard
    private func completeOnboarding() {
        print("OnboardingWindow: [US-518] User completed onboarding at step: \(currentStep.title)")
        onboardingManager.markOnboardingCompleted()
        onComplete()
    }
}

// MARK: - Onboarding Window Controller

/// Window controller for the onboarding wizard
/// Manages the onboarding window lifecycle
@MainActor
final class OnboardingWindowController: NSObject {
    private var onboardingWindow: NSWindow?
    private let onboardingManager: OnboardingManager
    
    /// Callback when onboarding is complete
    var onComplete: (() -> Void)?
    
    init(onboardingManager: OnboardingManager = OnboardingManager.shared) {
        self.onboardingManager = onboardingManager
        super.init()
    }
    
    /// Show the onboarding window
    /// Only shows if this is a first launch
    func showOnboardingIfNeeded() {
        // Check if this is first launch
        guard onboardingManager.isFirstLaunch else {
            print("OnboardingWindow: [US-517] Not first launch, skipping onboarding")
            onComplete?()
            return
        }
        
        print("OnboardingWindow: [US-517] First launch detected, showing welcome screen")
        showOnboarding()
    }
    
    /// Force show the onboarding window (for testing)
    func showOnboarding() {
        if let existingWindow = onboardingWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let onboardingView = OnboardingContainerView(
            onboardingManager: onboardingManager,
            onComplete: { [weak self] in
                self?.closeOnboarding()
            }
        )
        
        let hostingController = NSHostingController(rootView: onboardingView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to WispFlow"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 520, height: 620))
        window.center()
        window.isReleasedWhenClosed = false
        
        // Prevent window from being resized
        window.styleMask.remove(.resizable)
        
        // Handle window close via delegate
        window.delegate = self
        
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// Close the onboarding window
    private func closeOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
        onComplete?()
    }
}

// MARK: - NSWindowDelegate

extension OnboardingWindowController: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        // Dispatch to main actor for property access
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            // If user closes window via close button, treat as skip
            if self.onboardingManager.isFirstLaunch {
                print("OnboardingWindow: [US-517] User closed onboarding window, treating as skip")
                self.onboardingManager.markOnboardingSkipped()
            }
            self.onboardingWindow = nil
            self.onComplete?()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(
            onGetStarted: { print("Get Started tapped") },
            onSkipSetup: { print("Skip Setup tapped") }
        )
        .frame(width: 520, height: 620)
    }
}

struct MicrophonePermissionView_Previews: PreviewProvider {
    static var previews: some View {
        MicrophonePermissionView(
            permissionManager: PermissionManager.shared,
            onContinue: { print("Continue tapped") },
            onSkip: { print("Skip tapped") }
        )
        .frame(width: 520, height: 620)
    }
}
#endif
