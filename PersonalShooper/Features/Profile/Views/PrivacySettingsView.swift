import SwiftUI
import SwiftData

struct PrivacySettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var shareAnalyticsData = false
    @State private var allowPersonalizedAds = false
    @State private var showClearDataConfirmation = false
    @State private var clearDataConfirmationText = ""

    private var isSpanish: Bool {
        appState.preferredLanguage == .spanish
    }

    private var confirmationMatches: Bool {
        let normalized = clearDataConfirmationText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
        return normalized == "si" || normalized == "borrar" || normalized == "delete"
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
                    showClearDataConfirmation = true
                } label: {
                    Label(isSpanish ? "Borrar todos los datos" : "Clear All Data", systemImage: "trash")
                }
            } footer: {
                Text(isSpanish ? "Esto eliminará tus fotos, armario, resultados de try-on, análisis y conversaciones. Si en el futuro sincronizas el catálogo con iCloud, también podrías borrar esa copia. Esta acción no se puede deshacer." : "This will delete your photos, closet, try-on results, analysis, and conversation history. If you sync your catalog with iCloud in the future, that copy could be removed too. This action cannot be undone.")
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
        .sheet(isPresented: $showClearDataConfirmation, onDismiss: resetConfirmationState) {
            NavigationStack {
                Form {
                    Section {
                        Text(isSpanish ? "Vas a borrar permanentemente tus fotos, tu armario, los resultados de try-on, la paleta y el historial de chat. La suscripción premium seguirá activa." : "You are about to permanently delete your photos, closet, try-on results, palette, and chat history. Your premium subscription will remain active.")
                            .font(.body)
                        Text(isSpanish ? "Para continuar, escribe 'sí' o 'borrar'." : "To continue, type 'delete'.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section(isSpanish ? "Confirmación manual" : "Manual Confirmation") {
                        TextField(isSpanish ? "Escribe 'sí' o 'borrar'" : "Type 'delete'", text: $clearDataConfirmationText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Section {
                        Button(isSpanish ? "Borrar fotos, armario y datos" : "Delete Photos, Closet, and Data", role: .destructive) {
                            clearAllData()
                        }
                        .disabled(!confirmationMatches)
                    }
                }
                .navigationTitle(isSpanish ? "Confirmar borrado" : "Confirm Deletion")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(isSpanish ? "Cancelar" : "Cancel") {
                            showClearDataConfirmation = false
                        }
                    }
                }
            }
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
        resetConfirmationState()
        dismiss()
    }

    private func resetConfirmationState() {
        clearDataConfirmationText = ""
    }
}
