import Foundation
import SwiftData

/// A piece the user wants to buy — typically added from the capsule plan's missing slots, with the
/// suggested on-palette color and the reason it completes their wardrobe.
@Model
final class ShoppingItem {
    var id: UUID
    var title: String
    var categoryRaw: String?
    var colorHint: String?
    var reason: String?
    var isPurchased: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        categoryRaw: String? = nil,
        colorHint: String? = nil,
        reason: String? = nil,
        isPurchased: Bool = false
    ) {
        self.id = id
        self.title = title
        self.categoryRaw = categoryRaw
        self.colorHint = colorHint
        self.reason = reason
        self.isPurchased = isPurchased
        self.createdAt = Date()
    }

    var category: ClothingCategory? {
        categoryRaw.flatMap(ClothingCategory.init(rawValue:))
    }
}
