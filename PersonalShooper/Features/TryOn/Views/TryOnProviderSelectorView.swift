import SwiftUI

struct TryOnProviderSelectorView: View {
    @Environment(AppState.self) private var appState
    @Binding var selectedProvider: TryOnProvider
    @Environment(\.dismiss) private var dismiss

    private var lang: Language {
        appState.preferredLanguage
    }

    private var availableProviders: [TryOnProvider] {
        TryOnProvider.allCases.filter { appState.isTryOnProviderAvailable($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(availableProviders) { provider in
                        Button {
                            selectedProvider = provider
                            appState.setTryOnProvider(provider)
                            dismiss()
                        } label: {
                            HStack(spacing: Theme.Spacing.md) {
                                Image(systemName: provider.iconName)
                                    .font(.title2)
                                    .foregroundStyle(providerColor(provider))
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(provider.displayName(language: lang))
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        if provider.isFree {
                                            Text(lang == .spanish ? "GRATIS" : "FREE")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.green)
                                                .clipShape(Capsule())
                                        }

                                        if provider.isCartoonStyle {
                                            Text(lang == .spanish ? "CARTOON" : "CARTOON")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.purple)
                                                .clipShape(Capsule())
                                        }

                                        if provider.requiresPremium {
                                            Text(lang == .spanish ? "PREMIUM" : "PREMIUM")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue)
                                                .clipShape(Capsule())
                                        }
                                    }

                                    Text(provider.subtitle(language: lang))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedProvider == provider {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.Colors.primary)
                                }
                            }
                            .padding(.vertical, Theme.Spacing.xs)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(lang == .spanish ? "Selecciona el proveedor de try-on" : "Select Try-On Provider")
                        .font(.headline)
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lang == .spanish ? "**Google Gemini**: mejor calidad y realismo. Requiere uso de API o premium." : "**Google Gemini**: Best quality and realism. Requires API usage or premium.")

                        Text(lang == .spanish ? "**Vista local**: composición gratuita en el dispositivo. Sirve como previsualización rápida, no como try-on realista." : "**Local Preview**: Free on-device composition. Useful as a quick preview, not a realistic try-on.")

                        if appState.hasBYOKAccess {
                            Text(lang == .spanish ? "**BYOK**: usa tu propia clave de OpenAI si quieres este proveedor disponible." : "**BYOK**: Use your own OpenAI API key if you want this provider available.")
                        }
                    }
                    .font(.caption)
                    .padding(.top, Theme.Spacing.sm)
                }
            }
            .navigationTitle(lang == .spanish ? "Proveedor de try-on" : "Try-On Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lang == .spanish ? "Cerrar" : "Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func providerColor(_ provider: TryOnProvider) -> Color {
        switch provider {
        case .google: return .blue
        case .playground: return .orange
        case .chatgpt: return .green
        }
    }
}

struct ProviderBadge: View {
    let provider: TryOnProvider

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: provider.iconName)
                .font(.caption)
            Text(provider.displayName)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.1))
        .foregroundStyle(badgeColor)
        .clipShape(Capsule())
    }

    private var badgeColor: Color {
        switch provider {
        case .google: return .blue
        case .playground: return .orange
        case .chatgpt: return .green
        }
    }
}
