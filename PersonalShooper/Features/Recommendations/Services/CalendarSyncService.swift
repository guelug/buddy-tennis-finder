import Foundation
import EventKit

enum CalendarSyncAuthorizationStatus: String {
    case notDetermined
    case denied
    case restricted
    case writeOnly
    case fullAccess
    case unknown

    var hasReadableAccess: Bool {
        self == .fullAccess
    }
}

@MainActor
final class CalendarSyncService {
    private let eventStore = EKEventStore()

    func currentAuthorizationStatus() -> CalendarSyncAuthorizationStatus {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .fullAccess:
            return .fullAccess
        case .writeOnly:
            return .writeOnly
        @unknown default:
            return .unknown
        }
    }

    func requestAccessIfNeeded() async -> Bool {
        let status = currentAuthorizationStatus()

        switch status {
        case .fullAccess:
            return true
        case .writeOnly:
            return false
        case .denied, .restricted, .unknown:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                eventStore.requestFullAccessToEvents { granted, error in
                    if let error {
                        #if DEBUG
                        AppLog.calendar.error("requestAccessIfNeeded failed: \(error.localizedDescription, privacy: .public)")
                        #endif
                        continuation.resume(returning: false)
                        return
                    }

                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func fetchTodayEvents(limit: Int = 6) -> [CalendarEventSnapshot] {
        let status = currentAuthorizationStatus()
        guard status == .fullAccess else { return [] }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(limit)

        return events.map {
            CalendarEventSnapshot(
                id: $0.eventIdentifier ?? UUID().uuidString,
                title: $0.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Event",
                notes: $0.notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                location: $0.location?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                startDate: $0.startDate,
                endDate: $0.endDate,
                isAllDay: $0.isAllDay,
                calendarTitle: $0.calendar.title
            )
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
