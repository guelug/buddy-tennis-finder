import SwiftUI
import SwiftData

struct PrivacySettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var shareAnalyticsData = false
    @State private var allowPersonalizedAds = false
    @State private var showClearDataAlert = false

    private var isSpanish: Bool {
        appState.preferredLanguage == .spanish
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Label(isSpanish ? "Tus datos son privados" : "Your Data is Private", systemImage: "lock.shield.fill")
                        .font(.headline)
                        .foregroundStyle(.green)

                    Text(isSpanish ? "Personal Shooper procesa tus fotos localmente en tu dispositivo. No subimos tus fotos a servidores externos, salvo las referencias mínimas necesarias cuando usas el try-on virtual con proveedores externos." : "Personal Shooper processes your photos locally on your device. We never upload your photos to external servers, except the minimum reference images needed when you use virtual try-on with external providers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, Theme.Spacing.xs)
            }

            Section(isSpanish ? "Recopilación de datos" : "Data Collection") {
                Toggle(isSpanish ? "Compartir analítica" : "Share Analytics", isOn: $shareAnalyticsData)

                Toggle(isSpanish ? "Recomendaciones personalizadas" : "Personalized Recommendations", isOn: $allowPersonalizedAds)

                Text(isSpanish ? "Estos ajustes afectan a cómo mejoramos la app. Tus fotos no se comparten." : "These settings affect how we improve our services. Your photos are never shared.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(isSpanish ? "Tus datos guardados" : "Your Stored Data") {
                if let user = appState.currentUser {
                    HStack {
                        Text(isSpanish ? "Fotos de perfil" : "Profile Photos")
                        Spacer()
                        Text("\(user.profilePhotos.uploadedCount)/4")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(isSpanish ? "Paleta de color" : "Color Palette")
                        Spacer()
                        Text(user.personalPalette != nil ? (isSpanish ? "Generada" : "Generated") : (isSpanish ? "Sin configurar" : "Not Set"))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(isSpanish ? "Conversaciones" : "Conversations")
                        Spacer()
                        Text(isSpanish ? "Guardadas localmente" : "Stored Locally")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showClearDataAlert = true
                } label: {
                    Label(isSpanish ? "Borrar todos los datos" : "Clear All Data", systemImage: "trash")
                }
            } footer: {
                Text(isSpanish ? "Esto eliminará tus fotos, armario, resultados de try-on, análisis y conversaciones. Esta acción no se puede deshacer." : "This will delete your photos, closet, try-on results, analysis, and conversation history. This action cannot be undone.")
            }

            Section {
                Link(destination: URL(string: "https://personalshooper.app/privacy")!) {
                    HStack {
                        Text(isSpanish ? "Política de privacidad" : "Privacy Policy")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }

                Link(destination: URL(string: "https://personalshooper.app/terms")!) {
                    HStack {
                        Text(isSpanish ? "Términos del servicio" : "Terms of Service")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(isSpanish ? "Ajustes de privacidad" : "Privacy Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isSpanish ? "¿Borrar todos los datos?" : "Clear All Data?", isPresented: $showClearDataAlert) {
            Button(isSpanish ? "Cancelar" : "Cancel", role: .cancel) {}
            Button(isSpanish ? "Borrar" : "Clear", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text(isSpanish ? "Esto borrará permanentemente tus fotos, paleta, armario, resultados de try-on e historial de chat. La suscripción premium seguirá activa." : "This will permanently delete your photos, palette, closet, try-on results, and chat history. Premium subscription will remain active.")
        }
    }

    private func clearAllData() {
        if let users = try? modelContext.fetch(FetchDescriptor<User>()) {
            users.forEach { user in
                user.profilePhotos = ProfilePhotos()
                user.skinAnalysis = nil
                user.personalPalette = nil
                user.updateStylingProfile(PersonalStylingProfile())
            }
        }

        if let conversations = try? modelContext.fetch(FetchDescriptor<Conversation>()) {
            conversations.forEach { modelContext.delete($0) }
        }

        if let clothingItems = try? modelContext.fetch(FetchDescriptor<ClothingItem>()) {
            clothingItems.forEach { modelContext.delete($0) }
        }

        if let tryOnResults = try? modelContext.fetch(FetchDescriptor<TryOnResult>()) {
            tryOnResults.forEach { modelContext.delete($0) }
        }

        try? modelContext.save()
        if let user = (try? modelContext.fetch(FetchDescriptor<User>()))?.first {
            appState.updateUser(user)
        }
        dismiss()
    }
}
