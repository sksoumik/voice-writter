import AppKit
import SwiftUI

/// Shows and hides the floating overlay and keeps it positioned near the bottom
/// center of the active screen.
@MainActor
final class OverlayController {
    static let shared = OverlayController()

    private var panel: OverlayPanel?

    private init() {}

    func show(controller: DictationController) {
        let panel = panel ?? makePanel(controller: controller)
        self.panel = panel
        position(panel)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel(controller: DictationController) -> OverlayPanel {
        let size = NSSize(width: 460, height: 84)
        let panel = OverlayPanel(contentRect: NSRect(origin: .zero, size: size))
        let host = NSHostingView(rootView: OverlayView(controller: controller))
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        return panel
    }

    private func position(_ panel: OverlayPanel) {
        guard let screen = activeScreen() else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.minY + 120  // a little above the Dock
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// The screen that currently has the mouse, falling back to the main screen.
    private func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
    }
}
