import SwiftUI
import AppKit
import ServiceManagement

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
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // MARK: - Sidebar
                sidebarView
                    .frame(width: isSidebarCollapsed ? sidebarCollapsedWidth : sidebarExpandedWidth)
                
                // MARK: - Subtle Separator
                Rectangle()
                    .fill(Color.Wispflow.border.opacity(0.5))
                    .frame(width: 1)
                    .wispflowShadow(.subtle)
                
                // MARK: - Main Content Area
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                windowWidth = newWidth
                // Auto-collapse sidebar when window too small
                withAnimation(WispflowAnimation.smooth) {
                    isSidebarCollapsed = newWidth < collapseThreshold
                }
            }
            .onAppear {
                windowWidth = geometry.size.width
                isSidebarCollapsed = geometry.size.width < collapseThreshold
            }
        }
        .background(Color.Wispflow.background)
    }
    
    // MARK: - Sidebar View
    
    /// Fixed left sidebar with navigation items
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App branding area
            sidebarHeader
            
            Spacer()
                .frame(height: Spacing.lg)
            
            // Navigation items
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(NavigationItem.allCases) { item in
                    NavigationItemRow(
                        item: item,
                        isSelected: selectedItem == item,
                        isCollapsed: isSidebarCollapsed,
                        animationNamespace: animationNamespace,
                        onSelect: {
                            withAnimation(WispflowAnimation.smooth) {
                                selectedItem = item
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, Spacing.md)
            
            Spacer()
            
            // Collapse toggle button
            collapseToggleButton
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.lg)
        }
        .frame(maxHeight: .infinity)
        .background(Color.Wispflow.surface)
    }
    
    // MARK: - Sidebar Header
    
    /// App branding/logo area at top of sidebar
    private var sidebarHeader: some View {
        HStack(spacing: Spacing.md) {
            // App icon
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(
                        LinearGradient(
                            colors: [Color.Wispflow.accent.opacity(0.9), Color.Wispflow.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
            
            if !isSidebarCollapsed {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WispFlow")
                        .font(Font.Wispflow.headline)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    Text("Voice to Text")
                        .font(Font.Wispflow.small)
                        .foregroundColor(Color.Wispflow.textSecondary)
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
            
            Spacer()
        }
        .padding(Spacing.lg)
        .animation(WispflowAnimation.smooth, value: isSidebarCollapsed)
    }
    
    // MARK: - Collapse Toggle Button
    
    /// Button to manually toggle sidebar collapse state
    private var collapseToggleButton: some View {
        Button(action: {
            withAnimation(WispflowAnimation.smooth) {
                isSidebarCollapsed.toggle()
            }
        }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: isSidebarCollapsed ? "sidebar.right" : "sidebar.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.Wispflow.textSecondary)
                
                if !isSidebarCollapsed {
                    Text("Collapse")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .transition(.opacity)
                }
            }
            .padding(Spacing.sm)
            .frame(maxWidth: isSidebarCollapsed ? 44 : .infinity, alignment: isSidebarCollapsed ? .center : .leading)
            .background(Color.Wispflow.border.opacity(0.3))
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
        .animation(WispflowAnimation.tabTransition, value: selectedItem)
    }
}

// MARK: - Navigation Item Row

/// Single navigation item in the sidebar
struct NavigationItemRow: View {
    let item: NavigationItem
    let isSelected: Bool
    let isCollapsed: Bool
    let animationNamespace: Namespace.ID
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                // Icon
                Image(systemName: isSelected ? item.iconName : item.iconNameInactive)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color.Wispflow.accent : Color.Wispflow.textSecondary)
                    .frame(width: 24, height: 24)
                
                // Label (hidden when collapsed)
                if !isCollapsed {
                    Text(item.displayName)
                        .font(Font.Wispflow.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isSelected ? Color.Wispflow.textPrimary : Color.Wispflow.textSecondary)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
                
                if !isCollapsed {
                    Spacer()
                }
            }
            .padding(.horizontal, isCollapsed ? Spacing.md : Spacing.md)
            .padding(.vertical, Spacing.sm + 2)
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .background(
                ZStack {
                    // Selected indicator - left accent bar
                    if isSelected {
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .fill(Color.Wispflow.accentLight)
                            .matchedGeometryEffect(id: "selectedBackground", in: animationNamespace)
                    }
                    
                    // Hover highlight
                    if isHovering && !isSelected {
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .fill(Color.Wispflow.border.opacity(0.4))
                    }
                }
            )
            .overlay(
                // Left accent indicator for selected item
                HStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.Wispflow.accent)
                            .frame(width: 3)
                            .transition(.opacity)
                    }
                    Spacer()
                }
            )
            .cornerRadius(CornerRadius.small)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(WispflowAnimation.quick) {
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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // MARK: - Welcome Message
                welcomeSection
                
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
                
                // MARK: - Recent Activity Timeline
                recentActivitySection
                
                Spacer(minLength: Spacing.xxl)
            }
            .padding(Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Wispflow.background)
    }
    
    // MARK: - Welcome Section
    
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                // Greeting based on time of day
                Text(greetingMessage)
                    .font(Font.Wispflow.largeTitle)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Spacer()
                
                // Current date
                Text(currentDateString)
                    .font(Font.Wispflow.caption)
                    .foregroundColor(Color.Wispflow.textSecondary)
            }
            
            Text("Ready to capture your thoughts")
                .font(Font.Wispflow.body)
                .foregroundColor(Color.Wispflow.textSecondary)
        }
    }
    
    /// Time-based greeting message
    private var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning"
        } else if hour < 17 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }
    
    /// Current date string
    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Your Activity")
                .font(Font.Wispflow.headline)
                .foregroundColor(Color.Wispflow.textPrimary)
            
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
                    iconColor: Color.Wispflow.accent
                )
                
                // Average WPM
                StatCard(
                    icon: "speedometer",
                    value: String(format: "%.0f", statsManager.averageWPM),
                    label: "Avg WPM",
                    iconColor: Color.Wispflow.info
                )
                
                // Total Transcriptions
                StatCard(
                    icon: "waveform",
                    value: "\(statsManager.totalTranscriptions)",
                    label: "Recordings",
                    iconColor: Color.Wispflow.success
                )
            }
        }
    }
    
    /// Empty state for stats section showing onboarding prompt
    private var emptyStatsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Get Started")
                .font(Font.Wispflow.headline)
                .foregroundColor(Color.Wispflow.textPrimary)
            
            HStack(spacing: Spacing.lg) {
                Image(systemName: "waveform.badge.plus")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(Color.Wispflow.accent)
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Record your first transcription")
                        .font(Font.Wispflow.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    Text("Press ⌘⇧Space anywhere to start recording")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                }
                
                Spacer()
            }
            .padding(Spacing.lg)
            .background(Color.Wispflow.accentLight)
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
                            colors: [Color.Wispflow.accent.opacity(0.8), Color.Wispflow.accent],
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
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Text("Enable intelligent formatting and punctuation in Settings → Text Cleanup")
                    .font(Font.Wispflow.caption)
                    .foregroundColor(Color.Wispflow.textSecondary)
            }
            
            Spacer()
            
            Button(action: {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }) {
                Text("Settings")
                    .font(Font.Wispflow.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color.Wispflow.accent)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.Wispflow.accentLight)
                    .cornerRadius(CornerRadius.small)
            }
            .buttonStyle(InteractiveScaleStyle())
        }
        .padding(Spacing.lg)
        .background(Color.Wispflow.surface)
        .cornerRadius(CornerRadius.medium)
        .wispflowShadow(.subtle)
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Quick Actions")
                .font(Font.Wispflow.headline)
                .foregroundColor(Color.Wispflow.textPrimary)
            
            HStack(spacing: Spacing.lg) {
                ForEach(QuickAction.allCases) { action in
                    QuickActionCard(
                        action: action,
                        isHovered: hoveredQuickAction == action,
                        onHover: { isHovering in
                            withAnimation(WispflowAnimation.quick) {
                                hoveredQuickAction = isHovering ? action : nil
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Recent Activity Section
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Recent Activity")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Spacer()
                
                if !statsManager.recentEntries.isEmpty {
                    Text("\(statsManager.recentEntries.count) entries")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                }
            }
            
            if statsManager.recentEntries.isEmpty {
                // Empty state
                emptyActivityState
            } else {
                // Activity timeline
                activityTimeline
            }
        }
    }
    
    /// Empty state for activity section
    private var emptyActivityState: some View {
        HStack {
            Spacer()
            VStack(spacing: Spacing.md) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(Color.Wispflow.textTertiary)
                
                Text("No transcriptions yet")
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.textSecondary)
                
                Text("Your recent activity will appear here")
                    .font(Font.Wispflow.caption)
                    .foregroundColor(Color.Wispflow.textTertiary)
            }
            .padding(.vertical, Spacing.xxl)
            Spacer()
        }
        .background(Color.Wispflow.surfaceSecondary.opacity(0.5))
        .cornerRadius(CornerRadius.medium)
    }
    
    /// Activity timeline with dated entries
    private var activityTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group entries by date
            ForEach(groupedEntries.keys.sorted(by: >), id: \.self) { date in
                if let entries = groupedEntries[date] {
                    // Date header
                    dateHeader(for: date)
                    
                    // Entries for this date
                    ForEach(entries) { entry in
                        ActivityTimelineEntry(entry: entry)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.Wispflow.surface)
        .cornerRadius(CornerRadius.medium)
        .wispflowShadow(.subtle)
    }
    
    /// Group entries by date
    private var groupedEntries: [Date: [TranscriptionEntry]] {
        let calendar = Calendar.current
        var groups: [Date: [TranscriptionEntry]] = [:]
        
        for entry in statsManager.recentEntries {
            let dateKey = calendar.startOfDay(for: entry.timestamp)
            if groups[dateKey] == nil {
                groups[dateKey] = []
            }
            groups[dateKey]?.append(entry)
        }
        
        return groups
    }
    
    /// Date header for activity timeline
    private func dateHeader(for date: Date) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let label: String
        if calendar.isDate(date, inSameDayAs: today) {
            label = "Today"
        } else if calendar.isDate(date, inSameDayAs: yesterday) {
            label = "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d"
            label = formatter.string(from: date)
        }
        
        return Text(label)
            .font(Font.Wispflow.caption)
            .fontWeight(.semibold)
            .foregroundColor(Color.Wispflow.textSecondary)
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.xs)
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
                .font(Font.Wispflow.title)
                .foregroundColor(Color.Wispflow.textPrimary)
            
            // Label
            Text(label)
                .font(Font.Wispflow.caption)
                .foregroundColor(Color.Wispflow.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(Color.Wispflow.surface)
        .cornerRadius(CornerRadius.medium)
        .wispflowShadow(.subtle)
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
            return "Configure WispFlow preferences"
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
            return Color.Wispflow.accent
        case .viewHistory:
            return Color.Wispflow.info
        case .openSnippets:
            return Color.Wispflow.success
        case .openSettings:
            return Color.Wispflow.textSecondary
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
                    .font(Font.Wispflow.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                // Description
                Text(action.description)
                    .font(Font.Wispflow.small)
                    .foregroundColor(Color.Wispflow.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .padding(.horizontal, Spacing.md)
            .background(Color.Wispflow.surface)
            .cornerRadius(CornerRadius.medium)
            // Hover lift effect: shadow and slight scale
            .wispflowShadow(isHovered ? .card : .subtle)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .offset(y: isHovered ? -2 : 0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            onHover(hovering)
        }
        .animation(WispflowAnimation.quick, value: isHovered)
    }
    
    private func performAction() {
        switch action {
        case .newRecording:
            // Note: Recording is triggered via hotkey, show hint
            // Could post notification to show recording hint
            print("QuickAction: New Recording tapped - use hotkey ⌘⇧Space")
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
                        .fill(Color.Wispflow.accent)
                        .frame(width: 8, height: 8)
                    
                    Rectangle()
                        .fill(Color.Wispflow.border)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 20)
                
                // Entry content
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        // Timestamp
                        Text(entry.timeString)
                            .font(Font.Wispflow.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Wispflow.textSecondary)
                        
                        // Word count badge
                        Text("\(entry.wordCount) words")
                            .font(Font.Wispflow.small)
                            .foregroundColor(Color.Wispflow.textTertiary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.Wispflow.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                        
                        Spacer()
                        
                        // Expand/collapse button
                        Button(action: { 
                            withAnimation(WispflowAnimation.quick) {
                                isExpanded.toggle() 
                            }
                        }) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color.Wispflow.textTertiary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .opacity(isHovered || isExpanded ? 1 : 0)
                    }
                    
                    // Text preview
                    Text(entry.textPreview)
                        .font(Font.Wispflow.body)
                        .foregroundColor(Color.Wispflow.textPrimary)
                        .lineLimit(isExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // WPM info when expanded
                    if isExpanded {
                        HStack(spacing: Spacing.md) {
                            Label(String(format: "%.0f WPM", entry.wordsPerMinute), systemImage: "speedometer")
                            Label(String(format: "%.1fs", entry.durationSeconds), systemImage: "clock")
                        }
                        .font(Font.Wispflow.small)
                        .foregroundColor(Color.Wispflow.textTertiary)
                        .padding(.top, Spacing.xs)
                    }
                }
                .padding(.vertical, Spacing.sm)
            }
            .padding(.horizontal, Spacing.sm)
            .background(isHovered ? Color.Wispflow.surfaceSecondary.opacity(0.5) : Color.clear)
            .cornerRadius(CornerRadius.small)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(WispflowAnimation.quick) {
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
                .background(Color.Wispflow.border)
            
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
        .background(Color.Wispflow.background)
        .alert("Delete Transcription?", isPresented: $showDeleteConfirmation, presenting: entryToDelete) { entry in
            Button("Delete", role: .destructive) {
                withAnimation(WispflowAnimation.smooth) {
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
                    .font(Font.Wispflow.largeTitle)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Spacer()
                
                // Entry count badge
                if !statsManager.recentEntries.isEmpty {
                    Text("\(statsManager.recentEntries.count) \(statsManager.recentEntries.count == 1 ? "entry" : "entries")")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.Wispflow.surfaceSecondary)
                        .cornerRadius(CornerRadius.small)
                }
            }
            
            // Search bar
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.Wispflow.textTertiary)
                
                TextField("Search transcriptions...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                if !searchQuery.isEmpty {
                    Button(action: {
                        withAnimation(WispflowAnimation.quick) {
                            searchQuery = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.Wispflow.textTertiary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.Wispflow.surface)
            .cornerRadius(CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(Color.Wispflow.border, lineWidth: 1)
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
                    .fill(Color.Wispflow.accentLight)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(Color.Wispflow.accent)
            }
            
            VStack(spacing: Spacing.sm) {
                Text("No transcription history")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Text("Your transcriptions will appear here after you record them.\nPress ⌘⇧Space to start recording.")
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.textSecondary)
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
                    .fill(Color.Wispflow.surfaceSecondary)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(Color.Wispflow.textTertiary)
            }
            
            VStack(spacing: Spacing.sm) {
                Text("No results found")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Text("No transcriptions match \"\(searchQuery)\".\nTry a different search term.")
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                withAnimation(WispflowAnimation.quick) {
                    searchQuery = ""
                }
            }) {
                Text("Clear Search")
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.accent)
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
        .animation(WispflowAnimation.smooth, value: filteredEntries.count)
    }
    
    // MARK: - Date Category Section
    
    private func dateCategorySection(category: DateCategory, entries: [TranscriptionEntry]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Category header
            HStack {
                Text(category.displayName)
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textSecondary)
                
                Spacer()
                
                Text("\(entries.count)")
                    .font(Font.Wispflow.caption)
                    .foregroundColor(Color.Wispflow.textTertiary)
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
                        .font(Font.Wispflow.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    HStack(spacing: Spacing.sm) {
                        // Word count badge
                        Label("\(entry.wordCount) words", systemImage: "text.word.spacing")
                            .font(Font.Wispflow.small)
                            .foregroundColor(Color.Wispflow.textTertiary)
                        
                        // Duration badge
                        Label(String(format: "%.1fs", entry.durationSeconds), systemImage: "clock")
                            .font(Font.Wispflow.small)
                            .foregroundColor(Color.Wispflow.textTertiary)
                        
                        // WPM badge
                        Label(String(format: "%.0f WPM", entry.wordsPerMinute), systemImage: "speedometer")
                            .font(Font.Wispflow.small)
                            .foregroundColor(Color.Wispflow.textTertiary)
                    }
                }
                
                Spacer()
                
                // Action buttons (visible on hover or when expanded)
                HStack(spacing: Spacing.sm) {
                    // Copy button
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.Wispflow.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Color.Wispflow.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Copy to clipboard")
                    
                    // Delete button
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.Wispflow.error)
                            .frame(width: 28, height: 28)
                            .background(Color.Wispflow.errorLight)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Delete transcription")
                    
                    // Expand/collapse button
                    Button(action: {
                        withAnimation(WispflowAnimation.quick) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.Wispflow.textTertiary)
                            .frame(width: 28, height: 28)
                            .background(Color.Wispflow.surfaceSecondary)
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
                        .font(Font.Wispflow.body)
                        .foregroundColor(Color.Wispflow.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // Preview text when collapsed
                    Text(highlightedText(entry.textPreview))
                        .font(Font.Wispflow.body)
                        .foregroundColor(Color.Wispflow.textPrimary)
                        .lineLimit(2)
                    
                    // Show "more" indicator if text is longer than preview
                    if entry.fullText.count > entry.textPreview.count {
                        Text("Click to see full text...")
                            .font(Font.Wispflow.small)
                            .foregroundColor(Color.Wispflow.accent)
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.Wispflow.surface)
        .cornerRadius(CornerRadius.medium)
        .wispflowShadow(isHovered ? .card : .subtle)
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(WispflowAnimation.quick) {
                isExpanded.toggle()
            }
        }
        .onHover { hovering in
            withAnimation(WispflowAnimation.quick) {
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
                attributedString[attrRange].backgroundColor = Color.Wispflow.warningLight
                attributedString[attrRange].foregroundColor = Color.Wispflow.textPrimary
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
                .background(Color.Wispflow.border)
            
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
        .background(Color.Wispflow.background)
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
                withAnimation(WispflowAnimation.smooth) {
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
                    .font(Font.Wispflow.largeTitle)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Spacer()
                
                // View toggle (grid/list)
                HStack(spacing: Spacing.xs) {
                    Button(action: {
                        withAnimation(WispflowAnimation.quick) {
                            isGridView = true
                        }
                    }) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isGridView ? Color.Wispflow.accent : Color.Wispflow.textTertiary)
                            .frame(width: 28, height: 28)
                            .background(isGridView ? Color.Wispflow.accentLight : Color.clear)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Grid view")
                    
                    Button(action: {
                        withAnimation(WispflowAnimation.quick) {
                            isGridView = false
                        }
                    }) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(!isGridView ? Color.Wispflow.accent : Color.Wispflow.textTertiary)
                            .frame(width: 28, height: 28)
                            .background(!isGridView ? Color.Wispflow.accentLight : Color.clear)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("List view")
                }
                .padding(2)
                .background(Color.Wispflow.surfaceSecondary)
                .cornerRadius(CornerRadius.small)
                
                // Create new snippet button
                Button(action: {
                    showCreateSheet = true
                }) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("New Snippet")
                            .font(Font.Wispflow.body)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.Wispflow.accent)
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
                        .foregroundColor(Color.Wispflow.textTertiary)
                    
                    TextField("Search snippets...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(Font.Wispflow.body)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    if !searchQuery.isEmpty {
                        Button(action: {
                            withAnimation(WispflowAnimation.quick) {
                                searchQuery = ""
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.Wispflow.textTertiary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.Wispflow.surface)
                .cornerRadius(CornerRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .stroke(Color.Wispflow.border, lineWidth: 1)
                )
                
                Spacer()
                
                // Snippet count badge
                if !snippetsManager.isEmpty {
                    Text("\(snippetsManager.count) \(snippetsManager.count == 1 ? "snippet" : "snippets")")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.Wispflow.surfaceSecondary)
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
                    .fill(Color.Wispflow.accentLight)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(Color.Wispflow.accent)
            }
            
            VStack(spacing: Spacing.sm) {
                Text("No snippets yet")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Text("Create your first snippet to save frequently used text.\nYou can assign keyboard shortcuts for quick access.")
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.textSecondary)
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
                .font(Font.Wispflow.body)
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(Color.Wispflow.accent)
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
                    .fill(Color.Wispflow.surfaceSecondary)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(Color.Wispflow.textTertiary)
            }
            
            VStack(spacing: Spacing.sm) {
                Text("No snippets found")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Text("No snippets match \"\(searchQuery)\".\nTry a different search term.")
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                withAnimation(WispflowAnimation.quick) {
                    searchQuery = ""
                }
            }) {
                Text("Clear Search")
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.accent)
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
        .animation(WispflowAnimation.smooth, value: filteredSnippets.count)
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
                        .font(Font.Wispflow.headline)
                        .foregroundColor(Color.Wispflow.textPrimary)
                        .lineLimit(1)
                    
                    // Shortcut badge if assigned
                    if let shortcut = snippet.shortcut, !shortcut.isEmpty {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "keyboard")
                                .font(.system(size: 10, weight: .medium))
                            Text(shortcut)
                                .font(Font.Wispflow.monoSmall)
                        }
                        .foregroundColor(Color.Wispflow.accent)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Color.Wispflow.accentLight)
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
                            .foregroundColor(Color.Wispflow.textSecondary)
                            .frame(width: 26, height: 26)
                            .background(Color.Wispflow.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Copy to clipboard")
                    
                    // Edit button
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.Wispflow.textSecondary)
                            .frame(width: 26, height: 26)
                            .background(Color.Wispflow.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Edit snippet")
                    
                    // Delete button
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.Wispflow.error)
                            .frame(width: 26, height: 26)
                            .background(Color.Wispflow.errorLight)
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
                        .font(Font.Wispflow.body)
                        .foregroundColor(Color.Wispflow.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(highlightedText(snippet.contentPreview))
                        .font(Font.Wispflow.body)
                        .foregroundColor(Color.Wispflow.textPrimary)
                        .lineLimit(3)
                }
                
                // Show more/less toggle
                if snippet.content.count > 100 {
                    Button(action: {
                        withAnimation(WispflowAnimation.quick) {
                            isExpanded.toggle()
                        }
                    }) {
                        Text(isExpanded ? "Show less" : "Show more")
                            .font(Font.Wispflow.small)
                            .foregroundColor(Color.Wispflow.accent)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Footer with metadata
            HStack {
                // Word/character count
                Text("\(snippet.wordCount) words • \(snippet.characterCount) chars")
                    .font(Font.Wispflow.small)
                    .foregroundColor(Color.Wispflow.textTertiary)
                
                Spacer()
                
                // Last updated
                Text("Updated \(snippet.updatedRelativeString)")
                    .font(Font.Wispflow.small)
                    .foregroundColor(Color.Wispflow.textTertiary)
            }
        }
        .padding(Spacing.lg)
        .background(Color.Wispflow.surface)
        .cornerRadius(CornerRadius.medium)
        .wispflowShadow(isHovered ? .card : .subtle)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(WispflowAnimation.quick) {
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
                attributedString[attrRange].backgroundColor = Color.Wispflow.warningLight
                attributedString[attrRange].foregroundColor = Color.Wispflow.textPrimary
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
                        .fill(Color.Wispflow.accentLight)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "doc.text")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.Wispflow.accent)
                }
                
                // Title and shortcut
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(highlightedText(snippet.title))
                        .font(Font.Wispflow.body)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.Wispflow.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: Spacing.sm) {
                        // Shortcut badge
                        if let shortcut = snippet.shortcut, !shortcut.isEmpty {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "keyboard")
                                    .font(.system(size: 9, weight: .medium))
                                Text(shortcut)
                                    .font(Font.Wispflow.monoSmall)
                            }
                            .foregroundColor(Color.Wispflow.accent)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.Wispflow.accentLight)
                            .cornerRadius(CornerRadius.small)
                        }
                        
                        // Word count
                        Text("\(snippet.wordCount) words")
                            .font(Font.Wispflow.small)
                            .foregroundColor(Color.Wispflow.textTertiary)
                        
                        // Updated date
                        Text("• \(snippet.updatedRelativeString)")
                            .font(Font.Wispflow.small)
                            .foregroundColor(Color.Wispflow.textTertiary)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: Spacing.xs) {
                    // Copy button
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.Wispflow.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Color.Wispflow.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Copy to clipboard")
                    
                    // Edit button
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.Wispflow.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Color.Wispflow.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Edit snippet")
                    
                    // Delete button
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.Wispflow.error)
                            .frame(width: 28, height: 28)
                            .background(Color.Wispflow.errorLight)
                            .cornerRadius(CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Delete snippet")
                    
                    // Expand/collapse button
                    Button(action: {
                        withAnimation(WispflowAnimation.quick) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.Wispflow.textTertiary)
                            .frame(width: 28, height: 28)
                            .background(Color.Wispflow.surfaceSecondary)
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
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.textPrimary)
                    .textSelection(.enabled)
                    .padding(.leading, 40 + Spacing.md) // Align with title
                    .padding(.top, Spacing.sm)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .background(Color.Wispflow.surface)
        .cornerRadius(CornerRadius.medium)
        .wispflowShadow(isHovered ? .card : .subtle)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(WispflowAnimation.quick) {
                isExpanded.toggle()
            }
        }
        .onHover { hovering in
            withAnimation(WispflowAnimation.quick) {
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
                attributedString[attrRange].backgroundColor = Color.Wispflow.warningLight
                attributedString[attrRange].foregroundColor = Color.Wispflow.textPrimary
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
                    .font(Font.Wispflow.title)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Color.Wispflow.surfaceSecondary)
                        .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(Spacing.lg)
            .background(Color.Wispflow.surface)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Title field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Title")
                            .font(Font.Wispflow.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Wispflow.textSecondary)
                        
                        TextField("Enter snippet title...", text: $title)
                            .textFieldStyle(.plain)
                            .font(Font.Wispflow.body)
                            .foregroundColor(Color.Wispflow.textPrimary)
                            .padding(Spacing.md)
                            .background(Color.Wispflow.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .stroke(Color.Wispflow.border, lineWidth: 1)
                            )
                            .focused($focusedField, equals: .title)
                    }
                    
                    // Content field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Content")
                            .font(Font.Wispflow.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Wispflow.textSecondary)
                        
                        TextEditor(text: $content)
                            .font(Font.Wispflow.body)
                            .foregroundColor(Color.Wispflow.textPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(Spacing.sm)
                            .frame(minHeight: 150, maxHeight: 300)
                            .background(Color.Wispflow.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .stroke(Color.Wispflow.border, lineWidth: 1)
                            )
                            .focused($focusedField, equals: .content)
                        
                        Text("Tip: You can paste formatted text or multiple paragraphs")
                            .font(Font.Wispflow.small)
                            .foregroundColor(Color.Wispflow.textTertiary)
                    }
                    
                    // Optional shortcut field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Button(action: {
                            withAnimation(WispflowAnimation.quick) {
                                showShortcutField.toggle()
                            }
                        }) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: showShortcutField ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                Image(systemName: "keyboard")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Add Keyboard Shortcut (Optional)")
                                    .font(Font.Wispflow.body)
                            }
                            .foregroundColor(Color.Wispflow.textSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if showShortcutField {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                TextField("e.g., !sig, //email, @reply", text: $shortcut)
                                    .textFieldStyle(.plain)
                                    .font(Font.Wispflow.mono)
                                    .foregroundColor(Color.Wispflow.textPrimary)
                                    .padding(Spacing.md)
                                    .background(Color.Wispflow.surfaceSecondary)
                                    .cornerRadius(CornerRadius.small)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.small)
                                            .stroke(shortcutError != nil ? Color.Wispflow.error : Color.Wispflow.border, lineWidth: 1)
                                    )
                                    .focused($focusedField, equals: .shortcut)
                                    .onChange(of: shortcut) { _, newValue in
                                        validateShortcut(newValue)
                                    }
                                
                                if let error = shortcutError {
                                    Text(error)
                                        .font(Font.Wispflow.small)
                                        .foregroundColor(Color.Wispflow.error)
                                } else {
                                    Text("Type this shortcut text to quickly insert the snippet")
                                        .font(Font.Wispflow.small)
                                        .foregroundColor(Color.Wispflow.textTertiary)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .padding(Spacing.lg)
            }
            .background(Color.Wispflow.background)
            
            Divider()
            
            // Footer with action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(WispflowButtonStyle(variant: .secondary))
                
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
                .buttonStyle(WispflowButtonStyle(variant: .primary))
                .disabled(!isValid)
            }
            .padding(Spacing.lg)
            .background(Color.Wispflow.surface)
        }
        .frame(width: 500, height: 550)
        .background(Color.Wispflow.background)
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
                    .font(Font.Wispflow.title)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Color.Wispflow.surfaceSecondary)
                        .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(Spacing.lg)
            .background(Color.Wispflow.surface)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Title field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Title")
                            .font(Font.Wispflow.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Wispflow.textSecondary)
                        
                        TextField("Enter snippet title...", text: $title)
                            .textFieldStyle(.plain)
                            .font(Font.Wispflow.body)
                            .foregroundColor(Color.Wispflow.textPrimary)
                            .padding(Spacing.md)
                            .background(Color.Wispflow.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .stroke(Color.Wispflow.border, lineWidth: 1)
                            )
                            .focused($focusedField, equals: .title)
                    }
                    
                    // Content field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Content")
                            .font(Font.Wispflow.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Wispflow.textSecondary)
                        
                        TextEditor(text: $content)
                            .font(Font.Wispflow.body)
                            .foregroundColor(Color.Wispflow.textPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(Spacing.sm)
                            .frame(minHeight: 150, maxHeight: 300)
                            .background(Color.Wispflow.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .stroke(Color.Wispflow.border, lineWidth: 1)
                            )
                            .focused($focusedField, equals: .content)
                    }
                    
                    // Shortcut field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Button(action: {
                            withAnimation(WispflowAnimation.quick) {
                                showShortcutField.toggle()
                            }
                        }) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: showShortcutField ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                Image(systemName: "keyboard")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Keyboard Shortcut")
                                    .font(Font.Wispflow.body)
                                
                                if snippet.shortcut != nil && !snippet.shortcut!.isEmpty {
                                    Text("(\(snippet.shortcut!))")
                                        .font(Font.Wispflow.mono)
                                        .foregroundColor(Color.Wispflow.accent)
                                }
                            }
                            .foregroundColor(Color.Wispflow.textSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if showShortcutField {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                TextField("e.g., !sig, //email, @reply", text: $shortcut)
                                    .textFieldStyle(.plain)
                                    .font(Font.Wispflow.mono)
                                    .foregroundColor(Color.Wispflow.textPrimary)
                                    .padding(Spacing.md)
                                    .background(Color.Wispflow.surfaceSecondary)
                                    .cornerRadius(CornerRadius.small)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.small)
                                            .stroke(shortcutError != nil ? Color.Wispflow.error : Color.Wispflow.border, lineWidth: 1)
                                    )
                                    .focused($focusedField, equals: .shortcut)
                                    .onChange(of: shortcut) { _, newValue in
                                        validateShortcut(newValue)
                                    }
                                
                                if let error = shortcutError {
                                    Text(error)
                                        .font(Font.Wispflow.small)
                                        .foregroundColor(Color.Wispflow.error)
                                } else {
                                    Text("Leave empty to remove shortcut")
                                        .font(Font.Wispflow.small)
                                        .foregroundColor(Color.Wispflow.textTertiary)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Created: \(formatDate(snippet.createdAt))")
                            .font(Font.Wispflow.small)
                            .foregroundColor(Color.Wispflow.textTertiary)
                        Text("Last updated: \(formatDate(snippet.updatedAt))")
                            .font(Font.Wispflow.small)
                            .foregroundColor(Color.Wispflow.textTertiary)
                    }
                    .padding(.top, Spacing.md)
                }
                .padding(Spacing.lg)
            }
            .background(Color.Wispflow.background)
            
            Divider()
            
            // Footer with action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(WispflowButtonStyle(variant: .secondary))
                
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
                .buttonStyle(WispflowButtonStyle(variant: .primary))
                .disabled(!isValid || !hasChanges)
            }
            .padding(Spacing.lg)
            .background(Color.Wispflow.surface)
        }
        .frame(width: 500, height: 580)
        .background(Color.Wispflow.background)
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
                .background(Color.Wispflow.border)
            
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
        .background(Color.Wispflow.background)
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
                withAnimation(WispflowAnimation.smooth) {
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
                    .font(Font.Wispflow.largeTitle)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
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
                                .font(Font.Wispflow.caption)
                        }
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.Wispflow.surfaceSecondary)
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
                                .font(Font.Wispflow.caption)
                        }
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.Wispflow.surfaceSecondary)
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
                            .font(Font.Wispflow.body)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.Wispflow.accent)
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
                        .foregroundColor(Color.Wispflow.textTertiary)
                    
                    TextField("Search dictionary...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(Font.Wispflow.body)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    if !searchQuery.isEmpty {
                        Button(action: {
                            withAnimation(WispflowAnimation.quick) {
                                searchQuery = ""
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.Wispflow.textTertiary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.Wispflow.surface)
                .cornerRadius(CornerRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .stroke(Color.Wispflow.border, lineWidth: 1)
                )
                
                Spacer()
                
                // Word count and last updated info
                if !dictionaryManager.isEmpty {
                    HStack(spacing: Spacing.md) {
                        // Word count badge
                        Text("\(dictionaryManager.count) \(dictionaryManager.count == 1 ? "word" : "words")")
                            .font(Font.Wispflow.caption)
                            .foregroundColor(Color.Wispflow.textSecondary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(Color.Wispflow.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                        
                        // Last updated info
                        if let lastUpdated = dictionaryManager.lastUpdated {
                            Text("Updated \(formatRelativeDate(lastUpdated))")
                                .font(Font.Wispflow.small)
                                .foregroundColor(Color.Wispflow.textTertiary)
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
                    .fill(Color.Wispflow.accentLight)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "character.book.closed")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(Color.Wispflow.accent)
            }
            
            VStack(spacing: Spacing.sm) {
                Text("No custom words yet")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Text("Add words and phrases to improve transcription accuracy.\nCustom words help WispFlow recognize specialized terms,\nnames, and uncommon pronunciations.")
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.textSecondary)
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
            .background(Color.Wispflow.surface)
            .cornerRadius(CornerRadius.medium)
            .wispflowShadow(.subtle)
            
            Button(action: {
                showCreateSheet = true
            }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text("Add First Word")
                        .fontWeight(.medium)
                }
                .font(Font.Wispflow.body)
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(Color.Wispflow.accent)
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
                    .fill(Color.Wispflow.surfaceSecondary)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(Color.Wispflow.textTertiary)
            }
            
            VStack(spacing: Spacing.sm) {
                Text("No words found")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Text("No entries match \"\(searchQuery)\".\nTry a different search term.")
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                withAnimation(WispflowAnimation.quick) {
                    searchQuery = ""
                }
            }) {
                Text("Clear Search")
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.accent)
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
        .animation(WispflowAnimation.smooth, value: filteredEntries.count)
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
        savePanel.nameFieldStringValue = "wispflow-dictionary.txt"
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
                .foregroundColor(Color.Wispflow.accent)
                .frame(width: 20)
            
            Text(text)
                .font(Font.Wispflow.body)
                .foregroundColor(Color.Wispflow.textSecondary)
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
                    .fill(Color.Wispflow.accentLight)
                    .frame(width: 40, height: 40)
                
                Text(String(entry.word.prefix(1)).uppercased())
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.accent)
            }
            
            // Word and hint
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(highlightedText(entry.word))
                    .font(Font.Wispflow.body)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                HStack(spacing: Spacing.sm) {
                    // Pronunciation hint badge
                    if let hint = entry.pronunciationHint, !hint.isEmpty {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "waveform")
                                .font(.system(size: 9, weight: .medium))
                            Text(highlightedText(hint))
                                .font(Font.Wispflow.small)
                        }
                        .foregroundColor(Color.Wispflow.accent)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Color.Wispflow.accentLight)
                        .cornerRadius(CornerRadius.small)
                    }
                    
                    // Updated date
                    Text("Updated \(entry.updatedRelativeString)")
                        .font(Font.Wispflow.small)
                        .foregroundColor(Color.Wispflow.textTertiary)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: Spacing.xs) {
                // Edit button
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Color.Wispflow.surfaceSecondary)
                        .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Edit entry")
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.Wispflow.error)
                        .frame(width: 28, height: 28)
                        .background(Color.Wispflow.errorLight)
                        .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Delete entry")
            }
            .opacity(isHovered ? 1 : 0.5)
        }
        .padding(Spacing.md)
        .background(Color.Wispflow.surface)
        .cornerRadius(CornerRadius.medium)
        .wispflowShadow(isHovered ? .card : .subtle)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(WispflowAnimation.quick) {
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
                attributedString[attrRange].backgroundColor = Color.Wispflow.warningLight
                attributedString[attrRange].foregroundColor = Color.Wispflow.textPrimary
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
                    .font(Font.Wispflow.title)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Color.Wispflow.surfaceSecondary)
                        .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(Spacing.lg)
            .background(Color.Wispflow.surface)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Word field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Word or Phrase")
                            .font(Font.Wispflow.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Wispflow.textSecondary)
                        
                        TextField("Enter word or phrase...", text: $word)
                            .textFieldStyle(.plain)
                            .font(Font.Wispflow.body)
                            .foregroundColor(Color.Wispflow.textPrimary)
                            .padding(Spacing.md)
                            .background(Color.Wispflow.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .stroke(wordError != nil ? Color.Wispflow.error : Color.Wispflow.border, lineWidth: 1)
                            )
                            .focused($focusedField, equals: .word)
                            .onChange(of: word) { _, newValue in
                                validateWord(newValue)
                            }
                        
                        if let error = wordError {
                            Text(error)
                                .font(Font.Wispflow.small)
                                .foregroundColor(Color.Wispflow.error)
                        } else {
                            Text("Add technical terms, names, or uncommon words")
                                .font(Font.Wispflow.small)
                                .foregroundColor(Color.Wispflow.textTertiary)
                        }
                    }
                    
                    // Optional pronunciation hint field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Button(action: {
                            withAnimation(WispflowAnimation.quick) {
                                showHintField.toggle()
                            }
                        }) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: showHintField ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                Image(systemName: "waveform")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Add Pronunciation Hint (Optional)")
                                    .font(Font.Wispflow.body)
                            }
                            .foregroundColor(Color.Wispflow.textSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if showHintField {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                TextField("e.g., 'jif' for GIF, 'SEE-kwel' for SQL", text: $pronunciationHint)
                                    .textFieldStyle(.plain)
                                    .font(Font.Wispflow.body)
                                    .foregroundColor(Color.Wispflow.textPrimary)
                                    .padding(Spacing.md)
                                    .background(Color.Wispflow.surfaceSecondary)
                                    .cornerRadius(CornerRadius.small)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.small)
                                            .stroke(Color.Wispflow.border, lineWidth: 1)
                                    )
                                    .focused($focusedField, equals: .hint)
                                
                                Text("Helps the transcription engine recognize how you say this word")
                                    .font(Font.Wispflow.small)
                                    .foregroundColor(Color.Wispflow.textTertiary)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    
                    // Examples section
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Examples")
                            .font(Font.Wispflow.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Wispflow.textSecondary)
                        
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            DictionaryExampleRow(word: "WispFlow", hint: "WISP-flow")
                            DictionaryExampleRow(word: "GitHub", hint: "git-hub")
                            DictionaryExampleRow(word: "Kubernetes", hint: "koo-ber-NET-eez")
                            DictionaryExampleRow(word: "Dr. Smith", hint: nil)
                        }
                        .padding(Spacing.md)
                        .background(Color.Wispflow.surfaceSecondary)
                        .cornerRadius(CornerRadius.small)
                    }
                }
                .padding(Spacing.lg)
            }
            .background(Color.Wispflow.background)
            
            Divider()
            
            // Footer with action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(WispflowButtonStyle(variant: .secondary))
                
                Spacer()
                
                Button("Add Word") {
                    let trimmedHint = pronunciationHint.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(
                        word.trimmingCharacters(in: .whitespacesAndNewlines),
                        trimmedHint.isEmpty ? nil : trimmedHint
                    )
                    dismiss()
                }
                .buttonStyle(WispflowButtonStyle(variant: .primary))
                .disabled(!isValid)
            }
            .padding(Spacing.lg)
            .background(Color.Wispflow.surface)
        }
        .frame(width: 450, height: 480)
        .background(Color.Wispflow.background)
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
                    .font(Font.Wispflow.title)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Color.Wispflow.surfaceSecondary)
                        .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(Spacing.lg)
            .background(Color.Wispflow.surface)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Word field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Word or Phrase")
                            .font(Font.Wispflow.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Wispflow.textSecondary)
                        
                        TextField("Enter word or phrase...", text: $word)
                            .textFieldStyle(.plain)
                            .font(Font.Wispflow.body)
                            .foregroundColor(Color.Wispflow.textPrimary)
                            .padding(Spacing.md)
                            .background(Color.Wispflow.surfaceSecondary)
                            .cornerRadius(CornerRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .stroke(wordError != nil ? Color.Wispflow.error : Color.Wispflow.border, lineWidth: 1)
                            )
                            .focused($focusedField, equals: .word)
                            .onChange(of: word) { _, newValue in
                                validateWord(newValue)
                            }
                        
                        if let error = wordError {
                            Text(error)
                                .font(Font.Wispflow.small)
                                .foregroundColor(Color.Wispflow.error)
                        }
                    }
                    
                    // Pronunciation hint field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Button(action: {
                            withAnimation(WispflowAnimation.quick) {
                                showHintField.toggle()
                            }
                        }) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: showHintField ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                Image(systemName: "waveform")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Pronunciation Hint")
                                    .font(Font.Wispflow.body)
                                
                                if entry.pronunciationHint != nil && !entry.pronunciationHint!.isEmpty {
                                    Text("(\(entry.pronunciationHint!))")
                                        .font(Font.Wispflow.small)
                                        .foregroundColor(Color.Wispflow.accent)
                                }
                            }
                            .foregroundColor(Color.Wispflow.textSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if showHintField {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                TextField("e.g., 'jif' for GIF, 'SEE-kwel' for SQL", text: $pronunciationHint)
                                    .textFieldStyle(.plain)
                                    .font(Font.Wispflow.body)
                                    .foregroundColor(Color.Wispflow.textPrimary)
                                    .padding(Spacing.md)
                                    .background(Color.Wispflow.surfaceSecondary)
                                    .cornerRadius(CornerRadius.small)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.small)
                                            .stroke(Color.Wispflow.border, lineWidth: 1)
                                    )
                                    .focused($focusedField, equals: .hint)
                                
                                Text("Leave empty to remove pronunciation hint")
                                    .font(Font.Wispflow.small)
                                    .foregroundColor(Color.Wispflow.textTertiary)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Added: \(formatDate(entry.createdAt))")
                            .font(Font.Wispflow.small)
                            .foregroundColor(Color.Wispflow.textTertiary)
                        Text("Last updated: \(formatDate(entry.updatedAt))")
                            .font(Font.Wispflow.small)
                            .foregroundColor(Color.Wispflow.textTertiary)
                    }
                    .padding(.top, Spacing.md)
                }
                .padding(Spacing.lg)
            }
            .background(Color.Wispflow.background)
            
            Divider()
            
            // Footer with action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(WispflowButtonStyle(variant: .secondary))
                
                Spacer()
                
                Button("Save Changes") {
                    let trimmedHint = pronunciationHint.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(
                        word.trimmingCharacters(in: .whitespacesAndNewlines),
                        trimmedHint.isEmpty ? nil : trimmedHint
                    )
                    dismiss()
                }
                .buttonStyle(WispflowButtonStyle(variant: .primary))
                .disabled(!isValid || !hasChanges)
            }
            .padding(Spacing.lg)
            .background(Color.Wispflow.surface)
        }
        .frame(width: 450, height: 420)
        .background(Color.Wispflow.background)
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
                .font(Font.Wispflow.body)
                .foregroundColor(Color.Wispflow.textPrimary)
            
            if let hint = hint {
                Text("→")
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.textTertiary)
                
                Text(hint)
                    .font(Font.Wispflow.mono)
                    .foregroundColor(Color.Wispflow.accent)
            }
        }
    }
}

/// Settings content view that displays all settings in the main window content area
/// US-701: Create SettingsContentView for Main Window
struct SettingsContentView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // MARK: - Header
                settingsHeader
                
                // MARK: - General Section
                SettingsSectionView(
                    title: "General",
                    icon: "gear",
                    description: "App information, global hotkey, startup options, and permissions"
                ) {
                    GeneralSettingsSummary()
                }
                
                // MARK: - Audio Section
                SettingsSectionView(
                    title: "Audio",
                    icon: "speaker.wave.2",
                    description: "Input device selection, audio preview, and sensitivity settings"
                ) {
                    AudioSettingsSummary()
                }
                
                // MARK: - Transcription Section
                SettingsSectionView(
                    title: "Transcription",
                    icon: "waveform",
                    description: "Whisper model selection and language preferences"
                ) {
                    TranscriptionSettingsSummary()
                }
                
                // MARK: - Text Cleanup Section
                SettingsSectionView(
                    title: "Text Cleanup",
                    icon: "text.badge.checkmark",
                    description: "AI-powered text cleanup and post-processing options"
                ) {
                    TextCleanupSettingsSummary()
                }
                
                // MARK: - Text Insertion Section
                SettingsSectionView(
                    title: "Text Insertion",
                    icon: "doc.on.clipboard",
                    description: "How transcribed text is inserted into your applications"
                ) {
                    TextInsertionSettingsSummary()
                }
                
                // MARK: - Debug Section
                SettingsSectionView(
                    title: "Debug",
                    icon: "ladybug",
                    description: "Debug tools, logging, and audio export options"
                ) {
                    DebugSettingsSummary()
                }
                
                Spacer(minLength: Spacing.xxl)
            }
            .padding(Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Wispflow.background)
    }
    
    // MARK: - Header View
    
    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Settings")
                .font(Font.Wispflow.largeTitle)
                .foregroundColor(Color.Wispflow.textPrimary)
            
            Text("Configure WispFlow preferences and options")
                .font(Font.Wispflow.body)
                .foregroundColor(Color.Wispflow.textSecondary)
        }
    }
}

// MARK: - Settings Section View (US-701)

/// A reusable section container for settings groups
/// Applies consistent wispflowCard() styling to each section
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
                withAnimation(WispflowAnimation.quick) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: Spacing.md) {
                    // Section icon
                    ZStack {
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .fill(Color.Wispflow.accentLight)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.Wispflow.accent)
                    }
                    
                    // Title and description
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(title)
                            .font(Font.Wispflow.headline)
                            .foregroundColor(Color.Wispflow.textPrimary)
                        
                        Text(description)
                            .font(Font.Wispflow.caption)
                            .foregroundColor(Color.Wispflow.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Expand/collapse indicator
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Wispflow.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(Spacing.lg)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .background(
                RoundedRectangle(cornerRadius: isExpanded ? CornerRadius.medium : CornerRadius.medium)
                    .fill(isHovering && !isExpanded ? Color.Wispflow.border.opacity(0.3) : Color.clear)
            )
            .onHover { hovering in
                withAnimation(WispflowAnimation.quick) {
                    isHovering = hovering
                }
            }
            
            // Section Content (expandable)
            if isExpanded {
                Divider()
                    .background(Color.Wispflow.border)
                    .padding(.horizontal, Spacing.lg)
                
                VStack(alignment: .leading, spacing: Spacing.md) {
                    content()
                }
                .padding(Spacing.lg)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.Wispflow.surface)
        .cornerRadius(CornerRadius.medium)
        .wispflowShadow(.subtle)
    }
}

// MARK: - General Settings Section (US-702)

/// Full General settings section migrated from SettingsWindow
/// US-702: Migrate General Settings Section to integrated settings view
struct GeneralSettingsSummary: View {
    @StateObject private var hotkeyManager = HotkeyManager.shared
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var isRecordingHotkey = false
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
                                colors: [Color.Wispflow.accent.opacity(0.15), Color.Wispflow.accent.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                    
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.Wispflow.accent, Color.Wispflow.accent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // App name
                Text("WispFlow")
                    .font(Font.Wispflow.title)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
                // Version display
                Text("Version \(appVersion)")
                    .font(Font.Wispflow.caption)
                    .foregroundColor(Color.Wispflow.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.Wispflow.border.opacity(0.5))
                    .cornerRadius(CornerRadius.small / 2)
            }
            
            // Tagline/Description
            Text("Voice-to-text dictation with AI-powered transcription and auto-editing. All processing happens locally on your device.")
                .font(Font.Wispflow.body)
                .foregroundColor(Color.Wispflow.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.md)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .background(Color.Wispflow.border.opacity(0.2))
        .cornerRadius(CornerRadius.medium)
    }
    
    // MARK: - Link Buttons Section
    
    /// GitHub, Website, Support link buttons
    private var linkButtonsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Links")
                .font(Font.Wispflow.headline)
                .foregroundColor(Color.Wispflow.textPrimary)
            
            HStack(spacing: Spacing.md) {
                GeneralSettingsLinkButton(
                    title: "GitHub",
                    icon: "chevron.left.forwardslash.chevron.right",
                    url: "https://github.com"
                )
                
                GeneralSettingsLinkButton(
                    title: "Website",
                    icon: "globe",
                    url: "https://wispflow.app"
                )
                
                GeneralSettingsLinkButton(
                    title: "Support",
                    icon: "questionmark.circle",
                    url: "https://wispflow.app/support"
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
                    .foregroundColor(Color.Wispflow.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Global Hotkey")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
            }
            
            Text("Press this keyboard shortcut from any app to start/stop voice recording.")
                .font(Font.Wispflow.caption)
                .foregroundColor(Color.Wispflow.textSecondary)
            
            HStack(spacing: Spacing.md) {
                // Hotkey recorder component
                GeneralSettingsHotkeyRecorder(
                    hotkeyManager: hotkeyManager,
                    isRecording: $isRecordingHotkey
                )
                
                // Reset to default button
                Button(action: {
                    print("[US-702] Button action: Reset Hotkey to Default")
                    hotkeyManager.resetToDefault()
                }) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset")
                    }
                }
                .buttonStyle(WispflowButtonStyle.secondary)
                .disabled(hotkeyManager.configuration == .defaultHotkey)
            }
            
            if isRecordingHotkey {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                    Text("Press your desired key combination...")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.accent)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isRecordingHotkey)
    }
    
    // MARK: - Startup Section
    
    /// Launch at login toggle
    private var startupSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "power")
                    .foregroundColor(Color.Wispflow.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Startup")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Toggle("Launch WispFlow at Login", isOn: $launchAtLogin)
                    .toggleStyle(WispflowToggleStyle())
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.textPrimary)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }
                
                Text("Automatically start WispFlow when you log in to your Mac. WispFlow runs quietly in the menu bar.")
                    .font(Font.Wispflow.caption)
                    .foregroundColor(Color.Wispflow.textSecondary)
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
                    .foregroundColor(Color.Wispflow.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Permissions")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
            }
            
            Text("WispFlow requires these permissions to function. Grant permissions to enable voice recording and text insertion.")
                .font(Font.Wispflow.caption)
                .foregroundColor(Color.Wispflow.textSecondary)
            
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
                .background(Color.Wispflow.border)
            
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
                    .font(Font.Wispflow.caption)
            }
            .foregroundColor(isHovering ? Color.Wispflow.accent : Color.Wispflow.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(isHovering ? Color.Wispflow.accentLight : Color.Wispflow.border.opacity(0.3))
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
struct GeneralSettingsHotkeyRecorder: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @Binding var isRecording: Bool
    @State private var localEventMonitor: Any?
    @State private var isHovering = false
    @State private var pulseAnimation = false
    
    // Conflict detection state
    @State private var pendingConfig: HotkeyManager.HotkeyConfiguration?
    @State private var conflictingShortcuts: [HotkeyManager.SystemShortcut] = []
    @State private var showConflictWarning = false
    
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
                        .fill(Color.Wispflow.accent)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                        .opacity(pulseAnimation ? 1.0 : 0.6)
                    
                    Text("Recording...")
                        .font(Font.Wispflow.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Wispflow.accent)
                } else {
                    // Keyboard icon
                    Image(systemName: "command")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isHovering ? Color.Wispflow.accent : Color.Wispflow.textSecondary)
                    
                    Text(hotkeyManager.hotkeyDisplayString)
                        .font(Font.Wispflow.mono)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Wispflow.textPrimary)
                }
            }
            .frame(minWidth: 140)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(isRecording ? Color.Wispflow.accentLight : (isHovering ? Color.Wispflow.border.opacity(0.3) : Color.Wispflow.surface))
                    
                    if !isRecording {
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(Color.Wispflow.border.opacity(0.5), lineWidth: 1)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        isRecording ? Color.Wispflow.accent : (isHovering ? Color.Wispflow.accent.opacity(0.5) : Color.Wispflow.border),
                        lineWidth: isRecording ? 2 : 1
                    )
            )
            .shadow(
                color: isRecording ? Color.Wispflow.accent.opacity(0.4) : (isHovering ? Color.Wispflow.accent.opacity(0.15) : Color.clear),
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
            print("[US-702] Hotkey must include at least one modifier")
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
            print("[US-702] Conflict detected: \(conflicts.map { $0.name }.joined(separator: ", "))")
        } else {
            hotkeyManager.updateConfiguration(newConfig)
            stopRecording()
            print("[US-702] New hotkey set to \(newConfig.displayString)")
        }
    }
    
    private func applyPendingConfig() {
        guard let config = pendingConfig else { return }
        hotkeyManager.updateConfiguration(config)
        print("[US-702] User proceeded despite conflict, hotkey set to \(config.displayString)")
        pendingConfig = nil
        conflictingShortcuts = []
    }
    
    private func cancelPendingConfig() {
        print("[US-702] User cancelled conflicting hotkey")
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
                    .fill(isGranted ? Color.Wispflow.successLight : Color.Wispflow.errorLight)
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isGranted ? Color.Wispflow.success : Color.Wispflow.error)
            }
            
            // Permission info
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text(title)
                        .font(Font.Wispflow.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    // Status indicator
                    HStack(spacing: 4) {
                        Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(isGranted ? "Granted" : "Not Granted")
                            .font(Font.Wispflow.small)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(isGranted ? Color.Wispflow.success : Color.Wispflow.error)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 2)
                    .background((isGranted ? Color.Wispflow.success : Color.Wispflow.error).opacity(0.12))
                    .cornerRadius(CornerRadius.small / 2)
                }
                
                Text(description)
                    .font(Font.Wispflow.caption)
                    .foregroundColor(Color.Wispflow.textSecondary)
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
                .buttonStyle(WispflowButtonStyle.primary)
            }
        }
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(isHovering ? Color.Wispflow.border.opacity(0.2) : Color.clear)
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
                    .foregroundColor(Color.Wispflow.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Input Device")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
                
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
                            .font(Font.Wispflow.caption)
                    }
                    .foregroundColor(Color.Wispflow.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.Wispflow.border.opacity(0.3))
                    .cornerRadius(CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Refresh available audio devices")
            }
            
            Text("Select the microphone to use for voice recording. USB microphones are recommended for best accuracy.")
                .font(Font.Wispflow.caption)
                .foregroundColor(Color.Wispflow.textSecondary)
            
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
                    .foregroundColor(Color.Wispflow.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Audio Preview")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
            }
            
            Text("Test your microphone and see the input level in real-time.")
                .font(Font.Wispflow.caption)
                .foregroundColor(Color.Wispflow.textSecondary)
            
            // Audio level meter display (US-703 Task 2)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Level meter header
                HStack {
                    Text("Input Level")
                        .font(Font.Wispflow.body)
                        .foregroundColor(Color.Wispflow.textSecondary)
                    
                    Spacer()
                    
                    // Level value and status
                    HStack(spacing: Spacing.sm) {
                        Text(String(format: "%.1f dB", currentLevel))
                            .font(Font.Wispflow.mono)
                            .foregroundColor(levelColor(for: currentLevel))
                        
                        // Status badge
                        Text(levelStatus(for: currentLevel))
                            .font(Font.Wispflow.small)
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
                .buttonStyle(WispflowButtonStyle(variant: isPreviewingAudio ? .secondary : .primary))
                .padding(.top, Spacing.sm)
            }
            .padding(Spacing.lg)
            .background(Color.Wispflow.surface)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(isPreviewingAudio ? Color.Wispflow.accent : Color.Wispflow.border, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Input Sensitivity Section
    
    /// Input sensitivity slider (US-703 Task 3)
    private var inputSensitivitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "dial.low")
                    .foregroundColor(Color.Wispflow.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Input Sensitivity")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
            }
            
            Text("Adjust the microphone sensitivity. Higher values pick up quieter sounds but may introduce background noise.")
                .font(Font.Wispflow.caption)
                .foregroundColor(Color.Wispflow.textSecondary)
            
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Sensitivity")
                        .font(Font.Wispflow.body)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    Spacer()
                    Text(String(format: "%.0f%%", inputGain * 100))
                        .font(Font.Wispflow.mono)
                        .foregroundColor(Color.Wispflow.accent)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.Wispflow.accentLight)
                        .cornerRadius(CornerRadius.small / 2)
                }
                
                // Custom slider for input gain
                AudioSettingsSlider(value: $inputGain, range: 0.5...2.0)
                    .frame(height: 8)
                
                HStack {
                    Text("Low")
                        .font(Font.Wispflow.small)
                        .foregroundColor(Color.Wispflow.textSecondary)
                    Spacer()
                    Text("High")
                        .font(Font.Wispflow.small)
                        .foregroundColor(Color.Wispflow.textSecondary)
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
                    .buttonStyle(WispflowButtonStyle.ghost)
                    .disabled(inputGain == 1.0)
                }
            }
            .padding(Spacing.lg)
            .background(Color.Wispflow.surface)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(Color.Wispflow.border, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Calibration Section
    
    /// Audio level calibration controls (US-703 Task 4)
    private var calibrationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "tuningfork")
                    .foregroundColor(Color.Wispflow.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Audio Level Calibration")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
            }
            
            Text("Calibrate your microphone for optimal silence detection in your environment. This helps WispFlow distinguish between ambient noise and speech.")
                .font(Font.Wispflow.caption)
                .foregroundColor(Color.Wispflow.textSecondary)
            
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
                .buttonStyle(WispflowButtonStyle.primary)
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
                    .buttonStyle(WispflowButtonStyle.secondary)
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
                    .buttonStyle(WispflowButtonStyle.ghost)
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
            return Color.Wispflow.error // Clipping/too loud
        } else if level > -30 {
            return Color.Wispflow.success // Good level
        } else if level > -50 {
            return Color.Wispflow.warning // Quiet
        } else {
            return Color.Wispflow.textSecondary // Very quiet/silent
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
                        .foregroundColor(Color.Wispflow.accent)
                        .frame(width: 24)
                    
                    // Device name
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Spacing.xs) {
                            Text(selectedDevice?.name ?? "No device selected")
                                .font(Font.Wispflow.body)
                                .foregroundColor(Color.Wispflow.textPrimary)
                            
                            // Warning icon for low-quality selected device
                            if let device = selectedDevice, isLowQualityDevice(device) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.Wispflow.warning)
                                    .help(lowQualityWarningText(for: device))
                            }
                        }
                        
                        if let device = selectedDevice, device.isDefault {
                            Text("System Default")
                                .font(Font.Wispflow.small)
                                .foregroundColor(Color.Wispflow.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Dropdown indicator
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(Spacing.md)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(isHovering ? Color.Wispflow.border.opacity(0.3) : Color.Wispflow.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(isExpanded ? Color.Wispflow.accent : Color.Wispflow.border, lineWidth: 1)
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
                .background(Color.Wispflow.surface)
                .cornerRadius(CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.Wispflow.border, lineWidth: 1)
                )
                .wispflowShadow(.card)
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
                    .foregroundColor(isSelected ? Color.Wispflow.accent : Color.Wispflow.textSecondary)
                    .frame(width: 20)
                
                // Device name
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(device.name)
                            .font(Font.Wispflow.body)
                            .foregroundColor(isSelected ? Color.Wispflow.accent : Color.Wispflow.textPrimary)
                        
                        // Warning icon for low-quality devices
                        if isLowQuality {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.Wispflow.warning)
                                .help(lowQualityReason)
                        }
                    }
                    
                    if device.isDefault {
                        Text("System Default")
                            .font(Font.Wispflow.small)
                            .foregroundColor(Color.Wispflow.textSecondary)
                    } else if isLowQuality {
                        Text("May reduce transcription accuracy")
                            .font(Font.Wispflow.small)
                            .foregroundColor(Color.Wispflow.warning)
                    }
                }
                
                Spacer()
                
                // Selected checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Wispflow.accent)
                }
            }
            .padding(Spacing.md)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(isHovering ? Color.Wispflow.accentLight : Color.clear)
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
                    .fill(Color.Wispflow.border)
                
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
            return Color.Wispflow.error
        } else if segmentLevel > -30 {
            return Color.Wispflow.success
        } else {
            return Color.Wispflow.accent
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
                    .fill(Color.Wispflow.border)
                    .frame(height: 8)
                
                // Filled track
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [Color.Wispflow.accent.opacity(0.7), Color.Wispflow.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, thumbPosition), height: 8)
                
                // Thumb
                Circle()
                    .fill(Color.Wispflow.surface)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.Wispflow.accent, lineWidth: 2)
                    )
                    .shadow(color: Color.Wispflow.accent.opacity(isDragging ? 0.4 : 0.2), radius: isDragging ? 8 : 4)
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
        .background(Color.Wispflow.surface)
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(Color.Wispflow.border, lineWidth: 1)
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
                    .fill(Color.Wispflow.successLight)
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.Wispflow.success)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text("Calibrated")
                        .font(Font.Wispflow.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    // Status badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.Wispflow.success)
                            .frame(width: 6, height: 6)
                        Text("Active")
                            .font(Font.Wispflow.small)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(Color.Wispflow.success)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 2)
                    .background(Color.Wispflow.success.opacity(0.12))
                    .cornerRadius(CornerRadius.small / 2)
                }
                
                HStack(spacing: Spacing.md) {
                    AudioSettingsMetric(label: "Ambient", value: String(format: "%.1f dB", calibration.ambientNoiseLevel))
                    AudioSettingsMetric(label: "Threshold", value: String(format: "%.1f dB", calibration.silenceThreshold))
                }
                
                // Calibration date
                Text("Last calibrated: \(formattedDate(calibration.calibrationDate))")
                    .font(Font.Wispflow.small)
                    .foregroundColor(Color.Wispflow.textSecondary)
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
                    .fill(Color.Wispflow.border.opacity(0.3))
                    .frame(width: 36, height: 36)
                Image(systemName: "circle.dashed")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.Wispflow.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text("Not Calibrated")
                        .font(Font.Wispflow.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    // Status badge
                    Text("Using Default")
                        .font(Font.Wispflow.small)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Color.Wispflow.border.opacity(0.3))
                        .cornerRadius(CornerRadius.small / 2)
                }
                
                AudioSettingsMetric(label: "Default Threshold", value: String(format: "%.0f dB", AudioManager.silenceThreshold))
                
                Text("Calibrate to optimize for your environment")
                    .font(Font.Wispflow.small)
                    .foregroundColor(Color.Wispflow.textSecondary)
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
                        .fill(Color.Wispflow.accentLight)
                        .frame(width: 36, height: 36)
                    Image(systemName: "waveform")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.Wispflow.accent)
                }
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Measuring ambient noise...")
                        .font(Font.Wispflow.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Wispflow.textPrimary)
                    
                    Text("Please remain quiet for 3 seconds")
                        .font(Font.Wispflow.caption)
                        .foregroundColor(Color.Wispflow.textSecondary)
                }
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(Font.Wispflow.mono)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.Wispflow.accent)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.Wispflow.border)
                    
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [Color.Wispflow.accent.opacity(0.7), Color.Wispflow.accent],
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
                    .fill(Color.Wispflow.successLight)
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.Wispflow.success)
                    .scaleEffect(showCheckmark ? 1.0 : 0.5)
                    .opacity(showCheckmark ? 1.0 : 0.0)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text("Calibration Complete!")
                        .font(Font.Wispflow.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.Wispflow.success)
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
                    .fill(Color.Wispflow.errorLight)
                    .frame(width: 36, height: 36)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.Wispflow.error)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Calibration Failed")
                    .font(Font.Wispflow.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color.Wispflow.error)
                
                Text(message)
                    .font(Font.Wispflow.caption)
                    .foregroundColor(Color.Wispflow.textSecondary)
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
                .font(Font.Wispflow.small)
                .foregroundColor(Color.Wispflow.textSecondary)
            Text(value)
                .font(Font.Wispflow.mono)
                .fontWeight(.medium)
                .foregroundColor(Color.Wispflow.accent)
        }
    }
}

// MARK: - Transcription Settings Summary (US-704)

/// Full Transcription settings section migrated from SettingsWindow
/// US-704: Migrate Transcription Settings Section to integrated settings view
struct TranscriptionSettingsSummary: View {
    @StateObject private var whisperManager = WhisperManager.shared
    
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
                    .foregroundColor(Color.Wispflow.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Whisper Model")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
            }
            
            Text("Select a model size. Larger models are more accurate but slower and use more memory.")
                .font(Font.Wispflow.caption)
                .foregroundColor(Color.Wispflow.textSecondary)
            
            // Card-based model picker (US-704)
            VStack(spacing: Spacing.sm) {
                ForEach(WhisperManager.ModelSize.allCases) { model in
                    TranscriptionModelCard(
                        model: model,
                        isSelected: whisperManager.selectedModel == model,
                        isDownloaded: whisperManager.isModelDownloaded(model),
                        isActive: model == whisperManager.selectedModel && whisperManager.modelStatus == .ready,
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
                    .foregroundColor(Color.Wispflow.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Model Actions")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
            }
            
            // Status message
            Text(whisperManager.statusMessage)
                .font(Font.Wispflow.body)
                .foregroundColor(Color.Wispflow.textSecondary)
            
            // Download progress bar (US-704 Task 2)
            if case .downloading(let progress) = whisperManager.modelStatus {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    // Progress percentage header
                    HStack {
                        Text("Downloading \(whisperManager.selectedModel.displayName.components(separatedBy: " (").first ?? "model")...")
                            .font(Font.Wispflow.body)
                            .foregroundColor(Color.Wispflow.textPrimary)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(Font.Wispflow.mono)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.Wispflow.accent)
                    }
                    
                    // Gradient progress bar
                    TranscriptionProgressBar(progress: progress)
                        .frame(height: 10)
                    
                    // Status message
                    Text("Please wait, this may take a few minutes...")
                        .font(Font.Wispflow.small)
                        .foregroundColor(Color.Wispflow.textSecondary)
                }
                .padding(Spacing.md)
                .background(Color.Wispflow.accentLight.opacity(0.5))
                .cornerRadius(CornerRadius.small)
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
                .disabled(isLoadingModel || whisperManager.modelStatus == .ready)
                .buttonStyle(WispflowButtonStyle.primary)
                
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
                    .buttonStyle(WispflowButtonStyle.secondary)
                    
                    Button(action: {
                        showErrorAlert = true
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                            Text("Details")
                        }
                    }
                    .buttonStyle(WispflowButtonStyle.ghost)
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
                    .buttonStyle(WispflowButtonStyle.secondary)
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
                    .foregroundColor(Color.Wispflow.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Transcription Language")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
            }
            
            Text("Select the language for speech recognition. Auto-detect works best for most cases.")
                .font(Font.Wispflow.caption)
                .foregroundColor(Color.Wispflow.textSecondary)
            
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
                    .foregroundColor(Color.Wispflow.accent)
                    .font(.system(size: 16, weight: .medium))
                Text("Quality vs Speed")
                    .font(Font.Wispflow.headline)
                    .foregroundColor(Color.Wispflow.textPrimary)
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
            .background(Color.Wispflow.surface)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(Color.Wispflow.border, lineWidth: 1)
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
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    // Model metadata for quality/speed display
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
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                // Model icon
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(isSelected ? Color.Wispflow.accentLight : Color.Wispflow.border.opacity(0.3))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: modelInfo.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? Color.Wispflow.accent : Color.Wispflow.textSecondary)
                }
                
                // Model info
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.sm) {
                        Text(model.displayName.components(separatedBy: " (").first ?? model.rawValue.capitalized)
                            .font(Font.Wispflow.body)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Wispflow.textPrimary)
                        
                        // Status badge
                        if isActive {
                            TranscriptionModelBadge(text: "Active", color: Color.Wispflow.success)
                        } else if isDownloaded {
                            TranscriptionModelBadge(text: "Downloaded", color: Color.Wispflow.accent)
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
                        .stroke(isSelected ? Color.Wispflow.accent : Color.Wispflow.border, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.Wispflow.accent)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(Spacing.md)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(isHovering ? Color.Wispflow.border.opacity(0.2) : Color.Wispflow.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(isSelected ? Color.Wispflow.accent : Color.Wispflow.border.opacity(0.5), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(
                color: isSelected ? Color.Wispflow.accent.opacity(0.15) : Color.clear,
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
            .font(Font.Wispflow.small)
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
                .foregroundColor(Color.Wispflow.textSecondary)
            Text(text)
                .font(Font.Wispflow.small)
                .foregroundColor(Color.Wispflow.textSecondary)
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
                    .fill(Color.Wispflow.border)
                
                // Gradient fill
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.Wispflow.accent.opacity(0.7),
                                Color.Wispflow.accent,
                                Color.Wispflow.accent.opacity(0.9)
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
                            .font(Font.Wispflow.body)
                            .foregroundColor(Color.Wispflow.textPrimary)
                        
                        if selectedLanguage == .automatic {
                            Text("Recommended for mixed-language content")
                                .font(Font.Wispflow.small)
                                .foregroundColor(Color.Wispflow.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Dropdown indicator
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(Spacing.md)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(isHovering ? Color.Wispflow.border.opacity(0.3) : Color.Wispflow.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(isExpanded ? Color.Wispflow.accent : Color.Wispflow.border, lineWidth: 1)
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
                .background(Color.Wispflow.surface)
                .cornerRadius(CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.Wispflow.border, lineWidth: 1)
                )
                .wispflowShadow(.card)
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
                    .font(Font.Wispflow.body)
                    .foregroundColor(isSelected ? Color.Wispflow.accent : Color.Wispflow.textPrimary)
                
                if language == .automatic {
                    Text("Recommended")
                        .font(Font.Wispflow.small)
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Color.Wispflow.border.opacity(0.5))
                        .cornerRadius(CornerRadius.small / 2)
                }
                
                Spacer()
                
                // Selected checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Wispflow.accent)
                }
            }
            .padding(Spacing.md)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(isHovering ? Color.Wispflow.accentLight : Color.clear)
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
                .foregroundColor(highlight ? Color.Wispflow.accent : Color.Wispflow.textSecondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.Wispflow.body)
                    .fontWeight(highlight ? .semibold : .regular)
                    .foregroundColor(highlight ? Color.Wispflow.textPrimary : Color.Wispflow.textSecondary)
                
                Text(description)
                    .font(Font.Wispflow.small)
                    .foregroundColor(Color.Wispflow.textTertiary)
            }
            
            Spacer()
            
            if highlight {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.Wispflow.accent)
            }
        }
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(highlight ? Color.Wispflow.accentLight.opacity(0.5) : Color.clear)
        )
        .padding(.horizontal, Spacing.xs)
    }
}

// MARK: - Text Cleanup Settings Summary (US-701)

/// Summary view for Text Cleanup settings section
struct TextCleanupSettingsSummary: View {
    @StateObject private var textCleanupManager = TextCleanupManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Cleanup enabled status
            HStack(spacing: Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.Wispflow.textSecondary)
                    .frame(width: 20)
                
                Text("Text Cleanup")
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.textSecondary)
                
                Spacer()
                
                StatusPill(
                    text: textCleanupManager.isCleanupEnabled ? "Enabled" : "Disabled",
                    color: textCleanupManager.isCleanupEnabled ? Color.Wispflow.success : Color.Wispflow.textTertiary
                )
            }
            
            // Cleanup mode
            SettingsInfoRow(
                icon: "slider.horizontal.3",
                title: "Cleanup Mode",
                value: textCleanupManager.selectedMode.displayName
            )
            
            // Post-processing
            HStack(spacing: Spacing.md) {
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.Wispflow.textSecondary)
                    .frame(width: 20)
                
                Text("Post-Processing")
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.textSecondary)
                
                Spacer()
                
                HStack(spacing: Spacing.xs) {
                    if textCleanupManager.autoCapitalizeFirstLetter {
                        MiniFeatureBadge(icon: "textformat.abc")
                    }
                    if textCleanupManager.addPeriodAtEnd {
                        MiniFeatureBadge(icon: "period")
                    }
                    if textCleanupManager.trimWhitespace {
                        MiniFeatureBadge(icon: "text.alignleft")
                    }
                }
            }
            
            // Open full settings button
            SettingsOpenFullButton()
        }
    }
}

// MARK: - Text Insertion Settings Summary (US-701)

/// Summary view for Text Insertion settings section
struct TextInsertionSettingsSummary: View {
    @StateObject private var textInserter = TextInserter.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Insertion method - using paste (⌘V) by default
            SettingsInfoRow(
                icon: "keyboard.badge.ellipsis",
                title: "Insertion Method",
                value: "Paste (⌘V)"
            )
            
            // Clipboard preservation
            HStack(spacing: Spacing.md) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.Wispflow.textSecondary)
                    .frame(width: 20)
                
                Text("Clipboard Preservation")
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.textSecondary)
                
                Spacer()
                
                StatusPill(
                    text: textInserter.preserveClipboard ? "Enabled" : "Disabled",
                    color: textInserter.preserveClipboard ? Color.Wispflow.success : Color.Wispflow.textTertiary
                )
            }
            
            // Open full settings button
            SettingsOpenFullButton()
        }
    }
}

// MARK: - Debug Settings Summary (US-701)

/// Summary view for Debug settings section
struct DebugSettingsSummary: View {
    @StateObject private var debugManager = DebugManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Debug mode status
            HStack(spacing: Spacing.md) {
                Image(systemName: "ladybug")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.Wispflow.textSecondary)
                    .frame(width: 20)
                
                Text("Debug Mode")
                    .font(Font.Wispflow.body)
                    .foregroundColor(Color.Wispflow.textSecondary)
                
                Spacer()
                
                StatusPill(
                    text: debugManager.isDebugModeEnabled ? "Enabled" : "Disabled",
                    color: debugManager.isDebugModeEnabled ? Color.Wispflow.warning : Color.Wispflow.textTertiary
                )
            }
            
            // Auto-save recordings
            if debugManager.isDebugModeEnabled {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.Wispflow.textSecondary)
                        .frame(width: 20)
                    
                    Text("Auto-Save Recordings")
                        .font(Font.Wispflow.body)
                        .foregroundColor(Color.Wispflow.textSecondary)
                    
                    Spacer()
                    
                    StatusPill(
                        text: debugManager.isAutoSaveEnabled ? "Enabled" : "Disabled",
                        color: debugManager.isAutoSaveEnabled ? Color.Wispflow.success : Color.Wispflow.textTertiary
                    )
                }
            }
            
            // Last recording info
            if let lastAudio = debugManager.lastAudioData {
                SettingsInfoRow(
                    icon: "waveform",
                    title: "Last Recording",
                    value: String(format: "%.1fs • %.0f dB", lastAudio.duration, lastAudio.peakLevel)
                )
            }
            
            // Open full settings button
            SettingsOpenFullButton()
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
                .foregroundColor(Color.Wispflow.textSecondary)
                .frame(width: 20)
            
            Text(title)
                .font(Font.Wispflow.body)
                .foregroundColor(Color.Wispflow.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(Font.Wispflow.body)
                .foregroundColor(Color.Wispflow.textPrimary)
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
                .fill(isGranted ? Color.Wispflow.successLight : Color.Wispflow.errorLight)
                .frame(width: 28, height: 28)
            
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isGranted ? Color.Wispflow.success : Color.Wispflow.error)
        }
        .overlay(
            Circle()
                .stroke(isGranted ? Color.Wispflow.success.opacity(0.3) : Color.Wispflow.error.opacity(0.3), lineWidth: 1)
        )
        .help(isGranted ? "Permission granted" : "Permission not granted")
    }
}

/// A compact status indicator for Whisper model status
struct ModelStatusIndicator: View {
    let status: WhisperManager.ModelStatus
    
    private var color: Color {
        switch status {
        case .ready: return Color.Wispflow.success
        case .loading, .downloading: return Color.Wispflow.warning
        case .downloaded: return Color.Wispflow.accent
        case .notDownloaded: return Color.Wispflow.textTertiary
        case .error: return Color.Wispflow.error
        }
    }
    
    private var text: String {
        switch status {
        case .ready: return "Ready"
        case .loading: return "Loading"
        case .downloading: return "Downloading"
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
                .font(Font.Wispflow.small)
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
            .font(Font.Wispflow.small)
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
                .fill(Color.Wispflow.accentLight)
                .frame(width: 22, height: 22)
            
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.Wispflow.accent)
        }
    }
}

/// Button to open the full settings window
struct SettingsOpenFullButton: View {
    var body: some View {
        Button(action: {
            NotificationCenter.default.post(name: .openSettings, object: nil)
        }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12, weight: .medium))
                Text("Open Full Settings")
                    .font(Font.Wispflow.caption)
            }
            .foregroundColor(Color.Wispflow.accent)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.Wispflow.accentLight)
            .cornerRadius(CornerRadius.small)
        }
        .buttonStyle(InteractiveScaleStyle())
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, Spacing.sm)
    }
}

// MARK: - Main Window Controller

/// Controller for the main application window
/// Handles window state persistence and lifecycle
final class MainWindowController: NSObject {
    private var mainWindow: NSWindow?
    
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
    
    /// Show the main window
    func showMainWindow() {
        if let existingWindow = mainWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let mainView = MainWindowView()
        let hostingController = NSHostingController(rootView: mainView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "WispFlow"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
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
            .frame(width: 1000, height: 700)
    }
}
#endif
