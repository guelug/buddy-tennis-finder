import Foundation
import ActivityKit

/// Drives the daily-outfit Live Activity shown in the Dynamic Island and on the lock screen.
///
/// Note: iOS does not let an app pop a Live Activity into the Dynamic Island at a future time while
/// it's closed (that needs push). So the timed *notification* is the alert, and this controller
/// surfaces the elegant card whenever the app becomes active at/after the chosen time — e.g. when
/// the user taps the morning reminder — and keeps it pinned for the rest of the day.
@MainActor
final class DailyOutfitLiveActivityController {
    static let shared = DailyOutfitLiveActivityController()

    /// Starts/updates/ends the Live Activity based on the current conditions.
    func refresh(
        enabled: Bool,
        hasClosetItems: Bool,
        reminderTime: Date,
        recommendation: DailyStyleRecommendationSnapshot?,
        language: Language
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let shouldShow = enabled && hasClosetItems && Date() >= reminderTime

        if shouldShow, let recommendation {
            startOrUpdate(recommendation: recommendation, reminderTime: reminderTime, language: language)
        } else {
            end()
        }
    }

    /// Forces the card on screen immediately, ignoring the time-of-day gate (used by the manual
    /// "Show in Dynamic Island" button).
    func pin(recommendation: DailyStyleRecommendationSnapshot, reminderTime: Date, language: Language) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        startOrUpdate(recommendation: recommendation, reminderTime: reminderTime, language: language)
    }

    func end() {
        // Fetch the activities inside the task so no non-Sendable Activity crosses the boundary.
        Task { @MainActor in
            for activity in Activity<DailyOutfitActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func startOrUpdate(
        recommendation: DailyStyleRecommendationSnapshot,
        reminderTime: Date,
        language: Language
    ) {
        let state = DailyOutfitActivityAttributes.ContentState(
            headline: recommendation.headline,
            outfitFormula: recommendation.outfitFormula,
            colorDirection: recommendation.colorDirection,
            moodTags: Array(recommendation.moodTags.prefix(3)),
            timeText: timeText(from: reminderTime)
        )

        // Keep the card alive through the rest of the day.
        let endOfDay = Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400))
        let content = ActivityContent(state: state, staleDate: endOfDay)
        let attributes = DailyOutfitActivityAttributes(title: "Personal Shopper")

        Task { @MainActor in
            if let existing = Activity<DailyOutfitActivityAttributes>.activities.first {
                await existing.update(content)
                return
            }

            do {
                _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            } catch {
                #if DEBUG
                AppLog.liveActivity.error("failed to start: \(error.localizedDescription, privacy: .public)")
                #endif
            }
        }
    }

    private func timeText(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
