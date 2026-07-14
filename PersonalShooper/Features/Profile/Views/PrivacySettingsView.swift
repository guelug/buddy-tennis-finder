import SwiftUI
import SwiftData
import WidgetKit

struct PrivacySettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \User.createdAt) private var users: [User]
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var clothingItems: [ClothingItem]
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @Query(sort: \TryOnResult.createdAt, order: .reverse) private var tryOnResults: [TryOnResult]
    @Query(sort: \StyleProgressMission.createdAt, order: .reverse) private var progressMissions: [StyleProgressMission]
    @Query(sort: \SavedOutfit.createdAt, order: .reverse) private var savedOutfits: [SavedOutfit]
    @Query(sort: \OutfitCalendarEntry.dayKey) private var outfitCalendarEntries: [OutfitCalendarEntry]
    @Query(sort: \ARClothingPlacement.createdAt, order: .reverse) private var arPlacements: [ARClothingPlacement]
    @Query(sort: \ShoppingItem.createdAt, order: .reverse) private var shoppingItems: [ShoppingItem]
    @State private var showingDeleteConfirmation = false
    @State private var isExporting = false
    @State private var isDeleting = false
    @State private var exportResult: ExportResult?
    @State private var deleteResultMessage: String?
    @State private var storageUsed: String = "Calculating..."
    @State private var itemsInCloset: Int = 0
    @AppStorage(StyleImageService.managedProcessingConsentKey) private var allowsManagedImageProcessing = false

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
                    Text(text("Acceso", "Access"))
                    Spacer()
                    Text(text("Gratis", "Free"))
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
                        icon: "externaldrive.fill",
                        title: text("Guardado local", "Local Storage"),
                        description: text("Tu perfil, armario, looks y conversaciones se guardan en este dispositivo. La app no sincroniza ese contenido con iCloud.", "Your profile, closet, outfits, and conversations are stored on this device. The app doesn't sync that content to iCloud.")
                    )

                    PrivacyInfoRow(
                        icon: "photo",
                        title: text("Fotos bajo tu control", "Photos Under Your Control"),
                        description: text("Las fotos se guardan y analizan localmente. Solo se envían las referencias necesarias cuando eliges expresamente un try-on externo.", "Photos are stored and analyzed locally. Required references are sent only when you explicitly choose an external try-on provider.")
                    )

                    PrivacyInfoRow(
                        icon: "network",
                        title: text("Proveedor visible", "Visible Provider"),
                        description: text("Antes de generar un try-on puedes elegir entre opciones locales y externas. Las externas se identifican en la pantalla.", "Before generating a try-on you can choose between local and external options. External providers are identified on screen.")
                    )

                    PrivacyInfoRow(
                        icon: "gift.fill",
                        title: text("Siempre gratis", "Always Free"),
                        description: text("La app no contiene suscripciones, compras ni funciones bloqueadas por pago. La nube aplica límites de uso razonable.", "The app contains no subscriptions, purchases, or paid feature locks. Managed cloud uses fair-use limits.")
                    )
                }
                .padding(.vertical, 8)
            } header: {
                Text(text("Privacidad", "Privacy"))
            }

            Section {
                Toggle(isOn: $allowsManagedImageProcessing) {
                    Label(
                        text("Permitir miniaturas en la nube", "Allow Cloud Thumbnails"),
                        systemImage: "wand.and.stars.inverse"
                    )
                }
                .accessibilityIdentifier("privacy.managedImageProcessing")
            } header: {
                Text(text("Procesado externo", "External Processing"))
            } footer: {
                Text(text(
                    "Solo se usa si Image Playground no está disponible y no has configurado una clave propia. Las fotos de prendas necesarias se envían al servicio de IA para crear la miniatura.",
                    "Used only when Image Playground is unavailable and you haven't configured your own key. Required garment photos are sent to the AI service to create the thumbnail."
                ))
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
                Text(text("Exporta un JSON con perfil, armario, looks, calendario, conversaciones, try-ons, AR y lista de compras.", "Export JSON with profile, closet, looks, calendar, conversations, try-ons, AR, and shopping list."))
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
                Text(text("Esto elimina los datos locales y, cuando el backend está disponible, sus contadores de uso.", "This deletes local data and, when the backend is available, its usage counters."))
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
            Text(text("Se eliminarán perfil, armario, looks, calendario, AR, lista de compras, conversaciones y try-ons.", "This will delete your profile, closet, outfits, calendar, AR, shopping list, conversations, and try-ons."))
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

            exportData["access"] = "free"
            exportData["exportedAt"] = Date().description
            exportData["storageUsedBytes"] = StorageBudgetManager.currentUsageBytes(modelContext: modelContext)
            exportData["closetItems"] = clothingItems.map(exportDictionary(for:))
            exportData["conversations"] = conversations.map(exportDictionary(for:))
            exportData["tryOnResults"] = tryOnResults.map(exportDictionary(for:))
            exportData["styleProgressMissions"] = progressMissions.map(exportDictionary(for:))
            exportData["savedOutfits"] = savedOutfits.map(exportDictionary(for:))
            exportData["outfitCalendarEntries"] = outfitCalendarEntries.map(exportDictionary(for:))
            exportData["arPlacements"] = arPlacements.map(exportDictionary(for:))
            exportData["shoppingItems"] = shoppingItems.map(exportDictionary(for:))

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
            let remoteDeletion = await deleteRemoteUsageData()

            try deleteAllLocalRecords()

            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
            }
            SharedStyleCompanionStore.resetAllData()

            [
                "gemini_api_key", "openai_api_key", "anthropic_api_key",
                "kimi_api_key", "openrouter_api_key"
            ].forEach { KeychainHelper.delete(for: $0) }

            appState.currentUser = nil
            appState.isPremium = false
            appState.hasBYOKAccess = FreeAccessPolicy.allowsBYOK
            appState.hasAppleIntelligenceFeatures = FreeAccessPolicy.allowsAppleIntelligence
            appState.isBYOKEnabled = false
            appState.isChatGPTConnected = false
            appState.useConnectedChatGPTForChat = false
            appState.currentTier = .free
            appState.todayCalendarEvents = []
            appState.latestDailyRecommendation = nil
            WidgetCenter.shared.reloadAllTimelines()

            await loadStorageInfo()
            switch remoteDeletion {
            case .deleted:
                deleteResultMessage = text("Tus datos locales y contadores de uso remotos se han eliminado.", "Your local data and remote usage counters have been deleted.")
            case .notConfigured:
                deleteResultMessage = text("Tus datos locales se han eliminado. No había un backend remoto configurado.", "Your local data has been deleted. No remote backend was configured.")
            case .failed:
                deleteResultMessage = text("Tus datos locales se han eliminado, pero no se pudo confirmar el borrado de los contadores remotos. Reinténtalo cuando tengas conexión con App Store.", "Your local data has been deleted, but remote usage-counter deletion couldn't be confirmed. Try again when App Store connectivity is available.")
            }

        } catch {
            deleteResultMessage = text("No se pudieron eliminar todos los datos: \(error.localizedDescription)", "Could not delete all data: \(error.localizedDescription)")
        }

        isDeleting = false
    }

    private enum RemoteDeletionResult {
        case deleted
        case notConfigured
        case failed
    }

    private func deleteRemoteUsageData() async -> RemoteDeletionResult {
        guard let baseURL = AppSecrets.vercelAPIBaseURL else { return .notConfigured }
        guard let authorization = await StoreKitManager.shared.serverAuthorization() else { return .failed }

        var request = URLRequest(url: baseURL.appendingPathComponent("api/delete-user"))
        request.httpMethod = "POST"
        authorization.apply(to: &request)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                return .failed
            }
            return .deleted
        } catch {
            return .failed
        }
    }

    private func deleteAllLocalRecords() throws {
        try modelContext.fetch(FetchDescriptor<Message>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<Conversation>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<TryOnResult>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<StyleProgressMission>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<SavedOutfit>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<OutfitCalendarEntry>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<ARClothingPlacement>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<ShoppingItem>()).forEach { modelContext.delete($0) }
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

    private func exportDictionary(for outfit: SavedOutfit) -> [String: Any] {
        [
            "id": outfit.id.uuidString,
            "name": outfit.name,
            "itemIDs": outfit.itemIDStrings,
            "occasion": jsonValue(outfit.occasion),
            "note": jsonValue(outfit.note),
            "createdAt": outfit.createdAt.description
        ]
    }

    private func exportDictionary(for entry: OutfitCalendarEntry) -> [String: Any] {
        [
            "dayKey": entry.dayKey,
            "itemIDs": entry.clothingItemIDs.map(\.uuidString),
            "note": jsonValue(entry.note),
            "createdAt": entry.createdAt.description,
            "updatedAt": entry.updatedAt.description
        ]
    }

    private func exportDictionary(for placement: ARClothingPlacement) -> [String: Any] {
        [
            "id": placement.id.uuidString,
            "clothingItemID": placement.clothingItemIDString,
            "position": [
                "x": placement.positionX,
                "y": placement.positionY,
                "z": placement.positionZ
            ],
            "label": jsonValue(placement.label),
            "shelfName": jsonValue(placement.shelfName),
            "createdAt": placement.createdAt.description
        ]
    }

    private func exportDictionary(for item: ShoppingItem) -> [String: Any] {
        [
            "id": item.id.uuidString,
            "title": item.title,
            "category": jsonValue(item.categoryRaw),
            "colorHint": jsonValue(item.colorHint),
            "reason": jsonValue(item.reason),
            "isPurchased": item.isPurchased,
            "createdAt": item.createdAt.description
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
