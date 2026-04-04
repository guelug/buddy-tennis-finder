import SwiftUI
import SwiftData

@Observable
@MainActor
final class ChatViewModel {
    var inputText: String = ""
    var messages: [Message] = []
    var isLoading: Bool = false
    var errorMessage: String?
    
    private var conversation: Conversation?
    private var context: ChatContext = ChatContext()
    
    func setContext(from appState: AppState) {
        context.language = appState.preferredLanguage
        if let user = appState.currentUser {
            context.userPalette = user.personalPalette
            context.userStylePreferences = user.stylePreferences
        }
    }
    
    func sendMessage() async {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }
        
        let userMessage = Message(role: .user, content: trimmedInput)
        messages.append(userMessage)
        conversation?.addMessage(userMessage)
        inputText = ""
        isLoading = true
        
        // Generate response locally
        let response = generateLocalResponse(for: trimmedInput)
        
        let assistantMessage = Message(role: .assistant, content: response)
        messages.append(assistantMessage)
        conversation?.addMessage(assistantMessage)
        
        isLoading = false
    }
    
    private func generateLocalResponse(for message: String) -> String {
        let lowercased = message.lowercased()
        
        if lowercased.contains("color") || lowercased.contains("colores") {
            return "For color advice, I recommend choosing tones that complement your skin undertone. Warm undertones look great in earth tones, while cool undertones shine in jewel colors."
        } else if lowercased.contains("outfit") || lowercased.contains("ropa") {
            return "I'd love to help you put together an outfit! Consider the occasion and your personal style. A classic combination is a well-fitted top with complementary bottoms."
        } else if lowercased.contains("style") || lowercased.contains("estilo") {
            return "Personal style is about expressing yourself! Start with pieces that make you feel confident and build from there."
        } else {
            return "I'm your AI stylist here to help with fashion advice! Ask me about colors, outfits, or style tips."
        }
    }
}
