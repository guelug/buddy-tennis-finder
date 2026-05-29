import Foundation
import UIKit

final class SkinToneExtractor {

    func extractUndertone(from colors: [UIColor]) -> Undertone {
        guard colors.count >= 10 else { return .neutral }

        var warmScore: Double = 0
        var coolScore: Double = 0

        for color in colors {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: nil)

            // Warm tones have more red/yellow (higher R+G relative to B)
            // Cool tones have more blue (higher B relative to R+G)
            let warmth = (r + g) / 2.0 - b
            let redness = r - (g + b) / 2.0

            if warmth > 0.05 || redness > 0.1 {
                warmScore += 1
            } else if b > r && b > g * 1.1 {
                coolScore += 1
            }
        }

        let total = warmScore + coolScore
        guard total > 0 else { return .neutral }

        let warmRatio = warmScore / total
        if warmRatio > 0.6 {
            return .warm
        } else if warmRatio < 0.4 {
            return .cool
        } else {
            return .neutral
        }
    }

    func generatePalette(undertone: Undertone, skinTone: SkinToneCategory) -> PersonalPalette {
        let seasonalType = determineSeasonalType(undertone: undertone, skinTone: skinTone)
        let recommendedColors = generateRecommendedColors(for: seasonalType, skinTone: skinTone)

        return PersonalPalette(
            seasonalType: seasonalType,
            undertone: undertone,
            recommendedColors: recommendedColors,
            createdAt: Date()
        )
    }

    /// Public seasonal-type mapping so other services (e.g. the AI palette generator) can reuse it.
    func seasonalType(undertone: Undertone, skinTone: SkinToneCategory) -> SeasonalType {
        determineSeasonalType(undertone: undertone, skinTone: skinTone)
    }

    private func determineSeasonalType(undertone: Undertone, skinTone: SkinToneCategory) -> SeasonalType {
        switch (undertone, skinTone) {
        case (.warm, .fair), (.warm, .light): return .spring
        case (.cool, .fair), (.cool, .light): return .summer
        case (.warm, .medium), (.warm, .tan): return .autumn
        case (.cool, .medium), (.cool, .tan): return .winter
        case (.neutral, _):
            switch skinTone {
            case .fair, .light: return .softSpring
            case .medium, .tan: return .softAutumn
            case .dark: return .softWinter
            }
        default: return .spring
        }
    }

    private func generateRecommendedColors(for seasonalType: SeasonalType, skinTone: SkinToneCategory) -> [CodableColor] {
        let palettes: [SeasonalType: [(Double, Double, Double)]] = [
            .spring: [
                (1.0, 0.84, 0.0),
                (0.0, 0.8, 0.6),
                (0.4, 0.8, 0.6),
                (1.0, 0.5, 0.3),
                (0.98, 0.85, 0.0),
            ],
            .summer: [
                (0.6, 0.6, 0.9),
                (0.4, 0.7, 0.8),
                (0.9, 0.6, 0.6),
                (0.7, 0.75, 0.8),
                (0.8, 0.6, 0.7),
            ],
            .autumn: [
                (0.8, 0.5, 0.2),
                (0.6, 0.4, 0.2),
                (0.85, 0.6, 0.3),
                (0.6, 0.5, 0.3),
                (0.9, 0.6, 0.3),
            ],
            .winter: [
                (0.8, 0.0, 0.2),
                (0.0, 0.0, 0.6),
                (0.6, 0.0, 0.4),
                (0.0, 0.4, 0.4),
                (0.95, 0.95, 0.95),
            ],
            .softAutumn: [
                (0.7, 0.5, 0.3),
                (0.6, 0.5, 0.5),
                (0.8, 0.65, 0.5),
                (0.5, 0.45, 0.4),
                (0.6, 0.4, 0.3),
            ],
            .softSpring: [
                (0.95, 0.8, 0.6),
                (0.7, 0.85, 0.7),
                (1.0, 0.7, 0.6),
                (0.85, 0.8, 0.5),
                (0.75, 0.85, 0.75),
            ],
            .softSummer: [
                (0.75, 0.75, 0.8),
                (0.85, 0.75, 0.8),
                (0.8, 0.8, 0.85),
                (0.7, 0.65, 0.7),
                (0.8, 0.75, 0.7),
            ],
            .softWinter: [
                (0.6, 0.55, 0.65),
                (0.5, 0.55, 0.65),
                (0.7, 0.5, 0.6),
                (0.55, 0.6, 0.65),
                (0.65, 0.6, 0.55),
            ],
            .brightWinter: [
                (0.9, 0.0, 0.3),
                (0.0, 0.6, 0.8),
                (0.95, 0.95, 0.95),
                (0.0, 0.5, 0.5),
                (0.7, 0.0, 0.3),
            ],
            .brightSpring: [
                (1.0, 0.8, 0.0),
                (0.0, 0.9, 0.6),
                (1.0, 0.5, 0.3),
                (0.4, 0.9, 0.4),
                (1.0, 0.7, 0.5),
            ],
            .lightSummer: [
                (0.85, 0.85, 0.95),
                (0.9, 0.8, 0.8),
                (0.8, 0.85, 0.9),
                (0.85, 0.8, 0.75),
                (0.9, 0.9, 0.9),
            ],
            .lightSpring: [
                (1.0, 0.9, 0.6),
                (0.7, 0.9, 0.7),
                (1.0, 0.75, 0.7),
                (0.85, 0.95, 0.6),
                (0.8, 0.9, 0.75),
            ],
            .darkWinter: [
                (0.1, 0.1, 0.3),
                (0.4, 0.0, 0.2),
                (0.1, 0.2, 0.15),
                (0.2, 0.2, 0.25),
                (0.6, 0.0, 0.1),
            ],
            .darkAutumn: [
                (0.4, 0.2, 0.1),
                (0.5, 0.25, 0.1),
                (0.3, 0.25, 0.15),
                (0.45, 0.3, 0.2),
                (0.35, 0.2, 0.1),
            ],
        ]

        let colors = palettes[seasonalType] ?? palettes[.spring]!
        return colors.map { CodableColor(red: $0.0, green: $0.1, blue: $0.2) }
    }
}
