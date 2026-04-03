import SwiftUI
import SwiftData

@Observable
final class ChatViewModel {
    var inputText: String = ""
    var messages: [Message] = []
    var isLoading: Bool = false
    var errorMessage: String?

    private var conversation: Conversation?
    private var chatService: AIChatServiceProtocol?
    private var context: ChatContext = ChatContext()

    func setContext(from appState: AppState) {
        context.language = appState.preferredLanguage
        if let user = appState.currentUser {
            context.userPalette = user.personalPalette
            context.userStylePreferences = user.stylePreferences
        }
        initializeChatService()
    }

    private func initializeChatService() {
        if #available(iOS 17.2, *) {
            chatService = AIChatServiceFactory.createAppleIntelligenceService()
        } else {
            chatService = AIChatServiceFactory.createFallbackService()
        }
    }

    func loadConversation(_ conversation: Conversation) {
        self.conversation = conversation
        self.messages = conversation.messages
    }

    func startNewConversation() {
        conversation = Conversation(title: "New Conversation")
        messages = []
        inputText = ""
        errorMessage = nil
    }

    func clearConversation() {
        messages = []
        conversation?.messages.removeAll()
        errorMessage = nil
    }

    @MainActor
    func sendMessage() async {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }

        // Create user message
        let userMessage = Message(role: .user, content: trimmedInput)
        messages.append(userMessage)
        conversation?.addMessage(userMessage)
        inputText = ""
        errorMessage = nil

        isLoading = true

        do {
            let response: String
            if let service = chatService {
                response = try await service.sendMessage(trimmedInput, context: context)
            } else {
                response = await getDefaultResponse()
            }

            let assistantMessage = Message(role: .assistant, content: response)
            messages.append(assistantMessage)
            conversation?.addMessage(assistantMessage)

        } catch let error as AIError {
            let errorResponse = Message(role: .assistant, content: error.localizedDescription ?? "An error occurred")
            messages.append(errorResponse)
            errorMessage = error.localizedDescription
        } catch {
            let errorResponse = Message(role: .assistant, content: "Sorry, I couldn't process your request. Please try again.")
            messages.append(errorResponse)
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    private func getDefaultResponse() async -> String {
        let isSpanish = context.language == .spanish
        return isSpanish
            ? "Lo siento, el servicio de IA no está disponible en este momento."
            : "Sorry, the AI service is not available at this time."
    }
}

// MARK: - Message Extensions
extension Message {
    static func user(_ content: String) -> Message {
        Message(role: .user, content: content)
    }

    static func assistant(_ content: String) -> Message {
        Message(role: .assistant, content: content)
    }
}
