import AppKit

/// A borderless floating panel that never steals keyboard focus.
///
/// This is important: when dictating, the user's real app must stay frontmost so
/// the pasted text lands in the right place. A normal window would take focus.
final class OverlayPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    // Display only: never become key or main.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
