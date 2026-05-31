import Foundation
import SwiftData
import RealityKit

/// Represents a manually-placed 3D tag in the user's physical closet/wardrobe.
/// The user taps where a garment is located, and we save the world position + garment reference.
@Model
final class ARClothingPlacement {
    var id: UUID
    var clothingItemIDString: String
    var positionX: Double
    var positionY: Double
    var positionZ: Double
    var createdAt: Date
    var label: String?
    var shelfName: String?

    var clothingItemID: UUID {
        get { UUID(uuidString: clothingItemIDString) ?? UUID() }
        set { clothingItemIDString = newValue.uuidString }
    }

    var simdPosition: SIMD3<Float> {
        get { SIMD3<Float>(Float(positionX), Float(positionY), Float(positionZ)) }
        set {
            positionX = Double(newValue.x)
            positionY = Double(newValue.y)
            positionZ = Double(newValue.z)
        }
    }

    init(
        id: UUID = UUID(),
        clothingItemID: UUID,
        position: SIMD3<Float>,
        label: String? = nil,
        shelfName: String? = nil
    ) {
        self.id = id
        self.clothingItemIDString = clothingItemID.uuidString
        self.positionX = Double(position.x)
        self.positionY = Double(position.y)
        self.positionZ = Double(position.z)
        self.createdAt = Date()
        self.label = label
        self.shelfName = shelfName
    }
}
