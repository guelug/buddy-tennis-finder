import Foundation
import SwiftData

/// A planned outfit for a specific day: a set of garments the user picked for that date.
@Model
final class OutfitCalendarEntry {
    /// Day key in `yyyy-MM-dd` (local) so there's exactly one entry per calendar day.
    @Attribute(.unique) var dayKey: String
    var clothingItemIDsData: Data?
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    var clothingItemIDs: [UUID] {
        get {
            guard let data = clothingItemIDsData else { return [] }
            return (try? JSONDecoder().decode([UUID].self, from: data)) ?? []
        }
        set {
            clothingItemIDsData = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }

    var isEmpty: Bool { clothingItemIDs.isEmpty }

    init(dayKey: String, clothingItemIDs: [UUID] = [], note: String? = nil) {
        self.dayKey = dayKey
        self.clothingItemIDsData = try? JSONEncoder().encode(clothingItemIDs)
        self.note = note
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Day key helpers

    static func dayKey(for date: Date) -> String {
        Self.formatter.string(from: date)
    }

    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
