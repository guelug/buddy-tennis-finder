import Foundation
import NaturalLanguage

// MARK: - AI Service Errors
enum AIError: LocalizedError {
    case notSupported
    case promptFailed
    case responseFailed(String)
    case contentFiltered
    case timeout

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

// MARK: - Apple Intelligence Service
@available(iOS 17.2, *)
final class AppleIntelligenceService: AIChatServiceProtocol {

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

    func sendMessage(_ message: String, context: ChatContext) async throws -> String {
        let prompt = buildPrompt(message: message, context: context)

        do {
            let response = try await generateResponseWithAppleIntelligence(prompt)
            return response
        } catch {
            // Fall back to keyword-based responses
            return generateContextualFallback(prompt: prompt, context: context)
        }
    }

    private func buildPrompt(message: String, context: ChatContext) -> String {
        var promptParts: [String] = []

        // System instruction
        promptParts.append(fashionSystemPrompt)

        // Language preference
        let languageInstruction = context.language == .spanish
            ? "Respond in Spanish only."
            : "Respond in English only."
        promptParts.append(languageInstruction)

        // User's personal palette context
        if let palette = context.userPalette {
            promptParts.append("User's personal color analysis:")
            promptParts.append("- Undertone: \(palette.undertone.displayName)")
            promptParts.append("- Seasonal type: \(palette.seasonalType.displayName)")

            let colorNames = palette.recommendedColors.prefix(5).map { colorName(for: $0) }.joined(separator: ", ")
            if !colorNames.isEmpty {
                promptParts.append("- Recommended colors: \(colorNames)")
            }
        }

        // Style preferences
        if !context.userStylePreferences.isEmpty {
            let styles = context.userStylePreferences.joined(separator: ", ")
            promptParts.append("User's style preferences: \(styles)")
        }

        // Recent conversation context
        if !context.recentConversations.isEmpty {
            promptParts.append("Recent conversation context:")
            for conv in context.recentConversations.prefix(1) {
                for msg in conv.messages.suffix(3) {
                    let role = msg.role == .user ? "User" : "Assistant"
                    promptParts.append("\(role): \(msg.content)")
                }
            }
        }

        // Current message
        promptParts.append("\nUser's current message: \(message)")
        promptParts.append("\nProvide a helpful, concise response as Personal Shooper:")

        return promptParts.joined(separator: "\n\n")
    }

    private func generateResponseWithAppleIntelligence(_ prompt: String) async throws -> String {
        // Apple Intelligence with Foundation Models API is not yet publicly available
        // For iOS 18+, use the built-in fallback system
        // The real Apple Intelligence integration will come when Apple releases the public API
        throw AIError.notSupported
    }

    private func generateContextualFallback(prompt: String, context: ChatContext) -> String {
        // Fallback response generator using keyword analysis
        // This is used when Apple Intelligence is unavailable
        let lowercasedPrompt = prompt.lowercased()

        // Detect language
        let isSpanish = context.language == .spanish ||
            lowercasedPrompt.contains("como") ||
            lowercasedPrompt.contains("que") ||
            lowercasedPrompt.contains("colores")

        // Detect intent based on keywords
        if lowercasedPrompt.contains("color") || lowercasedPrompt.contains("colores") || lowercasedPrompt.contains("tono") {
            return colorAdvice(isSpanish: isSpanish, palette: context.userPalette)
        } else if lowercasedPrompt.contains("outfit") || lowercasedPrompt.contains("vestir") || lowercasedPrompt.contains("traje") || lowercasedPrompt.contains("ropa") {
            return outfitAdvice(isSpanish: isSpanish)
        } else if lowercasedPrompt.contains("match") || lowercasedPrompt.contains("combinar") || lowercasedPrompt.contains("combina") || lowercasedPrompt.contains("combinar") {
            return matchingAdvice(isSpanish: isSpanish)
        } else if lowercasedPrompt.contains("recommend") || lowercasedPrompt.contains("sugerir") || lowercasedPrompt.contains("sugerencia") {
            return recommendationAdvice(isSpanish: isSpanish, palette: context.userPalette)
        } else if lowercasedPrompt.contains("trends") || lowercasedPrompt.contains("tendencia") || lowercasedPrompt.contains("moda") {
            return trendsAdvice(isSpanish: isSpanish)
        } else {
            return generalAdvice(isSpanish: isSpanish)
        }
    }

    // MARK: - Fallback Response Generators

    private func colorAdvice(isSpanish: Bool, palette: PersonalPalette?) -> String {
        if isSpanish {
            var response = "Para consejos de color basados en tu paleta personal"
            if let palette = palette {
                response += ", te recomiendo colores que complementen tu tono \(palette.undertone.displayName.lowercased()). "
                response += "Los colores más favorecedores para ti incluyen tonos que realzan tu luminosidad natural."
            } else {
                response = "Para darte mejores consejos de color, te recomiendo completar tu perfil con una foto para analizar tu paleta personal."
            }
            return response
        }

        var response = "For color advice based on your personal palette"
        if let palette = palette {
            response += ", I recommend colors that complement your \(palette.undertone.displayName.lowercased()) undertone. "
            response += "The most flattering colors for you include tones that enhance your natural glow."
        } else {
            response = "To give you better color advice, I recommend completing your profile with a photo to analyze your personal palette."
        }
        return response
    }

    private func outfitAdvice(isSpanish: Bool) -> String {
        if isSpanish {
            return "¡Me encantaría ayudarte con un outfit! Para darte los mejores consejos, ¿podrías decirme la ocasión y tu estilo preferido? Por ejemplo: casual, formal, elegante, etc."
        }
        return "I'd love to help you put together an outfit! To give you the best advice, could you tell me the occasion and your preferred style? For example: casual, formal, business, evening, etc."
    }

    private func matchingAdvice(isSpanish: Bool) -> String {
        if isSpanish {
            return "¡Gran pregunta sobre combinación de colores! Para un look cohesivo, intenta usar colores de la misma familia o complementarios. ¿Hay colores específicos que te gustaría combinar?"
        }
        return "Great question about color matching! For a cohesive look, try using colors from the same family or complementary opposites. Which specific colors would you like to match?"
    }

    private func recommendationAdvice(isSpanish: Bool, palette: PersonalPalette?) -> String {
        if isSpanish {
            var response = "Aquí están mis sugerencias basadas en tus preferencias"
            if let palette = palette {
                response += " y tu paleta personal de \(palette.seasonalType.displayName.lowercased())"
            }
            response += ". ¿Hay algo específico que te gustaría explorar más?"
            return response
        }

        var response = "Here are my suggestions based on your preferences"
        if let palette = palette {
            response += " and your \(palette.seasonalType.displayName.lowercased()) personal palette"
        }
        response += ". Is there something specific you'd like to explore further?"
        return response
    }

    private func trendsAdvice(isSpanish: Bool) -> String {
        if isSpanish {
            return "Las tendencias actuales de moda incluyen tonos neutrosversátiles, texturas táctiles como terciopelo y sarga, y siluetas oversize cómodas. ¿Te gustaría consejos específicos sobre alguna tendencia?"
        }
        return "Current fashion trends include versatile neutral tones, tactile textures like velvet and twill, and comfortable oversized silhouettes. Would you like specific advice on any trend?"
    }

    private func generalAdvice(isSpanish: Bool) -> String {
        if isSpanish {
            return "Como tu estilista personal, estoy aquí para ayudarte con consejos de moda, recomendaciones de color y tips de estilo. ¿Qué te gustaría explorar hoy?"
        }
        return "As your personal stylist, I'm here to help with fashion advice, color recommendations, and style tips. What would you like to explore today?"
    }

    // MARK: - Helper Methods

    private func colorName(for color: CodableColor) -> String {
        let r = color.red
        let g = color.green
        let b = color.blue

        // Determine color name based on RGB values
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
}

// MARK: - Service Factory
enum AIChatServiceFactory {
    @available(iOS 17.2, *)
    static func createAppleIntelligenceService() -> AIChatServiceProtocol {
        return AppleIntelligenceService()
    }

    static func createFallbackService() -> AIChatServiceProtocol {
        // Return a basic fallback service for older iOS versions
        return FallbackAIChatService()
    }
}

// MARK: - Fallback Service for older iOS
final class FallbackAIChatService: AIChatServiceProtocol {
    func sendMessage(_ message: String, context: ChatContext) async throws -> String {
        // Use NaturalLanguage framework for basic keyword extraction
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = message

        let isSpanish = context.language == .spanish ||
            message.lowercased().contains("como") ||
            message.lowercased().contains("que")

        // Simple keyword detection
        let lowercased = message.lowercased()

        if lowercased.contains("color") || lowercased.contains("colores") {
            return isSpanish
                ? "Para consejos de color precisos, te recomiendo usar un dispositivo con Apple Intelligence."
                : "For accurate color advice, I recommend using a device with Apple Intelligence."
        } else if lowercased.contains("outfit") || lowercased.contains("vestir") {
            return isSpanish
                ? "Para suggestions de outfits, te recomiendo usar un dispositivo con Apple Intelligence."
                : "For outfit suggestions, I recommend using a device with Apple Intelligence."
        }

        return isSpanish
            ? "Lo siento, necesito Apple Intelligence para responder mejor. ¿Hay algo más en lo que pueda ayudarte?"
            : "Sorry, I need Apple Intelligence to provide better responses. Is there anything else I can help with?"
    }
}
