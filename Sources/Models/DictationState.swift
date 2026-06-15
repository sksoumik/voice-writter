import Foundation

/// The stages a single dictation moves through.
///
/// idle -> listening -> transcribing -> correcting -> inserting -> idle
/// The user can cancel from any active stage, which returns to idle.
enum DictationState: Equatable {
    /// Nothing happening. Models are warm and the overlay is hidden.
    case idle
    /// Microphone is on and WhisperKit is streaming partial text.
    case listening
    /// Recording stopped, finalising the raw transcript.
    case transcribing
    /// The grammar model is rewriting the transcript.
    case correcting
    /// Pasting the final text into the focused app.
    case inserting
    /// A model is still downloading or loading.
    case preparing(String)
    /// Something went wrong; carries a short message.
    case error(String)

    var isActive: Bool {
        switch self {
        case .listening, .transcribing, .correcting, .inserting:
            return true
        default:
            return false
        }
    }

    /// Short label shown in the overlay and the menu bar.
    var label: String {
        switch self {
        case .idle: return "Ready"
        case .listening: return "Listening"
        case .transcribing: return "Transcribing"
        case .correcting: return "Cleaning up"
        case .inserting: return "Inserting"
        case .preparing(let what): return what
        case .error(let message): return message
        }
    }
}
