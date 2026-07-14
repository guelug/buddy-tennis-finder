import ImagePlayground
import UIKit

/// Resolves which BYOK provider to use for image generation/editing (clean reference + wardrobe
/// marketing thumbnails) and runs the request against it.
///
/// Coherence rules:
/// - If the user configured only one image-capable provider (Gemini or OpenAI), everything uses it.
/// - If both are configured, an explicit saved choice (`image_provider`) wins; otherwise default.
@MainActor
enum StyleImageService {
    enum Engine: String, CaseIterable { case gemini, openai }
    enum StyleImageError: LocalizedError {
        case noProvider

        var errorDescription: String? {
            "No compatible image processor is available."
        }
    }

    static let providerDefaultsKey = "image_provider"
    static let managedProcessingConsentKey = "managed_image_processing_consent"

    static var hasManagedProcessingConsent: Bool {
        get { UserDefaults.standard.bool(forKey: managedProcessingConsentKey) }
        set { UserDefaults.standard.set(newValue, forKey: managedProcessingConsentKey) }
    }

    static var shouldRequestManagedProcessingConsent: Bool {
        geminiKey() == nil
            && openAIKey() == nil
            && BackendImageService.isConfigured
            && !hasManagedProcessingConsent
    }

    static var isLocalImagePlaygroundAvailable: Bool {
        if #available(iOS 18.4, *) {
            return ImagePlaygroundTryOnService.isAvailable
        }
        return false
    }

    static func geminiKey() -> String? {
        nonEmpty(KeychainHelper.load(for: "gemini_api_key")) ?? nonEmpty(AppSecrets.geminiAPIKey)
    }

    static func openAIKey() -> String? {
        nonEmpty(KeychainHelper.load(for: "openai_api_key")) ?? nonEmpty(AppSecrets.openAIAPIKey)
    }

    /// The provider that will actually be used, honoring the coherence rules above.
    static func resolvedEngine() -> Engine {
        let hasGemini = geminiKey() != nil
        let hasOpenAI = openAIKey() != nil

        if let saved = UserDefaults.standard.string(forKey: providerDefaultsKey),
           let engine = Engine(rawValue: saved) {
            if engine == .gemini, hasGemini { return .gemini }
            if engine == .openai, hasOpenAI { return .openai }
        }

        if hasGemini && !hasOpenAI { return .gemini }
        if hasOpenAI && !hasGemini { return .openai }
        return hasOpenAI ? .openai : .gemini // both or neither
    }

    /// True when the user has more than one image-capable provider, so a picker is meaningful.
    static func hasMultipleEngines() -> Bool {
        geminiKey() != nil && openAIKey() != nil
    }

    /// Engine for marketing thumbnails: prefer Gemini (Nano Banana 2) for speed/cost, regardless of
    /// the user's general image-provider preference. Falls back to OpenAI only if no Gemini key.
    static func marketingEngine() -> Engine {
        geminiKey() != nil ? .gemini : .openai
    }

    /// Local Image Playground is always preferred. Managed processing is available only after
    /// explicit consent.
    static func hasImageProvider() -> Bool {
        geminiKey() != nil
            || openAIKey() != nil
            || (BackendImageService.isConfigured && hasManagedProcessingConsent)
            || isLocalImagePlaygroundAvailable
    }

    static func cleanStudioReference(from person: UIImage) async throws -> UIImage {
        if let key = geminiKey(), resolvedEngine() == .gemini {
            return try await GeminiTryOnService(apiKey: key).cleanStudioImage(from: person)
        }
        if let key = openAIKey(), resolvedEngine() == .openai {
            return try await OpenAIImageTryOnService().cleanStudioImage(from: person, apiKey: key)
        }

        // Managed cloud consent covers garment thumbnails, not silent profile-photo cleanup.
        return person
    }

    static func marketingImage(for garment: UIImage, categoryHint: String) async throws -> UIImage {
        // 1. BYOK first: if the user brought their own image key, honor it (their key, their cost).
        if let key = geminiKey(), marketingEngine() == .gemini {
            return try await GeminiTryOnService(apiKey: key).marketingImage(for: garment, categoryHint: categoryHint)
        }
        if let key = openAIKey(), marketingEngine() == .openai {
            return try await OpenAIImageTryOnService().marketingImage(for: garment, categoryHint: categoryHint, apiKey: key)
        }

        // 2. On-device Apple Image Playground keeps the free path private and local.
        if #available(iOS 18.4, *), ImagePlaygroundTryOnService.isAvailable {
            return try await ImagePlaygroundTryOnService().generateCleanGarmentImage(garment, categoryHint: categoryHint)
        }

        // 3. Managed processing is an explicit fallback for devices without Image Playground.
        if BackendImageService.isConfigured && hasManagedProcessingConsent {
            return try await BackendImageService.optimizeGarment(garment, categoryHint: categoryHint)
        }

        throw StyleImageError.noProvider
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
