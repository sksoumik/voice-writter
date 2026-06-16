import Foundation
import Combine

/// User configurable preferences, backed by `UserDefaults`.
///
/// This is a single shared object so both the SwiftUI views and the AppKit
/// pieces (overlay, app delegate) read and write the same values.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    /// When true, every dictation is rewritten by the grammar model before it
    /// is inserted. When false, the raw transcription is inserted as is.
    @Published var grammarEnabled: Bool {
        didSet { defaults.set(grammarEnabled, forKey: Keys.grammarEnabled) }
    }

    /// How aggressive the rewrite should be.
    @Published var correctionStyle: CorrectionStyle {
        didSet { defaults.set(correctionStyle.rawValue, forKey: Keys.correctionStyle) }
    }

    /// WhisperKit model variant. Empty string means "let WhisperKit pick the
    /// best model for this Mac" which is always safe.
    @Published var whisperModel: String {
        didSet { defaults.set(whisperModel, forKey: Keys.whisperModel) }
    }

    /// Hugging Face id of the local grammar model run through MLX.
    @Published var grammarModelId: String {
        didSet { defaults.set(grammarModelId, forKey: Keys.grammarModelId) }
    }

    /// Spoken language hint for transcription. Empty means auto detect.
    @Published var language: String {
        didSet { defaults.set(language, forKey: Keys.language) }
    }

    /// Extra, always on guidance added to the grammar prompt. One rule per line.
    @Published var customInstructions: String {
        didSet { defaults.set(customInstructions, forKey: Keys.customInstructions) }
    }

    /// After pasting, put the user's previous clipboard contents back.
    @Published var restoreClipboard: Bool {
        didSet { defaults.set(restoreClipboard, forKey: Keys.restoreClipboard) }
    }

    /// Play a short sound when dictation starts and stops.
    @Published var playSounds: Bool {
        didSet { defaults.set(playSounds, forKey: Keys.playSounds) }
    }

    /// Show the floating overlay while dictating.
    @Published var overlayEnabled: Bool {
        didSet { defaults.set(overlayEnabled, forKey: Keys.overlayEnabled) }
    }

    /// Set to true once the user has completed first run setup.
    @Published var didCompleteOnboarding: Bool {
        didSet { defaults.set(didCompleteOnboarding, forKey: Keys.didCompleteOnboarding) }
    }

    private init() {
        defaults.register(defaults: [
            Keys.grammarEnabled: true,
            Keys.correctionStyle: CorrectionStyle.lightRephrase.rawValue,
            Keys.whisperModel: "",
            Keys.grammarModelId: AppSettings.defaultGrammarModelId,
            Keys.language: "",
            Keys.customInstructions: "",
            Keys.restoreClipboard: true,
            Keys.playSounds: true,
            Keys.overlayEnabled: true,
            Keys.didCompleteOnboarding: false,
        ])

        grammarEnabled = defaults.bool(forKey: Keys.grammarEnabled)
        correctionStyle = CorrectionStyle(rawValue: defaults.string(forKey: Keys.correctionStyle) ?? "")
            ?? .lightRephrase
        whisperModel = defaults.string(forKey: Keys.whisperModel) ?? ""
        grammarModelId = defaults.string(forKey: Keys.grammarModelId) ?? AppSettings.defaultGrammarModelId
        language = defaults.string(forKey: Keys.language) ?? ""
        customInstructions = defaults.string(forKey: Keys.customInstructions) ?? ""
        restoreClipboard = defaults.bool(forKey: Keys.restoreClipboard)
        playSounds = defaults.bool(forKey: Keys.playSounds)
        overlayEnabled = defaults.bool(forKey: Keys.overlayEnabled)
        didCompleteOnboarding = defaults.bool(forKey: Keys.didCompleteOnboarding)
    }

    /// The model id passed to WhisperKit, or nil to auto select.
    var whisperModelOrNil: String? {
        whisperModel.isEmpty ? nil : whisperModel
    }

    /// The language code passed to the decoder, or nil for auto detect.
    var languageOrNil: String? {
        language.isEmpty ? nil : language
    }

    // Default grammar model: a small, non reasoning instruct model that returns
    // corrected text directly with no hidden thinking tokens, so it stays fast.
    // Qwen3 Instruct 2507 follows instructions noticeably better than Qwen2.5.
    static let defaultGrammarModelId = "mlx-community/Qwen3-4B-Instruct-2507-4bit"

    /// Recommended grammar models. All are MLX format and use architectures the
    /// MLX Swift runtime supports. You can also type any other MLX model id.
    static let grammarModelChoices: [ModelChoice] = [
        ModelChoice(id: "mlx-community/Qwen3-4B-Instruct-2507-4bit",
                    label: "Qwen3 4B Instruct 2507 — recommended, fast (~2.5 GB)"),
        ModelChoice(id: "mlx-community/Qwen3-30B-A3B-Instruct-2507-4bit",
                    label: "Qwen3 30B A3B Instruct 2507 — best quality, still fast (~17 GB, 32 GB Macs)"),
        ModelChoice(id: "mlx-community/Qwen2.5-14B-Instruct-4bit",
                    label: "Qwen2.5 14B Instruct — strong (~8 GB)"),
        ModelChoice(id: "mlx-community/Qwen2.5-7B-Instruct-4bit",
                    label: "Qwen2.5 7B Instruct (~4.5 GB)"),
        ModelChoice(id: "mlx-community/Qwen2.5-3B-Instruct-4bit",
                    label: "Qwen2.5 3B Instruct — lightest (~2 GB)"),
    ]

    struct ModelChoice: Identifiable, Hashable {
        var id: String
        var label: String
    }

    private enum Keys {
        static let grammarEnabled = "grammarEnabled"
        static let correctionStyle = "correctionStyle"
        static let whisperModel = "whisperModel"
        static let grammarModelId = "grammarModelId"
        static let language = "language"
        static let customInstructions = "customInstructions"
        static let restoreClipboard = "restoreClipboard"
        static let playSounds = "playSounds"
        static let overlayEnabled = "overlayEnabled"
        static let didCompleteOnboarding = "didCompleteOnboarding"
    }
}

/// How much the grammar model is allowed to change the text.
enum CorrectionStyle: String, CaseIterable, Identifiable {
    case fixOnly
    case lightRephrase
    case clean

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixOnly: return "Fix errors only"
        case .lightRephrase: return "Fix and lightly rephrase"
        case .clean: return "Clean up for readability"
        }
    }
}
