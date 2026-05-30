import Foundation
import SwiftData
import UIKit

enum ClothingCategory: String, Codable, CaseIterable, Sendable {
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

    /// Where on the body this garment goes — used to instruct the try-on model to swap ONLY the
    /// relevant garment and keep everything else the person is wearing unchanged.
    var tryOnReplacementInstruction: String {
        switch self {
        case .tops, .activewear:
            return "The garment in image 1 is an UPPER-BODY top (e.g. shirt, t-shirt, blouse, sweater). Replace ONLY the person's upper-body top. Keep their existing trousers/skirt, shoes, and accessories exactly as they are."
        case .bottoms:
            return "The garment in image 1 is a LOWER-BODY item (e.g. trousers, jeans, skirt, shorts). Replace ONLY the person's lower-body garment. Keep their existing top, shoes, and accessories exactly as they are."
        case .dresses:
            return "The garment in image 1 is a full-body DRESS. Replace the person's full outfit with this dress, keeping their shoes unless the dress requires otherwise."
        case .shoes:
            return "The garment in image 1 is FOOTWEAR (shoes/sneakers/boots). Replace ONLY the shoes on the person's feet. Do NOT turn it into a shirt or any other garment. Keep their existing top, trousers, and accessories exactly as they are."
        case .outerwear:
            return "The garment in image 1 is an OUTER LAYER (jacket/coat/blazer). Place it as an outer layer over the person's existing outfit, keeping the visible clothing underneath, trousers, and shoes unchanged."
        case .accessories:
            return "The item in image 1 is an ACCESSORY (e.g. bag, hat, scarf, belt). Add ONLY this accessory. Keep all of the person's existing clothing and shoes unchanged."
        case .swimwear:
            return "The garment in image 1 is SWIMWEAR. Replace the person's outfit with this swimwear."
        }
    }
}

@Model
final class ClothingItem {
    var id: UUID
    var name: String
    var categoryRaw: String
    var imageData: Data?
    var realReferenceImageData: Data?
    var colorTags: [String]
    var styleTags: [String]
    var materialTags: [String]
    var occasionTags: [String]
    var detailTags: [String]
    var brandName: String?
    var notes: String?
    var metadataSummary: String?
    var createdAt: Date
    var isFavorite: Bool
    var timesWorn: Int
    var lastWornAt: Date?
    var recommendationAppearanceCount: Int
    var recommendationSuccessfulWearCount: Int
    var recommendationIgnoredCount: Int
    var hiddenUsageScore: Double
    var lastRecommendedAt: Date?
    var lastConfirmedWearAt: Date?

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
            imageData = StorageBudgetManager.normalizedClothingImageData(newValue)
        }
    }

    var realReferenceImage: UIImage? {
        get {
            guard let data = realReferenceImageData else { return nil }
            return UIImage(data: data)
        }
        set {
            realReferenceImageData = StorageBudgetManager.normalizedImageData(newValue)
        }
    }

    var displayImage: UIImage? {
        realReferenceImage ?? image
    }

    var hiddenUsagePercentage: Int {
        Int(hiddenUsageScore.rounded())
    }

    var hasRealReferenceImage: Bool {
        realReferenceImageData != nil
    }

    var shouldSuggestSelling: Bool {
        recommendationAppearanceCount >= 3
            && recommendationSuccessfulWearCount == 0
            && recommendationIgnoredCount >= 2
    }

    init(
        id: UUID = UUID(),
        name: String,
        category: ClothingCategory,
        image: UIImage? = nil,
        colorTags: [String] = [],
        styleTags: [String] = [],
        materialTags: [String] = [],
        occasionTags: [String] = [],
        detailTags: [String] = [],
        brandName: String? = nil,
        notes: String? = nil,
        metadataSummary: String? = nil
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.imageData = StorageBudgetManager.normalizedClothingImageData(image)
        self.realReferenceImageData = nil
        self.colorTags = colorTags
        self.styleTags = styleTags
        self.materialTags = materialTags
        self.occasionTags = occasionTags
        self.detailTags = detailTags
        self.brandName = brandName
        self.notes = notes
        self.metadataSummary = metadataSummary
        self.createdAt = Date()
        self.isFavorite = false
        self.timesWorn = 0
        self.lastWornAt = nil
        self.recommendationAppearanceCount = 0
        self.recommendationSuccessfulWearCount = 0
        self.recommendationIgnoredCount = 0
        self.hiddenUsageScore = 0
        self.lastRecommendedAt = nil
        self.lastConfirmedWearAt = nil
    }

    func registerRecommendationAppearance(at date: Date = Date()) {
        recommendationAppearanceCount += 1
        lastRecommendedAt = date
        recalculateHiddenUsageScore()
    }

    func registerConfirmedWear(at date: Date = Date(), afterRecommendation: Bool = false) {
        timesWorn += 1
        lastWornAt = date
        lastConfirmedWearAt = date

        if afterRecommendation {
            recommendationSuccessfulWearCount += 1
        }

        recalculateHiddenUsageScore()
    }

    func registerIgnoredRecommendation() {
        recommendationIgnoredCount += 1
        recalculateHiddenUsageScore()
    }

    func makeProgressMission(
        title: String? = nil,
        baselineImage: UIImage?,
        targetMonths: Int,
        notes: String? = nil
    ) -> StyleProgressMission {
        StyleProgressMission(
            title: title ?? name,
            linkedItemIDs: [id],
            baselineImage: baselineImage,
            targetMonths: targetMonths,
            notes: notes
        )
    }

    func recalculateHiddenUsageScore() {
        guard recommendationAppearanceCount > 0 else {
            hiddenUsageScore = min(Double(timesWorn) * 12, 100)
            return
        }

        let successRatio = Double(recommendationSuccessfulWearCount) / Double(max(recommendationAppearanceCount, 1))
        let ignorePenalty = min(Double(recommendationIgnoredCount) * 0.12, 0.4)
        let wearBonus = min(Double(timesWorn) * 0.03, 0.25)
        hiddenUsageScore = max(0, min((successRatio + wearBonus - ignorePenalty) * 100, 100))
    }
}

@Model
final class StyleProgressMission {
    var id: UUID
    var title: String
    var linkedItemIDStrings: [String]
    var baselineImageData: Data?
    var followUpImageData: Data?
    var detectedItemIDStrings: [String]
    var notes: String?
    var targetMonths: Int
    var createdAt: Date
    var dueAt: Date
    var completedAt: Date?
    var isActive: Bool
    var reminderIdentifier: String?

    var linkedItemIDs: [UUID] {
        get { linkedItemIDStrings.compactMap(UUID.init(uuidString:)) }
        set { linkedItemIDStrings = newValue.map(\.uuidString) }
    }

    var detectedItemIDs: [UUID] {
        get { detectedItemIDStrings.compactMap(UUID.init(uuidString:)) }
        set { detectedItemIDStrings = newValue.map(\.uuidString) }
    }

    var baselineImage: UIImage? {
        get {
            guard let baselineImageData else { return nil }
            return UIImage(data: baselineImageData)
        }
        set {
            baselineImageData = StorageBudgetManager.normalizedImageData(newValue)
        }
    }

    var followUpImage: UIImage? {
        get {
            guard let followUpImageData else { return nil }
            return UIImage(data: followUpImageData)
        }
        set {
            followUpImageData = StorageBudgetManager.normalizedImageData(newValue)
        }
    }

    var isDueForFollowUp: Bool {
        isActive && Date() >= dueAt
    }

    init(
        id: UUID = UUID(),
        title: String,
        linkedItemIDs: [UUID],
        baselineImage: UIImage? = nil,
        targetMonths: Int,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.linkedItemIDStrings = linkedItemIDs.map(\.uuidString)
        self.baselineImageData = StorageBudgetManager.normalizedImageData(baselineImage)
        self.followUpImageData = nil
        self.detectedItemIDStrings = []
        self.notes = notes
        self.targetMonths = targetMonths
        self.createdAt = createdAt
        self.dueAt = Calendar.current.date(byAdding: .month, value: max(targetMonths, 1), to: createdAt) ?? createdAt
        self.completedAt = nil
        self.isActive = true
        self.reminderIdentifier = nil
    }

    func complete(with image: UIImage?, detectedItemIDs: [UUID] = []) {
        followUpImage = image
        self.detectedItemIDs = detectedItemIDs
        completedAt = Date()
        isActive = false
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
        set { clothingImageData = StorageBudgetManager.normalizedClothingImageData(newValue) ?? Data() }
    }

    var userPhoto: UIImage? {
        get { UIImage(data: userPhotoData) }
        set { userPhotoData = StorageBudgetManager.normalizedImageData(newValue) ?? Data() }
    }

    var resultImage: UIImage? {
        get { UIImage(data: resultImageData) }
        set { resultImageData = StorageBudgetManager.normalizedImageData(newValue) ?? Data() }
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
        self.clothingImageData = StorageBudgetManager.normalizedClothingImageData(clothingImage) ?? Data()
        self.userPhotoData = StorageBudgetManager.normalizedImageData(userPhoto) ?? Data()
        self.resultImageData = StorageBudgetManager.normalizedImageData(resultImage) ?? Data()
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
        self.previousImageData = StorageBudgetManager.normalizedImageData(previousImage) ?? Data()
        self.newImageData = StorageBudgetManager.normalizedImageData(newImage) ?? Data()
        self.timestamp = Date()
    }
}
