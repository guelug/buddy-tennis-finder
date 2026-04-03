import SwiftUI

@Observable
final class AppState {
    var currentUser: User?
    var isPremium: Bool = false
    var preferredLanguage: Language = .english
    var hasCompletedProfileSetup: Bool = false

    private let storeKitManager = StoreKitManager()

    init() {
        isPremium = storeKitManager.isPremium
    }

    @MainActor
    func loadUserState() async {
        // User state is managed via SwiftData model context
        // This is handled by the views directly
    }

    @MainActor
    func updateUser(_ user: User) async {
        currentUser = user
        hasCompletedProfileSetup = user.profilePhotos.allPhotosUploaded
    }

    func setLanguage(_ language: Language) {
        preferredLanguage = language
    }
}

enum Language: String, Codable, CaseIterable, Identifiable {
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
