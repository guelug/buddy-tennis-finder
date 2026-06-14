import SwiftUI

struct BYOKSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var geminiAPIKey: String = ""
    @State private var openAIAPIKey: String = ""
    @State private var anthropicAPIKey: String = ""
    @State private var kimiAPIKey: String = ""
    @State private var openRouterAPIKey: String = ""
    @State private var selectedProvider: BYOKProvider = .gemini
    @State private var isTesting: Bool = false
    @State private var testResult: TestResult?
    @State private var showConfirmation: Bool = false
    @State private var hasStoredKeys: Bool = false

    enum BYOKProvider: String, CaseIterable {
        case gemini = "gemini"
        case openai = "openai"
        case anthropic = "anthropic"
        case kimi = "kimi"
        case openrouter = "openrouter"

        var displayName: String {
            switch self {
            case .gemini: return "Google Gemini"
            case .openai: return "OpenAI"
            case .anthropic: return "Anthropic Claude"
            case .kimi: return "Kimi"
            case .openrouter: return "OpenRouter"
            }
        }

        var icon: String {
            switch self {
            case .gemini: return "sparkles"
            case .openai: return "brain.head.profile"
            case .anthropic: return "flame.fill"
            case .kimi: return "moon.fill"
            case .openrouter: return "network"
            }
        }
    }

    private var hasAccess: Bool {
        appState.hasBYOKAccess
    }

    private var imageEngineBinding: Binding<StyleImageService.Engine> {
        Binding(
            get: { StyleImageService.resolvedEngine() },
            set: { UserDefaults.standard.set($0.rawValue, forKey: StyleImageService.providerDefaultsKey) }
        )
    }

    private var aiProviderModeBinding: Binding<AIProviderMode> {
        Binding(
            get: { appState.aiProviderMode },
            set: { appState.setAIProviderMode($0) }
        )
    }

    private var lang: Language {
        appState.preferredLanguage
    }

    private var aiModeIcon: String {
        switch appState.aiProviderMode {
        case .appleFoundation: return "apple.logo"
        case .byok: return "key.fill"
        case .premiumExternal: return "crown.fill"
        }
    }

    private var aiModeColor: Color {
        switch appState.aiProviderMode {
        case .appleFoundation: return .primary
        case .byok: return .blue
        case .premiumExternal: return Theme.Colors.premiumGold
        }
    }

    private var aiModeDescription: String {
        switch appState.aiProviderMode {
        case .appleFoundation:
            return text("Apple Intelligence es el modo por defecto: usa Foundation Models en el dispositivo para consejo de estilo privado.", "Apple Intelligence is the default mode: it uses on-device Foundation Models for private style advice.")
        case .byok:
            return text("BYOK usa la clave del proveedor seleccionado en este dispositivo. Apple Intelligence sigue disponible para alternar cuando quieras.", "BYOK uses the selected provider key on this device. Apple Intelligence remains available so you can switch anytime.")
        case .premiumExternal:
            return text("Premium externo usa el backend de fallback (Vercel) cuando está activado. BYOK queda guardado para cuando quieras volver a usar tu propia key.", "External Premium uses the fallback backend (Vercel) when enabled. BYOK stays saved for whenever you want to switch back to your own key.")
        }
    }

    private var canSave: Bool {
        hasStoredKeys || hasEnteredKeys
    }

    private var hasEnteredKeys: Bool {
        !geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !anthropicAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !kimiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    enum TestResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        List {
            if !hasAccess {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Bring Your Own Key", systemImage: "lock.fill")
                            .font(.headline)

                        Text(text("BYOK solo está disponible después de desbloquear la compra completa.", "BYOK is only available after unlocking the full purchase."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Section {
                    Picker(text("Proveedor activo", "Active provider"), selection: aiProviderModeBinding) {
                        ForEach(AIProviderMode.allCases) { mode in
                            Text(mode.displayName(language: lang)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: aiModeIcon)
                            .foregroundStyle(aiModeColor)
                            .frame(width: 22)

                        Text(aiModeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(text("Modo de IA", "AI Mode"))
                }

                // Info Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Bring Your Own Key", systemImage: "key.fill")
                            .font(.headline)

                        Text(text("Añade tus claves de Gemini u OpenAI para usar proveedores externos con tus propias credenciales.", "Add your Gemini or OpenAI keys to use external providers with your own credentials."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Status Section
                Section {
                    HStack {
                        Text(text("Estado", "Status"))
                        Spacer()
                        if appState.isBYOKEnabled {
                            Label(text("Activo", "Active"), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Label(text("Inactivo", "Not Active"), systemImage: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if appState.isBYOKEnabled {
                        HStack {
                            Text(text("Modo", "Mode"))
                            Spacer()
                            Text(appState.aiProviderMode.displayName(language: lang))
                                .foregroundStyle(.green)
                        }
                    }
                } header: {
                    Text(text("Estado", "Status"))
                }

                // API Keys Section
                Section {
                    // Provider selector
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(BYOKProvider.allCases, id: \.self) { provider in
                            Label(provider.displayName, systemImage: provider.icon)
                                .tag(provider)
                        }
                    }
                    .pickerStyle(.menu)

                    // Show key input based on selected provider
                    switch selectedProvider {
                    case .gemini:
                        SecureField("Gemini API Key", text: $geminiAPIKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    case .openai:
                        SecureField("OpenAI API Key", text: $openAIAPIKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    case .anthropic:
                        SecureField("Anthropic API Key", text: $anthropicAPIKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    case .kimi:
                        SecureField("Kimi API Key", text: $kimiAPIKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    case .openrouter:
                        SecureField("OpenRouter API Key", text: $openRouterAPIKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                } header: {
                    Text(text("Claves API", "API Keys"))
                } footer: {
                    Text(text("Tus claves se guardan en el Keychain de iOS y no se envían a nuestros servidores.", "Your keys are stored securely in the iOS Keychain and never sent to our servers."))
                }

                // Test Section
                Section {
                    Button {
                        Task { await testAPIKeys() }
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text(text("Probar claves", "Test Keys"))
                        }
                    }
                    .disabled(isTesting || !canSave)

                    if let result = testResult {
                        switch result {
                        case .success(let message):
                            Label(message, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failure(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }

                // Image provider — only meaningful when more than one image-capable key is set.
                if StyleImageService.hasMultipleEngines() {
                    Section {
                        Picker(text("Proveedor de imágenes y armario", "Image & wardrobe provider"), selection: imageEngineBinding) {
                            Text("Google Gemini").tag(StyleImageService.Engine.gemini)
                            Text("OpenAI").tag(StyleImageService.Engine.openai)
                        }
                    } footer: {
                        Text(text(
                            "Se usa para optimizar las fotos del armario y limpiar la referencia del probador. Si solo configuras un proveedor, se usa automáticamente.",
                            "Used to optimize wardrobe photos and clean the try-on reference. If you configure only one provider, it's used automatically."
                        ))
                    }
                }

                // Save Section
                Section {
                    Button {
                        saveAPIKeys()
                    } label: {
                        HStack {
                            Spacer()
                            Text(text("Guardar claves API", "Save API Keys"))
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)

                    if hasStoredKeys {
                        Button(role: .destructive) {
                            clearAPIKeys()
                        } label: {
                            HStack {
                                Spacer()
                                Text(text("Eliminar claves guardadas", "Remove Saved Keys"))
                                Spacer()
                            }
                        }
                    }
                }

                // Info Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(icon: "sparkles", title: "Google Gemini", description: text("Chat inteligente y análisis de imágenes.", "Smart chat and image analysis."))
                        InfoRow(icon: "brain.head.profile", title: "OpenAI", description: text("Chat avanzado y generación de imágenes.", "Advanced chat and image generation."))
                        InfoRow(icon: "flame.fill", title: "Anthropic Claude", description: text("Chat con razonamiento profundo.", "Deep reasoning chat."))
                        InfoRow(icon: "moon.fill", title: "Kimi", description: text("Chat con contexto extendido.", "Extended context chat."))
                        InfoRow(icon: "network", title: "OpenRouter", description: text("Acceso a múltiples proveedores con una sola key.", "Access multiple providers with one key."))
                        InfoRow(icon: "lock.shield", title: text("Seguro", "Secure"), description: text("Las claves se guardan en el Keychain de iOS.", "Keys are stored in iOS Keychain."))
                    }
                } header: {
                    Text(text("Proveedores soportados", "Supported Providers"))
                }
            }
        }
        .navigationTitle(text("Proveedor de IA", "AI Provider"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(text("Claves guardadas", "API Keys Saved"), isPresented: $showConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(text("Tus claves API se han guardado de forma segura en este dispositivo.", "Your API keys have been securely saved to your device."))
        }
        .task {
            loadStoredKeys()
        }
    }

    // MARK: - Methods

    private func testAPIKeys() async {
        isTesting = true
        testResult = nil

        let providersToTest: [(BYOKProvider, String)] = [
            (.gemini, geminiAPIKey),
            (.openai, openAIAPIKey),
            (.anthropic, anthropicAPIKey),
            (.kimi, kimiAPIKey),
            (.openrouter, openRouterAPIKey)
        ].filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        var messages: [String] = []

        for (provider, key) in providersToTest {
            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            let result = await testProvider(provider, key: trimmedKey)
            switch result {
            case .success(let message): messages.append(message)
            case .failure(let message):
                testResult = .failure(message)
                isTesting = false
                return
            }
        }

        testResult = .success(messages.joined(separator: " · "))
        isTesting = false
    }

    private func testProvider(_ provider: BYOKProvider, key: String) async -> TestResult {
        switch provider {
        case .gemini:
            return await testGeminiKey(key)
        case .openai:
            return await testOpenAIKey(key)
        case .anthropic:
            return await testAnthropicKey(key)
        case .kimi:
            return await testKimiKey(key)
        case .openrouter:
            return await testOpenRouterKey(key)
        }
    }

    private func testAnthropicKey(_ key: String) async -> TestResult {
        guard let url = URL(string: "https://api.anthropic.com/v1/models") else {
            return .failure(text("URL inválida para Anthropic", "Invalid Anthropic URL"))
        }

        var request = URLRequest(url: url)
        request.setValue("\(key)", forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return .success(text("Anthropic válida", "Anthropic key valid"))
            } else {
                return .failure(text("Clave Anthropic inválida", "Invalid Anthropic API key"))
            }
        } catch {
            return .failure(text("Falló la conexión con Anthropic: \(error.localizedDescription)", "Anthropic connection failed: \(error.localizedDescription)"))
        }
    }

    private func testKimiKey(_ key: String) async -> TestResult {
        guard let url = URL(string: "https://api.moonshot.cn/v1/models") else {
            return .failure(text("URL inválida para Kimi", "Invalid Kimi URL"))
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return .success(text("Kimi válida", "Kimi key valid"))
            } else {
                return .failure(text("Clave Kimi inválida", "Invalid Kimi API key"))
            }
        } catch {
            return .failure(text("Falló la conexión con Kimi: \(error.localizedDescription)", "Kimi connection failed: \(error.localizedDescription)"))
        }
    }

    private func testOpenRouterKey(_ key: String) async -> TestResult {
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else {
            return .failure(text("URL inválida para OpenRouter", "Invalid OpenRouter URL"))
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return .success(text("OpenRouter válida", "OpenRouter key valid"))
            } else {
                return .failure(text("Clave OpenRouter inválida", "Invalid OpenRouter API key"))
            }
        } catch {
            return .failure(text("Falló la conexión con OpenRouter: \(error.localizedDescription)", "OpenRouter connection failed: \(error.localizedDescription)"))
        }
    }

    private func testGeminiKey(_ key: String) async -> TestResult {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(key)") else {
            return .failure(text("URL inválida para Gemini", "Invalid Gemini URL"))
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return .success(text("Gemini válida", "Gemini key valid"))
            } else {
                return .failure(text("Clave Gemini inválida", "Invalid Gemini API key"))
            }
        } catch {
            return .failure(text("Falló la conexión con Gemini: \(error.localizedDescription)", "Gemini connection failed: \(error.localizedDescription)"))
        }
    }

    private func testOpenAIKey(_ key: String) async -> TestResult {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            return .failure(text("URL inválida para OpenAI", "Invalid OpenAI URL"))
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return .success(text("OpenAI válida", "OpenAI key valid"))
            } else {
                return .failure(text("Clave OpenAI inválida", "Invalid OpenAI API key"))
            }
        } catch {
            return .failure(text("Falló la conexión con OpenAI: \(error.localizedDescription)", "OpenAI connection failed: \(error.localizedDescription)"))
        }
    }

    private func saveAPIKeys() {
        guard hasAccess else { return }

        // Save all keys to Keychain
        saveKey(geminiAPIKey, keychainKey: "gemini_api_key")
        saveKey(openAIAPIKey, keychainKey: "openai_api_key")
        saveKey(anthropicAPIKey, keychainKey: "anthropic_api_key")
        saveKey(kimiAPIKey, keychainKey: "kimi_api_key")
        saveKey(openRouterAPIKey, keychainKey: "openrouter_api_key")

        // Save preferred provider
        UserDefaults.standard.set(selectedProvider.rawValue, forKey: "byok_preferred_provider")

        appState.isBYOKEnabled = hasEnteredKeys

        // Keep Vercel/premium-external connection independent from BYOK keys.
        // refreshAIProviderAvailability() will recompute isChatGPTConnected based on
        // the Vercel fallback flag or stored access token.
        appState.refreshAIProviderAvailability()

        hasStoredKeys = hasEnteredKeys
        showConfirmation = true

        Task {
            await appState.refreshPremiumStatus()
        }
    }

    private func saveKey(_ key: String, keychainKey: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainHelper.delete(for: keychainKey)
        } else {
            KeychainHelper.save(trimmed, for: keychainKey)
        }
    }

    private func loadStoredKeys() {
        geminiAPIKey = KeychainHelper.load(for: "gemini_api_key") ?? ""
        openAIAPIKey = KeychainHelper.load(for: "openai_api_key") ?? ""
        anthropicAPIKey = KeychainHelper.load(for: "anthropic_api_key") ?? ""
        kimiAPIKey = KeychainHelper.load(for: "kimi_api_key") ?? ""
        openRouterAPIKey = KeychainHelper.load(for: "openrouter_api_key") ?? ""

        // Load preferred provider
        if let savedProvider = UserDefaults.standard.string(forKey: "byok_preferred_provider"),
           let provider = BYOKProvider(rawValue: savedProvider) {
            selectedProvider = provider
        }

        hasStoredKeys = !geminiAPIKey.isEmpty || !openAIAPIKey.isEmpty || !anthropicAPIKey.isEmpty || !kimiAPIKey.isEmpty || !openRouterAPIKey.isEmpty
    }

    private func clearAPIKeys() {
        geminiAPIKey = ""
        openAIAPIKey = ""
        anthropicAPIKey = ""
        kimiAPIKey = ""
        openRouterAPIKey = ""
        saveAPIKeys()
    }

    private func text(_ spanish: String, _ english: String) -> String {
        lang == .spanish ? spanish : english
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
