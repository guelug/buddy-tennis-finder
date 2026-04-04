import SwiftUI

struct BYOKSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var geminiAPIKey: String = ""
    @State private var openAIAPIKey: String = ""
    @State private var isTesting: Bool = false
    @State private var testResult: TestResult?
    @State private var showConfirmation: Bool = false

    private var hasAccess: Bool {
        appState.hasBYOKAccess
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

                        Text("BYOK is only available after unlocking the full purchase.")
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

                        Text("Purchased the lifetime plan? Add your own API keys for unlimited try-ons.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Status Section
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        if appState.isBYOKEnabled {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Label("Not Active", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if appState.isBYOKEnabled {
                        HStack {
                            Text("Tier")
                            Spacer()
                            Text("BYOK - Unlimited")
                                .foregroundStyle(.green)
                        }
                    }
                } header: {
                    Text("BYOK Status")
                }

                // API Keys Section
                Section {
                    SecureField("Gemini API Key", text: $geminiAPIKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("OpenAI API Key (Optional)", text: $openAIAPIKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("API Keys")
                } footer: {
                    Text("Your keys are stored securely in the iOS Keychain and never sent to our servers.")
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
                            Text("Test Keys")
                        }
                    }
                    .disabled(isTesting || geminiAPIKey.isEmpty)

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
                            Text("Save API Keys")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(geminiAPIKey.isEmpty)
                }

                // Info Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(icon: "brain", title: "Gemini", description: "Use your own Gemini API key for try-on generation")
                        InfoRow(icon: "dollarsign.circle", title: "No Credits", description: "With BYOK, you pay for API usage directly")
                        InfoRow(icon: "lock.shield", title: "Secure", description: "Keys stored in iOS Keychain")
                    }
                } header: {
                    Text("How BYOK Works")
                }
            }
        }
        .navigationTitle("BYOK Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("API Keys Saved", isPresented: $showConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your API keys have been securely saved to your device.")
        }
    }

    // MARK: - Methods

    private func testAPIKeys() async {
        isTesting = true
        testResult = nil

        // Test Gemini key
        let result = await testGeminiKey(geminiAPIKey)

        self.testResult = result
        isTesting = false
    }

    private func testGeminiKey(_ key: String) async -> TestResult {
        // Simple test: call Gemini API to list models
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(key)") else {
            return .failure("Invalid URL")
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return .success("Gemini key is valid!")
            } else {
                return .failure("Invalid API key")
            }
        } catch {
            return .failure("Connection failed: \(error.localizedDescription)")
        }
    }

    private func saveAPIKeys() {
        guard hasAccess else { return }

        // Guardar en Keychain
        KeychainHelper.save(geminiAPIKey, for: "gemini_api_key")
        if !openAIAPIKey.isEmpty {
            KeychainHelper.save(openAIAPIKey, for: "openai_api_key")
        }

        appState.isBYOKEnabled = true

        showConfirmation = true

        Task {
            await appState.refreshPremiumStatus()
        }
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
