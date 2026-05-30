import UIKit
import AuthenticationServices

enum TryOnProvider: String, CaseIterable, Identifiable, Codable {
    case google = "google"
    case playground = "playground"
    case chatgpt = "chatgpt"

    var id: String { rawValue }

    var displayName: String {
        displayName(language: .english)
    }

    func displayName(language: Language) -> String {
        switch self {
        case .google: return "Google Gemini"
        case .playground: return language == .spanish ? "Vista local" : "Local Preview"
        case .chatgpt: return language == .spanish ? "Tu clave de OpenAI" : "BYOK"
        }
    }

    var subtitle: String {
        subtitle(language: .english)
    }

    func subtitle(language: Language) -> String {
        switch self {
        case .google: return language == .spanish ? "Resultados más precisos" : "Most accurate results"
        case .playground: return language == .spanish ? "Gratis, composición local" : "Free local composition"
        case .chatgpt: return language == .spanish ? "Usa tu propia clave de OpenAI" : "Bring your own OpenAI key"
        }
    }

    var iconName: String {
        switch self {
        case .google: return "g.circle.fill"
        case .playground: return "apple.logo"
        case .chatgpt: return "brain.head.profile"
        }
    }

    var isFree: Bool {
        switch self {
        case .google: return false
        case .playground: return true
        case .chatgpt: return false
        }
    }

    var requiresPremium: Bool {
        switch self {
        case .google: return true
        case .playground: return false
        case .chatgpt: return true
        }
    }

    var isCartoonStyle: Bool {
        switch self {
        case .google: return false
        case .playground: return true
        case .chatgpt: return false
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

        isAuthenticated = UserDefaults.standard.string(forKey: "chatgpt_access_token") != nil || AppSecrets.openAIAPIKey != nil
    }

    func setProvider(_ provider: TryOnProvider) {
        currentProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: "tryon_provider")

        if provider == .chatgpt {
            isAuthenticated = UserDefaults.standard.string(forKey: "chatgpt_access_token") != nil || AppSecrets.openAIAPIKey != nil
        } else {
            isAuthenticated = false
            chatGPTUserId = nil
        }
    }

    func generateTryOn(clothingImage: UIImage, userImage: UIImage, garmentCategory: ClothingCategory? = nil) async throws -> UIImage {
        switch currentProvider {
        case .google:
            return try await generateWithGoogle(clothing: clothingImage, user: userImage, garmentCategory: garmentCategory)
        case .playground:
            return try await generateWithPlayground(clothing: clothingImage, user: userImage)
        case .chatgpt:
            return try await generateWithChatGPT(clothing: clothingImage, user: userImage)
        }
    }

    // MARK: - Google Gemini

    private func generateWithGoogle(clothing: UIImage, user: UIImage, garmentCategory: ClothingCategory?) async throws -> UIImage {
        // Use Gemini service (existing implementation)
        let service = GeminiTryOnService()
        return try await service.generateTryOnImage(
            clothingImage: clothing,
            userImage: user,
            editHints: nil,
            garmentInstruction: garmentCategory?.tryOnReplacementInstruction
        )
    }

    // MARK: - Local Preview

    private func generateWithPlayground(clothing: UIImage, user: UIImage) async throws -> UIImage {
        let playgroundImage = createCartoonStyleImage(clothing: clothing, user: user)
        return playgroundImage
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
        let hasToken = UserDefaults.standard.string(forKey: "chatgpt_access_token") != nil || AppSecrets.openAIAPIKey != nil
        isAuthenticated = hasToken
        return hasToken
    }

    private func generateWithChatGPT(clothing: UIImage, user: UIImage) async throws -> UIImage {
        guard let apiKey = UserDefaults.standard.string(forKey: "chatgpt_access_token") ?? AppSecrets.openAIAPIKey,
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
}

enum TryOnProviderError: Error, LocalizedError {
    case authenticationRequired
    case notYetImplemented
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "OpenAI key not available"
        case .notYetImplemented:
            return "This provider is not available"
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        }
    }
}
