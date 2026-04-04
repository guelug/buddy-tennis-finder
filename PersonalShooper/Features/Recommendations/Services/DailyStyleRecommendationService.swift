import Foundation

@MainActor
struct DailyStyleRecommendationService {
    func buildRecommendation(
        for user: User?,
        closetItems: [ClothingItem],
        events: [CalendarEventSnapshot],
        language: Language
    ) -> DailyStyleRecommendationSnapshot {
        let event = preferredEvent(from: events)
        let mood = moodTags(for: user, event: event, language: language)
        let closetHighlights = suggestedClosetItems(from: closetItems, event: event, profile: user?.personalStylingProfile)
        let paletteHints = paletteHints(for: user?.personalPalette, language: language)
        let profile = user?.personalStylingProfile ?? PersonalStylingProfile()

        let headline = headline(for: event, language: language)
        let contextLine = contextLine(for: event, profile: profile, language: language)
        let outfitFormula = outfitFormula(for: event, profile: profile, language: language)
        let colorDirection = colorDirection(
            event: event,
            profile: profile,
            paletteHints: paletteHints,
            language: language
        )
        let accessoryNote = accessoryNote(for: event, language: language)
        let spokenSummary = spokenSummary(
            headline: headline,
            contextLine: contextLine,
            outfitFormula: outfitFormula,
            language: language
        )

        return DailyStyleRecommendationSnapshot(
            generatedAt: Date(),
            headline: headline,
            eventTitle: event?.title,
            contextLine: contextLine,
            outfitFormula: outfitFormula,
            colorDirection: colorDirection,
            accessoryNote: accessoryNote,
            closetHighlightNames: closetHighlights,
            moodTags: mood,
            spokenSummary: spokenSummary
        )
    }

    private func preferredEvent(from events: [CalendarEventSnapshot]) -> CalendarEventSnapshot? {
        let now = Date()
        return events.first(where: { $0.endDate >= now }) ?? events.first
    }

    private func headline(for event: CalendarEventSnapshot?, language: Language) -> String {
        guard let event else {
            return language == .spanish ? "Recomendación diaria" : "Daily style recommendation"
        }

        if language == .spanish {
            return "Look para \(event.title)"
        }

        return "Look for \(event.title)"
    }

    private func contextLine(
        for event: CalendarEventSnapshot?,
        profile: PersonalStylingProfile,
        language: Language
    ) -> String {
        if let event {
            let timeText = event.isAllDay ? (language == .spanish ? "todo el día" : "all day") : event.timeWindowText
            let locationText = event.location.map { language == .spanish ? " en \($0)" : " at \($0)" } ?? ""
            return language == .spanish
                ? "Hoy tienes \(event.title) \(timeText)\(locationText)."
                : "You have \(event.title) \(timeText)\(locationText) today."
        }

        if !profile.lifestyleSummary.isEmpty {
            return language == .spanish
                ? "Hoy no hay eventos sincronizados, así que he priorizado tu rutina habitual."
                : "There are no synced events today, so I prioritized your usual routine."
        }

        return language == .spanish
            ? "Hoy no hay eventos sincronizados; te propongo un look versátil."
            : "There are no synced events today, so I suggest a versatile look."
    }

    private func outfitFormula(
        for event: CalendarEventSnapshot?,
        profile: PersonalStylingProfile,
        language: Language
    ) -> String {
        let impression = profile.desiredImpression.first.map { StyleProfileCatalog.title(for: $0, in: language).lowercased() }
        let priorities = profile.fitPriorities.prefix(2).map { StyleProfileCatalog.title(for: $0, in: language).lowercased() }
        let priorityText = priorities.joined(separator: language == .spanish ? " y " : " and ")

        let baseFormula: String
        switch eventCategory(for: event?.title) {
        case .work:
            baseFormula = language == .spanish
                ? "Base pulida con capa ligera, silueta limpia y acabados profesionales."
                : "Polished base with a light layer, clean silhouette, and professional finish."
        case .social:
            baseFormula = language == .spanish
                ? "Prenda principal con personalidad, textura suave y un punto sofisticado."
                : "A statement main piece, soft texture, and a sophisticated finish."
        case .formal:
            baseFormula = language == .spanish
                ? "Línea elegante, tejido elevado y accesorios contenidos."
                : "Elegant line, elevated fabric, and restrained accessories."
        case .active:
            baseFormula = language == .spanish
                ? "Capas cómodas, tejido funcional y calzado práctico."
                : "Comfortable layers, functional fabric, and practical footwear."
        case .none:
            baseFormula = language == .spanish
                ? "Base versátil que funcione para trabajo, recados y cambios de plan."
                : "A versatile base that works for work, errands, and shifting plans."
        }

        if let impression, !priorityText.isEmpty {
            return language == .spanish
                ? "\(baseFormula) Busca verte \(impression) sin perder \(priorityText)."
                : "\(baseFormula) Aim to look \(impression) without losing \(priorityText)."
        }

        if let impression {
            return language == .spanish
                ? "\(baseFormula) Prioriza una imagen \(impression)."
                : "\(baseFormula) Prioritize a \(impression) image."
        }

        if !priorityText.isEmpty {
            return language == .spanish
                ? "\(baseFormula) Mantén foco en \(priorityText)."
                : "\(baseFormula) Keep the focus on \(priorityText)."
        }

        return baseFormula
    }

    private func colorDirection(
        event: CalendarEventSnapshot?,
        profile: PersonalStylingProfile,
        paletteHints: [String],
        language: Language
    ) -> String {
        let favoriteColors = profile.favoriteColors.prefix(2).joined(separator: ", ")
        let avoidColors = profile.avoidColors.prefix(2).joined(separator: ", ")
        let paletteText = paletteHints.prefix(2).joined(separator: language == .spanish ? " y " : " and ")

        switch eventCategory(for: event?.title) {
        case .work:
            return language == .spanish
                ? "Color: parte de neutros refinados y añade un acento en \(paletteText.ifEmpty(language == .spanish ? "tu mejor paleta" : "your palette"))."
                : "Color: start with refined neutrals and add one accent in \(paletteText.ifEmpty("your best palette"))."
        case .social, .formal:
            return language == .spanish
                ? "Color: usa profundidad y contraste moderado; \(favoriteColors.isEmpty ? "apóyate en tu paleta." : "si te apetece, incorpora \(favoriteColors).")"
                : "Color: use depth and moderate contrast; \(favoriteColors.isEmpty ? "lean on your palette." : "if you like, bring in \(favoriteColors).")"
        case .active, .none:
            let avoidText = avoidColors.isEmpty
                ? (language == .spanish ? "" : "")
                : (language == .spanish ? " Evita \(avoidColors) si quieres sentirte más alineada." : " Avoid \(avoidColors) if you want to feel more aligned.")
            return language == .spanish
                ? "Color: mantén una base fácil de repetir y deja el interés en un tono que ya te favorece.\(avoidText)"
                : "Color: keep an easy-to-repeat base and place the interest in a tone that already flatters you.\(avoidText)"
        }
    }

    private func accessoryNote(for event: CalendarEventSnapshot?, language: Language) -> String {
        switch eventCategory(for: event?.title) {
        case .work:
            return language == .spanish
                ? "Accesorios: bolso estructurado, reloj o pendientes discretos."
                : "Accessories: structured bag, watch, or discreet earrings."
        case .social:
            return language == .spanish
                ? "Accesorios: un punto especial, pero sin competir con la prenda principal."
                : "Accessories: one special touch, without competing with the main piece."
        case .formal:
            return language == .spanish
                ? "Accesorios: metal limpio, zapato cuidado y abrigo con caída."
                : "Accessories: clean metal, polished shoes, and a coat with drape."
        case .active:
            return language == .spanish
                ? "Accesorios: lo justo y funcional; prioridad total a comodidad."
                : "Accessories: minimal and functional; comfort comes first."
        case .none:
            return language == .spanish
                ? "Accesorios: busca piezas que eleven sin restar versatilidad."
                : "Accessories: choose pieces that elevate without reducing versatility."
        }
    }

    private func moodTags(
        for user: User?,
        event: CalendarEventSnapshot?,
        language: Language
    ) -> [String] {
        var tags: [String] = []
        let profile = user?.personalStylingProfile ?? PersonalStylingProfile()

        if let event {
            tags.append(eventCategory(for: event.title).tag(language: language))
        }

        tags.append(contentsOf: profile.desiredImpression.prefix(2).map { StyleProfileCatalog.title(for: $0, in: language) })
        tags.append(contentsOf: profile.fitPriorities.prefix(2).map { StyleProfileCatalog.title(for: $0, in: language) })

        return Array(Set(tags)).prefix(4).map { $0 }
    }

    private func suggestedClosetItems(
        from items: [ClothingItem],
        event: CalendarEventSnapshot?,
        profile: PersonalStylingProfile?
    ) -> [String] {
        guard !items.isEmpty else { return [] }

        let categories = targetCategories(for: eventCategory(for: event?.title))
        let preferredStyles = Set(profile?.preferredStyles ?? [])

        let filtered = items.filter { item in
            categories.contains(item.category) ||
            !preferredStyles.isDisjoint(with: Set(item.styleTags))
        }

        let sorted = (filtered.isEmpty ? items : filtered)
            .sorted {
                ($0.isFavorite ? 1 : 0, $0.timesWorn) > ($1.isFavorite ? 1 : 0, $1.timesWorn)
            }

        return Array(sorted.prefix(3).map(\.name))
    }

    private func targetCategories(for category: EventCategory) -> Set<ClothingCategory> {
        switch category {
        case .work:
            return [.tops, .bottoms, .outerwear, .accessories, .shoes]
        case .social:
            return [.dresses, .tops, .bottoms, .accessories, .shoes]
        case .formal:
            return [.dresses, .outerwear, .shoes, .accessories]
        case .active:
            return [.activewear, .shoes, .outerwear]
        case .none:
            return [.tops, .bottoms, .outerwear, .shoes]
        }
    }

    private func paletteHints(for palette: PersonalPalette?, language: Language) -> [String] {
        guard let palette else { return [] }

        return palette.recommendedColors.prefix(3).map {
            colorName(for: $0, language: language)
        }
    }

    private func colorName(for color: CodableColor, language: Language) -> String {
        let r = color.red
        let g = color.green
        let b = color.blue

        let english: String
        if r > 0.7 && g < 0.4 && b < 0.4 { english = "red" }
        else if r > 0.8 && g > 0.7 && b > 0.7 { english = "soft ivory" }
        else if r < 0.4 && g < 0.5 && b > 0.7 { english = "blue" }
        else if r < 0.4 && g > 0.5 && b < 0.4 { english = "green" }
        else if r > 0.7 && g > 0.6 && b > 0.5 { english = "beige" }
        else if r > 0.5 && g > 0.5 && b > 0.5 { english = "gray" }
        else { english = "neutral" }

        guard language == .spanish else { return english }

        switch english {
        case "red": return "rojo"
        case "soft ivory": return "marfil suave"
        case "blue": return "azul"
        case "green": return "verde"
        case "beige": return "beige"
        case "gray": return "gris"
        default: return "neutral"
        }
    }

    private func spokenSummary(
        headline: String,
        contextLine: String,
        outfitFormula: String,
        language: Language
    ) -> String {
        if language == .spanish {
            return "\(headline). \(contextLine) \(outfitFormula)"
        }
        return "\(headline). \(contextLine) \(outfitFormula)"
    }

    private func eventCategory(for title: String?) -> EventCategory {
        guard let title = title?.lowercased() else { return .none }

        if title.contains("meeting") || title.contains("reunion") || title.contains("reunión") || title.contains("office") || title.contains("trabajo") || title.contains("client") {
            return .work
        }

        if title.contains("wedding") || title.contains("boda") || title.contains("gala") || title.contains("ceremony") {
            return .formal
        }

        if title.contains("gym") || title.contains("workout") || title.contains("pilates") || title.contains("entreno") {
            return .active
        }

        if title.contains("dinner") || title.contains("cena") || title.contains("party") || title.contains("fiesta") || title.contains("date") || title.contains("evento") {
            return .social
        }

        return .none
    }
}

private enum EventCategory {
    case work
    case social
    case formal
    case active
    case none

    func tag(language: Language) -> String {
        switch (self, language) {
        case (.work, .spanish): return "Trabajo"
        case (.social, .spanish): return "Social"
        case (.formal, .spanish): return "Formal"
        case (.active, .spanish): return "Activo"
        case (.none, .spanish): return "Versátil"
        case (.work, .english): return "Work"
        case (.social, .english): return "Social"
        case (.formal, .english): return "Formal"
        case (.active, .english): return "Active"
        case (.none, .english): return "Versatile"
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
