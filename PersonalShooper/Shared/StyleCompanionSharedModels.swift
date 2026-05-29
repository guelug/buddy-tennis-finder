import Foundation
import ActivityKit

/// Live Activity (Dynamic Island / lock screen) for the daily outfit reminder.
struct DailyOutfitActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var headline: String
        var outfitFormula: String
        var colorDirection: String
        var moodTags: [String]
        var timeText: String
    }

    /// "Personal Shopper" by default; kept as an attribute so the look name can be localized.
    var title: String
}

enum StyleCompanionSharedKeys {
    static let appGroupID = "group.com.personalshooper.shared"
    static let recommendation = "daily_style_recommendation"
    static let events = "today_calendar_events"
    static let configuration = "style_companion_configuration"
    static let pendingLaunchDestination = "pending_launch_destination"
}

enum StyleCompanionLaunchDestination: String, Codable {
    case chat
    case closet
    case tryOn
}

struct CalendarEventSnapshot: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let notes: String?
    let location: String?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String

    var timeWindowText: String {
        if isAllDay {
            return "All day"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

struct DailyStyleRecommendationSnapshot: Codable, Hashable {
    let generatedAt: Date
    let headline: String
    let eventTitle: String?
    let contextLine: String
    let outfitFormula: String
    let colorDirection: String
    let accessoryNote: String
    let closetHighlightNames: [String]
    let moodTags: [String]
    let spokenSummary: String
}

struct StyleCompanionConfigurationSnapshot: Codable, Hashable {
    var calendarSyncEnabled: Bool
    var widgetRecommendationsEnabled: Bool
    var siriSuggestionsEnabled: Bool
    var dailyReminderEnabled: Bool
    var dailyReminderHour: Int
    var dailyReminderMinute: Int

    init(
        calendarSyncEnabled: Bool = false,
        widgetRecommendationsEnabled: Bool = true,
        siriSuggestionsEnabled: Bool = true,
        dailyReminderEnabled: Bool = false,
        dailyReminderHour: Int = 8,
        dailyReminderMinute: Int = 0
    ) {
        self.calendarSyncEnabled = calendarSyncEnabled
        self.widgetRecommendationsEnabled = widgetRecommendationsEnabled
        self.siriSuggestionsEnabled = siriSuggestionsEnabled
        self.dailyReminderEnabled = dailyReminderEnabled
        self.dailyReminderHour = dailyReminderHour
        self.dailyReminderMinute = dailyReminderMinute
    }

    // Backward-compatible decode: older stored configs without the reminder keys fall back to defaults.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        calendarSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .calendarSyncEnabled) ?? false
        widgetRecommendationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .widgetRecommendationsEnabled) ?? true
        siriSuggestionsEnabled = try container.decodeIfPresent(Bool.self, forKey: .siriSuggestionsEnabled) ?? true
        dailyReminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .dailyReminderEnabled) ?? false
        dailyReminderHour = try container.decodeIfPresent(Int.self, forKey: .dailyReminderHour) ?? 8
        dailyReminderMinute = try container.decodeIfPresent(Int.self, forKey: .dailyReminderMinute) ?? 0
    }

    static let `default` = StyleCompanionConfigurationSnapshot()
}

enum SharedStyleCompanionStore {
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: StyleCompanionSharedKeys.appGroupID) ?? .standard
    }

    static func saveRecommendation(_ recommendation: DailyStyleRecommendationSnapshot?) {
        if let recommendation,
           let encoded = try? JSONEncoder().encode(recommendation) {
            defaults.set(encoded, forKey: StyleCompanionSharedKeys.recommendation)
        } else {
            defaults.removeObject(forKey: StyleCompanionSharedKeys.recommendation)
        }
    }

    static func loadRecommendation() -> DailyStyleRecommendationSnapshot? {
        guard let data = defaults.data(forKey: StyleCompanionSharedKeys.recommendation) else {
            return nil
        }
        return try? JSONDecoder().decode(DailyStyleRecommendationSnapshot.self, from: data)
    }

    static func saveEvents(_ events: [CalendarEventSnapshot]) {
        if let encoded = try? JSONEncoder().encode(events) {
            defaults.set(encoded, forKey: StyleCompanionSharedKeys.events)
        }
    }

    static func loadEvents() -> [CalendarEventSnapshot] {
        guard let data = defaults.data(forKey: StyleCompanionSharedKeys.events),
              let decoded = try? JSONDecoder().decode([CalendarEventSnapshot].self, from: data) else {
            return []
        }
        return decoded
    }

    static func saveConfiguration(_ configuration: StyleCompanionConfigurationSnapshot) {
        if let encoded = try? JSONEncoder().encode(configuration) {
            defaults.set(encoded, forKey: StyleCompanionSharedKeys.configuration)
        }
    }

    static func loadConfiguration() -> StyleCompanionConfigurationSnapshot {
        guard let data = defaults.data(forKey: StyleCompanionSharedKeys.configuration),
              let decoded = try? JSONDecoder().decode(StyleCompanionConfigurationSnapshot.self, from: data) else {
            return .default
        }
        return decoded
    }

    static func savePendingLaunchDestination(_ destination: StyleCompanionLaunchDestination?) {
        defaults.set(destination?.rawValue, forKey: StyleCompanionSharedKeys.pendingLaunchDestination)
    }

    static func consumePendingLaunchDestination() -> StyleCompanionLaunchDestination? {
        guard let rawValue = defaults.string(forKey: StyleCompanionSharedKeys.pendingLaunchDestination),
              let destination = StyleCompanionLaunchDestination(rawValue: rawValue) else {
            return nil
        }

        defaults.removeObject(forKey: StyleCompanionSharedKeys.pendingLaunchDestination)
        return destination
    }
}
