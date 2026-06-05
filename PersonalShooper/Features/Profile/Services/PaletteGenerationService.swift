import Foundation
import FoundationModels

/// Turns a raw skin analysis into an expert, personal-shopper-grade color palette: flattering
/// garment colors (with names), versatile neutrals, statement colors, colors to avoid, and a short
/// explanation. Uses on-device Apple Intelligence (iOS 26+) when available, with a rich rule-based
/// fallback so the result is always far more useful than raw skin-tone swatches.
@MainActor
final class PaletteGenerationService {

    private let ruleBasedExtractor = SkinToneExtractor()

    func generatePalette(
        from analysis: SkinAnalysisResult,
        language: Language,
        preferences: PalettePreferences = PalettePreferences()
    ) async -> PersonalPalette {
        // Prefer the precise 3-axis (depth × undertone × clarity) classification computed by the
        // CIELAB/ITA° pipeline; fall back to the 2-axis mapping for analyses saved before it existed.
        let seasonalType = analysis.seasonalType ?? ruleBasedExtractor.seasonalType(
            undertone: analysis.undertone,
            skinTone: analysis.skinToneCategory
        )

        var result: PersonalPalette
        if #available(iOS 26.0, *),
           let aiPalette = await generateWithAI(
            seasonalType: seasonalType,
            analysis: analysis,
            language: language,
            preferences: preferences
           ) {
            result = aiPalette
        } else {
            result = ruleBasedPalette(seasonalType: seasonalType, undertone: analysis.undertone, language: language)
        }

        // Always honor what the user told us regardless of which engine produced the palette: the
        // person knows colors they look great in better than an automatic skin read does.
        return applyPreferences(preferences, to: result, language: language)
    }

    /// Forces the user's loved colors into the recommended set (and out of "avoid"), and pushes
    /// disliked colors into "avoid" (and out of the recommended/neutral/statement sets).
    private func applyPreferences(
        _ preferences: PalettePreferences,
        to palette: PersonalPalette,
        language: Language
    ) -> PersonalPalette {
        guard !preferences.isEmpty else { return palette }

        let loved = preferences.lovedChoices.compactMap { CodableColor(hex: $0.hex, name: $0.name(in: language)) }
        let disliked = preferences.dislikedChoices.compactMap { CodableColor(hex: $0.hex, name: $0.name(in: language)) }

        // Remove colors visually similar to any reference color (catches e.g. White vs near-white).
        func without(_ colors: [CodableColor]?, similarTo refs: [CodableColor]) -> [CodableColor] {
            (colors ?? []).filter { color in !refs.contains { Self.isSimilar($0, color) } }
        }

        // Recommended = loved colors first, then existing best (minus disliked, minus near-duplicates of loved).
        var recommended = loved
        for color in without(palette.recommendedColors, similarTo: disliked) where !loved.contains(where: { Self.isSimilar($0, color) }) {
            recommended.append(color)
        }

        let neutrals = without(palette.neutralColors, similarTo: disliked)
        let statements = without(palette.statementColors, similarTo: disliked)

        // Avoid = disliked colors first, then existing avoid (minus anything similar to a loved color).
        var avoid = disliked
        for color in without(palette.colorsToAvoid, similarTo: loved) where !disliked.contains(where: { Self.isSimilar($0, color) }) {
            avoid.append(color)
        }

        return PersonalPalette(
            seasonalType: palette.seasonalType,
            undertone: palette.undertone,
            recommendedColors: recommended.isEmpty ? palette.recommendedColors : recommended,
            createdAt: palette.createdAt,
            summary: palette.summary,
            neutralColors: neutrals.isEmpty ? palette.neutralColors : neutrals,
            statementColors: statements.isEmpty ? palette.statementColors : statements,
            colorsToAvoid: avoid.isEmpty ? nil : avoid
        )
    }

    // MARK: - AI generation (iOS 26+)

    @available(iOS 26.0, *)
    private func generateWithAI(
        seasonalType: SeasonalType,
        analysis: SkinAnalysisResult,
        language: Language,
        preferences: PalettePreferences
    ) async -> PersonalPalette? {
        let model = SystemLanguageModel.default
        guard model.isAvailable else { return nil }

        let session = LanguageModelSession(
            model: model,
            instructions: Self.instructions(language: language)
        )

        let prompt = Self.prompt(seasonalType: seasonalType, analysis: analysis, language: language, preferences: preferences)

        do {
            let result = try await session.respond(
                to: prompt,
                generating: GeneratedPalette.self,
                options: GenerationOptions(temperature: 0.6)
            ).content

            let palette = Self.palette(from: result, seasonalType: seasonalType, undertone: analysis.undertone)
            // If the model produced no usable colors, fall back to the curated library.
            return palette.recommendedColors.isEmpty ? nil : palette
        } catch {
            return nil
        }
    }

    @available(iOS 26.0, *)
    private static func instructions(language: Language) -> String {
        let lang = language == .spanish ? "español" : "English"
        return [
            "You are an expert personal color analyst and stylist (12-season color theory).",
            "Given a person's undertone, depth, and seasonal type, you recommend flattering CLOTHING colors — not skin colors.",
            "Recommend real, wearable garment colors: jewel tones, navies, ivories, denims, knit colors, etc.",
            "Always return valid hex colors (#RRGGBB).",
            "Write color names and the summary in \(lang).",
            "Favor colors that make the person look radiant near the face; avoid muddy or washed-out picks."
        ].joined(separator: "\n")
    }

    @available(iOS 26.0, *)
    private static func prompt(
        seasonalType: SeasonalType,
        analysis: SkinAnalysisResult,
        language: Language,
        preferences: PalettePreferences
    ) -> String {
        var lines = [
            "Create a personal color palette.",
            "Seasonal type: \(seasonalType.displayName).",
            "Undertone: \(analysis.undertone.displayName).",
            "Skin depth: \(analysis.skinToneCategory.displayName)."
        ]
        if !analysis.dominantColors.isEmpty {
            let swatches = analysis.dominantColors.prefix(3).map { hexString($0) }.joined(separator: ", ")
            lines.append("Sampled skin tones (for context only, do NOT recommend these): \(swatches).")
        }

        // Ground the model in the season's professional wardrobe direction so it personalizes within
        // the right family instead of drifting. These are real garment colors, never skin tones.
        let recipe = NamedPaletteLibrary.recipe(for: seasonalType)
        let anchors = (recipe.best + recipe.statements)
            .prefix(7)
            .map { "\($0.1) \($0.0)" }
            .joined(separator: ", ")
        if !anchors.isEmpty {
            lines.append("Professional anchor garment colors for a \(seasonalType.displayName) (stay within this family; you may refine or vary the exact shades, but keep the same temperature, depth and clarity): \(anchors).")
        }
        let avoidAnchors = recipe.avoid.map { $0.1 }.joined(separator: ", ")
        if !avoidAnchors.isEmpty {
            lines.append("Colors that typically wash out a \(seasonalType.displayName): \(avoidAnchors).")
        }

        // The user's self-reported experience outranks the automatic skin read.
        let loved = preferences.lovedChoices.map { $0.name(in: .english) }
        if !loved.isEmpty {
            lines.append("IMPORTANT: the user says they look great in and get compliments on: \(loved.joined(separator: ", ")). Treat these as flattering and include them (or close variants) among the best/neutral/statement colors. Do NOT put them in colors-to-avoid.")
        }
        let disliked = preferences.dislikedChoices.map { $0.name(in: .english) }
        if !disliked.isEmpty {
            lines.append("The user dislikes or feels washed out in: \(disliked.joined(separator: ", ")). Avoid recommending these.")
        }
        let notes = preferences.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            lines.append("Extra note from the user: \(notes)")
        }

        lines.append("Return 6 best flattering garment colors, 4 versatile neutrals, 3 bold statement colors, and 3 colors to avoid.")
        lines.append("Add a 1–2 sentence summary explaining why these work, in \(language == .spanish ? "Spanish" : "English").")
        return lines.joined(separator: "\n")
    }

    @available(iOS 26.0, *)
    private static func palette(
        from generated: GeneratedPalette,
        seasonalType: SeasonalType,
        undertone: Undertone
    ) -> PersonalPalette {
        let best = generated.bestColors.compactMap(codableColor(from:))
        let neutrals = generated.neutralColors.compactMap(codableColor(from:))
        let statements = generated.statementColors.compactMap(codableColor(from:))
        let avoid = generated.colorsToAvoid.compactMap(codableColor(from:))

        // If the model returned nothing usable, signal failure so we fall back to rules.
        guard !best.isEmpty else {
            return PersonalPalette(seasonalType: seasonalType, undertone: undertone, recommendedColors: [])
        }

        return PersonalPalette(
            seasonalType: seasonalType,
            undertone: undertone,
            recommendedColors: best,
            summary: generated.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            neutralColors: neutrals.isEmpty ? nil : neutrals,
            statementColors: statements.isEmpty ? nil : statements,
            colorsToAvoid: avoid.isEmpty ? nil : avoid
        )
    }

    @available(iOS 26.0, *)
    private static func codableColor(from generated: GeneratedColor) -> CodableColor? {
        CodableColor(hex: generated.hex, name: generated.name.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func hexString(_ color: CodableColor) -> String {
        let r = Int((color.red * 255).rounded())
        let g = Int((color.green * 255).rounded())
        let b = Int((color.blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Euclidean RGB distance; two colors within the threshold are treated as the "same" color so a
    /// user's loved/disliked pick overrides near-duplicates produced by the AI or the library.
    private static func isSimilar(_ a: CodableColor, _ b: CodableColor, threshold: Double = 0.16) -> Bool {
        let dr = a.red - b.red, dg = a.green - b.green, db = a.blue - b.blue
        return (dr * dr + dg * dg + db * db).squareRoot() <= threshold
    }

    // MARK: - Rich rule-based fallback

    private func ruleBasedPalette(seasonalType: SeasonalType, undertone: Undertone, language: Language) -> PersonalPalette {
        let recipe = NamedPaletteLibrary.recipe(for: seasonalType)
        let isSpanish = language == .spanish

        func swatches(_ entries: [(String, String, String)]) -> [CodableColor] {
            entries.compactMap { hex, en, es in
                CodableColor(hex: hex, name: isSpanish ? es : en)
            }
        }

        return PersonalPalette(
            seasonalType: seasonalType,
            undertone: undertone,
            recommendedColors: swatches(recipe.best),
            summary: isSpanish ? recipe.summaryEs : recipe.summaryEn,
            neutralColors: swatches(recipe.neutrals),
            statementColors: swatches(recipe.statements),
            colorsToAvoid: swatches(recipe.avoid)
        )
    }
}

// MARK: - Guided generation schema (iOS 26+)

@available(iOS 26.0, *)
@Generable
struct GeneratedPalette {
    @Guide(description: "6 flattering clothing colors that make the person look radiant.")
    var bestColors: [GeneratedColor]

    @Guide(description: "4 versatile neutral garment colors for basics.")
    var neutralColors: [GeneratedColor]

    @Guide(description: "3 bold statement or accent clothing colors.")
    var statementColors: [GeneratedColor]

    @Guide(description: "3 colors that wash this person out and should be avoided near the face.")
    var colorsToAvoid: [GeneratedColor]

    @Guide(description: "A 1-2 sentence stylist explanation of why these colors flatter the person.")
    var summary: String
}

@available(iOS 26.0, *)
@Generable
struct GeneratedColor {
    @Guide(description: "Short color name, e.g. Emerald, Navy, Camel.")
    var name: String

    @Guide(description: "Hex color in #RRGGBB format.")
    var hex: String
}
