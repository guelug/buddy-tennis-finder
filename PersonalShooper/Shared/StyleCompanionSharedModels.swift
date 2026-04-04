import Foundation

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

    static let `default` = StyleCompanionConfigurationSnapshot(
        calendarSyncEnabled: false,
        widgetRecommendationsEnabled: true,
        siriSuggestionsEnabled: true
    )
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
