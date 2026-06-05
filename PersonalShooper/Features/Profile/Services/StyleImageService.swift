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

    static let providerDefaultsKey = "image_provider"

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

    /// True when at least one image-capable provider key is available. When false, image
    /// generation/editing can't run, so callers should surface a "configure a key" message instead
    /// of silently returning the source image and pretending the operation succeeded.
    static func hasImageProvider() -> Bool {
        geminiKey() != nil || openAIKey() != nil
    }

    static func cleanStudioReference(from person: UIImage) async throws -> UIImage {
        switch resolvedEngine() {
        case .gemini:
            return try await GeminiTryOnService(apiKey: geminiKey()).cleanStudioImage(from: person)
        case .openai:
            guard let key = openAIKey() else { return person }
            return try await OpenAIImageTryOnService().cleanStudioImage(from: person, apiKey: key)
        }
    }

    static func marketingImage(for garment: UIImage, categoryHint: String) async throws -> UIImage {
        switch resolvedEngine() {
        case .gemini:
            return try await GeminiTryOnService(apiKey: geminiKey()).marketingImage(for: garment, categoryHint: categoryHint)
        case .openai:
            guard let key = openAIKey() else { return garment }
            return try await OpenAIImageTryOnService().marketingImage(for: garment, categoryHint: categoryHint, apiKey: key)
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
