import AppKit
import Carbon.HIToolbox

/// Inserts text into whatever application currently has keyboard focus.
///
/// The reliable, fast way to do this across every app is to put the text on the
/// clipboard and synthesize Command V. We save and restore the user's previous
/// clipboard so they do not lose what they had copied.
@MainActor
final class TextInserter {

    enum InsertResult {
        case inserted
        case secureFieldBlocked   // a password field is focused, paste is refused by macOS
        case noAccessibility      // we are not allowed to post keystrokes
    }

    /// Insert `text` at the current cursor position.
    /// - Parameter restoreClipboard: put the previous clipboard back afterwards.
    @discardableResult
    func insert(_ text: String, restoreClipboard: Bool) -> InsertResult {
        guard !text.isEmpty else { return .inserted }

        // Posting keystrokes into another app requires Accessibility trust.
        guard AXIsProcessTrusted() else {
            return .noAccessibility
        }

        let pasteboard = NSPasteboard.general

        // macOS blocks synthetic paste into secure (password) fields by design.
        // Detect it and let the caller fall back to leaving text on the clipboard.
        if IsSecureEventInputEnabled() {
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            return .secureFieldBlocked
        }

        let saved = restoreClipboard ? snapshot(pasteboard) : nil

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        postPasteShortcut()

        if let saved {
            // Restore after a short delay so the paste has time to read the
            // clipboard in the target app before we overwrite it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                pasteboard.clearContents()
                pasteboard.writeObjects(saved)
            }
        }

        return .inserted
    }

    /// Copy text to the clipboard without pasting. Used as a fallback.
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: - Private

    private func snapshot(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }

    private func postPasteShortcut() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyUp?.flags = .maskCommand

        let location = CGEventTapLocation.cghidEventTap
        keyDown?.post(tap: location)
        keyUp?.post(tap: location)
    }
}
