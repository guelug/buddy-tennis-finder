import Foundation

enum Language: String, Codable, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case spanish = "es"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        }
    }
}
