import Foundation

/// Manages text cleanup using rule-based processing and local LLM (when available)
/// Removes filler words, fixes grammar/punctuation, and formats text naturally
@MainActor
final class TextCleanupManager: ObservableObject {
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide access
    /// US-701: Added for SettingsContentView in MainWindow
    static let shared = TextCleanupManager()
    
    // MARK: - Types
    
    /// Cleanup mode
    enum CleanupMode: String, CaseIterable, Identifiable {
        case basic = "basic"
        case standard = "standard"
        case thorough = "thorough"
        case aiPowered = "ai-powered"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .basic: return "Basic (Fast)"
            case .standard: return "Standard (Balanced)"
            case .thorough: return "Thorough (Comprehensive)"
            case .aiPowered: return "AI-Powered (Local LLM)"
            }
        }
        
        var description: String {
            switch self {
            case .basic: return "Quick cleanup: removes common filler words only."
            case .standard: return "Balanced cleanup: removes fillers, fixes basic punctuation."
            case .thorough: return "Full cleanup: removes all fillers, fixes grammar and formatting."
            case .aiPowered: return "Uses local LLM for intelligent text cleanup. Falls back to thorough mode if unavailable."
            }
        }
        
        /// Whether this mode uses LLM
        var usesLLM: Bool {
            return self == .aiPowered
        }
    }
    
    /// Model status (ready immediately since rule-based)
    enum ModelStatus: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case downloaded
        case loading
        case ready
        case error(String)
    }
    
    /// Cleanup status
    enum CleanupStatus: Equatable {
        case idle
        case processing
        case completed(String)
        case error(String)
    }
    
    // MARK: - Constants
    
    private struct Constants {
        static let selectedModeKey = "selectedCleanupMode"
        static let cleanupEnabledKey = "textCleanupEnabled"
        // US-607: Post-processing option keys
        static let autoCapitalizeFirstLetterKey = "postProcessAutoCapitalizeFirstLetter"
        static let addPeriodAtEndKey = "postProcessAddPeriodAtEnd"
        static let trimWhitespaceKey = "postProcessTrimWhitespace"
        // US-023: Auto-capitalize sentences
        static let autoCapitalizeSentencesKey = "postProcessAutoCapitalizeSentences"
        // US-024: Smart quotes
        static let useSmartQuotesKey = "postProcessUseSmartQuotes"
        // US-025: Auto-punctuation based on pauses
        static let autoPunctuationEnabledKey = "postProcessAutoPunctuationEnabled"
        static let pauseForCommaKey = "postProcessPauseForComma"
        static let pauseForPeriodKey = "postProcessPauseForPeriod"
    }
    
    /// Common filler words and phrases to remove
    private static let fillerPatterns: [(pattern: String, mode: CleanupMode)] = [
        // Basic mode - most common fillers
        ("\\b[Uu]m+\\b,?\\s*", .basic),
        ("\\b[Uu]h+\\b,?\\s*", .basic),
        ("\\b[Ee]r+\\b,?\\s*", .basic),
        ("\\b[Aa]h+\\b,?\\s*", .basic),
        
        // Standard mode - additional fillers
        ("\\b[Ll]ike,?\\s+(?=\\w)", .standard),  // "like" followed by word
        ("\\b[Yy]ou know,?\\s*", .standard),
        ("\\b[Ii] mean,?\\s*", .standard),
        ("\\b[Ss]o,?\\s+(?=[A-Z])", .standard),  // "so" at sentence start
        
        // Thorough mode - all fillers
        ("\\b[Aa]ctually,?\\s*", .thorough),
        ("\\b[Bb]asically,?\\s*", .thorough),
        ("\\b[Ll]iterally,?\\s*", .thorough),
        ("\\b[Hh]onestly,?\\s*", .thorough),
        ("\\b[Oo]bviously,?\\s*", .thorough),
        ("\\b[Kk]ind of\\b,?\\s*", .thorough),
        ("\\b[Ss]ort of\\b,?\\s*", .thorough),
        ("\\b[Yy]ou see,?\\s*", .thorough),
        ("\\b[Rr]ight\\??,?\\s*(?=\\w)", .thorough),  // "right" as filler
        ("\\b[Oo]kay so,?\\s*", .thorough),
        ("\\b[Ww]ell,?\\s+(?=[A-Z])", .thorough),  // "well" at sentence start
    ]
    
    /// Contractions to fix
    private static let contractionFixes: [(from: String, to: String)] = [
        ("\\bi m\\b", "I'm"),
        ("\\bim\\b", "I'm"),
        ("\\bdont\\b", "don't"),
        ("\\bwont\\b", "won't"),
        ("\\bcant\\b", "can't"),
        ("\\bwouldnt\\b", "wouldn't"),
        ("\\bcouldnt\\b", "couldn't"),
        ("\\bshouldnt\\b", "shouldn't"),
        ("\\bisnt\\b", "isn't"),
        ("\\barent\\b", "aren't"),
        ("\\bwasnt\\b", "wasn't"),
        ("\\bwerent\\b", "weren't"),
        ("\\bhasnt\\b", "hasn't"),
        ("\\bhavent\\b", "haven't"),
        ("\\bhadnt\\b", "hadn't"),
        ("\\bdoesnt\\b", "doesn't"),
        ("\\bdidnt\\b", "didn't"),
        ("\\bthats\\b", "that's"),
        ("\\bwhats\\b", "what's"),
        ("\\bheres\\b", "here's"),
        ("\\btheres\\b", "there's"),
        ("\\bits\\b(?=\\s+[a-z])", "it's"),  // "its" followed by lowercase (likely "it's")
        ("\\bive\\b", "I've"),
        ("\\byoure\\b", "you're"),
        ("\\btheyre\\b", "they're"),
        ("\\bwere\\b(?=\\s+going|\\s+going)", "we're"),
    ]
    
    // MARK: - Properties
    
    /// Currently selected cleanup mode
    @Published var selectedMode: CleanupMode {
        didSet {
            UserDefaults.standard.set(selectedMode.rawValue, forKey: Constants.selectedModeKey)
        }
    }
    
    /// Status of the cleanup system (always ready for rule-based)
    @Published private(set) var modelStatus: ModelStatus = .ready
    
    /// Current cleanup status
    @Published private(set) var cleanupStatus: CleanupStatus = .idle
    
    /// Whether text cleanup is enabled
    @Published var isCleanupEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isCleanupEnabled, forKey: Constants.cleanupEnabledKey)
        }
    }
    
    /// Status messages for UI display
    @Published private(set) var statusMessage: String = "Ready"
    
    // MARK: - US-607: Post-Processing Options
    
    /// Option to auto-capitalize the first letter of transcription
    @Published var autoCapitalizeFirstLetter: Bool {
        didSet {
            UserDefaults.standard.set(autoCapitalizeFirstLetter, forKey: Constants.autoCapitalizeFirstLetterKey)
        }
    }
    
    /// Option to add period at the end of sentences (if no ending punctuation)
    @Published var addPeriodAtEnd: Bool {
        didSet {
            UserDefaults.standard.set(addPeriodAtEnd, forKey: Constants.addPeriodAtEndKey)
        }
    }
    
    /// Option to trim leading/trailing whitespace
    @Published var trimWhitespace: Bool {
        didSet {
            UserDefaults.standard.set(trimWhitespace, forKey: Constants.trimWhitespaceKey)
        }
    }

    // MARK: - US-023: Auto-Capitalize Sentences

    /// Option to auto-capitalize the first letter of each sentence
    /// This capitalizes after sentence-ending punctuation (. ! ?) and the first letter of the text
    @Published var autoCapitalizeSentences: Bool {
        didSet {
            UserDefaults.standard.set(autoCapitalizeSentences, forKey: Constants.autoCapitalizeSentencesKey)
        }
    }

    // MARK: - US-024: Smart Quotes

    /// Option to convert straight quotes to curly (smart) quotes
    /// Converts " to " or " and ' to ' or ' based on context
    @Published var useSmartQuotes: Bool {
        didSet {
            UserDefaults.standard.set(useSmartQuotes, forKey: Constants.useSmartQuotesKey)
        }
    }

    // MARK: - US-025: Auto-Punctuation Based on Pauses

    /// Option to enable auto-punctuation based on speech pauses
    /// When enabled, pauses between words/phrases can trigger punctuation insertion
    @Published var autoPunctuationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoPunctuationEnabled, forKey: Constants.autoPunctuationEnabledKey)
        }
    }

    /// Pause duration threshold for comma insertion (in seconds)
    /// Pauses longer than this but shorter than periodPause will insert a comma
    /// Range: 0.3 - 1.5 seconds, default 0.5
    @Published var pauseForComma: Double {
        didSet {
            UserDefaults.standard.set(pauseForComma, forKey: Constants.pauseForCommaKey)
        }
    }

    /// Pause duration threshold for period insertion (in seconds)
    /// Pauses longer than this will insert a period
    /// Range: 0.8 - 3.0 seconds, default 1.2
    @Published var pauseForPeriod: Double {
        didSet {
            UserDefaults.standard.set(pauseForPeriod, forKey: Constants.pauseForPeriodKey)
        }
    }

    // MARK: - Callbacks
    
    /// Called when cleanup completes
    var onCleanupComplete: ((String) -> Void)?
    
    /// Called when an error occurs
    var onError: ((String) -> Void)?
    
    // MARK: - LLM Integration
    
    /// LLM Manager for AI-powered cleanup
    var llmManager: LLMManager?
    
    // MARK: - Initialization
    
    init() {
        // Load saved mode preference
        if let savedMode = UserDefaults.standard.string(forKey: Constants.selectedModeKey),
           let mode = CleanupMode(rawValue: savedMode) {
            selectedMode = mode
        } else {
            selectedMode = .standard // Default to standard mode
        }
        
        // Load cleanup enabled preference (default to true)
        isCleanupEnabled = UserDefaults.standard.object(forKey: Constants.cleanupEnabledKey) as? Bool ?? true
        
        // US-607: Load post-processing preferences (all default to true for better UX)
        autoCapitalizeFirstLetter = UserDefaults.standard.object(forKey: Constants.autoCapitalizeFirstLetterKey) as? Bool ?? true
        addPeriodAtEnd = UserDefaults.standard.object(forKey: Constants.addPeriodAtEndKey) as? Bool ?? true
        trimWhitespace = UserDefaults.standard.object(forKey: Constants.trimWhitespaceKey) as? Bool ?? true

        // US-023: Load auto-capitalize sentences preference (default to true)
        autoCapitalizeSentences = UserDefaults.standard.object(forKey: Constants.autoCapitalizeSentencesKey) as? Bool ?? true

        // US-024: Load smart quotes preference (default to false - opt-in feature)
        useSmartQuotes = UserDefaults.standard.object(forKey: Constants.useSmartQuotesKey) as? Bool ?? false

        // US-025: Load auto-punctuation preferences (default to false - opt-in feature)
        autoPunctuationEnabled = UserDefaults.standard.object(forKey: Constants.autoPunctuationEnabledKey) as? Bool ?? false
        pauseForComma = UserDefaults.standard.object(forKey: Constants.pauseForCommaKey) as? Double ?? 0.5
        pauseForPeriod = UserDefaults.standard.object(forKey: Constants.pauseForPeriodKey) as? Double ?? 1.2

        print("TextCleanupManager initialized with mode: \(selectedMode.rawValue), cleanup enabled: \(isCleanupEnabled)")
        print("TextCleanupManager: [US-607] Post-processing: capitalize=\(autoCapitalizeFirstLetter), period=\(addPeriodAtEnd), trim=\(trimWhitespace)")
        print("TextCleanupManager: [US-023] Auto-capitalize sentences: \(autoCapitalizeSentences)")
        print("TextCleanupManager: [US-025] Auto-punctuation: enabled=\(autoPunctuationEnabled), comma=\(pauseForComma)s, period=\(pauseForPeriod)s")
    }
    
    // MARK: - Text Cleanup
    
    /// Clean up transcribed text
    /// - Parameter text: Raw transcribed text to clean up
    /// - Returns: Cleaned text or original text if cleanup is disabled
    func cleanupText(_ text: String) async -> String {
        // If cleanup is disabled, return original text
        guard isCleanupEnabled else {
            print("TextCleanupManager: Cleanup disabled, returning original text")
            return text
        }
        
        // If text is empty or whitespace only, return as-is
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return text
        }
        
        cleanupStatus = .processing
        statusMessage = "Cleaning up text..."
        
        print("TextCleanupManager: Cleaning up text with mode \(selectedMode.rawValue): \(text)")
        
        var cleanedText: String
        
        // If AI-powered mode is selected, try LLM first
        if selectedMode == .aiPowered {
            if let llm = llmManager, llm.isReady {
                statusMessage = "AI cleanup in progress..."
                if let llmResult = await llm.cleanupText(trimmedText) {
                    cleanedText = llmResult
                    print("TextCleanupManager: LLM cleanup successful")
                } else {
                    // LLM failed, fall back to thorough rule-based cleanup
                    print("TextCleanupManager: LLM cleanup failed, falling back to rule-based")
                    statusMessage = "Falling back to rule-based cleanup..."
                    cleanedText = performCleanup(trimmedText, forcedMode: .thorough)
                }
            } else {
                // LLM not available, fall back to thorough rule-based cleanup
                print("TextCleanupManager: LLM not available, falling back to rule-based")
                statusMessage = "LLM unavailable, using rule-based cleanup..."
                cleanedText = performCleanup(trimmedText, forcedMode: .thorough)
            }
        } else {
            // Use rule-based cleanup
            cleanedText = performCleanup(trimmedText)
        }
        
        cleanupStatus = .completed(cleanedText)
        statusMessage = "Cleanup complete"
        print("TextCleanupManager: Cleanup result: \(cleanedText)")
        
        onCleanupComplete?(cleanedText)
        return cleanedText
    }
    
    /// Perform the actual text cleanup
    /// - Parameters:
    ///   - text: The text to clean up
    ///   - forcedMode: Optional mode to force (used for fallback from AI mode)
    private func performCleanup(_ text: String, forcedMode: CleanupMode? = nil) -> String {
        var cleaned = text
        let modeToUse = forcedMode ?? selectedMode
        
        // Step 1: Remove filler words based on mode
        cleaned = removeFillerWords(cleaned, mode: modeToUse)
        
        // Step 2: Fix contractions (standard and thorough modes)
        if modeToUse != .basic {
            cleaned = fixContractions(cleaned)
        }
        
        // Step 3: Clean up spacing
        cleaned = cleanupSpacing(cleaned)
        
        // Step 4: Fix capitalization
        cleaned = fixCapitalization(cleaned)
        
        // Step 5: Fix punctuation (thorough mode)
        if modeToUse == .thorough || modeToUse == .aiPowered {
            cleaned = fixPunctuation(cleaned)
        }
        
        // Step 6: Ensure proper ending
        cleaned = ensureProperEnding(cleaned)
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Remove filler words based on current mode
    private func removeFillerWords(_ text: String, mode: CleanupMode? = nil) -> String {
        var cleaned = text
        let modeToUse = mode ?? selectedMode
        
        // Determine which patterns to apply based on mode
        let applicablePatterns = Self.fillerPatterns.filter { pattern in
            switch modeToUse {
            case .basic:
                return pattern.mode == .basic
            case .standard:
                return pattern.mode == .basic || pattern.mode == .standard
            case .thorough, .aiPowered:
                return true  // All patterns
            }
        }
        
        for (pattern, _) in applicablePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    options: [],
                    range: NSRange(location: 0, length: cleaned.utf16.count),
                    withTemplate: ""
                )
            }
        }
        
        return cleaned
    }
    
    /// Fix common contraction issues
    private func fixContractions(_ text: String) -> String {
        var cleaned = text
        
        for (from, to) in Self.contractionFixes {
            if let regex = try? NSRegularExpression(pattern: from, options: [.caseInsensitive]) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    options: [],
                    range: NSRange(location: 0, length: cleaned.utf16.count),
                    withTemplate: to
                )
            }
        }
        
        // Fix "i" to "I"
        if let regex = try? NSRegularExpression(pattern: "\\bi\\b", options: []) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(location: 0, length: cleaned.utf16.count),
                withTemplate: "I"
            )
        }
        
        return cleaned
    }
    
    /// Clean up extra spaces
    private func cleanupSpacing(_ text: String) -> String {
        var cleaned = text
        
        // Remove multiple spaces
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }
        
        // Remove space before punctuation
        cleaned = cleaned.replacingOccurrences(of: " ,", with: ",")
        cleaned = cleaned.replacingOccurrences(of: " .", with: ".")
        cleaned = cleaned.replacingOccurrences(of: " ?", with: "?")
        cleaned = cleaned.replacingOccurrences(of: " !", with: "!")
        
        // Ensure space after punctuation
        if let regex = try? NSRegularExpression(pattern: "([.!?])([A-Za-z])", options: []) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(location: 0, length: cleaned.utf16.count),
                withTemplate: "$1 $2"
            )
        }
        
        return cleaned
    }
    
    /// Fix capitalization at sentence starts
    private func fixCapitalization(_ text: String) -> String {
        var cleaned = text
        
        // Capitalize first letter of text
        if let firstChar = cleaned.first, firstChar.isLetter && firstChar.isLowercase {
            cleaned = cleaned.prefix(1).uppercased() + cleaned.dropFirst()
        }
        
        // Capitalize after sentence-ending punctuation
        if let regex = try? NSRegularExpression(pattern: "([.!?])\\s+([a-z])", options: []) {
            let range = NSRange(location: 0, length: cleaned.utf16.count)
            
            // Find all matches and process from end to preserve indices
            let matches = regex.matches(in: cleaned, options: [], range: range)
            for match in matches.reversed() {
                if let letterRange = Range(match.range(at: 2), in: cleaned) {
                    let letter = String(cleaned[letterRange]).uppercased()
                    cleaned = cleaned.replacingCharacters(in: letterRange, with: letter)
                }
            }
        }
        
        return cleaned
    }
    
    /// Fix punctuation issues
    private func fixPunctuation(_ text: String) -> String {
        var cleaned = text
        
        // Fix multiple punctuation marks
        if let regex = try? NSRegularExpression(pattern: "([.!?]){2,}", options: []) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(location: 0, length: cleaned.utf16.count),
                withTemplate: "$1"
            )
        }
        
        // Add comma before "but", "and", "or" in longer sentences (heuristic)
        if let regex = try? NSRegularExpression(pattern: "\\s+(but|and|or)\\s+", options: [.caseInsensitive]) {
            let range = NSRange(location: 0, length: cleaned.utf16.count)
            let matches = regex.matches(in: cleaned, options: [], range: range)
            
            // Only add commas if there are multiple clauses
            if matches.count <= 2 {
                for match in matches.reversed() {
                    if let matchRange = Range(match.range, in: cleaned) {
                        let matched = String(cleaned[matchRange])
                        // Check if there's already a comma
                        if !matched.contains(",") {
                            let replacement = ", " + matched.trimmingCharacters(in: .whitespaces) + " "
                            cleaned = cleaned.replacingCharacters(in: matchRange, with: replacement)
                        }
                    }
                }
            }
        }
        
        return cleaned
    }
    
    /// Ensure text ends with proper punctuation
    private func ensureProperEnding(_ text: String) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleaned.isEmpty else { return cleaned }
        
        let lastChar = cleaned.last!
        
        // If already has ending punctuation, we're done
        if ".!?".contains(lastChar) {
            return cleaned
        }
        
        // Check if it looks like a question
        let questionWords = ["what", "when", "where", "who", "why", "how", "is", "are", "do", "does", "did", "can", "could", "would", "should", "will"]
        let lowercased = cleaned.lowercased()
        
        for word in questionWords {
            if lowercased.hasPrefix(word + " ") {
                return cleaned + "?"
            }
        }
        
        // Default to period
        return cleaned + "."
    }
    
    /// Reset cleanup status to idle
    func resetStatus() {
        cleanupStatus = .idle
        statusMessage = "Ready"
    }
    
    // MARK: - Status
    
    /// Check if the manager is ready to clean up text
    var isReady: Bool {
        return modelStatus == .ready
    }
    
    // MARK: - US-607: Post-Processing Methods
    
    /// Apply post-processing options to text
    /// This is called AFTER cleanup (or on raw text if cleanup is disabled)
    /// These are independent, configurable options that run regardless of cleanup mode
    /// - Parameter text: The text to post-process
    /// - Returns: Post-processed text
    func applyPostProcessing(_ text: String) -> String {
        var result = text

        // Step 1: Trim whitespace (if enabled)
        if trimWhitespace {
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Guard against empty text after trimming
        guard !result.isEmpty else {
            return result
        }

        // Step 2: Auto-capitalize sentences (if enabled) - US-023
        // This capitalizes first letter of text AND first letter after sentence-ending punctuation
        if autoCapitalizeSentences {
            result = capitalizeSentences(result)
        }
        // Step 2b: Auto-capitalize first letter only (if sentences not enabled but first letter is)
        else if autoCapitalizeFirstLetter {
            if let firstChar = result.first, firstChar.isLetter && firstChar.isLowercase {
                result = result.prefix(1).uppercased() + result.dropFirst()
            }
        }

        // Step 3: Add period at end (if enabled and text doesn't already have ending punctuation)
        if addPeriodAtEnd {
            let lastChar = result.last!
            // Only add period if text doesn't already end with punctuation
            if !".!?;:".contains(lastChar) {
                result = result + "."
            }
        }

        // Step 4: Convert to smart quotes (if enabled) - US-024
        if useSmartQuotes {
            result = convertToSmartQuotes(result)
        }

        print("TextCleanupManager: [US-607/US-023/US-024] Post-processing applied (capitalizeSentences=\(autoCapitalizeSentences), capitalizeFirst=\(autoCapitalizeFirstLetter), period=\(addPeriodAtEnd), trim=\(trimWhitespace), smartQuotes=\(useSmartQuotes)): '\(text)' -> '\(result)'")

        return result
    }

    // MARK: - US-023: Sentence Capitalization

    /// Capitalize the first letter of each sentence
    /// - Parameter text: The text to capitalize
    /// - Returns: Text with capitalized sentence starts
    private func capitalizeSentences(_ text: String) -> String {
        var result = text

        // Capitalize first letter of text
        if let firstChar = result.first, firstChar.isLetter && firstChar.isLowercase {
            result = result.prefix(1).uppercased() + result.dropFirst()
        }

        // Capitalize after sentence-ending punctuation (. ! ?)
        // Pattern matches: punctuation, whitespace(s), lowercase letter
        if let regex = try? NSRegularExpression(pattern: "([.!?])\\s+([a-z])", options: []) {
            let range = NSRange(location: 0, length: result.utf16.count)

            // Find all matches and process from end to preserve indices
            let matches = regex.matches(in: result, options: [], range: range)
            for match in matches.reversed() {
                if let letterRange = Range(match.range(at: 2), in: result) {
                    let letter = String(result[letterRange]).uppercased()
                    result = result.replacingCharacters(in: letterRange, with: letter)
                }
            }
        }

        return result
    }

    // MARK: - US-024: Smart Quotes

    /// Convert straight quotes to curly (smart) quotes
    /// - Parameter text: The text to convert
    /// - Returns: Text with smart quotes
    private func convertToSmartQuotes(_ text: String) -> String {
        var result = text
        var chars = Array(result)

        // Track quote state for proper opening/closing
        var inDoubleQuote = false
        var inSingleQuote = false

        var i = 0
        while i < chars.count {
            let char = chars[i]

            // Handle double quotes
            if char == "\"" {
                // Determine if this is an opening or closing quote
                // Opening quote: at start, after whitespace, or after opening punctuation
                let isOpening: Bool
                if i == 0 {
                    isOpening = true
                } else {
                    let prevChar = chars[i - 1]
                    isOpening = prevChar.isWhitespace || "([{".contains(prevChar)
                }

                if isOpening && !inDoubleQuote {
                    chars[i] = "\u{201C}" // " Left double quotation mark
                    inDoubleQuote = true
                } else {
                    chars[i] = "\u{201D}" // " Right double quotation mark
                    inDoubleQuote = false
                }
            }
            // Handle single quotes and apostrophes
            else if char == "'" || char == "'" {
                // Determine context: apostrophe in contraction vs opening/closing quote
                // Check if it's likely an apostrophe (between letters)
                let prevIsLetter = i > 0 && chars[i - 1].isLetter
                let nextIsLetter = i < chars.count - 1 && chars[i + 1].isLetter

                if prevIsLetter && nextIsLetter {
                    // Apostrophe in contraction (e.g., don't, it's)
                    chars[i] = "\u{2019}" // ' Right single quotation mark (used for apostrophe)
                } else if prevIsLetter && !nextIsLetter {
                    // Closing quote or possessive ending (e.g., dogs')
                    chars[i] = "\u{2019}" // ' Right single quotation mark
                    inSingleQuote = false
                } else {
                    // Opening or closing single quote
                    let isOpening: Bool
                    if i == 0 {
                        isOpening = true
                    } else {
                        let prevChar = chars[i - 1]
                        isOpening = prevChar.isWhitespace || "([{\"".contains(prevChar) || prevChar == "\u{201C}"
                    }

                    if isOpening && !inSingleQuote {
                        chars[i] = "\u{2018}" // ' Left single quotation mark
                        inSingleQuote = true
                    } else {
                        chars[i] = "\u{2019}" // ' Right single quotation mark
                        inSingleQuote = false
                    }
                }
            }

            i += 1
        }

        result = String(chars)
        return result
    }

    // MARK: - US-025: Auto-Punctuation Based on Pauses

    /// Word timing information for pause-based punctuation
    struct WordTiming {
        let word: String
        let startTime: Double
        let endTime: Double
    }

    /// Apply auto-punctuation based on word timings
    /// This method inserts punctuation based on pause durations between words
    /// - Parameters:
    ///   - text: The transcribed text
    ///   - wordTimings: Optional array of word timing information. If nil, uses pattern-based punctuation.
    /// - Returns: Text with punctuation inserted at pause points
    func applyAutoPunctuation(_ text: String, wordTimings: [WordTiming]? = nil) -> String {
        guard autoPunctuationEnabled else {
            return text
        }

        // If we have word timings, use pause-based punctuation
        if let timings = wordTimings, !timings.isEmpty {
            return applyTimingBasedPunctuation(text, wordTimings: timings)
        }

        // Otherwise, use pattern-based punctuation enhancement
        return applyPatternBasedPunctuation(text)
    }

    /// Apply punctuation based on actual word timing/pause data
    /// - Parameters:
    ///   - text: The original text
    ///   - wordTimings: Array of word timing information
    /// - Returns: Text with pause-based punctuation
    private func applyTimingBasedPunctuation(_ text: String, wordTimings: [WordTiming]) -> String {
        guard wordTimings.count > 1 else {
            return text
        }

        var result = ""
        var textIndex = text.startIndex

        for i in 0..<wordTimings.count {
            let currentWord = wordTimings[i]

            // Find and append the word from the original text
            if let range = text.range(of: currentWord.word, range: textIndex..<text.endIndex, locale: nil) {
                // Append any text before this word (spaces, etc.)
                result += text[textIndex..<range.lowerBound]
                result += text[range]
                textIndex = range.upperBound

                // Check if this is not the last word
                if i < wordTimings.count - 1 {
                    let nextWord = wordTimings[i + 1]
                    let pauseDuration = nextWord.startTime - currentWord.endTime

                    // Don't add punctuation if the word already ends with punctuation
                    let lastChar = currentWord.word.last ?? Character(" ")
                    let hasPunctuation = ".!?,;:".contains(lastChar)

                    if !hasPunctuation && pauseDuration > 0 {
                        // Insert punctuation based on pause duration
                        if pauseDuration >= pauseForPeriod {
                            // Long pause - likely end of sentence
                            result += "."
                        } else if pauseDuration >= pauseForComma {
                            // Medium pause - likely a clause break
                            result += ","
                        }
                    }
                }
            }
        }

        // Append any remaining text
        if textIndex < text.endIndex {
            result += text[textIndex...]
        }

        print("TextCleanupManager: [US-025] Applied timing-based punctuation: '\(text)' -> '\(result)'")
        return result
    }

    /// Apply punctuation based on text patterns (when timing data is not available)
    /// This provides intelligent punctuation at likely pause points based on linguistic patterns
    /// - Parameter text: The text to process
    /// - Returns: Text with enhanced punctuation
    private func applyPatternBasedPunctuation(_ text: String) -> String {
        var result = text

        // Pattern 1: Add comma before coordinating conjunctions in longer clauses
        // (but, and, or, yet, so, for, nor) when preceded by 4+ words
        let conjunctionPattern = "([a-zA-Z]+(?:\\s+[a-zA-Z]+){3,})\\s+(but|and|or|yet|so|for|nor)\\s+"
        if let regex = try? NSRegularExpression(pattern: conjunctionPattern, options: [.caseInsensitive]) {
            let range = NSRange(location: 0, length: result.utf16.count)
            let matches = regex.matches(in: result, options: [], range: range)

            // Process matches in reverse to preserve indices
            for match in matches.reversed() {
                if let clauseRange = Range(match.range(at: 1), in: result) {
                    // Check if the clause already ends with punctuation
                    let clauseText = String(result[clauseRange])
                    if let lastChar = clauseText.last, !".!?,;:".contains(lastChar) {
                        // Insert comma after the clause (before the conjunction)
                        let insertionPoint = clauseRange.upperBound
                        result.insert(",", at: insertionPoint)
                    }
                }
            }
        }

        // Pattern 2: Add comma after introductory phrases
        // (However, Therefore, Meanwhile, Furthermore, Additionally, Nevertheless, Consequently)
        let introPattern = "^(However|Therefore|Meanwhile|Furthermore|Additionally|Nevertheless|Consequently|Moreover|Indeed|Actually|Basically|Essentially|Ultimately)\\s+"
        if let regex = try? NSRegularExpression(pattern: introPattern, options: [.caseInsensitive]) {
            let range = NSRange(location: 0, length: result.utf16.count)
            if let match = regex.firstMatch(in: result, options: [], range: range) {
                if let wordRange = Range(match.range(at: 1), in: result) {
                    let insertionPoint = wordRange.upperBound
                    // Check if already has comma
                    if insertionPoint < result.endIndex && result[insertionPoint] != "," {
                        result.insert(",", at: insertionPoint)
                    }
                }
            }
        }

        // Pattern 3: Add comma after subordinate clauses at the start
        // (When..., If..., Although..., Because..., Since..., While..., After..., Before...)
        let subordinatePattern = "^(When|If|Although|Because|Since|While|After|Before|Unless|Until|Whenever|Wherever|Whether)\\s+[^,\\.!?]+?(?=\\s+(?:I|you|we|they|he|she|it|the|a|an|this|that|there|here)\\s)"
        if let regex = try? NSRegularExpression(pattern: subordinatePattern, options: [.caseInsensitive]) {
            let range = NSRange(location: 0, length: result.utf16.count)
            if let match = regex.firstMatch(in: result, options: [], range: range) {
                if let fullRange = Range(match.range, in: result) {
                    let insertionPoint = fullRange.upperBound
                    // Check if already has comma
                    if insertionPoint < result.endIndex && result[insertionPoint] != "," {
                        result.insert(",", at: insertionPoint)
                    }
                }
            }
        }

        // Pattern 4: Add period before certain sentence starters in run-on sentences
        // (Then, So, And then, Next, Also, First, Second, Third, Finally)
        // Only if they appear after 15+ characters without punctuation
        let runOnPattern = "([a-zA-Z]{15,}[^.!?])\\s+(Then|And then|Next|Also|First|Second|Third|Finally)\\s+(?=[A-Z])"
        if let regex = try? NSRegularExpression(pattern: runOnPattern, options: []) {
            let range = NSRange(location: 0, length: result.utf16.count)
            let matches = regex.matches(in: result, options: [], range: range)

            for match in matches.reversed() {
                if let precedingRange = Range(match.range(at: 1), in: result) {
                    let precedingText = String(result[precedingRange])
                    // Only add period if the preceding text doesn't end with punctuation
                    if let lastChar = precedingText.last, !".!?,;:".contains(lastChar) {
                        let insertionPoint = precedingRange.upperBound
                        result.insert(".", at: insertionPoint)
                    }
                }
            }
        }

        if result != text {
            print("TextCleanupManager: [US-025] Applied pattern-based punctuation: '\(text)' -> '\(result)'")
        }

        return result
    }

    /// Process text with both cleanup and post-processing
    /// This is the main entry point for full text processing
    /// - Parameter text: The raw transcribed text
    /// - Returns: Fully processed text
    func processText(_ text: String) async -> String {
        // First apply cleanup (if enabled)
        let cleanedText = await cleanupText(text)

        // Then apply post-processing options (US-607)
        let processedText = applyPostProcessing(cleanedText)

        return processedText
    }

    /// Process text with word timing data for pause-based punctuation
    /// This is the enhanced entry point that supports pause-based auto-punctuation
    /// - Parameters:
    ///   - text: The raw transcribed text
    ///   - wordTimings: Optional array of word timing information from transcription
    /// - Returns: Fully processed text with pause-based punctuation if timings provided
    func processText(_ text: String, wordTimings: [WordTiming]? = nil) async -> String {
        // First apply cleanup (if enabled)
        var processedText = await cleanupText(text)

        // Apply auto-punctuation (US-025) - uses timings if available, otherwise pattern-based
        processedText = applyAutoPunctuation(processedText, wordTimings: wordTimings)

        // Then apply other post-processing options (US-607)
        processedText = applyPostProcessing(processedText)

        return processedText
    }
}
