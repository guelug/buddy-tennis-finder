import Foundation
import SwiftData
import UIKit

@Model
final class User {
    var id: UUID
    var displayName: String
    var faceCloseUpData: Data?
    var faceProfileData: Data?
    var fullBodyFrontData: Data?
    var fullBodyBackData: Data?
    var skinAnalysisData: Data?
    var personalPaletteData: Data?
    var stylePreferences: [String]
    var subscriptionTierRaw: String
    var preferredLanguageRaw: String
    var createdAt: Date
    var updatedAt: Date

    var profilePhotos: ProfilePhotos {
        get {
            ProfilePhotos(
                faceCloseUp: faceCloseUpData.flatMap { UIImage(data: $0) },
                faceProfile: faceProfileData.flatMap { UIImage(data: $0) },
                fullBodyFront: fullBodyFrontData.flatMap { UIImage(data: $0) },
                fullBodyBack: fullBodyBackData.flatMap { UIImage(data: $0) }
            )
        }
        set {
            faceCloseUpData = newValue.faceCloseUp?.jpegData(compressionQuality: 0.8)
            faceProfileData = newValue.faceProfile?.jpegData(compressionQuality: 0.8)
            fullBodyFrontData = newValue.fullBodyFront?.jpegData(compressionQuality: 0.8)
            fullBodyBackData = newValue.fullBodyBack?.jpegData(compressionQuality: 0.8)
        }
    }

    var skinAnalysis: SkinAnalysisResult? {
        get {
            guard let data = skinAnalysisData else { return nil }
            return try? JSONDecoder().decode(SkinAnalysisResult.self, from: data)
        }
        set {
            skinAnalysisData = try? JSONEncoder().encode(newValue)
        }
    }

    var personalPalette: PersonalPalette? {
        get {
            guard let data = personalPaletteData else { return nil }
            return try? JSONDecoder().decode(PersonalPalette.self, from: data)
        }
        set {
            personalPaletteData = try? JSONEncoder().encode(newValue)
        }
    }

    var subscriptionTier: SubscriptionTier {
        get { SubscriptionTier(rawValue: subscriptionTierRaw) ?? .free }
        set { subscriptionTierRaw = newValue.rawValue }
    }

    var preferredLanguage: Language {
        get { Language(rawValue: preferredLanguageRaw) ?? .english }
        set { preferredLanguageRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        displayName: String = "User",
        profilePhotos: ProfilePhotos = ProfilePhotos(),
        skinAnalysis: SkinAnalysisResult? = nil,
        personalPalette: PersonalPalette? = nil,
        stylePreferences: [String] = [],
        subscriptionTier: SubscriptionTier = .free,
        preferredLanguage: Language = .english
    ) {
        self.id = id
        self.displayName = displayName
        self.faceCloseUpData = profilePhotos.faceCloseUp?.jpegData(compressionQuality: 0.8)
        self.faceProfileData = profilePhotos.faceProfile?.jpegData(compressionQuality: 0.8)
        self.fullBodyFrontData = profilePhotos.fullBodyFront?.jpegData(compressionQuality: 0.8)
        self.fullBodyBackData = profilePhotos.fullBodyBack?.jpegData(compressionQuality: 0.8)
        self.skinAnalysisData = try? JSONEncoder().encode(skinAnalysis)
        self.personalPaletteData = try? JSONEncoder().encode(personalPalette)
        self.stylePreferences = stylePreferences
        self.subscriptionTierRaw = subscriptionTier.rawValue
        self.preferredLanguageRaw = preferredLanguage.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct ProfilePhotos {
    var faceCloseUp: UIImage?
    var faceProfile: UIImage?
    var fullBodyFront: UIImage?
    var fullBodyBack: UIImage?

    var allPhotosUploaded: Bool {
        faceCloseUp != nil && faceProfile != nil && fullBodyFront != nil && fullBodyBack != nil
    }

    var uploadedCount: Int {
        [faceCloseUp, faceProfile, fullBodyFront, fullBodyBack].compactMap { $0 }.count
    }
}

enum SubscriptionTier: String, Codable {
    case free
    case premium
}
