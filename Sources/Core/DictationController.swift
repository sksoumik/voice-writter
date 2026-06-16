import Foundation
import AppKit
import Combine

/// The brain of the app. It owns the services and runs the dictation state
/// machine. Both the overlay and the menu bar observe this object.
@MainActor
final class DictationController: ObservableObject {
    static let shared = DictationController()

    // Published state, watched by the UI.
    @Published private(set) var state: DictationState = .idle
    @Published private(set) var partialText: String = ""
    @Published private(set) var micLevel: Float = 0
    @Published private(set) var modelsReady: Bool = false
    @Published private(set) var whisperProgress: Double = 0
    @Published private(set) var grammarProgress: Double = 0
    @Published private(set) var grammarLoading: Bool = false
    @Published private(set) var lastMessage: String = ""

    private let settings = AppSettings.shared
    private let permissions = PermissionsManager.shared
    private let transcription = TranscriptionService()
    private let grammar = GrammarService()
    private let inserter = TextInserter()
    private let hotkeys = HotkeyManager()

    private var targetApp: NSRunningApplication?
    private var workTask: Task<Void, Never>?

    private init() {}

    /// Called once at launch: install hotkeys and start loading models.
    func bootstrap() {
        hotkeys.start(
            onToggle: { [weak self] in self?.toggle() },
            onCancel: { [weak self] in self?.cancel() }
        )
        Task { await prepareModels() }
    }

    /// Load both models. Runs at launch and whenever a model id changes.
    func prepareModels() async {
        modelsReady = false
        state = .preparing("Loading models")
        do {
            // Load both at once; on a 32 GB Mac there is plenty of headroom.
            async let whisper: Void = transcription.prepare(
                model: settings.whisperModelOrNil
            ) { [weak self] frac in
                Task { @MainActor in self?.whisperProgress = frac }
            }
            async let grammarLoad: Void = grammar.prepare(
                modelId: settings.grammarModelId,
                style: settings.correctionStyle,
                customInstructions: settings.customInstructions
            ) { [weak self] frac in
                Task { @MainActor in self?.grammarProgress = frac }
            }
            _ = try await (whisper, grammarLoad)
            modelsReady = true
            state = .idle
        } catch {
            Log.error("Model load failed: \(error.localizedDescription)")
            state = .error("Model load failed")
            lastMessage = error.localizedDescription
        }
    }

    /// Reload the grammar model after the user picks a different one.
    func reloadGrammarModel() {
        let modelId = settings.grammarModelId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelId.isEmpty, !grammarLoading else { return }
        Task {
            grammarLoading = true
            grammarProgress = 0
            lastMessage = ""
            defer { grammarLoading = false }
            do {
                try await grammar.prepare(
                    modelId: modelId,
                    style: settings.correctionStyle,
                    customInstructions: settings.customInstructions
                ) { [weak self] frac in
                    Task { @MainActor in self?.grammarProgress = frac }
                }
                lastMessage = "Loaded \(modelId)"
            } catch {
                Log.error("Grammar reload failed: \(error.localizedDescription)")
                lastMessage = "Could not load \(modelId)"
            }
        }
    }

    // MARK: - State machine

    /// The global toggle hotkey lands here.
    func toggle() {
        switch state {
        case .idle, .error:
            start()
        case .listening:
            finish()
        default:
            break // ignore while transcribing / correcting / inserting / preparing
        }
    }

    private func start() {
        guard permissions.microphoneGranted else {
            flash("Microphone permission needed")
            permissions.openMicrophoneSettings()
            return
        }
        guard permissions.accessibilityGranted else {
            flash("Accessibility permission needed")
            permissions.openAccessibilitySettings()
            return
        }
        guard modelsReady else {
            flash("Models are still loading")
            return
        }

        // Remember which app should receive the text.
        targetApp = NSWorkspace.shared.frontmostApplication

        partialText = ""
        micLevel = 0
        state = .listening
        if settings.overlayEnabled { OverlayController.shared.show(controller: self) }
        playSound("Tink")

        do {
            try transcription.startRecording { [weak self] level in
                self?.micLevel = level
            }
        } catch {
            Log.error("Could not start recording: \(error.localizedDescription)")
            state = .error("Could not start microphone")
            OverlayController.shared.hide()
        }
    }

    private func finish() {
        state = .transcribing
        playSound("Pop")

        workTask = Task {
            let raw = await transcription.stopAndTranscribe(language: settings.languageOrNil)
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

            if Task.isCancelled { finishIdle(); return }

            if trimmed.isEmpty {
                finishIdle()
                return
            }

            var finalText = trimmed
            if settings.grammarEnabled {
                state = .correcting
                do {
                    finalText = try await grammar.correct(
                        trimmed,
                        style: settings.correctionStyle,
                        customInstructions: settings.customInstructions)
                } catch {
                    Log.error("Grammar correction failed: \(error.localizedDescription)")
                    finalText = trimmed // fall back to raw transcript
                }
            }

            // If the user cancelled while we were correcting, do not paste.
            if Task.isCancelled { finishIdle(); return }

            insert(finalText)
            finishIdle()
        }
    }

    private func insert(_ text: String) {
        state = .inserting
        partialText = text

        // Make sure the original app is frontmost before pasting.
        if let targetApp, NSWorkspace.shared.frontmostApplication != targetApp {
            targetApp.activate()
        }

        let result = inserter.insert(text, restoreClipboard: settings.restoreClipboard)
        switch result {
        case .inserted:
            break
        case .secureFieldBlocked:
            flash("Secure field: text copied to clipboard")
        case .noAccessibility:
            inserter.copyToClipboard(text)
            flash("Accessibility off: text copied to clipboard")
            permissions.openAccessibilitySettings()
        }
    }

    func cancel() {
        guard state.isActive else { return }
        workTask?.cancel()
        transcription.cancelRecording()
        finishIdle()
    }

    private func finishIdle() {
        state = .idle
        micLevel = 0
        OverlayController.shared.hide()
    }

    // MARK: - Helpers

    private func flash(_ message: String) {
        lastMessage = message
        Log.info(message)
    }

    private func playSound(_ name: String) {
        guard settings.playSounds else { return }
        NSSound(named: name)?.play()
    }
}
