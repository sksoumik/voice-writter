import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers

/// Runs a small local language model (through MLX) to fix grammar and lightly
/// rephrase a transcript.
///
/// This is an `actor` because `ChatSession` is not thread safe. We keep one warm
/// session and clear its history between dictations, so each correction is
/// independent and earlier text never leaks into a later one.
actor GrammarService {
    private var container: ModelContainer?
    private var session: ChatSession?
    private var loadedModelId: String?
    private var loadedStyle: CorrectionStyle?
    private var loadedInstructions: String?

    var isReady: Bool { session != nil }

    /// Download (if needed) and load the grammar model.
    func prepare(modelId: String,
                 style: CorrectionStyle,
                 customInstructions: String,
                 progress: @escaping @Sendable (Double) -> Void) async throws {
        if loadedModelId == modelId, container != nil {
            if loadedStyle != style || loadedInstructions != customInstructions {
                makeSession(style: style, customInstructions: customInstructions)
            }
            progress(1.0)
            return
        }

        // Keep MLX's buffer cache bounded so memory does not grow without limit.
        MLX.GPU.set(cacheLimit: 64 * 1024 * 1024)

        let configuration = LLMModelFactory.shared.configuration(id: modelId)
        let loaded = try await #huggingFaceLoadModelContainer(configuration: configuration) { p in
            progress(p.fractionCompleted)
        }

        container = loaded
        loadedModelId = modelId
        makeSession(style: style, customInstructions: customInstructions)
        progress(1.0)
    }

    /// Correct a transcript and return clean text ready to insert.
    func correct(_ text: String,
                 style: CorrectionStyle,
                 customInstructions: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        guard let session else { return trimmed }

        if loadedStyle != style || loadedInstructions != customInstructions {
            makeSession(style: style, customInstructions: customInstructions)
        }

        let raw = try await self.session?.respond(to: trimmed) ?? trimmed
        await self.session?.clear()
        return OutputSanitizer.clean(raw, original: trimmed)
    }

    // MARK: - Private

    private func makeSession(style: CorrectionStyle, customInstructions: String) {
        guard let container else { return }
        // Low temperature keeps corrections stable and predictable. maxTokens is
        // generous; the sanitizer guards against the model running away.
        let params = GenerateParameters(maxTokens: 512, temperature: 0.2, topP: 1.0)
        session = ChatSession(
            container,
            instructions: SystemPrompts.grammar(style: style, customInstructions: customInstructions),
            generateParameters: params
        )
        loadedStyle = style
        loadedInstructions = customInstructions
    }
}
