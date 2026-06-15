import Foundation

/// Cleans up the grammar model's raw output before it is inserted.
///
/// Small instruct models sometimes wrap their answer in quotes, add a line like
/// "Here is the corrected text:", or emit hidden reasoning. This strips that.
enum OutputSanitizer {
    /// - Parameters:
    ///   - raw: the model output.
    ///   - original: the transcript we asked it to correct, used as a safety net.
    /// - Returns: cleaned text, or the original transcript if the model clearly
    ///   went off task.
    static func clean(_ raw: String, original: String) -> String {
        var text = raw

        // 1. Remove any <think> ... </think> reasoning blocks.
        text = removeBlocks(in: text, open: "<think>", close: "</think>")

        // 2. Strip surrounding markdown code fences.
        text = stripCodeFences(text)

        // 3. Trim whitespace and blank lines.
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 4. Remove a leading preamble line such as "Corrected text:".
        text = stripLeadingPreamble(text)

        // 5. Remove a single pair of matching surrounding quotes.
        text = stripWrappingQuotes(text)

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 6. Safety net. If the model returned nothing useful, or rambled to far
        //    more than the input, fall back to the original transcript so the
        //    user never loses their words.
        let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return trimmedOriginal
        }
        if !trimmedOriginal.isEmpty, text.count > max(40, trimmedOriginal.count * 3) {
            Log.error("Grammar output looked off task, using raw transcript")
            return trimmedOriginal
        }
        return text
    }

    private static func removeBlocks(in text: String, open: String, close: String) -> String {
        var result = text
        while let start = result.range(of: open),
              let end = result.range(of: close, range: start.upperBound..<result.endIndex) {
            result.removeSubrange(start.lowerBound..<end.upperBound)
        }
        // Drop a dangling opener with no closer.
        if let start = result.range(of: open) {
            result.removeSubrange(start.lowerBound..<result.endIndex)
        }
        return result
    }

    private static func stripCodeFences(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix("```") else { return text }
        // Remove the opening fence line (which may carry a language tag).
        if let firstNewline = t.firstIndex(of: "\n") {
            t = String(t[t.index(after: firstNewline)...])
        }
        if let closing = t.range(of: "```", options: .backwards) {
            t = String(t[..<closing.lowerBound])
        }
        return t
    }

    private static func stripLeadingPreamble(_ text: String) -> String {
        let patterns = [
            #"^(sure|okay|ok|certainly)[,!.]?\s+"#,
            #"^here(?:'s| is)(?: the)?(?: corrected| revised| fixed)?(?: text| version)?\s*[:\-]\s*"#,
            #"^(corrected|revised|fixed)(?: text| version)?\s*[:\-]\s*"#,
            #"^output\s*[:\-]\s*"#,
        ]
        var t = text
        for pattern in patterns {
            if let range = t.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                t.removeSubrange(range)
                break
            }
        }
        return t
    }

    private static func stripWrappingQuotes(_ text: String) -> String {
        let pairs: [(Character, Character)] = [("\"", "\""), ("'", "'"), ("\u{201C}", "\u{201D}")]
        guard let first = text.first, let last = text.last else { return text }
        for (open, close) in pairs where first == open && last == close && text.count >= 2 {
            let inner = String(text.dropFirst().dropLast())
            // Only unwrap if there is no other unescaped quote of the same kind inside.
            if !inner.contains(open) {
                return inner
            }
        }
        return text
    }

    /// Remove Whisper special tokens like <|0.00|> or <|en|> from transcript text.
    static func stripWhisperTokens(_ text: String) -> String {
        let cleaned = text.replacingOccurrences(
            of: #"<\|[^|]*\|>"#,
            with: "",
            options: .regularExpression
        )
        return cleaned
    }
}
