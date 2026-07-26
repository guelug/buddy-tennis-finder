import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var closetItems: [ClothingItem]
    @State private var selectedTheme: AppTheme = .system
    @State private var showingTryOnProvider = false

    private var managedCloudAvailable: Bool {
        AppSecrets.vercelAPIBaseURL != nil || appState.isChatGPTConnected
    }
    @State private var isRefreshingStyleCompanion = false
    @State private var showingClearCacheAlert = false
    @State private var clearCacheResultMessage: String?

    private var lang: Language {
        appState.preferredLanguage
    }

    /// Name of the chosen voice, or "Automatic" when the app picks it.
    private var selectedVoiceName: String {
        VoicePreferences.selectedVoice?.name ?? text("Automática", "Automatic")
    }

    private var aiModeIcon: String {
        switch appState.aiProviderMode {
        case .appleFoundation: return "apple.logo"
        case .byok: return "key.fill"
        case .managedCloud: return "cloud.fill"
        }
    }

    private var aiModeColor: Color {
        switch appState.aiProviderMode {
        case .appleFoundation: return .primary
        case .byok: return .blue
        case .managedCloud: return .cyan
        }
    }

    private var aiModeDescription: String {
        switch appState.aiProviderMode {
        case .appleFoundation:
            return text("Usa Apple Intelligence en el dispositivo para consejos privados de estilo.", "Uses on-device Apple Intelligence for private style advice.")
        case .byok:
            return text("Usa la clave BYOK y el proveedor elegido en este dispositivo.", "Uses the BYOK key and provider selected on this device.")
        case .managedCloud:
            return text("Usa la nube gestionada gratuita con límites de uso razonable.", "Uses the free managed cloud with fair-use limits.")
        }
    }

    var body: some View {
        List {
            // Appearance Section
            Section {
                // Theme Picker
                Picker(text("Tema", "Theme"), selection: $selectedTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        HStack {
                            Image(systemName: theme.icon)
                            Text(theme.displayName(language: lang))
                        }
                        .tag(theme)
                    }
                }
                .onChange(of: selectedTheme) { _, newValue in
                    applyTheme(newValue)
                }

                // Language Picker
                NavigationLink {
                    LanguageSettingsView()
                } label: {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text(text("Idioma", "Language"))
                        Spacer()
                        Text(lang.displayName)
                            .foregroundStyle(.secondary)
                    }
                }

                NavigationLink {
                    VoiceSettingsView()
                } label: {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundStyle(.pink)
                            .frame(width: 24)
                        Text(text("Voz del asistente", "Assistant voice"))
                        Spacer()
                        Text(selectedVoiceName)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(text("Apariencia", "Appearance"))
            }

            // Try-On Section
            Section {
                NavigationLink {
                    TryOnProviderSelectorView(selectedProvider: Binding(
                        get: { appState.tryOnProvider },
                        set: { appState.setTryOnProvider($0) }
                    ))
                } label: {
                    HStack {
                        Image(systemName: "camera.viewfinder")
                            .foregroundStyle(.purple)
                            .frame(width: 24)
                        Text(text("Proveedor de try-on", "Try-On Provider"))
                        Spacer()
                        Text(appState.tryOnProvider.displayName)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    showingTryOnProvider = true
                } label: {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text(text("Sobre los proveedores de try-on", "About Try-On Providers"))
                    }
                }
            } header: {
                Text(text("Probador virtual", "Virtual Try-On"))
            } footer: {
                Text(text("Google: mejor calidad. Apple Image Playground: generación gratuita y privada en el dispositivo. BYOK: usa tu propia clave de OpenAI.", "Google: best quality. Apple Image Playground: free, private on-device generation. BYOK: uses your own OpenAI API key."))
            }

            Section {
                Toggle(isOn: Binding(
                    get: { appState.isCalendarSyncEnabled },
                    set: { newValue in
                        Task {
                            await appState.setCalendarSyncEnabled(newValue, closetItems: closetItems)
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(text("Sincronizar calendario de Apple", "Sync Apple Calendar"))
                        Text(text("Leer eventos del día para afinar la recomendación.", "Read today's events to sharpen the recommendation."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: Binding(
                    get: { appState.areDailyWidgetsEnabled },
                    set: { appState.setDailyWidgetsEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(text("Widgets de recomendación diaria", "Daily recommendation widgets"))
                        Text(text("Comparte la recomendación del día con el widget.", "Share the recommendation of the day with the widget."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: Binding(
                    get: { appState.isSiriStyleSupportEnabled },
                    set: { appState.setSiriStyleSupportEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(text("Sugerencias con Siri", "Siri style suggestions"))
                        Text(text("Permite pedir la recomendación diaria con Siri.", "Lets Siri read your daily recommendation."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: Binding(
                    get: { appState.isDailyReminderEnabled },
                    set: { newValue in
                        Task { await appState.setDailyReminderEnabled(newValue, closetItems: closetItems) }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(text("Recordatorio diario de outfit", "Daily outfit reminder"))
                        Text(text("Cada día, a la hora que elijas, te recuerdo qué ponerte. Solo si tienes prendas en el armario.", "Each day, at the time you choose, I remind you what to wear. Only when your closet has garments."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if appState.isDailyReminderEnabled {
                    DatePicker(
                        text("Hora del recordatorio", "Reminder time"),
                        selection: Binding(
                            get: { appState.dailyReminderTime },
                            set: { newValue in
                                Task { await appState.setDailyReminderTime(newValue, closetItems: closetItems) }
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )

                    if closetItems.isEmpty {
                        Label(
                            text("Aún no tienes prendas. Añade alguna al armario para activar el recordatorio.", "No garments yet. Add some to your closet to activate the reminder."),
                            systemImage: "exclamationmark.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    } else if let recommendation = appState.latestDailyRecommendation {
                        Button {
                            DailyOutfitLiveActivityController.shared.pin(
                                recommendation: recommendation,
                                reminderTime: appState.dailyReminderTime,
                                language: lang
                            )
                        } label: {
                            Label(text("Mostrar look en la Isla Dinámica", "Show look in Dynamic Island"), systemImage: "sparkles")
                        }
                    }
                }

                Button {
                    Task {
                        isRefreshingStyleCompanion = true
                        await appState.refreshStyleCompanionState(closetItems: closetItems)
                        isRefreshingStyleCompanion = false
                    }
                } label: {
                    HStack {
                        Label(
                            text("Actualizar recomendación de hoy", "Refresh today's recommendation"),
                            systemImage: "arrow.clockwise"
                        )

                        Spacer()

                        if isRefreshingStyleCompanion {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(isRefreshingStyleCompanion)

                if appState.isCalendarSyncEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(text("Eventos de hoy", "Today's events"))
                            .font(.subheadline.weight(.semibold))

                        if appState.todayCalendarEvents.isEmpty {
                            Text(text("No se han encontrado eventos para hoy.", "No events were found for today."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(appState.todayCalendarEvents.prefix(3)) { event in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(.subheadline)
                                    Text(event.timeWindowText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let recommendation = appState.latestDailyRecommendation {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(text("Preview de la recomendación", "Recommendation preview"))
                            .font(.subheadline.weight(.semibold))
                        Text(recommendation.headline)
                            .font(.body.weight(.semibold))
                        Text(recommendation.outfitFormula)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(recommendation.colorDirection)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if appState.calendarAuthorizationStatus == .denied || appState.calendarAuthorizationStatus == .restricted {
                    Text(text(
                        "El acceso al calendario está bloqueado. Actívalo desde Ajustes del sistema si quieres usar recomendaciones según eventos.",
                        "Calendar access is blocked. Enable it in system Settings if you want event-aware recommendations."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text(text("Style Companion", "Style Companion"))
            } footer: {
                Text(text(
                    "Siri: di “¿Qué me recomienda ponerme hoy Personal Shopper?” para escuchar la recomendación diaria.",
                    "Siri: say “What should I wear today with Personal Shopper?” to hear the daily recommendation."
                ))
            }

            // Account Section
            Section {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.green)
                        .frame(width: 24)
                    Text(text("Nube gestionada de IA", "Managed AI Cloud"))
                    Spacer()
                    if managedCloudAvailable {
                        Label(text("Activo", "Active"), systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text(text("No disponible", "Unavailable"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if appState.hasBYOKAccess {
                    Picker(text("Modo de IA", "AI Mode"), selection: Binding(
                        get: { appState.aiProviderMode },
                        set: { appState.setAIProviderMode($0) }
                    )) {
                        ForEach(AIProviderMode.allCases) { mode in
                            Text(mode.displayName(language: lang)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: aiModeIcon)
                            .foregroundStyle(aiModeColor)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.aiProviderMode.displayName(language: lang))
                                .font(.subheadline)
                            Text(aiModeDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                NavigationLink {
                    BYOKSettingsView()
                } label: {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.yellow)
                            .frame(width: 24)
                        Text(text("Nube / claves propias", "Cloud / Your Keys"))
                        Spacer()
                        Text(appState.aiProviderMode.displayName(language: lang))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                NavigationLink {
                    PrivacySettingsView()
                } label: {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(.orange)
                            .frame(width: 24)
                        Text(text("Privacidad", "Privacy"))
                    }
                }
            } header: {
                Text(text("Cuenta", "Account"))
            } footer: {
                if appState.hasBYOKAccess, appState.isChatGPTConnected {
                    Text(text("Todas las funciones son gratuitas. Puedes alternar entre IA local, nube gestionada y claves propias.", "All features are free. You can switch between local AI, managed cloud, and your own keys."))
                }
            }

            // Data Section
            Section {
                NavigationLink {
                    ClosetManagementView()
                } label: {
                    HStack {
                        Image(systemName: "cabinet.fill")
                            .foregroundStyle(.brown)
                            .frame(width: 24)
                        Text(text("Gestionar armario", "Manage Closet"))
                    }
                }

                Button(role: .destructive) {
                    showingClearCacheAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                            .frame(width: 24)
                        Text(text("Limpiar caché local", "Clear Local Cache"))
                    }
                }
            } header: {
                Text(text("Datos", "Data"))
            } footer: {
                Text(text("Solo elimina resultados temporales del try-on guardados en este iPhone. No borra tu armario ni una futura copia sincronizada con iCloud.", "This only removes temporary try-on results stored on this iPhone. It does not delete your closet or a future iCloud-synced copy."))
            }

            // About Section
            Section {
                HStack {
                    Text(text("Versión", "Version"))
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }

                Link(destination: URL(string: "https://personalshooper.rebka.co/")!) {
                    HStack {
                        Text(text("Términos del servicio", "Terms of Service"))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                }

                Link(destination: URL(string: "https://personalshooper.rebka.co/#privacy")!) {
                    HStack {
                        Text(text("Política de privacidad", "Privacy Policy"))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                }
            } header: {
                Text(text("Acerca de", "About"))
            }
        }
        .navigationTitle(text("Ajustes", "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingTryOnProvider) {
            TryOnProviderInfoView()
        }
        .alert(text("Limpiar caché local", "Clear Local Cache"), isPresented: $showingClearCacheAlert) {
            Button(text("Cancelar", "Cancel"), role: .cancel) {}
            Button(text("Limpiar", "Clear"), role: .destructive) {
                clearTryOnCache()
            }
        } message: {
            Text(text("Se eliminarán solo los resultados guardados del try-on en este dispositivo para liberar espacio y forzar nuevas generaciones. Tu armario no se borrará.", "Only saved try-on results on this device will be removed to free up space and force fresh generations. Your closet will not be deleted."))
        }
        .alert(text("Caché actualizada", "Cache Updated"), isPresented: Binding(
            get: { clearCacheResultMessage != nil },
            set: { if !$0 { clearCacheResultMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                clearCacheResultMessage = nil
            }
        } message: {
            Text(clearCacheResultMessage ?? "")
        }
        .onAppear {
            if let savedTheme = UserDefaults.standard.string(forKey: "app_theme"),
               let theme = AppTheme(rawValue: savedTheme) {
                selectedTheme = theme
            }

            Task {
                await appState.refreshStyleCompanionState(closetItems: closetItems)
            }
        }
    }

    private func applyTheme(_ theme: AppTheme) {
        UserDefaults.standard.set(theme.rawValue, forKey: "app_theme")
    }

    private func clearTryOnCache() {
        let descriptor = FetchDescriptor<TryOnResult>()
        do {
            let results = try modelContext.fetch(descriptor)
            results.forEach { modelContext.delete($0) }
            try modelContext.save()
            clearCacheResultMessage = text(
                "Se eliminaron \(results.count) resultados guardados de try-on.",
                "Deleted \(results.count) saved try-on results."
            )
        } catch {
            clearCacheResultMessage = text(
                "No se pudo limpiar la caché: \(error.localizedDescription)",
                "Could not clear cache: \(error.localizedDescription)"
            )
        }
    }

    private func text(_ spanish: String, _ english: String) -> String {
        lang == .spanish ? spanish : english
    }
}

// MARK: - App Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    var id: String { rawValue }

    func displayName(language: Language) -> String {
        switch (self, language) {
        case (.light, .spanish): return "Claro"
        case (.dark, .spanish): return "Oscuro"
        case (.system, .spanish): return "Sistema"
        case (.light, .english): return "Light"
        case (.dark, .english): return "Dark"
        case (.system, .english): return "System"
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
}

// MARK: - Language Settings

struct LanguageSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            ForEach(Language.allCases) { language in
                Button {
                    appState.setLanguage(language)
                } label: {
                    HStack {
                        Text(language.flag)
                        Text(language.displayName)
                        Spacer()
                        if appState.preferredLanguage == language {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle(appState.preferredLanguage == .spanish ? "Idioma" : "Language")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Try-On Provider Info

struct TryOnProviderInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    private var isSpanish: Bool {
        appState.preferredLanguage == .spanish
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ProviderInfoCard(
                        icon: "g.circle.fill",
                        color: .blue,
                        name: "Google Gemini",
                        description: isSpanish ? "Resultados de try-on realistas mediante la nube gestionada gratuita." : "Realistic try-on results through the free managed cloud.",
                        features: isSpanish ? ["Imágenes realistas", "Sin compras", "Límites de uso razonable"] : ["Realistic images", "No purchases", "Fair-use limits"],
                        badge: isSpanish ? "RECOMENDADO" : "RECOMMENDED"
                    )

                    ProviderInfoCard(
                        icon: "apple.logo",
                        color: .orange,
                        name: "Apple Image Playground",
                        description: isSpanish ? "Generación gratuita y privada en el dispositivo para previsualizar una prenda sin llamar a un proveedor externo." : "Free, private on-device generation for previewing a garment without calling an external provider.",
                        features: isSpanish ? ["100% gratis", "Privado (no sale la foto)", "Funciona sin conexión", "Vista rápida", "No necesita cuenta"] : ["100% free", "Private (photo never leaves device)", "Works offline", "Quick preview", "No account needed"],
                        badge: "FREE"
                    )

                    ProviderInfoCard(
                        icon: "brain.head.profile",
                        color: .green,
                        name: "OpenAI · GPT Image 2",
                        description: isSpanish ? "Opción voluntaria para usar GPT Image 2 con tu propia clave." : "Optional provider using GPT Image 2 with your own key.",
                        features: isSpanish ? ["Clave guardada en Keychain", "Envío directo a OpenAI", "Sin pago dentro de la app"] : ["Key stored in Keychain", "Sent directly to OpenAI", "No in-app payment"],
                        badge: "BYOK"
                    )

                    ProviderInfoCard(
                        icon: "bolt.horizontal.circle.fill",
                        color: .pink,
                        name: "Fal.ai · Virtual Try-On",
                        description: isSpanish ? "Probador especializado opcional con tu propia clave de Fal.ai." : "Optional specialized try-on using your own Fal.ai key.",
                        features: isSpanish ? ["Cola con reintentos", "Clave guardada en Keychain", "El proveedor puede cobrar el uso"] : ["Reliable queued requests", "Key stored in Keychain", "Provider usage may cost"],
                        badge: "BYOK"
                    )
                }
                .padding()
            }
            .navigationTitle(isSpanish ? "Proveedores de try-on" : "Try-On Providers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSpanish ? "Cerrar" : "Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ProviderInfoCard: View {
    let icon: String
    let color: Color
    let name: String
    let description: String
    let features: [String]
    let badge: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)
                Text(name)
                    .font(.headline)
                Spacer()
                Text(badge)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color)
                    .clipShape(Capsule())
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(feature)
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Closet Management

struct ClosetManagementView: View {
    @Query private var items: [ClothingItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAllConfirmation = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text(appState.preferredLanguage == .spanish ? "Total de prendas" : "Total Items")
                    Spacer()
                    Text("\(items.count)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(appState.preferredLanguage == .spanish ? "Categorías" : "Categories")
                    Spacer()
                    Text("\(Set(items.map { $0.category }).count)")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(ClothingCategory.allCases, id: \.self) { category in
                    let count = items.filter { $0.category == category }.count
                    HStack {
                        Image(systemName: category.icon)
                        Text(category.displayName)
                        Spacer()
                        Text("\(count)")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(appState.preferredLanguage == .spanish ? "Por categoría" : "By Category")
            }

            Section {
                Button(role: .destructive) {
                    showingDeleteAllConfirmation = true
                } label: {
                    Text(appState.preferredLanguage == .spanish ? "Eliminar todas las prendas" : "Delete All Items")
                }
            }
        }
        .navigationTitle(appState.preferredLanguage == .spanish ? "Gestionar armario" : "Manage Closet")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            appState.preferredLanguage == .spanish ? "¿Eliminar todas las prendas?" : "Delete all items?",
            isPresented: $showingDeleteAllConfirmation,
            titleVisibility: .visible
        ) {
            Button(appState.preferredLanguage == .spanish ? "Eliminar todo" : "Delete Everything", role: .destructive) {
                deleteAllItems()
            }
            Button(appState.preferredLanguage == .spanish ? "Cancelar" : "Cancel", role: .cancel) {}
        } message: {
            Text(appState.preferredLanguage == .spanish ? "Esta acción borra el armario local. No elimina tus fotos del perfil." : "This deletes the local closet. It does not remove profile photos.")
        }
    }

    private func deleteAllItems() {
        items.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}
