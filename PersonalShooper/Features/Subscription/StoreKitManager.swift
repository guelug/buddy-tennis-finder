import Foundation
import StoreKit

struct StoreServerAuthorization: Sendable {
    let appTransactionJWS: String
    let entitlementJWS: String?

    func apply(to request: inout URLRequest) {
        request.setValue(appTransactionJWS, forHTTPHeaderField: "X-App-Transaction-JWS")
        if let entitlementJWS {
            request.setValue(entitlementJWS, forHTTPHeaderField: "X-Entitlement-JWS")
        }
    }
}

// MARK: - Subscription Tier & Product IDs

enum SubscriptionTier: String, CaseIterable, Codable {
    case free = "free"
    case byokLite = "byok_lite"             // legacy, kept for backward compatibility
    case byok = "byok"                       // one-time unlock: bring your own key
    case appleIntelligencePlus = "apple_intelligence_plus" // one-time unlock: Siri AI, tools, Vision, Playground
    case premium = "premium"
    case pro = "pro"
    case lifetime = "lifetime"               // legacy, treated as Apple Intelligence+ equivalent

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .byokLite: return "BYOK Lite"
        case .byok: return "BYOK"
        case .appleIntelligencePlus: return "Apple Intelligence+"
        case .premium: return "Premium"
        case .pro: return "Pro"
        case .lifetime: return "Lifetime"
        }
    }

    var monthlyCredits: Int {
        switch self {
        case .free: return 5
        case .byokLite, .byok: return 5  // Uses BYOK for unlimited, base same as free
        case .appleIntelligencePlus: return 5 // on-device only; no external credits
        case .premium: return 50
        case .pro: return 200
        case .lifetime: return Int.max
        }
    }

    var monthlyImages: Int {
        switch self {
        case .free, .byokLite, .byok, .appleIntelligencePlus: return 0
        case .premium: return 20
        case .pro: return 50
        case .lifetime: return 100
        }
    }

    var isUnlimited: Bool {
        self == .lifetime
    }

    var hasBYOK: Bool {
        switch self {
        case .byokLite, .byok, .premium, .pro, .lifetime: return true
        case .free, .appleIntelligencePlus: return false
        }
    }

    /// Apple Intelligence+ feature set (Siri AI, on-device tools, Vision, Image Playground).
    var hasAppleIntelligenceFeatures: Bool {
        switch self {
        case .appleIntelligencePlus, .premium, .pro, .lifetime: return true
        case .free, .byokLite, .byok: return false
        }
    }

    var hasTrial: Bool {
        self == .premium || self == .pro
    }
}

enum StoreProduct: String, CaseIterable {
    case free = "com.personalshooper.free"
    case byokLiteMonthly = "com.personalshooper.byoklite.monthly"   // legacy
    case appleIntelligencePlus = "com.personalshooper.appleintelligenceplus" // one-time
    case byokUnlock = "com.personalshooper.byok"                     // one-time
    case premiumMonthly = "com.personalshooper.premium.monthly"
    case proMonthly = "com.personalshooper.pro.monthly"
    case lifetime = "com.personalshooper.lifetime"                  // legacy
    case creditsPack10 = "com.personalshooper.credits.pack10"
    case creditsPack50 = "com.personalshooper.credits.pack50"

    var productID: String { rawValue }

    /// True for one-time (non-consumable) unlocks vs auto-renewing subscriptions.
    var isOneTimeUnlock: Bool {
        switch self {
        case .appleIntelligencePlus, .byokUnlock, .lifetime: return true
        default: return false
        }
    }

    var tier: SubscriptionTier? {
        switch self {
        case .free: return .free
        case .byokLiteMonthly: return .byokLite
        case .appleIntelligencePlus: return .appleIntelligencePlus
        case .byokUnlock: return .byok
        case .premiumMonthly: return .premium
        case .proMonthly: return .pro
        case .lifetime: return .lifetime
        case .creditsPack10, .creditsPack50: return nil
        }
    }

    var visibleInSubscriptionUI: Bool {
        switch self {
        case .free, .creditsPack10, .creditsPack50:
            return false
        case .byokLiteMonthly, .appleIntelligencePlus, .byokUnlock, .premiumMonthly, .proMonthly, .lifetime:
            return true
        }
    }
}

// MARK: - StoreKit Manager

@Observable
@MainActor
final class StoreKitManager: ObservableLike {
    static let shared = StoreKitManager()

    // MARK: - Published Properties
    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var currentTier: SubscriptionTier = .free
    var remainingCredits: Int = 5
    var totalUsedThisMonth: Int = 0
    var isLoading: Bool = false

    // MARK: - Private State
    private let creditsKey = "PersonalShooper.UsedCredits"
    private let resetDateKey = "PersonalShooper.CreditsResetDate"
    private let userDefaults = UserDefaults.standard
    private var appStoreEnvironment: AppStore.Environment?

    // MARK: - Initialization

    private init() {
        startTransactionListener()
        Task {
            await loadProducts()
            await getCurrentTier()
            await loadLocalCredits()
        }
    }

    // MARK: - Transaction Listener

    private func startTransactionListener() {
        Task {
            for await result in Transaction.updates {
                await handleTransaction(result)
            }
        }
    }

    private func handleTransaction(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(result)
            await updatePurchasedProducts()
            await getCurrentTier()
            await transaction.finish()
        } catch {
            AppLog.storeKit.error("Transaction verification failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Product Loading

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        let productIDs = StoreProduct.allCases.map(\.productID)

        do {
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            AppLog.storeKit.error("Failed to load products: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Purchase Flow

    func purchase(_ product: Product) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchasedProducts()
                await getCurrentTier()
                await transaction.finish()

            case .userCancelled:
                throw StoreKitError.userCancelled

            case .pending:
                throw StoreKitError.pending

            @unknown default:
                throw StoreKitError.unknown
            }
        } catch {
            throw error
        }
    }

    // MARK: - Restore & Verification

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        await updatePurchasedProducts()
        await getCurrentTier()
    }

    func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchased.insert(transaction.productID)
            }
        }

        purchasedProductIDs = purchased
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Current Tier

    func getCurrentTier() async {
        await refreshAppStoreEnvironment()
        var highestTier: SubscriptionTier = .free

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if transaction.revocationDate == nil {
                if let storeProduct = StoreProduct(rawValue: transaction.productID),
                   let tier = storeProduct.tier {
                    if tier.rank > highestTier.rank {
                        highestTier = tier
                    }
                }
            }
        }

        currentTier = highestTier
        await updateRemainingCredits()
    }

    private func refreshAppStoreEnvironment() async {
        do {
            let result = try await AppTransaction.shared
            appStoreEnvironment = try checkVerified(result).environment
        } catch {
            appStoreEnvironment = nil
            AppLog.storeKit.debug("App transaction environment is unavailable: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Credits Management

    func getRemainingCredits() async -> Int {
        await updateRemainingCredits()
        return remainingCredits
    }

    func consumeCredit() async -> Bool {
        await updateRemainingCredits()

        if remainingCredits <= 0 {
            return false
        }

        totalUsedThisMonth += 1
        remainingCredits -= 1
        await saveLocalCredits()
        return true
    }

    func addCredits(_ amount: Int) async {
        remainingCredits += amount
        await saveLocalCredits()
    }

    private func updateRemainingCredits() async {
        await checkCreditsReset()
        let maxCredits = creditsForTier(currentTier)
        remainingCredits = maxCredits - totalUsedThisMonth

        if isBYOKActive {
            remainingCredits = Int.max
        }
    }

    private func checkCreditsReset() async {
        let calendar = Calendar.current
        let now = Date()

        if let resetDate = userDefaults.object(forKey: resetDateKey) as? Date {
            if !calendar.isDate(resetDate, equalTo: now, toGranularity: .month) {
                // New month - reset credits
                totalUsedThisMonth = 0
                userDefaults.set(now, forKey: resetDateKey)
                await saveLocalCredits()
            }
        } else {
            userDefaults.set(now, forKey: resetDateKey)
        }
    }

    private func loadLocalCredits() async {
        totalUsedThisMonth = userDefaults.integer(forKey: creditsKey)
        await updateRemainingCredits()
    }

    private func saveLocalCredits() async {
        userDefaults.set(totalUsedThisMonth, forKey: creditsKey)
    }

    // MARK: - Server Authorization

    /// Returns only StoreKit values that passed Apple's on-device verification. The backend
    /// verifies both signatures again and derives identity and tier from Apple.
    func serverAuthorization() async -> StoreServerAuthorization? {
        do {
            let appResult = try await AppTransaction.shared
            guard case .verified = appResult else { return nil }

            var selectedEntitlement: (priority: Int, jws: String)?
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result,
                      transaction.revocationDate == nil,
                      transaction.expirationDate.map({ $0 > Date() }) ?? true else {
                    continue
                }

                let priority = StoreProduct(rawValue: transaction.productID)?.tier?.rank ?? 0
                if selectedEntitlement == nil || priority > selectedEntitlement!.priority {
                    selectedEntitlement = (priority, result.jwsRepresentation)
                }
            }

            return StoreServerAuthorization(
                appTransactionJWS: appResult.jwsRepresentation,
                entitlementJWS: selectedEntitlement?.jws
            )
        } catch {
            AppLog.storeKit.debug("Store server authorization is unavailable: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    // MARK: - Refresh Status

    func refreshSubscriptionStatus() async {
        isLoading = true
        defer { isLoading = false }

        await updatePurchasedProducts()
        await getCurrentTier()
        await loadLocalCredits()
    }

    // MARK: - Helpers

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    func creditsForTier(_ tier: SubscriptionTier) -> Int {
        tier.monthlyCredits
    }

    /// Product IDs that grant the bring-your-own-key entitlement.
    private var byokEntitlementIDs: Set<String> {
        [StoreProduct.byokUnlock, .byokLiteMonthly, .premiumMonthly, .proMonthly, .lifetime].map(\.productID).reduce(into: Set<String>()) { $0.insert($1) }
    }

    /// Product IDs that grant the Apple Intelligence+ feature set.
    private var appleIntelligenceEntitlementIDs: Set<String> {
        [StoreProduct.appleIntelligencePlus, .premiumMonthly, .proMonthly, .lifetime].map(\.productID).reduce(into: Set<String>()) { $0.insert($1) }
    }

    var hasBYOKPurchase: Bool {
        // Always enable BYOK for TestFlight and Debug builds
        #if DEBUG
        return true
        #else
        if isTestFlightBuild {
            return true
        }
        return !purchasedProductIDs.isDisjoint(with: byokEntitlementIDs) || AppSecrets.internalBYOKTestingEnabled
        #endif
    }

    /// True when the user owns any unlock that grants the Apple Intelligence+ feature set
    /// (Siri AI, on-device tools, Vision, Image Playground). Derived from the purchase set so
    /// orthogonal one-time unlocks (AI+ and BYOK) both apply.
    var hasAppleIntelligenceFeatures: Bool {
        #if DEBUG
        return true
        #else
        if isTestFlightBuild {
            return true
        }
        return !purchasedProductIDs.isDisjoint(with: appleIntelligenceEntitlementIDs)
        #endif
    }

    /// External (cloud) generation credits come only with the paid subscriptions.
    var hasExternalProviderCredits: Bool {
        currentTier == .premium || currentTier == .pro || currentTier == .lifetime
    }

    /// True when the user has any paid unlock or subscription (drives the larger closet limit).
    var hasAnyPaidUnlock: Bool {
        hasBYOKPurchase || hasAppleIntelligenceFeatures || isPremium
    }

    private var isTestFlightBuild: Bool {
        appStoreEnvironment == .sandbox
    }

    var isBYOKConfigured: Bool {
        let keys = [
            KeychainHelper.load(for: "gemini_api_key"),
            KeychainHelper.load(for: "openai_api_key"),
            KeychainHelper.load(for: "anthropic_api_key"),
            KeychainHelper.load(for: "kimi_api_key"),
            KeychainHelper.load(for: "openrouter_api_key")
        ]
        return keys
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .contains { !$0.isEmpty }
    }

    var isBYOKActive: Bool {
        hasBYOKPurchase && isBYOKConfigured
    }

    var hasLifetimePurchase: Bool {
        purchasedProductIDs.contains(StoreProduct.lifetime.productID)
    }

    var isSubscribed: Bool {
        currentTier == .premium || currentTier == .pro || currentTier == .byokLite
    }

    var isPremium: Bool {
        currentTier == .premium || currentTier == .pro || currentTier == .lifetime
    }

    var canTryOn: Bool {
        remainingCredits > 0 || isBYOKActive || currentTier.monthlyImages > 0
    }

    var canUseImages: Bool {
        currentTier.monthlyImages > 0
    }
}

// MARK: - Supporting Types

extension SubscriptionTier {
    var rank: Int {
        switch self {
        case .free: return 0
        case .byokLite: return 1
        case .byok: return 2
        case .appleIntelligencePlus: return 3
        case .premium: return 4
        case .pro: return 5
        case .lifetime: return 6
        }
    }
}

// MARK: - Protocol for Testing

protocol ObservableLike {}

// MARK: - Error Types

enum StoreKitError: Error, LocalizedError, Sendable {
    case productLoadingFailed
    case verificationFailed
    case userCancelled
    case pending
    case unknown
    case insufficientCredits

    var errorDescription: String? {
        switch self {
        case .productLoadingFailed:
            return "Failed to load subscription products"
        case .verificationFailed:
            return "Transaction verification failed"
        case .userCancelled:
            return "Purchase was cancelled"
        case .pending:
            return "Purchase is pending approval"
        case .unknown:
            return "An unknown error occurred"
        case .insufficientCredits:
            return "Insufficient credits for this action"
        }
    }
}
