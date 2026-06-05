import Foundation
import SwiftUI
import UIKit

// MARK: - Skin Analysis Result
struct SkinAnalysisResult: Codable {
    let dominantColors: [CodableColor]
    let undertone: Undertone
    let undertoneConfidence: Double
    let skinToneCategory: SkinToneCategory
    /// Precise 12-season classification computed from CIELAB depth (ITA°), undertone, and clarity.
    /// Optional for backward compatibility with analyses saved before the science-based pipeline.
    var seasonalType: SeasonalType?

    init(
        dominantColors: [CodableColor],
        undertone: Undertone,
        undertoneConfidence: Double,
        skinToneCategory: SkinToneCategory,
        seasonalType: SeasonalType? = nil
    ) {
        self.dominantColors = dominantColors
        self.undertone = undertone
        self.undertoneConfidence = undertoneConfidence
        self.skinToneCategory = skinToneCategory
        self.seasonalType = seasonalType
    }
}

// MARK: - Personal Palette
struct PersonalPalette: Codable {
    let seasonalType: SeasonalType
    let undertone: Undertone
    let recommendedColors: [CodableColor]
    let createdAt: Date

    // Richer, expert-stylist fields (optional for backward compatibility with previously saved data).
    /// Short expert explanation of why these colors flatter the user.
    var summary: String?
    /// Versatile base/neutral garment colors.
    var neutralColors: [CodableColor]?
    /// Bold statement/accent garment colors.
    var statementColors: [CodableColor]?
    /// Colors that tend to wash the user out — better to avoid near the face.
    var colorsToAvoid: [CodableColor]?

    init(
        seasonalType: SeasonalType,
        undertone: Undertone,
        recommendedColors: [CodableColor],
        createdAt: Date = Date(),
        summary: String? = nil,
        neutralColors: [CodableColor]? = nil,
        statementColors: [CodableColor]? = nil,
        colorsToAvoid: [CodableColor]? = nil
    ) {
        self.seasonalType = seasonalType
        self.undertone = undertone
        self.recommendedColors = recommendedColors
        self.createdAt = createdAt
        self.summary = summary
        self.neutralColors = neutralColors
        self.statementColors = statementColors
        self.colorsToAvoid = colorsToAvoid
    }
}

// MARK: - Codable Color
struct CodableColor: Codable, Identifiable {
    let id: UUID
    let red: Double
    let green: Double
    let blue: Double
    /// Human-readable name (e.g. "Emerald", "Navy"). Optional for backward compatibility.
    var name: String?

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    init(uiColor: UIColor, name: String? = nil) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        self.id = UUID()
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.name = name
    }

    init(color: Color, name: String? = nil) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        self.id = UUID()
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.name = name
    }

    init(red: Double, green: Double, blue: Double, name: String? = nil) {
        self.id = UUID()
        self.red = red
        self.green = green
        self.blue = blue
        self.name = name
    }

    /// Parses a "#RRGGBB" (or "RRGGBB") hex string. Returns nil for malformed input.
    init?(hex: String, name: String? = nil) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        if cleaned.hasPrefix("0X") { cleaned.removeFirst(2) }
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
        self.id = UUID()
        self.red = Double((value >> 16) & 0xFF) / 255.0
        self.green = Double((value >> 8) & 0xFF) / 255.0
        self.blue = Double(value & 0xFF) / 255.0
        self.name = name
    }
}

// MARK: - Undertone
enum Undertone: String, Codable, CaseIterable {
    case warm
    case cool
    case neutral

    var displayName: String {
        switch self {
        case .warm: return "Warm"
        case .cool: return "Cool"
        case .neutral: return "Neutral"
        }
    }
}

// MARK: - Seasonal Type
enum SeasonalType: String, Codable, CaseIterable {
    case spring = "Spring"
    case summer = "Summer"
    case autumn = "Autumn"
    case winter = "Winter"
    case softAutumn = "Soft Autumn"
    case softSpring = "Soft Spring"
    case softSummer = "Soft Summer"
    case softWinter = "Soft Winter"
    case brightWinter = "Bright Winter"
    case brightSpring = "Bright Spring"
    case lightSummer = "Light Summer"
    case lightSpring = "Light Spring"
    case darkWinter = "Dark Winter"
    case darkAutumn = "Dark Autumn"

    var displayName: String { rawValue }
}

// MARK: - Skin Tone Category
enum SkinToneCategory: String, Codable, CaseIterable {
    case fair
    case light
    case medium
    case tan
    case dark

    var displayName: String {
        switch self {
        case .fair: return "Fair"
        case .light: return "Light"
        case .medium: return "Medium"
        case .tan: return "Tan"
        case .dark: return "Dark"
        }
    }
}

// MARK: - Color Recommendation
struct ColorRecommendation: Codable, Identifiable {
    let id: UUID
    let color: CodableColor
    let name: String
    let category: ColorCategory
    let description: String

    init(color: CodableColor, name: String, category: ColorCategory, description: String) {
        self.id = UUID()
        self.color = color
        self.name = name
        self.category = category
        self.description = description
    }
}

enum ColorCategory: String, Codable {
    case primary
    case secondary
    case accent
    case neutral
}

// MARK: - Style Tag
struct StyleTag: Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let category: StyleCategory

    init(id: UUID = UUID(), name: String, category: StyleCategory) {
        self.id = id
        self.name = name
        self.category = category
    }
}

enum StyleCategory: String, Codable {
    case aesthetic
    case vibe
    case preference
}
