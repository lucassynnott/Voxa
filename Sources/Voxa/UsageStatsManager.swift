import Foundation

// MARK: - Usage Statistics Manager
// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║ US-633: Dashboard Home View - Usage Statistics Tracking                      ║
// ║                                                                              ║
// ║ Tracks and persists user activity statistics:                                ║
// ║ - Streak days (consecutive days of transcription)                            ║
// ║ - Total words transcribed                                                    ║
// ║ - Average words per minute (WPM)                                             ║
// ║ - Recent transcription entries for activity timeline                         ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

/// Data model for a transcription entry in activity history
/// US-634: Extended to store full text for history view
struct TranscriptionEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let textPreview: String
    let fullText: String // US-634: Store full text for history view expansion and copy
    let wordCount: Int
    let durationSeconds: Double // Recording duration
    
    init(text: String, durationSeconds: Double) {
        self.id = UUID()
        self.timestamp = Date()
        self.textPreview = String(text.prefix(200)) // Limit preview length for list display
        self.fullText = text // US-634: Store complete text
        self.wordCount = Self.countWords(in: text)
        self.durationSeconds = durationSeconds
    }
    
    // US-634: Migration initializer for entries without fullText
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        textPreview = try container.decode(String.self, forKey: .textPreview)
        // US-634: Handle migration - use textPreview as fallback if fullText is missing
        fullText = try container.decodeIfPresent(String.self, forKey: .fullText) ?? textPreview
        wordCount = try container.decode(Int.self, forKey: .wordCount)
        durationSeconds = try container.decode(Double.self, forKey: .durationSeconds)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, timestamp, textPreview, fullText, wordCount, durationSeconds
    }
    
    /// Calculate words per minute for this transcription
    var wordsPerMinute: Double {
        guard durationSeconds > 0 else { return 0 }
        return Double(wordCount) / (durationSeconds / 60.0)
    }
    
    /// Count words in text (simple whitespace split)
    private static func countWords(in text: String) -> Int {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        return words.count
    }
}

/// Manager for tracking usage statistics
/// Thread-safe singleton pattern with UserDefaults persistence
@MainActor
final class UsageStatsManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = UsageStatsManager()
    
    // MARK: - Constants
    
    private enum Constants {
        static let statsDataKey = "usageStatsData"
        static let historyDataKey = "transcriptionHistoryData"
        static let lastActiveDate = "lastActiveDate"
        static let currentStreakKey = "currentStreak"
        static let maxHistoryEntries = 50 // Keep last 50 transcriptions
    }
    
    // MARK: - Published Properties
    
    /// Current streak in days
    @Published private(set) var streakDays: Int = 0
    
    /// Total words transcribed
    @Published private(set) var totalWordsTranscribed: Int = 0
    
    /// Total transcriptions count
    @Published private(set) var totalTranscriptions: Int = 0
    
    /// Total recording duration in seconds
    @Published private(set) var totalRecordingDuration: Double = 0
    
    /// Recent transcription entries (newest first)
    @Published private(set) var recentEntries: [TranscriptionEntry] = []
    
    // MARK: - Computed Properties
    
    /// Average words per minute across all transcriptions
    var averageWPM: Double {
        guard totalRecordingDuration > 0 else { return 0 }
        return Double(totalWordsTranscribed) / (totalRecordingDuration / 60.0)
    }
    
    /// Check if user has any activity
    var hasActivity: Bool {
        return totalTranscriptions > 0
    }
    
    // MARK: - Initialization
    
    private init() {
        loadStats()
        loadHistory()
        updateStreakIfNeeded()
        
        print("UsageStatsManager: [US-633] Initialized - Streak: \(streakDays) days, Total words: \(totalWordsTranscribed), Transcriptions: \(totalTranscriptions)")
    }
    
    // MARK: - Public Methods
    
    /// Record a new transcription
    /// - Parameters:
    ///   - text: The transcribed text
    ///   - durationSeconds: Recording duration in seconds
    func recordTranscription(text: String, durationSeconds: Double) {
        let entry = TranscriptionEntry(text: text, durationSeconds: durationSeconds)
        
        // Update totals
        totalWordsTranscribed += entry.wordCount
        totalTranscriptions += 1
        totalRecordingDuration += durationSeconds
        
        // Add to history (newest first)
        recentEntries.insert(entry, at: 0)
        
        // Trim history if needed
        if recentEntries.count > Constants.maxHistoryEntries {
            recentEntries = Array(recentEntries.prefix(Constants.maxHistoryEntries))
        }
        
        // Update streak
        updateStreakForActivity()
        
        // Persist
        saveStats()
        saveHistory()
        
        print("UsageStatsManager: [US-633] Recorded transcription - Words: \(entry.wordCount), WPM: \(String(format: "%.1f", entry.wordsPerMinute)), Total words: \(totalWordsTranscribed)")
    }
    
    /// Clear a specific entry from history
    /// US-634: Enhanced to also update totals when entry is deleted
    func removeEntry(_ entry: TranscriptionEntry) {
        guard recentEntries.contains(where: { $0.id == entry.id }) else { return }
        
        // Update totals
        totalWordsTranscribed = max(0, totalWordsTranscribed - entry.wordCount)
        totalTranscriptions = max(0, totalTranscriptions - 1)
        totalRecordingDuration = max(0, totalRecordingDuration - entry.durationSeconds)
        
        // Remove entry
        recentEntries.removeAll { $0.id == entry.id }
        
        // Persist changes
        saveStats()
        saveHistory()
        
        print("UsageStatsManager: [US-634] Removed entry - Words: \(entry.wordCount), remaining entries: \(recentEntries.count)")
    }
    
    // MARK: - US-634: Search and Filter Support
    
    /// Search entries by text content
    /// - Parameter query: Search query string
    /// - Returns: Filtered entries matching the query
    func searchEntries(query: String) -> [TranscriptionEntry] {
        guard !query.isEmpty else { return recentEntries }
        let lowercasedQuery = query.lowercased()
        return recentEntries.filter { entry in
            entry.fullText.lowercased().contains(lowercasedQuery) ||
            entry.textPreview.lowercased().contains(lowercasedQuery)
        }
    }
    
    /// Group entries by date category (Today, Yesterday, This Week, etc.)
    /// - Parameter entries: Entries to group
    /// - Returns: Dictionary with date categories as keys
    func groupEntriesByDate(_ entries: [TranscriptionEntry]) -> [DateCategory: [TranscriptionEntry]] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: today)!
        
        var groups: [DateCategory: [TranscriptionEntry]] = [:]
        
        for entry in entries {
            let entryDate = calendar.startOfDay(for: entry.timestamp)
            let category: DateCategory
            
            if calendar.isDate(entryDate, inSameDayAs: today) {
                category = .today
            } else if calendar.isDate(entryDate, inSameDayAs: yesterday) {
                category = .yesterday
            } else if entryDate >= weekAgo {
                category = .thisWeek
            } else if entryDate >= monthAgo {
                category = .thisMonth
            } else {
                category = .older
            }
            
            if groups[category] == nil {
                groups[category] = []
            }
            groups[category]?.append(entry)
        }
        
        return groups
    }
    
    /// Clear all history and stats (for testing/reset)
    func resetAllStats() {
        streakDays = 0
        totalWordsTranscribed = 0
        totalTranscriptions = 0
        totalRecordingDuration = 0
        recentEntries = []
        
        UserDefaults.standard.removeObject(forKey: Constants.statsDataKey)
        UserDefaults.standard.removeObject(forKey: Constants.historyDataKey)
        UserDefaults.standard.removeObject(forKey: Constants.lastActiveDate)
        UserDefaults.standard.removeObject(forKey: Constants.currentStreakKey)
        
        print("UsageStatsManager: [US-633] All stats reset")
    }
    
    // MARK: - Persistence
    
    /// Codable structure for stats persistence
    private struct PersistedStats: Codable {
        let totalWordsTranscribed: Int
        let totalTranscriptions: Int
        let totalRecordingDuration: Double
    }
    
    private func loadStats() {
        guard let data = UserDefaults.standard.data(forKey: Constants.statsDataKey) else {
            return
        }
        
        do {
            let stats = try JSONDecoder().decode(PersistedStats.self, from: data)
            totalWordsTranscribed = stats.totalWordsTranscribed
            totalTranscriptions = stats.totalTranscriptions
            totalRecordingDuration = stats.totalRecordingDuration
        } catch {
            print("UsageStatsManager: [US-633] Failed to load stats: \(error)")
        }
        
        // Load streak separately for easier management
        streakDays = UserDefaults.standard.integer(forKey: Constants.currentStreakKey)
    }
    
    private func saveStats() {
        let stats = PersistedStats(
            totalWordsTranscribed: totalWordsTranscribed,
            totalTranscriptions: totalTranscriptions,
            totalRecordingDuration: totalRecordingDuration
        )
        
        do {
            let encoded = try JSONEncoder().encode(stats)
            UserDefaults.standard.set(encoded, forKey: Constants.statsDataKey)
        } catch {
            print("UsageStatsManager: [US-633] Failed to save stats: \(error)")
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: Constants.historyDataKey) else {
            return
        }
        
        do {
            recentEntries = try JSONDecoder().decode([TranscriptionEntry].self, from: data)
        } catch {
            print("UsageStatsManager: [US-633] Failed to load history: \(error)")
        }
    }
    
    private func saveHistory() {
        do {
            let encoded = try JSONEncoder().encode(recentEntries)
            UserDefaults.standard.set(encoded, forKey: Constants.historyDataKey)
        } catch {
            print("UsageStatsManager: [US-633] Failed to save history: \(error)")
        }
    }
    
    // MARK: - Streak Management
    
    /// Update streak count for current activity
    private func updateStreakForActivity() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastActiveData = UserDefaults.standard.object(forKey: Constants.lastActiveDate) as? Date {
            let lastActive = calendar.startOfDay(for: lastActiveData)
            let daysDiff = calendar.dateComponents([.day], from: lastActive, to: today).day ?? 0
            
            if daysDiff == 0 {
                // Same day, streak continues
            } else if daysDiff == 1 {
                // Next day, increment streak
                streakDays += 1
            } else {
                // Gap in days, reset streak
                streakDays = 1
            }
        } else {
            // First activity ever
            streakDays = 1
        }
        
        // Update last active date
        UserDefaults.standard.set(today, forKey: Constants.lastActiveDate)
        UserDefaults.standard.set(streakDays, forKey: Constants.currentStreakKey)
    }
    
    /// Check and update streak on app launch (might have missed days)
    private func updateStreakIfNeeded() {
        guard let lastActiveData = UserDefaults.standard.object(forKey: Constants.lastActiveDate) as? Date else {
            return
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastActive = calendar.startOfDay(for: lastActiveData)
        let daysDiff = calendar.dateComponents([.day], from: lastActive, to: today).day ?? 0
        
        // If more than 1 day has passed without activity, reset streak
        if daysDiff > 1 {
            streakDays = 0
            UserDefaults.standard.set(streakDays, forKey: Constants.currentStreakKey)
            print("UsageStatsManager: [US-633] Streak reset due to inactivity (gap of \(daysDiff) days)")
        }
    }
}

// MARK: - Date Formatting Extensions

extension TranscriptionEntry {
    /// Relative date string for display (e.g., "Today", "Yesterday", "2 days ago")
    var relativeDateString: String {
        let calendar = Calendar.current
        let now = Date()
        let entryDate = calendar.startOfDay(for: timestamp)
        let today = calendar.startOfDay(for: now)
        
        let daysDiff = calendar.dateComponents([.day], from: entryDate, to: today).day ?? 0
        
        switch daysDiff {
        case 0:
            return "Today"
        case 1:
            return "Yesterday"
        case 2...6:
            return "\(daysDiff) days ago"
        default:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: timestamp)
        }
    }
    
    /// Time string for display (e.g., "2:30 PM")
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    /// Full timestamp string
    var fullTimestampString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

// MARK: - US-634: Date Category Enum

/// Date categories for grouping transcription history entries
enum DateCategory: String, CaseIterable, Comparable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case older = "Older"
    
    /// Display name for the category
    var displayName: String {
        return rawValue
    }
    
    /// Sort order - earlier categories appear first
    var sortOrder: Int {
        switch self {
        case .today: return 0
        case .yesterday: return 1
        case .thisWeek: return 2
        case .thisMonth: return 3
        case .older: return 4
        }
    }
    
    static func < (lhs: DateCategory, rhs: DateCategory) -> Bool {
        return lhs.sortOrder < rhs.sortOrder
    }
}
