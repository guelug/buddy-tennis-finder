import SwiftUI
import CloudKit
import SwiftData

struct PrivacySettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \User.createdAt) private var users: [User]
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var clothingItems: [ClothingItem]
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @Query(sort: \TryOnResult.createdAt, order: .reverse) private var tryOnResults: [TryOnResult]
    @Query(sort: \StyleProgressMission.createdAt, order: .reverse) private var progressMissions: [StyleProgressMission]
    @State private var showingDeleteConfirmation = false
    @State private var isExporting = false
    @State private var isDeleting = false
    @State private var exportResult: ExportResult?
    @State private var deleteResultMessage: String?
    @State private var storageUsed: String = "Calculating..."
    @State private var itemsInCloset: Int = 0

    enum ExportResult {
        case success(URL)
        case failure(String)
    }

    private var lang: Language {
        appState.preferredLanguage
    }

    var body: some View {
        List {
            // Data Usage Section
            Section {
                HStack {
                    Text(text("Almacenamiento usado", "Storage Used"))
                    Spacer()
                    Text(storageUsed)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(text("Prendas en el armario", "Closet Items"))
                    Spacer()
                    Text("\(itemsInCloset)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(text("Plan actual", "Current Tier"))
                    Spacer()
                    Text(appState.currentTier.rawValue.capitalized)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(text("Tus datos", "Your Data"))
            }

            // Privacy Info Section
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    PrivacyInfoRow(
                        icon: "iphone",
                        title: text("IA en el dispositivo", "On-Device AI"),
                        description: text("El chat usa Apple Foundation Models cuando está disponible. Tus conversaciones se guardan localmente.", "Chat uses Apple Foundation Models when available. Your conversations are stored locally.")
                    )

                    PrivacyInfoRow(
                        icon: "icloud",
                        title: text("Sincronización iCloud", "iCloud Sync"),
                        description: text("Los datos preparados para sincronización usan CloudKit/iCloud cuando la cuenta y capacidades están activas.", "Sync-ready data uses CloudKit/iCloud when the account and capabilities are active.")
                    )

                    PrivacyInfoRow(
                        icon: "photo",
                        title: text("Fotos locales", "Photos Stay Local"),
                        description: text("Las fotos del perfil se analizan en el dispositivo y no se suben a proveedores externos.", "Profile photos are analyzed on-device and never uploaded to external providers.")
                    )

                    PrivacyInfoRow(
                        icon: "creditcard",
                        title: text("Pagos con Apple", "Payments by Apple"),
                        description: text("Las suscripciones las gestiona Apple. La app no recibe tus datos de pago.", "All subscriptions are handled by Apple. The app never sees your payment info.")
                    )
                }
                .padding(.vertical, 8)
            } header: {
                Text(text("Privacidad", "Privacy"))
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
                        Text(text("Exportar mis datos", "Export My Data"))
                    }
                }
                .disabled(isExporting)

                if let result = exportResult {
                    switch result {
                    case .success(let url):
                        ShareLink(item: url) {
                            Label(text("Compartir exportación", "Share Export"), systemImage: "square.and.arrow.up")
                        }
                    case .failure(let error):
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            } header: {
                Text(text("Portabilidad", "Data Portability"))
            } footer: {
                Text(text("Exporta un JSON con perfil, paleta, armario, conversaciones, try-ons y misiones de progreso.", "Export JSON with profile, palette, closet, conversations, try-ons, and progress missions."))
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
                        Text(text("Eliminar todos mis datos", "Delete All My Data"))
                    }
                }
                .disabled(isDeleting)
            } header: {
                Text(text("Zona de riesgo", "Danger Zone"))
            } footer: {
                Text(text("Esto elimina los datos locales y pide borrar los registros remotos configurados. No cancela suscripciones de App Store.", "This deletes local data and asks configured remote services to remove records. It does not cancel App Store subscriptions."))
            }
        }
        .navigationTitle(text("Privacidad", "Privacy"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            text("¿Eliminar todos los datos?", "Delete All Data?"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(text("Eliminar todo", "Delete Everything"), role: .destructive) {
                Task { await deleteAllUserData() }
            }
            Button(text("Cancelar", "Cancel"), role: .cancel) {}
        } message: {
            Text(text("Se eliminarán perfil, armario, paleta, conversaciones, try-ons y datos de sincronización. Las suscripciones se cancelan aparte en Ajustes > App Store.", "This will delete your profile, closet, palette, conversations, try-ons, and sync data. Subscriptions must be cancelled separately in Settings > App Store."))
        }
        .alert(text("Datos eliminados", "Data Deleted"), isPresented: Binding(
            get: { deleteResultMessage != nil },
            set: { if !$0 { deleteResultMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                deleteResultMessage = nil
            }
        } message: {
            Text(deleteResultMessage ?? "")
        }
        .task {
            await loadStorageInfo()
        }
    }

    // MARK: - Methods

    private func loadStorageInfo() async {
        let bytes = StorageBudgetManager.currentUsageBytes(modelContext: modelContext)
        storageUsed = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)

        do {
            itemsInCloset = try modelContext.fetchCount(FetchDescriptor<ClothingItem>())
        } catch {
            itemsInCloset = 0
        }
    }

    private func exportUserData() async {
        isExporting = true
        exportResult = nil

        do {
            var exportData: [String: Any] = [:]
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            if let user = appState.currentUser {
                exportData["displayName"] = user.displayName
                exportData["preferredLanguage"] = user.preferredLanguage.rawValue
                exportData["createdAt"] = user.createdAt.description
                exportData["updatedAt"] = user.updatedAt.description
                exportData["stylePreferences"] = user.stylePreferences
                exportData["profilePhotoBytes"] = [
                    "faceCloseUp": user.faceCloseUpData?.count ?? 0,
                    "faceProfile": user.faceProfileData?.count ?? 0,
                    "fullBodyFront": user.fullBodyFrontData?.count ?? 0,
                    "fullBodyBack": user.fullBodyBackData?.count ?? 0
                ]
                exportData["personalPalette"] = user.personalPaletteData.flatMap { String(data: $0, encoding: .utf8) }
                if let profileData = try? encoder.encode(user.personalStylingProfile),
                   let profileJSON = String(data: profileData, encoding: .utf8) {
                    exportData["personalStylingProfile"] = profileJSON
                }
            }

            exportData["currentTier"] = appState.currentTier.rawValue
            exportData["isPremium"] = appState.isPremium
            exportData["exportedAt"] = Date().description
            exportData["storageUsedBytes"] = StorageBudgetManager.currentUsageBytes(modelContext: modelContext)
            exportData["closetItems"] = clothingItems.map(exportDictionary(for:))
            exportData["conversations"] = conversations.map(exportDictionary(for:))
            exportData["tryOnResults"] = tryOnResults.map(exportDictionary(for:))
            exportData["styleProgressMissions"] = progressMissions.map(exportDictionary(for:))

            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
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
            try? await CloudKitManager.shared.deleteAllRecords()

            try deleteAllLocalRecords()

            if let receiptHash = UserDefaults.standard.string(forKey: "receipt_hash"),
               let baseURL = AppSecrets.vercelAPIBaseURL {
                let url = URL(string: "\(baseURL.absoluteString)/api/delete-user")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(receiptHash, forHTTPHeaderField: "X-Receipt-Hash")
                let _ = try? await URLSession.shared.data(for: request)
            }

            UserDefaults.standard.removeObject(forKey: "receipt_hash")
            UserDefaults.standard.removeObject(forKey: "tryon_provider")
            UserDefaults.standard.removeObject(forKey: "chatgpt_access_token")
            UserDefaults.standard.removeObject(forKey: "chatgpt_chat_enabled")

            KeychainHelper.delete(for: "gemini_api_key")
            KeychainHelper.delete(for: "openai_api_key")

            appState.currentUser = nil
            appState.isPremium = false
            appState.isBYOKEnabled = false
            appState.isChatGPTConnected = false
            appState.useConnectedChatGPTForChat = false

            await loadStorageInfo()
            deleteResultMessage = text("Tus datos locales se han eliminado. Si tenías datos en servicios remotos configurados, también se solicitó su borrado.", "Your local data has been deleted. If configured remote services had data, deletion was also requested.")

        } catch {
            deleteResultMessage = text("No se pudieron eliminar todos los datos: \(error.localizedDescription)", "Could not delete all data: \(error.localizedDescription)")
        }

        isDeleting = false
    }

    private func deleteAllLocalRecords() throws {
        try modelContext.fetch(FetchDescriptor<Message>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<Conversation>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<TryOnResult>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<StyleProgressMission>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<ClothingItem>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<User>()).forEach { modelContext.delete($0) }
        try modelContext.save()
    }

    private func exportDictionary(for item: ClothingItem) -> [String: Any] {
        [
            "id": item.id.uuidString,
            "name": item.name,
            "category": item.category.rawValue,
            "brandName": jsonValue(item.brandName),
            "notes": jsonValue(item.notes),
            "colorTags": item.colorTags,
            "styleTags": item.styleTags,
            "materialTags": item.materialTags,
            "occasionTags": item.occasionTags,
            "detailTags": item.detailTags,
            "isFavorite": item.isFavorite,
            "timesWorn": item.timesWorn,
            "lastWornAt": jsonValue(item.lastWornAt?.description),
            "hiddenUsageScore": item.hiddenUsageScore,
            "recommendationAppearanceCount": item.recommendationAppearanceCount,
            "recommendationSuccessfulWearCount": item.recommendationSuccessfulWearCount,
            "recommendationIgnoredCount": item.recommendationIgnoredCount,
            "createdAt": item.createdAt.description,
            "imageBytes": item.imageData?.count ?? 0,
            "realReferenceImageBytes": item.realReferenceImageData?.count ?? 0
        ]
    }

    private func exportDictionary(for conversation: Conversation) -> [String: Any] {
        [
            "id": conversation.id.uuidString,
            "title": conversation.title,
            "createdAt": conversation.createdAt.description,
            "updatedAt": conversation.updatedAt.description,
            "messages": conversation.messages
                .sorted { $0.timestamp < $1.timestamp }
                .map { message in
                    [
                        "id": message.id.uuidString,
                        "role": message.role.rawValue,
                        "content": message.content,
                        "timestamp": message.timestamp.description,
                        "hasImage": message.imageData != nil,
                        "linkedClosetItemID": jsonValue(message.linkedClosetItemID?.uuidString),
                        "linkedTryOnResultID": jsonValue(message.linkedTryOnResultID?.uuidString)
                    ] as [String: Any]
                }
        ]
    }

    private func exportDictionary(for result: TryOnResult) -> [String: Any] {
        [
            "id": result.id.uuidString,
            "provider": result.provider.rawValue,
            "clothingName": result.clothingName,
            "clothingCategory": jsonValue(result.clothingCategory?.rawValue),
            "closetItemID": jsonValue(result.closetItemID?.uuidString),
            "referenceDescriptor": result.referenceDescriptor,
            "createdAt": result.createdAt.description,
            "clothingImageBytes": result.clothingImageData.count,
            "userPhotoBytes": result.userPhotoData.count,
            "resultImageBytes": result.resultImageData.count,
            "editCount": result.editHistory.count
        ]
    }

    private func exportDictionary(for mission: StyleProgressMission) -> [String: Any] {
        [
            "id": mission.id.uuidString,
            "title": mission.title,
            "linkedItemIDs": mission.linkedItemIDStrings,
            "targetMonths": mission.targetMonths,
            "createdAt": mission.createdAt.description,
            "dueAt": mission.dueAt.description,
            "completedAt": jsonValue(mission.completedAt?.description),
            "isActive": mission.isActive,
            "notes": jsonValue(mission.notes),
            "hasBaselineImage": mission.baselineImageData != nil,
            "hasFollowUpImage": mission.followUpImageData != nil
        ]
    }

    private func text(_ spanish: String, _ english: String) -> String {
        lang == .spanish ? spanish : english
    }

    private func jsonValue(_ value: Any?) -> Any {
        value ?? NSNull()
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
