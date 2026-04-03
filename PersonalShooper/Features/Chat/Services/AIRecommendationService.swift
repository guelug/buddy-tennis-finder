import Foundation
import SwiftData

// MARK: - AI Recommendation Service
/// Service that generates personalized fashion recommendations using AI
@MainActor
final class AIRecommendationService {
    
    private let chatService: AIChatServiceProtocol?
    private var foundationService: (any FoundationModelsServiceProtocol)?
    
    init() {
        if #available(iOS 26.0, *) {
            let service = AIChatServiceFactory.createStreamingService()
            self.foundationService = service
            self.chatService = service
        } else {
            self.chatService = EnhancedAppleIntelligenceService()
        }
    }
    
    // MARK: - Personalized Outfit Recommendations
    
    /// Generates a complete outfit recommendation based on user profile and occasion
    func generateOutfitRecommendation(
        for occasion: OutfitOccasion,
        context: ChatContext,
        weather: WeatherCondition? = nil
    ) async throws -> OutfitRecommendation {
        
        // Try Foundation Models guided generation first
        if #available(iOS 26.0, *), let service = foundationService {
            return try await service.generateOutfitRecommendation(
                occasion: occasion.rawValue,
                context: context
            )
        }
        
        // Fallback to text-based recommendation
        let prompt = buildOutfitPrompt(occasion: occasion, context: context, weather: weather)
        let response = try await chatService?.sendMessage(prompt, context: context)
        
        // Parse the response into structured format
        return parseOutfitResponse(response ?? "", occasion: occasion)
    }
    
    // MARK: - Color Palette Analysis
    
    /// Analyzes which colors work best for the user
    func analyzeBestColors(
        context: ChatContext
    ) async throws -> ColorAnalysisResult {
        let prompt = context.language == .spanish
            ? "Analiza mi paleta \(context.userPalette?.seasonalType.displayName ?? "") y dime: 1) Los 3 mejores colores para mí, 2) Colores a evitar, 3) Cómo combinarlos"
            : "Analyze my \(context.userPalette?.seasonalType.displayName ?? "") palette and tell me: 1) Top 3 colors for me, 2) Colors to avoid, 3) How to combine them"
        
        let response = try await chatService?.sendMessage(prompt, context: context)
        
        return ColorAnalysisResult(
            summary: response ?? "No analysis available",
            bestColors: context.userPalette?.recommendedColors.prefix(5).map { $0.color } ?? [],
            colorsToAvoid: [],
            combinationTips: response ?? ""
        )
    }
    
    // MARK: - Wardrobe Analysis
    
    /// Analyzes user's wardrobe and suggests improvements
    func analyzeWardrobe(
        items: [ClothingItem],
        context: ChatContext
    ) async throws -> WardrobeAnalysis {
        let itemSummary = items.map { "\($0.name) (\($0.category.displayName))" }.joined(separator: ", ")
        
        let prompt = context.language == .spanish
            ? "Analiza mi armario: tengo \(items.count) prendas: \(itemSummary). ¿Qué piezas básicas me faltan? ¿Qué colores debería agregar? Dame 3 recomendaciones específicas."
            : "Analyze my wardrobe: I have \(items.count) items: \(itemSummary). What basics am I missing? What colors should I add? Give me 3 specific recommendations."
        
        let response = try await chatService?.sendMessage(prompt, context: context)
        
        return WardrobeAnalysis(
            totalItems: items.count,
            categoryBreakdown: Dictionary(grouping: items, by: { $0.category })
                .mapValues { $0.count },
            recommendations: response?.components(separatedBy: "\n").filter { !$0.isEmpty } ?? [],
            missingBasics: identifyMissingBasics(from: items),
            colorGaps: identifyColorGaps(from: items, context: context)
        )
    }
    
    // MARK: - Seasonal Recommendations
    
    /// Generates seasonal fashion recommendations
    func generateSeasonalRecommendations(
        season: Season,
        context: ChatContext
    ) async throws -> SeasonalRecommendations {
        let prompt = context.language == .spanish
            ? "Recomiéndame tendencias y piezas esenciales para \(season.displayName). Considera mi paleta \(context.userPalette?.seasonalType.displayName ?? "")."
            : "Recommend trends and essential pieces for \(season.displayName). Consider my \(context.userPalette?.seasonalType.displayName ?? "") palette."
        
        let response = try await chatService?.sendMessage(prompt, context: context)
        
        return SeasonalRecommendations(
            season: season,
            description: response ?? "",
            keyPieces: extractKeyPieces(from: response ?? ""),
            colorTrends: extractColorTrends(from: response ?? "", palette: context.userPalette),
            stylingTips: response?.components(separatedBy: "\n").filter { $0.contains("-") } ?? []
        )
    }
    
    // MARK: - Private Helpers
    
    private func buildOutfitPrompt(
        occasion: OutfitOccasion,
        context: ChatContext,
        weather: WeatherCondition?
    ) -> String {
        var parts: [String] = []
        
        let isSpanish = context.language == .spanish
        
        parts.append(isSpanish
            ? "Crea un outfit completo para: \(occasion.displayName)"
            : "Create a complete outfit for: \(occasion.displayName)"
        )
        
        if let palette = context.userPalette {
            parts.append(isSpanish
                ? "Mi paleta: \(palette.seasonalType.displayName) con tono \(palette.undertone.displayName)"
                : "My palette: \(palette.seasonalType.displayName) with \(palette.undertone.displayName) undertone"
            )
        }
        
        if let weather = weather {
            parts.append(isSpanish
                ? "Clima: \(weather.description)"
                : "Weather: \(weather.description)"
            )
        }
        
        if !context.userStylePreferences.isEmpty {
            parts.append(isSpanish
                ? "Estilo: \(context.userStylePreferences.joined(separator: ", "))"
                : "Style: \(context.userStylePreferences.joined(separator: ", "))"
            )
        }
        
        parts.append(isSpanish
            ? "Incluye: prendas específicas, colores recomendados, accesorios y consejos de estilo."
            : "Include: specific clothing items, recommended colors, accessories, and styling tips."
        )
        
        return parts.joined(separator: "\n")
    }
    
    private func parseOutfitResponse(_ response: String, occasion: OutfitOccasion) -> OutfitRecommendation {
        // Simple parsing - in production, use guided generation for structured output
        let lines = response.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        var items: [OutfitItem] = []
        var stylingTips: [String] = []
        
        for line in lines {
            if line.contains(":") || line.contains("-") {
                let cleanLine = line.trimmingCharacters(in: .punctuationCharacters)
                    .trimmingCharacters(in: .whitespaces)
                
                if cleanLine.lowercased().contains("tip") ||
                   cleanLine.lowercased().contains("consejo") {
                    stylingTips.append(cleanLine)
                } else {
                    items.append(OutfitItem(
                        type: "Item",
                        recommendedColor: "Neutral",
                        reasoning: cleanLine
                    ))
                }
            }
        }
        
        return OutfitRecommendation(
            name: "Outfit for \(occasion.displayName)",
            description: response,
            items: items.isEmpty ? [OutfitItem(type: "Outfit", recommendedColor: "Mixed", reasoning: response)] : items,
            colorNotes: "Based on your personal palette",
            stylingTips: stylingTips.isEmpty ? [response] : stylingTips,
            occasionMatch: 90
        )
    }
    
    private func identifyMissingBasics(from items: [ClothingItem]) -> [String] {
        var missing: [String] = []
        let categories = Set(items.map { $0.category })
        
        if !categories.contains(.tops) { missing.append("Basic tops") }
        if !categories.contains(.bottoms) { missing.append("Versatile bottoms") }
        if !categories.contains(.outerwear) { missing.append("Light jacket or cardigan") }
        if !categories.contains(.shoes) { missing.append("Comfortable shoes") }
        
        return missing
    }
    
    private func identifyColorGaps(from items: [ClothingItem], context: ChatContext) -> [String] {
        var gaps: [String] = []
        let existingColors = Set(items.flatMap { $0.colorTags }.map { $0.lowercased() })
        
        if let palette = context.userPalette {
            for color in palette.recommendedColors.prefix(3) {
                let colorName = colorName(for: color).lowercased()
                if !existingColors.contains(colorName) {
                    gaps.append(colorName.capitalized)
                }
            }
        }
        
        return gaps
    }
    
    private func colorName(for color: CodableColor) -> String {
        let r = color.red
        let g = color.green
        let b = color.blue
        
        if r > 0.7 && g < 0.4 && b < 0.4 { return "Red" }
        if r > 0.7 && g > 0.4 && b < 0.4 { return "Coral" }
        if r > 0.8 && g > 0.5 && b < 0.2 { return "Orange" }
        if r > 0.7 && g > 0.7 && b < 0.3 { return "Yellow" }
        if r < 0.4 && g > 0.5 && b < 0.4 { return "Green" }
        if r < 0.4 && g < 0.5 && b > 0.7 { return "Blue" }
        if r > 0.5 && g < 0.4 && b > 0.5 { return "Purple" }
        if r > 0.7 && g > 0.5 && b > 0.6 { return "Pink" }
        if r < 0.2 && g < 0.2 && b < 0.2 { return "Black" }
        if r > 0.8 && g > 0.8 && b > 0.8 { return "White" }
        if r > 0.5 && g > 0.5 && b > 0.5 { return "Gray" }
        if r > 0.5 && g > 0.3 && b < 0.2 { return "Brown" }
        if r > 0.7 && g > 0.6 && b > 0.5 { return "Beige" }
        if r < 0.4 && g > 0.5 && b > 0.5 { return "Teal" }
        if r > 0.6 && g < 0.5 && b > 0.7 { return "Lavender" }
        if r > 0.4 && g < 0.3 && b < 0.3 { return "Burgundy" }
        
        return "Neutral"
    }
    
    private func extractKeyPieces(from response: String) -> [String] {
        return response.components(separatedBy: "\n")
            .filter { $0.contains("-") || $0.contains("•") }
            .map { $0.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "•", with: "").trimmingCharacters(in: .whitespaces) }
    }
    
    private func extractColorTrends(from response: String, palette: PersonalPalette?) -> [Color] {
        // Return palette colors as fallback
        return palette?.recommendedColors.map { $0.color } ?? []
    }
}

// MARK: - Supporting Types

enum OutfitOccasion: String, CaseIterable {
    case casual = "casual"
    case work = "work"
    case formal = "formal"
    case party = "party"
    case date = "date"
    case workout = "workout"
    case travel = "travel"
    case wedding = "wedding"
    
    var displayName: String {
        switch self {
        case .casual: return "Casual"
        case .work: return "Work"
        case .formal: return "Formal Event"
        case .party: return "Party"
        case .date: return "Date Night"
        case .workout: return "Workout"
        case .travel: return "Travel"
        case .wedding: return "Wedding"
        }
    }
}

enum WeatherCondition {
    case hot
    case cold
    case rainy
    case sunny
    
    var description: String {
        switch self {
        case .hot: return "Hot weather"
        case .cold: return "Cold weather"
        case .rainy: return "Rainy weather"
        case .sunny: return "Sunny weather"
        }
    }
}

enum Season: CaseIterable {
    case spring
    case summer
    case autumn
    case winter
    
    var displayName: String {
        switch self {
        case .spring: return "Spring"
        case .summer: return "Summer"
        case .autumn: return "Autumn/Fall"
        case .winter: return "Winter"
        }
    }
}

struct ColorAnalysisResult {
    let summary: String
    let bestColors: [Color]
    let colorsToAvoid: [Color]
    let combinationTips: String
}

struct WardrobeAnalysis {
    let totalItems: Int
    let categoryBreakdown: [ClothingCategory: Int]
    let recommendations: [String]
    let missingBasics: [String]
    let colorGaps: [String]
}

struct SeasonalRecommendations {
    let season: Season
    let description: String
    let keyPieces: [String]
    let colorTrends: [Color]
    let stylingTips: [String]
}
