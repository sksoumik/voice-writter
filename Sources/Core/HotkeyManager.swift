import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// The dictation toggle. Defaults to Option + Q; the user can change it in
    /// Settings with the recorder. KeyboardShortcuts persists the choice.
    static let toggleDictation = Self("toggleDictation", default: .init(.q, modifiers: .option))
}

/// Global hotkey handling.
///
/// The toggle shortcut is registered through KeyboardShortcuts (Carbon
/// RegisterEventHotKey under the hood), so it works system wide, is consumed (it
/// never types a character), needs no Input Monitoring, and is user
/// configurable. Escape cancels and is observed without being consumed, so it
/// still works normally in the focused app.
@MainActor
final class HotkeyManager {
    private var globalEscapeMonitor: Any?
    private var localEscapeMonitor: Any?
    private var onCancel: () -> Void = {}

    private let escapeKeyCode: UInt16 = 53

    func start(onToggle: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onCancel = onCancel

        // Toggle: whatever shortcut is currently set (default Option + Q).
        // Changing it in the Settings recorder re-registers it automatically.
        KeyboardShortcuts.onKeyDown(for: .toggleDictation) {
            onToggle()
        }

        // Escape cancels the current dictation. Observe only (do not consume).
        let mask: NSEvent.EventTypeMask = [.keyDown]
        globalEscapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleEscape(event)
        }
        localEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleEscape(event)
            return event
        }
    }

    private func handleEscape(_ event: NSEvent) {
        if event.keyCode == escapeKeyCode {
            onCancel()
        }
    }
}
