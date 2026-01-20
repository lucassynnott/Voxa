import SwiftUI
import AppKit
import ServiceManagement
import Combine
import UniformTypeIdentifiers

// MARK: - Navigation Item Enum

/// Navigation items for the main window sidebar
/// US-632: Main Window with Sidebar Navigation
enum NavigationItem: String, CaseIterable, Identifiable {
    case home = "home"
    case history = "history"
    case snippets = "snippets"
    case dictionary = "dictionary"
    case settings = "settings"
    
    var id: String { rawValue }
    
    /// Display name for the navigation item
    var displayName: String {
        switch self {
        case .home:
            return "Home"
        case .history:
            return "History"
        case .snippets:
            return "Snippets"
        case .dictionary:
            return "Dictionary"
        case .settings:
            return "Settings"
        }
    }
    
    /// SF Symbol icon name for the navigation item
    /// Each icon is distinctive and represents the feature clearly
    var iconName: String {
        switch self {
        case .home:
            return "house.fill"
        case .history:
            return "clock.fill"
        case .snippets:
            return "doc.on.clipboard.fill"
        case .dictionary:
            return "character.book.closed.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
    
    /// Icon name for inactive/outline state
    var iconNameInactive: String {
        switch self {
        case .home:
            return "house"
        case .history:
            return "clock"
        case .snippets:
            return "doc.on.clipboard"
        case .dictionary:
            return "character.book.closed"
        case .settings:
            return "gearshape"
        }
    }
}

// MARK: - Main Window View

/// Main application window with sidebar navigation
/// US-632: Main Window with Sidebar Navigation
struct MainWindowView: View {
    /// Currently selected navigation item
    @State private var selectedItem: NavigationItem = .home
    
    /// Whether the sidebar is collapsed (icon-only mode)
    @State private var isSidebarCollapsed: Bool = false
    
    /// Track window width for auto-collapse
    @State private var windowWidth: CGFloat = 900
    
    /// Animation namespace for shared transitions
    @Namespace private var animationNamespace
    
    /// Sidebar width constants
    private let sidebarExpandedWidth: CGFloat = 220
    private let sidebarCollapsedWidth: CGFloat = 70
    private let collapseThreshold: CGFloat = 700
    
    /// US-708: Initial navigation item (can be set when opening window)
    var initialNavigationItem: NavigationItem? = nil
    
    /// Whether onboarding should be shown (first launch)
    @State private var showOnboarding: Bool = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    
    /// Audio manager for onboarding (injected via environment or created)
    @EnvironmentObject private var audioManager: AudioManager
    
    /// Hotkey manager for onboarding
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    
    var body: some View {
        ZStack {
            // Main app content
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // MARK: - Sidebar
                    sidebarView
                        .frame(width: isSidebarCollapsed ? sidebarCollapsedWidth : sidebarExpandedWidth)
                    
                    // MARK: - Subtle Separator
                    Rectangle()
                        .fill(Color.Voxa.border.opacity(0.5))
                        .frame(width: 1)
                        .voxaShadow(.subtle)
                    
                    // MARK: - Main Content Area
                    contentView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .onChange(of: geometry.size.width) { _, newWidth in
                    windowWidth = newWidth
                    // Auto-collapse sidebar when window too small
                    withAnimation(VoxaAnimation.smooth) {
                        isSidebarCollapsed = newWidth < collapseThreshold
                    }
                }
                .onAppear {
                    windowWidth = geometry.size.width
                    isSidebarCollapsed = geometry.size.width < collapseThreshold
                    // US-708: Navigate to initial item if specified
                    if let initialItem = initialNavigationItem {
                        withAnimation(VoxaAnimation.smooth) {
                            selectedItem = initialItem
                        }
                    }
                }
                // US-708: Listen for navigation requests from openSettings notification
                .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
                    withAnimation(VoxaAnimation.smooth) {
                        selectedItem = .settings
                    }
                }
                // US-803: Listen for navigation requests to history view
                .onReceive(NotificationCenter.default.publisher(for: .navigateToHistory)) { _ in
                    withAnimation(VoxaAnimation.smooth) {
                        selectedItem = .history
                    }
                }
                // US-805: Listen for navigation to Text Cleanup settings
                .onReceive(NotificationCenter.default.publisher(for: .navigateToTextCleanup)) { _ in
                    withAnimation(VoxaAnimation.smooth) {
                        selectedItem = .settings
                    }
                    // Post secondary notification to scroll to text cleanup section
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: .scrollToTextCleanupSection, object: nil)
                    }
                }
            }
            .blur(radius: showOnboarding ? 3 : 0)
            .disabled(showOnboarding)
            
            // Onboarding overlay (shown on first launch only)
            if showOnboarding {
                OnboardingContainerView(
                    onboardingManager: OnboardingManager.shared,
                    audioManager: audioManager,
                    hotkeyManager: hotkeyManager,
                    onComplete: {
                        withAnimation(VoxaAnimation.smooth) {
                            showOnboarding = false
                        }
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        // Start hotkey manager after onboarding
                        hotkeyManager.start()
                    }
                )
                .transition(.opacity)
            }
        }
        .background(Color.Voxa.background)
    }
    
    // MARK: - Sidebar View
    
    /// Fixed left sidebar with navigation items
    /// US-806: Updated sidebar background for light/dark mode with semi-transparent surface
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App branding area
            sidebarHeader
            
            // US-806: Increased spacing between header and nav items
            Spacer()
                .frame(height: Spacing.xl)
            
            // Navigation items
            // US-806: Updated spacing between nav items for cleaner look
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(NavigationItem.allCases) { item in
                    NavigationItemRow(
                        item: item,
                        isSelected: selectedItem == item,
                        isCollapsed: isSidebarCollapsed,
                        animationNamespace: animationNamespace,
                        onSelect: {
                            withAnimation(VoxaAnimation.smooth) {
                                selectedItem = item
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, Spacing.sm)
            
            Spacer()
            
            // US-804: Daily Insights Section (only shown when sidebar is expanded)
            if !isSidebarCollapsed {
                DailyInsightsSection()
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.lg)
            }
            
            // US-806: Border separator above collapse button
            Rectangle()
                .fill(Color.Voxa.border)
                .frame(height: 1)
            
            // Collapse toggle button
            // US-806: Updated collapse button styling
            collapseToggleButton
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
        }
        .frame(maxHeight: .infinity)
        // US-806: Updated sidebar background - semi-transparent surface with blur effect
        .background(
            Color.Voxa.sidebarBackground
                .opacity(0.5)
        )
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Sidebar Header
    
    /// App branding/logo area at top of sidebar
    /// US-806: Updated sidebar header with minimalist styling
    private var sidebarHeader: some View {
        HStack(spacing: Spacing.md) {
            // US-806: App icon - simple monochrome style that inverts in dark mode
            Image(systemName: "v.circle.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(Color.Voxa.textPrimary)
            
            if !isSidebarCollapsed {
                // US-806: App name with larger display font
                Text("Voxa")
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .tracking(0.5)
                    .foregroundColor(Color.Voxa.textPrimary)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
            
            Spacer()
        }
        // US-806: Fixed header height to match design (~96px / 6rem)
        .frame(height: 96)
        .padding(.horizontal, isSidebarCollapsed ? Spacing.lg : Spacing.xl)
        .animation(VoxaAnimation.smooth, value: isSidebarCollapsed)
    }
    
    // MARK: - Collapse Toggle Button
    
    /// Button to manually toggle sidebar collapse state
    private var collapseToggleButton: some View {
        Button(action: {
            withAnimation(VoxaAnimation.smooth) {
                isSidebarCollapsed.toggle()
            }
        }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: isSidebarCollapsed ? "sidebar.right" : "sidebar.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.Voxa.textSecondary)
                
                if !isSidebarCollapsed {
                    Text("Collapse")
                        .font(Font.Voxa.caption)
                        .foregroundColor(Color.Voxa.textSecondary)
                        .transition(.opacity)
                }
            }
            .padding(Spacing.sm)
            .frame(maxWidth: isSidebarCollapsed ? 44 : .infinity, alignment: isSidebarCollapsed ? .center : .leading)
            .background(Color.Voxa.border.opacity(0.3))
            .cornerRadius(CornerRadius.small)
        }
        .buttonStyle(PlainButtonStyle())
        .help(isSidebarCollapsed ? "Expand sidebar" : "Collapse sidebar")
    }
    
    // MARK: - Content View
    
    /// Main content area that displays the selected view
    private var contentView: some View {
        Group {
            switch selectedItem {
            case .home:
                HomeContentView()
            case .history:
                HistoryContentView()
            case .snippets:
                SnippetsContentView()
            case .dictionary:
                DictionaryContentView()
            case .settings:
                SettingsContentView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(VoxaAnimation.tabTransition, value: selectedItem)
    }
    
    // MARK: - US-805: Audio Import Picker
    
    /// Show file picker for importing audio files
    /// US-805: Connect button actions - Import Audio functionality
    private func showAudioImportPickerPanel() {
        let panel = NSOpenPanel()
        panel.title = "Import Audio File"
        panel.message = "Select an audio file to transcribe"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .audio,
            .mp3,
            .wav,
            .mpeg4Audio,
            .aiff
        ]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                print("[US-805] Audio file selected for import: \(url.path)")
                // Post notification to handle the audio file import
                NotificationCenter.default.post(name: .audioFileSelected, object: url)
            }
        }
    }
}

// MARK: - Navigation Item Row

/// Single navigation item in the sidebar
/// US-806: Redesigned navigation items with terracotta highlight for active item
struct NavigationItemRow: View {
    let item: NavigationItem
    let isSelected: Bool
    let isCollapsed: Bool
    let animationNamespace: Namespace.ID
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    // US-806: Icon color based on selection and hover state
    private var iconColor: Color {
        if isSelected {
            return Color.Voxa.accent // Terracotta for active
        } else if isHovering {
            return Color.Voxa.textPrimary // Darker on hover
        } else {
            return Color.Voxa.textSecondary // Muted for inactive
        }
    }
    
    // US-806: Text color based on selection and hover state
    private var textColor: Color {
        if isSelected {
            return Color.Voxa.accent // Terracotta for active
        } else if isHovering {
            return Color.Voxa.textPrimary // Darker on hover
        } else {
            return Color.Voxa.textSecondary // Muted for inactive
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                // US-806: Icon with updated color logic
                Image(systemName: isSelected ? item.iconName : item.iconNameInactive)
                    .font(.system(size: 18, weight: isSelected ? .medium : .regular))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
                
                // Label (hidden when collapsed)
                if !isCollapsed {
                    Text(item.displayName)
                        .font(Font.Voxa.body)
                        .fontWeight(isSelected ? .medium : .regular)
                        .foregroundColor(textColor)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
                
                if !isCollapsed {
                    Spacer()
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm + 4)
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .background(
                ZStack {
                    // US-806: Terracotta background highlight for selected item (bg-primary/10)
                    if isSelected {
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .fill(Color.Voxa.accent.opacity(0.10))
                            .matchedGeometryEffect(id: "selectedBackground", in: animationNamespace)
                    }
                    
                    // US-806: Subtle hover highlight (bg-black/5 in light mode, bg-white/5 in dark mode)
                    if isHovering && !isSelected {
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .fill(Color.Voxa.textPrimary.opacity(0.05))
                    }
                }
            )
            .cornerRadius(CornerRadius.small)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(VoxaAnimation.quick) {
                isHovering = hovering
            }
        }
        .help(item.displayName)
    }
}

// MARK: - Dashboard Home View (US-633)

/// Dashboard home view showing activity and quick actions
/// US-633: Dashboard Home View
struct HomeContentView: View {
    @StateObject private var statsManager = UsageStatsManager.shared
    @State private var hoveredQuickAction: QuickAction?
    /// US-805: Hover state for Quick Tools buttons
    @State private var hoveredQuickTool: QuickToolAction?
    /// US-805: State for audio import file picker
    @State private var showAudioImportPicker = false
    
    /// US-802: Recording state for Start Recording button
    @State private var isRecording = false
    /// US-802: Hover state for Start Recording button lift effect
    @State private var isRecordingButtonHovered = false
    /// US-802: Pulse animation state for microphone icon
    @State private var isPulsing = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // MARK: - Welcome Message
                welcomeSection
                
                // MARK: - Two Column Layout (US-804, US-807)
                // Main content (8/12) + Daily Insights Sidebar (4/12)
                HStack(alignment: .top, spacing: Spacing.xl) {
                    // MARK: - Main Content Column (Left)
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        // MARK: - Usage Statistics Row
                        if statsManager.hasActivity {
                            statsSection
                        } else {
                            emptyStatsSection
                        }
                        
                        // MARK: - Feature Banner (optional promotional area)
                        featureBannerSection
                        
                        // MARK: - Quick Actions
                        quickActionsSection
                        
                        // MARK: - US-805: Quick Tools Section
                        quickToolsSection
                        
                        // MARK: - US-803: Recent Transcriptions List
                        recentTranscriptionsSection
                    }
                    .frame(maxWidth: .infinity)
                    
                    // MARK: - US-804: Daily Insights Sidebar (Right)
                    dailyInsightsSidebar
                        .frame(width: 280)
                }
                
                Spacer(minLength: Spacing.xxl)
            }
            .padding(Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Voxa.background)
        // US-805: Listen for audio import request
        .onReceive(NotificationCenter.default.publisher(for: .openAudioImport)) { _ in
            showAudioImportPicker = true
        }
        // US-805: File importer for audio import
        .fileImporter(
            isPresented: $showAudioImportPicker,
            allowedContentTypes: [.audio, .mpeg, .mp3, .wav],
            allowsMultipleSelection: false
        ) { result in
            handleAudioImport(result)
        }
    }
    
    // MARK: - US-805: Audio Import Handler
    
    /// Handle audio file import result
    /// US-805: Connect button actions - Import Audio shows file picker and transcribes selected file
    private func handleAudioImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            print("[US-805] Audio file selected: \(url.lastPathComponent)")
            // Show toast notification for audio import (transcription coming soon)
            ToastManager.shared.showInfo(
                "Audio Import",
                message: "Audio import feature coming soon. Selected: \(url.lastPathComponent)",
                icon: "square.and.arrow.down",
                duration: 4.0
            )
        case .failure(let error):
            print("[US-805] Audio import failed: \(error.localizedDescription)")
            ToastManager.shared.showError("Import Failed", message: error.localizedDescription)
        }
    }
    
    // MARK: - Welcome Section (US-801: Home Dashboard Header)
    
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // MARK: - Top Header Row
            // US-801: DASHBOARD label (uppercase, tracking-widest) + Date and System Active status
            HStack(alignment: .center) {
                // DASHBOARD label
                Text("DASHBOARD")
                    .font(Font.Voxa.small)
                    .fontWeight(.semibold)
                    .tracking(4) // tracking-widest equivalent
                    .foregroundColor(Color.Voxa.textSecondary)
                
                Spacer()
                
                // Date and System Active status
                HStack(spacing: Spacing.md) {
                    // Current date
                    Text(currentDateString)
                        .font(Font.Voxa.caption)
                        .foregroundColor(Color.Voxa.textSecondary)
                    
                    // System Active status indicator
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(Color.Voxa.success)
                            .frame(width: 8, height: 8)
                        
                        Text("System Active")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.textSecondary)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.Voxa.success.opacity(0.1))
                    .cornerRadius(CornerRadius.small)
                }
            }
            
            // MARK: - Main Greeting and Start Recording Button
            // US-801: Time-based greeting with Playfair Display style font (~48-60pt)
            // US-802: Start Recording Button positioned prominently
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(greetingMessage)
                        .font(Font.Voxa.displayGreeting)
                        .foregroundColor(Color.Voxa.textPrimary)
                    
                    // Subtitle with last session info
                    Text(lastSessionSubtitle)
                        .font(Font.Voxa.body)
                        .foregroundColor(Color.Voxa.textSecondary)
                }
                
                Spacer()
                
                // US-802: Start Recording Button - Pill-shaped, terracotta background
                startRecordingButton
            }
        }
    }
    
    // MARK: - US-802: Start Recording Button
    
    /// Prominent pill-shaped Start Recording button with pulse animation and hover lift effect
    private var startRecordingButton: some View {
        Button(action: toggleRecording) {
            HStack(spacing: Spacing.md) {
                // Microphone icon with pulse animation when recording
                ZStack {
                    // Pulse animation circle (only visible when recording)
                    if isRecording {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .scaleEffect(isPulsing ? 1.4 : 1.0)
                            .opacity(isPulsing ? 0.0 : 0.5)
                            .animation(
                                .easeOut(duration: 1.0)
                                .repeatForever(autoreverses: false),
                                value: isPulsing
                            )
                    }
                    
                    // Microphone or stop icon
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 24, height: 24)
                
                // Button text
                Text(isRecording ? "Stop Recording" : "Start Recording")
                    .font(Font.Voxa.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                // US-802: Keyboard shortcut badge
                shortcutBadge
            }
            .padding(.horizontal, Spacing.lg + 4)
            .padding(.vertical, Spacing.md)
            .background(
                Capsule()
                    .fill(isRecording ? Color.Voxa.error : Color.Voxa.accent)
            )
            // US-802: Hover lift effect - shadow and slight Y offset
            .shadow(
                color: (isRecording ? Color.Voxa.error : Color.Voxa.accent).opacity(isRecordingButtonHovered ? 0.4 : 0.2),
                radius: isRecordingButtonHovered ? 12 : 6,
                x: 0,
                y: isRecordingButtonHovered ? 4 : 2
            )
            .scaleEffect(isRecordingButtonHovered ? 1.02 : 1.0)
            .offset(y: isRecordingButtonHovered ? -2 : 0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(VoxaAnimation.quick) {
                isRecordingButtonHovered = hovering
            }
        }
        .onChange(of: isRecording) { _, newValue in
            // Start or stop pulse animation when recording state changes
            if newValue {
                withAnimation {
                    isPulsing = true
                }
            } else {
                isPulsing = false
            }
        }
        .onAppear {
            // Subscribe to recording state changes from the app
            NotificationCenter.default.addObserver(
                forName: .recordingStateChanged,
                object: nil,
                queue: .main
            ) { notification in
                if let state = notification.object as? RecordingState {
                    withAnimation(VoxaAnimation.smooth) {
                        isRecording = (state == .recording)
                    }
                }
            }
        }
    }
    
    /// US-802: Keyboard shortcut badge showing ⌥⌘R
    private var shortcutBadge: some View {
        HStack(spacing: 2) {
            Text("⌥⌘R")
                .font(Font.Voxa.monoSmall)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.15))
        )
    }
    
    /// US-802: Toggle recording state and notify the app
    private func toggleRecording() {
        // Post notification to trigger recording toggle via AppDelegate
        NotificationCenter.default.post(name: .toggleRecording, object: nil)
    }
    
    // MARK: - Time-Based Greeting Logic (US-801)
    // Morning: before 12pm, Afternoon: 12pm-5pm, Evening: after 5pm
    
    /// Time-based greeting message with period (US-801)
    /// Morning: before 12pm, Afternoon: 12pm-5pm, Evening: after 5pm
    private var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning."
        } else if hour < 17 {
            return "Good afternoon."
        } else {
            return "Good evening."
        }
    }
    
    /// Current date string formatted as "Thursday, January 15"
    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
    
    /// Subtitle showing last session info (US-801)
    /// Format: "Ready to capture your thoughts? Your last session was X ago."
    /// Negative case: No previous session -> "Ready to capture your thoughts?"
    private var lastSessionSubtitle: String {
        if let lastEntry = statsManager.recentEntries.first {
            let timeAgo = relativeTimeString(from: lastEntry.timestamp)
            return "Ready to capture your thoughts? Your last session was \(timeAgo)."
        } else {
            return "Ready to capture your thoughts?"
        }
    }
    
    /// Convert a date to a relative time string (e.g., "2 hours ago", "yesterday")
    private func relativeTimeString(from date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let days = components.day, days > 0 {
            if days == 1 {
                return "yesterday"
            } else if days < 7 {
                return "\(days) days ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return "on \(formatter.string(from: date))"
            }
        } else if let hours = components.hour, hours > 0 {
            if hours == 1 {
                return "1 hour ago"
            } else {
                return "\(hours) hours ago"
            }
        } else if let minutes = components.minute, minutes > 0 {
            if minutes == 1 {
                return "1 minute ago"
            } else {
                return "\(minutes) minutes ago"
            }
        } else {
            return "just now"
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Your Activity")
                .font(Font.Voxa.headline)
                .foregroundColor(Color.Voxa.textPrimary)
            
            HStack(spacing: Spacing.lg) {
                // Streak Days
                StatCard(
                    icon: "flame.fill",
                    value: "\(statsManager.streakDays)",
                    label: "Day Streak",
                    iconColor: .orange
                )
                
                // Total Words
                StatCard(
                    icon: "text.word.spacing",
                    value: formatNumber(statsManager.totalWordsTranscribed),
                    label: "Words",
                    iconColor: Color.Voxa.accent
                )
                
                // Average WPM
                StatCard(
                    icon: "speedometer",
                    value: String(format: "%.0f", statsManager.averageWPM),
                    label: "Avg WPM",
                    iconColor: Color.Voxa.info
                )
                
                // Total Transcriptions
                StatCard(
                    icon: "waveform",
                    value: "\(statsManager.totalTranscriptions)",
                    label: "Recordings",
                    iconColor: Color.Voxa.success
                )
            }
        }
    }
    
    /// Empty state for stats section showing onboarding prompt
    private var emptyStatsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Get Started")
                .font(Font.Voxa.headline)
                .foregroundColor(Color.Voxa.textPrimary)
            
            HStack(spacing: Spacing.lg) {
                Image(systemName: "waveform.badge.plus")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(Color.Voxa.accent)
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Record your first transcription")
                        .font(Font.Voxa.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Voxa.textPrimary)
                    
                    Text("Press ⌥⌘R anywhere to start recording")
                        .font(Font.Voxa.caption)
                        .foregroundColor(Color.Voxa.textSecondary)
                }
                
                Spacer()
            }
            .padding(Spacing.lg)
            .background(Color.Voxa.accentLight)
            .cornerRadius(CornerRadius.medium)
        }
    }
    
    // MARK: - Feature Banner Section
    
    private var featureBannerSection: some View {
        HStack(spacing: Spacing.lg) {
            // Banner icon
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(
                        LinearGradient(
                            colors: [Color.Voxa.accent.opacity(0.8), Color.Voxa.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("AI-Powered Text Cleanup")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                Text("Enable intelligent formatting and punctuation in Settings → Text Cleanup")
                    .font(Font.Voxa.caption)
                    .foregroundColor(Color.Voxa.textSecondary)
            }
            
            Spacer()
            
            Button(action: {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }) {
                Text("Settings")
                    .font(Font.Voxa.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color.Voxa.accent)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.Voxa.accentLight)
                    .cornerRadius(CornerRadius.small)
            }
            .buttonStyle(InteractiveScaleStyle())
        }
        .padding(Spacing.lg)
        .background(Color.Voxa.surface)
        .cornerRadius(CornerRadius.medium)
        .voxaShadow(.subtle)
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Quick Actions")
                .font(Font.Voxa.headline)
                .foregroundColor(Color.Voxa.textPrimary)
            
            HStack(spacing: Spacing.lg) {
                ForEach(QuickAction.allCases) { action in
                    QuickActionCard(
                        action: action,
                        isHovered: hoveredQuickAction == action,
                        onHover: { isHovering in
                            withAnimation(VoxaAnimation.quick) {
                                hoveredQuickAction = isHovering ? action : nil
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - US-805: Quick Tools Section
    
    /// US-805: Quick Tools Section with bordered button components for AI Text Cleanup and Import Audio
    /// Displays quick access buttons with italic header and hover states (border and icon turn terracotta)
    private var quickToolsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // US-805: Section header with Playfair Display italic (matching Recent Transcriptions style)
            Text("Quick Tools")
                .font(Font.Voxa.sectionHeaderItalic)
                .foregroundColor(Color.Voxa.textPrimary)
            
            // US-805: Two tool buttons displayed horizontally
            HStack(spacing: Spacing.lg) {
                ForEach(QuickToolAction.allCases) { tool in
                    QuickToolButton(
                        tool: tool,
                        isHovered: hoveredQuickTool == tool,
                        onHover: { isHovering in
                            withAnimation(VoxaAnimation.quick) {
                                hoveredQuickTool = isHovering ? tool : nil
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Recent Transcriptions Section (US-803)
    
    /// US-803: Recent Transcriptions List with section header, View All link, and transcription items
    private var recentTranscriptionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // MARK: - Section Header with Playfair Display Italic + View All Link
            HStack(alignment: .center) {
                // US-803: Section header with Playfair Display italic (sectionHeaderItalic)
                Text("Recent Transcriptions")
                    .font(Font.Voxa.sectionHeaderItalic)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                Spacer()
                
                // US-803: View All link to navigate to History tab
                if !statsManager.recentEntries.isEmpty {
                    Button(action: {
                        // Navigate to history view
                        NotificationCenter.default.post(name: .navigateToHistory, object: nil)
                    }) {
                        HStack(spacing: Spacing.xs) {
                            Text("View All")
                                .font(Font.Voxa.caption)
                                .fontWeight(.medium)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(Color.Voxa.accent)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // MARK: - Transcription List or Empty State
            if statsManager.recentEntries.isEmpty {
                // US-803: Empty state when no transcriptions
                recentTranscriptionsEmptyState
            } else {
                // US-803: Show last 3-5 transcriptions (configurable, default 5)
                recentTranscriptionsList
            }
        }
    }
    
    /// US-803: Empty state when no transcriptions
    private var recentTranscriptionsEmptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: Spacing.md) {
                // Empty state icon
                ZStack {
                    Circle()
                        .fill(Color.Voxa.surfaceSecondary)
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "waveform.badge.plus")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(Color.Voxa.textTertiary)
                }
                
                VStack(spacing: Spacing.xs) {
                    Text("No transcriptions yet")
                        .font(Font.Voxa.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Voxa.textSecondary)
                    
                    Text("Press ⌥⌘R to start your first recording")
                        .font(Font.Voxa.caption)
                        .foregroundColor(Color.Voxa.textTertiary)
                }
            }
            .padding(.vertical, Spacing.xl)
            Spacer()
        }
        .background(Color.Voxa.surface)
        .cornerRadius(CornerRadius.medium)
        .voxaShadow(.subtle)
    }
    
    /// US-803: List of recent transcriptions (3-5 items)
    private var recentTranscriptionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Show up to 5 recent transcriptions
            let displayEntries = Array(statsManager.recentEntries.prefix(5))
            
            ForEach(Array(displayEntries.enumerated()), id: \.element.id) { index, entry in
                RecentTranscriptionItem(entry: entry, isLast: index == displayEntries.count - 1)
            }
        }
        .background(Color.Voxa.surface)
        .cornerRadius(CornerRadius.medium)
        .voxaShadow(.subtle)
    }
    
    // MARK: - US-804: Daily Insights Sidebar
    
    /// US-804: Daily Insights Sidebar showing daily statistics (words spoken, time saved)
    /// Displays in the right column of the dashboard with italic header and prominent numbers
    private var dailyInsightsSidebar: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // MARK: - Section Header with Italic Style
            // US-804: Daily Insights section with italic header (matching Recent Transcriptions)
            Text("Daily Insights")
                .font(Font.Voxa.sectionHeaderItalic)
                .foregroundColor(Color.Voxa.textPrimary)
            
            // MARK: - Insights Content
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // MARK: - Words Spoken Card
                // US-804: Display Words Spoken with large number and percentage change
                DailyInsightCard(
                    icon: "text.word.spacing",
                    iconColor: Color.Voxa.accent,
                    title: "Words Spoken",
                    value: formatNumber(statsManager.todayWordsSpoken),
                    percentageChange: statsManager.wordsSpokenPercentageChange,
                    subtitle: statsManager.hasTodayActivity ? "\(statsManager.todayTranscriptionCount) transcription\(statsManager.todayTranscriptionCount == 1 ? "" : "s") today" : "No activity today"
                )
                
                // MARK: - Time Saved Card
                // US-804: Display Time Saved with comparison label
                DailyInsightCard(
                    icon: "clock.badge.checkmark",
                    iconColor: Color.Voxa.success,
                    title: "Time Saved",
                    value: statsManager.todayTimeSavedFormatted,
                    percentageChange: nil, // Time saved doesn't show percentage
                    subtitle: statsManager.timeSavedComparisonLabel
                )
                
                // MARK: - Additional Insight: Today's WPM (optional context)
                if statsManager.hasTodayActivity {
                    DailyInsightCard(
                        icon: "speedometer",
                        iconColor: Color.Voxa.info,
                        title: "Today's Pace",
                        value: String(format: "%.0f", todayAverageWPM),
                        percentageChange: nil,
                        subtitle: "words per minute"
                    )
                }
            }
            .padding(Spacing.md)
            .background(Color.Voxa.surface)
            .cornerRadius(CornerRadius.medium)
            .voxaShadow(.subtle)
            
            Spacer()
        }
    }
    
    /// Calculate today's average WPM for Daily Insights
    private var todayAverageWPM: Double {
        let todayDuration = statsManager.todayRecordingDurationSeconds
        guard todayDuration > 0 else { return 0 }
        return Double(statsManager.todayWordsSpoken) / (todayDuration / 60.0)
    }
    
    // MARK: - Helpers
    
    /// Format large numbers with K/M suffix
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        }
        return "\(number)"
    }
}

// MARK: - US-804: Daily Insight Card Component

/// Individual insight card for the Daily Insights sidebar
/// US-804: Displays a single statistic with icon, large number, percentage change indicator, and subtitle
struct DailyInsightCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let percentageChange: Double?
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // MARK: - Header Row (Icon + Title)
            HStack(spacing: Spacing.sm) {
                // Icon in colored circle
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                Text(title)
                    .font(Font.Voxa.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color.Voxa.textSecondary)
                
                Spacer()
            }
            
            // MARK: - Large Value with Percentage Change
            HStack(alignment: .lastTextBaseline, spacing: Spacing.sm) {
                // US-804: Large numbers displayed prominently
                Text(value)
                    .font(Font.Voxa.largeTitle)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                // US-804: Percentage change with colored indicator
                if let change = percentageChange {
                    PercentageChangeIndicator(change: change)
                }
                
                Spacer()
            }
            
            // MARK: - Subtitle / Comparison Label
            // US-804: Display comparison label below value
            Text(subtitle)
                .font(Font.Voxa.small)
                .foregroundColor(Color.Voxa.textTertiary)
        }
        .padding(Spacing.md)
        .background(Color.Voxa.surfaceSecondary.opacity(0.5))
        .cornerRadius(CornerRadius.small)
    }
}

// MARK: - US-804: Percentage Change Indicator Component

/// Colored percentage change indicator for Daily Insights
/// US-804: Shows percentage change with up/down arrow and colored background
/// - Positive change: green with up arrow
/// - Negative change: red with down arrow
/// - Zero change: gray with dash
struct PercentageChangeIndicator: View {
    let change: Double
    
    /// Color based on change direction
    private var indicatorColor: Color {
        if change > 0 {
            return Color.Voxa.success
        } else if change < 0 {
            return Color.Voxa.error
        } else {
            return Color.Voxa.textTertiary
        }
    }
    
    /// Arrow icon based on change direction
    private var arrowIcon: String {
        if change > 0 {
            return "arrow.up"
        } else if change < 0 {
            return "arrow.down"
        } else {
            return "minus"
        }
    }
    
    /// Formatted percentage string (absolute value)
    private var percentageText: String {
        let absChange = abs(change)
        if absChange >= 100 {
            return String(format: "%.0f%%", absChange)
        } else if absChange >= 10 {
            return String(format: "%.0f%%", absChange)
        } else {
            return String(format: "%.1f%%", absChange)
        }
    }
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: arrowIcon)
                .font(.system(size: 9, weight: .bold))
            
            Text(percentageText)
                .font(Font.Voxa.small)
                .fontWeight(.semibold)
        }
        .foregroundColor(indicatorColor)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(indicatorColor.opacity(0.12))
        .cornerRadius(CornerRadius.small)
    }
}

// MARK: - US-803: Recent Transcription Item Component

/// Individual transcription item for the Recent Transcriptions list
/// US-803: Build transcription item component with icon, title, subtitle, timestamp
struct RecentTranscriptionItem: View {
    let entry: TranscriptionEntry
    let isLast: Bool
    
    /// US-803: Hover state for highlight and title color change
    @State private var isHovered = false
    
    /// Derived title from transcription text (first line or truncated)
    private var title: String {
        // Get first meaningful line as title
        let lines = entry.textPreview.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if let firstLine = lines.first {
            // Truncate if too long
            if firstLine.count > 50 {
                return String(firstLine.prefix(47)) + "..."
            }
            return firstLine
        }
        return entry.textPreview.prefix(50).description
    }
    
    /// Subtitle showing word count and duration
    private var subtitle: String {
        let wordText = entry.wordCount == 1 ? "word" : "words"
        let duration = String(format: "%.1fs", entry.durationSeconds)
        return "\(entry.wordCount) \(wordText) • \(duration)"
    }
    
    /// Relative timestamp (e.g., "2 hours ago", "Yesterday")
    private var relativeTimestamp: String {
        entry.relativeDateString == "Today" ? entry.timeString : entry.relativeDateString
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: Spacing.md) {
                // MARK: - Icon (waveform in circle)
                // US-803: Icon for transcription item
                ZStack {
                    Circle()
                        .fill(isHovered ? Color.Voxa.accentLight : Color.Voxa.surfaceSecondary)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "waveform")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isHovered ? Color.Voxa.accent : Color.Voxa.textSecondary)
                }
                
                // MARK: - Title and Subtitle
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    // US-803: Title (text content preview)
                    // Hover changes title color to accent
                    Text(title)
                        .font(Font.Voxa.body)
                        .fontWeight(.medium)
                        .foregroundColor(isHovered ? Color.Voxa.accent : Color.Voxa.textPrimary)
                        .lineLimit(1)
                    
                    // US-803: Subtitle with metadata
                    Text(subtitle)
                        .font(Font.Voxa.caption)
                        .foregroundColor(Color.Voxa.textSecondary)
                }
                
                Spacer()
                
                // MARK: - Timestamp
                // US-803: Timestamp aligned right
                Text(relativeTimestamp)
                    .font(Font.Voxa.small)
                    .foregroundColor(Color.Voxa.textTertiary)
                
                // Chevron indicator on hover
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.Voxa.textTertiary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            // US-803: Hover highlight background
            .background(isHovered ? Color.Voxa.surfaceSecondary.opacity(0.5) : Color.clear)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(VoxaAnimation.quick) {
                    isHovered = hovering
                }
            }
            .onTapGesture {
                // Copy to clipboard on tap (quick action)
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(entry.fullText, forType: .string)
                ToastManager.shared.showCopiedToClipboard()
            }
            
            // Divider (not shown for last item)
            if !isLast {
                Divider()
                    .background(Color.Voxa.border.opacity(0.5))
                    .padding(.leading, Spacing.md + 40 + Spacing.md) // Align with text, past icon
            }
        }
    }
}

// MARK: - Stat Card Component

/// Individual stat card with icon and value
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let iconColor: Color
    
    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            // Value
            Text(value)
                .font(Font.Voxa.title)
                .foregroundColor(Color.Voxa.textPrimary)
            
            // Label
            Text(label)
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(Color.Voxa.surface)
        .cornerRadius(CornerRadius.medium)
        .voxaShadow(.subtle)
    }
}

// MARK: - Quick Action Model

/// Quick action types for dashboard
enum QuickAction: String, CaseIterable, Identifiable {
    case newRecording = "new_recording"
    case viewHistory = "view_history"
    case openSnippets = "open_snippets"
    case openSettings = "open_settings"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .newRecording:
            return "New Recording"
        case .viewHistory:
            return "View History"
        case .openSnippets:
            return "Snippets"
        case .openSettings:
            return "Settings"
        }
    }
    
    var description: String {
        switch self {
        case .newRecording:
            return "Start a new voice transcription"
        case .viewHistory:
            return "Browse past transcriptions"
        case .openSnippets:
            return "Save and reuse text snippets"
        case .openSettings:
            return "Configure Voxa preferences"
        }
    }
    
    var icon: String {
        switch self {
        case .newRecording:
            return "mic.fill"
        case .viewHistory:
            return "clock.fill"
        case .openSnippets:
            return "doc.on.clipboard.fill"
        case .openSettings:
            return "gearshape.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .newRecording:
            return Color.Voxa.accent
        case .viewHistory:
            return Color.Voxa.info
        case .openSnippets:
            return Color.Voxa.success
        case .openSettings:
            return Color.Voxa.textSecondary
        }
    }
}

// MARK: - Quick Action Card Component

/// Quick action card with hover lift effect
struct QuickActionCard: View {
    let action: QuickAction
    let isHovered: Bool
    var onHover: (Bool) -> Void
    
    var body: some View {
        Button(action: performAction) {
            VStack(spacing: Spacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(action.iconColor.opacity(isHovered ? 0.2 : 0.12))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: action.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(action.iconColor)
                }
                
                // Label
                Text(action.title)
                    .font(Font.Voxa.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                // Description
                Text(action.description)
                    .font(Font.Voxa.small)
                    .foregroundColor(Color.Voxa.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .padding(.horizontal, Spacing.md)
            .background(Color.Voxa.surface)
            .cornerRadius(CornerRadius.medium)
            // Hover lift effect: shadow and slight scale
            .voxaShadow(isHovered ? .card : .subtle)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .offset(y: isHovered ? -2 : 0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            onHover(hovering)
        }
        .animation(VoxaAnimation.quick, value: isHovered)
    }
    
    private func performAction() {
        switch action {
        case .newRecording:
            // Note: Recording is triggered via hotkey, show hint
            // Could post notification to show recording hint
            print("QuickAction: New Recording tapped - use hotkey ⌥⌘R")
        case .viewHistory:
            // Navigate to history tab (would require coordination with parent)
            print("QuickAction: View History tapped")
        case .openSnippets:
            // Navigate to snippets tab
            print("QuickAction: Open Snippets tapped")
        case .openSettings:
            NotificationCenter.default.post(name: .openSettings, object: nil)
        }
    }
}

// MARK: - US-805: Quick Tool Action Model

/// Quick tool action types for the Quick Tools section
/// US-805: Quick Tools Section - Quick access buttons for AI Text Cleanup and Import Audio
enum QuickToolAction: String, CaseIterable, Identifiable {
    case aiTextCleanup = "ai_text_cleanup"
    case importAudio = "import_audio"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .aiTextCleanup:
            return "AI Text Cleanup"
        case .importAudio:
            return "Import Audio"
        }
    }
    
    var description: String {
        switch self {
        case .aiTextCleanup:
            return "Clean up and format transcribed text"
        case .importAudio:
            return "Transcribe an audio file"
        }
    }
    
    var icon: String {
        switch self {
        case .aiTextCleanup:
            return "sparkles"
        case .importAudio:
            return "square.and.arrow.down"
        }
    }
}

// MARK: - US-805: Quick Tool Button Component

/// Bordered button component for Quick Tools with hover state
/// US-805: Build bordered button components with icons
/// Implements hover states where border and icon turn terracotta
struct QuickToolButton: View {
    let tool: QuickToolAction
    let isHovered: Bool
    var onHover: (Bool) -> Void
    
    var body: some View {
        Button(action: performAction) {
            HStack(spacing: Spacing.md) {
                // Icon - changes to terracotta on hover
                Image(systemName: tool.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isHovered ? Color.Voxa.accent : Color.Voxa.textSecondary)
                
                // Label and description
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.title)
                        .font(Font.Voxa.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Voxa.textPrimary)
                    
                    Text(tool.description)
                        .font(Font.Voxa.small)
                        .foregroundColor(Color.Voxa.textSecondary)
                }
                
                Spacer()
                
                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isHovered ? Color.Voxa.accent : Color.Voxa.textTertiary)
            }
            .padding(Spacing.lg)
            .background(Color.Voxa.surface)
            // US-805: Bordered button with hover state - border turns terracotta on hover
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(isHovered ? Color.Voxa.accent : Color.Voxa.border, lineWidth: isHovered ? 1.5 : 1)
            )
            .cornerRadius(CornerRadius.medium)
            // Subtle shadow on hover
            .voxaShadow(isHovered ? .subtle : .subtle)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            onHover(hovering)
        }
        .contentShape(Rectangle())
        .animation(VoxaAnimation.quick, value: isHovered)
    }
    
    private func performAction() {
        switch tool {
        case .aiTextCleanup:
            // Navigate to Settings -> Text Cleanup
            print("[US-805] QuickTool: AI Text Cleanup tapped - navigating to Text Cleanup settings")
            NotificationCenter.default.post(name: .navigateToTextCleanup, object: nil)
        case .importAudio:
            // Show file picker for audio import
            print("[US-805] QuickTool: Import Audio tapped - showing file picker")
            NotificationCenter.default.post(name: .openAudioImport, object: nil)
        }
    }
}

// MARK: - US-804: Daily Insights Section Component

/// Daily Insights section for the sidebar showing daily statistics
/// US-804: Display daily statistics (words spoken, time saved) in sidebar
struct DailyInsightsSection: View {
    @StateObject private var statsManager = UsageStatsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // US-804: Section header with italic font (matching other section headers)
            Text("Daily Insights")
                .font(Font.Voxa.sectionHeaderItalic)
                .foregroundColor(Color.Voxa.textPrimary)
            
            // US-804: Stats cards
            if statsManager.hasTodayActivity {
                VStack(spacing: Spacing.sm) {
                    // Words Spoken stat
                    DailyInsightsStatCard(
                        value: "\(statsManager.todayWordsSpoken)",
                        label: "Words Spoken",
                        percentageChange: statsManager.wordsSpokenPercentageChange,
                        icon: "text.word.spacing"
                    )
                    
                    // Time Saved stat
                    DailyInsightsStatCard(
                        value: statsManager.todayTimeSavedFormatted,
                        label: "Time Saved",
                        comparisonLabel: statsManager.timeSavedComparisonLabel,
                        icon: "clock.arrow.circlepath"
                    )
                }
            } else {
                // Empty state when no activity today
                DailyInsightsEmptyState()
            }
        }
        .padding(Spacing.md)
        .background(Color.Voxa.surfaceSecondary)
        .cornerRadius(CornerRadius.medium)
    }
}

/// Individual stat card for Daily Insights section
/// US-804: Display large numbers prominently with percentage change indicator
struct DailyInsightsStatCard: View {
    let value: String
    let label: String
    var percentageChange: Double? = nil
    var comparisonLabel: String? = nil
    let icon: String
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.Voxa.accentLight)
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.Voxa.accent)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                // US-804: Large number displayed prominently
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(value)
                        .font(Font.Voxa.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color.Voxa.textPrimary)
                    
                    // US-804: Percentage change with colored indicator
                    if let change = percentageChange {
                        DailyInsightsPercentageChange(change: change)
                    }
                }
                
                // Label and comparison
                HStack(spacing: Spacing.xs) {
                    Text(label)
                        .font(Font.Voxa.small)
                        .foregroundColor(Color.Voxa.textSecondary)
                    
                    // US-804: Comparison label for time saved
                    if let comparison = comparisonLabel {
                        Text("•")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.textTertiary)
                        Text(comparison)
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.textTertiary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(Spacing.sm)
        .background(Color.Voxa.surface)
        .cornerRadius(CornerRadius.small)
    }
}

/// Percentage change indicator with colored arrow
/// US-804: Percentage change with colored indicator (green for increase, red for decrease)
struct DailyInsightsPercentageChange: View {
    let change: Double
    
    /// Whether the change is positive
    private var isPositive: Bool { change >= 0 }
    
    /// Formatted percentage string
    private var formattedChange: String {
        let absChange = abs(change)
        if absChange >= 100 {
            return String(format: "%.0f%%", absChange)
        } else {
            return String(format: "%.1f%%", absChange)
        }
    }
    
    /// Color based on direction (green for increase, red for decrease)
    private var changeColor: Color {
        isPositive ? Color.Voxa.success : Color.Voxa.error
    }
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .semibold))
            
            Text(formattedChange)
                .font(Font.Voxa.small)
                .fontWeight(.medium)
        }
        .foregroundColor(changeColor)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 2)
        .background(changeColor.opacity(0.15))
        .cornerRadius(CornerRadius.small)
    }
}

/// Empty state for Daily Insights when no activity today
/// US-804: Shows a prompt to start recording when no daily activity
struct DailyInsightsEmptyState: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(Color.Voxa.textTertiary)
            
            Text("No activity today")
                .font(Font.Voxa.small)
                .foregroundColor(Color.Voxa.textSecondary)
            
            Text("Start recording to see your insights")
                .font(Font.Voxa.small)
                .foregroundColor(Color.Voxa.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(Color.Voxa.surface)
        .cornerRadius(CornerRadius.small)
    }
}

// MARK: - Activity Timeline Entry Component

/// Single entry in the activity timeline
struct ActivityTimelineEntry: View {
    let entry: TranscriptionEntry
    @State private var isHovered = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: Spacing.md) {
                // Timeline dot and line
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color.Voxa.accent)
                        .frame(width: 8, height: 8)
                    
                    Rectangle()
                        .fill(Color.Voxa.border)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 20)
                
                // Entry content
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        // Timestamp
                        Text(entry.timeString)
                            .font(Font.Voxa.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Voxa.textSecondary)
                        
                        // Word count badge
                        Text("\(entry.wordCount) words")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.textTertiary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.Voxa.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                        
                        Spacer()
                        
                        // Expand/collapse button
                        Button(action: { 
                            withAnimation(VoxaAnimation.quick) {
                                isExpanded.toggle() 
                            }
                        }) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color.Voxa.textTertiary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .opacity(isHovered || isExpanded ? 1 : 0)
                    }
                    
                    // Text preview
                    Text(entry.textPreview)
                        .font(Font.Voxa.body)
                        .foregroundColor(Color.Voxa.textPrimary)
                        .lineLimit(isExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // WPM info when expanded
                    if isExpanded {
                        HStack(spacing: Spacing.md) {
                            Label(String(format: "%.0f WPM", entry.wordsPerMinute), systemImage: "speedometer")
                            Label(String(format: "%.1fs", entry.durationSeconds), systemImage: "clock")
                        }
                        .font(Font.Voxa.small)
                        .foregroundColor(Color.Voxa.textTertiary)
                        .padding(.top, Spacing.xs)
                    }
                }
                .padding(.vertical, Spacing.sm)
            }
            .padding(.horizontal, Spacing.sm)
            .background(isHovered ? Color.Voxa.surfaceSecondary.opacity(0.5) : Color.clear)
            .cornerRadius(CornerRadius.small)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(VoxaAnimation.quick) {
                    isHovered = hovering
                }
            }
        }
    }
}


// MARK: - US-634: Transcription History View

/// Full transcription history view with search, filtering, and management
/// US-634: Browse and search transcription history
struct HistoryContentView: View {
    @StateObject private var statsManager = UsageStatsManager.shared
    
    /// Search query for filtering entries
    @State private var searchQuery: String = ""
    
    /// Entry pending deletion (for confirmation dialog)
    @State private var entryToDelete: TranscriptionEntry?
    
    /// Whether to show delete confirmation dialog
    @State private var showDeleteConfirmation = false
    
    /// Filtered entries based on search query
    private var filteredEntries: [TranscriptionEntry] {
        statsManager.searchEntries(query: searchQuery)
    }
    
    /// Grouped entries by date category
    private var groupedEntries: [DateCategory: [TranscriptionEntry]] {
        statsManager.groupEntriesByDate(filteredEntries)
    }
    
    /// Sorted date categories for display
    private var sortedCategories: [DateCategory] {
        groupedEntries.keys.sorted()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header with search bar
            historyHeader
            
            Divider()
                .background(Color.Voxa.border)
            
            // MARK: - Content
            if statsManager.recentEntries.isEmpty {
                // Empty state when no history
                emptyHistoryState
            } else if filteredEntries.isEmpty {
                // No results for search
                noSearchResultsState
            } else {
                // History list grouped by date
                historyList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Voxa.background)
        .alert("Delete Transcription?", isPresented: $showDeleteConfirmation, presenting: entryToDelete) { entry in
            Button("Delete", role: .destructive) {
                withAnimation(VoxaAnimation.smooth) {
                    statsManager.removeEntry(entry)
                }
                entryToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                entryToDelete = nil
            }
        } message: { entry in
            Text("This transcription will be permanently deleted. This action cannot be undone.")
        }
    }
    
    // MARK: - Header
    
    private var historyHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Transcription History")
                    .font(Font.Voxa.largeTitle)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                Spacer()
                
                // Entry count badge
                if !statsManager.recentEntries.isEmpty {
                    Text("\(statsManager.recentEntries.count) \(statsManager.recentEntries.count == 1 ? "entry" : "entries")")
                        .font(Font.Voxa.caption)
                        .foregroundColor(Color.Voxa.textSecondary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.Voxa.surfaceSecondary)
                        .cornerRadius(CornerRadius.small)
                }
            }
            
            // Search bar
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.Voxa.textTertiary)
                
                TextField("Search transcriptions...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                if !searchQuery.isEmpty {
                    Button(action: {
                        withAnimation(VoxaAnimation.quick) {
                            searchQuery = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.Voxa.textTertiary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.Voxa.surface)
            .cornerRadius(CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(Color.Voxa.border, lineWidth: 1)
            )
        }
        .padding(Spacing.xl)
    }
    
    // MARK: - Empty State
    
    private var emptyHistoryState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.Voxa.accentLight)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(Color.Voxa.accent)
            }
            
            VStack(spacing: Spacing.sm) {
                Text("No transcription history")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                Text("Your transcriptions will appear here after you record them.\nPress ⌥⌘R to start recording.")
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
    }
    
    // MARK: - No Search Results State
    
    private var noSearchResultsState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.Voxa.surfaceSecondary)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(Color.Voxa.textTertiary)
            }
            
            VStack(spacing: Spacing.sm) {
                Text("No results found")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                Text("No transcriptions match \"\(searchQuery)\".\nTry a different search term.")
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                withAnimation(VoxaAnimation.quick) {
                    searchQuery = ""
                }
            }) {
                Text("Clear Search")
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.accent)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
    }
    
    // MARK: - History List
    
    private var historyList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                ForEach(sortedCategories, id: \.self) { category in
                    if let entries = groupedEntries[category] {
                        // Date category section
                        dateCategorySection(category: category, entries: entries)
                    }
                }
            }
            .padding(Spacing.xl)
        }
        .animation(VoxaAnimation.smooth, value: filteredEntries.count)
    }
    
    // MARK: - Date Category Section
    
    private func dateCategorySection(category: DateCategory, entries: [TranscriptionEntry]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Category header
            HStack {
                Text(category.displayName)
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textSecondary)
                
                Spacer()
                
                Text("\(entries.count)")
                    .font(Font.Voxa.caption)
                    .foregroundColor(Color.Voxa.textTertiary)
            }
            
            // Entries
            ForEach(entries) { entry in
                HistoryEntryCard(
                    entry: entry,
                    searchQuery: searchQuery,
                    onCopy: {
                        copyToClipboard(entry.fullText)
                    },
                    onDelete: {
                        entryToDelete = entry
                        showDeleteConfirmation = true
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Copy text to clipboard and show toast
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        ToastManager.shared.showCopiedToClipboard()
    }
}

// MARK: - History Entry Card Component

/// Individual history entry card with expand/collapse, copy, and delete
struct HistoryEntryCard: View {
    let entry: TranscriptionEntry
    let searchQuery: String
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    @State private var isExpanded = false
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header row with time and actions
            HStack(alignment: .top) {
                // Time and metadata
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(entry.timeString)
                        .font(Font.Voxa.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.Voxa.textPrimary)
                    
                    HStack(spacing: Spacing.sm) {
                        // Word count badge
                        Label("\(entry.wordCount) words", systemImage: "text.word.spacing")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.textTertiary)
                        
                        // Duration badge
                        Label(String(format: "%.1fs", entry.durationSeconds), systemImage: "clock")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.textTertiary)
                        
                        // WPM badge
                        Label(String(format: "%.0f WPM", entry.wordsPerMinute), systemImage: "speedometer")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.textTertiary)
                    }
                }
                
                Spacer()
                
                // Action buttons (visible on hover or when expanded)
                HStack(spacing: Spacing.sm) {
                    // Copy button
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.Voxa.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Color.Voxa.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Copy to clipboard")
                    
                    // Delete button
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.Voxa.error)
                            .frame(width: 28, height: 28)
                            .background(Color.Voxa.errorLight)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Delete transcription")
                    
                    // Expand/collapse button
                    Button(action: {
                        withAnimation(VoxaAnimation.quick) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.Voxa.textTertiary)
                            .frame(width: 28, height: 28)
                            .background(Color.Voxa.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(isExpanded ? "Collapse" : "Expand")
                }
                .opacity(isHovered || isExpanded ? 1 : 0.5)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if isExpanded {
                    // Full text when expanded
                    Text(highlightedText(entry.fullText))
                        .font(Font.Voxa.body)
                        .foregroundColor(Color.Voxa.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // Preview text when collapsed
                    Text(highlightedText(entry.textPreview))
                        .font(Font.Voxa.body)
                        .foregroundColor(Color.Voxa.textPrimary)
                        .lineLimit(2)
                    
                    // Show "more" indicator if text is longer than preview
                    if entry.fullText.count > entry.textPreview.count {
                        Text("Click to see full text...")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.accent)
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.Voxa.surface)
        .cornerRadius(CornerRadius.medium)
        .voxaShadow(isHovered ? .card : .subtle)
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(VoxaAnimation.quick) {
                isExpanded.toggle()
            }
        }
        .onHover { hovering in
            withAnimation(VoxaAnimation.quick) {
                isHovered = hovering
            }
        }
    }
    
    /// Highlight search query matches in text
    /// Returns an AttributedString with highlighted matches
    private func highlightedText(_ text: String) -> AttributedString {
        guard !searchQuery.isEmpty else {
            return AttributedString(text)
        }
        
        var attributedString = AttributedString(text)
        let lowercasedText = text.lowercased()
        let lowercasedQuery = searchQuery.lowercased()
        
        // Find and highlight all occurrences
        var searchStartIndex = lowercasedText.startIndex
        while let range = lowercasedText.range(of: lowercasedQuery, range: searchStartIndex..<lowercasedText.endIndex) {
            // Convert String range to AttributedString range
            let lowerBound = text.distance(from: text.startIndex, to: range.lowerBound)
            let upperBound = text.distance(from: text.startIndex, to: range.upperBound)
            
            if let attrRange = Range(NSRange(location: lowerBound, length: upperBound - lowerBound), in: attributedString) {
                attributedString[attrRange].backgroundColor = Color.Voxa.warningLight
                attributedString[attrRange].foregroundColor = Color.Voxa.textPrimary
            }
            
            searchStartIndex = range.upperBound
        }
        
        return attributedString
    }
}

// MARK: - US-635: Snippets Library View

/// Full snippets library view with create, edit, delete, copy, and search
/// US-635: Save and reuse frequently used text snippets
struct SnippetsContentView: View {
    @StateObject private var snippetsManager = SnippetsManager.shared
    
    /// Search query for filtering snippets
    @State private var searchQuery: String = ""
    
    /// Whether to show create snippet sheet
    @State private var showCreateSheet = false
    
    /// Snippet currently being edited (nil means no edit in progress)
    @State private var snippetBeingEdited: Snippet?
    
    /// Snippet pending deletion (for confirmation dialog)
    @State private var snippetToDelete: Snippet?
    
    /// Whether to show delete confirmation dialog
    @State private var showDeleteConfirmation = false
    
    /// Display mode: grid or list
    @State private var isGridView = true
    
    /// Filtered snippets based on search query
    private var filteredSnippets: [Snippet] {
        snippetsManager.searchSnippets(query: searchQuery)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header with search and actions
            snippetsHeader
            
            Divider()
                .background(Color.Voxa.border)
            
            // MARK: - Content
            if snippetsManager.isEmpty {
                // Empty state when no snippets
                emptySnippetsState
            } else if filteredSnippets.isEmpty {
                // No results for search
                noSearchResultsState
            } else {
                // Snippets grid/list
                snippetsContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Voxa.background)
        .sheet(isPresented: $showCreateSheet) {
            CreateSnippetSheet(onSave: { title, content, shortcut in
                snippetsManager.createSnippet(title: title, content: content, shortcut: shortcut)
            })
        }
        .sheet(item: $snippetBeingEdited) { snippet in
            EditSnippetSheet(
                snippet: snippet,
                onSave: { title, content, shortcut in
                    snippetsManager.updateSnippet(id: snippet.id, title: title, content: content, shortcut: shortcut)
                }
            )
        }
        .alert("Delete Snippet?", isPresented: $showDeleteConfirmation, presenting: snippetToDelete) { snippet in
            Button("Delete", role: .destructive) {
                withAnimation(VoxaAnimation.smooth) {
                    snippetsManager.deleteSnippet(snippet)
                }
                snippetToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                snippetToDelete = nil
            }
        } message: { snippet in
            Text("Are you sure you want to delete \"\(snippet.title)\"? This action cannot be undone.")
        }
    }
    
    // MARK: - Header
    
    private var snippetsHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Snippets Library")
                    .font(Font.Voxa.largeTitle)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                Spacer()
                
                // View toggle (grid/list)
                HStack(spacing: Spacing.xs) {
                    Button(action: {
                        withAnimation(VoxaAnimation.quick) {
                            isGridView = true
                        }
                    }) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isGridView ? Color.Voxa.accent : Color.Voxa.textTertiary)
                            .frame(width: 28, height: 28)
                            .background(isGridView ? Color.Voxa.accentLight : Color.clear)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Grid view")
                    
                    Button(action: {
                        withAnimation(VoxaAnimation.quick) {
                            isGridView = false
                        }
                    }) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(!isGridView ? Color.Voxa.accent : Color.Voxa.textTertiary)
                            .frame(width: 28, height: 28)
                            .background(!isGridView ? Color.Voxa.accentLight : Color.clear)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("List view")
                }
                .padding(2)
                .background(Color.Voxa.surfaceSecondary)
                .cornerRadius(CornerRadius.small)
                
                // Create new snippet button
                Button(action: {
                    showCreateSheet = true
                }) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("New Snippet")
                            .font(Font.Voxa.body)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.Voxa.accent)
                    .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(InteractiveScaleStyle())
                .disabled(snippetsManager.isAtCapacity)
                .opacity(snippetsManager.isAtCapacity ? 0.5 : 1.0)
                .help(snippetsManager.isAtCapacity ? "Maximum snippets reached" : "Create new snippet")
            }
            
            HStack(spacing: Spacing.md) {
                // Search bar
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.Voxa.textTertiary)
                    
                    TextField("Search snippets...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(Font.Voxa.body)
                        .foregroundColor(Color.Voxa.textPrimary)
                    
                    if !searchQuery.isEmpty {
                        Button(action: {
                            withAnimation(VoxaAnimation.quick) {
                                searchQuery = ""
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.Voxa.textTertiary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.Voxa.surface)
                .cornerRadius(CornerRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .stroke(Color.Voxa.border, lineWidth: 1)
                )
                
                Spacer()
                
                // Snippet count badge
                if !snippetsManager.isEmpty {
                    Text("\(snippetsManager.count) \(snippetsManager.count == 1 ? "snippet" : "snippets")")
                        .font(Font.Voxa.caption)
                        .foregroundColor(Color.Voxa.textSecondary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.Voxa.surfaceSecondary)
                        .cornerRadius(CornerRadius.small)
                }
            }
        }
        .padding(Spacing.xl)
    }
    
    // MARK: - Empty State
    
    private var emptySnippetsState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.Voxa.accentLight)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(Color.Voxa.accent)
            }
            
            VStack(spacing: Spacing.sm) {
                Text("No snippets yet")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                Text("Create your first snippet to save frequently used text.\nYou can assign keyboard shortcuts for quick access.")
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                showCreateSheet = true
            }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text("Create First Snippet")
                        .fontWeight(.medium)
                }
                .font(Font.Voxa.body)
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(Color.Voxa.accent)
                .cornerRadius(CornerRadius.small)
            }
            .buttonStyle(InteractiveScaleStyle())
            .padding(.top, Spacing.md)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
    }
    
    // MARK: - No Search Results State
    
    private var noSearchResultsState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.Voxa.surfaceSecondary)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(Color.Voxa.textTertiary)
            }
            
            VStack(spacing: Spacing.sm) {
                Text("No snippets found")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                Text("No snippets match \"\(searchQuery)\".\nTry a different search term.")
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                withAnimation(VoxaAnimation.quick) {
                    searchQuery = ""
                }
            }) {
                Text("Clear Search")
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.accent)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
    }
    
    // MARK: - Snippets Content (Grid/List)
    
    private var snippetsContent: some View {
        ScrollView {
            if isGridView {
                snippetsGrid
            } else {
                snippetsList
            }
        }
        .animation(VoxaAnimation.smooth, value: filteredSnippets.count)
    }
    
    // MARK: - Grid View
    
    private var snippetsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 280, maximum: 400), spacing: Spacing.lg)
        ], spacing: Spacing.lg) {
            ForEach(filteredSnippets) { snippet in
                SnippetCard(
                    snippet: snippet,
                    searchQuery: searchQuery,
                    onCopy: {
                        snippet.copyToClipboard()
                        ToastManager.shared.showCopiedToClipboard()
                    },
                    onEdit: {
                        snippetBeingEdited = snippet
                    },
                    onDelete: {
                        snippetToDelete = snippet
                        showDeleteConfirmation = true
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            }
        }
        .padding(Spacing.xl)
    }
    
    // MARK: - List View
    
    private var snippetsList: some View {
        LazyVStack(spacing: Spacing.md) {
            ForEach(filteredSnippets) { snippet in
                SnippetListRow(
                    snippet: snippet,
                    searchQuery: searchQuery,
                    onCopy: {
                        snippet.copyToClipboard()
                        ToastManager.shared.showCopiedToClipboard()
                    },
                    onEdit: {
                        snippetBeingEdited = snippet
                    },
                    onDelete: {
                        snippetToDelete = snippet
                        showDeleteConfirmation = true
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                    removal: .opacity.combined(with: .scale(scale: 0.98))
                ))
            }
        }
        .padding(Spacing.xl)
    }
}

// MARK: - Snippet Card Component (Grid View)

/// Individual snippet card for grid display
struct SnippetCard: View {
    let snippet: Snippet
    let searchQuery: String
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header row with title and shortcut
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(highlightedText(snippet.title))
                        .font(Font.Voxa.headline)
                        .foregroundColor(Color.Voxa.textPrimary)
                        .lineLimit(1)
                    
                    // Shortcut badge if assigned
                    if let shortcut = snippet.shortcut, !shortcut.isEmpty {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "keyboard")
                                .font(.system(size: 10, weight: .medium))
                            Text(shortcut)
                                .font(Font.Voxa.monoSmall)
                        }
                        .foregroundColor(Color.Voxa.accent)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Color.Voxa.accentLight)
                        .cornerRadius(CornerRadius.small)
                    }
                }
                
                Spacer()
                
                // Action buttons (visible on hover)
                HStack(spacing: Spacing.xs) {
                    // Copy button
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.Voxa.textSecondary)
                            .frame(width: 26, height: 26)
                            .background(Color.Voxa.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Copy to clipboard")
                    
                    // Edit button
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.Voxa.textSecondary)
                            .frame(width: 26, height: 26)
                            .background(Color.Voxa.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Edit snippet")
                    
                    // Delete button
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.Voxa.error)
                            .frame(width: 26, height: 26)
                            .background(Color.Voxa.errorLight)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Delete snippet")
                }
                .opacity(isHovered ? 1 : 0)
            }
            
            // Content preview or full content
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if isExpanded {
                    Text(highlightedText(snippet.content))
                        .font(Font.Voxa.body)
                        .foregroundColor(Color.Voxa.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(highlightedText(snippet.contentPreview))
                        .font(Font.Voxa.body)
                        .foregroundColor(Color.Voxa.textPrimary)
                        .lineLimit(3)
                }
                
                // Show more/less toggle
                if snippet.content.count > 100 {
                    Button(action: {
                        withAnimation(VoxaAnimation.quick) {
                            isExpanded.toggle()
                        }
                    }) {
                        Text(isExpanded ? "Show less" : "Show more")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.accent)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Footer with metadata
            HStack {
                // Word/character count
                Text("\(snippet.wordCount) words • \(snippet.characterCount) chars")
                    .font(Font.Voxa.small)
                    .foregroundColor(Color.Voxa.textTertiary)
                
                Spacer()
                
                // Last updated
                Text("Updated \(snippet.updatedRelativeString)")
                    .font(Font.Voxa.small)
                    .foregroundColor(Color.Voxa.textTertiary)
            }
        }
        .padding(Spacing.lg)
        .background(Color.Voxa.surface)
        .cornerRadius(CornerRadius.medium)
        .voxaShadow(isHovered ? .card : .subtle)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(VoxaAnimation.quick) {
                isHovered = hovering
            }
        }
    }
    
    /// Highlight search query matches in text
    private func highlightedText(_ text: String) -> AttributedString {
        guard !searchQuery.isEmpty else {
            return AttributedString(text)
        }
        
        var attributedString = AttributedString(text)
        let lowercasedText = text.lowercased()
        let lowercasedQuery = searchQuery.lowercased()
        
        var searchStartIndex = lowercasedText.startIndex
        while let range = lowercasedText.range(of: lowercasedQuery, range: searchStartIndex..<lowercasedText.endIndex) {
            let lowerBound = text.distance(from: text.startIndex, to: range.lowerBound)
            let upperBound = text.distance(from: text.startIndex, to: range.upperBound)
            
            if let attrRange = Range(NSRange(location: lowerBound, length: upperBound - lowerBound), in: attributedString) {
                attributedString[attrRange].backgroundColor = Color.Voxa.warningLight
                attributedString[attrRange].foregroundColor = Color.Voxa.textPrimary
            }
            
            searchStartIndex = range.upperBound
        }
        
        return attributedString
    }
}

// MARK: - Snippet List Row Component (List View)

/// Individual snippet row for list display
struct SnippetListRow: View {
    let snippet: Snippet
    let searchQuery: String
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Main row content
            HStack(alignment: .center, spacing: Spacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(Color.Voxa.accentLight)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "doc.text")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.Voxa.accent)
                }
                
                // Title and shortcut
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(highlightedText(snippet.title))
                        .font(Font.Voxa.body)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.Voxa.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: Spacing.sm) {
                        // Shortcut badge
                        if let shortcut = snippet.shortcut, !shortcut.isEmpty {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "keyboard")
                                    .font(.system(size: 9, weight: .medium))
                                Text(shortcut)
                                    .font(Font.Voxa.monoSmall)
                            }
                            .foregroundColor(Color.Voxa.accent)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.Voxa.accentLight)
                            .cornerRadius(CornerRadius.small)
                        }
                        
                        // Word count
                        Text("\(snippet.wordCount) words")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.textTertiary)
                        
                        // Updated date
                        Text("• \(snippet.updatedRelativeString)")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.textTertiary)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: Spacing.xs) {
                    // Copy button
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.Voxa.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Color.Voxa.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Copy to clipboard")
                    
                    // Edit button
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.Voxa.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Color.Voxa.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Edit snippet")
                    
                    // Delete button
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.Voxa.error)
                            .frame(width: 28, height: 28)
                            .background(Color.Voxa.errorLight)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Delete snippet")
                    
                    // Expand/collapse button
                    Button(action: {
                        withAnimation(VoxaAnimation.quick) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.Voxa.textTertiary)
                            .frame(width: 28, height: 28)
                            .background(Color.Voxa.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(isExpanded ? "Collapse" : "Expand")
                }
                .opacity(isHovered || isExpanded ? 1 : 0.5)
            }
            
            // Expanded content preview
            if isExpanded {
                Text(highlightedText(snippet.content))
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.textPrimary)
                    .textSelection(.enabled)
                    .padding(.leading, 40 + Spacing.md) // Align with title
                    .padding(.top, Spacing.sm)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .background(Color.Voxa.surface)
        .cornerRadius(CornerRadius.medium)
        .voxaShadow(isHovered ? .card : .subtle)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(VoxaAnimation.quick) {
                isExpanded.toggle()
            }
        }
        .onHover { hovering in
            withAnimation(VoxaAnimation.quick) {
                isHovered = hovering
            }
        }
    }
    
    /// Highlight search query matches in text
    private func highlightedText(_ text: String) -> AttributedString {
        guard !searchQuery.isEmpty else {
            return AttributedString(text)
        }
        
        var attributedString = AttributedString(text)
        let lowercasedText = text.lowercased()
        let lowercasedQuery = searchQuery.lowercased()
        
        var searchStartIndex = lowercasedText.startIndex
        while let range = lowercasedText.range(of: lowercasedQuery, range: searchStartIndex..<lowercasedText.endIndex) {
            let lowerBound = text.distance(from: text.startIndex, to: range.lowerBound)
            let upperBound = text.distance(from: text.startIndex, to: range.upperBound)
            
            if let attrRange = Range(NSRange(location: lowerBound, length: upperBound - lowerBound), in: attributedString) {
                attributedString[attrRange].backgroundColor = Color.Voxa.warningLight
                attributedString[attrRange].foregroundColor = Color.Voxa.textPrimary
            }
            
            searchStartIndex = range.upperBound
        }
        
        return attributedString
    }
}

// MARK: - Create Snippet Sheet

/// Sheet for creating a new snippet
struct CreateSnippetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, String, String?) -> Void
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var shortcut: String = ""
    @State private var showShortcutField = false
    @State private var shortcutError: String?
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case title, content, shortcut
    }
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        shortcutError == nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Snippet")
                    .font(Font.Voxa.title)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.Voxa.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Color.Voxa.surfaceSecondary)
                        .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(Spacing.lg)
            .background(Color.Voxa.surface)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Title field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Title")
                            .font(Font.Voxa.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Voxa.textSecondary)
                        
                        TextField("Enter snippet title...", text: $title)
                            .textFieldStyle(.plain)
                            .font(Font.Voxa.body)
                            .foregroundColor(Color.Voxa.textPrimary)
                            .padding(Spacing.md)
                            .background(Color.Voxa.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .stroke(Color.Voxa.border, lineWidth: 1)
                            )
                            .focused($focusedField, equals: .title)
                    }
                    
                    // Content field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Content")
                            .font(Font.Voxa.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Voxa.textSecondary)
                        
                        TextEditor(text: $content)
                            .font(Font.Voxa.body)
                            .foregroundColor(Color.Voxa.textPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(Spacing.sm)
                            .frame(minHeight: 150, maxHeight: 300)
                            .background(Color.Voxa.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .stroke(Color.Voxa.border, lineWidth: 1)
                            )
                            .focused($focusedField, equals: .content)
                        
                        Text("Tip: You can paste formatted text or multiple paragraphs")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.textTertiary)
                    }
                    
                    // Optional shortcut field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Button(action: {
                            withAnimation(VoxaAnimation.quick) {
                                showShortcutField.toggle()
                            }
                        }) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: showShortcutField ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                Image(systemName: "keyboard")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Add Keyboard Shortcut (Optional)")
                                    .font(Font.Voxa.body)
                            }
                            .foregroundColor(Color.Voxa.textSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if showShortcutField {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                TextField("e.g., !sig, //email, @reply", text: $shortcut)
                                    .textFieldStyle(.plain)
                                    .font(Font.Voxa.mono)
                                    .foregroundColor(Color.Voxa.textPrimary)
                                    .padding(Spacing.md)
                                    .background(Color.Voxa.surfaceSecondary)
                                    .cornerRadius(CornerRadius.small)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.small)
                                            .stroke(shortcutError != nil ? Color.Voxa.error : Color.Voxa.border, lineWidth: 1)
                                    )
                                    .focused($focusedField, equals: .shortcut)
                                    .onChange(of: shortcut) { _, newValue in
                                        validateShortcut(newValue)
                                    }
                                
                                if let error = shortcutError {
                                    Text(error)
                                        .font(Font.Voxa.small)
                                        .foregroundColor(Color.Voxa.error)
                                } else {
                                    Text("Type this shortcut text to quickly insert the snippet")
                                        .font(Font.Voxa.small)
                                        .foregroundColor(Color.Voxa.textTertiary)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .padding(Spacing.lg)
            }
            .background(Color.Voxa.background)
            
            Divider()
            
            // Footer with action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(VoxaButtonStyle(variant: .secondary))
                
                Spacer()
                
                Button("Create Snippet") {
                    let trimmedShortcut = shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(
                        title.trimmingCharacters(in: .whitespacesAndNewlines),
                        content.trimmingCharacters(in: .whitespacesAndNewlines),
                        trimmedShortcut.isEmpty ? nil : trimmedShortcut
                    )
                    dismiss()
                }
                .buttonStyle(VoxaButtonStyle(variant: .primary))
                .disabled(!isValid)
            }
            .padding(Spacing.lg)
            .background(Color.Voxa.surface)
        }
        .frame(width: 500, height: 550)
        .background(Color.Voxa.background)
        .onAppear {
            focusedField = .title
        }
    }
    
    private func validateShortcut(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            shortcutError = nil
        } else if SnippetsManager.shared.isShortcutInUse(trimmed) {
            shortcutError = "This shortcut is already in use"
        } else {
            shortcutError = nil
        }
    }
}

// MARK: - Edit Snippet Sheet

/// Sheet for editing an existing snippet
struct EditSnippetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let snippet: Snippet
    let onSave: (String, String, String?) -> Void
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var shortcut: String = ""
    @State private var showShortcutField = false
    @State private var shortcutError: String?
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case title, content, shortcut
    }
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        shortcutError == nil
    }
    
    private var hasChanges: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedShortcut = shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return trimmedTitle != snippet.title ||
               trimmedContent != snippet.content ||
               trimmedShortcut != (snippet.shortcut ?? "")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Snippet")
                    .font(Font.Voxa.title)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.Voxa.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Color.Voxa.surfaceSecondary)
                        .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(Spacing.lg)
            .background(Color.Voxa.surface)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Title field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Title")
                            .font(Font.Voxa.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Voxa.textSecondary)
                        
                        TextField("Enter snippet title...", text: $title)
                            .textFieldStyle(.plain)
                            .font(Font.Voxa.body)
                            .foregroundColor(Color.Voxa.textPrimary)
                            .padding(Spacing.md)
                            .background(Color.Voxa.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .stroke(Color.Voxa.border, lineWidth: 1)
                            )
                            .focused($focusedField, equals: .title)
                    }
                    
                    // Content field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Content")
                            .font(Font.Voxa.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Voxa.textSecondary)
                        
                        TextEditor(text: $content)
                            .font(Font.Voxa.body)
                            .foregroundColor(Color.Voxa.textPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(Spacing.sm)
                            .frame(minHeight: 150, maxHeight: 300)
                            .background(Color.Voxa.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .stroke(Color.Voxa.border, lineWidth: 1)
                            )
                            .focused($focusedField, equals: .content)
                    }
                    
                    // Shortcut field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Button(action: {
                            withAnimation(VoxaAnimation.quick) {
                                showShortcutField.toggle()
                            }
                        }) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: showShortcutField ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                Image(systemName: "keyboard")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Keyboard Shortcut")
                                    .font(Font.Voxa.body)
                                
                                if snippet.shortcut != nil && !snippet.shortcut!.isEmpty {
                                    Text("(\(snippet.shortcut!))")
                                        .font(Font.Voxa.mono)
                                        .foregroundColor(Color.Voxa.accent)
                                }
                            }
                            .foregroundColor(Color.Voxa.textSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if showShortcutField {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                TextField("e.g., !sig, //email, @reply", text: $shortcut)
                                    .textFieldStyle(.plain)
                                    .font(Font.Voxa.mono)
                                    .foregroundColor(Color.Voxa.textPrimary)
                                    .padding(Spacing.md)
                                    .background(Color.Voxa.surfaceSecondary)
                                    .cornerRadius(CornerRadius.small)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.small)
                                            .stroke(shortcutError != nil ? Color.Voxa.error : Color.Voxa.border, lineWidth: 1)
                                    )
                                    .focused($focusedField, equals: .shortcut)
                                    .onChange(of: shortcut) { _, newValue in
                                        validateShortcut(newValue)
                                    }
                                
                                if let error = shortcutError {
                                    Text(error)
                                        .font(Font.Voxa.small)
                                        .foregroundColor(Color.Voxa.error)
                                } else {
                                    Text("Leave empty to remove shortcut")
                                        .font(Font.Voxa.small)
                                        .foregroundColor(Color.Voxa.textTertiary)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Created: \(formatDate(snippet.createdAt))")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.textTertiary)
                        Text("Last updated: \(formatDate(snippet.updatedAt))")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.textTertiary)
                    }
                    .padding(.top, Spacing.md)
                }
                .padding(Spacing.lg)
            }
            .background(Color.Voxa.background)
            
            Divider()
            
            // Footer with action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(VoxaButtonStyle(variant: .secondary))
                
                Spacer()
                
                Button("Save Changes") {
                    let trimmedShortcut = shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(
                        title.trimmingCharacters(in: .whitespacesAndNewlines),
                        content.trimmingCharacters(in: .whitespacesAndNewlines),
                        trimmedShortcut.isEmpty ? "" : trimmedShortcut // Empty string to remove shortcut
                    )
                    dismiss()
                }
                .buttonStyle(VoxaButtonStyle(variant: .primary))
                .disabled(!isValid || !hasChanges)
            }
            .padding(Spacing.lg)
            .background(Color.Voxa.surface)
        }
        .frame(width: 500, height: 580)
        .background(Color.Voxa.background)
        .onAppear {
            // Initialize with existing values
            title = snippet.title
            content = snippet.content
            shortcut = snippet.shortcut ?? ""
            showShortcutField = snippet.shortcut != nil && !snippet.shortcut!.isEmpty
        }
    }
    
    private func validateShortcut(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            shortcutError = nil
        } else if SnippetsManager.shared.isShortcutInUse(trimmed, excludingSnippetId: snippet.id) {
            shortcutError = "This shortcut is already in use"
        } else {
            shortcutError = nil
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - US-636: Custom Dictionary View

/// Full custom dictionary view with create, edit, delete, search, and import/export
/// US-636: Manage custom words and phrases for better transcription accuracy
struct DictionaryContentView: View {
    @StateObject private var dictionaryManager = DictionaryManager.shared
    
    /// Search query for filtering entries
    @State private var searchQuery: String = ""
    
    /// Whether to show create entry sheet
    @State private var showCreateSheet = false
    
    /// Entry currently being edited (nil means no edit in progress)
    @State private var entryBeingEdited: DictionaryEntry?
    
    /// Entry pending deletion (for confirmation dialog)
    @State private var entryToDelete: DictionaryEntry?
    
    /// Whether to show delete confirmation dialog
    @State private var showDeleteConfirmation = false
    
    /// Whether to show import file picker
    @State private var showImportPicker = false
    
    /// Whether to show export save panel
    @State private var showExportPanel = false
    
    /// Import result message for toast
    @State private var importResultMessage: String?
    
    /// Whether to show import result
    @State private var showImportResult = false
    
    /// Filtered entries based on search query
    private var filteredEntries: [DictionaryEntry] {
        dictionaryManager.searchEntries(query: searchQuery)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header with search and actions
            dictionaryHeader
            
            Divider()
                .background(Color.Voxa.border)
            
            // MARK: - Content
            if dictionaryManager.isEmpty {
                // Empty state when no entries
                emptyDictionaryState
            } else if filteredEntries.isEmpty {
                // No results for search
                noSearchResultsState
            } else {
                // Dictionary list
                dictionaryList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Voxa.background)
        .sheet(isPresented: $showCreateSheet) {
            CreateDictionaryEntrySheet(onSave: { word, hint in
                dictionaryManager.createEntry(word: word, pronunciationHint: hint)
            })
        }
        .sheet(item: $entryBeingEdited) { entry in
            EditDictionaryEntrySheet(
                entry: entry,
                onSave: { word, hint in
                    dictionaryManager.updateEntry(id: entry.id, word: word, pronunciationHint: hint)
                }
            )
        }
        .alert("Delete Entry?", isPresented: $showDeleteConfirmation, presenting: entryToDelete) { entry in
            Button("Delete", role: .destructive) {
                withAnimation(VoxaAnimation.smooth) {
                    dictionaryManager.deleteEntry(entry)
                }
                entryToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                entryToDelete = nil
            }
        } message: { entry in
            Text("Are you sure you want to delete \"\(entry.word)\"? This action cannot be undone.")
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.plainText, .json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Import Complete", isPresented: $showImportResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importResultMessage ?? "Import completed.")
        }
    }
    
    // MARK: - Header
    
    private var dictionaryHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Custom Dictionary")
                    .font(Font.Voxa.largeTitle)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                Spacer()
                
                // Import/Export buttons
                HStack(spacing: Spacing.sm) {
                    // Import button
                    Button(action: {
                        showImportPicker = true
                    }) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 12, weight: .medium))
                            Text("Import")
                                .font(Font.Voxa.caption)
                        }
                        .foregroundColor(Color.Voxa.textSecondary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.Voxa.surfaceSecondary)
                        .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Import dictionary from file")
                    
                    // Export button
                    Button(action: {
                        exportDictionary()
                    }) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 12, weight: .medium))
                            Text("Export")
                                .font(Font.Voxa.caption)
                        }
                        .foregroundColor(Color.Voxa.textSecondary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.Voxa.surfaceSecondary)
                        .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(dictionaryManager.isEmpty)
                    .opacity(dictionaryManager.isEmpty ? 0.5 : 1.0)
                    .help("Export dictionary to file")
                }
                
                // Add new word button
                Button(action: {
                    showCreateSheet = true
                }) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Add Word")
                            .font(Font.Voxa.body)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.Voxa.accent)
                    .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(InteractiveScaleStyle())
                .disabled(dictionaryManager.isAtCapacity)
                .opacity(dictionaryManager.isAtCapacity ? 0.5 : 1.0)
                .help(dictionaryManager.isAtCapacity ? "Maximum entries reached" : "Add new word")
            }
            
            HStack(spacing: Spacing.md) {
                // Search bar
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.Voxa.textTertiary)
                    
                    TextField("Search dictionary...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(Font.Voxa.body)
                        .foregroundColor(Color.Voxa.textPrimary)
                    
                    if !searchQuery.isEmpty {
                        Button(action: {
                            withAnimation(VoxaAnimation.quick) {
                                searchQuery = ""
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.Voxa.textTertiary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.Voxa.surface)
                .cornerRadius(CornerRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .stroke(Color.Voxa.border, lineWidth: 1)
                )
                
                Spacer()
                
                // Word count and last updated info
                if !dictionaryManager.isEmpty {
                    HStack(spacing: Spacing.md) {
                        // Word count badge
                        Text("\(dictionaryManager.count) \(dictionaryManager.count == 1 ? "word" : "words")")
                            .font(Font.Voxa.caption)
                            .foregroundColor(Color.Voxa.textSecondary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(Color.Voxa.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                        
                        // Last updated info
                        if let lastUpdated = dictionaryManager.lastUpdated {
                            Text("Updated \(formatRelativeDate(lastUpdated))")
                                .font(Font.Voxa.small)
                                .foregroundColor(Color.Voxa.textTertiary)
                        }
                    }
                }
            }
        }
        .padding(Spacing.xl)
    }
    
    // MARK: - Empty State
    
    private var emptyDictionaryState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.Voxa.accentLight)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "character.book.closed")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(Color.Voxa.accent)
            }
            
            VStack(spacing: Spacing.sm) {
                Text("No custom words yet")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                Text("Add words and phrases to improve transcription accuracy.\nCustom words help Voxa recognize specialized terms,\nnames, and uncommon pronunciations.")
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Feature benefits explanation
            VStack(alignment: .leading, spacing: Spacing.sm) {
                DictionaryBenefitRow(icon: "textformat.abc", text: "Add technical terms and acronyms")
                DictionaryBenefitRow(icon: "person.fill", text: "Include names of people and places")
                DictionaryBenefitRow(icon: "waveform", text: "Add pronunciation hints for accuracy")
                DictionaryBenefitRow(icon: "square.and.arrow.down", text: "Import existing word lists")
            }
            .padding(Spacing.lg)
            .background(Color.Voxa.surface)
            .cornerRadius(CornerRadius.medium)
            .voxaShadow(.subtle)
            
            Button(action: {
                showCreateSheet = true
            }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text("Add First Word")
                        .fontWeight(.medium)
                }
                .font(Font.Voxa.body)
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(Color.Voxa.accent)
                .cornerRadius(CornerRadius.small)
            }
            .buttonStyle(InteractiveScaleStyle())
            .padding(.top, Spacing.md)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
    }
    
    // MARK: - No Search Results State
    
    private var noSearchResultsState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.Voxa.surfaceSecondary)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(Color.Voxa.textTertiary)
            }
            
            VStack(spacing: Spacing.sm) {
                Text("No words found")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                Text("No entries match \"\(searchQuery)\".\nTry a different search term.")
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                withAnimation(VoxaAnimation.quick) {
                    searchQuery = ""
                }
            }) {
                Text("Clear Search")
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.accent)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
    }
    
    // MARK: - Dictionary List
    
    private var dictionaryList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(filteredEntries) { entry in
                    DictionaryEntryRow(
                        entry: entry,
                        searchQuery: searchQuery,
                        onEdit: {
                            entryBeingEdited = entry
                        },
                        onDelete: {
                            entryToDelete = entry
                            showDeleteConfirmation = true
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
                }
            }
            .padding(Spacing.xl)
        }
        .animation(VoxaAnimation.smooth, value: filteredEntries.count)
    }
    
    // MARK: - Import/Export Helpers
    
    /// Handle file import result
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                // Start accessing security-scoped resource
                _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }
                
                let data = try Data(contentsOf: url)
                
                // Try JSON first, then text
                if url.pathExtension.lowercased() == "json" {
                    let count = dictionaryManager.importFromJSON(data)
                    importResultMessage = count > 0 ? "Imported \(count) new \(count == 1 ? "word" : "words")." : "No new words to import (all duplicates or invalid)."
                } else {
                    // Treat as plain text
                    if let text = String(data: data, encoding: .utf8) {
                        let count = dictionaryManager.importFromText(text)
                        importResultMessage = count > 0 ? "Imported \(count) new \(count == 1 ? "word" : "words")." : "No new words to import (all duplicates or invalid)."
                    } else {
                        importResultMessage = "Failed to read file as text."
                    }
                }
                showImportResult = true
            } catch {
                importResultMessage = "Failed to import: \(error.localizedDescription)"
                showImportResult = true
            }
            
        case .failure(let error):
            importResultMessage = "Failed to select file: \(error.localizedDescription)"
            showImportResult = true
        }
    }
    
    /// Export dictionary with save panel
    private func exportDictionary() {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Dictionary"
        savePanel.nameFieldStringValue = "voxa-dictionary.txt"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                let content = dictionaryManager.exportAsText()
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    print("DictionaryManager: [US-636] Exported dictionary to \(url.path)")
                } catch {
                    print("DictionaryManager: [US-636] Failed to export: \(error)")
                }
            }
        }
    }
    
    /// Format relative date for display
    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let entryDate = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        
        let daysDiff = calendar.dateComponents([.day], from: entryDate, to: today).day ?? 0
        
        switch daysDiff {
        case 0:
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "today at \(formatter.string(from: date))"
        case 1:
            return "yesterday"
        case 2...6:
            return "\(daysDiff) days ago"
        default:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

// MARK: - Dictionary Benefit Row

/// Row showing a benefit of using the custom dictionary
struct DictionaryBenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.Voxa.accent)
                .frame(width: 20)
            
            Text(text)
                .font(Font.Voxa.body)
                .foregroundColor(Color.Voxa.textSecondary)
        }
    }
}

// MARK: - Dictionary Entry Row Component

/// Individual dictionary entry row with edit and delete actions
struct DictionaryEntryRow: View {
    let entry: DictionaryEntry
    let searchQuery: String
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color.Voxa.accentLight)
                    .frame(width: 40, height: 40)
                
                Text(String(entry.word.prefix(1)).uppercased())
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.accent)
            }
            
            // Word and hint
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(highlightedText(entry.word))
                    .font(Font.Voxa.body)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                HStack(spacing: Spacing.sm) {
                    // Pronunciation hint badge
                    if let hint = entry.pronunciationHint, !hint.isEmpty {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "waveform")
                                .font(.system(size: 9, weight: .medium))
                            Text(highlightedText(hint))
                                .font(Font.Voxa.small)
                        }
                        .foregroundColor(Color.Voxa.accent)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Color.Voxa.accentLight)
                        .cornerRadius(CornerRadius.small)
                    }
                    
                    // Updated date
                    Text("Updated \(entry.updatedRelativeString)")
                        .font(Font.Voxa.small)
                        .foregroundColor(Color.Voxa.textTertiary)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: Spacing.xs) {
                // Edit button
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.Voxa.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Color.Voxa.surfaceSecondary)
                        .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Edit entry")
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.Voxa.error)
                        .frame(width: 28, height: 28)
                        .background(Color.Voxa.errorLight)
                        .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Delete entry")
            }
            .opacity(isHovered ? 1 : 0.5)
        }
        .padding(Spacing.md)
        .background(Color.Voxa.surface)
        .cornerRadius(CornerRadius.medium)
        .voxaShadow(isHovered ? .card : .subtle)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(VoxaAnimation.quick) {
                isHovered = hovering
            }
        }
    }
    
    /// Highlight search query matches in text
    private func highlightedText(_ text: String) -> AttributedString {
        guard !searchQuery.isEmpty else {
            return AttributedString(text)
        }
        
        var attributedString = AttributedString(text)
        let lowercasedText = text.lowercased()
        let lowercasedQuery = searchQuery.lowercased()
        
        var searchStartIndex = lowercasedText.startIndex
        while let range = lowercasedText.range(of: lowercasedQuery, range: searchStartIndex..<lowercasedText.endIndex) {
            let lowerBound = text.distance(from: text.startIndex, to: range.lowerBound)
            let upperBound = text.distance(from: text.startIndex, to: range.upperBound)
            
            if let attrRange = Range(NSRange(location: lowerBound, length: upperBound - lowerBound), in: attributedString) {
                attributedString[attrRange].backgroundColor = Color.Voxa.warningLight
                attributedString[attrRange].foregroundColor = Color.Voxa.textPrimary
            }
            
            searchStartIndex = range.upperBound
        }
        
        return attributedString
    }
}

// MARK: - Create Dictionary Entry Sheet

/// Sheet for creating a new dictionary entry
struct CreateDictionaryEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, String?) -> Void
    
    @State private var word: String = ""
    @State private var pronunciationHint: String = ""
    @State private var showHintField = false
    @State private var wordError: String?
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case word, hint
    }
    
    private var isValid: Bool {
        !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        wordError == nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Word")
                    .font(Font.Voxa.title)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.Voxa.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Color.Voxa.surfaceSecondary)
                        .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(Spacing.lg)
            .background(Color.Voxa.surface)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Word field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Word or Phrase")
                            .font(Font.Voxa.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Voxa.textSecondary)
                        
                        TextField("Enter word or phrase...", text: $word)
                            .textFieldStyle(.plain)
                            .font(Font.Voxa.body)
                            .foregroundColor(Color.Voxa.textPrimary)
                            .padding(Spacing.md)
                            .background(Color.Voxa.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .stroke(wordError != nil ? Color.Voxa.error : Color.Voxa.border, lineWidth: 1)
                            )
                            .focused($focusedField, equals: .word)
                            .onChange(of: word) { _, newValue in
                                validateWord(newValue)
                            }
                        
                        if let error = wordError {
                            Text(error)
                                .font(Font.Voxa.small)
                                .foregroundColor(Color.Voxa.error)
                        } else {
                            Text("Add technical terms, names, or uncommon words")
                                .font(Font.Voxa.small)
                                .foregroundColor(Color.Voxa.textTertiary)
                        }
                    }
                    
                    // Optional pronunciation hint field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Button(action: {
                            withAnimation(VoxaAnimation.quick) {
                                showHintField.toggle()
                            }
                        }) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: showHintField ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                Image(systemName: "waveform")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Add Pronunciation Hint (Optional)")
                                    .font(Font.Voxa.body)
                            }
                            .foregroundColor(Color.Voxa.textSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if showHintField {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                TextField("e.g., 'jif' for GIF, 'SEE-kwel' for SQL", text: $pronunciationHint)
                                    .textFieldStyle(.plain)
                                    .font(Font.Voxa.body)
                                    .foregroundColor(Color.Voxa.textPrimary)
                                    .padding(Spacing.md)
                                    .background(Color.Voxa.surfaceSecondary)
                                    .cornerRadius(CornerRadius.small)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.small)
                                            .stroke(Color.Voxa.border, lineWidth: 1)
                                    )
                                    .focused($focusedField, equals: .hint)
                                
                                Text("Helps the transcription engine recognize how you say this word")
                                    .font(Font.Voxa.small)
                                    .foregroundColor(Color.Voxa.textTertiary)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    
                    // Examples section
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Examples")
                            .font(Font.Voxa.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Voxa.textSecondary)
                        
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            DictionaryExampleRow(word: "Voxa", hint: "WISP-flow")
                            DictionaryExampleRow(word: "GitHub", hint: "git-hub")
                            DictionaryExampleRow(word: "Kubernetes", hint: "koo-ber-NET-eez")
                            DictionaryExampleRow(word: "Dr. Smith", hint: nil)
                        }
                        .padding(Spacing.md)
                        .background(Color.Voxa.surfaceSecondary)
                        .cornerRadius(CornerRadius.small)
                    }
                }
                .padding(Spacing.lg)
            }
            .background(Color.Voxa.background)
            
            Divider()
            
            // Footer with action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(VoxaButtonStyle(variant: .secondary))
                
                Spacer()
                
                Button("Add Word") {
                    let trimmedHint = pronunciationHint.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(
                        word.trimmingCharacters(in: .whitespacesAndNewlines),
                        trimmedHint.isEmpty ? nil : trimmedHint
                    )
                    dismiss()
                }
                .buttonStyle(VoxaButtonStyle(variant: .primary))
                .disabled(!isValid)
            }
            .padding(Spacing.lg)
            .background(Color.Voxa.surface)
        }
        .frame(width: 450, height: 480)
        .background(Color.Voxa.background)
        .onAppear {
            focusedField = .word
        }
    }
    
    private func validateWord(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            wordError = nil
        } else {
            // Check for duplicates using main actor Task
            Task { @MainActor in
                if DictionaryManager.shared.wordExists(trimmed) {
                    wordError = "This word already exists in your dictionary"
                } else {
                    wordError = nil
                }
            }
        }
    }
}

// MARK: - Edit Dictionary Entry Sheet

/// Sheet for editing an existing dictionary entry
struct EditDictionaryEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let entry: DictionaryEntry
    let onSave: (String, String?) -> Void
    
    @State private var word: String = ""
    @State private var pronunciationHint: String = ""
    @State private var showHintField = false
    @State private var wordError: String?
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case word, hint
    }
    
    private var isValid: Bool {
        !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        wordError == nil
    }
    
    private var hasChanges: Bool {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHint = pronunciationHint.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return trimmedWord != entry.word ||
               trimmedHint != (entry.pronunciationHint ?? "")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Word")
                    .font(Font.Voxa.title)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.Voxa.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Color.Voxa.surfaceSecondary)
                        .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(Spacing.lg)
            .background(Color.Voxa.surface)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Word field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Word or Phrase")
                            .font(Font.Voxa.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Voxa.textSecondary)
                        
                        TextField("Enter word or phrase...", text: $word)
                            .textFieldStyle(.plain)
                            .font(Font.Voxa.body)
                            .foregroundColor(Color.Voxa.textPrimary)
                            .padding(Spacing.md)
                            .background(Color.Voxa.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .stroke(wordError != nil ? Color.Voxa.error : Color.Voxa.border, lineWidth: 1)
                            )
                            .focused($focusedField, equals: .word)
                            .onChange(of: word) { _, newValue in
                                validateWord(newValue)
                            }
                        
                        if let error = wordError {
                            Text(error)
                                .font(Font.Voxa.small)
                                .foregroundColor(Color.Voxa.error)
                        }
                    }
                    
                    // Pronunciation hint field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Button(action: {
                            withAnimation(VoxaAnimation.quick) {
                                showHintField.toggle()
                            }
                        }) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: showHintField ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                Image(systemName: "waveform")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Pronunciation Hint")
                                    .font(Font.Voxa.body)
                                
                                if entry.pronunciationHint != nil && !entry.pronunciationHint!.isEmpty {
                                    Text("(\(entry.pronunciationHint!))")
                                        .font(Font.Voxa.small)
                                        .foregroundColor(Color.Voxa.accent)
                                }
                            }
                            .foregroundColor(Color.Voxa.textSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if showHintField {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                TextField("e.g., 'jif' for GIF, 'SEE-kwel' for SQL", text: $pronunciationHint)
                                    .textFieldStyle(.plain)
                                    .font(Font.Voxa.body)
                                    .foregroundColor(Color.Voxa.textPrimary)
                                    .padding(Spacing.md)
                                    .background(Color.Voxa.surfaceSecondary)
                                    .cornerRadius(CornerRadius.small)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.small)
                                            .stroke(Color.Voxa.border, lineWidth: 1)
                                    )
                                    .focused($focusedField, equals: .hint)
                                
                                Text("Leave empty to remove pronunciation hint")
                                    .font(Font.Voxa.small)
                                    .foregroundColor(Color.Voxa.textTertiary)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Added: \(formatDate(entry.createdAt))")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.textTertiary)
                        Text("Last updated: \(formatDate(entry.updatedAt))")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.textTertiary)
                    }
                    .padding(.top, Spacing.md)
                }
                .padding(Spacing.lg)
            }
            .background(Color.Voxa.background)
            
            Divider()
            
            // Footer with action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(VoxaButtonStyle(variant: .secondary))
                
                Spacer()
                
                Button("Save Changes") {
                    let trimmedHint = pronunciationHint.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(
                        word.trimmingCharacters(in: .whitespacesAndNewlines),
                        trimmedHint.isEmpty ? nil : trimmedHint
                    )
                    dismiss()
                }
                .buttonStyle(VoxaButtonStyle(variant: .primary))
                .disabled(!isValid || !hasChanges)
            }
            .padding(Spacing.lg)
            .background(Color.Voxa.surface)
        }
        .frame(width: 450, height: 420)
        .background(Color.Voxa.background)
        .onAppear {
            // Initialize with existing values
            word = entry.word
            pronunciationHint = entry.pronunciationHint ?? ""
            showHintField = entry.pronunciationHint != nil && !entry.pronunciationHint!.isEmpty
        }
    }
    
    private func validateWord(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentEntryId = entry.id
        let currentWord = entry.word
        if trimmed.isEmpty {
            wordError = nil
        } else if trimmed.lowercased() == currentWord.lowercased() {
            // Same word (case-insensitive), no duplicate
            wordError = nil
        } else {
            // Check for duplicates using main actor Task
            Task { @MainActor in
                if DictionaryManager.shared.wordExists(trimmed, excludingEntryId: currentEntryId) {
                    wordError = "This word already exists in your dictionary"
                } else {
                    wordError = nil
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Dictionary Example Row

/// Example row showing word and hint format
struct DictionaryExampleRow: View {
    let word: String
    let hint: String?
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(word)
                .font(Font.Voxa.body)
                .foregroundColor(Color.Voxa.textPrimary)
            
            if let hint = hint {
                Text("→")
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.textTertiary)
                
                Text(hint)
                    .font(Font.Voxa.mono)
                    .foregroundColor(Color.Voxa.accent)
            }
        }
    }
}

// MARK: - Settings Section Enum (US-709)

/// Section identifiers for settings navigation
/// US-709: Settings Section Navigation
enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "general"
    case audio = "audio"
    case transcription = "transcription"
    case modelManagement = "modelManagement"  // US-012
    case textCleanup = "textCleanup"
    case textInsertion = "textInsertion"
    case debug = "debug"

    var id: String { rawValue }

    /// Display name for the section
    var displayName: String {
        switch self {
        case .general:
            return "General"
        case .audio:
            return "Audio"
        case .transcription:
            return "Transcription"
        case .modelManagement:
            return "Model Management"
        case .textCleanup:
            return "Text Cleanup"
        case .textInsertion:
            return "Text Insertion"
        case .debug:
            return "Debug"
        }
    }

    /// SF Symbol icon for the section
    var icon: String {
        switch self {
        case .general:
            return "gear"
        case .audio:
            return "speaker.wave.2"
        case .transcription:
            return "waveform"
        case .modelManagement:
            return "internaldrive"
        case .textCleanup:
            return "text.badge.checkmark"
        case .textInsertion:
            return "doc.on.clipboard"
        case .debug:
            return "ladybug"
        }
    }

    /// Brief description of the section
    var description: String {
        switch self {
        case .general:
            return "App information, global hotkey, startup options, and permissions"
        case .audio:
            return "Input device selection, audio preview, and sensitivity settings"
        case .transcription:
            return "Whisper model selection and language preferences"
        case .modelManagement:
            return "Download, delete, and manage storage for Whisper models"
        case .textCleanup:
            return "AI-powered text cleanup and post-processing options"
        case .textInsertion:
            return "How transcribed text is inserted into your applications"
        case .debug:
            return "Debug tools, logging, and audio export options"
        }
    }
}

/// Settings content view that displays all settings in the main window content area
/// US-701: Create SettingsContentView for Main Window
/// US-709: Settings Section Navigation - Added section jump buttons and smooth scrolling
struct SettingsContentView: View {
    /// Currently active/visible section for highlighting navigation
    @State private var activeSection: SettingsSection = .general
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    // MARK: - Header with Navigation
                    settingsHeader
                    
                    // MARK: - Section Navigation Bar (US-709)
                    sectionNavigationBar(scrollProxy: scrollProxy)
                    
                    // MARK: - General Section
                    SettingsSectionView(
                        title: SettingsSection.general.displayName,
                        icon: SettingsSection.general.icon,
                        description: SettingsSection.general.description
                    ) {
                        GeneralSettingsSummary()
                    }
                    .id(SettingsSection.general)
                    
                    // MARK: - Audio Section
                    SettingsSectionView(
                        title: SettingsSection.audio.displayName,
                        icon: SettingsSection.audio.icon,
                        description: SettingsSection.audio.description
                    ) {
                        AudioSettingsSummary()
                    }
                    .id(SettingsSection.audio)
                    
                    // MARK: - Transcription Section
                    SettingsSectionView(
                        title: SettingsSection.transcription.displayName,
                        icon: SettingsSection.transcription.icon,
                        description: SettingsSection.transcription.description
                    ) {
                        TranscriptionSettingsSummary()
                    }
                    .id(SettingsSection.transcription)

                    // MARK: - Model Management Section (US-012)
                    SettingsSectionView(
                        title: SettingsSection.modelManagement.displayName,
                        icon: SettingsSection.modelManagement.icon,
                        description: SettingsSection.modelManagement.description
                    ) {
                        ModelManagementView()
                    }
                    .id(SettingsSection.modelManagement)

                    // MARK: - Text Cleanup Section
                    SettingsSectionView(
                        title: SettingsSection.textCleanup.displayName,
                        icon: SettingsSection.textCleanup.icon,
                        description: SettingsSection.textCleanup.description
                    ) {
                        TextCleanupSettingsSummary()
                    }
                    .id(SettingsSection.textCleanup)
                    
                    // MARK: - Text Insertion Section
                    SettingsSectionView(
                        title: SettingsSection.textInsertion.displayName,
                        icon: SettingsSection.textInsertion.icon,
                        description: SettingsSection.textInsertion.description
                    ) {
                        TextInsertionSettingsSummary()
                    }
                    .id(SettingsSection.textInsertion)
                    
                    // MARK: - Debug Section
                    SettingsSectionView(
                        title: SettingsSection.debug.displayName,
                        icon: SettingsSection.debug.icon,
                        description: SettingsSection.debug.description
                    ) {
                        DebugSettingsSummary()
                    }
                    .id(SettingsSection.debug)
                    
                    Spacer(minLength: Spacing.xxl)
                }
                .padding(Spacing.xl)
            }
            // US-805: Listen for scroll to text cleanup section notification
            .onReceive(NotificationCenter.default.publisher(for: .scrollToTextCleanupSection)) { _ in
                scrollToSection(.textCleanup, using: scrollProxy)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Voxa.background)
    }
    
    // MARK: - Header View
    
    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Settings")
                .font(Font.Voxa.largeTitle)
                .foregroundColor(Color.Voxa.textPrimary)
            
            Text("Configure Voxa preferences and options")
                .font(Font.Voxa.body)
                .foregroundColor(Color.Voxa.textSecondary)
        }
    }
    
    // MARK: - Section Navigation Bar (US-709)
    
    /// Navigation bar with section jump buttons
    /// US-709: Add section jump buttons at top of settings view
    private func sectionNavigationBar(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Jump to Section")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textTertiary)
            
            // Horizontal scrollable section buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(SettingsSection.allCases) { section in
                        SettingsSectionNavButton(
                            section: section,
                            isActive: activeSection == section,
                            onTap: {
                                scrollToSection(section, using: scrollProxy)
                            }
                        )
                    }
                }
                .padding(.horizontal, 1) // Prevent clipping of button shadows
            }
        }
        .padding(Spacing.md)
        .background(Color.Voxa.surface)
        .cornerRadius(CornerRadius.medium)
        .voxaShadow(.subtle)
    }
    
    // MARK: - Scroll to Section (US-709)
    
    /// Scrolls to the specified section with smooth animation
    /// US-709: Implement smooth scroll to section
    private func scrollToSection(_ section: SettingsSection, using proxy: ScrollViewProxy) {
        // Update active section for visual feedback
        withAnimation(VoxaAnimation.smooth) {
            activeSection = section
        }
        
        // Perform smooth scroll to section
        withAnimation(.easeInOut(duration: 0.4)) {
            proxy.scrollTo(section, anchor: .top)
        }
        
        print("[US-709] Scrolled to section: \(section.displayName)")
    }
}

// MARK: - Settings Section Nav Button (US-709)

/// Navigation button for quickly jumping to a settings section
/// US-709: Section navigation button component
struct SettingsSectionNavButton: View {
    let section: SettingsSection
    let isActive: Bool
    let onTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: section.icon)
                    .font(.system(size: 12, weight: .medium))
                
                Text(section.displayName)
                    .font(Font.Voxa.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isActive ? .white : (isHovering ? Color.Voxa.accent : Color.Voxa.textSecondary))
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(isActive ? Color.Voxa.accent : (isHovering ? Color.Voxa.accentLight : Color.Voxa.border.opacity(0.3)))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(VoxaAnimation.quick, value: isHovering)
        .animation(VoxaAnimation.quick, value: isActive)
        .onHover { hovering in
            isHovering = hovering
        }
        .help("Jump to \(section.displayName)")
    }
}

// MARK: - Settings Section View (US-701)

/// A reusable section container for settings groups
/// Applies consistent voxaCard() styling to each section
struct SettingsSectionView<Content: View>: View {
    let title: String
    let icon: String
    let description: String
    @ViewBuilder let content: () -> Content
    
    @State private var isExpanded: Bool = true
    @State private var isHovering: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            Button(action: {
                withAnimation(VoxaAnimation.quick) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: Spacing.md) {
                    // Section icon
                    ZStack {
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .fill(Color.Voxa.accentLight)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.Voxa.accent)
                    }
                    
                    // Title and description
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(title)
                            .font(Font.Voxa.headline)
                            .foregroundColor(Color.Voxa.textPrimary)
                        
                        Text(description)
                            .font(Font.Voxa.caption)
                            .foregroundColor(Color.Voxa.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Expand/collapse indicator
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Voxa.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(Spacing.lg)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .background(
                RoundedRectangle(cornerRadius: isExpanded ? CornerRadius.medium : CornerRadius.medium)
                    .fill(isHovering && !isExpanded ? Color.Voxa.border.opacity(0.3) : Color.clear)
            )
            .onHover { hovering in
                withAnimation(VoxaAnimation.quick) {
                    isHovering = hovering
                }
            }
            
            // Section Content (expandable)
            if isExpanded {
                Divider()
                    .background(Color.Voxa.border)
                    .padding(.horizontal, Spacing.lg)
                
                VStack(alignment: .leading, spacing: Spacing.md) {
                    content()
                }
                .padding(Spacing.lg)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.Voxa.surface)
        .cornerRadius(CornerRadius.medium)
        .voxaShadow(.subtle)
    }
}

// MARK: - General Settings Section (US-702)

/// Full General settings section migrated from SettingsWindow
/// US-702: Migrate General Settings Section to integrated settings view
struct GeneralSettingsSummary: View {
    @StateObject private var hotkeyManager = HotkeyManager.shared
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var isRecordingHotkey = false
    @State private var isRecordingStopHotkey = false  // US-015
    @State private var isRecordingCancelHotkey = false  // US-016
    @State private var isRecordingInsertHotkey = false  // US-017
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    
    /// Get the app version from the bundle
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.5"
    }
    
    /// Get the build number from the bundle
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            // MARK: - App Info Header (US-702 Task 1)
            appInfoHeader
            
            // MARK: - Link Buttons (US-702 Task 2)
            linkButtonsSection
            
            // MARK: - Global Hotkey Configuration (US-702 Task 3)
            hotkeySection
            
            // MARK: - Startup Options (US-702 Task 4)
            startupSection
            
            // MARK: - Permissions Section
            permissionsSection
        }
        .onAppear {
            // Refresh launch at login status
            launchAtLogin = SMAppService.mainApp.status == .enabled
            // Refresh permission status on appear
            permissionManager.refreshAllStatuses()
        }
    }
    
    // MARK: - App Info Header
    
    /// App info header with icon, version, and description
    private var appInfoHeader: some View {
        VStack(spacing: Spacing.md) {
            // Logo and branding
            VStack(spacing: Spacing.md) {
                // App Icon representation using SF Symbols
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.Voxa.accent.opacity(0.15), Color.Voxa.accent.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                    
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.Voxa.accent, Color.Voxa.accent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // App name
                Text("Voxa")
                    .font(Font.Voxa.title)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                // Version display
                Text("Version \(appVersion)")
                    .font(Font.Voxa.caption)
                    .foregroundColor(Color.Voxa.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.Voxa.border.opacity(0.5))
                    .cornerRadius(CornerRadius.small / 2)
            }
            
            // Tagline/Description
            Text("Voice-to-text dictation with AI-powered transcription and auto-editing. All processing happens locally on your device.")
                .font(Font.Voxa.body)
                .foregroundColor(Color.Voxa.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.md)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .background(Color.Voxa.border.opacity(0.2))
        .cornerRadius(CornerRadius.medium)
    }
    
    // MARK: - Link Buttons Section
    
    /// GitHub, Website, Support link buttons
    private var linkButtonsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Links")
                .font(Font.Voxa.headline)
                .foregroundColor(Color.Voxa.textPrimary)
            
            HStack(spacing: Spacing.md) {
                GeneralSettingsLinkButton(
                    title: "GitHub",
                    icon: "chevron.left.forwardslash.chevron.right",
                    url: "https://github.com"
                )
                
                GeneralSettingsLinkButton(
                    title: "Website",
                    icon: "globe",
                    url: "https://voxa.app"
                )
                
                GeneralSettingsLinkButton(
                    title: "Support",
                    icon: "questionmark.circle",
                    url: "https://voxa.app/support"
                )
            }
        }
    }
    
    // MARK: - Hotkey Section

    /// Global hotkey configuration with recording UI
    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "keyboard")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Global Hotkeys")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)

                Spacer()

                // US-022: Visual Hotkey Mode Indicator
                hotkeyModeIndicator
            }

            Text("Configure keyboard shortcuts for recording control from any app.")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)

            // Start Recording Hotkey
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Start Recording")
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.textPrimary)

                HStack(spacing: Spacing.md) {
                    GeneralSettingsHotkeyRecorder(
                        hotkeyManager: hotkeyManager,
                        isRecording: $isRecordingHotkey,
                        isForStopHotkey: false
                    )

                    Button(action: {
                        print("[US-702] Button action: Reset Start Hotkey to Default")
                        hotkeyManager.resetToDefault()
                    }) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset")
                        }
                    }
                    .buttonStyle(VoxaButtonStyle.secondary)
                    .disabled(hotkeyManager.configuration == .defaultHotkey)
                }
            }

            if isRecordingHotkey {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                    Text("Press your desired key combination...")
                        .font(Font.Voxa.caption)
                        .foregroundColor(Color.Voxa.accent)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // US-020: Push-to-Talk Mode Toggle
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Toggle("Push-to-talk mode", isOn: $hotkeyManager.pushToTalkEnabled)
                    .toggleStyle(VoxaToggleStyle())
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.textPrimary)

                Text("Hold hotkey to record, release to stop and transcribe.")
                    .font(Font.Voxa.caption)
                    .foregroundColor(Color.Voxa.textSecondary)

                if hotkeyManager.pushToTalkEnabled {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "hand.tap")
                            .foregroundColor(Color.Voxa.accent)
                            .font(.system(size: 12))
                        Text("Recording starts on press, stops on release")
                            .font(Font.Voxa.caption)
                            .foregroundColor(Color.Voxa.accent)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.Voxa.accent.opacity(0.1))
                    .cornerRadius(6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.top, Spacing.sm)
            .animation(.easeInOut(duration: 0.2), value: hotkeyManager.pushToTalkEnabled)

            Divider()
                .background(Color.Voxa.border)
                .padding(.vertical, Spacing.xs)

            // US-015: Stop Recording Hotkey (hidden when push-to-talk is enabled)
            if !hotkeyManager.pushToTalkEnabled {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Stop Recording")
                        .font(Font.Voxa.body)
                        .foregroundColor(Color.Voxa.textPrimary)

                    // Toggle for using same hotkey
                    Toggle("Use same hotkey (toggle behavior)", isOn: $hotkeyManager.useSameHotkeyForStop)
                        .toggleStyle(VoxaToggleStyle())
                        .font(Font.Voxa.caption)
                        .foregroundColor(Color.Voxa.textSecondary)

                    if !hotkeyManager.useSameHotkeyForStop {
                        HStack(spacing: Spacing.md) {
                            GeneralSettingsHotkeyRecorder(
                                hotkeyManager: hotkeyManager,
                                isRecording: $isRecordingStopHotkey,
                                isForStopHotkey: true
                            )

                            Button(action: {
                                print("[US-015] Button action: Reset Stop Hotkey to Default")
                                hotkeyManager.updateStopConfiguration(.defaultHotkey)
                            }) {
                                HStack(spacing: Spacing.xs) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Reset")
                                }
                            }
                            .buttonStyle(VoxaButtonStyle.secondary)
                            .disabled(hotkeyManager.stopConfiguration == .defaultHotkey)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if isRecordingStopHotkey {
                        HStack(spacing: Spacing.sm) {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                            Text("Press your desired key combination...")
                                .font(Font.Voxa.caption)
                                .foregroundColor(Color.Voxa.accent)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: hotkeyManager.useSameHotkeyForStop)

                Divider()
                    .background(Color.Voxa.border)
                    .padding(.vertical, Spacing.xs)
            }

            // US-016: Cancel Recording Hotkey
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Cancel Recording")
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.textPrimary)

                Text("Discards current recording without transcribing.")
                    .font(Font.Voxa.caption)
                    .foregroundColor(Color.Voxa.textSecondary)

                HStack(spacing: Spacing.md) {
                    GeneralSettingsCancelHotkeyRecorder(
                        hotkeyManager: hotkeyManager,
                        isRecording: $isRecordingCancelHotkey
                    )

                    Button(action: {
                        print("[US-016] Button action: Reset Cancel Hotkey to Default")
                        hotkeyManager.resetCancelToDefault()
                    }) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset")
                        }
                    }
                    .buttonStyle(VoxaButtonStyle.secondary)
                    .disabled(hotkeyManager.cancelConfiguration == .defaultCancelHotkey)
                }

                if isRecordingCancelHotkey {
                    HStack(spacing: Spacing.sm) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                        Text("Press your desired key or key combination...")
                            .font(Font.Voxa.caption)
                            .foregroundColor(Color.Voxa.accent)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isRecordingCancelHotkey)

            Divider()
                .background(Color.Voxa.border)
                .padding(.vertical, Spacing.xs)

            // US-017: Insert Last Transcription Hotkey
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Insert Last Transcription")
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.textPrimary)

                Text("Inserts your most recent transcription at the cursor position.")
                    .font(Font.Voxa.caption)
                    .foregroundColor(Color.Voxa.textSecondary)

                HStack(spacing: Spacing.md) {
                    GeneralSettingsInsertHotkeyRecorder(
                        hotkeyManager: hotkeyManager,
                        isRecording: $isRecordingInsertHotkey
                    )

                    Button(action: {
                        print("[US-017] Button action: Reset Insert Hotkey to Default")
                        hotkeyManager.resetInsertToDefault()
                    }) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset")
                        }
                    }
                    .buttonStyle(VoxaButtonStyle.secondary)
                    .disabled(hotkeyManager.insertConfiguration == .defaultInsertHotkey)
                }

                if isRecordingInsertHotkey {
                    HStack(spacing: Spacing.sm) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                        Text("Press your desired key combination...")
                            .font(Font.Voxa.caption)
                            .foregroundColor(Color.Voxa.accent)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isRecordingInsertHotkey)
        }
        .animation(.easeInOut(duration: 0.2), value: isRecordingHotkey)
        .animation(.easeInOut(duration: 0.2), value: isRecordingStopHotkey)
        .animation(.easeInOut(duration: 0.2), value: isRecordingCancelHotkey)
        .animation(.easeInOut(duration: 0.2), value: isRecordingInsertHotkey)
    }

    // MARK: - US-022: Hotkey Mode Indicator

    /// Visual indicator showing current hotkey mode (push-to-talk vs toggle)
    private var hotkeyModeIndicator: some View {
        let modeName: String
        let modeIcon: String

        if hotkeyManager.pushToTalkEnabled {
            modeName = "Push-to-Talk"
            modeIcon = "hand.tap"
        } else if hotkeyManager.useSameHotkeyForStop {
            modeName = "Toggle"
            modeIcon = "arrow.triangle.2.circlepath"
        } else {
            modeName = "Separate Keys"
            modeIcon = "rectangle.split.2x1"
        }

        return HStack(spacing: Spacing.xs) {
            Image(systemName: modeIcon)
                .font(.system(size: 10, weight: .medium))
            Text(modeName)
                .font(Font.Voxa.caption)
        }
        .foregroundColor(Color.Voxa.textSecondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(Color.Voxa.border.opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - Startup Section

    /// Launch at login toggle
    private var startupSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "power")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Startup")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Toggle("Launch Voxa at Login", isOn: $launchAtLogin)
                    .toggleStyle(VoxaToggleStyle())
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.textPrimary)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }
                
                Text("Automatically start Voxa when you log in to your Mac. Voxa runs quietly in the menu bar.")
                    .font(Font.Voxa.caption)
                    .foregroundColor(Color.Voxa.textSecondary)
                    .padding(.leading, Spacing.xxl + Spacing.md)
            }
        }
    }
    
    // MARK: - Permissions Section
    
    /// Permissions status display with grant buttons
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "lock.shield")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Permissions")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            Text("Voxa requires these permissions to function. Grant permissions to enable voice recording and text insertion.")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
            
            // Microphone Permission Status
            GeneralSettingsPermissionRow(
                title: "Microphone",
                description: "Required for voice recording",
                icon: "mic.fill",
                isGranted: permissionManager.microphoneStatus.isGranted,
                onGrantPermission: {
                    Task {
                        _ = await permissionManager.requestMicrophonePermission()
                    }
                }
            )
            
            Divider()
                .background(Color.Voxa.border)
            
            // Accessibility Permission Status
            GeneralSettingsPermissionRow(
                title: "Accessibility",
                description: "Required for global hotkeys and text insertion",
                icon: "hand.raised.fill",
                isGranted: permissionManager.accessibilityStatus.isGranted,
                onGrantPermission: {
                    _ = permissionManager.requestAccessibilityPermission()
                }
            )
        }
    }
    
    // MARK: - Helper Methods
    
    /// Set launch at login preference
    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                print("[US-702] Launch at login enabled")
            } else {
                try SMAppService.mainApp.unregister()
                print("[US-702] Launch at login disabled")
            }
        } catch {
            print("[US-702] Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            // Revert the toggle on failure
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - General Settings Link Button (US-702)

/// A styled link button for the General settings section
/// US-702: Add GitHub, Website, Support link buttons
struct GeneralSettingsLinkButton: View {
    let title: String
    let icon: String
    let url: String
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: {
            if let linkURL = URL(string: url) {
                NSWorkspace.shared.open(linkURL)
            }
        }) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(Font.Voxa.caption)
            }
            .foregroundColor(isHovering ? Color.Voxa.accent : Color.Voxa.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(isHovering ? Color.Voxa.accentLight : Color.Voxa.border.opacity(0.3))
            .cornerRadius(CornerRadius.small)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - General Settings Hotkey Recorder (US-702)

/// Hotkey recorder component for the General settings section
/// US-702: Include Global Hotkey configuration with recording UI
/// US-015: Support separate stop hotkey configuration
struct GeneralSettingsHotkeyRecorder: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @Binding var isRecording: Bool
    var isForStopHotkey: Bool = false  // US-015: Flag to indicate this recorder is for stop hotkey
    @State private var localEventMonitor: Any?
    @State private var isHovering = false
    @State private var pulseAnimation = false

    // Conflict detection state
    @State private var pendingConfig: HotkeyManager.HotkeyConfiguration?
    @State private var conflictingShortcuts: [HotkeyManager.SystemShortcut] = []
    @State private var showConflictWarning = false

    /// US-015: Display string based on whether this is for start or stop hotkey
    private var displayString: String {
        isForStopHotkey ? hotkeyManager.stopHotkeyDisplayString : hotkeyManager.hotkeyDisplayString
    }

    var body: some View {
        Button(action: {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }) {
            HStack(spacing: Spacing.sm) {
                if isRecording {
                    // Animated recording indicator
                    Circle()
                        .fill(Color.Voxa.accent)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                        .opacity(pulseAnimation ? 1.0 : 0.6)

                    Text("Recording...")
                        .font(Font.Voxa.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Voxa.accent)
                } else {
                    // Keyboard icon
                    Image(systemName: "command")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isHovering ? Color.Voxa.accent : Color.Voxa.textSecondary)

                    Text(displayString)
                        .font(Font.Voxa.mono)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Voxa.textPrimary)
                }
            }
            .frame(minWidth: 140)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(isRecording ? Color.Voxa.accentLight : (isHovering ? Color.Voxa.border.opacity(0.3) : Color.Voxa.surface))

                    if !isRecording {
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(Color.Voxa.border.opacity(0.5), lineWidth: 1)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        isRecording ? Color.Voxa.accent : (isHovering ? Color.Voxa.accent.opacity(0.5) : Color.Voxa.border),
                        lineWidth: isRecording ? 2 : 1
                    )
            )
            .shadow(
                color: isRecording ? Color.Voxa.accent.opacity(0.4) : (isHovering ? Color.Voxa.accent.opacity(0.15) : Color.clear),
                radius: isRecording ? 12 : 6,
                x: 0,
                y: 0
            )
            .scaleEffect(isRecording ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onDisappear {
            stopRecording()
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    pulseAnimation = false
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .alert("Shortcut Conflict", isPresented: $showConflictWarning, presenting: pendingConfig) { config in
            Button("Use Anyway", role: .destructive) {
                applyPendingConfig()
            }
            Button("Cancel", role: .cancel) {
                cancelPendingConfig()
            }
        } message: { config in
            let conflictDescriptions = conflictingShortcuts.map { "• \($0.name): \($0.description)" }.joined(separator: "\n")
            Text("\(config.displayString) conflicts with:\n\n\(conflictDescriptions)\n\nUsing this hotkey may prevent these system shortcuts from working.")
        }
    }

    private func startRecording() {
        isRecording = true

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown {
                handleKeyEvent(event)
                return nil
            }
            return event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let relevantFlags: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let modifiers = event.modifierFlags.intersection(relevantFlags)

        guard !modifiers.isEmpty else {
            let hotkeyType = isForStopHotkey ? "Stop" : "Start"
            print("[US-015] \(hotkeyType) hotkey must include at least one modifier")
            return
        }

        // Ignore Escape key (cancel)
        if event.keyCode == 53 {
            stopRecording()
            return
        }

        let newConfig = HotkeyManager.HotkeyConfiguration(
            keyCode: event.keyCode,
            modifierFlags: modifiers
        )

        let conflicts = HotkeyManager.checkForConflicts(newConfig)

        if !conflicts.isEmpty {
            pendingConfig = newConfig
            conflictingShortcuts = conflicts
            showConflictWarning = true
            stopRecording()
            print("[US-015] Conflict detected: \(conflicts.map { $0.name }.joined(separator: ", "))")
        } else {
            // US-015: Update appropriate configuration based on isForStopHotkey
            if isForStopHotkey {
                hotkeyManager.updateStopConfiguration(newConfig)
                print("[US-015] New stop hotkey set to \(newConfig.displayString)")
            } else {
                hotkeyManager.updateConfiguration(newConfig)
                print("[US-702] New start hotkey set to \(newConfig.displayString)")
            }
            stopRecording()
        }
    }

    private func applyPendingConfig() {
        guard let config = pendingConfig else { return }
        // US-015: Apply to appropriate configuration
        if isForStopHotkey {
            hotkeyManager.updateStopConfiguration(config)
            print("[US-015] User proceeded despite conflict, stop hotkey set to \(config.displayString)")
        } else {
            hotkeyManager.updateConfiguration(config)
            print("[US-702] User proceeded despite conflict, start hotkey set to \(config.displayString)")
        }
        pendingConfig = nil
        conflictingShortcuts = []
    }

    private func cancelPendingConfig() {
        let hotkeyType = isForStopHotkey ? "stop" : "start"
        print("[US-015] User cancelled conflicting \(hotkeyType) hotkey")
        pendingConfig = nil
        conflictingShortcuts = []
    }
}

// MARK: - General Settings Cancel Hotkey Recorder (US-016)

/// Cancel hotkey recorder component for the General settings section
/// US-016: Allows setting a cancel hotkey (can be single key like Escape or key with modifiers)
struct GeneralSettingsCancelHotkeyRecorder: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @Binding var isRecording: Bool
    @State private var localEventMonitor: Any?
    @State private var isHovering = false
    @State private var pulseAnimation = false

    // Conflict detection state
    @State private var pendingConfig: HotkeyManager.HotkeyConfiguration?
    @State private var conflictingShortcuts: [HotkeyManager.SystemShortcut] = []
    @State private var showConflictWarning = false

    /// Display string for the cancel hotkey
    private var displayString: String {
        hotkeyManager.cancelHotkeyDisplayString
    }

    var body: some View {
        Button(action: {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }) {
            HStack(spacing: Spacing.sm) {
                if isRecording {
                    // Animated recording indicator
                    Circle()
                        .fill(Color.Voxa.accent)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                        .opacity(pulseAnimation ? 1.0 : 0.6)

                    Text("Recording...")
                        .font(Font.Voxa.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Voxa.accent)
                } else {
                    // Keyboard icon
                    Image(systemName: "escape")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isHovering ? Color.Voxa.accent : Color.Voxa.textSecondary)

                    Text(displayString)
                        .font(Font.Voxa.mono)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Voxa.textPrimary)
                }
            }
            .frame(minWidth: 140)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(isRecording ? Color.Voxa.accentLight : (isHovering ? Color.Voxa.border.opacity(0.3) : Color.Voxa.surface))

                    if !isRecording {
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(Color.Voxa.border.opacity(0.5), lineWidth: 1)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        isRecording ? Color.Voxa.accent : (isHovering ? Color.Voxa.accent.opacity(0.5) : Color.Voxa.border),
                        lineWidth: isRecording ? 2 : 1
                    )
            )
            .shadow(
                color: isRecording ? Color.Voxa.accent.opacity(0.4) : (isHovering ? Color.Voxa.accent.opacity(0.15) : Color.clear),
                radius: isRecording ? 12 : 6,
                x: 0,
                y: 0
            )
            .scaleEffect(isRecording ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onDisappear {
            stopRecording()
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    pulseAnimation = false
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .alert("Shortcut Conflict", isPresented: $showConflictWarning, presenting: pendingConfig) { config in
            Button("Use Anyway", role: .destructive) {
                applyPendingConfig()
            }
            Button("Cancel", role: .cancel) {
                cancelPendingConfig()
            }
        } message: { config in
            let conflictDescriptions = conflictingShortcuts.map { "• \($0.name): \($0.description)" }.joined(separator: "\n")
            Text("\(config.displayString) conflicts with:\n\n\(conflictDescriptions)\n\nUsing this hotkey may prevent these system shortcuts from working.")
        }
    }

    private func startRecording() {
        isRecording = true

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown {
                handleKeyEvent(event)
                return nil
            }
            return event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let relevantFlags: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let modifiers = event.modifierFlags.intersection(relevantFlags)

        // US-016: Cancel hotkey allows keys without modifiers (like Escape)
        // Unlike start/stop hotkeys which require at least one modifier

        let newConfig = HotkeyManager.HotkeyConfiguration(
            keyCode: event.keyCode,
            modifierFlags: modifiers
        )

        let conflicts = HotkeyManager.checkForConflicts(newConfig)

        if !conflicts.isEmpty {
            pendingConfig = newConfig
            conflictingShortcuts = conflicts
            showConflictWarning = true
            stopRecording()
            print("[US-016] Conflict detected for cancel hotkey: \(conflicts.map { $0.name }.joined(separator: ", "))")
        } else {
            hotkeyManager.updateCancelConfiguration(newConfig)
            print("[US-016] New cancel hotkey set to \(newConfig.displayString)")
            stopRecording()
        }
    }

    private func applyPendingConfig() {
        guard let config = pendingConfig else { return }
        hotkeyManager.updateCancelConfiguration(config)
        print("[US-016] User proceeded despite conflict, cancel hotkey set to \(config.displayString)")
        pendingConfig = nil
        conflictingShortcuts = []
    }

    private func cancelPendingConfig() {
        print("[US-016] User cancelled conflicting cancel hotkey")
        pendingConfig = nil
        conflictingShortcuts = []
    }
}

// MARK: - General Settings Insert Hotkey Recorder (US-017)

/// Insert last transcription hotkey recorder component for the General settings section
/// US-017: Allows setting a hotkey to insert the most recent transcription at cursor
struct GeneralSettingsInsertHotkeyRecorder: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @Binding var isRecording: Bool
    @State private var localEventMonitor: Any?
    @State private var isHovering = false
    @State private var pulseAnimation = false

    // Conflict detection state
    @State private var pendingConfig: HotkeyManager.HotkeyConfiguration?
    @State private var conflictingShortcuts: [HotkeyManager.SystemShortcut] = []
    @State private var showConflictWarning = false

    /// Display string for the insert hotkey
    private var displayString: String {
        hotkeyManager.insertHotkeyDisplayString
    }

    var body: some View {
        Button(action: {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }) {
            HStack(spacing: Spacing.sm) {
                if isRecording {
                    // Animated recording indicator
                    Circle()
                        .fill(Color.Voxa.accent)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                        .opacity(pulseAnimation ? 1.0 : 0.6)

                    Text("Recording...")
                        .font(Font.Voxa.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Voxa.accent)
                } else {
                    // Keyboard icon (doc.on.clipboard for insert/paste action)
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isHovering ? Color.Voxa.accent : Color.Voxa.textSecondary)

                    Text(displayString)
                        .font(Font.Voxa.mono)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Voxa.textPrimary)
                }
            }
            .frame(minWidth: 140)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(isRecording ? Color.Voxa.accentLight : (isHovering ? Color.Voxa.border.opacity(0.3) : Color.Voxa.surface))

                    if !isRecording {
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(Color.Voxa.border.opacity(0.5), lineWidth: 1)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        isRecording ? Color.Voxa.accent : (isHovering ? Color.Voxa.accent.opacity(0.5) : Color.Voxa.border),
                        lineWidth: isRecording ? 2 : 1
                    )
            )
            .shadow(
                color: isRecording ? Color.Voxa.accent.opacity(0.4) : (isHovering ? Color.Voxa.accent.opacity(0.15) : Color.clear),
                radius: isRecording ? 12 : 6,
                x: 0,
                y: 0
            )
            .scaleEffect(isRecording ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onDisappear {
            stopRecording()
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    pulseAnimation = false
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .alert("Shortcut Conflict", isPresented: $showConflictWarning, presenting: pendingConfig) { config in
            Button("Use Anyway", role: .destructive) {
                applyPendingConfig()
            }
            Button("Cancel", role: .cancel) {
                cancelPendingConfig()
            }
        } message: { config in
            let conflictDescriptions = conflictingShortcuts.map { "• \($0.name): \($0.description)" }.joined(separator: "\n")
            Text("\(config.displayString) conflicts with:\n\n\(conflictDescriptions)\n\nUsing this hotkey may prevent these system shortcuts from working.")
        }
    }

    private func startRecording() {
        isRecording = true

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown {
                handleKeyEvent(event)
                return nil
            }
            return event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let relevantFlags: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let modifiers = event.modifierFlags.intersection(relevantFlags)

        // US-017: Insert hotkey requires at least one modifier
        guard !modifiers.isEmpty else {
            print("[US-017] Insert hotkey must include at least one modifier")
            return
        }

        // Ignore Escape key (cancel)
        if event.keyCode == 53 {
            stopRecording()
            return
        }

        let newConfig = HotkeyManager.HotkeyConfiguration(
            keyCode: event.keyCode,
            modifierFlags: modifiers
        )

        let conflicts = HotkeyManager.checkForConflicts(newConfig)

        if !conflicts.isEmpty {
            pendingConfig = newConfig
            conflictingShortcuts = conflicts
            showConflictWarning = true
            stopRecording()
            print("[US-017] Conflict detected for insert hotkey: \(conflicts.map { $0.name }.joined(separator: ", "))")
        } else {
            hotkeyManager.updateInsertConfiguration(newConfig)
            print("[US-017] New insert hotkey set to \(newConfig.displayString)")
            stopRecording()
        }
    }

    private func applyPendingConfig() {
        guard let config = pendingConfig else { return }
        hotkeyManager.updateInsertConfiguration(config)
        print("[US-017] User proceeded despite conflict, insert hotkey set to \(config.displayString)")
        pendingConfig = nil
        conflictingShortcuts = []
    }

    private func cancelPendingConfig() {
        print("[US-017] User cancelled conflicting insert hotkey")
        pendingConfig = nil
        conflictingShortcuts = []
    }
}

// MARK: - General Settings Permission Row (US-702)

/// Permission status row component for the General settings section
/// US-702: Display permission status with grant button
struct GeneralSettingsPermissionRow: View {
    let title: String
    let description: String
    let icon: String
    let isGranted: Bool
    let onGrantPermission: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Permission icon
            ZStack {
                Circle()
                    .fill(isGranted ? Color.Voxa.successLight : Color.Voxa.errorLight)
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isGranted ? Color.Voxa.success : Color.Voxa.error)
            }
            
            // Permission info
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text(title)
                        .font(Font.Voxa.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Voxa.textPrimary)
                    
                    // Status indicator
                    HStack(spacing: 4) {
                        Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(isGranted ? "Granted" : "Not Granted")
                            .font(Font.Voxa.small)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(isGranted ? Color.Voxa.success : Color.Voxa.error)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 2)
                    .background((isGranted ? Color.Voxa.success : Color.Voxa.error).opacity(0.12))
                    .cornerRadius(CornerRadius.small / 2)
                }
                
                Text(description)
                    .font(Font.Voxa.caption)
                    .foregroundColor(Color.Voxa.textSecondary)
            }
            
            Spacer()
            
            // Grant Permission button
            if !isGranted {
                Button(action: onGrantPermission) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "arrow.right.circle")
                        Text("Grant")
                    }
                }
                .buttonStyle(VoxaButtonStyle.primary)
            }
        }
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(isHovering ? Color.Voxa.border.opacity(0.2) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isGranted)
    }
}

// MARK: - Audio Settings Section (US-703)

/// Full Audio settings section migrated from SettingsWindow
/// US-703: Migrate Audio Settings Section to integrated settings view
struct AudioSettingsSummary: View {
    @StateObject private var audioManager = AudioManager.shared
    @State private var isPreviewingAudio = false
    @State private var previewTimer: Timer?
    @State private var currentLevel: Float = -60.0
    @State private var inputGain: Double = 1.0
    @State private var showResetCalibrationConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            // MARK: - Input Device Section (US-703 Task 1)
            inputDeviceSection
            
            // MARK: - Audio Preview Section (US-703 Task 2)
            audioPreviewSection
            
            // MARK: - Input Sensitivity Section (US-703 Task 3)
            inputSensitivitySection
            
            // MARK: - Calibration Section (US-703 Task 4)
            calibrationSection
        }
        .onDisappear {
            stopPreview()
        }
    }
    
    // MARK: - Input Device Section
    
    /// Audio input device picker with refresh button
    private var inputDeviceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "mic.fill")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Input Device")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                Spacer()
                
                // US-703 Task 5: Device Refresh Button
                Button(action: {
                    print("[US-703] Refreshing audio devices...")
                    audioManager.refreshAvailableDevices()
                }) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                        Text("Refresh")
                            .font(Font.Voxa.caption)
                    }
                    .foregroundColor(Color.Voxa.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.Voxa.border.opacity(0.3))
                    .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Refresh available audio devices")
            }
            
            Text("Select the microphone to use for voice recording. USB microphones are recommended for best accuracy.")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
            
            // Audio device picker dropdown (US-703 Task 1)
            AudioSettingsDevicePicker(
                devices: audioManager.inputDevices,
                selectedDevice: audioManager.currentDevice,
                onDeviceSelected: { device in
                    print("[US-703] Device selected: \(device.name)")
                    audioManager.selectDevice(device)
                },
                audioManager: audioManager
            )
        }
    }
    
    // MARK: - Audio Preview Section
    
    /// Real-time audio level meter and preview controls
    private var audioPreviewSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "waveform")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Audio Preview")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            Text("Test your microphone and see the input level in real-time.")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
            
            // Audio level meter display (US-703 Task 2)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Level meter header
                HStack {
                    Text("Input Level")
                        .font(Font.Voxa.body)
                        .foregroundColor(Color.Voxa.textSecondary)
                    
                    Spacer()
                    
                    // Level value and status
                    HStack(spacing: Spacing.sm) {
                        Text(String(format: "%.1f dB", currentLevel))
                            .font(Font.Voxa.mono)
                            .foregroundColor(levelColor(for: currentLevel))
                        
                        // Status badge
                        Text(levelStatus(for: currentLevel))
                            .font(Font.Voxa.small)
                            .fontWeight(.medium)
                            .foregroundColor(levelColor(for: currentLevel))
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(levelColor(for: currentLevel).opacity(0.12))
                            .cornerRadius(CornerRadius.small / 2)
                    }
                }
                
                // Visual audio level meter
                AudioSettingsLevelMeter(level: currentLevel, isActive: isPreviewingAudio)
                    .frame(height: 16)
                
                // Preview toggle button
                Button(action: togglePreview) {
                    HStack {
                        Image(systemName: isPreviewingAudio ? "stop.fill" : "play.fill")
                        Text(isPreviewingAudio ? "Stop Preview" : "Start Preview")
                    }
                }
                .buttonStyle(VoxaButtonStyle(variant: isPreviewingAudio ? .secondary : .primary))
                .padding(.top, Spacing.sm)
            }
            .padding(Spacing.lg)
            .background(Color.Voxa.surface)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(isPreviewingAudio ? Color.Voxa.accent : Color.Voxa.border, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Input Sensitivity Section
    
    /// Input sensitivity slider (US-703 Task 3)
    private var inputSensitivitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "dial.low")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Input Sensitivity")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            Text("Adjust the microphone sensitivity. Higher values pick up quieter sounds but may introduce background noise.")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
            
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Sensitivity")
                        .font(Font.Voxa.body)
                        .foregroundColor(Color.Voxa.textPrimary)
                    Spacer()
                    Text(String(format: "%.0f%%", inputGain * 100))
                        .font(Font.Voxa.mono)
                        .foregroundColor(Color.Voxa.accent)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.Voxa.accentLight)
                        .cornerRadius(CornerRadius.small / 2)
                }
                
                // Custom slider for input gain
                AudioSettingsSlider(value: $inputGain, range: 0.5...2.0)
                    .frame(height: 8)
                
                HStack {
                    Text("Low")
                        .font(Font.Voxa.small)
                        .foregroundColor(Color.Voxa.textSecondary)
                    Spacer()
                    Text("High")
                        .font(Font.Voxa.small)
                        .foregroundColor(Color.Voxa.textSecondary)
                }
                
                // Reset to default
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            inputGain = 1.0
                        }
                        print("[US-703] Input sensitivity reset to default")
                    }) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Default")
                        }
                    }
                    .buttonStyle(VoxaButtonStyle.ghost)
                    .disabled(inputGain == 1.0)
                }
            }
            .padding(Spacing.lg)
            .background(Color.Voxa.surface)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(Color.Voxa.border, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Calibration Section
    
    /// Audio level calibration controls (US-703 Task 4)
    private var calibrationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "tuningfork")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Audio Level Calibration")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            Text("Calibrate your microphone for optimal silence detection in your environment. This helps Voxa distinguish between ambient noise and speech.")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
            
            // Calibration status display
            AudioSettingsCalibrationStatus(audioManager: audioManager)
            
            // Calibration action buttons
            HStack(spacing: Spacing.md) {
                // Calibrate button
                Button(action: {
                    print("[US-703] Calibrate button tapped")
                    audioManager.startCalibration()
                }) {
                    HStack {
                        if case .calibrating = audioManager.calibrationState {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "tuningfork")
                        }
                        Text(calibrateButtonText)
                    }
                }
                .buttonStyle(VoxaButtonStyle.primary)
                .disabled(isCalibrationDisabled)
                
                // Cancel button (shown during calibration)
                if case .calibrating = audioManager.calibrationState {
                    Button(action: {
                        print("[US-703] Cancel calibration button tapped")
                        audioManager.cancelCalibration()
                    }) {
                        HStack {
                            Image(systemName: "xmark")
                            Text("Cancel")
                        }
                    }
                    .buttonStyle(VoxaButtonStyle.secondary)
                }
                
                Spacer()
                
                // Reset to defaults button (shown if device is calibrated)
                if audioManager.isCurrentDeviceCalibrated {
                    Button(action: {
                        print("[US-703] Reset to defaults button tapped")
                        showResetCalibrationConfirmation = true
                    }) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Defaults")
                        }
                    }
                    .buttonStyle(VoxaButtonStyle.ghost)
                    .disabled(isCalibrating)
                }
            }
        }
        .alert("Reset Calibration?", isPresented: $showResetCalibrationConfirmation) {
            Button("Reset", role: .destructive) {
                audioManager.resetCalibrationForCurrentDevice()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset the calibration for \(audioManager.currentDevice?.name ?? "this device") to the default threshold of \(String(format: "%.0f", AudioManager.silenceThreshold))dB.")
        }
    }
    
    // MARK: - Preview Control Methods
    
    private func togglePreview() {
        print("[US-703] togglePreview() called, isPreviewingAudio=\(isPreviewingAudio)")
        if isPreviewingAudio {
            stopPreview()
        } else {
            startPreview()
        }
    }
    
    private func startPreview() {
        print("[US-703] startPreview() called")
        audioManager.requestMicrophonePermission { granted in
            print("[US-703] Permission callback received, granted=\(granted)")
            DispatchQueue.main.async {
                guard granted else {
                    print("[US-703] Audio preview blocked: microphone permission denied")
                    self.isPreviewingAudio = false
                    self.currentLevel = -60.0
                    return
                }
                // Start audio capture for preview
                do {
                    print("[US-703] Starting audio capture...")
                    try self.audioManager.startCapturing()
                    self.isPreviewingAudio = true
                    print("[US-703] Audio capture started successfully")
                    
                    // Start timer to read audio level at 20fps
                    self.previewTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                        // Apply gain to the visual level display
                        let rawLevel = self.audioManager.currentAudioLevel
                        let adjustedLevel = rawLevel + Float(20 * log10(max(self.inputGain, 0.001)))
                        self.currentLevel = adjustedLevel
                    }
                    print("[US-703] Timer started for level updates")
                } catch {
                    print("[US-703] Failed to start audio preview: \(error)")
                    self.isPreviewingAudio = false
                    self.currentLevel = -60.0
                }
            }
        }
    }
    
    private func stopPreview() {
        previewTimer?.invalidate()
        previewTimer = nil
        audioManager.cancelCapturing()
        isPreviewingAudio = false
        currentLevel = -60.0
    }
    
    // MARK: - Helper Methods
    
    private func levelColor(for level: Float) -> Color {
        if level > -10 {
            return Color.Voxa.error // Clipping/too loud
        } else if level > -30 {
            return Color.Voxa.success // Good level
        } else if level > -50 {
            return Color.Voxa.warning // Quiet
        } else {
            return Color.Voxa.textSecondary // Very quiet/silent
        }
    }
    
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
    
    private var calibrateButtonText: String {
        switch audioManager.calibrationState {
        case .idle:
            return "Calibrate"
        case .calibrating:
            return "Calibrating..."
        case .completed:
            return "Recalibrate"
        case .failed:
            return "Retry Calibration"
        }
    }
    
    private var isCalibrationDisabled: Bool {
        if case .calibrating = audioManager.calibrationState {
            return true
        }
        return false
    }
    
    private var isCalibrating: Bool {
        if case .calibrating = audioManager.calibrationState {
            return true
        }
        return false
    }
}

// MARK: - Audio Settings Device Picker (US-703)

/// Elegant dropdown picker for audio input devices with device icons
/// US-703: Show audio input device picker dropdown in integrated settings
struct AudioSettingsDevicePicker: View {
    let devices: [AudioManager.AudioInputDevice]
    let selectedDevice: AudioManager.AudioInputDevice?
    let onDeviceSelected: (AudioManager.AudioInputDevice) -> Void
    var audioManager: AudioManager? = nil
    
    @State private var isExpanded = false
    @State private var isHovering = false
    
    /// Keywords that indicate low-quality devices for flagging
    private static let lowQualityKeywords = [
        "airpods", "airpod", "bluetooth", "beats", "headset", "hfp", "wireless"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Selected device display / dropdown trigger
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: Spacing.md) {
                    // Device icon
                    Image(systemName: deviceIcon(for: selectedDevice))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.Voxa.accent)
                        .frame(width: 24)
                    
                    // Device name
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Spacing.xs) {
                            Text(selectedDevice?.name ?? "No device selected")
                                .font(Font.Voxa.body)
                                .foregroundColor(Color.Voxa.textPrimary)
                            
                            // Warning icon for low-quality selected device
                            if let device = selectedDevice, isLowQualityDevice(device) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.Voxa.warning)
                                    .help(lowQualityWarningText(for: device))
                            }
                        }
                        
                        if let device = selectedDevice, device.isDefault {
                            Text("System Default")
                                .font(Font.Voxa.small)
                                .foregroundColor(Color.Voxa.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Dropdown indicator
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Voxa.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(Spacing.md)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(isHovering ? Color.Voxa.border.opacity(0.3) : Color.Voxa.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(isExpanded ? Color.Voxa.accent : Color.Voxa.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            
            // Dropdown list
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(devices) { device in
                        AudioSettingsDeviceRow(
                            device: device,
                            isSelected: device.uid == selectedDevice?.uid,
                            isLowQuality: isLowQualityDevice(device),
                            lowQualityReason: lowQualityWarningText(for: device),
                            onSelect: {
                                onDeviceSelected(device)
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    isExpanded = false
                                }
                            }
                        )
                    }
                }
                .background(Color.Voxa.surface)
                .cornerRadius(CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.Voxa.border, lineWidth: 1)
                )
                .voxaShadow(.card)
                .padding(.top, Spacing.xs)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }
    
    private func deviceIcon(for device: AudioManager.AudioInputDevice?) -> String {
        guard let device = device else { return "mic.slash" }
        let name = device.name.lowercased()
        
        if name.contains("airpod") {
            return "airpodspro"
        } else if name.contains("bluetooth") || name.contains("wireless") {
            return "wave.3.right"
        } else if name.contains("usb") {
            return "cable.connector"
        } else if name.contains("built-in") || name.contains("macbook") || name.contains("internal") {
            return "laptopcomputer"
        } else if name.contains("headphone") || name.contains("headset") {
            return "headphones"
        } else {
            return "mic"
        }
    }
    
    /// Check if a device is flagged as low quality
    private func isLowQualityDevice(_ device: AudioManager.AudioInputDevice) -> Bool {
        if let manager = audioManager {
            return manager.isLowQualityDevice(device)
        }
        let nameLower = device.name.lowercased()
        return Self.lowQualityKeywords.contains { keyword in
            nameLower.contains(keyword)
        }
    }
    
    /// Generate tooltip text explaining why device may have poor quality
    private func lowQualityWarningText(for device: AudioManager.AudioInputDevice) -> String {
        let nameLower = device.name.lowercased()
        
        if nameLower.contains("airpod") || nameLower.contains("airpods") {
            return "AirPods use Bluetooth compression which may reduce transcription accuracy. Consider using a built-in or USB microphone for better results."
        } else if nameLower.contains("beats") {
            return "Beats headphones use Bluetooth compression which may reduce transcription accuracy. Consider using a built-in or USB microphone for better results."
        } else if nameLower.contains("hfp") {
            return "This device uses the Hands-Free Profile (HFP) which limits audio quality. Consider using a different microphone for better results."
        } else if nameLower.contains("headset") {
            return "Headset microphones may have limited audio quality. Consider using a built-in or USB microphone for better transcription accuracy."
        } else if nameLower.contains("bluetooth") || nameLower.contains("wireless") {
            return "Bluetooth audio devices may have reduced quality due to compression. Consider using a built-in or USB microphone for better transcription accuracy."
        }
        
        return "This device may have reduced audio quality for voice transcription."
    }
}

// MARK: - Audio Settings Device Row (US-703)

/// Single row in the audio device picker dropdown
struct AudioSettingsDeviceRow: View {
    let device: AudioManager.AudioInputDevice
    let isSelected: Bool
    var isLowQuality: Bool = false
    var lowQualityReason: String = ""
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                // Device icon
                Image(systemName: deviceIcon(for: device))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? Color.Voxa.accent : Color.Voxa.textSecondary)
                    .frame(width: 20)
                
                // Device name
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(device.name)
                            .font(Font.Voxa.body)
                            .foregroundColor(isSelected ? Color.Voxa.accent : Color.Voxa.textPrimary)
                        
                        // Warning icon for low-quality devices
                        if isLowQuality {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.Voxa.warning)
                                .help(lowQualityReason)
                        }
                    }
                    
                    if device.isDefault {
                        Text("System Default")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.textSecondary)
                    } else if isLowQuality {
                        Text("May reduce transcription accuracy")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.warning)
                    }
                }
                
                Spacer()
                
                // Selected checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Voxa.accent)
                }
            }
            .padding(Spacing.md)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(isHovering ? Color.Voxa.accentLight : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
    
    private func deviceIcon(for device: AudioManager.AudioInputDevice) -> String {
        let name = device.name.lowercased()
        
        if name.contains("airpod") {
            return "airpodspro"
        } else if name.contains("bluetooth") || name.contains("wireless") {
            return "wave.3.right"
        } else if name.contains("usb") {
            return "cable.connector"
        } else if name.contains("built-in") || name.contains("macbook") || name.contains("internal") {
            return "laptopcomputer"
        } else if name.contains("headphone") || name.contains("headset") {
            return "headphones"
        } else {
            return "mic"
        }
    }
}

// MARK: - Audio Settings Level Meter (US-703)

/// Visual audio level meter with smooth animation
struct AudioSettingsLevelMeter: View {
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

// MARK: - Audio Settings Slider (US-703)

/// Custom styled slider for input sensitivity
struct AudioSettingsSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let thumbPosition = width * CGFloat(normalizedValue)
            
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.Voxa.border)
                    .frame(height: 8)
                
                // Filled track
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [Color.Voxa.accent.opacity(0.7), Color.Voxa.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, thumbPosition), height: 8)
                
                // Thumb
                Circle()
                    .fill(Color.Voxa.surface)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.Voxa.accent, lineWidth: 2)
                    )
                    .shadow(color: Color.Voxa.accent.opacity(isDragging ? 0.4 : 0.2), radius: isDragging ? 8 : 4)
                    .scaleEffect(isDragging ? 1.1 : 1.0)
                    .offset(x: thumbPosition - 10)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * Double(gesture.location.x / width)
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDragging)
        }
    }
}

// MARK: - Audio Settings Calibration Status (US-703)

/// Display calibration status and progress
struct AudioSettingsCalibrationStatus: View {
    @ObservedObject var audioManager: AudioManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            switch audioManager.calibrationState {
            case .idle:
                // Show current calibration status or default
                if let calibration = audioManager.getCalibrationForCurrentDevice() {
                    AudioSettingsCalibrationResult(calibration: calibration)
                } else {
                    AudioSettingsDefaultThreshold()
                }
                
            case .calibrating(let progress):
                AudioSettingsCalibrationProgress(progress: progress)
                
            case .completed(let ambientLevel):
                AudioSettingsCalibrationCompleted(ambientLevel: ambientLevel, calibration: audioManager.getCalibrationForCurrentDevice())
                
            case .failed(let message):
                AudioSettingsCalibrationFailed(message: message)
            }
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

// MARK: - Audio Settings Calibration Result (US-703)

/// Shows the current calibration result
struct AudioSettingsCalibrationResult: View {
    let calibration: AudioManager.DeviceCalibration
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Status icon
            ZStack {
                Circle()
                    .fill(Color.Voxa.successLight)
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.Voxa.success)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text("Calibrated")
                        .font(Font.Voxa.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Voxa.textPrimary)
                    
                    // Status badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.Voxa.success)
                            .frame(width: 6, height: 6)
                        Text("Active")
                            .font(Font.Voxa.small)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(Color.Voxa.success)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 2)
                    .background(Color.Voxa.success.opacity(0.12))
                    .cornerRadius(CornerRadius.small / 2)
                }
                
                HStack(spacing: Spacing.md) {
                    AudioSettingsMetric(label: "Ambient", value: String(format: "%.1f dB", calibration.ambientNoiseLevel))
                    AudioSettingsMetric(label: "Threshold", value: String(format: "%.1f dB", calibration.silenceThreshold))
                }
                
                // Calibration date
                Text("Last calibrated: \(formattedDate(calibration.calibrationDate))")
                    .font(Font.Voxa.small)
                    .foregroundColor(Color.Voxa.textSecondary)
            }
            
            Spacer()
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Audio Settings Default Threshold (US-703)

/// Shows the default threshold when not calibrated
struct AudioSettingsDefaultThreshold: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Status icon
            ZStack {
                Circle()
                    .fill(Color.Voxa.border.opacity(0.3))
                    .frame(width: 36, height: 36)
                Image(systemName: "circle.dashed")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.Voxa.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text("Not Calibrated")
                        .font(Font.Voxa.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Voxa.textPrimary)
                    
                    // Status badge
                    Text("Using Default")
                        .font(Font.Voxa.small)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Voxa.textSecondary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Color.Voxa.border.opacity(0.3))
                        .cornerRadius(CornerRadius.small / 2)
                }
                
                AudioSettingsMetric(label: "Default Threshold", value: String(format: "%.0f dB", AudioManager.silenceThreshold))
                
                Text("Calibrate to optimize for your environment")
                    .font(Font.Voxa.small)
                    .foregroundColor(Color.Voxa.textSecondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Audio Settings Calibration Progress (US-703)

/// Shows calibration progress
struct AudioSettingsCalibrationProgress: View {
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                // Animated mic icon
                ZStack {
                    Circle()
                        .fill(Color.Voxa.accentLight)
                        .frame(width: 36, height: 36)
                    Image(systemName: "waveform")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.Voxa.accent)
                }
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Measuring ambient noise...")
                        .font(Font.Voxa.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Voxa.textPrimary)
                    
                    Text("Please remain quiet for 3 seconds")
                        .font(Font.Voxa.caption)
                        .foregroundColor(Color.Voxa.textSecondary)
                }
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(Font.Voxa.mono)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.Voxa.accent)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.Voxa.border)
                    
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [Color.Voxa.accent.opacity(0.7), Color.Voxa.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geometry.size.width * CGFloat(progress)))
                        .animation(.easeOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Audio Settings Calibration Completed (US-703)

/// Shows calibration completed state
struct AudioSettingsCalibrationCompleted: View {
    let ambientLevel: Float
    let calibration: AudioManager.DeviceCalibration?
    
    @State private var showCheckmark = false
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Success icon with animation
            ZStack {
                Circle()
                    .fill(Color.Voxa.successLight)
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.Voxa.success)
                    .scaleEffect(showCheckmark ? 1.0 : 0.5)
                    .opacity(showCheckmark ? 1.0 : 0.0)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text("Calibration Complete!")
                        .font(Font.Voxa.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Voxa.success)
                }
                
                if let cal = calibration {
                    HStack(spacing: Spacing.md) {
                        AudioSettingsMetric(label: "Ambient", value: String(format: "%.1f dB", cal.ambientNoiseLevel))
                        AudioSettingsMetric(label: "New Threshold", value: String(format: "%.1f dB", cal.silenceThreshold))
                    }
                }
            }
            
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showCheckmark = true
            }
        }
    }
}

// MARK: - Audio Settings Calibration Failed (US-703)

/// Shows calibration failed state
struct AudioSettingsCalibrationFailed: View {
    let message: String
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Error icon
            ZStack {
                Circle()
                    .fill(Color.Voxa.errorLight)
                    .frame(width: 36, height: 36)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.Voxa.error)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Calibration Failed")
                    .font(Font.Voxa.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color.Voxa.error)
                
                Text(message)
                    .font(Font.Voxa.caption)
                    .foregroundColor(Color.Voxa.textSecondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Audio Settings Metric (US-703)

/// Small metric display for calibration values
struct AudioSettingsMetric: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(label + ":")
                .font(Font.Voxa.small)
                .foregroundColor(Color.Voxa.textSecondary)
            Text(value)
                .font(Font.Voxa.mono)
                .fontWeight(.medium)
                .foregroundColor(Color.Voxa.accent)
        }
    }
}

// MARK: - Transcription Settings Summary (US-704)

/// Full Transcription settings section migrated from SettingsWindow
/// US-704: Migrate Transcription Settings Section to integrated settings view
struct TranscriptionSettingsSummary: View {
    @StateObject private var whisperManager = WhisperManager.shared
    /// US-013: Device capability manager for model recommendations
    @StateObject private var deviceCapabilityManager = DeviceCapabilityManager.shared

    /// Loading state for model operations
    @State private var isLoadingModel = false
    
    /// Show delete confirmation dialog
    @State private var showDeleteConfirmation = false
    
    /// Model selected for deletion
    @State private var modelToDelete: WhisperManager.ModelSize?
    
    /// Show error alert
    @State private var showErrorAlert = false
    
    /// Expanded language picker state
    @State private var isLanguagePickerExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            // MARK: - Model Selection Section
            modelSelectionSection
            
            // MARK: - Model Actions Section (Download/Load)
            modelActionsSection
            
            // MARK: - Language Selection Section
            languageSelectionSection
            
            // MARK: - Quality/Speed Tradeoff Info
            tradeoffInfoSection
        }
        .alert("Delete Model?", isPresented: $showDeleteConfirmation, presenting: modelToDelete) { model in
            Button("Delete", role: .destructive) {
                Task {
                    await whisperManager.deleteModel(model)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { model in
            Text("Are you sure you want to delete the \(model.displayName.components(separatedBy: " (").first ?? model.rawValue.capitalized) model? You can re-download it later.")
        }
        .alert("Download Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let errorMessage = whisperManager.lastErrorMessage {
                Text(errorMessage)
            } else {
                Text(whisperManager.statusMessage)
            }
        }
    }
    
    // MARK: - Model Selection Section
    
    /// Whisper model size picker with card-based selection
    /// US-704 Task 1: Show Whisper model size picker
    private var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "cpu")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Whisper Model")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            Text("Select a model size. Larger models are more accurate but slower and use more memory.")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
            
            // Card-based model picker (US-704)
            VStack(spacing: Spacing.sm) {
                ForEach(WhisperManager.ModelSize.allCases) { model in
                    TranscriptionModelCard(
                        model: model,
                        isSelected: whisperManager.selectedModel == model,
                        isDownloaded: whisperManager.isModelDownloaded(model),
                        isActive: model == whisperManager.selectedModel && whisperManager.modelStatus == .ready,
                        // US-008: Show switching indicator when this model is being hot-swapped to
                        isSwitchingTo: whisperManager.pendingModel == model,
                        // US-013: Show recommended badge for optimal model
                        isRecommended: deviceCapabilityManager.isModelRecommended(model),
                        onSelect: {
                            Task {
                                print("[US-704] Model selected: \(model.rawValue)")
                                await whisperManager.selectModel(model)
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Model Actions Section
    
    /// Download/Load/Delete model actions with progress display
    /// US-704 Task 2: Display model download progress
    private var modelActionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Model Actions")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            // Status message
            Text(whisperManager.statusMessage)
                .font(Font.Voxa.body)
                .foregroundColor(Color.Voxa.textSecondary)
            
            // Download progress bar (US-704 Task 2, US-010: Cancel support)
            if case .downloading(let progress) = whisperManager.modelStatus {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    // Progress percentage header
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(Color.Voxa.accent)
                            .font(.system(size: 14, weight: .medium))
                        Text("Downloading \(whisperManager.selectedModel.displayName.components(separatedBy: " (").first ?? "model")...")
                            .font(Font.Voxa.body)
                            .foregroundColor(Color.Voxa.textPrimary)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(Font.Voxa.mono)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.Voxa.accent)
                    }

                    // Gradient progress bar
                    TranscriptionProgressBar(progress: progress)
                        .frame(height: 10)

                    // Status message
                    Text("Please wait, this may take a few minutes...")
                        .font(Font.Voxa.small)
                        .foregroundColor(Color.Voxa.textSecondary)

                    // US-010: Cancel download button
                    Button(action: {
                        whisperManager.cancelDownload()
                    }) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "xmark.circle")
                            Text("Cancel Download")
                        }
                        .font(Font.Voxa.small)
                    }
                    .buttonStyle(VoxaButtonStyle.ghost)
                }
                .padding(Spacing.md)
                .background(Color.Voxa.accentLight.opacity(0.5))
                .cornerRadius(CornerRadius.small)
            }

            // US-008: Hot-swap progress indicator
            if case .switching(let toModel, let progress) = whisperManager.modelStatus {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    // Header with switch icon
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(Color.Voxa.accent)
                            .font(.system(size: 14, weight: .medium))
                        Text("Switching to \(toModel.components(separatedBy: " (").first ?? "model")...")
                            .font(Font.Voxa.body)
                            .foregroundColor(Color.Voxa.textPrimary)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(Font.Voxa.mono)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.Voxa.accent)
                    }

                    // Progress bar
                    TranscriptionProgressBar(progress: progress)
                        .frame(height: 10)

                    // Status message showing current model remains active
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.Voxa.success)
                            .font(.system(size: 12))
                        Text("Current model (\(whisperManager.selectedModel.displayName.components(separatedBy: " (").first ?? "model")) remains active during switch")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.textSecondary)
                    }

                    // Cancel button
                    Button(action: {
                        whisperManager.cancelModelSwitch()
                    }) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "xmark.circle")
                            Text("Cancel Switch")
                        }
                        .font(Font.Voxa.small)
                    }
                    .buttonStyle(VoxaButtonStyle.ghost)
                }
                .padding(Spacing.md)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.Voxa.accentLight.opacity(0.3),
                            Color.Voxa.accent.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(CornerRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .stroke(Color.Voxa.accent.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Action buttons
            HStack(spacing: Spacing.md) {
                // Load/Download button
                Button(action: {
                    Task {
                        isLoadingModel = true
                        print("[US-704] Load/Download button tapped for model: \(whisperManager.selectedModel.rawValue)")
                        await whisperManager.loadModel()
                        isLoadingModel = false
                        if case .error = whisperManager.modelStatus {
                            showErrorAlert = true
                        }
                    }
                }) {
                    HStack {
                        if isLoadingModel && whisperManager.modelStatus != .downloading(progress: 0) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: buttonIconName)
                        }
                        Text(buttonTitle)
                    }
                }
                // US-008: Also disable during model switching
                .disabled(isLoadingModel || whisperManager.modelStatus == .ready || whisperManager.isModelSwitchInProgress)
                .buttonStyle(VoxaButtonStyle.primary)
                
                // Retry button (shown when there's an error)
                if case .error = whisperManager.modelStatus {
                    Button(action: {
                        Task {
                            isLoadingModel = true
                            print("[US-704] Retry button tapped")
                            await whisperManager.retryLoadModel()
                            isLoadingModel = false
                            if case .error = whisperManager.modelStatus {
                                showErrorAlert = true
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                    }
                    .disabled(isLoadingModel)
                    .buttonStyle(VoxaButtonStyle.secondary)
                    
                    Button(action: {
                        showErrorAlert = true
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                            Text("Details")
                        }
                    }
                    .buttonStyle(VoxaButtonStyle.ghost)
                }
                
                // Delete button (if model is downloaded)
                if whisperManager.isModelDownloaded(whisperManager.selectedModel) && whisperManager.modelStatus != .downloading(progress: 0) {
                    Button(action: {
                        modelToDelete = whisperManager.selectedModel
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                    }
                    .disabled(isLoadingModel)
                    .buttonStyle(VoxaButtonStyle.secondary)
                }
            }
        }
    }
    
    // MARK: - Language Selection Section
    
    /// Language selection dropdown
    /// US-704 Task 3: Include language selection dropdown
    private var languageSelectionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "globe")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Transcription Language")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            Text("Select the language for speech recognition. Auto-detect works best for most cases.")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
            
            // Language picker dropdown
            TranscriptionLanguagePicker(
                selectedLanguage: $whisperManager.selectedLanguage,
                isExpanded: $isLanguagePickerExpanded
            )
        }
    }
    
    // MARK: - Quality/Speed Tradeoff Section
    
    /// Information about model quality vs speed tradeoffs
    /// US-704 Task 4: Show quality/speed tradeoff info
    private var tradeoffInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "info.circle")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Quality vs Speed")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: Spacing.sm) {
                TranscriptionTradeoffRow(
                    icon: "hare",
                    title: "Tiny & Base",
                    description: "Fastest transcription, good for quick notes and casual use",
                    highlight: whisperManager.selectedModel == .tiny || whisperManager.selectedModel == .base
                )
                
                TranscriptionTradeoffRow(
                    icon: "gauge.with.dots.needle.50percent",
                    title: "Small",
                    description: "Balanced speed and accuracy, recommended for general use",
                    highlight: whisperManager.selectedModel == .small
                )
                
                TranscriptionTradeoffRow(
                    icon: "gauge.with.dots.needle.67percent",
                    title: "Medium",
                    description: "Best accuracy, slower processing, ideal for important content",
                    highlight: whisperManager.selectedModel == .medium
                )
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
    
    // MARK: - Helper Properties
    
    private var buttonTitle: String {
        switch whisperManager.modelStatus {
        case .ready:
            return "Model Loaded"
        case .loading:
            return "Loading..."
        case .downloading:
            return "Downloading..."
        case .switching:
            // US-008: Show switching status
            return "Switching..."
        case .notDownloaded:
            return whisperManager.isModelDownloaded(whisperManager.selectedModel) ? "Load Model" : "Download & Load"
        case .downloaded:
            return "Load Model"
        case .error:
            return "Retry"
        }
    }

    private var buttonIconName: String {
        switch whisperManager.modelStatus {
        case .ready:
            return "checkmark.circle"
        case .loading, .downloading:
            return "arrow.clockwise"
        case .switching:
            // US-008: Show switching icon
            return "arrow.triangle.2.circlepath"
        case .notDownloaded:
            return whisperManager.isModelDownloaded(whisperManager.selectedModel) ? "play.circle" : "arrow.down.circle"
        case .downloaded:
            return "play.circle"
        case .error:
            return "arrow.clockwise"
        }
    }
}

// MARK: - Transcription Model Card (US-704)

/// Card-based model selection item with elegant design
/// US-704: Whisper model size picker component
struct TranscriptionModelCard: View {
    let model: WhisperManager.ModelSize
    let isSelected: Bool
    let isDownloaded: Bool
    let isActive: Bool
    /// US-008: Whether this model is currently being switched to (hot-swap in progress)
    var isSwitchingTo: Bool = false
    /// US-013: Whether this model is recommended for the user's device
    var isRecommended: Bool = false
    let onSelect: () -> Void

    @State private var isHovering = false
    
    // Model metadata for quality/speed display
    // US-007: Each model shows size and characteristics
    private var modelInfo: (size: String, speed: String, accuracy: String, icon: String) {
        switch model {
        case .tiny:
            return ("~75 MB", "Fastest", "Basic", "hare")
        case .base:
            return ("~140 MB", "Fast", "Good", "tortoise")
        case .small:
            return ("~460 MB", "Medium", "Great", "gauge.with.dots.needle.33percent")
        case .medium:
            return ("~1.5 GB", "Slower", "Best", "gauge.with.dots.needle.67percent")
        case .large:
            return ("~3 GB", "Slowest", "Professional", "gauge.with.dots.needle.100percent")
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                // Model icon
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(isSelected ? Color.Voxa.accentLight : Color.Voxa.border.opacity(0.3))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: modelInfo.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? Color.Voxa.accent : Color.Voxa.textSecondary)
                }
                
                // Model info
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.sm) {
                        Text(model.displayName.components(separatedBy: " (").first ?? model.rawValue.capitalized)
                            .font(Font.Voxa.body)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Voxa.textPrimary)

                        // US-013: Recommended badge (shown independently of status)
                        if isRecommended {
                            TranscriptionModelBadge(text: "Recommended", color: Color.Voxa.warning)
                        }

                        // Status badge
                        // US-008: Show switching indicator during hot-swap
                        if isSwitchingTo {
                            HStack(spacing: Spacing.xs) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                                TranscriptionModelBadge(text: "Switching...", color: Color.Voxa.accent)
                            }
                        } else if isActive {
                            TranscriptionModelBadge(text: "Active", color: Color.Voxa.success)
                        } else if isDownloaded {
                            TranscriptionModelBadge(text: "Downloaded", color: Color.Voxa.accent)
                        }
                    }
                    
                    // Model specs - quality/speed tradeoff info
                    HStack(spacing: Spacing.md) {
                        TranscriptionModelSpec(icon: "internaldrive", text: modelInfo.size)
                        TranscriptionModelSpec(icon: "speedometer", text: modelInfo.speed)
                        TranscriptionModelSpec(icon: "star", text: modelInfo.accuracy)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.Voxa.accent : Color.Voxa.border, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.Voxa.accent)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(Spacing.md)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(isHovering ? Color.Voxa.border.opacity(0.2) : Color.Voxa.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(isSelected ? Color.Voxa.accent : Color.Voxa.border.opacity(0.5), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(
                color: isSelected ? Color.Voxa.accent.opacity(0.15) : Color.clear,
                radius: 8,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Transcription Model Badge (US-704)

/// Small badge for model card status indicators
struct TranscriptionModelBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(Font.Voxa.small)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(CornerRadius.small / 2)
    }
}

// MARK: - Transcription Model Spec (US-704)

/// Small spec indicator for model cards showing size, speed, accuracy
struct TranscriptionModelSpec: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Color.Voxa.textSecondary)
            Text(text)
                .font(Font.Voxa.small)
                .foregroundColor(Color.Voxa.textSecondary)
        }
    }
}

// MARK: - Transcription Progress Bar (US-704)

/// Gradient progress bar for model downloads
struct TranscriptionProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.Voxa.border)
                
                // Gradient fill
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.Voxa.accent.opacity(0.7),
                                Color.Voxa.accent,
                                Color.Voxa.accent.opacity(0.9)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geometry.size.width * CGFloat(progress)))
                    .animation(.easeOut(duration: 0.3), value: progress)
                
                // Shimmer effect overlay (subtle)
                if progress > 0 && progress < 1 {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geometry.size.width * CGFloat(progress)))
                }
            }
        }
    }
}

// MARK: - Transcription Language Picker (US-704)

/// Language selection dropdown with flags
struct TranscriptionLanguagePicker: View {
    @Binding var selectedLanguage: WhisperManager.TranscriptionLanguage
    @Binding var isExpanded: Bool
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Selected language display / dropdown trigger
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: Spacing.md) {
                    // Flag
                    Text(selectedLanguage.flag)
                        .font(.system(size: 24))
                    
                    // Language name
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedLanguage.displayName)
                            .font(Font.Voxa.body)
                            .foregroundColor(Color.Voxa.textPrimary)
                        
                        if selectedLanguage == .automatic {
                            Text("Recommended for mixed-language content")
                                .font(Font.Voxa.small)
                                .foregroundColor(Color.Voxa.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Dropdown indicator
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Voxa.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(Spacing.md)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(isHovering ? Color.Voxa.border.opacity(0.3) : Color.Voxa.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(isExpanded ? Color.Voxa.accent : Color.Voxa.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            
            // Dropdown list
            if isExpanded {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(WhisperManager.TranscriptionLanguage.allCases) { language in
                            TranscriptionLanguageRow(
                                language: language,
                                isSelected: language == selectedLanguage,
                                onSelect: {
                                    print("[US-704] Language selected: \(language.displayName)")
                                    selectedLanguage = language
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        isExpanded = false
                                    }
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 250)
                .background(Color.Voxa.surface)
                .cornerRadius(CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.Voxa.border, lineWidth: 1)
                )
                .voxaShadow(.card)
                .padding(.top, Spacing.xs)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }
}

// MARK: - Transcription Language Row (US-704)

/// Single row in the language picker dropdown
struct TranscriptionLanguageRow: View {
    let language: WhisperManager.TranscriptionLanguage
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                // Flag
                Text(language.flag)
                    .font(.system(size: 20))
                
                // Language name
                Text(language.displayName)
                    .font(Font.Voxa.body)
                    .foregroundColor(isSelected ? Color.Voxa.accent : Color.Voxa.textPrimary)
                
                if language == .automatic {
                    Text("Recommended")
                        .font(Font.Voxa.small)
                        .foregroundColor(Color.Voxa.textSecondary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Color.Voxa.border.opacity(0.5))
                        .cornerRadius(CornerRadius.small / 2)
                }
                
                Spacer()
                
                // Selected checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Voxa.accent)
                }
            }
            .padding(Spacing.md)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(isHovering ? Color.Voxa.accentLight : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Transcription Tradeoff Row (US-704)

/// Row displaying quality/speed tradeoff information
struct TranscriptionTradeoffRow: View {
    let icon: String
    let title: String
    let description: String
    var highlight: Bool = false
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(highlight ? Color.Voxa.accent : Color.Voxa.textSecondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.Voxa.body)
                    .fontWeight(highlight ? .semibold : .regular)
                    .foregroundColor(highlight ? Color.Voxa.textPrimary : Color.Voxa.textSecondary)
                
                Text(description)
                    .font(Font.Voxa.small)
                    .foregroundColor(Color.Voxa.textTertiary)
            }
            
            Spacer()
            
            if highlight {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.Voxa.accent)
            }
        }
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(highlight ? Color.Voxa.accentLight.opacity(0.5) : Color.clear)
        )
        .padding(.horizontal, Spacing.xs)
    }
}

// MARK: - Model Management View (US-012)

/// Model storage management interface for downloading, deleting, and viewing model storage
/// US-012: Model Management UI with storage information
struct ModelManagementView: View {
    @StateObject private var whisperManager = WhisperManager.shared

    /// Show delete confirmation dialog
    @State private var showDeleteConfirmation = false

    /// Model selected for deletion
    @State private var modelToDelete: WhisperManager.ModelSize?

    /// Track expanded state for storage details
    @State private var showStorageDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            // MARK: - Storage Overview Section
            storageOverviewSection

            // MARK: - Downloaded Models List Section
            downloadedModelsSection

            // MARK: - Available Models Section
            availableModelsSection
        }
        .alert("Delete Model?", isPresented: $showDeleteConfirmation, presenting: modelToDelete) { model in
            Button("Delete", role: .destructive) {
                Task {
                    await whisperManager.deleteModel(model)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { model in
            let size = whisperManager.getStorageForModel(model)
            let formattedSize = WhisperManager.formatBytes(size)
            Text("Are you sure you want to delete the \(model.displayName.components(separatedBy: " (").first ?? model.rawValue.capitalized) model? This will free up \(formattedSize) of disk space. You can re-download it later.")
        }
    }

    // MARK: - Storage Overview Section

    /// Total storage used by all models with visual indicator
    private var storageOverviewSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "internaldrive")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Storage Overview")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }

            Text("Manage disk space used by downloaded Whisper models.")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)

            // Storage summary card
            HStack(spacing: Spacing.lg) {
                // Total storage used
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Total Storage Used")
                        .font(Font.Voxa.small)
                        .foregroundColor(Color.Voxa.textSecondary)
                    Text(WhisperManager.formatBytes(whisperManager.getTotalStorageUsed()))
                        .font(Font.Voxa.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color.Voxa.textPrimary)
                }

                Spacer()

                // Downloaded models count
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text("Models Downloaded")
                        .font(Font.Voxa.small)
                        .foregroundColor(Color.Voxa.textSecondary)
                    HStack(spacing: Spacing.xs) {
                        Text("\(whisperManager.getDownloadedModels().count)")
                            .font(Font.Voxa.title)
                            .fontWeight(.bold)
                            .foregroundColor(Color.Voxa.accent)
                        Text("of \(WhisperManager.ModelSize.allCases.count)")
                            .font(Font.Voxa.body)
                            .foregroundColor(Color.Voxa.textSecondary)
                    }
                }
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color.Voxa.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(Color.Voxa.border, lineWidth: 1)
            )

            // Storage breakdown toggle
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showStorageDetails.toggle()
                }
            }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: showStorageDetails ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.Voxa.textSecondary)
                    Text(showStorageDetails ? "Hide Storage Breakdown" : "Show Storage Breakdown")
                        .font(Font.Voxa.small)
                        .foregroundColor(Color.Voxa.textSecondary)
                }
            }
            .buttonStyle(.plain)

            // Storage breakdown (expandable)
            if showStorageDetails {
                VStack(spacing: Spacing.sm) {
                    ForEach(whisperManager.getAllModelsInfo(), id: \.model.id) { info in
                        if info.isDownloaded {
                            ModelStorageRow(
                                modelName: info.model.displayName.components(separatedBy: " (").first ?? info.model.rawValue.capitalized,
                                storageUsed: WhisperManager.formatBytes(info.size),
                                isActive: info.isActive,
                                totalStorage: whisperManager.getTotalStorageUsed(),
                                modelStorage: info.size
                            )
                        }
                    }
                }
                .padding(Spacing.md)
                .background(Color.Voxa.surface.opacity(0.5))
                .cornerRadius(CornerRadius.small)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Downloaded Models Section

    /// List of downloaded models with delete options
    private var downloadedModelsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.Voxa.success)
                    .font(.system(size: 16, weight: .medium))
                Text("Downloaded Models")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }

            let downloadedModels = whisperManager.getDownloadedModels()

            if downloadedModels.isEmpty {
                // Empty state
                HStack(spacing: Spacing.md) {
                    Image(systemName: "arrow.down.circle.dotted")
                        .font(.system(size: 24))
                        .foregroundColor(Color.Voxa.textTertiary)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("No Models Downloaded")
                            .font(Font.Voxa.body)
                            .foregroundColor(Color.Voxa.textSecondary)
                        Text("Download a model from the Transcription settings to start using Voxa.")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.textTertiary)
                    }
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.Voxa.surface)
                .cornerRadius(CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.Voxa.border.opacity(0.5), lineWidth: 1)
                )
            } else {
                // List of downloaded models
                VStack(spacing: Spacing.sm) {
                    ForEach(downloadedModels) { model in
                        DownloadedModelRow(
                            model: model,
                            storageUsed: WhisperManager.formatBytes(whisperManager.getStorageForModel(model)),
                            isActive: model == whisperManager.selectedModel && whisperManager.modelStatus == .ready,
                            onDelete: {
                                modelToDelete = model
                                showDeleteConfirmation = true
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Available Models Section

    /// List of models available for download
    private var availableModelsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(Color.Voxa.textSecondary)
                    .font(.system(size: 16, weight: .medium))
                Text("Available to Download")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }

            let availableModels = WhisperManager.ModelSize.allCases.filter { !whisperManager.isModelDownloaded($0) }

            if availableModels.isEmpty {
                // All models downloaded
                HStack(spacing: Spacing.md) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.Voxa.success)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("All Models Downloaded")
                            .font(Font.Voxa.body)
                            .foregroundColor(Color.Voxa.textPrimary)
                        Text("You have downloaded all available Whisper models.")
                            .font(Font.Voxa.small)
                            .foregroundColor(Color.Voxa.textSecondary)
                    }
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.Voxa.accentLight.opacity(0.3))
                .cornerRadius(CornerRadius.medium)
            } else {
                // List of available models
                VStack(spacing: Spacing.sm) {
                    ForEach(availableModels) { model in
                        AvailableModelRow(
                            model: model,
                            estimatedSize: getEstimatedModelSize(model),
                            onDownload: {
                                Task {
                                    await whisperManager.selectModel(model)
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func getEstimatedModelSize(_ model: WhisperManager.ModelSize) -> String {
        switch model {
        case .tiny: return "~75 MB"
        case .base: return "~145 MB"
        case .small: return "~485 MB"
        case .medium: return "~1.5 GB"
        case .large: return "~3 GB"
        }
    }
}

// MARK: - Model Storage Row (US-012)

/// Row displaying storage usage for a single model with percentage bar
struct ModelStorageRow: View {
    let modelName: String
    let storageUsed: String
    let isActive: Bool
    let totalStorage: UInt64
    let modelStorage: UInt64

    private var storagePercentage: Double {
        guard totalStorage > 0 else { return 0 }
        return Double(modelStorage) / Double(totalStorage)
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Model name
            HStack(spacing: Spacing.sm) {
                Text(modelName)
                    .font(Font.Voxa.body)
                    .foregroundColor(Color.Voxa.textPrimary)
                if isActive {
                    TranscriptionModelBadge(text: "Active", color: Color.Voxa.success)
                }
            }
            .frame(width: 100, alignment: .leading)

            // Storage bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.Voxa.border)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(isActive ? Color.Voxa.accent : Color.Voxa.textSecondary)
                        .frame(width: max(4, geometry.size.width * CGFloat(storagePercentage)), height: 8)
                }
            }
            .frame(height: 8)

            // Storage size
            Text(storageUsed)
                .font(Font.Voxa.mono)
                .foregroundColor(Color.Voxa.textSecondary)
                .frame(width: 70, alignment: .trailing)
        }
    }
}

// MARK: - Downloaded Model Row (US-012)

/// Row displaying a downloaded model with delete option
struct DownloadedModelRow: View {
    let model: WhisperManager.ModelSize
    let storageUsed: String
    let isActive: Bool
    let onDelete: () -> Void

    @State private var isHovering = false

    private var modelInfo: (speed: String, accuracy: String) {
        switch model {
        case .tiny: return ("Fastest", "Basic")
        case .base: return ("Fast", "Good")
        case .small: return ("Medium", "Great")
        case .medium: return ("Slower", "Best")
        case .large: return ("Slowest", "Professional")
        }
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Model icon
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(isActive ? Color.Voxa.accentLight : Color.Voxa.border.opacity(0.3))
                    .frame(width: 40, height: 40)

                Image(systemName: "cpu")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isActive ? Color.Voxa.accent : Color.Voxa.textSecondary)
            }

            // Model info
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text(model.displayName.components(separatedBy: " (").first ?? model.rawValue.capitalized)
                        .font(Font.Voxa.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Voxa.textPrimary)

                    if isActive {
                        TranscriptionModelBadge(text: "Active", color: Color.Voxa.success)
                    }
                }

                HStack(spacing: Spacing.md) {
                    TranscriptionModelSpec(icon: "internaldrive", text: storageUsed)
                    TranscriptionModelSpec(icon: "speedometer", text: modelInfo.speed)
                    TranscriptionModelSpec(icon: "star", text: modelInfo.accuracy)
                }
            }

            Spacer()

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isHovering ? Color.Voxa.error : Color.Voxa.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(isActive)
            .opacity(isActive ? 0.3 : 1.0)
            .help(isActive ? "Cannot delete the active model" : "Delete this model")
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(isHovering ? Color.Voxa.border.opacity(0.2) : Color.Voxa.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(isActive ? Color.Voxa.accent.opacity(0.5) : Color.Voxa.border.opacity(0.5), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Available Model Row (US-012)

/// Row displaying a model available for download
struct AvailableModelRow: View {
    let model: WhisperManager.ModelSize
    let estimatedSize: String
    let onDownload: () -> Void

    @State private var isHovering = false

    private var modelInfo: (speed: String, accuracy: String, icon: String) {
        switch model {
        case .tiny: return ("Fastest", "Basic", "hare")
        case .base: return ("Fast", "Good", "tortoise")
        case .small: return ("Medium", "Great", "gauge.with.dots.needle.33percent")
        case .medium: return ("Slower", "Best", "gauge.with.dots.needle.67percent")
        case .large: return ("Slowest", "Professional", "gauge.with.dots.needle.100percent")
        }
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Model icon
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color.Voxa.border.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: modelInfo.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.Voxa.textTertiary)
            }

            // Model info
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(model.displayName.components(separatedBy: " (").first ?? model.rawValue.capitalized)
                    .font(Font.Voxa.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color.Voxa.textSecondary)

                HStack(spacing: Spacing.md) {
                    TranscriptionModelSpec(icon: "arrow.down.circle", text: estimatedSize)
                    TranscriptionModelSpec(icon: "speedometer", text: modelInfo.speed)
                    TranscriptionModelSpec(icon: "star", text: modelInfo.accuracy)
                }
            }

            Spacer()

            // Download button
            Button(action: onDownload) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 12, weight: .medium))
                    Text("Download")
                        .font(Font.Voxa.small)
                }
            }
            .buttonStyle(VoxaButtonStyle.secondary)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(isHovering ? Color.Voxa.border.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(Color.Voxa.border.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Text Cleanup Settings Summary (US-701, US-705)

/// Full Text Cleanup settings section migrated from SettingsWindow
/// US-705: Migrate Text Cleanup Settings Section to integrated settings view
struct TextCleanupSettingsSummary: View {
    @StateObject private var textCleanupManager = TextCleanupManager.shared
    @StateObject private var llmManager = LLMManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            // MARK: - Enable/Disable Toggle Section (US-705 Task 1)
            cleanupToggleSection
            
            // MARK: - Filler Word Removal Section (US-705 Task 2)
            fillerWordRemovalSection
            
            // MARK: - Post-Processing Toggles Section (US-705 Task 3)
            postProcessingSection
            
            // MARK: - Preview Section
            cleanupPreviewSection
        }
    }
    
    // MARK: - Cleanup Toggle Section
    
    /// Text cleanup enable/disable toggle with description
    /// US-705 Task 1: Show text cleanup enable/disable toggle
    private var cleanupToggleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Text Cleanup")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                Spacer()
                
                // Status badge
                StatusPill(
                    text: textCleanupManager.isCleanupEnabled ? "Enabled" : "Disabled",
                    color: textCleanupManager.isCleanupEnabled ? Color.Voxa.success : Color.Voxa.textTertiary
                )
            }
            
            Toggle("Enable Text Cleanup", isOn: $textCleanupManager.isCleanupEnabled)
                .toggleStyle(VoxaToggleStyle())
                .font(Font.Voxa.body)
                .foregroundColor(Color.Voxa.textPrimary)
            
            Text("When enabled, transcribed text will be cleaned up to remove filler words, fix grammar, and improve formatting.")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
        }
    }
    
    // MARK: - Filler Word Removal Section
    
    /// Cleanup mode selection for filler word removal options
    /// US-705 Task 2: Display filler word removal options
    private var fillerWordRemovalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "minus.circle")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Cleanup Mode")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            Text("Select a cleanup intensity level. Higher levels remove more filler words and apply more formatting.")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
            
            // Mode selection cards
            VStack(spacing: Spacing.sm) {
                ForEach(TextCleanupManager.CleanupMode.allCases, id: \.id) { mode in
                    TextCleanupModeCard(
                        mode: mode,
                        isSelected: textCleanupManager.selectedMode == mode,
                        isEnabled: textCleanupManager.isCleanupEnabled,
                        llmReady: llmManager.modelStatus == .ready,
                        onSelect: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                textCleanupManager.selectedMode = mode
                            }
                            print("[US-705] Cleanup mode selected: \(mode.rawValue)")
                        }
                    )
                }
            }
            .opacity(textCleanupManager.isCleanupEnabled ? 1.0 : 0.5)
            
            // Mode description
            HStack(spacing: Spacing.sm) {
                Image(systemName: modeDescriptionIcon)
                    .foregroundColor(Color.Voxa.textSecondary)
                    .font(.system(size: 12))
                Text(textCleanupManager.selectedMode.description)
                    .font(Font.Voxa.caption)
                    .foregroundColor(Color.Voxa.textSecondary)
            }
            .padding(Spacing.sm)
            .background(Color.Voxa.border.opacity(0.3))
            .cornerRadius(CornerRadius.small)
        }
    }
    
    // MARK: - Post-Processing Section
    
    /// Post-processing toggles for additional text cleanup options
    /// US-705 Task 3: Include post-processing toggles
    private var postProcessingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "text.badge.plus")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Post-Processing")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            Text("These options apply to all transcriptions, even when full text cleanup is disabled.")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
            
            VStack(alignment: .leading, spacing: Spacing.md) {
                // US-023: Auto-capitalize sentences toggle
                TextCleanupToggleRow(
                    icon: "textformat.abc.dottedunderline",
                    title: "Auto-Capitalize Sentences",
                    description: "Capitalize the first letter of each sentence",
                    isOn: $textCleanupManager.autoCapitalizeSentences
                )

                Divider()
                    .background(Color.Voxa.border)

                // Auto-capitalize first letter toggle (only shown when sentences is disabled)
                if !textCleanupManager.autoCapitalizeSentences {
                    TextCleanupToggleRow(
                        icon: "textformat.abc",
                        title: "Auto-Capitalize First Letter",
                        description: "Automatically capitalize the first letter of transcription",
                        isOn: $textCleanupManager.autoCapitalizeFirstLetter
                    )

                    Divider()
                        .background(Color.Voxa.border)
                }

                // Add period at end toggle
                TextCleanupToggleRow(
                    icon: "text.append",
                    title: "Add Period at End",
                    description: "Add a period at the end if no ending punctuation exists",
                    isOn: $textCleanupManager.addPeriodAtEnd
                )

                Divider()
                    .background(Color.Voxa.border)

                // Trim whitespace toggle
                TextCleanupToggleRow(
                    icon: "scissors",
                    title: "Trim Whitespace",
                    description: "Remove leading and trailing whitespace from transcription",
                    isOn: $textCleanupManager.trimWhitespace
                )

                Divider()
                    .background(Color.Voxa.border)

                // US-024: Smart quotes toggle
                TextCleanupToggleRow(
                    icon: "quote.opening",
                    title: "Smart Quotes",
                    description: "Convert straight quotes (\") to curly quotes (\u{201C}\u{201D})",
                    isOn: $textCleanupManager.useSmartQuotes
                )

                Divider()
                    .background(Color.Voxa.border)

                // US-025: Auto-punctuation toggle
                TextCleanupToggleRow(
                    icon: "ellipsis.curlybraces",
                    title: "Auto-Punctuation",
                    description: "Add punctuation based on speech pauses",
                    isOn: $textCleanupManager.autoPunctuationEnabled
                )

                // US-025: Pause duration settings (shown when auto-punctuation is enabled)
                if textCleanupManager.autoPunctuationEnabled {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        // Comma pause threshold slider
                        HStack {
                            Image(systemName: "comma")
                                .foregroundColor(Color.Voxa.textSecondary)
                                .font(.system(size: 14))
                                .frame(width: 20)
                            Text("Comma pause:")
                                .font(Font.Voxa.caption)
                                .foregroundColor(Color.Voxa.textSecondary)
                            Slider(
                                value: $textCleanupManager.pauseForComma,
                                in: 0.3...1.5,
                                step: 0.1
                            )
                            .frame(maxWidth: 120)
                            Text(String(format: "%.1fs", textCleanupManager.pauseForComma))
                                .font(Font.Voxa.caption)
                                .foregroundColor(Color.Voxa.textSecondary)
                                .frame(width: 35)
                        }

                        // Period pause threshold slider
                        HStack {
                            Image(systemName: "period")
                                .foregroundColor(Color.Voxa.textSecondary)
                                .font(.system(size: 14))
                                .frame(width: 20)
                            Text("Period pause:")
                                .font(Font.Voxa.caption)
                                .foregroundColor(Color.Voxa.textSecondary)
                            Slider(
                                value: $textCleanupManager.pauseForPeriod,
                                in: 0.8...3.0,
                                step: 0.1
                            )
                            .frame(maxWidth: 120)
                            Text(String(format: "%.1fs", textCleanupManager.pauseForPeriod))
                                .font(Font.Voxa.caption)
                                .foregroundColor(Color.Voxa.textSecondary)
                                .frame(width: 35)
                        }

                        Text("Shorter pauses insert commas, longer pauses insert periods")
                            .font(.system(size: 10))
                            .foregroundColor(Color.Voxa.textSecondary)
                            .opacity(0.8)
                    }
                    .padding(.leading, Spacing.lg)
                    .padding(.top, Spacing.xs)
                }
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

    // MARK: - Preview Section
    
    /// Shows before/after preview of text cleanup
    private var cleanupPreviewSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "eye")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Preview")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            Text("See how your transcriptions will be cleaned up with the selected mode.")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
            
            // Preview cards
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Before text
                TextCleanupPreviewText(
                    label: "Before",
                    text: sampleBefore,
                    color: Color.Voxa.error
                )
                
                // Arrow indicator
                HStack {
                    Spacer()
                    Image(systemName: "arrow.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.Voxa.accent)
                    Spacer()
                }
                .padding(.vertical, Spacing.xs)
                
                // After text
                TextCleanupPreviewText(
                    label: "After (\(textCleanupManager.selectedMode.displayName.components(separatedBy: " ").first ?? ""))",
                    text: sampleAfter,
                    color: Color.Voxa.success
                )
            }
        }
        .opacity(textCleanupManager.isCleanupEnabled ? 1.0 : 0.5)
    }
    
    // MARK: - Helper Properties
    
    private var modeDescriptionIcon: String {
        switch textCleanupManager.selectedMode {
        case .basic:
            return "hare"
        case .standard:
            return "dial.medium"
        case .thorough:
            return "sparkles"
        case .aiPowered:
            return "brain"
        }
    }
    
    private var sampleBefore: String {
        "Um, so like, I was thinking, you know, that we should, uh, basically just go ahead and, like, finish the project by friday."
    }
    
    private var sampleAfter: String {
        switch textCleanupManager.selectedMode {
        case .basic:
            return "So like, I was thinking, you know, that we should basically just go ahead and, like, finish the project by friday."
        case .standard:
            return "I was thinking that we should just go ahead and finish the project by Friday."
        case .thorough:
            return "I was thinking that we should finish the project by Friday."
        case .aiPowered:
            return "I think we should finish the project by Friday."
        }
    }
}

// MARK: - Text Cleanup Mode Card (US-705)

/// Card-based mode selection item for cleanup intensity
/// US-705: Filler word removal options component
struct TextCleanupModeCard: View {
    let mode: TextCleanupManager.CleanupMode
    let isSelected: Bool
    let isEnabled: Bool
    let llmReady: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    // Mode metadata for display
    private var modeInfo: (icon: String, shortName: String, fillerWords: String) {
        switch mode {
        case .basic:
            return ("hare", "Basic", "um, uh, er, ah")
        case .standard:
            return ("dial.medium", "Standard", "Basic + like, you know, I mean")
        case .thorough:
            return ("sparkles", "Thorough", "All fillers + basically, literally, obviously")
        case .aiPowered:
            return ("brain", "AI-Powered", "Intelligent cleanup with context awareness")
        }
    }
    
    var body: some View {
        Button(action: {
            if isEnabled {
                onSelect()
            }
        }) {
            HStack(spacing: Spacing.md) {
                // Mode icon
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(isSelected ? Color.Voxa.accentLight : Color.Voxa.border.opacity(0.3))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: modeInfo.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? Color.Voxa.accent : Color.Voxa.textSecondary)
                    
                    // LLM ready indicator for AI mode
                    if mode == .aiPowered && llmReady {
                        Circle()
                            .fill(Color.Voxa.success)
                            .frame(width: 8, height: 8)
                            .offset(x: 14, y: -14)
                    }
                }
                
                // Mode info
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.sm) {
                        Text(modeInfo.shortName)
                            .font(Font.Voxa.body)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Voxa.textPrimary)
                        
                        // LLM status for AI mode
                        if mode == .aiPowered {
                            TextCleanupModeBadge(
                                text: llmReady ? "LLM Ready" : "LLM Required",
                                color: llmReady ? Color.Voxa.success : Color.Voxa.warning
                            )
                        }
                    }
                    
                    // Filler words removed description
                    Text("Removes: \(modeInfo.fillerWords)")
                        .font(Font.Voxa.small)
                        .foregroundColor(Color.Voxa.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.Voxa.accent : Color.Voxa.border, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.Voxa.accent)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(Spacing.md)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(isHovering ? Color.Voxa.border.opacity(0.2) : Color.Voxa.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(isSelected ? Color.Voxa.accent : Color.Voxa.border.opacity(0.5), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(
                color: isSelected ? Color.Voxa.accent.opacity(0.15) : Color.clear,
                radius: 8,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Text Cleanup Mode Badge (US-705)

/// Small badge for cleanup mode status indicators
struct TextCleanupModeBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(Font.Voxa.small)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(CornerRadius.small / 2)
    }
}

// MARK: - Text Cleanup Toggle Row (US-705)

/// Toggle row for post-processing options
/// US-705: Post-processing toggles component
struct TextCleanupToggleRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Toggle(isOn: $isOn) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isOn ? Color.Voxa.accent : Color.Voxa.textSecondary)
                        .frame(width: 20)
                    
                    Text(title)
                        .font(Font.Voxa.body)
                        .foregroundColor(Color.Voxa.textPrimary)
                }
            }
            .toggleStyle(VoxaToggleStyle())
            .onChange(of: isOn) { _, newValue in
                print("[US-705] Post-processing toggle '\(title)' changed to: \(newValue)")
            }
            
            Text(description)
                .font(Font.Voxa.small)
                .foregroundColor(Color.Voxa.textSecondary)
                .padding(.leading, Spacing.xxl + Spacing.md)
        }
    }
}

// MARK: - Text Cleanup Preview Text (US-705)

/// Preview text display for before/after comparison
struct TextCleanupPreviewText: View {
    let label: String
    let text: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(color.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(Font.Voxa.small)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.Voxa.textSecondary)
            }
            
            Text(text)
                .font(Font.Voxa.body)
                .foregroundColor(label.contains("Before") ? Color.Voxa.textSecondary : Color.Voxa.textPrimary)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.08))
                .cornerRadius(CornerRadius.small)
        }
    }
}

// MARK: - Text Insertion Settings Summary (US-701, US-706)

/// Full Text Insertion settings section migrated from SettingsWindow
/// US-706: Migrate Text Insertion Settings Section to integrated settings view
struct TextInsertionSettingsSummary: View {
    @StateObject private var textInserter = TextInserter.shared
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var showPermissionGrantedMessage = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            // MARK: - Insertion Method Section (US-706 Task 1)
            insertionMethodSection
            
            Divider()
                .background(Color.Voxa.border)
            
            // MARK: - Clipboard Preservation Section (US-706 Task 2)
            clipboardPreservationSection
            
            Divider()
                .background(Color.Voxa.border)
            
            // MARK: - Timing Options Section (US-706 Task 3)
            if textInserter.preserveClipboard {
                timingOptionsSection
                
                Divider()
                    .background(Color.Voxa.border)
            }
            
            // MARK: - Accessibility Permission Section
            accessibilityPermissionSection
            
            Divider()
                .background(Color.Voxa.border)
            
            // MARK: - How It Works Section
            howItWorksSection
        }
        .onAppear {
            // Set up callback to show success message when permission is granted
            textInserter.onPermissionGranted = {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showPermissionGrantedMessage = true
                }
                // Hide the message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showPermissionGrantedMessage = false
                    }
                }
            }
        }
    }
    
    // MARK: - Insertion Method Section
    
    /// US-706 Task 1: Show text insertion method options
    private var insertionMethodSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section Header
            HStack(spacing: Spacing.sm) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.Voxa.accent)
                Text("Insertion Method")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            Text("Choose how transcribed text is inserted into your applications.")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
            
            // Method selection card
            TextInsertionMethodCard(
                isSelected: true, // Only paste method is currently supported
                icon: "doc.on.clipboard",
                title: "Paste (⌘V)",
                description: "Copies text to clipboard and simulates Cmd+V paste. Works in all applications.",
                features: ["Universal compatibility", "Works in all apps", "Reliable insertion"]
            )
            
            // Note about other methods
            HStack(spacing: Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.Voxa.info)
                Text("The paste method is the most reliable and works across all applications.")
                    .font(Font.Voxa.small)
                    .foregroundColor(Color.Voxa.textSecondary)
            }
            .padding(Spacing.sm)
            .background(Color.Voxa.infoLight.opacity(0.3))
            .cornerRadius(CornerRadius.small)
        }
    }
    
    // MARK: - Clipboard Preservation Section
    
    /// US-706 Task 2: Include clipboard preservation toggle
    private var clipboardPreservationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section Header
            HStack(spacing: Spacing.sm) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.Voxa.accent)
                Text("Clipboard Preservation")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            // Toggle row
            TextInsertionToggleRow(
                icon: "arrow.uturn.backward",
                title: "Preserve Clipboard Contents",
                description: "Automatically restore the original clipboard contents after text insertion.",
                isOn: $textInserter.preserveClipboard
            )
            
            // Status indicator
            HStack(spacing: Spacing.sm) {
                Image(systemName: textInserter.preserveClipboard ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textInserter.preserveClipboard ? Color.Voxa.success : Color.Voxa.textTertiary)
                
                Text(textInserter.preserveClipboard ? "Your clipboard will be restored after insertion" : "Clipboard will not be restored")
                    .font(Font.Voxa.small)
                    .foregroundColor(textInserter.preserveClipboard ? Color.Voxa.success : Color.Voxa.textSecondary)
            }
            .padding(Spacing.sm)
            .background(textInserter.preserveClipboard ? Color.Voxa.successLight.opacity(0.3) : Color.Voxa.border.opacity(0.2))
            .cornerRadius(CornerRadius.small)
        }
    }
    
    // MARK: - Timing Options Section
    
    /// US-706 Task 3: Display timing options
    private var timingOptionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section Header
            HStack(spacing: Spacing.sm) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.Voxa.accent)
                Text("Timing Options")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            Text("Configure the delay before restoring clipboard contents.")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
            
            // Delay slider with visual display
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Restore Delay")
                        .font(Font.Voxa.body)
                        .foregroundColor(Color.Voxa.textPrimary)
                    
                    Spacer()
                    
                    // Formatted delay value badge
                    Text(String(format: "%.1f seconds", textInserter.clipboardRestoreDelay))
                        .font(Font.Voxa.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.Voxa.accent)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.Voxa.accentLight)
                        .cornerRadius(CornerRadius.small)
                }
                
                // Custom slider
                TextInsertionDelaySlider(value: $textInserter.clipboardRestoreDelay)
                
                // Slider labels
                HStack {
                    Text("0.2s")
                        .font(Font.Voxa.small)
                        .foregroundColor(Color.Voxa.textTertiary)
                    Spacer()
                    Text("2.0s")
                        .font(Font.Voxa.small)
                        .foregroundColor(Color.Voxa.textTertiary)
                }
            }
            .padding(Spacing.md)
            .background(Color.Voxa.surface)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(Color.Voxa.border, lineWidth: 1)
            )
            
            // Help text
            HStack(spacing: Spacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.Voxa.warning)
                Text("Increase the delay if inserted text gets cut off. The default 0.8s works for most applications.")
                    .font(Font.Voxa.small)
                    .foregroundColor(Color.Voxa.textSecondary)
            }
            .padding(Spacing.sm)
            .background(Color.Voxa.warningLight.opacity(0.3))
            .cornerRadius(CornerRadius.small)
        }
    }
    
    // MARK: - Accessibility Permission Section
    
    private var accessibilityPermissionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section Header
            HStack(spacing: Spacing.sm) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.Voxa.accent)
                Text("Accessibility Permission")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            Text("Required for simulating keyboard shortcuts to paste text.")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
            
            // Permission status card
            HStack(spacing: Spacing.md) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(textInserter.hasAccessibilityPermission ? Color.Voxa.successLight : Color.Voxa.errorLight)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: textInserter.hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(textInserter.hasAccessibilityPermission ? Color.Voxa.success : Color.Voxa.error)
                }
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(textInserter.hasAccessibilityPermission ? "Permission Granted" : "Permission Not Granted")
                        .font(Font.Voxa.body)
                        .fontWeight(.semibold)
                        .foregroundColor(textInserter.hasAccessibilityPermission ? Color.Voxa.success : Color.Voxa.error)
                    
                    Text(textInserter.hasAccessibilityPermission ? "Text insertion is ready to use" : "Grant permission to enable text insertion")
                        .font(Font.Voxa.small)
                        .foregroundColor(Color.Voxa.textSecondary)
                }
                
                Spacer()
                
                // Grant permission button (only shown when not granted)
                if !textInserter.hasAccessibilityPermission {
                    Button(action: {
                        print("[US-706] Opening accessibility settings")
                        _ = permissionManager.requestAccessibilityPermission()
                    }) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "gear")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Grant Access")
                                .font(Font.Voxa.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .foregroundColor(.white)
                        .background(Color.Voxa.accent)
                        .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(Spacing.md)
            .background(textInserter.hasAccessibilityPermission ? Color.Voxa.successLight.opacity(0.2) : Color.Voxa.errorLight.opacity(0.2))
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(textInserter.hasAccessibilityPermission ? Color.Voxa.success.opacity(0.3) : Color.Voxa.error.opacity(0.3), lineWidth: 1)
            )
            
            // Success message when permission is granted
            if showPermissionGrantedMessage {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(Color.Voxa.success)
                    Text("Permission Granted!")
                        .font(Font.Voxa.caption)
                        .foregroundColor(Color.Voxa.success)
                        .fontWeight(.semibold)
                }
                .padding(Spacing.sm)
                .background(Color.Voxa.successLight)
                .cornerRadius(CornerRadius.small)
                .transition(.opacity.combined(with: .scale))
            }
            
            // Instructions if not granted
            if !textInserter.hasAccessibilityPermission {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("How to grant permission:")
                        .font(Font.Voxa.caption)
                        .foregroundColor(Color.Voxa.textSecondary)
                        .fontWeight(.semibold)
                    
                    TextInsertionInstructionRow(number: 1, text: "Click \"Grant Access\" above to open System Settings")
                    TextInsertionInstructionRow(number: 2, text: "Find Voxa in the list and enable the toggle")
                    TextInsertionInstructionRow(number: 3, text: "Return to Voxa - permission will be detected automatically")
                }
                .padding(Spacing.md)
                .background(Color.Voxa.surface)
                .cornerRadius(CornerRadius.small)
            }
        }
    }
    
    // MARK: - How It Works Section
    
    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section Header
            HStack(spacing: Spacing.sm) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.Voxa.accent)
                Text("How Text Insertion Works")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            // Feature list
            VStack(alignment: .leading, spacing: Spacing.sm) {
                TextInsertionFeatureRow(icon: "1.circle.fill", text: "Transcribed text is copied to the clipboard", color: Color.Voxa.accent)
                TextInsertionFeatureRow(icon: "2.circle.fill", text: "Cmd+V keystroke is simulated to paste", color: Color.Voxa.accent)
                if textInserter.preserveClipboard {
                    TextInsertionFeatureRow(icon: "3.circle.fill", text: "Original clipboard is restored after \(String(format: "%.1fs", textInserter.clipboardRestoreDelay))", color: Color.Voxa.accent)
                } else {
                    TextInsertionFeatureRow(icon: "3.circle.fill", text: "Text remains on clipboard (preservation disabled)", color: Color.Voxa.textTertiary)
                }
                TextInsertionFeatureRow(icon: "checkmark.circle.fill", text: "Works in any application with text input", color: Color.Voxa.success)
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
}

// MARK: - Text Insertion Method Card (US-706)

/// Card component for displaying an insertion method option
struct TextInsertionMethodCard: View {
    let isSelected: Bool
    let icon: String
    let title: String
    let description: String
    let features: [String]
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            // Selection indicator
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.Voxa.accent : Color.Voxa.border, lineWidth: 2)
                    .frame(width: 20, height: 20)
                
                if isSelected {
                    Circle()
                        .fill(Color.Voxa.accent)
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Icon and title
                HStack(spacing: Spacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? Color.Voxa.accent : Color.Voxa.textSecondary)
                    
                    Text(title)
                        .font(Font.Voxa.body)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.Voxa.textPrimary)
                    
                    if isSelected {
                        Text("Active")
                            .font(Font.Voxa.small)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.Voxa.success)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs - 2)
                            .background(Color.Voxa.successLight)
                            .cornerRadius(CornerRadius.small)
                    }
                }
                
                Text(description)
                    .font(Font.Voxa.caption)
                    .foregroundColor(Color.Voxa.textSecondary)
                
                // Features list
                HStack(spacing: Spacing.md) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.Voxa.success)
                            Text(feature)
                                .font(Font.Voxa.small)
                                .foregroundColor(Color.Voxa.textSecondary)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(Spacing.md)
        .background(isSelected ? Color.Voxa.accentLight.opacity(0.3) : Color.Voxa.surface)
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(isSelected ? Color.Voxa.accent.opacity(0.5) : Color.Voxa.border, lineWidth: isSelected ? 2 : 1)
        )
        .scaleEffect(isHovering ? 1.01 : 1.0)
        .animation(VoxaAnimation.quick, value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Text Insertion Toggle Row (US-706)

/// Toggle row component for text insertion settings
struct TextInsertionToggleRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Toggle(isOn: $isOn) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isOn ? Color.Voxa.accent : Color.Voxa.textSecondary)
                        .frame(width: 20)
                    
                    Text(title)
                        .font(Font.Voxa.body)
                        .foregroundColor(Color.Voxa.textPrimary)
                }
            }
            .toggleStyle(VoxaToggleStyle())
            .onChange(of: isOn) { _, newValue in
                print("[US-706] Text insertion toggle '\(title)' changed to: \(newValue)")
            }
            
            Text(description)
                .font(Font.Voxa.small)
                .foregroundColor(Color.Voxa.textSecondary)
                .padding(.leading, Spacing.xxl + Spacing.md)
        }
    }
}

// MARK: - Text Insertion Delay Slider (US-706)

/// Custom slider for clipboard restore delay
struct TextInsertionDelaySlider: View {
    @Binding var value: Double
    
    private let minValue: Double = 0.2
    private let maxValue: Double = 2.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.Voxa.border)
                    .frame(height: 8)
                
                // Filled portion
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [Color.Voxa.accent.opacity(0.7), Color.Voxa.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: CGFloat((value - minValue) / (maxValue - minValue)) * geometry.size.width, height: 8)
                
                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .overlay(
                        Circle()
                            .stroke(Color.Voxa.accent, lineWidth: 2)
                    )
                    .offset(x: CGFloat((value - minValue) / (maxValue - minValue)) * (geometry.size.width - 20))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let newValue = minValue + (maxValue - minValue) * Double(gesture.location.x / geometry.size.width)
                                value = min(max(newValue, minValue), maxValue)
                                // Round to nearest 0.1
                                value = round(value * 10) / 10
                            }
                    )
            }
        }
        .frame(height: 20)
    }
}

// MARK: - Text Insertion Instruction Row (US-706)

/// Instruction row with number for text insertion setup
struct TextInsertionInstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text("\(number).")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.accent)
                .fontWeight(.semibold)
                .frame(width: 16, alignment: .trailing)
            
            Text(text)
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
        }
    }
}

// MARK: - Text Insertion Feature Row (US-706)

/// Feature row component for how-it-works section
struct TextInsertionFeatureRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(text)
                .font(Font.Voxa.body)
                .foregroundColor(Color.Voxa.textPrimary)
            
            Spacer()
        }
    }
}

// MARK: - Debug Settings Summary (US-701, US-707)

/// Full Debug settings section migrated from SettingsWindow
/// US-707: Migrate Debug Settings Section to integrated settings view
struct DebugSettingsSummary: View {
    @StateObject private var debugManager = DebugManager.shared
    @State private var showResetConfirmation = false
    @State private var showExportSuccess = false
    @State private var exportMessage = ""
    @State private var exportedFilePath: String? = nil
    @State private var isPlayingAudio = false
    @State private var selectedLogLevel: DebugLogLevel = .info
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            // MARK: - Debug Mode Section
            debugModeSection
            
            // MARK: - Log Level Section (US-707 Task 1)
            logLevelSection
            
            // MARK: - Debug Actions Section (US-707 Tasks 2, 3)
            debugActionsSection
            
            // MARK: - System Info Section (US-707 Task 4)
            systemInfoSection
            
            // MARK: - Last Recording Section
            lastRecordingSection
            
            // MARK: - Reset Settings Section (US-707 Task 5)
            resetSettingsSection
        }
        .alert("Export Result", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) {}
            if let _ = exportedFilePath {
                Button("Show in Finder") {
                    AudioExporter.shared.revealLastExportInFinder()
                }
                Button("Play Audio") {
                    togglePlayback()
                }
            }
        } message: {
            Text(exportMessage)
        }
        .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all Voxa settings to their default values. This action cannot be undone.")
        }
        .onAppear {
            // Set up playback completion callback
            AudioExporter.shared.onPlaybackComplete = {
                isPlayingAudio = false
            }
            // Load last exported path if available
            if let url = AudioExporter.shared.lastExportedURL {
                exportedFilePath = url.path
            }
        }
    }
    
    // MARK: - Debug Mode Section
    
    /// Debug mode toggle and associated options
    private var debugModeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "ladybug")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Debug Mode")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
                
                Spacer()
                
                StatusPill(
                    text: debugManager.isDebugModeEnabled ? "Enabled" : "Disabled",
                    color: debugManager.isDebugModeEnabled ? Color.Voxa.warning : Color.Voxa.textTertiary
                )
            }
            
            Toggle("Enable Debug Mode", isOn: $debugManager.isDebugModeEnabled)
                .toggleStyle(VoxaToggleStyle())
                .font(Font.Voxa.body)
                .foregroundColor(Color.Voxa.textPrimary)
            
            Text("When enabled, Voxa will log detailed information about audio capture, transcription, and text cleanup. Use this to troubleshoot issues.")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
            
            // Debug sub-options (only visible when debug mode is enabled)
            if debugManager.isDebugModeEnabled {
                Divider()
                    .background(Color.Voxa.border)
                
                // Silence detection override
                DebugSettingsToggleRow(
                    icon: "speaker.slash",
                    title: "Disable Silence Detection",
                    description: "Audio will not be rejected for being too quiet. Useful for testing with silent recordings.",
                    isOn: $debugManager.isSilenceDetectionDisabled
                )
                
                Divider()
                    .background(Color.Voxa.border)
                
                // Auto-save recordings toggle
                DebugSettingsToggleRow(
                    icon: "arrow.down.doc",
                    title: "Auto-Save Recordings",
                    description: "Each recording will be saved to Documents/Voxa/DebugRecordings/ for analysis.",
                    isOn: $debugManager.isAutoSaveEnabled
                )
            }
        }
    }
    
    // MARK: - Log Level Section (US-707 Task 1)
    
    /// Log level selector
    private var logLevelSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Log Level")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            Text("Select the verbosity of debug logging. Higher levels include more detailed information.")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
            
            // Log level picker
            DebugLogLevelPicker(selectedLevel: $selectedLogLevel)
                .opacity(debugManager.isDebugModeEnabled ? 1.0 : 0.5)
            
            if !debugManager.isDebugModeEnabled {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(Color.Voxa.textSecondary)
                    Text("Enable Debug Mode to configure log level")
                        .font(Font.Voxa.small)
                        .foregroundColor(Color.Voxa.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Debug Actions Section (US-707 Tasks 2, 3)
    
    /// Export logs and open recordings folder buttons
    private var debugActionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Debug Actions")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            // Action buttons row
            HStack(spacing: Spacing.md) {
                // Export Logs button (US-707 Task 2)
                Button(action: exportLogs) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "doc.text")
                        Text("Export Logs")
                    }
                }
                .buttonStyle(VoxaButtonStyle.secondary)
                .disabled(!debugManager.isDebugModeEnabled || debugManager.logEntries.isEmpty)
                
                // Open Recordings Folder button (US-707 Task 3)
                Button(action: {
                    AudioExporter.shared.openDebugRecordingsFolder()
                    print("[US-707] Open Recordings Folder button clicked")
                }) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "folder")
                        Text("Open Recordings Folder")
                    }
                }
                .buttonStyle(VoxaButtonStyle.secondary)
            }
            
            // Additional action buttons (when debug mode is enabled)
            if debugManager.isDebugModeEnabled && debugManager.lastRawAudioData != nil {
                HStack(spacing: Spacing.md) {
                    // Export last audio
                    Button(action: quickExportToDocuments) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "waveform.badge.plus")
                            Text("Export Last Audio")
                        }
                    }
                    .buttonStyle(VoxaButtonStyle.secondary)
                    
                    // Playback button (if there's an exported file)
                    if AudioExporter.shared.lastExportedURL != nil {
                        Button(action: togglePlayback) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: isPlayingAudio ? "stop.fill" : "play.fill")
                                Text(isPlayingAudio ? "Stop" : "Play")
                            }
                        }
                        .buttonStyle(VoxaButtonStyle(variant: isPlayingAudio ? .ghost : .secondary))
                        
                        // Show in Finder
                        Button(action: {
                            AudioExporter.shared.revealLastExportInFinder()
                            print("[US-707] Show in Finder button clicked")
                        }) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "folder.badge.questionmark")
                                Text("Show in Finder")
                            }
                        }
                        .buttonStyle(VoxaButtonStyle.secondary)
                    }
                }
            }
            
            // Last export path
            if let path = exportedFilePath {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Last Export:")
                        .font(Font.Voxa.caption)
                        .foregroundColor(Color.Voxa.textSecondary)
                    Text(path)
                        .font(Font.Voxa.small)
                        .foregroundColor(Color.Voxa.accent)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                .padding(.top, Spacing.sm)
            }
            
            if !debugManager.isDebugModeEnabled {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(Color.Voxa.textSecondary)
                    Text("Enable Debug Mode to access export features")
                        .font(Font.Voxa.small)
                        .foregroundColor(Color.Voxa.textSecondary)
                }
                .padding(.top, Spacing.xs)
            }
        }
    }
    
    // MARK: - System Info Section (US-707 Task 4)
    
    /// System information display
    private var systemInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "info.circle")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("System Info")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            // System info grid
            VStack(alignment: .leading, spacing: Spacing.sm) {
                DebugSystemInfoRow(label: "App Version", value: appVersion)
                DebugSystemInfoRow(label: "Build Number", value: buildNumber)
                DebugSystemInfoRow(label: "macOS Version", value: macOSVersion)
                DebugSystemInfoRow(label: "Model Identifier", value: machineModel)
                DebugSystemInfoRow(label: "Available Memory", value: availableMemory)
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
    
    // MARK: - Last Recording Section
    
    /// Display last recording information
    private var lastRecordingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "waveform")
                    .foregroundColor(Color.Voxa.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Last Recording")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            if let audioData = debugManager.lastAudioData {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.lg) {
                        DebugRecordingMetric(
                            icon: "clock",
                            label: "Duration",
                            value: String(format: "%.2fs", audioData.duration)
                        )
                        
                        DebugRecordingMetric(
                            icon: "speaker.wave.2",
                            label: "Peak Level",
                            value: String(format: "%.1f dB", audioData.peakLevel),
                            color: audioData.peakLevel > -55 ? Color.Voxa.success : Color.Voxa.warning
                        )
                        
                        DebugRecordingMetric(
                            icon: "waveform.path",
                            label: "Samples",
                            value: "\(audioData.samples.count)"
                        )
                    }
                    
                    // Mini waveform
                    DebugCompactWaveformView(
                        samples: audioData.samples,
                        sampleRate: audioData.sampleRate
                    )
                    .frame(height: 50)
                    .padding(.top, Spacing.xs)
                }
                .padding(Spacing.md)
                .background(Color.Voxa.surface)
                .cornerRadius(CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.Voxa.border, lineWidth: 1)
                )
            } else {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "waveform.slash")
                        .font(.system(size: 14))
                        .foregroundColor(Color.Voxa.textTertiary)
                    Text("No recording data available")
                        .font(Font.Voxa.caption)
                        .foregroundColor(Color.Voxa.textSecondary)
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.Voxa.surface)
                .cornerRadius(CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.Voxa.border, lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Reset Settings Section (US-707 Task 5)
    
    /// Reset all settings option
    private var resetSettingsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundColor(Color.Voxa.error)
                    .font(.system(size: 16, weight: .medium))
                Text("Reset Settings")
                    .font(Font.Voxa.headline)
                    .foregroundColor(Color.Voxa.textPrimary)
            }
            
            Text("Reset all Voxa settings to their default values. This cannot be undone.")
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
            
            Button(action: {
                showResetConfirmation = true
                print("[US-707] Reset All Settings button clicked")
            }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset All Settings")
                }
            }
            .buttonStyle(VoxaButtonStyle(variant: .ghost))
            .foregroundColor(Color.Voxa.error)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Toggle audio playback
    private func togglePlayback() {
        if isPlayingAudio {
            AudioExporter.shared.stopPlayback()
            isPlayingAudio = false
        } else {
            if AudioExporter.shared.playLastExport() {
                isPlayingAudio = true
            }
        }
        print("[US-707] Toggle playback: \(isPlayingAudio ? "playing" : "stopped")")
    }
    
    /// Quick export to Documents folder
    private func quickExportToDocuments() {
        guard let audioData = debugManager.lastRawAudioData else {
            exportMessage = "No audio data available to export"
            showExportSuccess = true
            return
        }
        
        let result = AudioExporter.shared.exportToDocuments(
            audioData: audioData,
            sampleRate: debugManager.lastRawAudioSampleRate
        )
        
        switch result {
        case .success(let url):
            exportMessage = "Audio exported successfully to:\n\(url.path)"
            exportedFilePath = url.path
            print("[US-707] Audio exported to: \(url.path)")
        case .noAudioData:
            exportMessage = "No audio data available to export"
        case .exportFailed(let error):
            exportMessage = "Export failed: \(error)"
        }
        showExportSuccess = true
    }
    
    /// Export logs to file (US-707 Task 2)
    private func exportLogs() {
        let logsText = debugManager.getAllLogsFormatted()
        
        guard !logsText.isEmpty else {
            exportMessage = "No logs available to export"
            showExportSuccess = true
            return
        }
        
        DispatchQueue.main.async {
            let savePanel = NSSavePanel()
            savePanel.title = "Export Debug Logs"
            savePanel.nameFieldStringValue = generateLogsFilename()
            savePanel.allowedContentTypes = [.plainText]
            savePanel.canCreateDirectories = true
            savePanel.message = "Choose a location to save the debug logs"
            
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    do {
                        try logsText.write(to: url, atomically: true, encoding: .utf8)
                        exportMessage = "Logs exported successfully to:\n\(url.path)"
                        exportedFilePath = url.path
                        print("[US-707] Logs exported to: \(url.path)")
                    } catch {
                        exportMessage = "Failed to export logs: \(error.localizedDescription)"
                    }
                    showExportSuccess = true
                }
            }
        }
    }
    
    /// Generate a default logs filename with timestamp
    private func generateLogsFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        return "Voxa_Logs_\(timestamp).txt"
    }
    
    /// Reset all settings to defaults (US-707 Task 5)
    private func resetAllSettings() {
        print("[US-707] Resetting all settings to defaults...")
        
        // Reset debug settings
        debugManager.isDebugModeEnabled = false
        debugManager.isSilenceDetectionDisabled = false
        debugManager.isAutoSaveEnabled = false
        
        // Reset text cleanup settings
        TextCleanupManager.shared.isCleanupEnabled = true
        TextCleanupManager.shared.selectedMode = .standard
        TextCleanupManager.shared.autoCapitalizeFirstLetter = true
        TextCleanupManager.shared.addPeriodAtEnd = true
        TextCleanupManager.shared.trimWhitespace = true
        TextCleanupManager.shared.autoCapitalizeSentences = true  // US-023
        TextCleanupManager.shared.useSmartQuotes = false  // US-024 (opt-in feature, default off)

        // Reset text insertion settings
        TextInserter.shared.preserveClipboard = true
        TextInserter.shared.clipboardRestoreDelay = 0.8
        
        // Reset hotkey to default
        HotkeyManager.shared.resetToDefault()
        
        // Reset log level
        selectedLogLevel = .info
        
        print("[US-707] All settings have been reset to defaults")
    }
    
    // MARK: - System Info Properties
    
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }
    
    private var macOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    private var machineModel: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
    
    private var availableMemory: String {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let totalGB = Double(totalMemory) / (1024 * 1024 * 1024)
        return String(format: "%.1f GB", totalGB)
    }
}

// MARK: - Debug Log Level Enum (US-707)

/// Log level options for debug logging
/// US-707 Task 1: Log level selector
enum DebugLogLevel: String, CaseIterable, Identifiable {
    case verbose = "verbose"
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .verbose: return "Verbose"
        case .debug: return "Debug"
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        }
    }
    
    var description: String {
        switch self {
        case .verbose: return "All messages including trace information"
        case .debug: return "Debug and higher priority messages"
        case .info: return "Info and higher priority messages"
        case .warning: return "Warning and error messages only"
        case .error: return "Error messages only"
        }
    }
    
    var icon: String {
        switch self {
        case .verbose: return "text.magnifyingglass"
        case .debug: return "ladybug"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .verbose: return Color.Voxa.textSecondary
        case .debug: return Color.Voxa.info
        case .info: return Color.Voxa.success
        case .warning: return Color.Voxa.warning
        case .error: return Color.Voxa.error
        }
    }
}

// MARK: - Debug Log Level Picker (US-707)

/// Picker for selecting log verbosity level
/// US-707 Task 1: Log level selection works
struct DebugLogLevelPicker: View {
    @Binding var selectedLevel: DebugLogLevel
    
    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(DebugLogLevel.allCases) { level in
                DebugLogLevelRow(
                    level: level,
                    isSelected: selectedLevel == level,
                    onSelect: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedLevel = level
                        }
                        print("[US-707] Log level selected: \(level.rawValue)")
                    }
                )
            }
        }
    }
}

// MARK: - Debug Log Level Row (US-707)

/// Single row in the log level picker
struct DebugLogLevelRow: View {
    let level: DebugLogLevel
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                // Level icon
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(isSelected ? level.color.opacity(0.2) : Color.Voxa.border.opacity(0.3))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: level.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? level.color : Color.Voxa.textSecondary)
                }
                
                // Level info
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.displayName)
                        .font(Font.Voxa.body)
                        .fontWeight(isSelected ? .medium : .regular)
                        .foregroundColor(isSelected ? Color.Voxa.textPrimary : Color.Voxa.textSecondary)
                    
                    Text(level.description)
                        .font(Font.Voxa.small)
                        .foregroundColor(Color.Voxa.textTertiary)
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? level.color : Color.Voxa.border, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if isSelected {
                        Circle()
                            .fill(level.color)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(Spacing.sm)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(isHovering ? Color.Voxa.border.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(isSelected ? level.color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Debug Settings Toggle Row (US-707)

/// Toggle row for debug settings options
struct DebugSettingsToggleRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Toggle(isOn: $isOn) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.Voxa.textSecondary)
                        .frame(width: 20)
                    
                    Text(title)
                        .font(Font.Voxa.body)
                        .foregroundColor(Color.Voxa.textPrimary)
                }
            }
            .toggleStyle(VoxaToggleStyle())
            
            Text(description)
                .font(Font.Voxa.caption)
                .foregroundColor(Color.Voxa.textSecondary)
                .padding(.leading, 28) // Align with title text
        }
    }
}

// MARK: - Debug System Info Row (US-707)

/// Single row displaying system information
/// US-707 Task 4: Show system info
struct DebugSystemInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(Font.Voxa.body)
                .foregroundColor(Color.Voxa.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(Font.Voxa.mono)
                .foregroundColor(Color.Voxa.textPrimary)
        }
    }
}

// MARK: - Debug Recording Metric (US-707)

/// Metric display for last recording info
struct DebugRecordingMetric: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = Color.Voxa.textPrimary
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.Voxa.textSecondary)
                Text(label)
                    .font(Font.Voxa.small)
                    .foregroundColor(Color.Voxa.textSecondary)
            }
            
            Text(value)
                .font(Font.Voxa.body)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// MARK: - Debug Compact Waveform View (US-707)

/// Compact waveform visualization for debug settings
struct DebugCompactWaveformView: View {
    let samples: [Float]
    let sampleRate: Double
    
    var body: some View {
        GeometryReader { geometry in
            let barWidth: CGFloat = 2
            let barSpacing: CGFloat = 1
            let totalBarWidth = barWidth + barSpacing
            let numberOfBars = Int(geometry.size.width / totalBarWidth)
            let samplesPerBar = max(1, samples.count / numberOfBars)
            
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(0..<numberOfBars, id: \.self) { index in
                    let startIndex = index * samplesPerBar
                    let endIndex = min(startIndex + samplesPerBar, samples.count)
                    let barSamples = Array(samples[startIndex..<endIndex])
                    
                    // Calculate RMS for this bar segment
                    let rms = sqrt(barSamples.map { $0 * $0 }.reduce(0, +) / Float(barSamples.count))
                    let normalizedHeight = CGFloat(min(1.0, rms * 3)) // Scale up for visibility
                    
                    RoundedRectangle(cornerRadius: 1)
                        .fill(barColor(for: rms))
                        .frame(width: barWidth, height: max(2, geometry.size.height * normalizedHeight))
                }
            }
            .frame(height: geometry.size.height, alignment: .center)
        }
    }
    
    private func barColor(for rms: Float) -> Color {
        if rms > 0.5 {
            return Color.Voxa.error
        } else if rms > 0.1 {
            return Color.Voxa.success
        } else if rms > 0.01 {
            return Color.Voxa.accent
        } else {
            return Color.Voxa.textTertiary
        }
    }
}

// MARK: - Supporting Components (US-701)

/// A row displaying a settings info item with icon, title, and value
struct SettingsInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.Voxa.textSecondary)
                .frame(width: 20)
            
            Text(title)
                .font(Font.Voxa.body)
                .foregroundColor(Color.Voxa.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(Font.Voxa.body)
                .foregroundColor(Color.Voxa.textPrimary)
        }
    }
}

/// A small permission badge showing granted/denied status
struct PermissionBadge: View {
    let icon: String
    let isGranted: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isGranted ? Color.Voxa.successLight : Color.Voxa.errorLight)
                .frame(width: 28, height: 28)
            
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isGranted ? Color.Voxa.success : Color.Voxa.error)
        }
        .overlay(
            Circle()
                .stroke(isGranted ? Color.Voxa.success.opacity(0.3) : Color.Voxa.error.opacity(0.3), lineWidth: 1)
        )
        .help(isGranted ? "Permission granted" : "Permission not granted")
    }
}

/// A compact status indicator for Whisper model status
struct ModelStatusIndicator: View {
    let status: WhisperManager.ModelStatus
    
    private var color: Color {
        switch status {
        case .ready: return Color.Voxa.success
        case .loading, .downloading: return Color.Voxa.warning
        case .switching: return Color.Voxa.accent  // US-008
        case .downloaded: return Color.Voxa.accent
        case .notDownloaded: return Color.Voxa.textTertiary
        case .error: return Color.Voxa.error
        }
    }

    private var text: String {
        switch status {
        case .ready: return "Ready"
        case .loading: return "Loading"
        case .downloading: return "Downloading"
        case .switching: return "Switching"  // US-008
        case .downloaded: return "Downloaded"
        case .notDownloaded: return "Not Loaded"
        case .error: return "Error"
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(Font.Voxa.small)
                .foregroundColor(color)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 2)
        .background(color.opacity(0.12))
        .cornerRadius(CornerRadius.small / 2)
    }
}

/// A pill-shaped status indicator
struct StatusPill: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(Font.Voxa.small)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .cornerRadius(CornerRadius.small / 2)
    }
}

/// A mini badge showing a feature is enabled
struct MiniFeatureBadge: View {
    let icon: String
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.Voxa.accentLight)
                .frame(width: 22, height: 22)
            
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.Voxa.accent)
        }
    }
}

// US-708: SettingsOpenFullButton removed - settings now displayed directly in main window

// MARK: - Main Window Controller

/// Controller for the main application window
/// Handles window state persistence and lifecycle
final class MainWindowController: NSObject {
    private var mainWindow: NSWindow?
    
    /// Audio manager reference for onboarding
    private var audioManager: AudioManager?
    
    /// Hotkey manager reference for onboarding
    private var hotkeyManager: HotkeyManager?
    
    /// UserDefaults keys for window state persistence
    private enum WindowStateKeys {
        static let frameKey = "MainWindowFrame"
        static let wasOpen = "MainWindowWasOpen"
    }
    
    /// Minimum window size (800x600 as specified)
    private let minimumSize = NSSize(width: 800, height: 600)
    
    /// Default window size
    private let defaultSize = NSSize(width: 1000, height: 700)
    
    override init() {
        super.init()
    }
    
    /// Configure with managers for onboarding
    func configure(audioManager: AudioManager, hotkeyManager: HotkeyManager) {
        self.audioManager = audioManager
        self.hotkeyManager = hotkeyManager
    }
    
    /// Show the main window
    /// - Parameter initialNavItem: Optional navigation item to select when window opens
    func showMainWindow(initialNavItem: NavigationItem? = nil) {
        if let existingWindow = mainWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            // US-708: If a specific nav item is requested and window exists, send notification
            // to navigate to that item (the MainWindowView listens for this)
            if let navItem = initialNavItem {
                // Post openSettings notification for settings, or a generic navigation notification
                if navItem == .settings {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
            }
            return
        }
        
        guard let audio = audioManager, let hotkey = hotkeyManager else {
            print("MainWindowController: Error - managers not configured")
            return
        }
        
        let mainView = MainWindowView(initialNavigationItem: initialNavItem)
            .environmentObject(audio)
            .environmentObject(hotkey)
        let hostingController = NSHostingController(rootView: mainView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Voxa"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = NSColor(Color.Voxa.background)
        window.minSize = minimumSize
        window.delegate = self
        
        // Restore saved window frame or use default
        if let savedFrame = loadWindowFrame() {
            window.setFrame(savedFrame, display: true)
        } else {
            window.setContentSize(defaultSize)
            window.center()
        }
        
        // Use autosave for window position
        window.setFrameAutosaveName("MainWindow")
        
        mainWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Mark window as open
        UserDefaults.standard.set(true, forKey: WindowStateKeys.wasOpen)
    }
    
    /// Close the main window
    func closeMainWindow() {
        mainWindow?.close()
    }
    
    /// Check if main window is currently open
    var isWindowOpen: Bool {
        return mainWindow != nil && mainWindow!.isVisible
    }
    
    // MARK: - Window State Persistence
    
    /// Save window frame to UserDefaults
    private func saveWindowFrame() {
        guard let window = mainWindow else { return }
        let frameString = NSStringFromRect(window.frame)
        UserDefaults.standard.set(frameString, forKey: WindowStateKeys.frameKey)
    }
    
    /// Load saved window frame from UserDefaults
    private func loadWindowFrame() -> NSRect? {
        guard let frameString = UserDefaults.standard.string(forKey: WindowStateKeys.frameKey) else {
            return nil
        }
        let frame = NSRectFromString(frameString)
        // Validate frame is reasonable
        if frame.width >= minimumSize.width && frame.height >= minimumSize.height {
            return frame
        }
        return nil
    }
}

// MARK: - NSWindowDelegate

extension MainWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        saveWindowFrame()
        UserDefaults.standard.set(false, forKey: "MainWindowWasOpen")
        mainWindow = nil
    }
    
    func windowDidResize(_ notification: Notification) {
        // Save frame on resize for persistence
        saveWindowFrame()
    }
    
    func windowDidMove(_ notification: Notification) {
        // Save frame when window is moved
        saveWindowFrame()
    }
}

// Note: openSettings notification is already defined in ToastView.swift
// We use the existing Notification.Name.openSettings from there

// MARK: - Preview Provider

#if DEBUG
struct MainWindowView_Previews: PreviewProvider {
    static var previews: some View {
        MainWindowView()
            .environmentObject(AudioManager())
            .environmentObject(HotkeyManager.shared)
            .frame(width: 1000, height: 700)
    }
}
#endif
