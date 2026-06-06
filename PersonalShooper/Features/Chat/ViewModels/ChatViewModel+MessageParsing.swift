import Foundation
import UIKit

// Pure text- and media-parsing helpers split out of ChatViewModel to keep the view model
// focused on orchestration. These touch no instance state; they only transform inputs.
extension ChatViewModel {
    func extractName(from message: String) -> String? {
        let phrases = ["me llamo ", "mi nombre es ", "my name is ", "call me "]

        for phrase in phrases {
            if let value = extractClause(after: phrase, in: message) {
                return normalizedName(value)
            }
        }

        return nil
    }

    func extractAge(from message: String) -> Int? {
        let patterns = [
            #"(?:tengo|cumplo|i am|i'm)\s+(\d{1,2})\b"#,
            #"(\d{1,2})\s*(?:años|anos|years?\sold)"#
        ]

        for pattern in patterns {
            if let match = firstCapture(in: message, pattern: pattern),
               let age = Int(match),
               (13...99).contains(age) {
                return age
            }
        }

        return nil
    }

    func extractGender(from message: String) -> StyleGender? {
        let female = ["soy mujer", "soy una mujer", "soy chica", "soy una chica", "soy femenina", "i'm a woman", "i am a woman", "i'm female"]
        let male = ["soy hombre", "soy un hombre", "soy chico", "soy un chico", "soy masculino", "i'm a man", "i am a man", "i'm male"]

        if containsAny(female, in: message) { return .female }
        if containsAny(male, in: message) { return .male }
        return nil
    }

    func extractOccupation(from message: String) -> String? {
        let phrases = [
            "trabajo como ",
            "trabajo en ",
            "me dedico a ",
            "i work as ",
            "i work in ",
            "my job is "
        ]

        for phrase in phrases {
            if let clause = extractClause(after: phrase, in: message) {
                return normalizedSentence(clause)
            }
        }

        return nil
    }

    func extractLifestyleSummary(from message: String) -> String? {
        let phrases = [
            "mi dia a dia es ",
            "mi día a día es ",
            "suelo vestir ",
            "normalmente voy ",
            "my day to day is ",
            "my routine is ",
            "i usually dress "
        ]

        for phrase in phrases {
            if let clause = extractClause(after: phrase, in: message) {
                return normalizedSentence(clause)
            }
        }

        return nil
    }

    func extractStyleGoals(from message: String) -> String? {
        let phrases = [
            "quiero verme ",
            "quiero mejorar ",
            "me gustaria ",
            "me gustaría ",
            "i want to look ",
            "i want to improve ",
            "i'd like to "
        ]

        guard containsStyleIntent(in: message) else { return nil }

        for phrase in phrases {
            if let clause = extractClause(after: phrase, in: message) {
                return normalizedSentence(clause)
            }
        }

        return nil
    }

    func extractShoppingChallenge(from message: String) -> String? {
        let phrases = [
            "me cuesta ",
            "siempre me pasa ",
            "mi problema es ",
            "i struggle with ",
            "my problem is ",
            "i find it hard to "
        ]

        for phrase in phrases {
            if let clause = extractClause(after: phrase, in: message) {
                return normalizedSentence(clause)
            }
        }

        return nil
    }

    func detectSocialPlanMatches(in message: String) -> [String] {
        let mappings: [(String, String)] = [
            ("reuniones", "work_meetings"),
            ("meeting", "work_meetings"),
            ("oficina", "office_days"),
            ("office", "office_days"),
            ("clientes", "client_meetings"),
            ("client", "client_meetings"),
            ("networking", "networking"),
            ("cenas", "dinners"),
            ("dinner", "dinners"),
            ("citas", "date_nights"),
            ("date", "date_nights"),
            ("escapadas", "weekend_getaways"),
            ("getaway", "weekend_getaways"),
            ("viajes", "travel"),
            ("travel", "travel"),
            ("bodas", "weddings"),
            ("wedding", "weddings"),
            ("familiares", "family_events"),
            ("family", "family_events"),
            ("fiestas", "parties"),
            ("party", "parties"),
            ("casuales", "casual_weekends"),
            ("weekend", "casual_weekends")
        ]

        return detectedOptionIDs(in: message, mappings: mappings)
    }

    func detectNegativeSocialPlanMatches(in message: String) -> [String] {
        guard containsAny(
            ["ya no", "no suelo", "no voy", "i no longer", "i don't", "i do not"],
            in: message
        ) else {
            return []
        }

        return detectSocialPlanMatches(in: message)
    }

    func shouldClearAllEvents(in message: String) -> Bool {
        containsAny(
            [
                "ya no voy a eventos",
                "ya no hago eventos",
                "no voy a eventos",
                "i no longer go to events",
                "i don't go to events"
            ],
            in: message
        )
    }

    func detectStyleMatches(in message: String) -> [String] {
        let mappings: [(String, String)] = [
            ("minimalista", "minimal"),
            ("minimal", "minimal"),
            ("clasica", "classic"),
            ("clásica", "classic"),
            ("classic", "classic"),
            ("elegante", "elegant"),
            ("elegant", "elegant"),
            ("creativa", "creative"),
            ("creative", "creative"),
            ("casual", "casual"),
            ("relajada", "relaxed"),
            ("relaxed", "relaxed"),
            ("tendencia", "trendy"),
            ("trendy", "trendy"),
            ("romantica", "romantic"),
            ("romántica", "romantic"),
            ("romantic", "romantic"),
            ("sport", "sporty"),
            ("sporty", "sporty"),
            ("personalidad", "statement"),
            ("statement", "statement")
        ]

        return detectedOptionIDs(in: message, mappings: mappings)
    }

    func detectImpressionMatches(in message: String) -> [String] {
        let mappings: [(String, String)] = [
            ("profesional", "professional"),
            ("professional", "professional"),
            ("cercana", "approachable"),
            ("approachable", "approachable"),
            ("sofisticada", "sophisticated"),
            ("sophisticated", "sophisticated"),
            ("creativa", "creative"),
            ("creative", "creative"),
            ("segura", "powerful"),
            ("powerful", "powerful"),
            ("relajada", "relaxed"),
            ("relaxed", "relaxed"),
            ("actual", "modern"),
            ("modern", "modern"),
            ("atemporal", "timeless"),
            ("timeless", "timeless")
        ]

        return detectedOptionIDs(in: message, mappings: mappings)
    }

    func detectPriorityMatches(in message: String) -> [String] {
        let mappings: [(String, String)] = [
            ("comodidad", "comfort"),
            ("comfort", "comfort"),
            ("pulida", "polished"),
            ("polished", "polished"),
            ("versatil", "versatility"),
            ("versátil", "versatility"),
            ("versatility", "versatility"),
            ("practicidad", "practicality"),
            ("practical", "practicality"),
            ("impacto", "impact"),
            ("impact", "impact"),
            ("calidad", "quality"),
            ("quality", "quality")
        ]

        return detectedOptionIDs(in: message, mappings: mappings)
    }

    func applyColorPreferences(
        from message: String,
        profile: PersonalStylingProfile
    ) -> (
        favoriteColors: [String],
        avoidColors: [String],
        addedFavoriteColors: [String],
        addedAvoidColors: [String]
    ) {
        var favoriteColors = profile.favoriteColors
        var avoidColors = profile.avoidColors
        var addedFavoriteColors: [String] = []
        var addedAvoidColors: [String] = []

        let colors = detectedColors(in: message)

        if containsAny(["me gusta", "me gustan", "mi color", "i like", "my favorite"], in: message) {
            for color in colors where !favoriteColors.contains(color) {
                favoriteColors.append(color)
                addedFavoriteColors.append(color)
            }
        }

        if containsAny(["evito", "no me gusta", "odio", "avoid", "don't like"], in: message) {
            for color in colors where !avoidColors.contains(color) {
                avoidColors.append(color)
                addedAvoidColors.append(color)
            }
        }

        return (favoriteColors, avoidColors, addedFavoriteColors, addedAvoidColors)
    }

    func detectedOptionIDs(in message: String, mappings: [(String, String)]) -> [String] {
        var results: [String] = []

        for (keyword, id) in mappings where message.localizedCaseInsensitiveContains(keyword) && !results.contains(id) {
            results.append(id)
        }

        return results
    }

    func detectedColors(in message: String) -> [String] {
        let colors = [
            "negro", "blanco", "gris", "azul", "azul marino", "verde", "oliva",
            "burdeos", "rojo", "rosa", "beige", "camel", "crema", "marrón",
            "black", "white", "gray", "blue", "navy", "green", "olive",
            "burgundy", "red", "pink", "beige", "camel", "cream", "brown"
        ]

        var result: [String] = []
        for color in colors where message.localizedCaseInsensitiveContains(color) && !result.contains(color) {
            result.append(color)
        }
        return result
    }

    func shouldAddAttachedGarmentToCloset(in message: String) -> Bool {
        containsAny(
            [
                "añade al armario",
                "añadela al armario",
                "añádela al armario",
                "añade al closet",
                "añádela al closet",
                "guardar en el armario",
                "guardar en el closet",
                "he comprado",
                "compré",
                "add to closet",
                "add it to my closet",
                "save to closet",
                "i bought",
                "put it in my wardrobe"
            ],
            in: message
        )
    }

    func detectCategoryFromText(_ message: String) -> ClothingCategory? {
        let mappings: [(String, ClothingCategory)] = [
            ("blazer", .outerwear),
            ("chaqueta", .outerwear),
            ("jacket", .outerwear),
            ("coat", .outerwear),
            ("abrigo", .outerwear),
            ("vestido", .dresses),
            ("dress", .dresses),
            ("falda", .bottoms),
            ("skirt", .bottoms),
            ("pantal", .bottoms),
            ("jean", .bottoms),
            ("trouser", .bottoms),
            ("shirt", .tops),
            ("camisa", .tops),
            ("top", .tops),
            ("blusa", .tops),
            ("shoe", .shoes),
            ("zapato", .shoes),
            ("zapatilla", .shoes),
            ("bolso", .accessories),
            ("bag", .accessories),
            ("hat", .accessories),
            ("gorro", .accessories),
            ("gym", .activewear),
            ("legging", .activewear),
            ("bikini", .swimwear),
            ("swimsuit", .swimwear),
            ("bañador", .swimwear)
        ]

        for (keyword, category) in mappings where message.localizedCaseInsensitiveContains(keyword) {
            return category
        }

        return nil
    }

    func extractClothingNameForCloset(from message: String, category: ClothingCategory, language: Language) -> String {
        let phrases = [
            "he comprado una ",
            "he comprado un ",
            "compré una ",
            "compre una ",
            "compré un ",
            "compre un ",
            "i bought a ",
            "i bought an ",
            "add this to my closet as ",
            "save this to closet as "
        ]

        for phrase in phrases {
            if let clause = extractClause(after: phrase, in: message) {
                let cleaned = sanitizeClothingNameClause(clause)
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }

        return defaultClothingName(for: category, language: language)
    }

    func sanitizeClothingNameClause(_ clause: String) -> String {
        let separators = [
            " y añad", " y guard", " para el armario", " para el closet",
            " and add", " and save", " to my closet", " in my wardrobe"
        ]

        var result = clause
        for separator in separators {
            if let range = result.range(of: separator, options: [.caseInsensitive, .diacriticInsensitive]) {
                result = String(result[..<range.lowerBound])
            }
        }

        return normalizedSentence(
            result.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        )
    }

    func defaultClothingName(for category: ClothingCategory, language: Language) -> String {
        switch (category, language) {
        case (.tops, .spanish): return "Parte de arriba"
        case (.bottoms, .spanish): return "Parte de abajo"
        case (.dresses, .spanish): return "Vestido"
        case (.shoes, .spanish): return "Zapatos"
        case (.accessories, .spanish): return "Accesorio"
        case (.outerwear, .spanish): return "Chaqueta o abrigo"
        case (.activewear, .spanish): return "Ropa deportiva"
        case (.swimwear, .spanish): return "Prenda de baño"
        case (.tops, .english): return "Top"
        case (.bottoms, .english): return "Bottom"
        case (.dresses, .english): return "Dress"
        case (.shoes, .english): return "Shoes"
        case (.accessories, .english): return "Accessory"
        case (.outerwear, .english): return "Outerwear"
        case (.activewear, .english): return "Activewear"
        case (.swimwear, .english): return "Swimwear"
        case (.jewelry, .spanish): return "Joyería"
        case (.lingerie, .spanish): return "Lencería"
        case (.beauty, .spanish): return "Belleza"
        case (.jewelry, .english): return "Jewelry"
        case (.lingerie, .english): return "Lingerie"
        case (.beauty, .english): return "Beauty"
        }
    }

    func compressAttachedImage(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1024
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func containsStyleIntent(in message: String) -> Bool {
        containsAny(
            [
                "estilo", "vestir", "imagen", "armario", "outfit", "look",
                "style", "dress", "wardrobe"
            ],
            in: message
        )
    }

    func containsAny(_ phrases: [String], in message: String) -> Bool {
        phrases.contains(where: { message.localizedCaseInsensitiveContains($0) })
    }

    func extractClause(after phrase: String, in text: String) -> String? {
        guard let range = text.range(of: phrase, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return nil
        }

        let remainder = String(text[range.upperBound...])
        let fragment = remainder
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) ?? ""

        return fragment.isEmpty ? nil : fragment
    }

    func normalizedName(_ value: String) -> String {
        value
            .split(separator: " ")
            .prefix(2)
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    func normalizedSentence(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return trimmed }
        return first.uppercased() + trimmed.dropFirst()
    }

    func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[range])
    }
}
