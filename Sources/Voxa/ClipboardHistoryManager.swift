import Foundation
import AppKit

// MARK: - Clipboard History Manager
// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║ US-030: Clipboard History of Transcriptions                                  ║
// ║                                                                              ║
// ║ Maintains a persistent history of transcriptions for quick access:          ║
// ║ - Stores recent transcriptions with timestamps and metadata                 ║
// ║ - Provides search and filtering capabilities                                ║
// ║ - Supports copy and insert actions for history items                        ║
// ║ - Configurable history size and retention period                            ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

/// Data model for a clipboard history entry
struct ClipboardHistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let timestamp: Date
    let wordCount: Int
    let characterCount: Int

    /// Preview text for display (truncated if needed)
    var preview: String {
        let maxLength = 100
        if text.count <= maxLength {
            return text.replacingOccurrences(of: "\n", with: " ")
        }
        let truncated = String(text.prefix(maxLength))
        return truncated.replacingOccurrences(of: "\n", with: " ") + "..."
    }

    /// Formatted timestamp for display
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(timestamp) {
            formatter.dateFormat = "h:mm a"
            return "Today, " + formatter.string(from: timestamp)
        } else if calendar.isDateInYesterday(timestamp) {
            formatter.dateFormat = "h:mm a"
            return "Yesterday, " + formatter.string(from: timestamp)
        } else if calendar.isDate(timestamp, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE, h:mm a"
            return formatter.string(from: timestamp)
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: timestamp)
        }
    }

    init(text: String) {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
        self.wordCount = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        self.characterCount = text.count
    }

    static func == (lhs: ClipboardHistoryEntry, rhs: ClipboardHistoryEntry) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Date category for grouping history entries
enum HistoryDateCategory: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case older = "Older"

    static func category(for date: Date) -> HistoryDateCategory {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return .today
        } else if calendar.isDateInYesterday(date) {
            return .yesterday
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return .thisWeek
        } else if calendar.isDate(date, equalTo: now, toGranularity: .month) {
            return .thisMonth
        } else {
            return .older
        }
    }
}

/// Manager for clipboard history of transcriptions
/// Thread-safe singleton pattern with persistent storage
@MainActor
final class ClipboardHistoryManager: ObservableObject {
    // MARK: - Singleton

    static let shared = ClipboardHistoryManager()

    // MARK: - Constants

    private enum Constants {
        static let defaultMaxEntries = 50
        static let minEntries = 10
        static let maxEntries = 200
        static let defaultRetentionDays = 30
        static let minRetentionDays = 1
        static let maxRetentionDays = 365

        // UserDefaults keys
        static let historyKey = "clipboardHistory"
        static let maxEntriesKey = "clipboardHistoryMaxEntries"
        static let retentionDaysKey = "clipboardHistoryRetentionDays"
        static let isEnabledKey = "clipboardHistoryEnabled"
    }

    // MARK: - Published Properties

    /// Current clipboard history (newest first)
    @Published private(set) var entries: [ClipboardHistoryEntry] = []

    /// Maximum number of entries to keep
    @Published var maxEntries: Int {
        didSet {
            let clamped = max(Constants.minEntries, min(Constants.maxEntries, maxEntries))
            if clamped != maxEntries {
                maxEntries = clamped
            }
            UserDefaults.standard.set(maxEntries, forKey: Constants.maxEntriesKey)
            trimEntries()
            print("ClipboardHistoryManager: [US-030] Max entries set to \(maxEntries)")
        }
    }

    /// Number of days to retain history entries
    @Published var retentionDays: Int {
        didSet {
            let clamped = max(Constants.minRetentionDays, min(Constants.maxRetentionDays, retentionDays))
            if clamped != retentionDays {
                retentionDays = clamped
            }
            UserDefaults.standard.set(retentionDays, forKey: Constants.retentionDaysKey)
            cleanupOldEntries()
            print("ClipboardHistoryManager: [US-030] Retention days set to \(retentionDays)")
        }
    }

    /// Whether clipboard history is enabled
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Constants.isEnabledKey)
            print("ClipboardHistoryManager: [US-030] History enabled: \(isEnabled)")
        }
    }

    /// Whether there are any entries in history
    var hasEntries: Bool {
        return !entries.isEmpty
    }

    /// Total word count across all entries
    var totalWordCount: Int {
        return entries.reduce(0) { $0 + $1.wordCount }
    }

    /// Range for configurable max entries
    static var maxEntriesRange: ClosedRange<Int> {
        return Constants.minEntries...Constants.maxEntries
    }

    /// Range for configurable retention days
    static var retentionDaysRange: ClosedRange<Int> {
        return Constants.minRetentionDays...Constants.maxRetentionDays
    }

    // MARK: - Initialization

    private init() {
        // Load settings from UserDefaults
        let savedMaxEntries = UserDefaults.standard.integer(forKey: Constants.maxEntriesKey)
        self.maxEntries = savedMaxEntries > 0 ? savedMaxEntries : Constants.defaultMaxEntries

        let savedRetentionDays = UserDefaults.standard.integer(forKey: Constants.retentionDaysKey)
        self.retentionDays = savedRetentionDays > 0 ? savedRetentionDays : Constants.defaultRetentionDays

        // Default to enabled if not set
        if UserDefaults.standard.object(forKey: Constants.isEnabledKey) == nil {
            self.isEnabled = true
        } else {
            self.isEnabled = UserDefaults.standard.bool(forKey: Constants.isEnabledKey)
        }

        // Load history from persistent storage
        loadHistory()

        // Clean up old entries on startup
        cleanupOldEntries()

        print("ClipboardHistoryManager: [US-030] Initialized with \(entries.count) entries, maxEntries=\(maxEntries), retentionDays=\(retentionDays), enabled=\(isEnabled)")
    }

    // MARK: - Public Methods

    /// Record a new transcription to history
    /// - Parameter text: The transcribed text to record
    func recordEntry(_ text: String) {
        // Skip if disabled
        guard isEnabled else {
            return
        }

        // Skip empty text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Check for duplicate (same text within last 5 seconds)
        if let lastEntry = entries.first,
           lastEntry.text == text,
           Date().timeIntervalSince(lastEntry.timestamp) < 5 {
            print("ClipboardHistoryManager: [US-030] Skipping duplicate entry")
            return
        }

        let entry = ClipboardHistoryEntry(text: text)

        // Add to history (newest first)
        entries.insert(entry, at: 0)

        // Trim and save
        trimEntries()
        saveHistory()

        print("ClipboardHistoryManager: [US-030] Recorded entry - \(entry.wordCount) words, \(entry.characterCount) chars, total: \(entries.count)")
    }

    /// Get entries grouped by date category
    func entriesGroupedByDate() -> [(category: HistoryDateCategory, entries: [ClipboardHistoryEntry])] {
        var grouped: [HistoryDateCategory: [ClipboardHistoryEntry]] = [:]

        for entry in entries {
            let category = HistoryDateCategory.category(for: entry.timestamp)
            grouped[category, default: []].append(entry)
        }

        // Return in chronological order (Today first)
        return HistoryDateCategory.allCases.compactMap { category in
            guard let categoryEntries = grouped[category], !categoryEntries.isEmpty else {
                return nil
            }
            return (category: category, entries: categoryEntries)
        }
    }

    /// Search entries by text
    /// - Parameter query: The search query
    /// - Returns: Filtered entries containing the query
    func searchEntries(query: String) -> [ClipboardHistoryEntry] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return entries
        }

        let lowercasedQuery = query.lowercased()
        return entries.filter { entry in
            entry.text.lowercased().contains(lowercasedQuery)
        }
    }

    /// Remove a specific entry from history
    /// - Parameter entry: The entry to remove
    func removeEntry(_ entry: ClipboardHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        saveHistory()
        print("ClipboardHistoryManager: [US-030] Removed entry, remaining: \(entries.count)")
    }

    /// Remove entry by ID
    /// - Parameter id: The UUID of the entry to remove
    func removeEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        saveHistory()
        print("ClipboardHistoryManager: [US-030] Removed entry by ID, remaining: \(entries.count)")
    }

    /// Clear all history entries
    func clearHistory() {
        entries.removeAll()
        saveHistory()
        print("ClipboardHistoryManager: [US-030] History cleared")
    }

    /// Copy entry text to system clipboard
    /// - Parameter entry: The entry to copy
    func copyToClipboard(_ entry: ClipboardHistoryEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
        print("ClipboardHistoryManager: [US-030] Copied entry to clipboard - \(entry.characterCount) chars")
    }

    /// Reset settings to defaults
    func resetToDefaults() {
        maxEntries = Constants.defaultMaxEntries
        retentionDays = Constants.defaultRetentionDays
        isEnabled = true
        print("ClipboardHistoryManager: [US-030] Reset to defaults")
    }

    // MARK: - Private Methods

    /// Trim entries to configured max
    private func trimEntries() {
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
    }

    /// Remove entries older than retention period
    private func cleanupOldEntries() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        let beforeCount = entries.count
        entries.removeAll { $0.timestamp < cutoffDate }

        let cleaned = beforeCount - entries.count
        if cleaned > 0 {
            saveHistory()
            print("ClipboardHistoryManager: [US-030] Cleaned up \(cleaned) old entries")
        }
    }

    /// Load history from UserDefaults
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: Constants.historyKey) else {
            print("ClipboardHistoryManager: [US-030] No saved history found")
            return
        }

        do {
            let decoder = JSONDecoder()
            entries = try decoder.decode([ClipboardHistoryEntry].self, from: data)
            print("ClipboardHistoryManager: [US-030] Loaded \(entries.count) entries from storage")
        } catch {
            print("ClipboardHistoryManager: [US-030] Failed to load history: \(error)")
            entries = []
        }
    }

    /// Save history to UserDefaults
    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(entries)
            UserDefaults.standard.set(data, forKey: Constants.historyKey)
        } catch {
            print("ClipboardHistoryManager: [US-030] Failed to save history: \(error)")
        }
    }
}
