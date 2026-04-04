import SwiftUI

struct TryOnProviderSelectorView: View {
    @Environment(AppState.self) private var appState
    @Binding var selectedProvider: TryOnProvider
    @Environment(\.dismiss) private var dismiss

    private var lang: Language {
        appState.preferredLanguage
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(TryOnProvider.allCases) { provider in
                        Button {
                            selectedProvider = provider
                            dismiss()
                        } label: {
                            HStack(spacing: Theme.Spacing.md) {
                                Image(systemName: provider.icon)
                                    .font(.title2)
                                    .foregroundStyle(providerColor(provider))
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(provider.displayName)
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        if provider.isFree {
                                            Text("FREE")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.green)
                                                .clipShape(Capsule())
                                        }

                                        if provider.isCartoonStyle {
                                            Text("CARTOON")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.purple)
                                                .clipShape(Capsule())
                                        }
                                    }

                                    Text(provider.description)
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
                    Text("Select Try-On Provider")
                        .font(.headline)
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("**Google Gemini**: Best quality and realism. Requires API usage.")

                        Text("**Apple Playground**: Free on-device generation. Creates cartoon-style images, fun for kids!")

                        Text("**ChatGPT**: Uses your ChatGPT Plus subscription. Connect your account for premium quality.")
                    }
                    .font(.caption)
                    .padding(.top, Theme.Spacing.sm)
                }
            }
            .navigationTitle("Try-On Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
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
            Image(systemName: provider.icon)
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
