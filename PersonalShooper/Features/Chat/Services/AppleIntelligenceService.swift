import Foundation
import NaturalLanguage

// MARK: - AI Service Errors
enum AIError: LocalizedError {
    case notSupported
    case promptFailed
    case responseFailed(String)
    case contentFiltered
    case timeout
    case modelNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Apple Intelligence is not available on this device."
        case .promptFailed:
            return "Failed to create the prompt."
        case .responseFailed(let message):
            return "AI response failed: \(message)"
        case .contentFiltered:
            return "Your request was filtered for safety. Please try a different message."
        case .timeout:
            return "The request timed out. Please try again."
        case .modelNotAvailable:
            return "The AI model is not available at the moment."
        }
    }
}

// MARK: - AI Response
struct AIResponse {
    let content: String
    let shouldFilter: Bool
}

// MARK: - AI Chat Service Protocol
protocol AIChatServiceProtocol {
    func sendMessage(_ message: String, context: ChatContext) async throws -> String
}

// MARK: - Streaming Service Protocol
protocol FoundationModelsServiceProtocol: AIChatServiceProtocol {
    var isStreaming: Bool { get }
    func streamMessage(_ message: String, context: ChatContext) -> AsyncThrowingStream<String, Error>
    func prewarm() async
}

// MARK: - Clothing Data Service Protocol
protocol ClothingDataServiceProtocol: Sendable {
    func searchItems(
        category: String?,
        occasion: String?,
        colorPreference: String?,
        stylePreference: String?
    ) async -> [ClothingItemSummary]
}

struct ClothingItemSummary: Codable {
    let id: UUID
    let name: String
    let category: ClothingCategory
    let colorTags: [String]
    let styleTags: [String]
}

// MARK: - Service Factory
enum AIChatServiceFactory {
    static func createService() -> AIChatServiceProtocol {
        return EnhancedAppleIntelligenceService()
    }

    static func createFallbackService() -> AIChatServiceProtocol {
        return BasicFallbackService()
    }
}

// MARK: - Enhanced Apple Intelligence Service (Fallback for older iOS)
/// Enhanced fallback service using keyword analysis and NaturalLanguage framework
final class EnhancedAppleIntelligenceService: AIChatServiceProtocol {

    private let fashionSystemPrompt = """
    You are Personal Shooper, a professional AI fashion stylist assistant. Your role is to help users with:
    - Color recommendations based on their personal color palette
    - Outfit suggestions for various occasions
    - Style advice matching their preferences
    - Fashion tips and trends

    Important guidelines:
    - Always be helpful, friendly, and professional
    - Respect user privacy - never ask for personal information beyond fashion preferences
    - Provide specific, actionable advice
    - Consider the user's personal color palette and style preferences when giving recommendations
    - If unsure about something, suggest consulting a human stylist
    """

    private let responseCache = NSCache<NSString, NSString>()
    private let sentimentAnalyzer = NLTagger(tagSchemes: [.sentimentScore])

    func sendMessage(_ message: String, context: ChatContext) async throws -> String {
        return generateContextualResponse(message: message, context: context)
    }

    // MARK: - Response Generation
    private func generateContextualResponse(message: String, context: ChatContext) -> String {
        let lowercasedMessage = message.lowercased()
        let language = detectLanguage(message: message, context: context)

        // Analyze sentiment to adjust tone
        let sentiment = analyzeSentiment(message)

        // Detect intent using more sophisticated pattern matching
        let intent = detectIntent(message: lowercasedMessage)
        
        switch intent {
        case .colorAdvice:
            return generateColorAdvice(language: language, palette: context.userPalette, message: message)
        case .outfitRecommendation:
            return generateOutfitRecommendation(language: language, context: context, message: message)
        case .colorMatching:
            return generateColorMatchingAdvice(language: language, message: message)
        case .styleAdvice:
            return generateStyleAdvice(language: language, context: context)
        case .trends:
            return generateTrendsAdvice(language: language)
        case .wardrobeHelp:
            return generateWardrobeAdvice(language: language, context: context)
        case .occasionHelp:
            return generateOccasionAdvice(language: language, message: message, context: context)
        case .general, .unknown:
            return generateGeneralResponse(language: language, sentiment: sentiment, context: context)
        }
    }
    
    // MARK: - Intent Detection
    private func detectIntent(message: String) -> UserIntent {
        let colorKeywords = ["color", "colores", "tono", "tones", "palette", "paleta", "matches", "combinan"]
        let outfitKeywords = ["outfit", "vestir", "traje", "ropa", "wear", "wearing", "look", "conjunto"]
        let matchingKeywords = ["match", "combinar", "combina", "go with", "pair", "coordinates"]
        let styleKeywords = ["style", "estilo", "fashion", "moda", "elegant", "casual", "formal"]
        let trendKeywords = ["trend", "tendencia", "popular", "in style", "fashionable"]
        let wardrobeKeywords = ["closet", "armario", "wardrobe", "clothes", "tengo", "have"]
        let occasionKeywords = ["occasion", "ocasion", "event", "evento", "wedding", "boda", "party", "fiesta", "work", "trabajo"]
        
        var scores: [UserIntent: Int] = [:]
        
        for keyword in colorKeywords {
            if message.contains(keyword) { scores[.colorAdvice, default: 0] += 1 }
        }
        for keyword in outfitKeywords {
            if message.contains(keyword) { scores[.outfitRecommendation, default: 0] += 1 }
        }
        for keyword in matchingKeywords {
            if message.contains(keyword) { scores[.colorMatching, default: 0] += 1 }
        }
        for keyword in styleKeywords {
            if message.contains(keyword) { scores[.styleAdvice, default: 0] += 1 }
        }
        for keyword in trendKeywords {
            if message.contains(keyword) { scores[.trends, default: 0] += 1 }
        }
        for keyword in wardrobeKeywords {
            if message.contains(keyword) { scores[.wardrobeHelp, default: 0] += 1 }
        }
        for keyword in occasionKeywords {
            if message.contains(keyword) { scores[.occasionHelp, default: 0] += 1 }
        }
        
        return scores.max(by: { $0.value < $1.value })?.key ?? .general
    }
    
    // MARK: - Language Detection
    private func detectLanguage(message: String, context: ChatContext) -> Language {
        // Prioritize context language setting
        if context.language == .spanish {
            return .spanish
        }
        
        let lowercased = message.lowercased()
        let spanishIndicators = ["como", "que", "cual", "cuando", "donde", "por que", "me", "mi", "te", "tu", 
                                "el", "la", "los", "las", "un", "una", "es", "son", "tengo", "quiero"]
        
        let spanishCount = spanishIndicators.filter { lowercased.contains($0) }.count
        return spanishCount >= 2 ? .spanish : .english
    }
    
    // MARK: - Sentiment Analysis
    private func analyzeSentiment(_ message: String) -> Double {
        sentimentAnalyzer.string = message
        let (sentiment, _) = sentimentAnalyzer.tag(at: message.startIndex, unit: .paragraph, scheme: .sentimentScore)
        return Double(sentiment?.rawValue ?? "0") ?? 0
    }
    
    // MARK: - Response Generators
    private func generateColorAdvice(language: Language, palette: PersonalPalette?, message: String) -> String {
        let isSpanish = language == .spanish
        
        // Extract specific color mentions
        let colors = extractColors(from: message)
        
        if isSpanish {
            var response = ""
            if let palette = palette {
                response = "Basándome en tu paleta de \(palette.seasonalType.displayName) con tono \(palette.undertone.displayName.lowercased()), "
                
                if !colors.isEmpty {
                    response += "los colores \(colors.joined(separator: ", ")) pueden funcionar bien para ti. "
                }
                
                response += "Te favorecen los tonos que realzan tu luminosidad natural. "
                response += "Los colores recomendados para tu tipo incluyen: "
                response += palette.recommendedColors.prefix(3).map { colorNameInSpanish(for: $0) }.joined(separator: ", ")
                response += "."
            } else {
                response = "Para darte mejores consejos de color personalizados, te recomiendo completar tu perfil con una foto para analizar tu paleta personal. "
                response += "Mientras tanto, los tonos neutros como el beige, gris y marino suelen ser versátiles para la mayoría de personas."
            }
            return response
        }
        
        var response = ""
        if let palette = palette {
            response = "Based on your \(palette.seasonalType.displayName) palette with \(palette.undertone.displayName.lowercased()) undertones, "
            
            if !colors.isEmpty {
                response += "colors like \(colors.joined(separator: ", ")) can work well for you. "
            }
            
            response += "You look best in tones that enhance your natural glow. "
            response += "Colors recommended for your type include: "
            response += palette.recommendedColors.prefix(3).map { colorName(for: $0) }.joined(separator: ", ")
            response += "."
        } else {
            response = "To give you personalized color advice, I recommend completing your profile with a photo to analyze your personal palette. "
            response += "In the meantime, neutral tones like beige, gray, and navy are versatile choices for most people."
        }
        return response
    }
    
    private func generateOutfitRecommendation(language: Language, context: ChatContext, message: String) -> String {
        let isSpanish = language == .spanish
        
        // Extract occasion
        let occasions = extractOccasions(from: message)
        
        if isSpanish {
            var response = "¡Me encantaría ayudarte con un outfit"
            if !occasions.isEmpty {
                response += " para \(occasions.joined(separator: ", "))"
            }
            response += "! "
            
            if let palette = context.userPalette {
                response += "Con tu paleta \(palette.seasonalType.displayName.lowercased()), considera usar "
                response += "prendas en tonos \(palette.recommendedColors.prefix(2).map { colorNameInSpanish(for: $0) }.joined(separator: " o ")) "
                response += "como piezas principales. "
            }
            
            response += "Para un look completo, necesitaría saber más sobre tu estilo preferido y la ocasión específica. "
            response += "¿Prefieres algo casual, formal, o elegante?"
            return response
        }
        
        var response = "I'd love to help you put together an outfit"
        if !occasions.isEmpty {
            response += " for \(occasions.joined(separator: ", "))"
        }
        response += "! "
        
        if let palette = context.userPalette {
            response += "With your \(palette.seasonalType.displayName.lowercased()) palette, consider wearing "
            response += "pieces in \(palette.recommendedColors.prefix(2).map { colorName(for: $0) }.joined(separator: " or ")) "
            response += "as your main items. "
        }
        
        response += "For a complete look, I'd need to know more about your preferred style and the specific occasion. "
        response += "Do you prefer something casual, formal, or chic?"
        return response
    }
    
    private func generateColorMatchingAdvice(language: Language, message: String) -> String {
        let isSpanish = language == .spanish
        let colors = extractColors(from: message)
        
        if isSpanish {
            var response = "¡Gran pregunta sobre combinación de colores! "
            
            if colors.count >= 2 {
                response += "Para combinar \(colors[0]) con \(colors[1]): "
                response += "usa el 60-30-10 rule - 60% color dominante, 30% secundario, 10% acento. "
            } else {
                response += "Para un look cohesivo, intenta usar la regla de colores análogos (vecinos en el círculo cromático) "
                response += "o colores complementarios (opuestos) para contraste. "
            }
            
            response += "¿Hay colores específicos que te gustaría combinar? Puedo darte consejos más detallados."
            return response
        }
        
        var response = "Great question about color matching! "
        
        if colors.count >= 2 {
            response += "To match \(colors[0]) with \(colors[1]): "
            response += "use the 60-30-10 rule - 60% dominant color, 30% secondary, 10% accent. "
        } else {
            response += "For a cohesive look, try using analogous colors (neighbors on the color wheel) "
            response += "or complementary colors (opposites) for contrast. "
        }
        
        response += "Which specific colors would you like to match? I can give you more detailed advice."
        return response
    }
    
    private func generateStyleAdvice(language: Language, context: ChatContext) -> String {
        let isSpanish = language == .spanish
        
        if isSpanish {
            var response = "El estilo personal es una forma de expresión única. "
            
            if !context.userStylePreferences.isEmpty {
                response += "Veo que te gustan los estilos: \(context.userStylePreferences.joined(separator: ", ")). "
            }
            
            response += "Para definir mejor tu estilo, considera: ¿qué te hace sentir más cómodo y seguro? "
            response += "¿Prefieres piezas atemporales o sigues las últimas tendencias? "
            response += "Un buen armario tiene un equilibrio de ambos."
            return response
        }
        
        var response = "Personal style is a unique form of expression. "
        
        if !context.userStylePreferences.isEmpty {
            response += "I see you like these styles: \(context.userStylePreferences.joined(separator: ", ")). "
        }
        
        response += "To define your style better, consider: what makes you feel most comfortable and confident? "
        response += "Do you prefer timeless pieces or following the latest trends? "
        response += "A great wardrobe has a balance of both."
        return response
    }
    
    private func generateTrendsAdvice(language: Language) -> String {
        let isSpanish = language == .spanish
        
        if isSpanish {
            return """
            Las tendencias actuales de moda incluyen:
            • Siluetas oversize cómodas y relajadas
            • Texturas táctiles como terciopelo, sarga y punto
            • Tonos neutros versátiles con toques de color terracota
            • Accesorios statement que elevan cualquier outfit
            • Moda sostenible y piezas atemporales
            
            Recuerda: las tendencias son guías, no reglas. Adapta lo que resuene contigo.
            ¿Te gustaría consejos específicos sobre alguna tendencia?
            """
        }
        
        return """
        Current fashion trends include:
        • Comfortable, relaxed oversized silhouettes
        • Tactile textures like velvet, twill, and knit
        • Versatile neutral tones with touches of terracotta
        • Statement accessories that elevate any outfit
        • Sustainable fashion and timeless pieces
        
        Remember: trends are guides, not rules. Adapt what resonates with you.
        Would you like specific advice on any trend?
        """
    }
    
    private func generateWardrobeAdvice(language: Language, context: ChatContext) -> String {
        let isSpanish = language == .spanish
        
        if isSpanish {
            var response = "Organizar tu armario es clave para aprovecharlo al máximo. "
            
            if let palette = context.userPalette {
                response += "Con tu paleta \(palette.seasonalType.displayName.lowercased()), enfócate en piezas versátiles en tus colores favorables. "
            }
            
            response += "Te sugiero: una base de neutros de calidad, algunas piezas statement en tus mejores colores, "
            response += "y prendas que se combinen entre sí. ¿Quieres ayuda organizando categorías específicas?"
            return response
        }
        
        var response = "Organizing your wardrobe is key to maximizing it. "
        
        if let palette = context.userPalette {
            response += "With your \(palette.seasonalType.displayName.lowercased()) palette, focus on versatile pieces in your favorable colors. "
        }
        
        response += "I suggest: quality neutral basics, some statement pieces in your best colors, "
        response += "and items that mix and match well. Want help organizing specific categories?"
        return response
    }
    
    private func generateOccasionAdvice(language: Language, message: String, context: ChatContext) -> String {
        let isSpanish = language == .spanish
        let occasions = extractOccasions(from: message)
        
        if isSpanish {
            var response = ""
            if !occasions.isEmpty {
                response = "Para \(occasions.joined(separator: ", ")), considera el dress code y tu comodidad. "
            } else {
                response = "Para cualquier ocasión, considera el dress code y tu comodidad. "
            }
            
            if let palette = context.userPalette {
                response += "Con tu tono \(palette.undertone.displayName.lowercased()), los colores \(palette.recommendedColors.prefix(2).map { colorNameInSpanish(for: $0) }.joined(separator: " y ")) te favorecerán especialmente. "
            }
            
            response += "Cuéntame más sobre el evento específico para darte recomendaciones más precisas."
            return response
        }
        
        var response = ""
        if !occasions.isEmpty {
            response = "For \(occasions.joined(separator: ", ")), consider the dress code and your comfort. "
        } else {
            response = "For any occasion, consider the dress code and your comfort. "
        }
        
        if let palette = context.userPalette {
            response += "With your \(palette.undertone.displayName.lowercased()) undertones, colors like \(palette.recommendedColors.prefix(2).map { colorName(for: $0) }.joined(separator: " and ")) will be especially flattering. "
        }
        
        response += "Tell me more about the specific event for more precise recommendations."
        return response
    }
    
    private func generateGeneralResponse(language: Language, sentiment: Double, context: ChatContext) -> String {
        let isSpanish = language == .spanish
        let isPositive = sentiment > 0
        
        if isSpanish {
            var response = isPositive 
                ? "¡Me alegra que estés interesado en mejorar tu estilo! "
                : "Entiendo que encontrar tu estilo puede ser desafiante. "
            
            response += "Como tu estilista personal, estoy aquí para ayudarte con consejos de moda, recomendaciones de color y tips de estilo. "
            
            if context.userPalette == nil {
                response += "Para empezar con recomendaciones personalizadas, completa tu perfil con fotos para analizar tu paleta de colores. "
            }
            
            response += "¿Qué te gustaría explorar hoy? Puedo ayudarte con outfits, combinaciones de colores, o tendencias."
            return response
        }
        
        var response = isPositive
            ? "I'm glad you're interested in elevating your style! "
            : "I understand that finding your style can be challenging. "
        
        response += "As your personal stylist, I'm here to help with fashion advice, color recommendations, and style tips. "
        
        if context.userPalette == nil {
            response += "To start with personalized recommendations, complete your profile with photos to analyze your color palette. "
        }
        
        response += "What would you like to explore today? I can help with outfits, color combinations, or trends."
        return response
    }
    
    // MARK: - Helper Methods
    private func extractColors(from message: String) -> [String] {
        let colorPatterns = [
            "red", "blue", "green", "yellow", "orange", "purple", "pink", "black", "white",
            "gray", "grey", "brown", "beige", "navy", "burgundy", "teal", "coral",
            "rojo", "azul", "verde", "amarillo", "naranja", "morado", "rosa", "negro", "blanco",
            "gris", "cafe", "marrón", "beige", "marino", "borgoña", "turquesa", "coral"
        ]
        
        let lowercased = message.lowercased()
        return colorPatterns.filter { lowercased.contains($0) }
    }
    
    private func extractOccasions(from message: String) -> [String] {
        let occasionPatterns = [
            ("wedding", "boda"), ("party", "fiesta"), ("work", "trabajo"), ("interview", "entrevista"),
            ("date", "cita"), ("casual", "casual"), ("formal", "formal"), ("gym", "gimnasio"),
            ("vacation", "vacaciones"), ("beach", "playa"), ("dinner", "cena")
        ]
        
        let lowercased = message.lowercased()
        var found: [String] = []
        
        for (en, es) in occasionPatterns {
            if lowercased.contains(en) || lowercased.contains(es) {
                found.append(en)
            }
        }
        
        return found
    }
    
    private func colorName(for color: CodableColor) -> String {
        let r = color.red
        let g = color.green
        let b = color.blue
        
        if r > 0.7 && g < 0.4 && b < 0.4 { return "red" }
        if r > 0.7 && g > 0.4 && b < 0.4 { return "coral" }
        if r > 0.8 && g > 0.5 && b < 0.2 { return "orange" }
        if r > 0.7 && g > 0.7 && b < 0.3 { return "yellow" }
        if r < 0.4 && g > 0.5 && b < 0.4 { return "green" }
        if r < 0.4 && g < 0.5 && b > 0.7 { return "blue" }
        if r > 0.5 && g < 0.4 && b > 0.5 { return "purple" }
        if r > 0.7 && g > 0.5 && b > 0.6 { return "pink" }
        if r < 0.2 && g < 0.2 && b < 0.2 { return "black" }
        if r > 0.8 && g > 0.8 && b > 0.8 { return "white" }
        if r > 0.5 && g > 0.5 && b > 0.5 { return "gray" }
        if r > 0.5 && g > 0.3 && b < 0.2 { return "brown" }
        if r > 0.7 && g > 0.6 && b > 0.5 { return "beige" }
        if r < 0.4 && g > 0.5 && b > 0.5 { return "teal" }
        if r > 0.6 && g < 0.5 && b > 0.7 { return "lavender" }
        if r > 0.4 && g < 0.3 && b < 0.3 { return "burgundy" }
        
        return "neutral"
    }
    
    private func colorNameInSpanish(for color: CodableColor) -> String {
        let english = colorName(for: color)
        let translations: [String: String] = [
            "red": "rojo", "coral": "coral", "orange": "naranja", "yellow": "amarillo",
            "green": "verde", "blue": "azul", "purple": "morado", "pink": "rosa",
            "black": "negro", "white": "blanco", "gray": "gris", "brown": "marrón",
            "beige": "beige", "teal": "turquesa", "lavender": "lavanda", "burgundy": "bordó",
            "neutral": "neutral"
        ]
        return translations[english] ?? english
    }
}

// MARK: - User Intent Enum
enum UserIntent {
    case colorAdvice
    case outfitRecommendation
    case colorMatching
    case styleAdvice
    case trends
    case wardrobeHelp
    case occasionHelp
    case general
    case unknown
}

// MARK: - Legacy Fallback (for very old iOS versions)
final class BasicFallbackService: AIChatServiceProtocol {
    func sendMessage(_ message: String, context: ChatContext) async throws -> String {
        let isSpanish = context.language == .spanish ||
            message.lowercased().contains("como") ||
            message.lowercased().contains("que")
        
        return isSpanish
            ? "Necesitas iOS 17.2 o superior para usar el asistente de estilo completo."
            : "You need iOS 17.2 or later to use the full style assistant."
    }
}
