import Foundation

/// Represents the current recording state of the application
enum RecordingState: String {
    case idle
    case recording
    
    /// Toggle between idle and recording states
    mutating func toggle() {
        switch self {
        case .idle:
            self = .recording
        case .recording:
            self = .idle
        }
    }
    
    /// Returns the SF Symbol name for the current state
    var iconName: String {
        switch self {
        case .idle:
            return "mic"
        case .recording:
            return "mic.fill"
        }
    }
    
    /// Returns the accessibility label for the current state
    var accessibilityLabel: String {
        switch self {
        case .idle:
            return "Voxa - Click to start recording"
        case .recording:
            return "Voxa - Recording... Click to stop"
        }
    }
}
