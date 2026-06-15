import AppKit
import SwiftUI
import Combine

/// Owns app lifecycle, the menu bar status item, and the setup and settings
/// windows. Using an AppKit `NSStatusItem` (rather than SwiftUI `MenuBarExtra`)
/// makes the menu bar icon appear reliably for this accessory app.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static private(set) var shared: AppDelegate?

    private var statusItem: NSStatusItem?
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)

        installStatusItem()
        Log.info("App launched; status item installed")

        DictationController.shared.bootstrap()

        // Update the menu bar icon whenever the dictation state changes.
        DictationController.shared.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.updateIcon(for: state) }
            .store(in: &cancellables)

        let needsSetup = !AppSettings.shared.didCompleteOnboarding
            || !PermissionsManager.shared.allGranted
        if needsSetup {
            showOnboarding()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        PermissionsManager.shared.refresh()
    }

    // MARK: - Status item

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = Self.icon(listening: false)
            button.toolTip = "Voice Writter"
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    private static func icon(listening: Bool) -> NSImage? {
        let name = listening ? "mic.fill" : "mic"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Voice Writter")
        image?.isTemplate = true
        return image
    }

    private func updateIcon(for state: DictationState) {
        guard let button = statusItem?.button else { return }
        let listening = state == .listening
        button.image = Self.icon(listening: listening)
        button.contentTintColor = listening ? .systemRed : nil
    }

    // MARK: - Menu (rebuilt each time it opens so labels stay current)

    func menuNeedsUpdate(_ menu: NSMenu) {
        let controller = DictationController.shared
        let settings = AppSettings.shared
        menu.removeAllItems()

        let status = NSMenuItem(title: statusTitle(controller), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let toggle = NSMenuItem(
            title: controller.state == .listening ? "Stop dictation" : "Start dictation",
            action: #selector(toggleDictation), keyEquivalent: "")
        toggle.target = self
        toggle.isEnabled = controller.modelsReady || controller.state == .listening
        menu.addItem(toggle)

        if controller.state.isActive {
            let cancel = NSMenuItem(title: "Cancel", action: #selector(cancelDictation), keyEquivalent: "")
            cancel.target = self
            menu.addItem(cancel)
        }

        menu.addItem(.separator())

        let grammar = NSMenuItem(title: "Fix grammar automatically",
                                 action: #selector(toggleGrammar), keyEquivalent: "")
        grammar.target = self
        grammar.state = settings.grammarEnabled ? .on : .off
        menu.addItem(grammar)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let setup = NSMenuItem(title: "Setup & Permissions…", action: #selector(openOnboarding), keyEquivalent: "")
        setup.target = self
        menu.addItem(setup)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Voice Writter", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func statusTitle(_ controller: DictationController) -> String {
        if !controller.modelsReady {
            let pct = Int(min(controller.whisperProgress, controller.grammarProgress) * 100)
            return "Loading models… \(pct)%"
        }
        return "Voice Writter — \(controller.state.label)"
    }

    // MARK: - Actions

    @objc private func toggleDictation() { DictationController.shared.toggle() }
    @objc private func cancelDictation() { DictationController.shared.cancel() }
    @objc private func toggleGrammar() {
        AppSettings.shared.grammarEnabled.toggle()
    }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "Voice Writter Settings"
            window.styleMask = [.titled, .closable, .resizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 580, height: 680))
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    @objc private func openOnboarding() { showOnboarding() }

    /// Show (or focus) the setup and permissions window.
    func showOnboarding() {
        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        let view = OnboardingView(onClose: { [weak self] in
            self?.onboardingWindow?.close()
        })
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Voice Writter Setup"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        onboardingWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        Log.info("Showing onboarding window")
    }
}
