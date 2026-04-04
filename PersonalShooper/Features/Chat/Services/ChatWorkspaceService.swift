import CryptoKit
import SwiftData
import UIKit

struct ChatPreparedFeatures {
    var textSelectionEnabled = false
    var richMediaMessagesEnabled = false
    var toolInvocationEnabled = false
    var imageGenerationEnabled = false
}

enum ChatToolKind: String, Codable, CaseIterable {
    case closetSearch
    case closetAdd
    case tryOnGenerate
    case imageCreate
}

struct ChatToolResult {
    let assistantText: String
    let image: UIImage?
    let linkedClosetItemID: UUID?
    let linkedTryOnResultID: UUID?
    let metadata: ChatMessageMetadata
}

enum ChatWorkspaceError: LocalizedError {
    case missingClosetImage
    case missingProfilePhoto
    case imagePreparationFailed
    case generatedImageMissing
    case imageGenerationUnavailable
    case storageQuotaExceeded(String)

    var errorDescription: String? {
        switch self {
        case .missingClosetImage:
            return "The selected closet garment does not have a valid image."
        case .missingProfilePhoto:
            return "The user profile does not contain the required reference photos."
        case .imagePreparationFailed:
            return "The source images could not be prepared."
        case .generatedImageMissing:
            return "The generated result image is missing."
        case .imageGenerationUnavailable:
            return "Chat image generation is prepared but still disabled."
        case .storageQuotaExceeded(let message):
            return message
        }
    }
}

private struct ChatTryOnReferencePlan {
    let image: UIImage
    let descriptor: String
}

@MainActor
final class ChatWorkspaceService {
    private let providerService = TryOnProviderService()

    func makeAssistantMessage(baseContent: String, toolResult: ChatToolResult? = nil) -> Message {
        guard let toolResult else {
            return Message(role: .assistant, content: baseContent)
        }

        let content: String
        if baseContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content = toolResult.assistantText
        } else if toolResult.assistantText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content = baseContent
        } else {
            content = "\(baseContent)\n\n\(toolResult.assistantText)"
        }

        return Message(
            role: .assistant,
            content: content,
            image: toolResult.image,
            linkedClosetItemID: toolResult.linkedClosetItemID,
            linkedTryOnResultID: toolResult.linkedTryOnResultID,
            metadata: toolResult.metadata
        )
    }

    func generateTryOnAsset(
        for closetItem: ClothingItem,
        user: User,
        provider: TryOnProvider,
        modelContext: ModelContext,
        language: Language
    ) async throws -> ChatToolResult {
        guard let clothingImage = closetItem.image else {
            throw ChatWorkspaceError.missingClosetImage
        }

        guard let referencePlan = resolveReferencePlan(for: user, category: closetItem.category, language: language) else {
            throw ChatWorkspaceError.missingProfilePhoto
        }

        guard let clothingData = clothingImage.jpegData(compressionQuality: 0.8),
              let referenceData = referencePlan.image.jpegData(compressionQuality: 0.8) else {
            throw ChatWorkspaceError.imagePreparationFailed
        }

        let cacheKey = makeCacheKey(provider: provider, clothingData: clothingData, referenceData: referenceData)

        if let cached = fetchCachedResult(cacheKey: cacheKey, modelContext: modelContext),
           let cachedImage = cached.resultImage {
            return ChatToolResult(
                assistantText: cachedResultMessage(for: closetItem, language: language),
                image: cachedImage,
                linkedClosetItemID: closetItem.id,
                linkedTryOnResultID: cached.id,
                metadata: ChatMessageMetadata(
                    assetSource: .generatedTryOn,
                    toolIdentifier: ChatToolKind.tryOnGenerate.rawValue,
                    cacheKey: cacheKey
                )
            )
        }

        providerService.setProvider(provider)
        let generated = try await providerService.generateTryOn(
            clothingImage: clothingImage,
            userImage: referencePlan.image
        )

        let additionalBytes = StorageBudgetManager.incrementalBytesForTryOnResult(
            cacheKey: cacheKey,
            provider: provider,
            clothingName: closetItem.name,
            clothingCategory: closetItem.category,
            closetItemID: closetItem.id,
            referenceDescriptor: referencePlan.descriptor,
            clothingImage: clothingImage,
            userPhoto: referencePlan.image,
            resultImage: generated
        )

        guard StorageBudgetManager.canStore(additionalBytes: additionalBytes, modelContext: modelContext) else {
            throw ChatWorkspaceError.storageQuotaExceeded(
                StorageBudgetManager.overflowMessage(
                    language: language,
                    modelContext: modelContext,
                    additionalBytes: additionalBytes
                )
            )
        }

        let result = TryOnResult(
            cacheKey: cacheKey,
            provider: provider,
            clothingName: closetItem.name,
            clothingCategory: closetItem.category,
            closetItemID: closetItem.id,
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
            return ChatToolResult(
                assistantText: generatedResultMessage(for: closetItem, language: language),
                image: generated,
                linkedClosetItemID: closetItem.id,
                linkedTryOnResultID: nil,
                metadata: ChatMessageMetadata(
                    assetSource: .generatedTryOn,
                    toolIdentifier: ChatToolKind.tryOnGenerate.rawValue,
                    cacheKey: cacheKey
                )
            )
        }

        return ChatToolResult(
            assistantText: generatedResultMessage(for: closetItem, language: language),
            image: generated,
            linkedClosetItemID: closetItem.id,
            linkedTryOnResultID: result.id,
            metadata: ChatMessageMetadata(
                assetSource: .generatedTryOn,
                toolIdentifier: ChatToolKind.tryOnGenerate.rawValue,
                cacheKey: cacheKey
            )
        )
    }

    func prepareStandaloneImageGeneration(prompt: String, language: Language) throws -> ChatToolResult {
        let message = language == .spanish
            ? "La generación de imágenes desde el chat está preparada, pero sigue desactivada."
            : "Chat image generation is prepared, but it is still disabled."

        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ChatWorkspaceError.imageGenerationUnavailable
        }

        return ChatToolResult(
            assistantText: message,
            image: nil,
            linkedClosetItemID: nil,
            linkedTryOnResultID: nil,
            metadata: ChatMessageMetadata(
                assetSource: .none,
                toolIdentifier: ChatToolKind.imageCreate.rawValue,
                cacheKey: nil
            )
        )
    }

    private func cachedResultMessage(for closetItem: ClothingItem, language: Language) -> String {
        language == .spanish
            ? "He recuperado del caché una versión previa de \(closetItem.name) para usarla más adelante desde el chat."
            : "I recovered a cached version of \(closetItem.name) so chat can use it later."
    }

    private func generatedResultMessage(for closetItem: ClothingItem, language: Language) -> String {
        language == .spanish
            ? "He preparado un resultado visual para \(closetItem.name) y ya queda enlazado al caché del armario para una futura experiencia desde el chat."
            : "I prepared a visual result for \(closetItem.name), and it is now linked to the closet cache for a future chat experience."
    }

    private func resolveReferencePlan(for user: User, category: ClothingCategory, language: Language) -> ChatTryOnReferencePlan? {
        let photos = user.profilePhotos

        if category == .accessories {
            guard let primary = photos.faceCloseUp ?? photos.faceProfile else {
                return nil
            }

            let composite = composeReferenceImage(primary: primary, secondary: photos.faceProfile)
            return ChatTryOnReferencePlan(
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

        return ChatTryOnReferencePlan(image: image, descriptor: descriptor)
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
}
