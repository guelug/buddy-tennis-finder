import Foundation

/// Single source of truth for turning a `ChatContext` into the user-fact lines and closet payload
/// shared by the network chat backends (BYOK + connected). Previously each service rebuilt these
/// slightly differently, which let them drift (e.g. the connected path omitted the color palette).
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
            let best = palette.recommendedColors.prefix(6).compactMap(\.name).joined(separator: ", ")
            if !best.isEmpty { line += " Best colors: \(best)." }
            if let neutrals = palette.neutralColors, !neutrals.isEmpty {
                line += " Neutrals: \(neutrals.prefix(4).compactMap(\.name).joined(separator: ", "))."
            }
            if let statements = palette.statementColors, !statements.isEmpty {
                line += " Statement colors: \(statements.prefix(3).compactMap(\.name).joined(separator: ", "))."
            }
            if let avoid = palette.colorsToAvoid, !avoid.isEmpty {
                line += " Colors to avoid: \(avoid.prefix(3).compactMap(\.name).joined(separator: ", "))."
            }
            lines.append(line)
            lines.append("Favor the user's best colors and avoid recommending their unflattering colors.")
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

        return lines
    }

    /// The closet inventory as a compact JSON payload the model must treat as the only owned garments.
    static func closetContextLine(for items: [ClothingItemSummary]) -> String {
        guard !items.isEmpty else {
            return "closet_context JSON: {\"items\":[],\"instruction\":\"The user's closet is empty. Do not invent owned garments.\"}"
        }
        return "closet_context JSON: \(closetContextJSON(for: items))"
    }

    private static func closetContextJSON(for items: [ClothingItemSummary]) -> String {
        let payload = [
            "items": items.prefix(30).map { item in
                [
                    "id": item.id.uuidString,
                    "name": item.name,
                    "category": item.category.displayName,
                    "colors": item.colorTags,
                    "styles": item.styleTags
                ] as [String: Any]
            },
            "instruction": "Use only these items as owned garments. If they do not match the user request, say so and suggest additions."
        ] as [String: Any]

        guard
            let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
            let json = String(data: data, encoding: .utf8)
        else {
            return "{\"items\":[]}"
        }
        return json
    }
}
