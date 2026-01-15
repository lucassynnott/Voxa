import Foundation
import AppKit

// MARK: - Snippets Manager
// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║ US-635: Snippets Library View - Snippets Management                          ║
// ║                                                                              ║
// ║ Manages text snippets that users can save and reuse:                         ║
// ║ - Create, edit, and delete snippets                                          ║
// ║ - Optional keyboard shortcut assignment per snippet                          ║
// ║ - Search and filter snippets by title or content                             ║
// ║ - Persist snippets to UserDefaults                                           ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

/// Data model for a text snippet
/// US-635: Stores title, content, optional shortcut, and metadata
struct Snippet: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var shortcut: String? // Optional keyboard shortcut like "⌘1" or custom binding
    let createdAt: Date
    var updatedAt: Date
    
    /// Initialize a new snippet
    init(title: String, content: String, shortcut: String? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.shortcut = shortcut
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Update snippet content and timestamp
    mutating func update(title: String? = nil, content: String? = nil, shortcut: String? = nil) {
        if let newTitle = title {
            self.title = newTitle
        }
        if let newContent = content {
            self.content = newContent
        }
        // Allow setting shortcut to nil or a new value
        self.shortcut = shortcut
        self.updatedAt = Date()
    }
    
    /// Word count in content
    var wordCount: Int {
        let words = content.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        return words.count
    }
    
    /// Preview of content (first 100 characters)
    var contentPreview: String {
        if content.count <= 100 {
            return content
        }
        return String(content.prefix(100)) + "..."
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
    
    /// Character count in content
    var characterCount: Int {
        return content.count
    }
    
    /// Relative date string for "Updated X" display
    var updatedRelativeString: String {
        return relativeDateString
    }
    
    /// Copy snippet content to clipboard
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        print("Snippet: [US-635] Copied '\(title)' to clipboard")
    }
    
    static func == (lhs: Snippet, rhs: Snippet) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Manager for snippet storage and operations
/// Thread-safe singleton pattern with UserDefaults persistence
@MainActor
final class SnippetsManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = SnippetsManager()
    
    // MARK: - Constants
    
    private enum Constants {
        static let snippetsDataKey = "snippetsLibraryData"
        static let maxSnippets = 100 // Maximum number of snippets
    }
    
    // MARK: - Published Properties
    
    /// All saved snippets (sorted by updatedAt, newest first)
    @Published private(set) var snippets: [Snippet] = []
    
    // MARK: - Computed Properties
    
    /// Total number of snippets
    var count: Int {
        return snippets.count
    }
    
    /// Check if snippets library is empty
    var isEmpty: Bool {
        return snippets.isEmpty
    }
    
    /// Check if at capacity
    var isAtCapacity: Bool {
        return snippets.count >= Constants.maxSnippets
    }
    
    // MARK: - Initialization
    
    private init() {
        loadSnippets()
        print("SnippetsManager: [US-635] Initialized - \(snippets.count) snippets loaded")
    }
    
    // MARK: - Public Methods - CRUD Operations
    
    /// Create a new snippet
    /// - Parameters:
    ///   - title: Snippet title
    ///   - content: Snippet content
    ///   - shortcut: Optional keyboard shortcut
    /// - Returns: The created snippet, or nil if at capacity
    @discardableResult
    func createSnippet(title: String, content: String, shortcut: String? = nil) -> Snippet? {
        guard !isAtCapacity else {
            print("SnippetsManager: [US-635] Cannot create snippet - at capacity (\(Constants.maxSnippets))")
            return nil
        }
        
        let snippet = Snippet(title: title, content: content, shortcut: shortcut)
        snippets.insert(snippet, at: 0) // Add at beginning (newest first)
        saveSnippets()
        
        print("SnippetsManager: [US-635] Created snippet '\(title)' - Total: \(snippets.count)")
        return snippet
    }
    
    /// Update an existing snippet
    /// - Parameters:
    ///   - id: Snippet ID to update
    ///   - title: New title (optional)
    ///   - content: New content (optional)
    ///   - shortcut: New shortcut (optional, pass nil to remove)
    /// - Returns: Updated snippet, or nil if not found
    @discardableResult
    func updateSnippet(id: UUID, title: String? = nil, content: String? = nil, shortcut: String? = nil) -> Snippet? {
        guard let index = snippets.firstIndex(where: { $0.id == id }) else {
            print("SnippetsManager: [US-635] Snippet not found for update: \(id)")
            return nil
        }
        
        snippets[index].update(title: title, content: content, shortcut: shortcut)
        
        // Re-sort to move updated snippet to top
        let updatedSnippet = snippets.remove(at: index)
        snippets.insert(updatedSnippet, at: 0)
        
        saveSnippets()
        
        print("SnippetsManager: [US-635] Updated snippet '\(snippets[0].title)'")
        return snippets[0]
    }
    
    /// Update an existing snippet (alternative signature accepting Snippet)
    /// - Parameters:
    ///   - snippet: The snippet to update
    ///   - title: New title
    ///   - content: New content
    ///   - shortcut: New shortcut (pass nil or empty string to remove)
    /// - Returns: Updated snippet, or nil if not found
    @discardableResult
    func updateSnippet(_ snippet: Snippet, title: String, content: String, shortcut: String?) -> Snippet? {
        // Convert empty string to nil for shortcut
        let finalShortcut = shortcut?.isEmpty == true ? nil : shortcut
        return updateSnippet(id: snippet.id, title: title, content: content, shortcut: finalShortcut)
    }
    
    /// Delete a snippet
    /// - Parameter id: Snippet ID to delete
    /// - Returns: True if deleted, false if not found
    @discardableResult
    func deleteSnippet(id: UUID) -> Bool {
        guard let index = snippets.firstIndex(where: { $0.id == id }) else {
            print("SnippetsManager: [US-635] Snippet not found for deletion: \(id)")
            return false
        }
        
        let title = snippets[index].title
        snippets.remove(at: index)
        saveSnippets()
        
        print("SnippetsManager: [US-635] Deleted snippet '\(title)' - Remaining: \(snippets.count)")
        return true
    }
    
    /// Delete a snippet by reference
    /// - Parameter snippet: Snippet to delete
    func deleteSnippet(_ snippet: Snippet) {
        deleteSnippet(id: snippet.id)
    }
    
    /// Get a snippet by ID
    /// - Parameter id: Snippet ID
    /// - Returns: Snippet if found, nil otherwise
    func getSnippet(id: UUID) -> Snippet? {
        return snippets.first(where: { $0.id == id })
    }
    
    // MARK: - Public Methods - Search and Filter
    
    /// Search snippets by title or content
    /// - Parameter query: Search query string
    /// - Returns: Filtered snippets matching the query
    func searchSnippets(query: String) -> [Snippet] {
        guard !query.isEmpty else { return snippets }
        
        let lowercasedQuery = query.lowercased()
        return snippets.filter { snippet in
            snippet.title.lowercased().contains(lowercasedQuery) ||
            snippet.content.lowercased().contains(lowercasedQuery)
        }
    }
    
    /// Check if a shortcut is already in use
    /// - Parameters:
    ///   - shortcut: The shortcut to check
    ///   - excludingSnippetId: Optional snippet ID to exclude from check (for editing)
    /// - Returns: true if shortcut is already used by another snippet
    func isShortcutInUse(_ shortcut: String, excludingSnippetId: UUID? = nil) -> Bool {
        guard !shortcut.isEmpty else { return false }
        let lowercasedShortcut = shortcut.lowercased()
        return snippets.contains { snippet in
            snippet.id != excludingSnippetId &&
            snippet.shortcut?.lowercased() == lowercasedShortcut
        }
    }
    
    // MARK: - Public Methods - Clipboard
    
    /// Copy snippet content to clipboard
    /// - Parameter snippet: Snippet to copy
    func copyToClipboard(_ snippet: Snippet) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(snippet.content, forType: .string)
        
        print("SnippetsManager: [US-635] Copied snippet '\(snippet.title)' to clipboard")
    }
    
    /// Copy snippet content to clipboard by ID
    /// - Parameter id: Snippet ID
    /// - Returns: True if copied, false if not found
    @discardableResult
    func copyToClipboard(id: UUID) -> Bool {
        guard let snippet = getSnippet(id: id) else {
            return false
        }
        copyToClipboard(snippet)
        return true
    }
    
    // MARK: - Public Methods - Import/Export
    
    /// Export all snippets as JSON data
    /// - Returns: JSON data of all snippets
    func exportSnippets() -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(snippets)
        } catch {
            print("SnippetsManager: [US-635] Failed to export snippets: \(error)")
            return nil
        }
    }
    
    /// Import snippets from JSON data
    /// - Parameter data: JSON data containing snippets
    /// - Returns: Number of snippets imported
    @discardableResult
    func importSnippets(from data: Data) -> Int {
        do {
            let importedSnippets = try JSONDecoder().decode([Snippet].self, from: data)
            
            // Merge with existing snippets (avoid duplicates by ID)
            let existingIds = Set(snippets.map { $0.id })
            let newSnippets = importedSnippets.filter { !existingIds.contains($0.id) }
            
            snippets.append(contentsOf: newSnippets)
            snippets.sort { $0.updatedAt > $1.updatedAt }
            
            // Trim to max capacity
            if snippets.count > Constants.maxSnippets {
                snippets = Array(snippets.prefix(Constants.maxSnippets))
            }
            
            saveSnippets()
            
            print("SnippetsManager: [US-635] Imported \(newSnippets.count) snippets")
            return newSnippets.count
        } catch {
            print("SnippetsManager: [US-635] Failed to import snippets: \(error)")
            return 0
        }
    }
    
    // MARK: - Public Methods - Reset
    
    /// Clear all snippets (for testing/reset)
    func clearAllSnippets() {
        snippets = []
        UserDefaults.standard.removeObject(forKey: Constants.snippetsDataKey)
        print("SnippetsManager: [US-635] All snippets cleared")
    }
    
    // MARK: - Persistence
    
    private func loadSnippets() {
        guard let data = UserDefaults.standard.data(forKey: Constants.snippetsDataKey) else {
            return
        }
        
        do {
            snippets = try JSONDecoder().decode([Snippet].self, from: data)
            // Ensure sorted by updatedAt (newest first)
            snippets.sort { $0.updatedAt > $1.updatedAt }
        } catch {
            print("SnippetsManager: [US-635] Failed to load snippets: \(error)")
        }
    }
    
    private func saveSnippets() {
        do {
            let encoded = try JSONEncoder().encode(snippets)
            UserDefaults.standard.set(encoded, forKey: Constants.snippetsDataKey)
        } catch {
            print("SnippetsManager: [US-635] Failed to save snippets: \(error)")
        }
    }
}
