import SwiftUI

@Observable
@MainActor
final class AppState {
    var currentUser: User?
    var isPremium: Bool = false
    var preferredLanguage: Language = .spanish
    var hasCompletedProfileSetup: Bool = false

    private let storeKitManager = StoreKitManager()

    init() {
        isPremium = storeKitManager.isPremium
    }

    func loadUserState() async {
        // User state is managed via SwiftData model context
    }

    func updateUser(_ user: User) {
        currentUser = user
        hasCompletedProfileSetup = user.profilePhotos.allPhotosUploaded
    }

    func setLanguage(_ language: Language) {
        preferredLanguage = language
    }
}

