import Foundation
import SwiftData

/// A look the user assembled from their closet: an ordered set of garment references plus optional
/// occasion and note. Stored as garment ID strings so it survives independently of the items and is
/// resilient if an item is later deleted (missing items are simply skipped when rendering).
@Model
final class SavedOutfit {
    var id: UUID
    var name: String
    var createdAt: Date
    var itemIDStrings: [String]
    var occasion: String?
    var note: String?

    init(
        id: UUID = UUID(),
        name: String,
        itemIDStrings: [String],
        occasion: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = Date()
        self.itemIDStrings = itemIDStrings
        self.occasion = occasion
        self.note = note
    }

    var itemIDs: [UUID] {
        itemIDStrings.compactMap(UUID.init(uuidString:))
    }
}
