import Foundation
import WhisperKit

/// Loads WhisperKit and handles push to talk recording.
///
/// While the fn key is held we record the microphone. When it is released we
/// transcribe the whole clip in one pass, which is more accurate for short
/// bursts than streaming and reliably captures the end of the sentence.
@MainActor
final class TranscriptionService {
    private var whisperKit: WhisperKit?
    private var levelTimer: Timer?

    var isLoaded: Bool { whisperKit != nil }

    private let repo = "argmaxinc/whisperkit-coreml"

    /// Download (if needed) and load the Whisper model.
    func prepare(model: String?, progress: @escaping @Sendable (Double) -> Void) async throws {
        guard whisperKit == nil else { return }

        let variant: String
        if let model, !model.isEmpty {
            variant = model
        } else {
            variant = await WhisperKit.recommendedRemoteModels(from: repo).default
        }

        let folder = try await WhisperKit.download(variant: variant, from: repo) { p in
            progress(p.fractionCompleted)
        }

        let kit = try await WhisperKit(
            model: variant,
            modelFolder: folder.path,
            verbose: false,
            logLevel: .error,
            prewarm: true,
            load: true,
            download: false
        )
        whisperKit = kit
        progress(1.0)
    }

    /// Start recording. `onLevel` is called on the main actor with a 0...1
    /// microphone level so the overlay can show a meter.
    func startRecording(onLevel: @escaping (Float) -> Void) throws {
        guard let whisperKit else { throw TranscriptionError.notLoaded }

        try whisperKit.audioProcessor.startRecordingLive { _ in }

        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self, let kit = self.whisperKit else { return }
            let level = kit.audioProcessor.relativeEnergy.suffix(12).max() ?? 0
            onLevel(min(max(level, 0), 1))
        }
    }

    /// Stop recording and transcribe everything that was captured.
    func stopAndTranscribe(language: String?) async -> String {
        levelTimer?.invalidate()
        levelTimer = nil
        guard let whisperKit else { return "" }

        let samples = Array(whisperKit.audioProcessor.audioSamples)
        whisperKit.audioProcessor.stopRecording()

        // Ignore clips shorter than about 0.2 seconds (16000 samples per second).
        guard samples.count > 3200 else { return "" }

        var options = DecodingOptions()
        options.task = .transcribe
        if let language { options.language = language }

        do {
            let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
            let text = results.map { $0.text }.joined(separator: " ")
            return normalize(text)
        } catch {
            Log.error("Transcription failed: \(error.localizedDescription)")
            return ""
        }
    }

    /// Stop recording and throw the audio away.
    func cancelRecording() {
        levelTimer?.invalidate()
        levelTimer = nil
        whisperKit?.audioProcessor.stopRecording()
    }

    private func normalize(_ text: String) -> String {
        let withoutTokens = OutputSanitizer.stripWhisperTokens(text)
        let collapsed = withoutTokens.replacingOccurrences(
            of: #"\s+"#, with: " ", options: .regularExpression)
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum TranscriptionError: LocalizedError {
    case notLoaded
    var errorDescription: String? {
        switch self {
        case .notLoaded: return "The transcription model is not loaded yet."
        }
    }
}
