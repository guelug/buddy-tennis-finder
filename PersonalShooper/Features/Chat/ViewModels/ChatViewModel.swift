import SwiftUI
import SwiftData

/// ViewModel for managing chat interactions with AI
@Observable
@MainActor
final class ChatViewModel {
    
    // MARK: - Published Properties
    var inputText: String = ""
    var messages: [Message] = []
    var isLoading: Bool = false
    var isStreaming: Bool = false
    var errorMessage: String?
    var streamingText: String = ""
    var aiAvailabilityStatus: AIAvailabilityStatus = .unknown
    
    // MARK: - Private Properties
    private var conversation: Conversation?
    private var chatService: AIChatServiceProtocol?
    private var context: ChatContext = ChatContext()
    private var currentStreamingTask: Task<Void, Never>?
    
    // MARK: - Setup
    
    /// Configures the ViewModel with app state and initializes the AI service
    func setContext(from appState: AppState, modelContext: ModelContext? = nil) {
        context.language = appState.preferredLanguage
        
        if let user = appState.currentUser {
            context.userPalette = user.personalPalette
            context.userStylePreferences = user.stylePreferences
        }
        
        // Initialize with clothing service if available
        let clothingService: ClothingDataService? = modelContext.map { ClothingDataService(modelContext: $0) }
        initializeChatService(clothingService: clothingService)
    }
    
    private func initializeChatService(clothingService: ClothingDataServiceProtocol? = nil) {
        chatService = AIChatServiceFactory.createService()
        aiAvailabilityStatus = .fallback
    }
    
    // MARK: - Conversation Management
    
    func loadConversation(_ conversation: Conversation) {
        self.conversation = conversation
        self.messages = conversation.messages
    }
    
    func startNewConversation() {
        conversation = Conversation(title: "New Conversation")
        messages = []
        inputText = ""
        errorMessage = nil
        streamingText = ""
    }
    
    func clearConversation() {
        messages = []
        conversation?.messages.removeAll()
        errorMessage = nil
        streamingText = ""
        currentStreamingTask?.cancel()
    }
    
    // MARK: - Message Sending
    
    func sendMessage(useStreaming: Bool = true) async {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }
        
        // Cancel any existing streaming
        currentStreamingTask?.cancel()
        
        // Create user message
        let userMessage = Message(role: .user, content: trimmedInput)
        messages.append(userMessage)
        conversation?.addMessage(userMessage)
        inputText = ""
        errorMessage = nil
        
        isLoading = true
        
        await sendNonStreamingMessage(trimmedInput)
    }
    
    private func sendNonStreamingMessage(_ text: String) async {
        do {
            let response: String
            if let service = chatService {
                response = try await service.sendMessage(text, context: context)
            } else {
                response = await getDefaultResponse()
            }
            
            let assistantMessage = Message(role: .assistant, content: response)
            messages.append(assistantMessage)
            conversation?.addMessage(assistantMessage)
            
        } catch let error as AIError {
            handleError(error)
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Quick Actions
    
    func sendQuickAction(_ action: QuickChatAction) async {
        let prompt: String
        
        switch action {
        case .colorAnalysis:
            prompt = context.language == .spanish
                ? "Analiza mi paleta de colores y dime qué colores me favorecen más"
                : "Analyze my color palette and tell me which colors suit me best"
        case .outfitSuggestion:
            prompt = context.language == .spanish
                ? "Sugiéreme un outfit completo para hoy"
                : "Suggest a complete outfit for today"
        case .trendInfo:
            prompt = context.language == .spanish
                ? "Cuéntame sobre las tendencias actuales de moda"
                : "Tell me about current fashion trends"
        case .wardrobeHelp:
            prompt = context.language == .spanish
                ? "Ayúdame a organizar mi armario"
                : "Help me organize my wardrobe"
        }
        
        inputText = prompt
        await sendMessage()
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error, fallbackToLastMessage: Bool = false) {
        let errorContent: String
        
        if let aiError = error as? AIError {
            errorContent = aiError.localizedDescription ?? "An error occurred"
            errorMessage = aiError.localizedDescription
        } else {
            errorContent = "Sorry, I couldn't process your request. Please try again."
            errorMessage = error.localizedDescription
        }
        
        if fallbackToLastMessage, let lastIndex = messages.indices.last {
            messages[lastIndex].content = errorContent
            conversation?.addMessage(messages[lastIndex])
        } else {
            let errorMessage = Message(role: .assistant, content: errorContent)
            messages.append(errorMessage)
            conversation?.addMessage(errorMessage)
        }
    }
    
    private func getDefaultResponse() async -> String {
        let isSpanish = context.language == .spanish
        return isSpanish
            ? "Lo siento, el servicio de IA no está disponible en este momento."
            : "Sorry, the AI service is not available at this time."
    }
    
    // MARK: - Conversation Title Generation
    
    func generateConversationTitle() async {
        guard let firstUserMessage = messages.first(where: { $0.role == .user })?.content else { return }
        
        // Simple title generation from first message
        let maxLength = 30
        let title: String
        
        if firstUserMessage.count > maxLength {
            let endIndex = firstUserMessage.index(firstUserMessage.startIndex, offsetBy: maxLength)
            title = String(firstUserMessage[..<endIndex]) + "..."
        } else {
            title = firstUserMessage
        }
        
        conversation?.title = title
    }
}

// MARK: - Supporting Types

enum QuickChatAction {
    case colorAnalysis
    case outfitSuggestion
    case trendInfo
    case wardrobeHelp
}

enum AIAvailabilityStatus {
    case unknown
    case foundationModels
    case fallback
    case unavailable
}

// MARK: - Clothing Data Service
@MainActor
final class ClothingDataService: ClothingDataServiceProtocol {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func searchItems(
        category: String?,
        occasion: String?,
        colorPreference: String?,
        stylePreference: String?
    ) async -> [ClothingItemSummary] {
        let descriptor = FetchDescriptor<ClothingItem>()
        
        do {
            let items = try modelContext.fetch(descriptor)
            
            return items.compactMap { item in
                // Filter by category if specified
                if let category = category {
                    let categoryMatch = item.category.displayName.lowercased().contains(category.lowercased()) ||
                                      category.lowercased().contains(item.category.displayName.lowercased())
                    if !categoryMatch { return nil }
                }
                
                // Filter by color if specified
                if let color = colorPreference {
                    let colorMatch = item.colorTags.contains { $0.lowercased().contains(color.lowercased()) }
                    if !colorMatch { return nil }
                }
                
                // Filter by style if specified
                if let style = stylePreference {
                    let styleMatch = item.styleTags.contains { $0.lowercased().contains(style.lowercased()) }
                    if !styleMatch { return nil }
                }
                
                return ClothingItemSummary(
                    id: item.id,
                    name: item.name,
                    category: item.category,
                    colorTags: item.colorTags,
                    styleTags: item.styleTags
                )
            }
        } catch {
            print("Failed to fetch clothing items: \(error)")
            return []
        }
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
