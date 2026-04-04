import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var storeKitManager = StoreKitManager()
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // Header
                    headerSection

                    // Features comparison
                    featuresSection

                    // Pricing
                    pricingSection

                    // Restore
                    restoreSection
                }
                .padding(Theme.Spacing.screenPadding)
            }
            .background(Theme.Colors.groupedBackground)
            .navigationTitle("Go Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
            .task {
                await appState.refreshPremiumStatus()
                await storeKitManager.loadProducts()
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundStyle(Theme.Colors.premiumGold)

            Text("Unlock Your Full Potential")
                .font(.title2)
                .fontWeight(.bold)

            Text("Get unlimited virtual try-ons and premium features")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text("7-day free premium trial")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Theme.Colors.premiumGold)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.Colors.premiumGold.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            FeatureRow(
                icon: "infinity",
                title: "Unlimited Try-Ons",
                description: "Generate as many virtual try-on images as you want",
                badgeText: "PREMIUM",
                badgeColor: Theme.Colors.premiumGold
            )

            FeatureRow(
                icon: "paintpalette.fill",
                title: "Personal Color Analysis",
                description: "Complete skin tone and undertone analysis",
                badgeText: "PREMIUM",
                badgeColor: Theme.Colors.premiumGold
            )

            FeatureRow(
                icon: "arkit",
                title: "AR Wardrobe Preview",
                description: "See clothes in your space with AR",
                badgeText: "PREMIUM",
                badgeColor: Theme.Colors.premiumGold
            )

            FeatureRow(
                icon: "bubble.left.and.bubble.right.fill",
                title: "Priority AI Responses",
                description: "Get faster responses from your AI stylist",
                badgeText: "PREMIUM",
                badgeColor: Theme.Colors.premiumGold
            )

            FeatureRow(
                icon: "photo.on.rectangle",
                title: "10-Garment Free Closet",
                description: "The free plan lets you save up to 10 garments",
                badgeText: "FREE",
                badgeColor: Theme.Colors.primary
            )

            FeatureRow(
                icon: "cabinet.fill",
                title: "Unlimited Premium Closet",
                description: "Save as many garments as you want, depending on local and iCloud space",
                badgeText: "PREMIUM",
                badgeColor: Theme.Colors.premiumGold
            )
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
    }

    private var pricingSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            if storeKitManager.products.isEmpty {
                ProgressView()
                    .padding()
            } else {
                ForEach(storeKitManager.products, id: \.id) { product in
                    Button {
                        selectedProduct = product
                        Task {
                            await purchase(product)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(product.displayName)
                                    .font(.headline)

                                Text(product.displayPrice)
                                    .font(.title3)
                                    .fontWeight(.bold)

                                Text("Includes a 7-day free trial")
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.premiumGold)
                            }

                            Spacer()

                            if isPurchasing && selectedProduct?.id == product.id {
                                ProgressView()
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .background(
                            selectedProduct?.id == product.id
                                ? Theme.Colors.primary.opacity(0.1)
                                : Theme.Colors.cardBackground
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                    }
                    .disabled(isPurchasing)
                }
            }
        }
    }

    private var restoreSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                Task { await restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.primary)
            }

            Text("Already subscribed? Restore your purchases here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func purchase(_ product: Product) async {
        isPurchasing = true

        do {
            _ = try await storeKitManager.purchase(product)
            await MainActor.run {
                isPurchasing = false
                appState.isPremium = true
                dismiss()
            }
        } catch {
            await MainActor.run {
                isPurchasing = false
                if case StoreKitError.userCancelled = error {
                    // User cancelled, don't show error
                } else {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func restorePurchases() async {
        await storeKitManager.restorePurchases()
        await appState.refreshPremiumStatus()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let badgeText: String
    let badgeColor: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(badgeColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(badgeText)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor)
                        .clipShape(Capsule())
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
