import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    private let storeKitManager = StoreKitManager.shared
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var headerPulse = false
    @State private var purchaseFeedbackCounter = 0

    private var isSpanish: Bool {
        appState.preferredLanguage == .spanish
    }

    private var visibleProducts: [Product] {
        storeKitManager.products.filter {
            guard let storeProduct = StoreProduct(rawValue: $0.id) else { return false }
            return storeProduct.visibleInSubscriptionUI
        }
    }

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
            .navigationTitle(isSpanish ? "Hazte premium" : "Go Premium")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.success, trigger: purchaseFeedbackCounter)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSpanish ? "Cerrar" : "Close") {
                        dismiss()
                    }
                    .buttonStyle(.premiumPressable)
                }
            }
            .alert(isSpanish ? "Error" : "Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? (isSpanish ? "Ha ocurrido un error" : "An error occurred"))
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
                .symbolEffect(.pulse, options: .repeating.speed(0.35), value: headerPulse)
                .shadow(color: Theme.Colors.premiumGold.opacity(headerPulse ? 0.42 : 0.18), radius: headerPulse ? 18 : 8, y: 4)
                .onAppear {
                    headerPulse = true
                }

            Text(isSpanish ? "Desbloquea todo tu potencial" : "Unlock Your Full Potential")
                .font(.title2)
                .fontWeight(.bold)

            Text(isSpanish ? "Obtén try-ons limitados y funciones premium" : "Get limited virtual try-ons and premium features")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text(isSpanish ? "Prueba premium gratis de 7 días" : "7-day free premium trial")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Theme.Colors.premiumGold)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.Colors.premiumGold.opacity(0.12))
            .clipShape(Capsule())

            Text(isSpanish ? "*Sujeto a tipo de suscripción" : "*Subject to subscription type")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            FeatureRow(
                icon: "infinity",
                title: isSpanish ? "Try-ons incluidos" : "Try-Ons Included",
                description: isSpanish ? "Genera imágenes de try-on según tu plan (5-200/mes)" : "Generate try-on images based on your plan (5-200/month)",
                badgeText: isSpanish ? "PREMIUM" : "PREMIUM",
                badgeColor: Theme.Colors.premiumGold
            )

            FeatureRow(
                icon: "paintpalette.fill",
                title: isSpanish ? "Análisis personal de color" : "Personal Color Analysis",
                description: isSpanish ? "Análisis completo de tono de piel y subtono" : "Complete skin tone and undertone analysis",
                badgeText: isSpanish ? "PREMIUM" : "PREMIUM",
                badgeColor: Theme.Colors.premiumGold
            )

            FeatureRow(
                icon: "arkit",
                title: isSpanish ? "Encuentra tus prendas en tu habitación" : "Find your garments in your room",
                description: isSpanish ? "Guarda y localiza dónde tienes cada prenda usando AR" : "Save and locate where you keep each garment using AR",
                badgeText: isSpanish ? "PREMIUM" : "PREMIUM",
                badgeColor: Theme.Colors.premiumGold
            )

            FeatureRow(
                icon: "apple.intelligence",
                title: isSpanish ? "Apple Intelligence+" : "Apple Intelligence+",
                description: isSpanish ? "Siri AI, búsqueda visual del armario, Image Playground y armario hasta 100 prendas" : "Siri AI, visual closet search, Image Playground and up to 100 garments",
                badgeText: isSpanish ? "AI+" : "AI+",
                badgeColor: .orange
            )

            FeatureRow(
                icon: "bubble.left.and.bubble.right.fill",
                title: isSpanish ? "Modelos más inteligentes de IA" : "Smarter AI Models",
                description: isSpanish ? "Accede a modelos de IA más avanzados para mejores respuestas" : "Access more advanced AI models for better responses",
                badgeText: isSpanish ? "PREMIUM" : "PREMIUM",
                badgeColor: Theme.Colors.premiumGold
            )

            FeatureRow(
                icon: "brain.head.profile",
                title: isSpanish ? "BYOK: tus propias claves" : "BYOK: your own keys",
                description: isSpanish ? "Conecta OpenAI, Gemini, Grok y más con tus propias API keys" : "Connect OpenAI, Gemini, Grok and more with your own API keys",
                badgeText: "BYOK",
                badgeColor: .green
            )

            FeatureRow(
                icon: "photo.on.rectangle",
                title: isSpanish ? "Armario gratis de 20 prendas" : "20-Garment Free Closet",
                description: isSpanish ? "El plan gratis te deja guardar hasta 20 prendas" : "The free plan lets you save up to 20 garments",
                badgeText: isSpanish ? "GRATIS" : "FREE",
                badgeColor: Theme.Colors.primary
            )

            FeatureRow(
                icon: "cabinet.fill",
                title: isSpanish ? "Armario hasta 100 prendas" : "Closet up to 100 garments",
                description: isSpanish ? "Guarda hasta 100 prendas con cualquier pago único o suscripción" : "Save up to 100 garments with any one-time unlock or subscription",
                badgeText: isSpanish ? "PAGO" : "PAID",
                badgeColor: Theme.Colors.premiumGold
            )
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
    }

    private var pricingSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            if visibleProducts.isEmpty {
                ProgressView()
                    .padding()
                    .transition(.opacity)
            } else {
                ForEach(visibleProducts, id: \.id) { product in
                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            selectedProduct = product
                        }
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

                                if let storeProduct = StoreProduct(rawValue: product.id), storeProduct.isOneTimeUnlock {
                                    Text(isSpanish ? "Pago único" : "One-time purchase")
                                        .font(.caption)
                                        .foregroundStyle(Theme.Colors.premiumGold)
                                } else {
                                    Text(isSpanish ? "Incluye 7 días de prueba gratis" : "Includes a 7-day free trial")
                                        .font(.caption)
                                        .foregroundStyle(Theme.Colors.premiumGold)
                                }
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
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                .stroke(
                                    selectedProduct?.id == product.id ? Theme.Colors.primary.opacity(0.35) : Color.clear,
                                    lineWidth: 1
                                )
                        }
                    }
                    .disabled(isPurchasing)
                    .buttonStyle(.premiumPressable)
                    .transition(.scale(scale: 0.98).combined(with: .opacity))
                }
            }
        }
        .animation(.snappy(duration: 0.25), value: visibleProducts.map(\.id))
        .animation(.snappy(duration: 0.2), value: selectedProduct?.id)
    }

    private var restoreSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                Task { await restorePurchases() }
            } label: {
                Text(isSpanish ? "Restaurar compras" : "Restore Purchases")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.primary)
            }
            .buttonStyle(.premiumPressable)

            Text(isSpanish ? "¿Ya estás suscrito? Restaura aquí tus compras." : "Already subscribed? Restore your purchases here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func purchase(_ product: Product) async {
        isPurchasing = true

        do {
            try await storeKitManager.purchase(product)
            await appState.refreshPremiumStatus()
            await MainActor.run {
                isPurchasing = false
                purchaseFeedbackCounter += 1
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
        await MainActor.run {
            purchaseFeedbackCounter += 1
        }
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
