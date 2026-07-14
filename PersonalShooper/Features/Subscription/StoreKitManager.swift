import Foundation
import StoreKit

struct StoreServerAuthorization: Sendable {
    let appTransactionJWS: String

    func apply(to request: inout URLRequest) {
        request.setValue(appTransactionJWS, forHTTPHeaderField: "X-App-Transaction-JWS")
    }
}

/// Single product policy: every app feature is available without purchases or subscriptions.
enum FreeAccessPolicy {
    static let closetItemLimit = 100
    static let allowsAppleIntelligence = true
    static let allowsBYOK = true
    static let allowsManagedCloud = true
}

/// Legacy values remain decodable so existing local profiles migrate without data loss.
enum SubscriptionTier: String, CaseIterable, Codable {
    case free
    case byokLite = "byok_lite"
    case byok
    case appleIntelligencePlus = "apple_intelligence_plus"
    case premium
    case pro
    case lifetime

    var displayName: String { "Free" }
    var monthlyCredits: Int { Int.max }
    var monthlyImages: Int { Int.max }
    var isUnlimited: Bool { true }
    var hasBYOK: Bool { FreeAccessPolicy.allowsBYOK }
    var hasAppleIntelligenceFeatures: Bool { FreeAccessPolicy.allowsAppleIntelligence }
    var hasTrial: Bool { false }
}

/// StoreKit is used only to obtain Apple's signed AppTransaction JWS for backend authentication.
/// No products are loaded and the app contains no purchase flow.
@Observable
@MainActor
final class StoreKitManager {
    static let shared = StoreKitManager()
    static let byokKeychainKeys = [
        "gemini_api_key", "openai_api_key", "anthropic_api_key",
        "grok_api_key", "kimi_api_key", "openrouter_api_key"
    ]

    var currentTier: SubscriptionTier = .free
    var remainingCredits: Int = Int.max

    private init() {}

    func serverAuthorization() async -> StoreServerAuthorization? {
        do {
            let result = try await AppTransaction.shared
            guard case .verified = result else { return nil }
            return StoreServerAuthorization(appTransactionJWS: result.jwsRepresentation)
        } catch {
            AppLog.storeKit.debug("Store server authorization is unavailable: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    func refreshSubscriptionStatus() async {
        currentTier = .free
        remainingCredits = Int.max
    }

    var hasBYOKPurchase: Bool { FreeAccessPolicy.allowsBYOK }
    var hasAppleIntelligenceFeatures: Bool { FreeAccessPolicy.allowsAppleIntelligence }
    var hasExternalProviderCredits: Bool { FreeAccessPolicy.allowsManagedCloud }
    var hasAnyPaidUnlock: Bool { true }

    var isBYOKConfigured: Bool {
        Self.byokKeychainKeys
        .compactMap { KeychainHelper.load(for: $0)?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .contains { !$0.isEmpty }
    }

    var isBYOKActive: Bool { isBYOKConfigured }
    var hasLifetimePurchase: Bool { false }
    var isSubscribed: Bool { false }
    var isPremium: Bool { false }
    var canTryOn: Bool { true }
    var canUseImages: Bool { true }
}
