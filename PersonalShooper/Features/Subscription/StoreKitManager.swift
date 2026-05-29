import Foundation
import StoreKit

// MARK: - Subscription Tier & Product IDs

enum SubscriptionTier: String, CaseIterable, Codable {
    case free = "free"
    case byokLite = "byok_lite"
    case premium = "premium"
    case pro = "pro"
    case lifetime = "lifetime"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .byokLite: return "BYOK Lite"
        case .premium: return "Premium"
        case .pro: return "Pro"
        case .lifetime: return "Lifetime"
        }
    }

    var monthlyCredits: Int {
        switch self {
        case .free: return 5
        case .byokLite: return 5  // Uses BYOK for unlimited, but has same base as free
        case .premium: return 50
        case .pro: return 200
        case .lifetime: return Int.max
        }
    }

    var monthlyImages: Int {
        switch self {
        case .free: return 0
        case .byokLite: return 0
        case .premium: return 20
        case .pro: return 50
        case .lifetime: return 100
        }
    }

    var isUnlimited: Bool {
        self == .lifetime
    }

    var hasBYOK: Bool {
        self == .byokLite || self == .pro || self == .lifetime
    }

    var hasTrial: Bool {
        self == .premium || self == .pro
    }
}

enum StoreProduct: String, CaseIterable {
    case free = "com.personalshooper.free"
    case byokLiteMonthly = "com.personalshooper.byoklite.monthly"
    case premiumMonthly = "com.personalshooper.premium.monthly"
    case proMonthly = "com.personalshooper.pro.monthly"
    case lifetime = "com.personalshooper.lifetime"
    case creditsPack10 = "com.personalshooper.credits.pack10"
    case creditsPack50 = "com.personalshooper.credits.pack50"

    var productID: String { rawValue }

    var tier: SubscriptionTier? {
        switch self {
        case .free: return .free
        case .byokLiteMonthly: return .byokLite
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
        case .byokLiteMonthly, .premiumMonthly, .proMonthly, .lifetime:
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
            print("Transaction verification failed: \(error)")
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
            print("Failed to load products: \(error)")
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

    // MARK: - CloudKit Sync

    func syncCreditsWithCloudKit() async {
        // Placeholder for CloudKit sync
        // In production, this would use CKContainer and sync usage data
        // For now, credits are stored locally via UserDefaults
        await updateRemainingCredits()
    }

    // MARK: - Receipt

    func fetchAppStoreReceipt() -> Data? {
        guard #unavailable(iOS 18.0) else {
            return nil
        }

        // iOS 7+ receipt location
        let receiptURL = Bundle.main.appStoreReceiptURL

        guard let url = receiptURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        return try? Data(contentsOf: url)
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

    var hasBYOKPurchase: Bool {
        purchasedProductIDs.contains(StoreProduct.lifetime.productID) || AppSecrets.internalBYOKTestingEnabled
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
        (currentTier.hasBYOK || hasLifetimePurchase) && isBYOKConfigured
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
        case .premium: return 2
        case .pro: return 3
        case .lifetime: return 4
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
