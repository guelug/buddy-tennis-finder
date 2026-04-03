import Foundation
import SwiftUI
import UIKit

// MARK: - Skin Analysis Result
struct SkinAnalysisResult: Codable {
    let dominantColors: [CodableColor]
    let undertone: Undertone
    let undertoneConfidence: Double
    let skinToneCategory: SkinToneCategory
}

// MARK: - Personal Palette
struct PersonalPalette: Codable {
    let seasonalType: SeasonalType
    let undertone: Undertone
    let recommendedColors: [CodableColor]
    let createdAt: Date
}

// MARK: - Codable Color
struct CodableColor: Codable, Identifiable {
    let id: UUID
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    init(uiColor: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        self.id = UUID()
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
    }

    init(color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        self.id = UUID()
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
    }

    init(red: Double, green: Double, blue: Double) {
        self.id = UUID()
        self.red = red
        self.green = green
        self.blue = blue
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
