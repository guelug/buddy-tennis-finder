import Foundation
import FoundationModels

/// Turns a raw skin analysis into an expert, personal-shopper-grade color palette: flattering
/// garment colors (with names), versatile neutrals, statement colors, colors to avoid, and a short
/// explanation. Uses on-device Apple Intelligence (iOS 26+) when available, with a rich rule-based
/// fallback so the result is always far more useful than raw skin-tone swatches.
@MainActor
final class PaletteGenerationService {

    private let ruleBasedExtractor = SkinToneExtractor()

    func generatePalette(from analysis: SkinAnalysisResult, language: Language) async -> PersonalPalette {
        let seasonalType = ruleBasedExtractor.seasonalType(
            undertone: analysis.undertone,
            skinTone: analysis.skinToneCategory
        )

        if #available(iOS 26.0, *) {
            if let aiPalette = await generateWithAI(
                seasonalType: seasonalType,
                analysis: analysis,
                language: language
            ) {
                return aiPalette
            }
        }

        return ruleBasedPalette(seasonalType: seasonalType, undertone: analysis.undertone, language: language)
    }

    // MARK: - AI generation (iOS 26+)

    @available(iOS 26.0, *)
    private func generateWithAI(
        seasonalType: SeasonalType,
        analysis: SkinAnalysisResult,
        language: Language
    ) async -> PersonalPalette? {
        let model = SystemLanguageModel.default
        guard model.isAvailable else { return nil }

        let session = LanguageModelSession(
            model: model,
            instructions: Self.instructions(language: language)
        )

        let prompt = Self.prompt(seasonalType: seasonalType, analysis: analysis, language: language)

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
    private static func prompt(seasonalType: SeasonalType, analysis: SkinAnalysisResult, language: Language) -> String {
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
