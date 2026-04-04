import CryptoKit
import SwiftData
import SwiftUI
import UIKit

enum TryOnSelectionSource {
    case camera
    case library
    case closet
}

private struct TryOnReferencePlan {
    let image: UIImage
    let descriptor: String
}

@Observable
@MainActor
final class TryOnViewModel {
    var selectedClothingImage: UIImage?
    var selectedClothingCategory: ClothingCategory?
    var selectedClothingName: String = ""
    var selectedClosetItemID: UUID?
    var selectedSource: TryOnSelectionSource?
    var generatedImage: UIImage?
    var isGenerating = false
    var isAnalyzingClothing = false
    var errorMessage: String?
    var selectedProvider: TryOnProvider
    var referenceDescription: String?
    var lastResultWasCached = false

    private let classificationService = ClothingClassificationService()
    private let providerService = TryOnProviderService()

    init() {
        selectedProvider = providerService.currentProvider
    }

    func setSelectedClothingImage(
        _ image: UIImage,
        source: TryOnSelectionSource,
        closetItem: ClothingItem? = nil
    ) async {
        selectedClothingImage = image
        selectedSource = source
        generatedImage = nil
        lastResultWasCached = false
        errorMessage = nil

        if let closetItem {
            selectedClothingCategory = closetItem.category
            selectedClothingName = closetItem.name
            selectedClosetItemID = closetItem.id
            return
        }

        selectedClosetItemID = nil
        selectedClothingName = ""
        selectedClothingCategory = nil
        isAnalyzingClothing = true

        defer { isAnalyzingClothing = false }

        do {
            let classification = try await classificationService.classifyClothing(image: image)
            selectedClothingCategory = classification.category
            selectedClothingName = classification.category.displayName
        } catch {
            selectedClothingCategory = .tops
            selectedClothingName = ClothingCategory.tops.displayName
        }
    }

    func generateTryOn(for user: User?, modelContext: ModelContext, language: Language) async {
        guard let clothingImage = selectedClothingImage else {
            errorMessage = language == .spanish
                ? "Selecciona una prenda para generar el try-on."
                : "Select a garment to generate the try-on."
            return
        }

        guard let user else {
            errorMessage = language == .spanish
                ? "Necesitas un perfil antes de usar el probador."
                : "You need a profile before using try-on."
            return
        }

        guard let referencePlan = resolveReferencePlan(for: user, language: language) else {
            errorMessage = missingProfilePhotosMessage(for: selectedClothingCategory, language: language)
            return
        }

        referenceDescription = referencePlan.descriptor

        guard let clothingData = clothingImage.jpegData(compressionQuality: 0.8),
              let referenceData = referencePlan.image.jpegData(compressionQuality: 0.8) else {
            errorMessage = language == .spanish
                ? "No he podido preparar las imágenes para el try-on."
                : "I couldn't prepare the images for try-on."
            return
        }

        let cacheKey = makeCacheKey(
            provider: selectedProvider,
            clothingData: clothingData,
            referenceData: referenceData
        )

        if let cachedResult = fetchCachedResult(cacheKey: cacheKey, modelContext: modelContext) {
            generatedImage = cachedResult.resultImage
            lastResultWasCached = true
            return
        }

        isGenerating = true
        errorMessage = nil
        lastResultWasCached = false

        do {
            providerService.setProvider(selectedProvider)
            let generated = try await providerService.generateTryOn(
                clothingImage: clothingImage,
                userImage: referencePlan.image
            )

            let result = TryOnResult(
                cacheKey: cacheKey,
                provider: selectedProvider,
                clothingName: selectedClothingLabel(language: language),
                clothingCategory: selectedClothingCategory,
                closetItemID: selectedClosetItemID,
                referenceDescriptor: referencePlan.descriptor,
                clothingImage: clothingImage,
                userPhoto: referencePlan.image,
                resultImage: generated
            )
            modelContext.insert(result)
            try? modelContext.save()

            generatedImage = generated
        } catch {
            errorMessage = localizedErrorMessage(error, language: language)
        }

        isGenerating = false
    }

    func selectProvider(_ provider: TryOnProvider) {
        selectedProvider = provider
        providerService.setProvider(provider)
        generatedImage = nil
        lastResultWasCached = false
    }

    func clearGeneratedResult() {
        generatedImage = nil
        lastResultWasCached = false
    }

    func resetSelection() {
        selectedClothingImage = nil
        selectedClothingCategory = nil
        selectedClothingName = ""
        selectedClosetItemID = nil
        selectedSource = nil
        generatedImage = nil
        isGenerating = false
        isAnalyzingClothing = false
        errorMessage = nil
        referenceDescription = nil
        lastResultWasCached = false
    }

    private func selectedClothingLabel(language: Language) -> String {
        if !selectedClothingName.isEmpty {
            return selectedClothingName
        }

        if let category = selectedClothingCategory {
            return language == .spanish ? localizedCategoryName(category) : category.displayName
        }

        return language == .spanish ? "Prenda" : "Garment"
    }

    private func resolveReferencePlan(for user: User, language: Language) -> TryOnReferencePlan? {
        let photos = user.profilePhotos
        let category = selectedClothingCategory ?? .tops

        if category == .accessories {
            guard let primary = photos.faceCloseUp ?? photos.faceProfile else {
                return nil
            }

            let composite = composeReferenceImage(primary: primary, secondary: photos.faceProfile)
            return TryOnReferencePlan(
                image: composite,
                descriptor: language == .spanish
                    ? "Referencia de rostro del perfil"
                    : "Face reference from profile"
            )
        }

        guard let primary = photos.fullBodyFront else {
            return nil
        }

        let secondary = shouldUseBackReference(for: category) ? photos.fullBodyBack : nil
        let image = composeReferenceImage(primary: primary, secondary: secondary)
        let descriptor: String
        if secondary != nil {
            descriptor = language == .spanish
                ? "Referencia frontal y trasera del perfil"
                : "Front and back profile reference"
        } else {
            descriptor = language == .spanish
                ? "Referencia frontal del perfil"
                : "Front profile reference"
        }

        return TryOnReferencePlan(image: image, descriptor: descriptor)
    }

    private func shouldUseBackReference(for category: ClothingCategory) -> Bool {
        switch category {
        case .tops, .dresses, .outerwear, .activewear, .swimwear:
            return true
        case .bottoms, .shoes, .accessories:
            return false
        }
    }

    private func composeReferenceImage(primary: UIImage, secondary: UIImage?) -> UIImage {
        guard let secondary else { return primary }

        let targetHeight = max(primary.size.height, secondary.size.height)
        let leftWidth = primary.size.width * (targetHeight / max(primary.size.height, 1))
        let rightWidth = secondary.size.width * (targetHeight / max(secondary.size.height, 1))
        let canvasSize = CGSize(width: leftWidth + rightWidth, height: targetHeight)

        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { _ in
            UIColor.systemBackground.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: canvasSize)).fill()

            primary.draw(in: CGRect(x: 0, y: 0, width: leftWidth, height: targetHeight))
            secondary.draw(in: CGRect(x: leftWidth, y: 0, width: rightWidth, height: targetHeight))
        }
    }

    private func fetchCachedResult(cacheKey: String, modelContext: ModelContext) -> TryOnResult? {
        let descriptor = FetchDescriptor<TryOnResult>(
            predicate: #Predicate { $0.cacheKey == cacheKey },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        return try? modelContext.fetch(descriptor).first
    }

    private func makeCacheKey(provider: TryOnProvider, clothingData: Data, referenceData: Data) -> String {
        var combined = Data(provider.rawValue.utf8)
        combined.append(clothingData)
        combined.append(referenceData)
        let digest = SHA256.hash(data: combined)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func localizedErrorMessage(_ error: Error, language: Language) -> String {
        if let tryOnError = error as? TryOnProviderError,
           let description = tryOnError.errorDescription {
            return description
        }

        return language == .spanish
            ? "No se ha podido generar el try-on. \(error.localizedDescription)"
            : "The try-on could not be generated. \(error.localizedDescription)"
    }

    private func missingProfilePhotosMessage(for category: ClothingCategory?, language: Language) -> String {
        if category == .accessories {
            return language == .spanish
                ? "Para esta prenda necesito al menos una foto de rostro en tu perfil."
                : "For this garment I need at least one face photo in your profile."
        }

        return language == .spanish
            ? "Para esta prenda necesito tu foto de cuerpo completo frontal en el perfil. La trasera mejora el resultado en prendas con espalda."
            : "For this garment I need your front full-body profile photo. The back photo improves garments with rear detail."
    }

    private func localizedCategoryName(_ category: ClothingCategory) -> String {
        switch category {
        case .tops: return "Parte de arriba"
        case .bottoms: return "Parte de abajo"
        case .dresses: return "Vestido"
        case .shoes: return "Zapatos"
        case .accessories: return "Accesorio"
        case .outerwear: return "Abrigo o chaqueta"
        case .activewear: return "Deporte"
        case .swimwear: return "Baño"
        }
    }
}
