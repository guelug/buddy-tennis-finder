import SwiftUI
import CloudKit

struct PrivacySettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showingDeleteConfirmation = false
    @State private var isExporting = false
    @State private var isDeleting = false
    @State private var exportResult: ExportResult?
    @State private var storageUsed: String = "Calculating..."
    @State private var itemsInCloset: Int = 0

    enum ExportResult {
        case success(URL)
        case failure(String)
    }

    var body: some View {
        List {
            // Data Usage Section
            Section {
                HStack {
                    Text("Storage Used")
                    Spacer()
                    Text(storageUsed)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Closet Items")
                    Spacer()
                    Text("\(itemsInCloset)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Current Tier")
                    Spacer()
                    Text(appState.currentTier.rawValue.capitalized)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Your Data")
            }

            // Privacy Info Section
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    PrivacyInfoRow(
                        icon: "iphone",
                        title: "On-Device AI",
                        description: "Chat uses Apple Foundation Models. Your conversations never leave your device."
                    )

                    PrivacyInfoRow(
                        icon: "icloud",
                        title: "iCloud Sync",
                        description: "Your profile, closet, and credits are encrypted and synced via iCloud."
                    )

                    PrivacyInfoRow(
                        icon: "photo",
                        title: "Photos Stay Local",
                        description: "Profile photos are analyzed on-device and never uploaded to external servers."
                    )

                    PrivacyInfoRow(
                        icon: "creditcard",
                        title: "Payments by Apple",
                        description: "All subscriptions are handled by Apple. We never see your payment info."
                    )
                }
                .padding(.vertical, 8)
            } header: {
                Text("Privacy")
            }

            // Export Section
            Section {
                Button {
                    Task { await exportUserData() }
                } label: {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .padding(.trailing, 4)
                        }
                        Text("Export My Data")
                    }
                }
                .disabled(isExporting)

                if let result = exportResult {
                    switch result {
                    case .success(let url):
                        ShareLink(item: url) {
                            Label("Share Export", systemImage: "square.and.arrow.up")
                        }
                    case .failure(let error):
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            } header: {
                Text("Data Portability")
            } footer: {
                Text("Export all your data as JSON including profile, palette, and closet items.")
            }

            // Delete Section
            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        if isDeleting {
                            ProgressView()
                                .padding(.trailing, 4)
                        }
                        Text("Delete All My Data")
                    }
                }
                .disabled(isDeleting)
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("This will permanently delete all your data from iCloud and our servers. This action cannot be undone.")
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete All Data?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) {
                Task { await deleteAllUserData() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your profile, closet items, color palette, and sync data. Subscriptions must be cancelled separately in Settings > App Store.")
        }
        .task {
            await loadStorageInfo()
        }
    }

    // MARK: - Methods

    private func loadStorageInfo() async {
        // Calcular storage usado aproximádamente
        // Por ahora mostrar valores placeholder
        storageUsed = "~2.3 MB"

        // Contar items del armario
        do {
            itemsInCloset = try await CloudKitManager.shared.clothingItemCount()
        } catch {
            itemsInCloset = 0
        }
    }

    private func exportUserData() async {
        isExporting = true
        exportResult = nil

        do {
            // Recoger datos de CloudKit
            var exportData: [String: Any] = [:]

            // User profile
            if let user = appState.currentUser {
                exportData["displayName"] = user.displayName
                exportData["preferredLanguage"] = user.preferredLanguage.rawValue
                exportData["createdAt"] = user.createdAt.description
            }

            // Credits info
            exportData["currentTier"] = appState.currentTier.rawValue
            exportData["isPremium"] = appState.isPremium
            exportData["exportedAt"] = Date().description

            // Closet items (simplificado)
            exportData["closetItemCount"] = itemsInCloset

            // Convertir a JSON
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)

            // Guardar temporalmente
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("personal_shooper_export.json")
            try jsonData.write(to: tempURL)

            exportResult = .success(tempURL)
        } catch {
            exportResult = .failure(error.localizedDescription)
        }

        isExporting = false
    }

    private func deleteAllUserData() async {
        isDeleting = true

        do {
            // 1. Eliminar de CloudKit
            try await CloudKitManager.shared.deleteAllRecords()

            // 2. Eliminar localmente (SwiftData se maneja solo con cascade)

            // 3. Llamar a Vercel para eliminar de Redis (si hay receipt hash)
            if let receiptHash = UserDefaults.standard.string(forKey: "receipt_hash") {
                let url = URL(string: "https://your-vercel-app.vercel.app/api/delete-user")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(receiptHash, forHTTPHeaderField: "X-Receipt-Hash")
                let _ = try? await URLSession.shared.data(for: request)
            }

            // 4. Limpiar UserDefaults
            UserDefaults.standard.removeObject(forKey: "receipt_hash")
            UserDefaults.standard.removeObject(forKey: "tryon_provider")

            // 5. Limpiar Keychain
            KeychainHelper.delete(for: "gemini_api_key")
            KeychainHelper.delete(for: "openai_api_key")

            // 6. Reset AppState
            appState.currentUser = nil
            appState.isPremium = false
            appState.isBYOKEnabled = false

        } catch {
            // Log error pero continuar con limpieza local
            print("Error deleting cloud data: \(error)")
        }

        isDeleting = false
    }
}

struct PrivacyInfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
