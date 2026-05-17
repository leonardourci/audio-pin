import os

enum AppLog {
    static let subsystem = "AudioPin"

    static func logger(_ category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}
