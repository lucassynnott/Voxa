import SwiftUI
import AppKit

// MARK: - Onboarding Step Enum

/// Steps in the onboarding wizard flow
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case microphone = 1
    case accessibility = 2
    case audioTest = 3
    case hotkey = 4
    case completion = 5
    
    var title: String {
        switch self {
        case .welcome:
            return "Welcome to Voxa"
        case .microphone:
            return "Microphone Permission"
        case .accessibility:
            return "Accessibility Permission"
        case .audioTest:
            return "Test Your Microphone"
        case .hotkey:
            return "Your Recording Hotkey"
        case .completion:
            return "You're All Set!"
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

/// Welcome screen shown on first launch - explains what Voxa does
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
            Text("Voxa")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(Color.Voxa.textPrimary)
            
            Spacer()
                .frame(height: Spacing.sm)
            
            // Brief description: "Voice-to-text for your Mac"
            Text("Voice-to-text for your Mac")
                .font(Font.Voxa.title)
                .foregroundColor(Color.Voxa.textSecondary)
            
            Spacer()
                .frame(height: Spacing.xxl)
            
            // Key features listed (3-4 bullet points)
            featuresList
            
            Spacer()
                .frame(height: Spacing.xxl)
            
            // "Get Started" button advances to next step
            Button(action: onGetStarted) {
                Text("Get Started")
                    .font(Font.Voxa.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, Spacing.md)
                    .background(Color.Voxa.accent)
                    .cornerRadius(CornerRadius.small)
            }
            .buttonStyle(InteractiveScaleStyle())
            
            Spacer()
                .frame(height: Spacing.lg)
            
            // "Skip Setup" link available (not prominent)
            Button(action: onSkipSetup) {
                Text("Skip Setup")
                    .font(Font.Voxa.caption)
                    .foregroundColor(Color.Voxa.textSecondary)
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
        .background(Color.Voxa.background)
    }
    
    // MARK: - App Logo
    
    /// App icon/logo displayed prominently
    private var appLogo: some View {
        ZStack {
            // Outer glow circle
            Circle()
                .fill(Color.Voxa.accent.opacity(0.15))
                .frame(width: 120, height: 120)
            
            // Inner circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.Voxa.accent.opacity(0.9), Color.Voxa.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 90, height: 90)
                .shadow(color: Color.Voxa.accent.opacity(0.3), radius: 10, x: 0, y: 5)
            
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
                    .fill(Color.Voxa.accentLight)
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.Voxa.accent)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                Text(description)
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.textSecondary)
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
                .foregroundColor(Color.Voxa.textPrimary)
            
            Spacer()
                .frame(height: Spacing.sm)
            
            // Screen explains why microphone access is needed
            Text("Voxa needs microphone access to\nrecord and transcribe your voice.")
                .font(Font.Voxa.body)
                .foregroundColor(Color.Voxa.textSecondary)
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
                            .font(Font.Voxa.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, Spacing.md)
                    .background(Color.Voxa.accent)
                    .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(InteractiveScaleStyle())
                .disabled(isRequestingPermission)
            } else {
                // "Continue" enabled only after permission granted
                Button(action: onContinue) {
                    Text("Continue")
                        .font(Font.Voxa.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: 200)
                        .padding(.vertical, Spacing.md)
                        .background(Color.Voxa.success)
                        .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(InteractiveScaleStyle())
            }
            
            Spacer()
                .frame(height: Spacing.lg)
            
            // "Skip" always available
            Button(action: onSkip) {
                Text("Skip for now")
                    .font(Font.Voxa.caption)
                    .foregroundColor(Color.Voxa.textSecondary)
                    .underline()
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(0.7)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Voxa.background)
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
                .fill(Color.Voxa.accent.opacity(0.15))
                .frame(width: 120, height: 120)
            
            // Inner circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.Voxa.accent.opacity(0.9), Color.Voxa.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 90, height: 90)
                .shadow(color: Color.Voxa.accent.opacity(0.3), radius: 10, x: 0, y: 5)
            
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
                    .fill(isPermissionGranted ? Color.Voxa.successLight : Color.Voxa.errorLight)
                    .frame(width: 40, height: 40)
                
                Image(systemName: isPermissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isPermissionGranted ? Color.Voxa.success : Color.Voxa.error)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Microphone Permission")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                // Status text updates after permission granted
                Text(statusText)
                    .font(Font.Voxa.caption)
                    .foregroundColor(isPermissionGranted ? Color.Voxa.success : Color.Voxa.textSecondary)
            }
            
            Spacer()
        }
        .padding(Spacing.lg)
        .background(Color.Voxa.surface)
        .cornerRadius(CornerRadius.medium)
        .voxaShadow(.card)
        .padding(.horizontal, Spacing.xxl)
        .animation(VoxaAnimation.smooth, value: isPermissionGranted)
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

// MARK: - Accessibility Permission Screen (US-519)

/// Accessibility permission step - guides user through granting accessibility access
/// US-519: Accessibility Permission Step
struct AccessibilityPermissionView: View {
    /// Permission manager for status tracking and requesting permission
    @ObservedObject var permissionManager: PermissionManager
    
    /// Callback when user clicks "Continue"
    var onContinue: () -> Void
    
    /// Callback when user clicks "Skip"
    var onSkip: () -> Void
    
    /// Current accessibility permission status (derived from permissionManager)
    private var isPermissionGranted: Bool {
        permissionManager.accessibilityStatus.isGranted
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Spacer()
                    .frame(height: Spacing.xl)
                
                // Illustration/icon showing accessibility
                accessibilityIllustration
                
                // Title
                Text("Accessibility Access")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color.Voxa.textPrimary)
                
                // Screen explains why accessibility access is needed (hotkeys + text insertion)
                Text("Voxa needs accessibility access for\nglobal hotkeys and text insertion.")
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                
                // Current permission status displayed
                permissionStatusCard
                
                // Instructions: "Enable Voxa in the list"
                instructionsCard
                
                Spacer()
                    .frame(height: Spacing.md)
                
                // "Open System Settings" button opens Accessibility pane
                if !isPermissionGranted {
                    Button(action: openSystemSettings) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "gear")
                                .font(.system(size: 16, weight: .medium))
                            Text("Open System Settings")
                                .font(Font.Voxa.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: 220)
                        .padding(.vertical, Spacing.md)
                        .background(Color.Voxa.accent)
                        .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(InteractiveScaleStyle())
                } else {
                    // "Continue" enabled only after permission granted
                    Button(action: onContinue) {
                        Text("Continue")
                            .font(Font.Voxa.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: 200)
                            .padding(.vertical, Spacing.md)
                            .background(Color.Voxa.success)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(InteractiveScaleStyle())
                }
                
                // "Skip" available
                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(Font.Voxa.caption)
                        .foregroundColor(Color.Voxa.textSecondary)
                        .underline()
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(0.7)
                
                Spacer()
                    .frame(height: Spacing.xl)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color.Voxa.background)
        .onAppear {
            // Refresh status when view appears
            permissionManager.refreshAccessibilityStatus()
            print("OnboardingWindow: [US-519] Accessibility permission view appeared, status: \(permissionManager.accessibilityStatus.rawValue)")
        }
    }
    
    // MARK: - Accessibility Illustration
    
    /// Illustration/icon showing accessibility
    private var accessibilityIllustration: some View {
        ZStack {
            // Outer glow circle
            Circle()
                .fill(Color.Voxa.accent.opacity(0.15))
                .frame(width: 120, height: 120)
            
            // Inner circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.Voxa.accent.opacity(0.9), Color.Voxa.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 90, height: 90)
                .shadow(color: Color.Voxa.accent.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Accessibility icon (keyboard representing hotkeys + text insertion)
            Image(systemName: "keyboard.fill")
                .font(.system(size: 36, weight: .medium))
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
                    .fill(isPermissionGranted ? Color.Voxa.successLight : Color.Voxa.errorLight)
                    .frame(width: 40, height: 40)
                
                Image(systemName: isPermissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isPermissionGranted ? Color.Voxa.success : Color.Voxa.error)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Accessibility Permission")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                // Status updates when user returns to app
                Text(statusText)
                    .font(Font.Voxa.caption)
                    .foregroundColor(isPermissionGranted ? Color.Voxa.success : Color.Voxa.textSecondary)
            }
            
            Spacer()
        }
        .padding(Spacing.lg)
        .background(Color.Voxa.surface)
        .cornerRadius(CornerRadius.medium)
        .voxaShadow(.card)
        .padding(.horizontal, Spacing.xxl)
        .animation(VoxaAnimation.smooth, value: isPermissionGranted)
    }
    
    // MARK: - Instructions Card
    
    /// Instructions: "Enable Voxa in the list"
    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.Voxa.accent)
                
                Text("How to enable")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                InstructionRow(number: 1, text: "Click \"Open System Settings\" below")
                InstructionRow(number: 2, text: "Find Voxa in the list")
                InstructionRow(number: 3, text: "Toggle the switch to enable")
                InstructionRow(number: 4, text: "Return to this window")
            }
        }
        .padding(Spacing.lg)
        .background(Color.Voxa.surface.opacity(0.5))
        .cornerRadius(CornerRadius.medium)
        .padding(.horizontal, Spacing.xxl)
    }
    
    /// Status text based on current permission state
    private var statusText: String {
        switch permissionManager.accessibilityStatus {
        case .authorized:
            return "Access granted ✓"
        case .denied, .notDetermined:
            return "Enable in System Settings"
        case .restricted:
            return "Access restricted by system"
        }
    }
    
    // MARK: - Actions
    
    /// Open System Settings to Accessibility pane
    private func openSystemSettings() {
        print("OnboardingWindow: [US-519] Opening System Settings > Accessibility")
        permissionManager.openAccessibilitySettings()
    }
}

// MARK: - Instruction Row Component

/// A single instruction row with number and text
struct InstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            // Number badge
            ZStack {
                Circle()
                    .fill(Color.Voxa.accentLight)
                    .frame(width: 22, height: 22)
                
                Text("\(number)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.Voxa.accent)
            }
            
            Text(text)
                .font(Font.Voxa.body)
                .foregroundColor(Color.Voxa.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Audio Test Step (US-520)

/// Audio test step - allows user to test their microphone during setup
/// US-520: Audio Test Step
struct AudioTestView: View {
    /// Audio manager for capturing audio and device selection
    @ObservedObject var audioManager: AudioManager
    
    /// Callback when user clicks "Sounds Good!"
    var onContinue: () -> Void
    
    /// Callback when user clicks "Skip"
    var onSkip: () -> Void
    
    /// Whether audio test is currently running
    @State private var isTestingAudio = false
    
    /// Current audio level for the meter
    @State private var currentLevel: Float = -60.0
    
    /// Timer for updating audio level
    @State private var levelTimer: Timer?
    
    /// Whether troubleshooting tips are shown
    @State private var showTroubleshootingTips = false
    
    /// Whether the user has tested and is satisfied with the audio
    @State private var hasTestedAudio = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: Spacing.xl)
            
            // Illustration/icon showing audio testing
            audioTestIllustration
            
            Spacer()
                .frame(height: Spacing.lg)
            
            // Title
            Text("Test Your Microphone")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color.Voxa.textPrimary)
            
            Spacer()
                .frame(height: Spacing.sm)
            
            // Description
            Text("Speak into your microphone to make sure\nit's working correctly.")
                .font(Font.Voxa.body)
                .foregroundColor(Color.Voxa.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            Spacer()
                .frame(height: Spacing.xl)
            
            // Device selector (if multiple devices available)
            if audioManager.inputDevices.count > 1 {
                deviceSelector
                Spacer()
                    .frame(height: Spacing.lg)
            }
            
            // Live audio level meter
            audioLevelMeterCard
            
            Spacer()
                .frame(height: Spacing.lg)
            
            // "Start Test" / "Stop Test" button
            testButton
            
            Spacer()
                .frame(height: Spacing.lg)
            
            // "Sounds Good!" button (enabled when user has tested)
            if hasTestedAudio {
                Button(action: onContinue) {
                    Text("Sounds Good!")
                        .font(Font.Voxa.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: 200)
                        .padding(.vertical, Spacing.md)
                        .background(Color.Voxa.success)
                        .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(InteractiveScaleStyle())
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            Spacer()
                .frame(height: Spacing.md)
            
            // "Having Issues?" link shows troubleshooting tips
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showTroubleshootingTips.toggle()
                }
            }) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: showTroubleshootingTips ? "chevron.up" : "questionmark.circle")
                        .font(.system(size: 12, weight: .medium))
                    Text("Having Issues?")
                        .font(Font.Voxa.caption)
                }
                .foregroundColor(Color.Voxa.accent)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Troubleshooting tips section
            if showTroubleshootingTips {
                troubleshootingTipsCard
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Spacer()
                .frame(height: Spacing.md)
            
            // Skip link
            Button(action: onSkip) {
                Text("Skip for now")
                    .font(Font.Voxa.caption)
                    .foregroundColor(Color.Voxa.textSecondary)
                    .underline()
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(0.7)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Voxa.background)
        .onAppear {
            print("OnboardingWindow: [US-520] Audio test view appeared")
            audioManager.refreshAvailableDevices()
        }
        .onDisappear {
            stopAudioTest()
        }
    }
    
    // MARK: - Audio Test Illustration
    
    /// Illustration showing audio/microphone testing
    private var audioTestIllustration: some View {
        ZStack {
            // Outer animated ring (pulses when testing)
            Circle()
                .stroke(Color.Voxa.accent.opacity(isTestingAudio ? 0.3 : 0.1), lineWidth: 3)
                .frame(width: 130, height: 130)
                .scaleEffect(isTestingAudio ? 1.1 : 1.0)
                .animation(
                    isTestingAudio ?
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                        .default,
                    value: isTestingAudio
                )
            
            // Outer glow circle
            Circle()
                .fill(Color.Voxa.accent.opacity(0.15))
                .frame(width: 120, height: 120)
            
            // Inner circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.Voxa.accent.opacity(0.9), Color.Voxa.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 90, height: 90)
                .shadow(color: Color.Voxa.accent.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Waveform icon
            Image(systemName: isTestingAudio ? "waveform" : "mic.fill")
                .font(.system(size: isTestingAudio ? 32 : 40, weight: .medium))
                .foregroundColor(.white)
                .symbolEffect(.variableColor.iterative, options: .repeating, value: isTestingAudio)
        }
    }
    
    // MARK: - Device Selector
    
    /// Device selector dropdown (shown if multiple devices available)
    private var deviceSelector: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Select Microphone")
                .font(Font.Voxa.caption)
                .fontWeight(.medium)
                .foregroundColor(Color.Voxa.textSecondary)
            
            Menu {
                ForEach(audioManager.inputDevices) { device in
                    Button(action: {
                        audioManager.selectDevice(device)
                        // If currently testing, restart with new device
                        if isTestingAudio {
                            stopAudioTest()
                            startAudioTest()
                        }
                    }) {
                        HStack {
                            Text(device.name)
                            if device.uid == audioManager.currentDevice?.uid {
                                Image(systemName: "checkmark")
                            }
                            if device.isDefault {
                                Text("(Default)")
                                    .foregroundColor(Color.Voxa.textSecondary)
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundColor(Color.Voxa.accent)
                    Text(audioManager.currentDevice?.name ?? "Select Device")
                        .font(Font.Voxa.body)
                        .foregroundColor(Color.Voxa.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(Color.Voxa.textSecondary)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(Spacing.md)
                .background(Color.Voxa.surface)
                .cornerRadius(CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.Voxa.border, lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, Spacing.xxl)
    }
    
    // MARK: - Audio Level Meter Card
    
    /// Card containing the live audio level meter
    private var audioLevelMeterCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Level meter
            OnboardingAudioLevelMeter(
                level: isTestingAudio ? currentLevel : -60.0,
                isActive: isTestingAudio
            )
            .frame(height: 44)
            .animation(.easeOut(duration: 0.1), value: currentLevel)
            
            // Level indicator and status
            HStack {
                Text("Level:")
                    .font(Font.Voxa.caption)
                    .foregroundColor(Color.Voxa.textSecondary)
                
                Text(isTestingAudio ? String(format: "%.1f dB", currentLevel) : "—")
                    .font(Font.Voxa.mono)
                    .foregroundColor(levelColor(for: currentLevel))
                
                Spacer()
                
                // Level status badge
                if isTestingAudio {
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(levelColor(for: currentLevel))
                            .frame(width: 8, height: 8)
                        Text(levelStatus(for: currentLevel))
                            .font(Font.Voxa.caption)
                            .foregroundColor(levelColor(for: currentLevel))
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(levelColor(for: currentLevel).opacity(0.15))
                    .cornerRadius(CornerRadius.small)
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.Voxa.surface)
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(isTestingAudio ? Color.Voxa.accent.opacity(0.5) : Color.Voxa.border, lineWidth: 1)
        )
        .voxaShadow(.card)
        .padding(.horizontal, Spacing.xxl)
        .animation(.easeInOut(duration: 0.2), value: isTestingAudio)
    }
    
    // MARK: - Test Button
    
    /// Start/Stop test button
    private var testButton: some View {
        Button(action: {
            if isTestingAudio {
                stopAudioTest()
            } else {
                startAudioTest()
            }
        }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: isTestingAudio ? "stop.fill" : "mic.fill")
                    .font(.system(size: 14, weight: .medium))
                Text(isTestingAudio ? "Stop Test" : "Start Test")
                    .font(Font.Voxa.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: 180)
            .padding(.vertical, Spacing.md)
            .background(isTestingAudio ? Color.Voxa.error : Color.Voxa.accent)
            .cornerRadius(CornerRadius.small)
        }
        .buttonStyle(InteractiveScaleStyle())
    }
    
    // MARK: - Troubleshooting Tips Card
    
    /// Card with troubleshooting tips
    private var troubleshootingTipsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(Color.Voxa.warning)
                    .font(.system(size: 14, weight: .medium))
                Text("Troubleshooting Tips")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: Spacing.sm) {
                TroubleshootingTipRow(
                    icon: "checkmark.circle",
                    text: "Make sure your microphone is connected and not muted"
                )
                TroubleshootingTipRow(
                    icon: "gear",
                    text: "Check System Settings > Sound > Input to verify the correct device is selected"
                )
                TroubleshootingTipRow(
                    icon: "hand.raised",
                    text: "Ensure Voxa has microphone permission in System Settings > Privacy & Security"
                )
                TroubleshootingTipRow(
                    icon: "arrow.clockwise",
                    text: "Try selecting a different microphone from the dropdown above"
                )
                TroubleshootingTipRow(
                    icon: "speaker.wave.2",
                    text: "Speak loudly and clearly, about 6-12 inches from your microphone"
                )
            }
        }
        .padding(Spacing.lg)
        .background(Color.Voxa.surface.opacity(0.7))
        .cornerRadius(CornerRadius.medium)
        .padding(.horizontal, Spacing.xxl)
        .padding(.top, Spacing.sm)
    }
    
    // MARK: - Audio Test Actions
    
    /// Start the audio test
    private func startAudioTest() {
        print("OnboardingWindow: [US-520] Starting audio test")
        
        audioManager.requestMicrophonePermission { granted in
            DispatchQueue.main.async {
                guard granted else {
                    print("OnboardingWindow: [US-520] Microphone permission denied")
                    return
                }
                
                do {
                    try audioManager.startCapturing()
                    isTestingAudio = true
                    print("OnboardingWindow: [US-520] Audio capture started")
                    
                    // Start timer to update level meter (20fps = 0.05s interval)
                    levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                        currentLevel = audioManager.currentAudioLevel
                        
                        // Mark as tested if level goes above threshold (user is speaking)
                        if currentLevel > -40 {
                            hasTestedAudio = true
                        }
                    }
                } catch {
                    print("OnboardingWindow: [US-520] Failed to start audio capture: \(error)")
                }
            }
        }
    }
    
    /// Stop the audio test
    private func stopAudioTest() {
        print("OnboardingWindow: [US-520] Stopping audio test")
        levelTimer?.invalidate()
        levelTimer = nil
        audioManager.cancelCapturing()
        isTestingAudio = false
        currentLevel = -60.0
    }
    
    // MARK: - Level Helpers
    
    /// Color for the current audio level
    private func levelColor(for level: Float) -> Color {
        if level > -10 {
            return Color.Voxa.error // Too loud / clipping
        } else if level > -30 {
            return Color.Voxa.success // Good level
        } else if level > -50 {
            return Color.Voxa.warning // Quiet
        } else {
            return Color.Voxa.textSecondary // Silent
        }
    }
    
    /// Status text for the current audio level
    private func levelStatus(for level: Float) -> String {
        if level > -10 {
            return "Too Loud"
        } else if level > -30 {
            return "Good"
        } else if level > -50 {
            return "Quiet"
        } else {
            return "Silent"
        }
    }
}

// MARK: - Onboarding Audio Level Meter

/// Visual audio level meter for the onboarding audio test
/// Similar to AudioLevelMeterView in SettingsWindow but styled for onboarding
struct OnboardingAudioLevelMeter: View {
    let level: Float
    let isActive: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color.Voxa.border)
                
                // Segmented level indicator
                HStack(spacing: 2) {
                    ForEach(0..<30, id: \.self) { index in
                        let segmentLevel = -60.0 + (Double(index) * 2.0) // Each segment = 2dB
                        let isLit = isActive && Double(level) >= segmentLevel
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(segmentColor(for: Float(segmentLevel), isLit: isLit))
                            .opacity(isLit ? 1.0 : 0.15)
                    }
                }
                .padding(Spacing.xs)
            }
        }
    }
    
    /// Color for each segment based on level
    private func segmentColor(for segmentLevel: Float, isLit: Bool) -> Color {
        if segmentLevel > -10 {
            return Color.Voxa.error
        } else if segmentLevel > -30 {
            return Color.Voxa.success
        } else {
            return Color.Voxa.accent
        }
    }
}

// MARK: - Troubleshooting Tip Row

/// A single troubleshooting tip row with icon and text
struct TroubleshootingTipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.Voxa.accent)
                .frame(width: 16)
            
            Text(text)
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Hotkey Introduction Step (US-521)

/// Hotkey introduction step - teaches user the recording hotkey and allows customization
/// US-521: Hotkey Introduction Step
struct HotkeyIntroductionView: View {
    /// Hotkey manager for configuration and listening
    @ObservedObject var hotkeyManager: HotkeyManager
    
    /// Callback when user clicks "Continue"
    var onContinue: () -> Void
    
    /// Callback when user clicks "Skip"
    var onSkip: () -> Void
    
    /// Whether the hotkey was pressed (for visual feedback)
    @State private var hotkeyPressed = false
    
    /// Whether user is in hotkey customization mode
    @State private var isCustomizing = false
    
    /// Whether we're listening for hotkey test
    @State private var isListeningForTest = false
    
    /// Animation state for hotkey press feedback
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: Spacing.xl)
            
            // Illustration showing keyboard/hotkey
            hotkeyIllustration
            
            Spacer()
                .frame(height: Spacing.lg)
            
            // Title
            Text("Your Recording Hotkey")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color.Voxa.textPrimary)
            
            Spacer()
                .frame(height: Spacing.sm)
            
            // Description
            Text("Press this shortcut anywhere to start recording.\nIt works in any app, anytime.")
                .font(Font.Voxa.body)
                .foregroundColor(Color.Voxa.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            Spacer()
                .frame(height: Spacing.xxl)
            
            // Current hotkey displayed prominently
            hotkeyDisplayCard
            
            Spacer()
                .frame(height: Spacing.lg)
            
            // "Try it now" prompt
            if !hotkeyPressed {
                tryItNowPrompt
            } else {
                // Visual feedback when hotkey pressed
                hotkeySuccessFeedback
            }
            
            Spacer()
                .frame(height: Spacing.lg)
            
            // "Change Hotkey" option for customization
            if isCustomizing {
                hotkeyCustomizationView
            } else {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isCustomizing = true
                    }
                }) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 12, weight: .medium))
                        Text("Change Hotkey")
                            .font(Font.Voxa.caption)
                    }
                    .foregroundColor(Color.Voxa.accent)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
                .frame(height: Spacing.lg)
            
            // Default hotkey recommendation
            defaultHotkeyNote
            
            Spacer()
                .frame(height: Spacing.xxl)
            
            // Continue button
            Button(action: onContinue) {
                Text(hotkeyPressed ? "Continue" : "Got it!")
                    .font(Font.Voxa.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, Spacing.md)
                    .background(hotkeyPressed ? Color.Voxa.success : Color.Voxa.accent)
                    .cornerRadius(CornerRadius.small)
            }
            .buttonStyle(InteractiveScaleStyle())
            
            Spacer()
                .frame(height: Spacing.lg)
            
            // Skip link
            Button(action: onSkip) {
                Text("Skip for now")
                    .font(Font.Voxa.caption)
                    .foregroundColor(Color.Voxa.textSecondary)
                    .underline()
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(0.7)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Voxa.background)
        .onAppear {
            print("OnboardingWindow: [US-521] Hotkey introduction view appeared")
            setupHotkeyTestListener()
        }
        .onDisappear {
            removeHotkeyTestListener()
        }
    }
    
    // MARK: - Hotkey Illustration
    
    /// Illustration showing keyboard/hotkey icon
    private var hotkeyIllustration: some View {
        ZStack {
            // Outer animated ring (pulses when hotkey pressed)
            Circle()
                .stroke(Color.Voxa.accent.opacity(hotkeyPressed ? 0.5 : 0.1), lineWidth: 3)
                .frame(width: 130, height: 130)
                .scaleEffect(hotkeyPressed ? 1.15 : 1.0)
                .animation(
                    hotkeyPressed ?
                        .easeOut(duration: 0.3) :
                        .default,
                    value: hotkeyPressed
                )
            
            // Outer glow circle
            Circle()
                .fill(Color.Voxa.accent.opacity(0.15))
                .frame(width: 120, height: 120)
            
            // Inner circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            hotkeyPressed ? Color.Voxa.success.opacity(0.9) : Color.Voxa.accent.opacity(0.9),
                            hotkeyPressed ? Color.Voxa.success : Color.Voxa.accent
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 90, height: 90)
                .shadow(color: (hotkeyPressed ? Color.Voxa.success : Color.Voxa.accent).opacity(0.3), radius: 10, x: 0, y: 5)
                .animation(.easeInOut(duration: 0.3), value: hotkeyPressed)
            
            // Keyboard icon or checkmark
            Image(systemName: hotkeyPressed ? "checkmark" : "command")
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Hotkey Display Card
    
    /// Current hotkey displayed prominently (⌘⇧Space)
    private var hotkeyDisplayCard: some View {
        VStack(spacing: Spacing.md) {
            // Hotkey badge - large and prominent
            HStack(spacing: Spacing.sm) {
                ForEach(hotkeySymbols, id: \.self) { symbol in
                    HotkeyKeyBadge(symbol: symbol)
                }
            }
            
            // Hotkey name
            Text(hotkeyManager.configuration.displayString)
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
        }
        .padding(Spacing.xl)
        .background(Color.Voxa.surface)
        .cornerRadius(CornerRadius.large)
        .voxaShadow(.card)
        .padding(.horizontal, Spacing.xxl)
        .scaleEffect(hotkeyPressed ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hotkeyPressed)
    }
    
    /// Parse hotkey display string into individual symbols
    private var hotkeySymbols: [String] {
        let displayString = hotkeyManager.configuration.displayString
        var symbols: [String] = []
        
        // Parse modifier symbols
        let modifiers = hotkeyManager.configuration.modifiers
        if modifiers.contains(.control) { symbols.append("⌃") }
        if modifiers.contains(.option) { symbols.append("⌥") }
        if modifiers.contains(.shift) { symbols.append("⇧") }
        if modifiers.contains(.command) { symbols.append("⌘") }
        
        // Get the key name (last part after modifiers)
        let keyName = displayString.replacingOccurrences(of: "⌃", with: "")
            .replacingOccurrences(of: "⌥", with: "")
            .replacingOccurrences(of: "⇧", with: "")
            .replacingOccurrences(of: "⌘", with: "")
        
        if !keyName.isEmpty {
            symbols.append(keyName)
        }
        
        return symbols
    }
    
    // MARK: - Try It Now Prompt
    
    /// "Try it now" prompt - user can test hotkey
    private var tryItNowPrompt: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                PulsingDot(size: 8, color: Color.Voxa.accent)
                Text("Try it now!")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            Text("Press the hotkey to see it in action")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
        }
        .padding(Spacing.lg)
        .background(Color.Voxa.accentLight)
        .cornerRadius(CornerRadius.medium)
        .padding(.horizontal, Spacing.xxl)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // MARK: - Success Feedback
    
    /// Visual feedback when hotkey pressed
    private var hotkeySuccessFeedback: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.Voxa.success)
                Text("Perfect!")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.success)
            }
            
            Text("Your hotkey is working correctly")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
        }
        .padding(Spacing.lg)
        .background(Color.Voxa.successLight)
        .cornerRadius(CornerRadius.medium)
        .padding(.horizontal, Spacing.xxl)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // MARK: - Hotkey Customization View
    
    /// View for customizing the hotkey
    private var hotkeyCustomizationView: some View {
        VStack(spacing: Spacing.md) {
            Text("Record New Hotkey")
                .font(Font.Voxa.headline)
                .foregroundColor(Color.Voxa.textPrimary)
            
            OnboardingHotkeyRecorder(hotkeyManager: hotkeyManager)
            
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isCustomizing = false
                }
            }) {
                Text("Done")
                    .font(Font.Voxa.caption)
                    .foregroundColor(Color.Voxa.textSecondary)
                    .underline()
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(Spacing.lg)
        .background(Color.Voxa.surface)
        .cornerRadius(CornerRadius.medium)
        .voxaShadow(.card)
        .padding(.horizontal, Spacing.xxl)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - Default Hotkey Note
    
    /// Default hotkey recommended for most users
    private var defaultHotkeyNote: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.Voxa.warning)
            
            Text("Tip: The default ⌘⇧Space works well for most users")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
        }
        .padding(.horizontal, Spacing.xxl)
    }
    
    // MARK: - Hotkey Test Listener
    
    /// Set up listener to detect hotkey press for visual feedback
    private func setupHotkeyTestListener() {
        print("OnboardingWindow: [US-521] Setting up hotkey test listener")
        
        // Try to start the hotkey manager now that we're at this step
        // (User should have granted accessibility in the previous step)
        if !hotkeyManager.isActive {
            print("OnboardingWindow: [US-521] Hotkey manager not active, attempting to start...")
            hotkeyManager.start()
            
            if hotkeyManager.isActive {
                print("OnboardingWindow: [US-521] Hotkey manager started successfully!")
            } else {
                print("OnboardingWindow: [US-521] Warning: Hotkey manager failed to start - accessibility may not be granted")
            }
        }
        
        // Store original callback
        let originalCallback = hotkeyManager.onHotkeyPressed
        
        // Set our test callback
        hotkeyManager.onHotkeyPressed = { [originalCallback] in
            print("OnboardingWindow: [US-521] Hotkey pressed during onboarding!")
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                hotkeyPressed = true
            }
            
            // Also call original callback if exists
            originalCallback?()
        }
    }
    
    /// Remove the test listener
    private func removeHotkeyTestListener() {
        print("OnboardingWindow: [US-521] Removing hotkey test listener")
        // Note: The callback will be reset when AppDelegate sets it up properly
    }
}

// MARK: - Onboarding Completion Step (US-522)

/// Completion screen shown after all onboarding steps are finished
/// US-522: Onboarding Completion
struct OnboardingCompletionView: View {
    /// Permission manager for checking permission status
    @ObservedObject var permissionManager: PermissionManager
    
    /// Hotkey manager for getting current hotkey configuration
    @ObservedObject var hotkeyManager: HotkeyManager
    
    /// Callback when user clicks "Start Using Voxa"
    var onStartUsingApp: () -> Void
    
    /// Animation state for checkmark appearance
    @State private var showCheckmarks = false
    
    /// Animation state for success icon
    @State private var showSuccessIcon = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: Spacing.xl)
            
            // Success illustration with animated checkmark
            successIllustration
            
            Spacer()
                .frame(height: Spacing.lg)
            
            // Title
            Text("You're All Set!")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Color.Voxa.textPrimary)
            
            Spacer()
                .frame(height: Spacing.sm)
            
            // Brief description
            Text("Voxa is ready to transcribe your voice.")
                .font(Font.Voxa.body)
                .foregroundColor(Color.Voxa.textSecondary)
                .multilineTextAlignment(.center)
            
            Spacer()
                .frame(height: Spacing.xxl)
            
            // Success screen with checkmarks for completed steps
            completedStepsCard
            
            Spacer()
                .frame(height: Spacing.xl)
            
            // Brief recap of how to use: "Press ⌘⇧Space to start recording"
            hotkeyRecapCard
            
            Spacer()
                .frame(height: Spacing.xxl)
            
            // "Start Using Voxa" button closes wizard
            Button(action: onStartUsingApp) {
                HStack(spacing: Spacing.sm) {
                    Text("Start Using Voxa")
                        .font(Font.Voxa.headline)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: 240)
                .padding(.vertical, Spacing.md)
                .background(Color.Voxa.success)
                .cornerRadius(CornerRadius.small)
            }
            .buttonStyle(InteractiveScaleStyle())
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Voxa.background)
        .onAppear {
            print("OnboardingWindow: [US-522] Completion view appeared")
            // Trigger animations with slight delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showSuccessIcon = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showCheckmarks = true
                }
            }
        }
    }
    
    // MARK: - Success Illustration
    
    /// Success checkmark icon with animated entrance
    private var successIllustration: some View {
        ZStack {
            // Outer celebration ring
            Circle()
                .stroke(Color.Voxa.success.opacity(0.2), lineWidth: 4)
                .frame(width: 130, height: 130)
                .scaleEffect(showSuccessIcon ? 1.0 : 0.5)
                .opacity(showSuccessIcon ? 1.0 : 0.0)
            
            // Outer glow circle
            Circle()
                .fill(Color.Voxa.success.opacity(0.15))
                .frame(width: 120, height: 120)
                .scaleEffect(showSuccessIcon ? 1.0 : 0.7)
            
            // Inner circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.Voxa.success.opacity(0.9), Color.Voxa.success],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 90, height: 90)
                .shadow(color: Color.Voxa.success.opacity(0.3), radius: 10, x: 0, y: 5)
                .scaleEffect(showSuccessIcon ? 1.0 : 0.5)
            
            // Checkmark icon
            Image(systemName: "checkmark")
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(.white)
                .scaleEffect(showSuccessIcon ? 1.0 : 0.3)
                .opacity(showSuccessIcon ? 1.0 : 0.0)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showSuccessIcon)
    }
    
    // MARK: - Completed Steps Card
    
    /// Card showing checkmarks for completed steps
    private var completedStepsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Card header
            HStack(spacing: Spacing.sm) {
                Image(systemName: "list.bullet.clipboard.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.Voxa.accent)
                Text("Setup Complete")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            Divider()
                .background(Color.Voxa.border)
            
            // Completed steps list
            VStack(alignment: .leading, spacing: Spacing.sm) {
                CompletedStepRow(
                    title: "Microphone Access",
                    isCompleted: permissionManager.microphoneStatus.isGranted,
                    showCheckmark: showCheckmarks
                )
                
                CompletedStepRow(
                    title: "Accessibility Access",
                    isCompleted: permissionManager.accessibilityStatus.isGranted,
                    showCheckmark: showCheckmarks
                )
                
                CompletedStepRow(
                    title: "Audio Test",
                    isCompleted: true, // Always shown as completed if they reached this step
                    showCheckmark: showCheckmarks
                )
                
                CompletedStepRow(
                    title: "Hotkey Configuration",
                    isCompleted: true, // Always shown as completed if they reached this step
                    showCheckmark: showCheckmarks
                )
            }
        }
        .padding(Spacing.lg)
        .background(Color.Voxa.surface)
        .cornerRadius(CornerRadius.medium)
        .voxaShadow(.card)
        .padding(.horizontal, Spacing.xxl)
    }
    
    // MARK: - Hotkey Recap Card
    
    /// Brief recap of how to use: "Press ⌘⇧Space to start recording"
    private var hotkeyRecapCard: some View {
        VStack(spacing: Spacing.md) {
            // Instruction text
            Text("To start recording, press:")
                .font(Font.Voxa.body)
                .foregroundColor(Color.Voxa.textSecondary)
            
            // Hotkey display
            HStack(spacing: Spacing.sm) {
                ForEach(hotkeySymbols, id: \.self) { symbol in
                    HotkeyKeyBadge(symbol: symbol)
                }
            }
            
            // Hotkey string
            Text(hotkeyManager.configuration.displayString)
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
        }
        .padding(Spacing.xl)
        .background(Color.Voxa.accentLight.opacity(0.5))
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(Color.Voxa.accent.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, Spacing.xxl)
    }
    
    /// Parse hotkey display string into individual symbols
    private var hotkeySymbols: [String] {
        let displayString = hotkeyManager.configuration.displayString
        var symbols: [String] = []
        
        // Parse modifier symbols
        let modifiers = hotkeyManager.configuration.modifiers
        if modifiers.contains(.control) { symbols.append("⌃") }
        if modifiers.contains(.option) { symbols.append("⌥") }
        if modifiers.contains(.shift) { symbols.append("⇧") }
        if modifiers.contains(.command) { symbols.append("⌘") }
        
        // Get the key name (last part after modifiers)
        let keyName = displayString.replacingOccurrences(of: "⌃", with: "")
            .replacingOccurrences(of: "⌥", with: "")
            .replacingOccurrences(of: "⇧", with: "")
            .replacingOccurrences(of: "⌘", with: "")
        
        if !keyName.isEmpty {
            symbols.append(keyName)
        }
        
        return symbols
    }
}

// MARK: - Completed Step Row

/// A single row in the completed steps list with checkmark
struct CompletedStepRow: View {
    let title: String
    let isCompleted: Bool
    let showCheckmark: Bool
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Checkmark or X icon
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.Voxa.successLight : Color.Voxa.surface)
                    .frame(width: 28, height: 28)
                
                if showCheckmark {
                    Image(systemName: isCompleted ? "checkmark" : "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isCompleted ? Color.Voxa.success : Color.Voxa.textSecondary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showCheckmark)
            
            // Step title
            Text(title)
                .font(Font.Voxa.body)
                .foregroundColor(isCompleted ? Color.Voxa.textPrimary : Color.Voxa.textSecondary)
            
            Spacer()
            
            // Status badge
            if showCheckmark {
                Text(isCompleted ? "Done" : "Skipped")
                    .font(Font.Voxa.caption)
                    .foregroundColor(isCompleted ? Color.Voxa.success : Color.Voxa.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(isCompleted ? Color.Voxa.successLight : Color.Voxa.surface)
                    .cornerRadius(CornerRadius.small)
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(Double.random(in: 0...0.1)), value: showCheckmark)
    }
}

// MARK: - Hotkey Key Badge

/// A single key badge for the hotkey display
struct HotkeyKeyBadge: View {
    let symbol: String
    
    var body: some View {
        Text(symbol)
            .font(.system(size: 24, weight: .semibold, design: .rounded))
            .foregroundColor(Color.Voxa.textPrimary)
            .frame(minWidth: 44, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color.Voxa.background)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(Color.Voxa.border, lineWidth: 1)
            )
    }
}

// MARK: - Onboarding Hotkey Recorder

/// Simplified hotkey recorder for onboarding customization
struct OnboardingHotkeyRecorder: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    
    @State private var isRecording = false
    @State private var recordedKeyCode: UInt16?
    @State private var recordedModifiers: NSEvent.ModifierFlags = []
    @State private var showConflictWarning = false
    @State private var conflictingShortcuts: [HotkeyManager.SystemShortcut] = []
    @State private var pendingConfig: HotkeyManager.HotkeyConfiguration?
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            // Current hotkey display
            HStack {
                Text("Current:")
                    .font(Font.Voxa.caption)
                    .foregroundColor(Color.Voxa.textSecondary)
                
                Text(hotkeyManager.configuration.displayString)
                    .font(Font.Voxa.mono)
                    .foregroundColor(Color.Voxa.textPrimary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.Voxa.accentLight)
                    .cornerRadius(CornerRadius.small)
            }
            
            // Record button
            Button(action: toggleRecording) {
                HStack(spacing: Spacing.sm) {
                    if isRecording {
                        PulsingDot(size: 8, color: .white)
                    }
                    Text(isRecording ? "Press keys..." : "Record New")
                        .font(Font.Voxa.body)
                }
                .foregroundColor(.white)
                .frame(maxWidth: 160)
                .padding(.vertical, Spacing.sm)
                .background(isRecording ? Color.Voxa.error : Color.Voxa.accent)
                .cornerRadius(CornerRadius.small)
            }
            .buttonStyle(InteractiveScaleStyle())
            
            // Reset to default button
            if hotkeyManager.configuration != .defaultHotkey {
                Button(action: {
                    hotkeyManager.resetToDefault()
                }) {
                    Text("Reset to Default (⌘⇧Space)")
                        .font(Font.Voxa.caption)
                        .foregroundColor(Color.Voxa.accent)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .alert("Shortcut Conflict", isPresented: $showConflictWarning) {
            Button("Use Anyway") {
                if let config = pendingConfig {
                    hotkeyManager.updateConfiguration(config)
                    pendingConfig = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingConfig = nil
            }
        } message: {
            let names = conflictingShortcuts.map { $0.name }.joined(separator: ", ")
            Text("This shortcut conflicts with: \(names). Using it may interfere with system functions.")
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        recordedKeyCode = nil
        recordedModifiers = []
        
        // Install local event monitor for keyDown
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyEvent(event)
            return nil // Consume the event
        }
    }
    
    private func stopRecording() {
        isRecording = false
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        // Ignore escape (cancel)
        if event.keyCode == 53 { // Escape key
            stopRecording()
            return
        }
        
        // Check for valid modifiers
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard !modifiers.isEmpty else {
            // Need at least one modifier
            return
        }
        
        let newConfig = HotkeyManager.HotkeyConfiguration(
            keyCode: event.keyCode,
            modifierFlags: modifiers
        )
        
        // Check for conflicts (US-512)
        let conflicts = HotkeyManager.checkForConflicts(newConfig)
        if !conflicts.isEmpty {
            pendingConfig = newConfig
            conflictingShortcuts = conflicts
            showConflictWarning = true
        } else {
            hotkeyManager.updateConfiguration(newConfig)
        }
        
        stopRecording()
    }
}

// MARK: - Onboarding Container View

/// Main container view for the onboarding wizard
/// Manages navigation between onboarding steps
struct OnboardingContainerView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    
    /// Permission manager for tracking microphone/accessibility permissions
    @ObservedObject var permissionManager: PermissionManager = PermissionManager.shared
    
    /// Audio manager for the audio test step (US-520)
    @ObservedObject var audioManager: AudioManager
    
    /// Hotkey manager for the hotkey introduction step (US-521)
    @ObservedObject var hotkeyManager: HotkeyManager
    
    /// Current step in the onboarding flow
    @State private var currentStep: OnboardingStep = .welcome
    
    /// Callback when onboarding is complete (either finished or skipped)
    var onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            Color.Voxa.background
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
                
            case .accessibility:
                AccessibilityPermissionView(
                    permissionManager: permissionManager,
                    onContinue: {
                        advanceToNextStep()
                    },
                    onSkip: {
                        advanceToNextStep()  // Skip just advances, doesn't exit
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                
            case .audioTest:
                AudioTestView(
                    audioManager: audioManager,
                    onContinue: {
                        advanceToNextStep()
                    },
                    onSkip: {
                        advanceToNextStep()  // Skip just advances, doesn't exit
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                
            case .hotkey:
                HotkeyIntroductionView(
                    hotkeyManager: hotkeyManager,
                    onContinue: {
                        advanceToNextStep()
                    },
                    onSkip: {
                        advanceToNextStep()  // Skip just advances, doesn't exit
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                
            case .completion:
                OnboardingCompletionView(
                    permissionManager: permissionManager,
                    hotkeyManager: hotkeyManager,
                    onStartUsingApp: {
                        completeOnboarding()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(VoxaAnimation.smooth, value: currentStep)
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
    /// Audio manager for the audio test step (US-520)
    private let audioManager: AudioManager
    /// Hotkey manager for the hotkey introduction step (US-521)
    private let hotkeyManager: HotkeyManager
    
    /// Callback when onboarding is complete
    var onComplete: (() -> Void)?
    
    init(onboardingManager: OnboardingManager = OnboardingManager.shared, audioManager: AudioManager, hotkeyManager: HotkeyManager) {
        self.onboardingManager = onboardingManager
        self.audioManager = audioManager
        self.hotkeyManager = hotkeyManager
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
            audioManager: audioManager,
            hotkeyManager: hotkeyManager,
            onComplete: { [weak self] in
                self?.closeOnboarding()
            }
        )
        
        let hostingController = NSHostingController(rootView: onboardingView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to Voxa"
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

struct AccessibilityPermissionView_Previews: PreviewProvider {
    static var previews: some View {
        AccessibilityPermissionView(
            permissionManager: PermissionManager.shared,
            onContinue: { print("Continue tapped") },
            onSkip: { print("Skip tapped") }
        )
        .frame(width: 520, height: 620)
    }
}

struct AudioTestView_Previews: PreviewProvider {
    static var previews: some View {
        AudioTestView(
            audioManager: AudioManager(),
            onContinue: { print("Sounds Good tapped") },
            onSkip: { print("Skip tapped") }
        )
        .frame(width: 520, height: 620)
    }
}

struct HotkeyIntroductionView_Previews: PreviewProvider {
    static var previews: some View {
        HotkeyIntroductionView(
            hotkeyManager: HotkeyManager(),
            onContinue: { print("Continue tapped") },
            onSkip: { print("Skip tapped") }
        )
        .frame(width: 520, height: 620)
    }
}

struct OnboardingCompletionView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingCompletionView(
            permissionManager: PermissionManager.shared,
            hotkeyManager: HotkeyManager(),
            onStartUsingApp: { print("Start Using Voxa tapped") }
        )
        .frame(width: 520, height: 620)
    }
}
#endif
