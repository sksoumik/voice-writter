import SwiftUI

/// The whole UI is driven by `AppDelegate` through an AppKit status item, the
/// setup window, and the settings window. SwiftUI's `App` still needs at least
/// one scene, so we keep an empty `Settings` scene as a placeholder.
@main
struct VoiceWritterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
