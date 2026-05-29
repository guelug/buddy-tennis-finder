import Foundation

/// Resolves the AI stylist's name. She's "Rebe" by default, but if the user themselves is named
/// Rebe/Rebeca, the assistant becomes "Peter" so the two names don't clash.
enum AssistantPersona {
    static let defaultName = "Rebe"
    static let alternateName = "Peter"

    private static let clashingFirstNames: Set<String> = ["rebe", "rebeca", "rebecca"]

    static func name(forUserNamed userName: String?) -> String {
        guard let userName else { return defaultName }

        let normalized = userName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let firstName = normalized.split(separator: " ").first.map(String.init) ?? normalized
        return clashingFirstNames.contains(firstName) ? alternateName : defaultName
    }
}
