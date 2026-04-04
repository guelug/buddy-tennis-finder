import Foundation

enum AppSecrets {
    private static let openAIKeyName = "OPENAI_API_KEY"
    private static let geminiKeyName = "GEMINI_API_KEY"
    private static let vercelAPIURLName = "VERCEL_API_URL"
    private static let internalBYOKTestingName = "ENABLE_BYOK_INTERNAL_TESTING"
    private static let storedOpenAIKey = "chatgpt_access_token"

    private static var bundledSecrets: [String: Any] {
        guard let url = Bundle.main.url(forResource: "LocalSecrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let object = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dictionary = object as? [String: Any] else {
            return [:]
        }

        return dictionary
    }

    private static func boolValue(for key: String) -> Bool {
        guard let value = stringValue(for: key)?.lowercased() else {
            return false
        }

        return value == "1" || value == "true" || value == "yes"
    }

    static var openAIAPIKey: String? {
        stringValue(for: openAIKeyName)
    }

    static var geminiAPIKey: String? {
        stringValue(for: geminiKeyName)
    }

    static var vercelAPIBaseURL: URL? {
        guard let value = stringValue(for: vercelAPIURLName) else { return nil }
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
}
