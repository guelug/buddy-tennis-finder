import Foundation
import SwiftData

/// Learns the user's real style habits from actual garment usage. Triggers only after enough *days
/// of use* (not calendar days) so there's real signal, then refreshes periodically. The resulting
/// summary is stored on the styling profile and fed to the stylist as extra context.
@MainActor
enum StyleUsageLearning {
    private static let usageDaysKey = "style_usage_days"
    private static let lastUsageDayKey = "style_last_usage_day"

    /// First learning pass after this many distinct days of real use.
    private static let firstThreshold = 30
    /// Re-evaluate roughly every 3 months of *use* after that, to catch changing taste.
    private static let refreshIntervalDays = 90

    /// Increments the distinct usage-day counter at most once per calendar day. Returns the new total.
    @discardableResult
    static func registerUsageDay(now: Date = Date()) -> Int {
        let today = dayKey(now)
        var count = UserDefaults.standard.integer(forKey: usageDaysKey)
        if UserDefaults.standard.string(forKey: lastUsageDayKey) != today {
            count += 1
            UserDefaults.standard.set(count, forKey: usageDaysKey)
            UserDefaults.standard.set(today, forKey: lastUsageDayKey)
        }
        return count
    }

    static func usageDayCount() -> Int {
        UserDefaults.standard.integer(forKey: usageDaysKey)
    }

    /// Runs the learning pass if the user has reached the threshold (or it's time to refresh).
    static func runIfDue(user: User, closetItems: [ClothingItem], language: Language, modelContext: ModelContext) {
        let count = usageDayCount()
        let profile = user.personalStylingProfile

        let due = profile.learnedAtUsageDay == 0
            ? count >= firstThreshold
            : count - profile.learnedAtUsageDay >= refreshIntervalDays
        guard due else { return }

        guard let summary = buildSummary(closetItems: closetItems, language: language) else { return }

        var updated = profile
        updated.learnedStyleSummary = summary
        updated.learnedAtUsageDay = count
        user.updateStylingProfile(updated)
        user.updatedAt = Date()
        try? modelContext.save()
    }

    /// Builds a plain-language summary from the most-worn pieces.
    private static func buildSummary(closetItems: [ClothingItem], language: Language) -> String? {
        let worn = closetItems
            .filter { $0.timesWorn > 0 }
            .sorted { $0.timesWorn > $1.timesWorn }
        guard !worn.isEmpty else { return nil }

        let top = Array(worn.prefix(5))
        let names = top.map { $0.name }.joined(separator: ", ")
        let categories = topTokens(top.map { $0.category.displayName }, limit: 3)
        let colors = topTokens(top.flatMap { $0.colorTags }, limit: 4)
        let styles = topTokens(top.flatMap { $0.styleTags }, limit: 4)

        if language == .spanish {
            var parts = ["Aprendido del uso real: las prendas que más lleva son \(names)."]
            if !categories.isEmpty { parts.append("Categorías que más repite: \(categories.joined(separator: ", ")).") }
            if !colors.isEmpty { parts.append("Colores que más usa: \(colors.joined(separator: ", ")).") }
            if !styles.isEmpty { parts.append("Estilo predominante en su día a día: \(styles.joined(separator: ", ")).") }
            parts.append("Prioriza recomendaciones alineadas con estos hábitos reales y, si propones algo distinto, justifícalo.")
            return parts.joined(separator: " ")
        } else {
            var parts = ["Learned from real usage: the most-worn pieces are \(names)."]
            if !categories.isEmpty { parts.append("Most-repeated categories: \(categories.joined(separator: ", ")).") }
            if !colors.isEmpty { parts.append("Most-worn colors: \(colors.joined(separator: ", ")).") }
            if !styles.isEmpty { parts.append("Predominant everyday style: \(styles.joined(separator: ", ")).") }
            parts.append("Prioritize recommendations aligned with these real habits; if you suggest something different, justify it.")
            return parts.joined(separator: " ")
        }
    }

    private static func topTokens(_ tokens: [String], limit: Int) -> [String] {
        var counts: [String: Int] = [:]
        for token in tokens {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            counts[trimmed, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.prefix(limit).map(\.key)
    }

    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
