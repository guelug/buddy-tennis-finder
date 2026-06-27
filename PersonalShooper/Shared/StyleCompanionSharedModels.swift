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
    static let closetIndex = "style_companion_closet_index"
    static let pendingLaunchDestination = "pending_launch_destination"
    static let pendingChatPrompt = "pending_chat_prompt"
    static let pendingClosetSearch = "pending_closet_search"
    static let pendingClosetItemID = "pending_closet_item_id"
}

enum StyleCompanionLaunchDestination: String, Codable {
    case chat
    case closet
    case tryOn
    case profile
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

struct StyleCompanionClosetItemSnapshot: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let categoryRaw: String
    let categoryDisplayName: String
    let colorTags: [String]
    let styleTags: [String]
    let materialTags: [String]
    let occasionTags: [String]
    let detailTags: [String]
    let brandName: String?
    let notes: String?
    let metadataSummary: String?
    let isFavorite: Bool
    let timesWorn: Int
    let createdAt: Date

    var searchableTerms: [String] {
        ([name, categoryRaw, categoryDisplayName]
            + colorTags
            + styleTags
            + materialTags
            + occasionTags
            + detailTags
            + [brandName, notes, metadataSummary].compactMap { $0 })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var spokenSummary: String {
        let highlights = Array((colorTags + styleTags + materialTags + occasionTags + detailTags).prefix(5))
        guard !highlights.isEmpty else {
            return "\(name), \(categoryDisplayName)"
        }
        return "\(name), \(categoryDisplayName): \(highlights.joined(separator: ", "))"
    }

    func matches(_ query: String) -> Bool {
        let normalizedQuery = Self.normalized(query)
        guard !normalizedQuery.isEmpty else { return true }
        return searchableTerms.contains { Self.normalized($0).contains(normalizedQuery) }
    }

    func visualMatchScore(labels: [String]) -> Double {
        let normalizedLabels = labels
            .map(Self.normalized)
            .filter { !$0.isEmpty }
        guard !normalizedLabels.isEmpty else { return 0 }

        let terms = searchableTerms.map(Self.normalized).filter { !$0.isEmpty }
        var score = 0.0

        for label in normalizedLabels {
            for term in terms {
                if term == label || term.contains(label) || label.contains(term) {
                    score += term == label ? 1.0 : 0.55
                    break
                }
            }
        }

        if normalizedLabels.contains(Self.normalized(categoryDisplayName)) ||
            normalizedLabels.contains(Self.normalized(categoryRaw)) {
            score += 1.25
        }

        return score
    }

    static func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct StyleCompanionConfigurationSnapshot: Codable, Hashable {
    var calendarSyncEnabled: Bool
    var widgetRecommendationsEnabled: Bool
    var siriSuggestionsEnabled: Bool
    var dailyReminderEnabled: Bool
    var dailyReminderHour: Int
    var dailyReminderMinute: Int
    var preferredLanguageRaw: String

    init(
        calendarSyncEnabled: Bool = false,
        widgetRecommendationsEnabled: Bool = true,
        siriSuggestionsEnabled: Bool = true,
        dailyReminderEnabled: Bool = false,
        dailyReminderHour: Int = 8,
        dailyReminderMinute: Int = 0,
        preferredLanguageRaw: String = "es"
    ) {
        self.calendarSyncEnabled = calendarSyncEnabled
        self.widgetRecommendationsEnabled = widgetRecommendationsEnabled
        self.siriSuggestionsEnabled = siriSuggestionsEnabled
        self.dailyReminderEnabled = dailyReminderEnabled
        self.dailyReminderHour = dailyReminderHour
        self.dailyReminderMinute = dailyReminderMinute
        self.preferredLanguageRaw = preferredLanguageRaw
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
        preferredLanguageRaw = try container.decodeIfPresent(String.self, forKey: .preferredLanguageRaw) ?? "es"
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

    static func saveClosetIndex(_ items: [StyleCompanionClosetItemSnapshot]) {
        if let encoded = try? JSONEncoder().encode(items) {
            defaults.set(encoded, forKey: StyleCompanionSharedKeys.closetIndex)
        }
    }

    static func loadClosetIndex() -> [StyleCompanionClosetItemSnapshot] {
        guard let data = defaults.data(forKey: StyleCompanionSharedKeys.closetIndex),
              let decoded = try? JSONDecoder().decode([StyleCompanionClosetItemSnapshot].self, from: data) else {
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

    static func savePendingChatPrompt(_ prompt: String?) {
        saveTrimmed(prompt, forKey: StyleCompanionSharedKeys.pendingChatPrompt)
    }

    static func consumePendingChatPrompt() -> String? {
        consumeString(forKey: StyleCompanionSharedKeys.pendingChatPrompt)
    }

    static func savePendingClosetSearch(_ query: String?) {
        saveTrimmed(query, forKey: StyleCompanionSharedKeys.pendingClosetSearch)
    }

    static func consumePendingClosetSearch() -> String? {
        consumeString(forKey: StyleCompanionSharedKeys.pendingClosetSearch)
    }

    static func savePendingClosetItemID(_ itemID: String?) {
        saveTrimmed(itemID, forKey: StyleCompanionSharedKeys.pendingClosetItemID)
    }

    static func consumePendingClosetItemID() -> String? {
        consumeString(forKey: StyleCompanionSharedKeys.pendingClosetItemID)
    }

    private static func saveTrimmed(_ value: String?, forKey key: String) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            defaults.set(trimmed, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private static func consumeString(forKey key: String) -> String? {
        guard let value = defaults.string(forKey: key), !value.isEmpty else {
            return nil
        }
        defaults.removeObject(forKey: key)
        return value
    }
}
