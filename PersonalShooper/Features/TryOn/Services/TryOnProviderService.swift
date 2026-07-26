import UIKit
import AuthenticationServices

enum TryOnProvider: String, CaseIterable, Identifiable, Codable {
    case google = "google"
    case playground = "playground"
    case chatgpt = "chatgpt"
    case fal = "fal"

    var id: String { rawValue }

    var displayName: String {
        displayName(language: .english)
    }

    func displayName(language: Language) -> String {
        switch self {
        case .google: return "Gemini · Nano Banana 2"
        case .playground: return language == .spanish ? "Apple Image Playground" : "Apple Image Playground"
        case .chatgpt: return "OpenAI · GPT Image 2"
        case .fal: return "Fal.ai · Virtual Try-On"
        }
    }

    var subtitle: String {
        subtitle(language: .english)
    }

    func subtitle(language: Language) -> String {
        switch self {
        case .google: return language == .spanish ? "Nano Banana 2, gratis con uso razonable" : "Nano Banana 2, free with fair-use limits"
        case .playground: return language == .spanish ? "Apple Image Playground gratis en el dispositivo" : "Free Apple Image Playground on-device"
        case .chatgpt: return language == .spanish ? "GPT Image 2 con tu propia clave" : "GPT Image 2 with your own key"
        case .fal: return language == .spanish ? "Probador especializado con tu clave de Fal" : "Specialized try-on with your Fal key"
        }
    }

    var iconName: String {
        switch self {
        case .google: return "g.circle.fill"
        case .playground: return "apple.logo"
        case .chatgpt: return "brain.head.profile"
        case .fal: return "bolt.horizontal.circle.fill"
        }
    }

    var isFree: Bool {
        switch self {
        case .google, .playground: return true
        case .chatgpt, .fal: return false
        }
    }

    var requiresUserAPIKey: Bool {
        self == .chatgpt || self == .fal
    }

    var isStylized: Bool {
        switch self {
        case .google: return false
        case .playground: return true
        case .chatgpt, .fal: return false
        }
    }
}

@Observable
@MainActor
final class TryOnProviderService {
    var currentProvider: TryOnProvider = .google
    var isAuthenticated: Bool = false
    var authenticationError: String?

    private var chatGPTUserId: String?

    init() {
        // Load saved provider preference
        if let savedProvider = UserDefaults.standard.string(forKey: "tryon_provider"),
           let provider = TryOnProvider(rawValue: savedProvider) {
            currentProvider = provider
        }

        refreshAuthenticationState()
    }

    func setProvider(_ provider: TryOnProvider) {
        currentProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: "tryon_provider")

        refreshAuthenticationState()
    }

    func generateTryOn(clothingImage: UIImage, userImage: UIImage, garmentCategory: ClothingCategory? = nil) async throws -> UIImage {
        switch currentProvider {
        case .google:
            return try await generateWithGoogle(clothing: clothingImage, user: userImage, garmentCategory: garmentCategory)
        case .playground:
            return try await generateWithPlayground(clothing: clothingImage, user: userImage, garmentCategory: garmentCategory)
        case .chatgpt:
            return try await generateWithChatGPT(clothing: clothingImage, user: userImage)
        case .fal:
            return try await generateWithFal(clothing: clothingImage, user: userImage)
        }
    }

    // MARK: - Google Gemini

    private func generateWithGoogle(clothing: UIImage, user: UIImage, garmentCategory: ClothingCategory?) async throws -> UIImage {
        if let key = StyleImageService.geminiKey() {
            return try await GeminiTryOnService(apiKey: key).generateTryOnImage(
                clothingImage: clothing,
                userImage: user,
                editHints: nil,
                garmentInstruction: garmentCategory?.tryOnReplacementInstruction
            )
        }

        return try await TryOnService.shared.generate(
            clothingImage: clothing,
            personImage: user
        )
    }

    // MARK: - Local Preview (Image Playground)

    private func generateWithPlayground(clothing: UIImage, user: UIImage, garmentCategory: ClothingCategory?) async throws -> UIImage {
        if #available(iOS 18.4, *), ImagePlaygroundTryOnService.isAvailable {
            do {
                let service = try await ImagePlaygroundTryOnService()
                let prompt = garmentCategory?.imagePlaygroundPrompt ?? "fashion try-on preview"
                return try await service.generateOutfitInspiration(
                    clothingImage: clothing,
                    userImage: user,
                    prompt: prompt
                )
            } catch {
                // Fall back to the placeholder preview so the UX never breaks.
                return createCartoonStyleImage(clothing: clothing, user: user)
            }
        }

        return createCartoonStyleImage(clothing: clothing, user: user)
    }

    private func createCartoonStyleImage(clothing: UIImage, user: UIImage) -> UIImage {
        // Create a cartoon-styled version using CIFilter
        let size = CGSize(width: 512, height: 512)

        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)

        guard let context = UIGraphicsGetCurrentContext() else {
            return user
        }

        // Fill background
        context.setFillColor(UIColor.systemBackground.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        // Draw user silhouette (scaled)
        let userAspect = user.size.width / user.size.height
        var userRect: CGRect
        if userAspect > 1 {
            let height = size.height * 0.7
            let width = height * userAspect
            userRect = CGRect(x: (size.width - width) / 2, y: size.height - height, width: width, height: height)
        } else {
            let width = size.width * 0.7
            let height = width / userAspect
            userRect = CGRect(x: (size.width - width) / 2, y: size.height - height, width: width, height: height)
        }

        // Apply cartoon effect - draw with slight stylization
        context.saveGState()
        context.addEllipse(in: userRect)
        context.clip()
        user.draw(in: userRect)
        context.restoreGState()

        // Add cartoon outline
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(4)
        context.strokeEllipse(in: userRect.insetBy(dx: -2, dy: -2))

        // Draw clothing overlay (simplified)
        let clothingRect = CGRect(x: size.width * 0.2, y: 50, width: size.width * 0.6, height: size.height * 0.5)
        clothing.draw(in: clothingRect)

        // Add cartoon border to clothing
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(3)
        context.strokeEllipse(in: clothingRect)

        let result = UIGraphicsGetImageFromCurrentImageContext() ?? user
        UIGraphicsEndImageContext()

        return result
    }

    // MARK: - BYOK OpenAI Key

    func authenticateWithChatGPT() async throws {
        throw TryOnProviderError.authenticationRequired
    }

    func checkChatGPTAuthentication() async -> Bool {
        // Check if user has a valid BYOK token stored
        let hasToken = AppSecrets.openAIAPIKey != nil
        isAuthenticated = hasToken
        return hasToken
    }

    private func generateWithChatGPT(clothing: UIImage, user: UIImage) async throws -> UIImage {
        guard let apiKey = AppSecrets.openAIAPIKey,
              !apiKey.isEmpty else {
            isAuthenticated = false
            throw TryOnProviderError.authenticationRequired
        }

        isAuthenticated = true

        let service = OpenAIImageTryOnService()
        return try await service.generateTryOnImage(
            clothingImage: clothing,
            userImage: user,
            apiKey: apiKey
        )
    }

    // MARK: - BYOK Fal.ai

    private func generateWithFal(clothing: UIImage, user: UIImage) async throws -> UIImage {
        guard let apiKey = AppSecrets.falAPIKey,
              !apiKey.isEmpty else {
            isAuthenticated = false
            throw TryOnProviderError.authenticationRequired
        }

        isAuthenticated = true
        return try await FalTryOnService().generateTryOnImage(
            clothingImage: clothing,
            userImage: user,
            apiKey: apiKey
        )
    }

    private func refreshAuthenticationState() {
        switch currentProvider {
        case .chatgpt:
            isAuthenticated = AppSecrets.openAIAPIKey != nil
        case .fal:
            isAuthenticated = AppSecrets.falAPIKey != nil
        case .google, .playground:
            isAuthenticated = false
            chatGPTUserId = nil
        }
    }
}

enum TryOnProviderError: Error, LocalizedError {
    case authenticationRequired
    case notYetImplemented
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Provider API key not available"
        case .notYetImplemented:
            return "This provider is not available"
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        }
    }
}
