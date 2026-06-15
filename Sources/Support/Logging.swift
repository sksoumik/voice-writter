import Foundation
import os

/// Tiny logging helper so the rest of the code does not import os everywhere.
enum Log {
    private static let logger = Logger(subsystem: "com.sadmansoumik.voicewritter", category: "app")

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    static func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }
}
