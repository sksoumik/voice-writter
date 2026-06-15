import AppKit
import CoreGraphics

/// Global hotkey handling with a consuming event tap.
///
/// Option + Q toggles dictation: press once to start listening, press again to
/// stop and run the transcribe, correct, and paste pipeline. The tap consumes
/// Option + Q so the character it would normally type is not inserted. Escape
/// cancels and is left to pass through to the focused app.
///
/// The event tap needs Accessibility permission (which the app already uses for
/// pasting). Input Monitoring also covers it.
final class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var onToggle: () -> Void = {}
    private var onCancel: () -> Void = {}

    private let qKeyCode: Int64 = 12     // kVK_ANSI_Q
    private let escapeKeyCode: Int64 = 53

    func start(onToggle: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onToggle = onToggle
        self.onCancel = onCancel
        installTap()
    }

    private func installTap() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            return manager.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Log.error("Could not create the event tap. Accessibility permission may be missing.")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system can disable the tap under load; re-enable it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let flags = event.flags
        let option = flags.contains(.maskAlternate)
        let command = flags.contains(.maskCommand)
        let control = flags.contains(.maskControl)

        // Option + Q (without Command or Control) toggles dictation.
        if keyCode == qKeyCode, option, !command, !control, !isRepeat {
            DispatchQueue.main.async { self.onToggle() }
            return nil   // consume so the key does not type a character
        }

        // Escape cancels, but we let it keep working in the focused app too.
        if keyCode == escapeKeyCode {
            DispatchQueue.main.async { self.onCancel() }
            return Unmanaged.passUnretained(event)
        }

        return Unmanaged.passUnretained(event)
    }
}
