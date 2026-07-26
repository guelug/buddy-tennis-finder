import Foundation
import SwiftData
import UIKit

enum StorageQuotaStatus: Equatable {
    case ok(used: Int64, total: Int64)
    case warning(used: Int64, total: Int64)
    case critical(used: Int64, total: Int64)
}

enum StorageBudgetManager {
    static let totalBudgetBytes: Int64 = 2_000_000_000
    private static let warningThresholdRatio: Double = 0.85
    private static let criticalThresholdRatio: Double = 0.95
    private static let normalizedImageMaxDimension: CGFloat = 1280
    private static let normalizedImageCompressionQuality: CGFloat = 0.76

    static func currentUsageBytes(modelContext: ModelContext) -> Int64 {
        let users = (try? modelContext.fetch(FetchDescriptor<User>())) ?? []
        let clothingItems = (try? modelContext.fetch(FetchDescriptor<ClothingItem>())) ?? []
        let tryOnResults = (try? modelContext.fetch(FetchDescriptor<TryOnResult>())) ?? []
        let progressMissions = (try? modelContext.fetch(FetchDescriptor<StyleProgressMission>())) ?? []

        let userUsage = users.reduce(into: Int64.zero) { partialResult, user in
            partialResult += estimatedSize(of: user)
        }
        let clothingUsage = clothingItems.reduce(into: Int64.zero) { partialResult, item in
            partialResult += estimatedSize(of: item)
        }
        let tryOnUsage = tryOnResults.reduce(into: Int64.zero) { partialResult, result in
            partialResult += estimatedSize(of: result)
        }
        let missionUsage = progressMissions.reduce(into: Int64.zero) { partialResult, mission in
            partialResult += estimatedSize(of: mission)
        }

        return userUsage + clothingUsage + tryOnUsage + missionUsage
    }

    static func projectedUsageBytes(modelContext: ModelContext, additionalBytes: Int64) -> Int64 {
        max(0, currentUsageBytes(modelContext: modelContext) + additionalBytes)
    }

    static func canStore(additionalBytes: Int64, modelContext: ModelContext) -> Bool {
        projectedUsageBytes(modelContext: modelContext, additionalBytes: additionalBytes) <= totalBudgetBytes
    }

    static func quotaStatus(modelContext: ModelContext, additionalBytes: Int64 = 0) -> StorageQuotaStatus {
        let used = projectedUsageBytes(modelContext: modelContext, additionalBytes: additionalBytes)
        let ratio = Double(used) / Double(totalBudgetBytes)

        if ratio >= criticalThresholdRatio {
            return .critical(used: used, total: totalBudgetBytes)
        }

        if ratio >= warningThresholdRatio {
            return .warning(used: used, total: totalBudgetBytes)
        }

        return .ok(used: used, total: totalBudgetBytes)
    }

    static func overflowMessage(language: Language, modelContext: ModelContext, additionalBytes: Int64) -> String {
        let used = projectedUsageBytes(modelContext: modelContext, additionalBytes: additionalBytes)
        let usedString = formattedStorage(used)
        let totalString = formattedStorage(totalBudgetBytes)

        if language == .spanish {
            return "No puedo guardar más imágenes porque superarías el límite estimado de almacenamiento por usuario de \(totalString). Uso proyectado: \(usedString). Elimina resultados de try-on o prendas guardadas para liberar espacio."
        }

        return "I can't save more images because you would exceed the estimated per-user storage limit of \(totalString). Projected usage: \(usedString). Delete try-on results or saved garments to free space."
    }

    static func estimatedSize(of user: User) -> Int64 {
        let photoBytes = [
            user.faceCloseUpData,
            user.faceProfileData,
            user.fullBodyFrontData,
            user.fullBodyBackData,
            user.skinAnalysisData,
            user.personalPaletteData,
            user.personalStylingProfileData
        ].reduce(into: Int64.zero) { partialResult, data in
            partialResult += Int64(data?.count ?? 0)
        }

        return photoBytes
            + stringBytes(user.displayName)
            + stringBytes(user.subscriptionTierRaw)
            + stringBytes(user.preferredLanguageRaw)
            + collectionBytes(user.stylePreferences)
    }

    static func estimatedSize(of item: ClothingItem) -> Int64 {
        Int64(item.imageData?.count ?? 0)
            + Int64(item.realReferenceImageData?.count ?? 0)
            + Int64(item.optimizedImageData?.count ?? 0)
            + Int64(item.cutoutImageData?.count ?? 0)
            + stringBytes(item.id.uuidString)
            + stringBytes(item.name)
            + stringBytes(item.categoryRaw)
            + collectionBytes(item.colorTags)
            + collectionBytes(item.styleTags)
            + collectionBytes(item.materialTags)
            + collectionBytes(item.occasionTags)
            + collectionBytes(item.detailTags)
            + stringBytes(item.brandName)
            + stringBytes(item.notes)
            + stringBytes(item.metadataSummary)
            + intBytes(item.recommendationAppearanceCount)
            + intBytes(item.recommendationSuccessfulWearCount)
            + intBytes(item.recommendationIgnoredCount)
            + doubleBytes(item.hiddenUsageScore)
            + dateBytes(item.lastRecommendedAt)
            + dateBytes(item.lastConfirmedWearAt)
    }

    static func estimatedSize(of result: TryOnResult) -> Int64 {
        Int64(result.clothingImageData.count + result.userPhotoData.count + result.resultImageData.count)
            + Int64(result.editHistoryData?.count ?? 0)
            + stringBytes(result.id.uuidString)
            + stringBytes(result.cacheKey)
            + stringBytes(result.providerRaw)
            + stringBytes(result.clothingName)
            + stringBytes(result.clothingCategoryRaw)
            + stringBytes(result.closetItemIDString)
            + stringBytes(result.referenceDescriptor)
    }

    static func estimatedSize(of mission: StyleProgressMission) -> Int64 {
        Int64(mission.baselineImageData?.count ?? 0)
            + Int64(mission.followUpImageData?.count ?? 0)
            + stringBytes(mission.id.uuidString)
            + stringBytes(mission.title)
            + collectionBytes(mission.linkedItemIDStrings)
            + collectionBytes(mission.detectedItemIDStrings)
            + stringBytes(mission.notes)
            + intBytes(mission.targetMonths)
            + dateBytes(mission.createdAt)
            + dateBytes(mission.dueAt)
            + dateBytes(mission.completedAt)
            + stringBytes(mission.reminderIdentifier)
    }

    static func normalizedImageData(_ image: UIImage?) -> Data? {
        normalizedImageData(image, preservesAlpha: false)
    }

    static func normalizedClothingImageData(_ image: UIImage?) -> Data? {
        normalizedImageData(image, preservesAlpha: true)
    }

    static func normalizedClothingImage(_ image: UIImage?) -> UIImage? {
        guard let data = normalizedClothingImageData(image) else { return nil }
        return UIImage(data: data)
    }

    static func normalizedImage(_ image: UIImage?) -> UIImage? {
        guard let data = normalizedImageData(image) else { return nil }
        return UIImage(data: data)
    }

    private static func normalizedImageData(_ image: UIImage?, preservesAlpha: Bool) -> Data? {
        guard let image else { return nil }
        let maxDimension = max(image.size.width, image.size.height)
        let shouldPreserveAlpha = preservesAlpha && imageHasAlpha(image)

        guard maxDimension > normalizedImageMaxDimension else {
            return encodedData(for: image, preservesAlpha: shouldPreserveAlpha)
        }

        let scale = normalizedImageMaxDimension / maxDimension
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.opaque = !shouldPreserveAlpha
        rendererFormat.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: rendererFormat)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return encodedData(for: resizedImage, preservesAlpha: shouldPreserveAlpha)
    }

    static func incrementalBytesForProfileUpdate(
        currentUser: User?,
        profilePhotos: ProfilePhotos,
        skinAnalysis: SkinAnalysisResult?,
        personalPalette: PersonalPalette?
    ) -> Int64 {
        let currentBytes = currentUser.map(estimatedSize(of:)) ?? 0

        let profileDataBytes = [
            normalizedImageData(profilePhotos.faceCloseUp),
            normalizedImageData(profilePhotos.faceProfile),
            normalizedImageData(profilePhotos.fullBodyFront),
            normalizedImageData(profilePhotos.fullBodyBack)
        ].reduce(into: Int64.zero) { partialResult, data in
            partialResult += Int64(data?.count ?? 0)
        }

        let analysisBytes = Int64((try? JSONEncoder().encode(skinAnalysis))?.count ?? 0)
        let paletteBytes = Int64((try? JSONEncoder().encode(personalPalette))?.count ?? 0)
        let stylingBytes = Int64(currentUser?.personalStylingProfileData?.count ?? 0)
        let displayNameBytes = stringBytes(currentUser?.displayName)
        let tierBytes = stringBytes(currentUser?.subscriptionTierRaw)
        let languageBytes = stringBytes(currentUser?.preferredLanguageRaw)
        let preferenceBytes = collectionBytes(currentUser?.stylePreferences ?? [])

        let updatedBytes = profileDataBytes + analysisBytes + paletteBytes + stylingBytes + displayNameBytes + tierBytes + languageBytes + preferenceBytes
        return updatedBytes - currentBytes
    }

    static func incrementalBytesForClothingItem(
        name: String,
        category: ClothingCategory,
        image: UIImage?,
        realReferenceImage: UIImage? = nil,
        colorTags: [String],
        styleTags: [String] = [],
        materialTags: [String] = [],
        occasionTags: [String] = [],
        detailTags: [String] = [],
        brandName: String? = nil,
        notes: String? = nil,
        metadataSummary: String? = nil
    ) -> Int64 {
        Int64(normalizedClothingImageData(image)?.count ?? 0)
            + Int64(normalizedImageData(realReferenceImage)?.count ?? 0)
            + stringBytes(name)
            + stringBytes(category.rawValue)
            + collectionBytes(colorTags)
            + collectionBytes(styleTags)
            + collectionBytes(materialTags)
            + collectionBytes(occasionTags)
            + collectionBytes(detailTags)
            + stringBytes(brandName)
            + stringBytes(notes)
            + stringBytes(metadataSummary)
            + 36
    }

    static func incrementalBytesForProgressMission(
        title: String,
        linkedItemIDs: [UUID],
        baselineImage: UIImage?,
        followUpImage: UIImage? = nil,
        notes: String? = nil,
        reminderIdentifier: String? = nil
    ) -> Int64 {
        Int64(normalizedImageData(baselineImage)?.count ?? 0)
            + Int64(normalizedImageData(followUpImage)?.count ?? 0)
            + stringBytes(title)
            + collectionBytes(linkedItemIDs.map(\.uuidString))
            + stringBytes(notes)
            + stringBytes(reminderIdentifier)
            + 36
    }

    static func incrementalBytesForTryOnResult(
        cacheKey: String,
        provider: TryOnProvider,
        clothingName: String,
        clothingCategory: ClothingCategory?,
        closetItemID: UUID?,
        referenceDescriptor: String,
        clothingImage: UIImage,
        userPhoto: UIImage,
        resultImage: UIImage,
        editHistory: [ImageEdit] = []
    ) -> Int64 {
        Int64(normalizedClothingImageData(clothingImage)?.count ?? 0)
            + Int64(normalizedImageData(userPhoto)?.count ?? 0)
            + Int64(normalizedImageData(resultImage)?.count ?? 0)
            + Int64((try? JSONEncoder().encode(editHistory))?.count ?? 0)
            + stringBytes(cacheKey)
            + stringBytes(provider.rawValue)
            + stringBytes(clothingName)
            + stringBytes(clothingCategory?.rawValue)
            + stringBytes(closetItemID?.uuidString)
            + stringBytes(referenceDescriptor)
            + 36
    }

    private static func stringBytes(_ value: String?) -> Int64 {
        Int64(value?.utf8.count ?? 0)
    }

    private static func collectionBytes(_ values: [String]) -> Int64 {
        values.reduce(into: Int64.zero) { partialResult, value in
            partialResult += Int64(value.utf8.count)
        }
    }

    private static func intBytes(_ value: Int) -> Int64 {
        Int64(MemoryLayout<Int>.size)
    }

    private static func doubleBytes(_ value: Double) -> Int64 {
        Int64(MemoryLayout<Double>.size)
    }

    private static func dateBytes(_ value: Date?) -> Int64 {
        value == nil ? 0 : Int64(MemoryLayout<Double>.size)
    }

    private static func encodedData(for image: UIImage, preservesAlpha: Bool) -> Data? {
        if preservesAlpha {
            return image.pngData()
        }

        return image.jpegData(compressionQuality: normalizedImageCompressionQuality)
    }

    static func imageHasAlpha(_ image: UIImage) -> Bool {
        guard let alphaInfo = image.cgImage?.alphaInfo else {
            return false
        }

        switch alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast, .alphaOnly:
            return true
        case .none, .noneSkipFirst, .noneSkipLast:
            return false
        @unknown default:
            return false
        }
    }

    private static func formattedStorage(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
