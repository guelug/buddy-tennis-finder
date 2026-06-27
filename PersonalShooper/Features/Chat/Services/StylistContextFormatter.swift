import Foundation

/// Single source of truth for turning a `ChatContext` into the user-fact lines and closet payload
/// shared by Foundation Models, BYOK, and connected chat backends.
enum StylistContextFormatter {

    /// Stable, ordered facts about the user: name, gender, color palette, image-analysis notes
    /// (silhouette / face shape / contrast) and saved styling profile, plus the day's context.
    static func userFacts(for context: ChatContext) -> [String] {
        var lines: [String] = []

        if let name = context.preferredName, !name.isEmpty {
            lines.append("User name: \(name)")
        }
        if let gender = context.userGender {
            lines.append("The user is \(gender.stylingDescriptor).")
        }

        if let palette = context.userPalette {
            var line = "Personal color palette: \(palette.seasonalType.displayName), \(palette.undertone.displayName) undertone."
            let best = palette.recommendedColors.prefix(6).map(colorName).joined(separator: ", ")
            if !best.isEmpty { line += " Best colors near the face: \(best)." }
            if let neutrals = palette.neutralColors, !neutrals.isEmpty {
                line += " Best neutrals/base colors: \(neutrals.prefix(5).map(colorName).joined(separator: ", "))."
            }
            if let statements = palette.statementColors, !statements.isEmpty {
                line += " Statement/accent colors: \(statements.prefix(4).map(colorName).joined(separator: ", "))."
            }
            if let avoid = palette.colorsToAvoid, !avoid.isEmpty {
                line += " Avoid near the face: \(avoid.prefix(5).map(colorName).joined(separator: ", "))."
            }
            if let summary = palette.summary, !summary.isEmpty {
                line += " Expert palette note: \(summary)"
            }
            lines.append(line)
            lines.append("Color rule: prioritize the user's palette for tops, jackets, scarves, makeup and anything near the face; off-palette colors can still work in shoes, bags, belts or lower-body pieces.")
        }

        if let profile = context.personalStylingProfile {
            if let shape = profile.bodyShape ?? ImageConsulting.bodyShape(chestCm: profile.chestCm, waistCm: profile.waistCm, hipsCm: profile.hipsCm) {
                lines.append(ImageConsulting.bodyShapeNote(shape, language: context.language))
            }
            if let face = profile.faceShape {
                lines.append(ImageConsulting.faceShapeNote(face, language: context.language))
            }
            if let contrast = profile.contrastLevel {
                lines.append(ImageConsulting.contrastNote(contrast, language: context.language))
            }
            if let age = profile.age { lines.append("Age: \(age)") }
            if !profile.occupation.isEmpty { lines.append("Occupation: \(profile.occupation)") }
            if !profile.lifestyleSummary.isEmpty { lines.append("Routine: \(profile.lifestyleSummary)") }
            if !profile.usualSocialPlans.isEmpty { lines.append("Usual events: \(profile.usualSocialPlans.joined(separator: ", "))") }
            if !profile.preferredStyles.isEmpty { lines.append("Preferred styles: \(profile.preferredStyles.joined(separator: ", "))") }
            if !profile.desiredImpression.isEmpty { lines.append("Desired impression: \(profile.desiredImpression.joined(separator: ", "))") }
            if !profile.fitPriorities.isEmpty { lines.append("Fit priorities: \(profile.fitPriorities.joined(separator: ", "))") }
            if !profile.favoriteColors.isEmpty { lines.append("Favorite colors: \(profile.favoriteColors.joined(separator: ", "))") }
            if !profile.avoidColors.isEmpty { lines.append("Avoid colors: \(profile.avoidColors.joined(separator: ", "))") }
            if !profile.styleGoals.isEmpty { lines.append("Style goals: \(profile.styleGoals)") }
            if !profile.shoppingChallenges.isEmpty { lines.append("Shopping challenges: \(profile.shoppingChallenges)") }
            if !profile.additionalNotes.isEmpty { lines.append("Extra notes: \(profile.additionalNotes)") }
            if !profile.learnedStyleSummary.isEmpty { lines.append(profile.learnedStyleSummary) }
        }

        if let recommendation = context.dailyRecommendation,
           !recommendation.outfitFormula.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Today's suggested outfit formula (for reference, do not read it back verbatim): \(recommendation.outfitFormula)")
        }

        if !context.todayEvents.isEmpty {
            let events = context.todayEvents.prefix(3).map { "\($0.title) (\($0.timeWindowText))" }.joined(separator: ", ")
            lines.append("Today's synced events: \(events)")
        }

        if !context.closetItems.isEmpty {
            lines.append(wardrobeExpertBrief(for: context.closetItems, language: context.language))
        }

        return lines
    }

    /// The closet inventory as a compact JSON payload the model must treat as the only owned garments.
    static func closetContextLine(for items: [ClothingItemSummary]) -> String {
        guard !items.isEmpty else {
            return "closet_context JSON: {\"items\":[],\"instruction\":\"The user's closet is empty. Do not invent owned garments.\"}"
        }
        return "closet_context JSON: \(closetContextJSON(for: items))"
    }

    static func wardrobeSummary(for items: [ClothingItemSummary], language: Language) -> String {
        guard !items.isEmpty else {
            return language == .spanish
                ? "Tu armario está vacío. Añade prendas para que pueda analizar colores, categorías y huecos."
                : "Your closet is empty. Add garments so I can analyze colors, categories, and gaps."
        }

        let total = items.count
        let categoryText = topCounts(items.map { $0.category.displayName }, limit: 4).joined(separator: ", ")
        let colorText = topCounts(items.flatMap(\.colorTags), limit: 4).joined(separator: ", ")
        let favoriteCount = items.filter(\.isFavorite).count
        let neverWornCount = items.filter { $0.timesWorn == 0 }.count
        let gaps = categoryGaps(in: items).prefix(3).joined(separator: ", ")

        if language == .spanish {
            var parts = ["Tu armario tiene \(total) prendas"]
            if !categoryText.isEmpty { parts.append("categorías principales: \(categoryText)") }
            if !colorText.isEmpty { parts.append("colores dominantes: \(colorText)") }
            parts.append("favoritas: \(favoriteCount)")
            if neverWornCount > 0 { parts.append("sin usar: \(neverWornCount)") }
            if !gaps.isEmpty { parts.append("huecos útiles: \(gaps)") }
            return parts.joined(separator: ". ") + "."
        }

        var parts = ["Your closet has \(total) garments"]
        if !categoryText.isEmpty { parts.append("main categories: \(categoryText)") }
        if !colorText.isEmpty { parts.append("dominant colors: \(colorText)") }
        parts.append("favorites: \(favoriteCount)")
        if neverWornCount > 0 { parts.append("unworn: \(neverWornCount)") }
        if !gaps.isEmpty { parts.append("useful gaps: \(gaps)") }
        return parts.joined(separator: ". ") + "."
    }

    private static func closetContextJSON(for items: [ClothingItemSummary]) -> String {
        let payload = [
            "items": items.prefix(40).map { item in
                [
                    "id": item.id.uuidString,
                    "name": item.name,
                    "category": item.category.displayName,
                    "colors": item.colorTags,
                    "styles": item.styleTags,
                    "materials": item.materialTags,
                    "occasions": item.occasionTags,
                    "details": item.detailTags,
                    "brand": item.brandName ?? NSNull(),
                    "notes": item.notes ?? NSNull(),
                    "summary": item.metadataSummary ?? NSNull(),
                    "favorite": item.isFavorite,
                    "times_worn": item.timesWorn
                ] as [String: Any]
            },
            "analysis": [
                "summary": wardrobeSummary(for: items, language: .english),
                "category_gaps": Array(categoryGaps(in: items)),
                "dominant_colors": topCounts(items.flatMap(\.colorTags), limit: 8),
                "dominant_styles": topCounts(items.flatMap(\.styleTags), limit: 8),
                "dominant_occasions": topCounts(items.flatMap(\.occasionTags), limit: 8),
                "underused_items": items.filter { $0.timesWorn == 0 }.prefix(8).map(\.name),
                "favorites": items.filter(\.isFavorite).prefix(8).map(\.name)
            ] as [String: Any],
            "instruction": "Use only these items as owned garments. Use the analysis to discuss color balance, missing categories, overrepresented colors/styles, favorites, underused pieces, and practical next purchases. If owned garments do not match the request, say so and suggest the closest alternatives plus what to add."
        ] as [String: Any]

        guard
            let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
            let json = String(data: data, encoding: .utf8)
        else {
            return "{\"items\":[]}"
        }
        return json
    }

    private static func wardrobeExpertBrief(for items: [ClothingItemSummary], language: Language) -> String {
        let summary = wardrobeSummary(for: items, language: language)
        let favoriteItems = items.filter(\.isFavorite).prefix(5).map(\.name).joined(separator: ", ")
        let underusedItems = items.filter { $0.timesWorn == 0 }.prefix(5).map(\.name).joined(separator: ", ")
        let materials = topCounts(items.flatMap(\.materialTags), limit: 5).joined(separator: ", ")
        let occasions = topCounts(items.flatMap(\.occasionTags), limit: 5).joined(separator: ", ")

        var lines = ["Wardrobe expert brief: \(summary)"]
        if !favoriteItems.isEmpty { lines.append("Favorite garments to prioritize when suitable: \(favoriteItems).") }
        if !underusedItems.isEmpty { lines.append("Underused garments worth re-styling before buying more: \(underusedItems).") }
        if !materials.isEmpty { lines.append("Dominant materials: \(materials).") }
        if !occasions.isEmpty { lines.append("Occasion coverage: \(occasions).") }
        return lines.joined(separator: " ")
    }

    private static func topCounts(_ values: [String], limit: Int) -> [String] {
        let counts = Dictionary(grouping: values.map(normalizedToken).filter { !$0.isEmpty }, by: { $0 })
            .map { token, values in (token: token, count: values.count) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.token < rhs.token }
                return lhs.count > rhs.count
            }
        return counts.prefix(limit).map { "\($0.token) (\($0.count))" }
    }

    private static func categoryGaps(in items: [ClothingItemSummary]) -> [String] {
        let existing = Set(items.map(\.category))
        var gaps: [String] = []
        let essentials: [ClothingCategory] = [.tops, .bottoms, .shoes, .outerwear, .accessories]
        for category in essentials where !existing.contains(category) {
            gaps.append(category.displayName)
        }
        return gaps
    }

    private static func normalizedToken(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func colorName(_ color: CodableColor) -> String {
        if let name = color.name, !name.isEmpty { return name }
        let red = Int((color.red * 255).rounded())
        let green = Int((color.green * 255).rounded())
        let blue = Int((color.blue * 255).rounded())
        return "rgb(\(red), \(green), \(blue))"
    }
}
