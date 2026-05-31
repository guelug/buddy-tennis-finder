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
        selectedSource = source
        generatedImage = nil
        lastResultWasCached = false
        errorMessage = nil

        if let closetItem {
            selectedClothingImage = image
            selectedClothingCategory = closetItem.category
            selectedClothingName = closetItem.name
            selectedClosetItemID = closetItem.id
            return
        }

        selectedClothingImage = image
        selectedClosetItemID = nil
        selectedClothingName = ""
        selectedClothingCategory = nil
        isAnalyzingClothing = true

        defer { isAnalyzingClothing = false }

        let preparedImage = await GarmentBackgroundRemovalService.prepareImage(image)
        selectedClothingImage = preparedImage

        do {
            let classification = try await classificationService.classifyClothing(image: preparedImage)
            selectedClothingCategory = classification.category
            selectedClothingName = classification.category.displayName
        } catch {
            selectedClothingCategory = .tops
            selectedClothingName = ClothingCategory.tops.displayName
        }
    }

    func generateTryOn(
        for user: User?,
        modelContext: ModelContext,
        language: Language,
        canGenerateCleanReference: Bool = false
    ) async {
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

        // Premium/BYOK: generate (once) a clean studio reference so try-ons aren't polluted by the
        // original photo's mirror/background. Cached on the user; failures fall back to the raw photo.
        if canGenerateCleanReference {
            await ensureCleanReference(for: user, modelContext: modelContext)
        }

        guard let referencePlan = resolveReferencePlan(for: user, language: language) else {
            errorMessage = missingProfilePhotosMessage(for: selectedClothingCategory, language: language)
            return
        }

        referenceDescription = referencePlan.descriptor

        guard let clothingData = StorageBudgetManager.normalizedClothingImageData(clothingImage),
              let referenceData = StorageBudgetManager.normalizedImageData(referencePlan.image) else {
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
                userImage: referencePlan.image,
                garmentCategory: selectedClothingCategory
            )

            let additionalBytes = StorageBudgetManager.incrementalBytesForTryOnResult(
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

            guard StorageBudgetManager.canStore(additionalBytes: additionalBytes, modelContext: modelContext) else {
                errorMessage = StorageBudgetManager.overflowMessage(
                    language: language,
                    modelContext: modelContext,
                    additionalBytes: additionalBytes
                )
                isGenerating = false
                return
            }

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
            do {
                try modelContext.save()
            } catch {
                modelContext.delete(result)
                errorMessage = language == .spanish
                    ? "He generado la imagen, pero no he podido guardarla en caché: \(error.localizedDescription)"
                    : "I generated the image, but I couldn't cache it: \(error.localizedDescription)"
            }
 
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

    /// Generates and caches an AI-cleaned full-body reference once, when the user is entitled and a
    /// front body photo exists. Best-effort: any failure leaves the raw photo path intact.
    private func ensureCleanReference(for user: User, modelContext: ModelContext) async {
        guard user.cleanBodyReferenceData == nil,
              let frontPhoto = user.profilePhotos.fullBodyFront else { return }

        do {
            let cleaned = try await StyleImageService.cleanStudioReference(from: frontPhoto)
            user.cleanBodyReference = cleaned
            user.updatedAt = Date()
            try? modelContext.save()
        } catch {
            // Ignore — try-on will fall back to the original front photo.
        }
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

        // Prefer the AI-cleaned studio reference when available; fall back to the raw front photo.
        guard let primary = user.cleanBodyReference ?? photos.fullBodyFront else {
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
        case .bottoms, .shoes, .accessories, .jewelry, .lingerie, .beauty:
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
        if let tryOnError = error as? TryOnProviderError {
            switch (tryOnError, language) {
            case (.authenticationRequired, .spanish):
                return "Necesitas configurar una clave válida de OpenAI para usar este proveedor."
            case (.authenticationRequired, .english):
                return "You need to configure a valid OpenAI key to use this provider."
            case (.notYetImplemented, .spanish):
                return "Este proveedor aún no está disponible."
            case (.notYetImplemented, .english):
                return "This provider is not available yet."
            case (.generationFailed(let message), .spanish):
                return "No se ha podido generar el try-on. \(message)"
            case (.generationFailed(let message), .english):
                return "The try-on could not be generated. \(message)"
            }
        }

        if let tryOnError = error as? TryOnError {
            switch (tryOnError, language) {
            case (.apiError(let message), .spanish):
                return "La llamada al proveedor de try-on falló: \(message)"
            case (.apiError(let message), .english):
                return "The try-on provider request failed: \(message)"
            case (.invalidURL, .spanish):
                return "La URL del proveedor de try-on no es válida."
            case (.invalidURL, .english):
                return "The try-on provider URL is invalid."
            case (.parsingError, .spanish):
                return "No he podido interpretar la respuesta del proveedor de try-on."
            case (.parsingError, .english):
                return "I couldn't parse the try-on provider response."
            case (.invalidImageData, .spanish):
                return "No he podido preparar correctamente las imágenes enviadas al proveedor."
            case (.invalidImageData, .english):
                return "I couldn't prepare the images correctly for the provider."
            case (.noAPIKey, .spanish):
                return "Falta configurar la clave de Gemini para este proveedor."
            case (.noAPIKey, .english):
                return "The Gemini API key is missing for this provider."
            }
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
        case .jewelry: return "Joyería"
        case .lingerie: return "Lencería"
        case .beauty: return "Belleza"
        }
    }
}
