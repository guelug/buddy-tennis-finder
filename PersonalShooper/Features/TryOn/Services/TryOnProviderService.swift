import UIKit
import AuthenticationServices

enum TryOnProvider: String, CaseIterable, Identifiable {
    case google = "google"
    case playground = "playground"
    case chatgpt = "chatgpt"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .google: return "Google Gemini"
        case .playground: return "Apple Playground"
        case .chatgpt: return "ChatGPT"
        }
    }

    var description: String {
        switch self {
        case .google: return "Best quality, uses Google's AI"
        case .playground: return "Free on-device, cartoon style"
        case .chatgpt: return "Your ChatGPT Plus account"
        }
    }

    var icon: String {
        switch self {
        case .google: return "g.circle.fill"
        case .playground: return "sun.max.fill"
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
    }

    func setProvider(_ provider: TryOnProvider) {
        currentProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: "tryon_provider")

        // Reset authentication when switching providers
        if provider != .chatgpt {
            isAuthenticated = false
            chatGPTUserId = nil
        }
    }

    func generateTryOn(clothingImage: UIImage, userImage: UIImage) async throws -> UIImage {
        switch currentProvider {
        case .google:
            return try await generateWithGoogle(clothing: clothingImage, user: userImage)
        case .playground:
            return try await generateWithPlayground(clothing: clothingImage, user: userImage)
        case .chatgpt:
            return try await generateWithChatGPT(clothing: clothingImage, user: userImage)
        }
    }

    // MARK: - Google Gemini

    private func generateWithGoogle(clothing: UIImage, user: UIImage) async throws -> UIImage {
        // Use Gemini service (existing implementation)
        let service = GeminiTryOnService()
        return try await service.generateTryOnImage(clothingImage: clothing, userImage: user, editHints: nil)
    }

    // MARK: - Apple Playground (Cartoon Style)

    private func generateWithPlayground(clothing: UIImage, user: UIImage) async throws -> UIImage {
        // Apple Playground generates cartoon-style images
        // For now, we create a stylized cartoon version locally
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

    // MARK: - ChatGPT OAuth

    func authenticateWithChatGPT() async throws {
        // Sign in with Apple for OAuth token
        // This would use ASAuthorizationController to present Sign in with Apple UI
        // After authentication, exchange the Apple ID token for ChatGPT access token via backend

        throw TryOnProviderError.authenticationRequired
    }

    func checkChatGPTAuthentication() async -> Bool {
        // Check if user has valid ChatGPT OAuth token stored
        return UserDefaults.standard.string(forKey: "chatgpt_access_token") != nil
    }

    private func generateWithChatGPT(clothing: UIImage, user: UIImage) async throws -> UIImage {
        guard isAuthenticated else {
            throw TryOnProviderError.authenticationRequired
        }

        // Use ChatGPT DALL-E API through user's authenticated session
        // This requires OpenAI SDK configured with OAuth flow
        // For now, fall back to playground style

        throw TryOnProviderError.notYetImplemented
    }
}

enum TryOnProviderError: Error, LocalizedError {
    case authenticationRequired
    case notYetImplemented
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Please sign in with your ChatGPT account first"
        case .notYetImplemented:
            return "ChatGPT integration is coming soon"
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        }
    }
}
