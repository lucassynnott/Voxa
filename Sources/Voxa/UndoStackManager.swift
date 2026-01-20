import Foundation

// MARK: - Undo Stack Manager
// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║ US-026: Full Undo Stack for Transcriptions                                   ║
// ║                                                                              ║
// ║ Tracks transcription insertions to enable Cmd+Z undo functionality:          ║
// ║ - Maintains a stack of recent insertions with text and character counts      ║
// ║ - Supports undo across different applications                                ║
// ║ - Provides character count for deletion simulation                           ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

/// Data model for an undo entry representing an inserted transcription
struct UndoEntry: Codable, Identifiable {
    let id: UUID
    let text: String
    let characterCount: Int
    let timestamp: Date

    init(text: String) {
        self.id = UUID()
        self.text = text
        self.characterCount = text.count
        self.timestamp = Date()
    }
}

/// Manager for tracking transcription insertions for undo functionality
/// Thread-safe singleton pattern
@MainActor
final class UndoStackManager: ObservableObject {
    // MARK: - Singleton

    static let shared = UndoStackManager()

    // MARK: - Constants

    private enum Constants {
        static let maxUndoStackSize = 20 // Keep last 20 insertions
        static let undoTimeoutSeconds: TimeInterval = 300 // 5 minutes - entries older than this are cleared
    }

    // MARK: - Published Properties

    /// Current undo stack (newest first)
    @Published private(set) var undoStack: [UndoEntry] = []

    /// Whether there's an entry available to undo
    var canUndo: Bool {
        return !undoStack.isEmpty
    }

    /// The most recent entry that can be undone
    var topEntry: UndoEntry? {
        return undoStack.first
    }

    // MARK: - Initialization

    private init() {
        print("UndoStackManager: [US-026] Initialized")
    }

    // MARK: - Public Methods

    /// Record a new transcription insertion for potential undo
    /// - Parameter text: The text that was inserted
    func recordInsertion(_ text: String) {
        // Skip empty text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let entry = UndoEntry(text: text)

        // Add to stack (newest first)
        undoStack.insert(entry, at: 0)

        // Trim stack if needed
        if undoStack.count > Constants.maxUndoStackSize {
            undoStack = Array(undoStack.prefix(Constants.maxUndoStackSize))
        }

        // Clean up old entries
        cleanupOldEntries()

        print("UndoStackManager: [US-026] Recorded insertion - \(entry.characterCount) characters, stack size: \(undoStack.count)")
    }

    /// Pop the most recent entry from the stack (after successful undo)
    /// - Returns: The entry that was removed, or nil if stack is empty
    @discardableResult
    func popTopEntry() -> UndoEntry? {
        guard !undoStack.isEmpty else {
            return nil
        }

        let entry = undoStack.removeFirst()
        print("UndoStackManager: [US-026] Popped entry - \(entry.characterCount) characters, remaining: \(undoStack.count)")
        return entry
    }

    /// Clear the entire undo stack
    func clearStack() {
        undoStack.removeAll()
        print("UndoStackManager: [US-026] Stack cleared")
    }

    // MARK: - Private Methods

    /// Remove entries older than the timeout threshold
    private func cleanupOldEntries() {
        let cutoffDate = Date().addingTimeInterval(-Constants.undoTimeoutSeconds)
        let beforeCount = undoStack.count
        undoStack.removeAll { $0.timestamp < cutoffDate }

        if undoStack.count < beforeCount {
            print("UndoStackManager: [US-026] Cleaned up \(beforeCount - undoStack.count) old entries")
        }
    }
}
