#if canImport(FoundationModels)
import Foundation
import FoundationModels
import SwiftData

// MARK: - Foundation Models Service Implementation
/// Service that uses Apple's native Foundation Models framework for on-device AI
@available(iOS 26.0, *)
final class FoundationModelsService: FoundationModelsServiceProtocol {
    
    private var session: LanguageModelSession?
    private let clothingTool: ClothingRecommendationTool
    private let fashionSystemPrompt: String
    
    var isStreaming: Bool = false
    
    init(clothingService: ClothingDataServiceProtocol? = nil) {
        self.clothingTool = ClothingRecommendationTool(clothingService: clothingService)
        
        self.fashionSystemPrompt = """
        You are Personal Shooper, a professional AI fashion stylist assistant. Your role is to help users with:
        - Color recommendations based on their personal color palette
        - Outfit suggestions for various occasions
        - Style advice matching their preferences
        - Fashion tips and trends
        - Recommendations from their existing wardrobe
        
        Important guidelines:
        - Always be helpful, friendly, and professional
        - Respect user privacy - never ask for personal information beyond fashion preferences
        - Provide specific, actionable advice
        - Consider the user's personal color palette and style preferences when giving recommendations
        - Use the closet tool when users ask about items they already own
        - If unsure about something, suggest consulting a human stylist
        """
        
        setupSession()
    }
    
    private func setupSession() {
        session = LanguageModelSession(tools: [clothingTool]) { [fashionSystemPrompt] in
            fashionSystemPrompt
        }
    }
    
    /// Pre-warms the model for faster responses
    func prewarm() async {
        await session?.prewarm()
    }
    
    // MARK: - Send Message (Non-streaming)
    func sendMessage(_ message: String, context: ChatContext) async throws -> String {
        let prompt = buildPrompt(message: message, context: context)
        
        guard let session = session else {
            throw AIError.notSupported
        }
        
        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            throw AIError.responseFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Stream Message
    func streamMessage(_ message: String, context: ChatContext) -> AsyncThrowingStream<String, Error> {
        let prompt = buildPrompt(message: message, context: context)
        
        guard let session = session else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: AIError.notSupported)
            }
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = session.streamResponse(to: prompt)
                    for try await partialResponse in stream {
                        continuation.yield(partialResponse)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Guided Generation for Structured Output
    /// Generates structured outfit recommendations
    func generateOutfitRecommendation(
        occasion: String,
        context: ChatContext
    ) async throws -> OutfitRecommendation {
        let prompt = """
        Create a complete outfit recommendation for the following occasion: \(occasion).
        User's palette: \(context.userPalette?.seasonalType.displayName ?? "Unknown")
        User's style preferences: \(context.userStylePreferences.joined(separator: ", "))
        """
        
        guard let session = session else {
            throw AIError.notSupported
        }
        
        let response = try await session.respond(to: prompt, generating: OutfitRecommendation.self)
        return response.content
    }
    
    // MARK: - Private Methods
    private func buildPrompt(message: String, context: ChatContext) -> String {
        var promptParts: [String] = []
        
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
        
        // Recent conversation context (limited to reduce tokens)
        if !context.recentConversations.isEmpty {
            promptParts.append("Recent conversation context:")
            for conv in context.recentConversations.prefix(1) {
                for msg in conv.messages.suffix(2) {
                    let role = msg.role == .user ? "User" : "Assistant"
                    promptParts.append("\(role): \(msg.content)")
                }
            }
        }
        
        // Current message
        promptParts.append("\nUser's current message: \(message)")
        
        return promptParts.joined(separator: "\n\n")
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
}

// MARK: - Clothing Recommendation Tool
@available(iOS 26.0, *)
struct ClothingRecommendationTool: Tool {
    let clothingService: ClothingDataServiceProtocol?
    
    var name: String { "closet_recommendation" }
    var description: String {
        "Search user's closet for clothing items matching specific criteria like category, occasion, color, or style."
    }
    
    @Generable
    struct Arguments {
        @Guide(description: "Clothing category to search for (tops, bottoms, dresses, shoes, accessories, outerwear)")
        let category: String?
        
        @Guide(description: "Occasion or context for the outfit (casual, formal, work, party, workout)")
        let occasion: String?
        
        @Guide(description: "Preferred color or color family")
        let colorPreference: String?
        
        @Guide(description: "Style preference (classic, trendy, minimalist, bohemian, etc.)")
        let stylePreference: String?
    }
    
    nonisolated func call(arguments: Arguments) async throws -> ToolOutput {
        guard let service = clothingService else {
            return ToolOutput("No closet data available. The user hasn't added any clothing items yet.")
        }
        
        let items = await service.searchItems(
            category: arguments.category,
            occasion: arguments.occasion,
            colorPreference: arguments.colorPreference,
            stylePreference: arguments.stylePreference
        )
        
        if items.isEmpty {
            return ToolOutput("No matching items found in the closet.")
        }
        
        let descriptions = items.map { "- \($0.name) (\($0.category.displayName))" }.joined(separator: "\n")
        return ToolOutput("Found the following items in the closet:\n\(descriptions)")
    }
}

// MARK: - Outfit Recommendation (Structured Output)
@Generable
struct OutfitRecommendation {
    @Guide(description: "Name or title for this outfit combination")
    let name: String
    
    @Guide(description: "Detailed description of why this outfit works")
    let description: String
    
    @Guide(description: "List of clothing items in this outfit")
    let items: [OutfitItem]
    
    @Guide(description: "Color coordination notes")
    let colorNotes: String
    
    @Guide(description: "Styling tips for this outfit")
    let stylingTips: [String]
    
    @Guide(description: "Suitable occasions for this outfit", .range(0...100))
    let occasionMatch: Int
}

@Generable
struct OutfitItem {
    @Guide(description: "Type of clothing item (shirt, pants, dress, shoes, etc.)")
    let type: String
    
    @Guide(description: "Recommended color for this item")
    let recommendedColor: String
    
    @Guide(description: "Why this item works in the outfit")
    let reasoning: String
}

// MARK: - Foundation Models Factory Helpers
extension AIChatServiceFactory {
    @available(iOS 26.0, *)
    static func createFoundationModelsService(
        clothingService: ClothingDataServiceProtocol? = nil
    ) -> AIChatServiceProtocol {
        return FoundationModelsService(clothingService: clothingService)
    }

    @available(iOS 26.0, *)
    static func createStreamingService(
        clothingService: ClothingDataServiceProtocol? = nil
    ) -> FoundationModelsServiceProtocol {
        return FoundationModelsService(clothingService: clothingService)
    }
}

#endif
