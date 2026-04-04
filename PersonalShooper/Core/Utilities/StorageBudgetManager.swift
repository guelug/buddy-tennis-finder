import Foundation
import SwiftData
import UIKit

enum StorageBudgetManager {
    static let totalBudgetBytes: Int64 = 2_000_000_000
    private static let warningThresholdRatio: Double = 0.85
    private static let criticalThresholdRatio: Double = 0.95
    private static let normalizedImageMaxDimension: CGFloat = 1600
    private static let normalizedImageCompressionQuality: CGFloat = 0.78

    static func currentUsageBytes(modelContext: ModelContext) -> Int64 {
        let users = (try? modelContext.fetch(FetchDescriptor<User>())) ?? []
        let clothingItems = (try? modelContext.fetch(FetchDescriptor<ClothingItem>())) ?? []
        let tryOnResults = (try? modelContext.fetch(FetchDescriptor<TryOnResult>())) ?? []

        let userUsage = users.reduce(into: Int64.zero) { partialResult, user in
            partialResult += estimatedSize(of: user)
        }
        let clothingUsage = clothingItems.reduce(into: Int64.zero) { partialResult, item in
            partialResult += estimatedSize(of: item)
        }
        let tryOnUsage = tryOnResults.reduce(into: Int64.zero) { partialResult, result in
            partialResult += estimatedSize(of: result)
        }

        return userUsage + clothingUsage + tryOnUsage
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
            + stringBytes(item.id.uuidString)
            + stringBytes(item.name)
            + stringBytes(item.categoryRaw)
            + collectionBytes(item.colorTags)
            + collectionBytes(item.styleTags)
            + stringBytes(item.brandName)
            + stringBytes(item.notes)
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

    static func normalizedImageData(_ image: UIImage?) -> Data? {
        guard let image else { return nil }
        let maxDimension = max(image.size.width, image.size.height)

        guard maxDimension > normalizedImageMaxDimension else {
            return image.jpegData(compressionQuality: normalizedImageCompressionQuality)
        }

        let scale = normalizedImageMaxDimension / maxDimension
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resizedImage.jpegData(compressionQuality: normalizedImageCompressionQuality)
    }

    static func normalizedImage(_ image: UIImage?) -> UIImage? {
        guard let data = normalizedImageData(image) else { return nil }
        return UIImage(data: data)
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
        colorTags: [String],
        styleTags: [String] = [],
        brandName: String? = nil,
        notes: String? = nil
    ) -> Int64 {
        Int64(normalizedImageData(image)?.count ?? 0)
            + stringBytes(name)
            + stringBytes(category.rawValue)
            + collectionBytes(colorTags)
            + collectionBytes(styleTags)
            + stringBytes(brandName)
            + stringBytes(notes)
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
        Int64(normalizedImageData(clothingImage)?.count ?? 0)
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

    private static func formattedStorage(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
