import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// An optional key combo for the dictation toggle, on top of the Right
    /// Command key tap (see `HotkeyManager`). Defaults to Option + Q; the user
    /// can change it in Settings with the recorder. KeyboardShortcuts persists
    /// the choice.
    static let toggleDictation = Self("toggleDictation", default: .init(.q, modifiers: .option))
}

/// Global hotkey handling.
///
/// Two ways trigger the dictation toggle:
///
/// 1. A clean tap of the **Right Command** key. We watch `flagsChanged` events
///    and fire only when Right Command is pressed and released on its own, with
///    no other key in between. That way ordinary shortcuts such as
///    Right Command + C keep working and never start dictation. The key is only
///    observed, never consumed, so it still behaves as a normal modifier.
/// 2. The optional combo registered through KeyboardShortcuts (Carbon
///    RegisterEventHotKey under the hood, default Option + Q). It works system
///    wide, is consumed (it never types a character), and is user configurable.
///
/// Escape cancels and is observed without being consumed, so it still works
/// normally in the focused app.
@MainActor
final class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var onToggle: () -> Void = {}
    private var onCancel: () -> Void = {}

    private let escapeKeyCode: UInt16 = 53
    private let rightCommandKeyCode: UInt16 = 54
    // Device dependent bit that is set while the Right Command key is held
    // (NX_DEVICERCMDKEYMASK). Used to tell a press from a release.
    private let rightCommandFlag: UInt = 0x10

    // Tracks a clean tap of the Right Command key: pressed and released with no
    // other key in between. Anything else (a combo, a second modifier) clears
    // the pending tap so it does not toggle dictation.
    private var rightCommandDown = false
    private var otherKeyDuringRightCommand = false

    func start(onToggle: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onToggle = onToggle
        self.onCancel = onCancel

        // Optional combo (default Option + Q). Re-registers itself automatically
        // when the user changes it in the Settings recorder.
        KeyboardShortcuts.onKeyDown(for: .toggleDictation) { [weak self] in
            self?.onToggle()
        }

        // Watch modifier changes (for the Right Command tap) and key presses
        // (Escape to cancel, and to notice when Right Command is used in a
        // combo). Observe only; never consume, so every key keeps working.
        let mask: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            handleFlagsChanged(event)
        case .keyDown:
            // A key pressed while Right Command is held means it is part of a
            // combo, not a lone tap.
            if rightCommandDown { otherKeyDuringRightCommand = true }
            if event.keyCode == escapeKeyCode { onCancel() }
        default:
            break
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        // Only react to the Right Command key. A change to any other modifier
        // while Right Command is held also cancels the pending tap
        // (for example Right Command + Shift).
        guard event.keyCode == rightCommandKeyCode else {
            if rightCommandDown { otherKeyDuringRightCommand = true }
            return
        }

        let isDown = (event.modifierFlags.rawValue & rightCommandFlag) != 0
        if isDown {
            rightCommandDown = true
            otherKeyDuringRightCommand = false
        } else {
            let wasCleanTap = rightCommandDown && !otherKeyDuringRightCommand
            rightCommandDown = false
            otherKeyDuringRightCommand = false
            if wasCleanTap { onToggle() }
        }
    }
}
