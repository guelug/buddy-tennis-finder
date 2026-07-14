import Foundation

enum AppSecrets {
    private static let openAIKeyName = "OPENAI_API_KEY"
    private static let geminiKeyName = "GEMINI_API_KEY"
    private static let vercelAPIURLName = "VERCEL_API_URL"
    private static let internalBYOKTestingName = "ENABLE_BYOK_INTERNAL_TESTING"
    private static let storedOpenAIKey = "chatgpt_access_token"

    private static func plistDictionary(named name: String) -> [String: Any] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let object = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dictionary = object as? [String: Any] else {
            return [:]
        }

        return dictionary
    }

    /// Sensitive provider keys (OpenAI/Gemini). Lives in `LocalSecrets.plist`, which is NOT bundled
    /// in release/TestFlight builds — so embedded paid keys never ship. Only present when running
    /// from Xcode with the file alongside the sources (dev convenience).
    private static var bundledSecrets: [String: Any] {
        plistDictionary(named: "LocalSecrets")
    }

    /// Non-sensitive runtime backend config. Authorization uses Apple-signed StoreKit 2 JWS values;
    /// no shared secret is bundled in the app.
    private static var bundledConfig: [String: Any] {
        plistDictionary(named: "BackendConfig")
    }

    private static func boolValue(for key: String) -> Bool {
        guard let value = stringValue(for: key)?.lowercased() else {
            return false
        }

        return value == "1" || value == "true" || value == "yes"
    }

    static var openAIAPIKey: String? {
        stringValue(for: openAIKeyName)
            ?? KeychainHelper.load(for: "openai_api_key")
            ?? UserDefaults.standard.string(forKey: storedOpenAIKey)
    }

    static var geminiAPIKey: String? {
        stringValue(for: geminiKeyName)
            ?? KeychainHelper.load(for: "gemini_api_key")
    }

    static var vercelAPIBaseURL: URL? {
        guard let value = configValue(for: vercelAPIURLName) else { return nil }
        return URL(string: value)
    }

    static var internalBYOKTestingEnabled: Bool {
        boolValue(for: internalBYOKTestingName)
    }

    static func primeDefaultsIfNeeded() {
        guard UserDefaults.standard.string(forKey: storedOpenAIKey) == nil,
              let openAIAPIKey,
              !openAIAPIKey.isEmpty else {
            return
        }

        UserDefaults.standard.set(openAIAPIKey, forKey: storedOpenAIKey)
    }

    private static func stringValue(for key: String) -> String? {
        if let processValue = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !processValue.isEmpty {
            return processValue
        }

        if let bundledValue = bundledSecrets[key] as? String {
            let trimmed = bundledValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return nil
    }

    /// Runtime config lookup for non-sensitive backend settings: env → bundled config →
    /// LocalSecrets.plist (dev).
    private static func configValue(for key: String) -> String? {
        if let value = stringValue(for: key) {
            return value
        }

        if let configValue = bundledConfig[key] as? String {
            let trimmed = configValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return nil
    }
}
