import os

/// Centralized structured loggers, so production diagnostics go through the unified logging system
/// (filterable, privacy-aware) instead of `print`, which is invisible in release and unstructured.
enum AppLog {
    private static let subsystem = "com.personalshooper.app"

    static let storeKit = Logger(subsystem: subsystem, category: "StoreKit")
    static let persistence = Logger(subsystem: subsystem, category: "Persistence")
    static let calendar = Logger(subsystem: subsystem, category: "Calendar")
    static let liveActivity = Logger(subsystem: subsystem, category: "LiveActivity")
    static let classification = Logger(subsystem: subsystem, category: "Classification")
    static let reminders = Logger(subsystem: subsystem, category: "Reminders")
}
