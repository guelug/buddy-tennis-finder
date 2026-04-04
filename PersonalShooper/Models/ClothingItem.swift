import Foundation
import SwiftData
import UIKit

enum ClothingCategory: String, Codable, CaseIterable {
    case tops
    case bottoms
    case dresses
    case shoes
    case accessories
    case outerwear
    case activewear
    case swimwear

    var displayName: String {
        switch self {
        case .tops: return "Tops"
        case .bottoms: return "Bottoms"
        case .dresses: return "Dresses"
        case .shoes: return "Shoes"
        case .accessories: return "Accessories"
        case .outerwear: return "Outerwear"
        case .activewear: return "Activewear"
        case .swimwear: return "Swimwear"
        }
    }

    var icon: String {
        switch self {
        case .tops: return "tshirt"
        case .bottoms: return "figure.walk"
        case .dresses: return "figure.dress.line.vertical.figure"
        case .shoes: return "shoe"
        case .accessories: return "bag"
        case .outerwear: return "cloud.snow"
        case .activewear: return "figure.run"
        case .swimwear: return "figure.pool.swim"
        }
    }
}

@Model
final class ClothingItem {
    var id: UUID
    var name: String
    var categoryRaw: String
    var imageData: Data?
    var colorTags: [String]
    var styleTags: [String]
    var brandName: String?
    var notes: String?
    var createdAt: Date
    var isFavorite: Bool
    var timesWorn: Int
    var lastWornAt: Date?

    var category: ClothingCategory {
        get { ClothingCategory(rawValue: categoryRaw) ?? .tops }
        set { categoryRaw = newValue.rawValue }
    }

    var image: UIImage? {
        get {
            guard let data = imageData else { return nil }
            return UIImage(data: data)
        }
        set {
            imageData = newValue?.jpegData(compressionQuality: 0.8)
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        category: ClothingCategory,
        image: UIImage? = nil,
        colorTags: [String] = [],
        styleTags: [String] = [],
        brandName: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.imageData = image?.jpegData(compressionQuality: 0.8)
        self.colorTags = colorTags
        self.styleTags = styleTags
        self.brandName = brandName
        self.notes = notes
        self.createdAt = Date()
        self.isFavorite = false
        self.timesWorn = 0
        self.lastWornAt = nil
    }
}

@Model
final class TryOnResult {
    var id: UUID
    var cacheKey: String
    var providerRaw: String
    var clothingName: String
    var clothingCategoryRaw: String?
    var closetItemIDString: String?
    var referenceDescriptor: String
    var clothingImageData: Data
    var userPhotoData: Data
    var resultImageData: Data
    var editHistoryData: Data?
    var createdAt: Date

    var provider: TryOnProvider {
        get { TryOnProvider(rawValue: providerRaw) ?? .google }
        set { providerRaw = newValue.rawValue }
    }

    var clothingCategory: ClothingCategory? {
        get { clothingCategoryRaw.flatMap(ClothingCategory.init(rawValue:)) }
        set { clothingCategoryRaw = newValue?.rawValue }
    }

    var closetItemID: UUID? {
        get { closetItemIDString.flatMap(UUID.init(uuidString:)) }
        set { closetItemIDString = newValue?.uuidString }
    }

    var clothingImage: UIImage? {
        get { UIImage(data: clothingImageData) }
        set { clothingImageData = newValue?.jpegData(compressionQuality: 0.8) ?? Data() }
    }

    var userPhoto: UIImage? {
        get { UIImage(data: userPhotoData) }
        set { userPhotoData = newValue?.jpegData(compressionQuality: 0.8) ?? Data() }
    }

    var resultImage: UIImage? {
        get { UIImage(data: resultImageData) }
        set { resultImageData = newValue?.jpegData(compressionQuality: 0.8) ?? Data() }
    }

    var editHistory: [ImageEdit] {
        get {
            guard let data = editHistoryData else { return [] }
            return (try? JSONDecoder().decode([ImageEdit].self, from: data)) ?? []
        }
        set {
            editHistoryData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        id: UUID = UUID(),
        cacheKey: String,
        provider: TryOnProvider,
        clothingName: String,
        clothingCategory: ClothingCategory? = nil,
        closetItemID: UUID? = nil,
        referenceDescriptor: String,
        clothingImage: UIImage,
        userPhoto: UIImage,
        resultImage: UIImage,
        editHistory: [ImageEdit] = []
    ) {
        self.id = id
        self.cacheKey = cacheKey
        self.providerRaw = provider.rawValue
        self.clothingName = clothingName
        self.clothingCategoryRaw = clothingCategory?.rawValue
        self.closetItemIDString = closetItemID?.uuidString
        self.referenceDescriptor = referenceDescriptor
        self.clothingImageData = clothingImage.jpegData(compressionQuality: 0.8) ?? Data()
        self.userPhotoData = userPhoto.jpegData(compressionQuality: 0.8) ?? Data()
        self.resultImageData = resultImage.jpegData(compressionQuality: 0.8) ?? Data()
        self.editHistoryData = try? JSONEncoder().encode(editHistory)
        self.createdAt = Date()
    }
}

struct ImageEdit: Codable, Identifiable {
    let id: UUID
    let instruction: String
    let previousImageData: Data
    let newImageData: Data
    let timestamp: Date

    init(
        id: UUID = UUID(),
        instruction: String,
        previousImage: UIImage,
        newImage: UIImage
    ) {
        self.id = id
        self.instruction = instruction
        self.previousImageData = previousImage.jpegData(compressionQuality: 0.8) ?? Data()
        self.newImageData = newImage.jpegData(compressionQuality: 0.8) ?? Data()
        self.timestamp = Date()
    }
}
