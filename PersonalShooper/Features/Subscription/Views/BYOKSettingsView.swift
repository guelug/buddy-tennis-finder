import SwiftUI

struct BYOKSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var geminiAPIKey: String = ""
    @State private var openAIAPIKey: String = ""
    @State private var isTesting: Bool = false
    @State private var testResult: TestResult?
    @State private var showConfirmation: Bool = false
    @State private var hasStoredKeys: Bool = false

    private var hasAccess: Bool {
        appState.hasBYOKAccess
    }

    private var lang: Language {
        appState.preferredLanguage
    }

    private var canSave: Bool {
        hasStoredKeys || hasEnteredKeys
    }

    private var hasEnteredKeys: Bool {
        !geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                            Text(text("Plan", "Tier"))
                            Spacer()
                            Text("BYOK - Unlimited")
                                .foregroundStyle(.green)
                        }
                    }
                } header: {
                    Text(text("Estado BYOK", "BYOK Status"))
                }

                // API Keys Section
                Section {
                    SecureField("Gemini API Key", text: $geminiAPIKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField(text("OpenAI API Key (opcional)", "OpenAI API Key (Optional)"), text: $openAIAPIKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
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
                        InfoRow(icon: "sparkles", title: "Gemini", description: text("Activa el proveedor Google Gemini para try-ons realistas.", "Enables the Google Gemini provider for realistic try-ons."))
                        InfoRow(icon: "brain.head.profile", title: "OpenAI", description: text("Activa el proveedor OpenAI y puede usarse también para el chat si lo habilitas.", "Enables the OpenAI provider and can also be used for chat when enabled."))
                        InfoRow(icon: "lock.shield", title: text("Seguro", "Secure"), description: text("Las claves se guardan en el Keychain de iOS.", "Keys are stored in iOS Keychain."))
                    }
                } header: {
                    Text(text("Cómo funciona BYOK", "How BYOK Works"))
                }
            }
        }
        .navigationTitle(text("Ajustes BYOK", "BYOK Settings"))
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

        var messages: [String] = []
        let trimmedGeminiKey = geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOpenAIKey = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedGeminiKey.isEmpty {
            switch await testGeminiKey(trimmedGeminiKey) {
            case .success(let message): messages.append(message)
            case .failure(let message):
                testResult = .failure(message)
                isTesting = false
                return
            }
        }

        if !trimmedOpenAIKey.isEmpty {
            switch await testOpenAIKey(trimmedOpenAIKey) {
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

        let trimmedGeminiKey = geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOpenAIKey = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedGeminiKey.isEmpty {
            KeychainHelper.delete(for: "gemini_api_key")
        } else {
            KeychainHelper.save(trimmedGeminiKey, for: "gemini_api_key")
        }

        if trimmedOpenAIKey.isEmpty {
            KeychainHelper.delete(for: "openai_api_key")
        } else {
            KeychainHelper.save(trimmedOpenAIKey, for: "openai_api_key")
        }

        appState.isBYOKEnabled = hasEnteredKeys
        if trimmedOpenAIKey.isEmpty {
            UserDefaults.standard.removeObject(forKey: "chatgpt_access_token")
            UserDefaults.standard.set(false, forKey: "chatgpt_chat_enabled")
            appState.useConnectedChatGPTForChat = false
            appState.isChatGPTConnected = AppSecrets.openAIAPIKey != nil
        } else {
            appState.isChatGPTConnected = true
        }

        hasStoredKeys = hasEnteredKeys

        showConfirmation = true

        Task {
            await appState.refreshPremiumStatus()
        }
    }

    private func loadStoredKeys() {
        geminiAPIKey = KeychainHelper.load(for: "gemini_api_key") ?? ""
        openAIAPIKey = KeychainHelper.load(for: "openai_api_key") ?? ""
        hasStoredKeys = !geminiAPIKey.isEmpty || !openAIAPIKey.isEmpty
    }

    private func clearAPIKeys() {
        geminiAPIKey = ""
        openAIAPIKey = ""
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
