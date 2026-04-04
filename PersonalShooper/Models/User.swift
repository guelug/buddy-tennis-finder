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
    var personalStylingProfileData: Data?
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

    var personalStylingProfile: PersonalStylingProfile {
        get {
            guard let data = personalStylingProfileData,
                  let profile = try? JSONDecoder().decode(PersonalStylingProfile.self, from: data) else {
                return PersonalStylingProfile()
            }
            return profile
        }
        set {
            personalStylingProfileData = try? JSONEncoder().encode(newValue)
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
        personalStylingProfile: PersonalStylingProfile = PersonalStylingProfile(),
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
        self.personalStylingProfileData = try? JSONEncoder().encode(personalStylingProfile)
        self.stylePreferences = Array(Set(stylePreferences + personalStylingProfile.derivedStylePreferences)).sorted()
        self.subscriptionTierRaw = subscriptionTier.rawValue
        self.preferredLanguageRaw = preferredLanguage.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var stylistContextHighlights: [String] {
        personalStylingProfile.highlightTags(in: preferredLanguage)
    }

    func syncDerivedStylePreferences() {
        stylePreferences = personalStylingProfile.derivedStylePreferences
        updatedAt = Date()
    }

    func updateStylingProfile(_ profile: PersonalStylingProfile) {
        personalStylingProfile = profile
        syncDerivedStylePreferences()
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

struct PersonalStylingProfile: Codable, Equatable {
    var age: Int?
    var occupation: String
    var lifestyleSummary: String
    var usualSocialPlans: [String]
    var preferredStyles: [String]
    var desiredImpression: [String]
    var fitPriorities: [String]
    var favoriteColors: [String]
    var avoidColors: [String]
    var styleGoals: String
    var shoppingChallenges: String
    var additionalNotes: String
    var lastUpdatedFromChatAt: Date?

    init(
        age: Int? = nil,
        occupation: String = "",
        lifestyleSummary: String = "",
        usualSocialPlans: [String] = [],
        preferredStyles: [String] = [],
        desiredImpression: [String] = [],
        fitPriorities: [String] = [],
        favoriteColors: [String] = [],
        avoidColors: [String] = [],
        styleGoals: String = "",
        shoppingChallenges: String = "",
        additionalNotes: String = "",
        lastUpdatedFromChatAt: Date? = nil
    ) {
        self.age = age
        self.occupation = occupation
        self.lifestyleSummary = lifestyleSummary
        self.usualSocialPlans = usualSocialPlans
        self.preferredStyles = preferredStyles
        self.desiredImpression = desiredImpression
        self.fitPriorities = fitPriorities
        self.favoriteColors = favoriteColors
        self.avoidColors = avoidColors
        self.styleGoals = styleGoals
        self.shoppingChallenges = shoppingChallenges
        self.additionalNotes = additionalNotes
        self.lastUpdatedFromChatAt = lastUpdatedFromChatAt
    }

    var derivedStylePreferences: [String] {
        Array(Set(preferredStyles + desiredImpression + fitPriorities)).sorted()
    }

    var completionRatio: Double {
        let completedFields = [
            age != nil,
            !occupation.isEmpty,
            !lifestyleSummary.isEmpty,
            !usualSocialPlans.isEmpty,
            !preferredStyles.isEmpty,
            !desiredImpression.isEmpty,
            !fitPriorities.isEmpty,
            !favoriteColors.isEmpty || !avoidColors.isEmpty,
            !styleGoals.isEmpty,
            !shoppingChallenges.isEmpty || !additionalNotes.isEmpty
        ].filter { $0 }.count

        return Double(completedFields) / 10.0
    }

    var isCompleteEnough: Bool {
        completionRatio >= 0.45
    }

    func nextQuestion(in language: Language) -> String? {
        if age == nil {
            return language == .spanish
                ? "¿Qué edad tienes aproximadamente? Es opcional, pero me ayuda a ajustar referencias y niveles de formalidad."
                : "How old are you approximately? It is optional, but it helps me calibrate references and formality."
        }

        if occupation.isEmpty {
            return language == .spanish
                ? "¿A qué te dedicas o cómo es tu entorno de trabajo?"
                : "What do you do, or what is your work environment like?"
        }

        if usualSocialPlans.isEmpty {
            return language == .spanish
                ? "¿Qué planes o eventos sueles tener: oficina, cenas, viajes, bodas, networking o algo más?"
                : "What plans or events do you usually have: office, dinners, travel, weddings, networking, or something else?"
        }

        if preferredStyles.isEmpty {
            return language == .spanish
                ? "¿Con qué estilos te identificas más: minimalista, clásica, elegante, casual, creativa...?"
                : "Which styles feel most like you: minimal, classic, elegant, casual, creative...?"
        }

        if desiredImpression.isEmpty {
            return language == .spanish
                ? "¿Cómo te gusta proyectarte al vestir: profesional, cercana, sofisticada, creativa, relajada...?"
                : "How do you like to come across when you dress: professional, approachable, sophisticated, creative, relaxed...?"
        }

        if fitPriorities.isEmpty {
            return language == .spanish
                ? "¿Qué priorizas más al vestirte: comodidad, verte pulida, versatilidad, practicidad o impacto?"
                : "What matters most to you when dressing: comfort, polish, versatility, practicality, or impact?"
        }

        if styleGoals.isEmpty {
            return language == .spanish
                ? "¿Qué te gustaría mejorar en tu estilo ahora mismo?"
                : "What would you most like to improve about your style right now?"
        }

        return nil
    }

    func highlightTags(in language: Language) -> [String] {
        var tags: [String] = []

        if let age {
            tags.append(language == .spanish ? "\(age) años" : "\(age) years")
        }

        if !occupation.isEmpty {
            tags.append(occupation)
        }

        tags.append(contentsOf: usualSocialPlans.prefix(2).map { StyleProfileCatalog.title(for: $0, in: language) })
        tags.append(contentsOf: preferredStyles.prefix(2).map { StyleProfileCatalog.title(for: $0, in: language) })
        tags.append(contentsOf: desiredImpression.prefix(2).map { StyleProfileCatalog.title(for: $0, in: language) })

        if !favoriteColors.isEmpty {
            let colors = favoriteColors.prefix(2).joined(separator: ", ")
            tags.append(language == .spanish ? "Colores: \(colors)" : "Colors: \(colors)")
        }

        return Array(tags.prefix(6))
    }
}

struct StyleProfileOption: Identifiable, Hashable {
    let id: String
    let titleEs: String
    let titleEn: String

    var title: String {
        titleEs
    }

    func title(in language: Language) -> String {
        language == .spanish ? titleEs : titleEn
    }
}

enum StyleProfileCatalog {
    static let socialActivities: [StyleProfileOption] = [
        StyleProfileOption(id: "work_meetings", titleEs: "Reuniones de trabajo", titleEn: "Work meetings"),
        StyleProfileOption(id: "office_days", titleEs: "Días de oficina", titleEn: "Office days"),
        StyleProfileOption(id: "client_meetings", titleEs: "Reuniones con clientes", titleEn: "Client meetings"),
        StyleProfileOption(id: "networking", titleEs: "Networking", titleEn: "Networking"),
        StyleProfileOption(id: "dinners", titleEs: "Cenas", titleEn: "Dinners"),
        StyleProfileOption(id: "date_nights", titleEs: "Citas", titleEn: "Date nights"),
        StyleProfileOption(id: "weekend_getaways", titleEs: "Escapadas", titleEn: "Weekend getaways"),
        StyleProfileOption(id: "travel", titleEs: "Viajes", titleEn: "Travel"),
        StyleProfileOption(id: "weddings", titleEs: "Bodas", titleEn: "Weddings"),
        StyleProfileOption(id: "family_events", titleEs: "Eventos familiares", titleEn: "Family events"),
        StyleProfileOption(id: "parties", titleEs: "Fiestas", titleEn: "Parties"),
        StyleProfileOption(id: "casual_weekends", titleEs: "Planes casuales", titleEn: "Casual weekends")
    ]

    static let styleIdentities: [StyleProfileOption] = [
        StyleProfileOption(id: "minimal", titleEs: "Minimalista", titleEn: "Minimal"),
        StyleProfileOption(id: "classic", titleEs: "Clásica", titleEn: "Classic"),
        StyleProfileOption(id: "elegant", titleEs: "Elegante", titleEn: "Elegant"),
        StyleProfileOption(id: "creative", titleEs: "Creativa", titleEn: "Creative"),
        StyleProfileOption(id: "casual", titleEs: "Casual", titleEn: "Casual"),
        StyleProfileOption(id: "relaxed", titleEs: "Relajada", titleEn: "Relaxed"),
        StyleProfileOption(id: "trendy", titleEs: "Tendencia", titleEn: "Trend-driven"),
        StyleProfileOption(id: "romantic", titleEs: "Romántica", titleEn: "Romantic"),
        StyleProfileOption(id: "sporty", titleEs: "Sport", titleEn: "Sporty"),
        StyleProfileOption(id: "statement", titleEs: "Con personalidad", titleEn: "Statement")
    ]

    static let impressionGoals: [StyleProfileOption] = [
        StyleProfileOption(id: "professional", titleEs: "Profesional", titleEn: "Professional"),
        StyleProfileOption(id: "approachable", titleEs: "Cercana", titleEn: "Approachable"),
        StyleProfileOption(id: "sophisticated", titleEs: "Sofisticada", titleEn: "Sophisticated"),
        StyleProfileOption(id: "creative", titleEs: "Creativa", titleEn: "Creative"),
        StyleProfileOption(id: "powerful", titleEs: "Segura", titleEn: "Powerful"),
        StyleProfileOption(id: "relaxed", titleEs: "Relajada", titleEn: "Relaxed"),
        StyleProfileOption(id: "modern", titleEs: "Actual", titleEn: "Modern"),
        StyleProfileOption(id: "timeless", titleEs: "Atemporal", titleEn: "Timeless")
    ]

    static let fitPriorities: [StyleProfileOption] = [
        StyleProfileOption(id: "comfort", titleEs: "Comodidad", titleEn: "Comfort"),
        StyleProfileOption(id: "polished", titleEs: "Verme pulida", titleEn: "Polished look"),
        StyleProfileOption(id: "versatility", titleEs: "Versatilidad", titleEn: "Versatility"),
        StyleProfileOption(id: "practicality", titleEs: "Practicidad", titleEn: "Practicality"),
        StyleProfileOption(id: "impact", titleEs: "Impacto visual", titleEn: "Visual impact"),
        StyleProfileOption(id: "quality", titleEs: "Calidad", titleEn: "Quality")
    ]

    private static let allOptions: [StyleProfileOption] =
        socialActivities + styleIdentities + impressionGoals + fitPriorities

    static func title(for id: String, in language: Language) -> String {
        allOptions.first(where: { $0.id == id })?.title(in: language) ?? id
    }
}
