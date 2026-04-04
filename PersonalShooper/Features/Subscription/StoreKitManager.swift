import Foundation
import StoreKit

@Observable
@MainActor
final class StoreKitManager {

    var products: [Product] = []
    var purchaseState: PurchaseState = .idle
    private(set) var purchasedProductIDs: Set<String> = []

    var isPremium: Bool {
        !purchasedProductIDs.isEmpty
    }

    init() {
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    // MARK: - Product Loading

    func loadProducts() async {
        let productIDs = [
            ProductID.premiumMonthly,
            ProductID.premiumYearly
        ]

        do {
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase Flow

    func purchase(_ product: Product) async throws -> Transaction {
        purchaseState = .purchasing

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchasedProducts()
                purchaseState = .idle
                return transaction

            case .userCancelled:
                purchaseState = .idle
                throw StoreKitError.userCancelled

            case .pending:
                purchaseState = .idle
                throw StoreKitError.pending

            @unknown default:
                purchaseState = .idle
                throw StoreKitError.unknown
            }
        } catch {
            purchaseState = .idle
            throw error
        }
    }

    // MARK: - Restore & Verification

    func restorePurchases() async {
        await updatePurchasedProducts()
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

    // MARK: - Helpers

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }
}

// MARK: - Supporting Types

enum ProductID {
    static let premiumMonthly = "com.personalshooper.premium.monthly"
    static let premiumYearly = "com.personalshooper.premium.yearly"
}

enum PurchaseState: Sendable {
    case idle
    case purchasing
    case purchased
    case failed(String)
}

enum StoreKitError: Error, LocalizedError, Sendable {
    case productLoadingFailed
    case verificationFailed
    case userCancelled
    case pending
    case unknown

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
        }
    }
}
