import Foundation
import UserNotifications

/// Schedules the repeating daily "what should I wear" local notification. The reminder only fires
/// when the user has enabled it AND there are garments in the closet — without a wardrobe the app
/// can't give useful recommendations.
@MainActor
final class DailyOutfitReminderScheduler {
    static let shared = DailyOutfitReminderScheduler()

    private let identifier = "daily-outfit-reminder"
    private let center = UNUserNotificationCenter.current()

    /// Returns `true` if a reminder is now scheduled.
    @discardableResult
    func sync(enabled: Bool, hour: Int, minute: Int, hasClosetItems: Bool, language: Language) async -> Bool {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard enabled, hasClosetItems else { return false }

        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            break
        case .denied:
            return false
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else { return false }
        @unknown default:
            return false
        }

        var dateComponents = DateComponents()
        dateComponents.hour = max(0, min(23, hour))
        dateComponents.minute = max(0, min(59, minute))
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = language == .spanish ? "Tu look de hoy ✨" : "Your look today ✨"
        content.body = language == .spanish
            ? "Abre Personal Shopper para ver qué ponerte hoy."
            : "Open Personal Shopper to see what to wear today."
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    private func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }
}
