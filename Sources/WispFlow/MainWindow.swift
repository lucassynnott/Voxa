import SwiftUI
import AppKit

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

/// Dictionary view placeholder (to be implemented in US-636)
struct DictionaryContentView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color.Wispflow.accent.opacity(0.5))
            
            Text("Dictionary")
                .font(Font.Wispflow.largeTitle)
                .foregroundColor(Color.Wispflow.textPrimary)
            
            Text("Custom words and phrases for better transcription")
                .font(Font.Wispflow.body)
                .foregroundColor(Color.Wispflow.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Wispflow.background)
    }
}

/// Settings view placeholder (redirects to Settings window)
struct SettingsContentView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color.Wispflow.accent.opacity(0.5))
            
            Text("Settings")
                .font(Font.Wispflow.largeTitle)
                .foregroundColor(Color.Wispflow.textPrimary)
            
            Text("Configure WispFlow preferences")
                .font(Font.Wispflow.body)
                .foregroundColor(Color.Wispflow.textSecondary)
            
            Button(action: {
                // Post notification to open settings
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14, weight: .medium))
                    Text("Open Settings Window")
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Wispflow.background)
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
