import Foundation
import AppKit

// MARK: - Dictionary Manager
// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║ US-636: Custom Dictionary View - Dictionary Management                       ║
// ║                                                                              ║
// ║ Manages custom dictionary entries that users can add for better              ║
// ║ transcription accuracy:                                                      ║
// ║ - Create, edit, and delete dictionary entries                                ║
// ║ - Optional pronunciation hint for each word                                  ║
// ║ - Search and filter entries by word or pronunciation                         ║
// ║ - Import/export dictionary as text file                                      ║
// ║ - Persist entries to UserDefaults                                            ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

/// Data model for a custom dictionary entry
/// US-636: Stores word, optional pronunciation hint, and metadata
struct DictionaryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var word: String
    var pronunciationHint: String? // Optional pronunciation hint (e.g., "ay-ther" for "either")
    let createdAt: Date
    var updatedAt: Date
    
    /// Initialize a new dictionary entry
    init(word: String, pronunciationHint: String? = nil) {
        self.id = UUID()
        self.word = word
        self.pronunciationHint = pronunciationHint
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Update entry content and timestamp
    mutating func update(word: String? = nil, pronunciationHint: String? = nil) {
        if let newWord = word {
            self.word = newWord
        }
        // Allow setting pronunciation hint to nil or a new value
        self.pronunciationHint = pronunciationHint
        self.updatedAt = Date()
    }
    
    /// Character count in word
    var characterCount: Int {
        return word.count
    }
    
    /// Whether the entry has a pronunciation hint
    var hasPronunciationHint: Bool {
        return pronunciationHint != nil && !pronunciationHint!.isEmpty
    }
    
    /// Relative date string for display
    var relativeDateString: String {
        let calendar = Calendar.current
        let now = Date()
        let entryDate = calendar.startOfDay(for: updatedAt)
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
            return formatter.string(from: updatedAt)
        }
    }
    
    /// Full timestamp string
    var fullTimestampString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: updatedAt)
    }
    
    /// Relative date string for "Updated X" display
    var updatedRelativeString: String {
        return relativeDateString
    }
    
    static func == (lhs: DictionaryEntry, rhs: DictionaryEntry) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Manager for dictionary entry storage and operations
/// Thread-safe singleton pattern with UserDefaults persistence
@MainActor
final class DictionaryManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = DictionaryManager()
    
    // MARK: - Constants
    
    private enum Constants {
        static let dictionaryDataKey = "customDictionaryData"
        static let lastUpdatedKey = "customDictionaryLastUpdated"
        static let maxEntries = 1000 // Maximum number of dictionary entries
    }
    
    // MARK: - Published Properties
    
    /// All saved dictionary entries (sorted alphabetically by word)
    @Published private(set) var entries: [DictionaryEntry] = []
    
    /// Last updated timestamp for the dictionary
    @Published private(set) var lastUpdated: Date?
    
    // MARK: - Computed Properties
    
    /// Total number of entries
    var count: Int {
        return entries.count
    }
    
    /// Check if dictionary is empty
    var isEmpty: Bool {
        return entries.isEmpty
    }
    
    /// Check if at capacity
    var isAtCapacity: Bool {
        return entries.count >= Constants.maxEntries
    }
    
    /// Total character count across all words
    var totalCharacters: Int {
        return entries.reduce(0) { $0 + $1.characterCount }
    }
    
    /// Number of entries with pronunciation hints
    var entriesWithHints: Int {
        return entries.filter { $0.hasPronunciationHint }.count
    }
    
    // MARK: - Initialization
    
    private init() {
        loadEntries()
        print("DictionaryManager: [US-636] Initialized - \(entries.count) entries loaded")
    }
    
    // MARK: - Public Methods - CRUD Operations
    
    /// Create a new dictionary entry
    /// - Parameters:
    ///   - word: The word to add
    ///   - pronunciationHint: Optional pronunciation hint
    /// - Returns: The created entry, or nil if at capacity or word already exists
    @discardableResult
    func createEntry(word: String, pronunciationHint: String? = nil) -> DictionaryEntry? {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedWord.isEmpty else {
            print("DictionaryManager: [US-636] Cannot create entry - word is empty")
            return nil
        }
        
        guard !isAtCapacity else {
            print("DictionaryManager: [US-636] Cannot create entry - at capacity (\(Constants.maxEntries))")
            return nil
        }
        
        // Check if word already exists (case-insensitive)
        if entries.contains(where: { $0.word.lowercased() == trimmedWord.lowercased() }) {
            print("DictionaryManager: [US-636] Word already exists: '\(trimmedWord)'")
            return nil
        }
        
        let trimmedHint = pronunciationHint?.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = DictionaryEntry(
            word: trimmedWord,
            pronunciationHint: trimmedHint?.isEmpty == true ? nil : trimmedHint
        )
        entries.append(entry)
        sortEntries()
        updateLastUpdated()
        saveEntries()
        
        print("DictionaryManager: [US-636] Created entry '\(trimmedWord)' - Total: \(entries.count)")
        return entry
    }
    
    /// Update an existing dictionary entry
    /// - Parameters:
    ///   - id: Entry ID to update
    ///   - word: New word (optional)
    ///   - pronunciationHint: New pronunciation hint (optional, pass nil to remove)
    /// - Returns: Updated entry, or nil if not found
    @discardableResult
    func updateEntry(id: UUID, word: String? = nil, pronunciationHint: String? = nil) -> DictionaryEntry? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            print("DictionaryManager: [US-636] Entry not found for update: \(id)")
            return nil
        }
        
        let trimmedWord = word?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHint = pronunciationHint?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If updating word, check for duplicates (excluding self)
        if let newWord = trimmedWord, !newWord.isEmpty {
            let isDuplicate = entries.contains { entry in
                entry.id != id && entry.word.lowercased() == newWord.lowercased()
            }
            if isDuplicate {
                print("DictionaryManager: [US-636] Word already exists: '\(newWord)'")
                return nil
            }
        }
        
        entries[index].update(
            word: trimmedWord?.isEmpty == true ? nil : trimmedWord,
            pronunciationHint: trimmedHint?.isEmpty == true ? nil : trimmedHint
        )
        
        sortEntries()
        updateLastUpdated()
        saveEntries()
        
        // Find the updated entry after sorting
        if let updatedEntry = entries.first(where: { $0.id == id }) {
            print("DictionaryManager: [US-636] Updated entry '\(updatedEntry.word)'")
            return updatedEntry
        }
        return nil
    }
    
    /// Update an existing entry (alternative signature accepting DictionaryEntry)
    /// - Parameters:
    ///   - entry: The entry to update
    ///   - word: New word
    ///   - pronunciationHint: New pronunciation hint (pass nil or empty string to remove)
    /// - Returns: Updated entry, or nil if not found
    @discardableResult
    func updateEntry(_ entry: DictionaryEntry, word: String, pronunciationHint: String?) -> DictionaryEntry? {
        // Convert empty string to nil for pronunciation hint
        let finalHint = pronunciationHint?.isEmpty == true ? nil : pronunciationHint
        return updateEntry(id: entry.id, word: word, pronunciationHint: finalHint)
    }
    
    /// Delete a dictionary entry
    /// - Parameter id: Entry ID to delete
    /// - Returns: True if deleted, false if not found
    @discardableResult
    func deleteEntry(id: UUID) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            print("DictionaryManager: [US-636] Entry not found for deletion: \(id)")
            return false
        }
        
        let word = entries[index].word
        entries.remove(at: index)
        updateLastUpdated()
        saveEntries()
        
        print("DictionaryManager: [US-636] Deleted entry '\(word)' - Remaining: \(entries.count)")
        return true
    }
    
    /// Delete an entry by reference
    /// - Parameter entry: Entry to delete
    func deleteEntry(_ entry: DictionaryEntry) {
        deleteEntry(id: entry.id)
    }
    
    /// Get an entry by ID
    /// - Parameter id: Entry ID
    /// - Returns: Entry if found, nil otherwise
    func getEntry(id: UUID) -> DictionaryEntry? {
        return entries.first(where: { $0.id == id })
    }
    
    /// Check if a word already exists in the dictionary (case-insensitive)
    /// - Parameters:
    ///   - word: The word to check
    ///   - excludingEntryId: Optional entry ID to exclude from check (for editing)
    /// - Returns: true if word exists
    func wordExists(_ word: String, excludingEntryId: UUID? = nil) -> Bool {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedWord.isEmpty else { return false }
        return entries.contains { entry in
            entry.id != excludingEntryId &&
            entry.word.lowercased() == trimmedWord
        }
    }
    
    // MARK: - Public Methods - Search and Filter
    
    /// Search entries by word or pronunciation hint
    /// - Parameter query: Search query string
    /// - Returns: Filtered entries matching the query
    func searchEntries(query: String) -> [DictionaryEntry] {
        guard !query.isEmpty else { return entries }
        
        let lowercasedQuery = query.lowercased()
        return entries.filter { entry in
            entry.word.lowercased().contains(lowercasedQuery) ||
            (entry.pronunciationHint?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }
    
    // MARK: - Public Methods - Import/Export
    
    /// Export dictionary as text file content
    /// Format: "word\tpronunciation_hint" (one entry per line, tab-separated)
    /// - Returns: Text content for export
    func exportAsText() -> String {
        var lines: [String] = []
        lines.append("# WispFlow Custom Dictionary")
        lines.append("# Format: word<tab>pronunciation_hint (hint is optional)")
        lines.append("# Exported: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("")
        
        for entry in entries {
            if let hint = entry.pronunciationHint, !hint.isEmpty {
                lines.append("\(entry.word)\t\(hint)")
            } else {
                lines.append(entry.word)
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    /// Export dictionary as JSON data
    /// - Returns: JSON data of all entries
    func exportAsJSON() -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(entries)
        } catch {
            print("DictionaryManager: [US-636] Failed to export as JSON: \(error)")
            return nil
        }
    }
    
    /// Import dictionary from text content
    /// Format: "word\tpronunciation_hint" (one entry per line, tab-separated)
    /// - Parameter text: Text content to import
    /// - Returns: Number of entries imported (new only, skips duplicates)
    @discardableResult
    func importFromText(_ text: String) -> Int {
        let lines = text.components(separatedBy: .newlines)
        var importedCount = 0
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }
            
            // Parse tab-separated or just word
            let parts = trimmedLine.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            let word = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let hint = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : nil
            
            // Skip if word already exists
            if word.isEmpty || wordExists(word) {
                continue
            }
            
            // Create entry (bypass capacity check for import)
            if entries.count < Constants.maxEntries {
                let entry = DictionaryEntry(word: word, pronunciationHint: hint?.isEmpty == true ? nil : hint)
                entries.append(entry)
                importedCount += 1
            }
        }
        
        if importedCount > 0 {
            sortEntries()
            updateLastUpdated()
            saveEntries()
            print("DictionaryManager: [US-636] Imported \(importedCount) entries from text")
        }
        
        return importedCount
    }
    
    /// Import dictionary from JSON data
    /// - Parameter data: JSON data containing entries
    /// - Returns: Number of entries imported (new only, skips duplicates)
    @discardableResult
    func importFromJSON(_ data: Data) -> Int {
        do {
            let importedEntries = try JSONDecoder().decode([DictionaryEntry].self, from: data)
            
            // Merge with existing entries (avoid duplicates by word, case-insensitive)
            let existingWords = Set(entries.map { $0.word.lowercased() })
            let newEntries = importedEntries.filter { !existingWords.contains($0.word.lowercased()) }
            
            // Limit to max capacity
            let availableSlots = Constants.maxEntries - entries.count
            let entriesToAdd = Array(newEntries.prefix(availableSlots))
            
            entries.append(contentsOf: entriesToAdd)
            sortEntries()
            updateLastUpdated()
            saveEntries()
            
            print("DictionaryManager: [US-636] Imported \(entriesToAdd.count) entries from JSON")
            return entriesToAdd.count
        } catch {
            print("DictionaryManager: [US-636] Failed to import from JSON: \(error)")
            return 0
        }
    }
    
    // MARK: - Public Methods - Reset
    
    /// Clear all entries (for testing/reset)
    func clearAllEntries() {
        entries = []
        lastUpdated = nil
        UserDefaults.standard.removeObject(forKey: Constants.dictionaryDataKey)
        UserDefaults.standard.removeObject(forKey: Constants.lastUpdatedKey)
        print("DictionaryManager: [US-636] All entries cleared")
    }
    
    // MARK: - Private Methods
    
    /// Sort entries alphabetically by word (case-insensitive)
    private func sortEntries() {
        entries.sort { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending }
    }
    
    /// Update the last updated timestamp
    private func updateLastUpdated() {
        lastUpdated = Date()
        UserDefaults.standard.set(lastUpdated, forKey: Constants.lastUpdatedKey)
    }
    
    // MARK: - Persistence
    
    private func loadEntries() {
        // Load entries
        if let data = UserDefaults.standard.data(forKey: Constants.dictionaryDataKey) {
            do {
                entries = try JSONDecoder().decode([DictionaryEntry].self, from: data)
                sortEntries()
            } catch {
                print("DictionaryManager: [US-636] Failed to load entries: \(error)")
            }
        }
        
        // Load last updated timestamp
        lastUpdated = UserDefaults.standard.object(forKey: Constants.lastUpdatedKey) as? Date
    }
    
    private func saveEntries() {
        do {
            let encoded = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(encoded, forKey: Constants.dictionaryDataKey)
        } catch {
            print("DictionaryManager: [US-636] Failed to save entries: \(error)")
        }
    }
}
