import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    var conversation: Conversation?
    
    @State private var viewModel = ChatViewModel()
    @State private var showAIStatus = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // AI Status indicator
            if showAIStatus {
                aiStatusBar
            }
            
            // Messages
            messagesScrollView
            
            // Input area
            chatInputArea
        }
        .navigationTitle("AI Stylist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        viewModel.startNewConversation()
                    } label: {
                        Label("New Conversation", systemImage: "plus")
                    }
                    
                    Button {
                        Task {
                            await viewModel.generateConversationTitle()
                        }
                    } label: {
                        Label("Generate Title", systemImage: "text.badge.star")
                    }
                    
                    Button(role: .destructive) {
                        viewModel.clearConversation()
                    } label: {
                        Label("Clear Chat", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            setupViewModel()
        }
    }
    
    // MARK: - Subviews
    
    private var aiStatusBar: some View {
        HStack(spacing: 6) {
            Image(systemName: aiStatusIcon)
                .foregroundStyle(aiStatusColor)
                .font(.caption)
            
            Text(aiStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(aiStatusColor.opacity(0.1))
    }
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(viewModel.messages) { message in
                        ChatBubbleView(
                            message: message,
                            isStreaming: viewModel.isStreaming && message.id == viewModel.messages.last?.id
                        )
                        .id(message.id)
                    }
                    
                    // Typing indicator
                    if viewModel.isLoading && !viewModel.isStreaming {
                        TypingIndicatorView()
                            .id("typing")
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.streamingText) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
            }
        }
    }
    
    private var chatInputArea: some View {
        VStack(spacing: 0) {
            // Quick action buttons
            if viewModel.messages.isEmpty {
                quickActionsScrollView
            }
            
            // Text input
            HStack(spacing: Theme.Spacing.sm) {
                TextField(
                    placeholderText,
                    text: $viewModel.inputText,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .padding(Theme.Spacing.sm)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
                .lineLimit(1...5)
                .focused($isInputFocused)
                
                Button {
                    Task {
                        await viewModel.sendMessage()
                        isInputFocused = false
                    }
                } label: {
                    Image(systemName: viewModel.isLoading ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(viewModel.inputText.isEmpty && !viewModel.isLoading ? .gray : Theme.Colors.primary)
                }
                .disabled(viewModel.inputText.isEmpty && !viewModel.isLoading)
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.cardBackground)
    }
    
    private var quickActionsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                QuickActionButton(
                    icon: "paintpalette",
                    title: quickActionTitle(.colorAnalysis)
                ) {
                    Task {
                        await viewModel.sendQuickAction(.colorAnalysis)
                    }
                }
                
                QuickActionButton(
                    icon: "tshirt",
                    title: quickActionTitle(.outfitSuggestion)
                ) {
                    Task {
                        await viewModel.sendQuickAction(.outfitSuggestion)
                    }
                }
                
                QuickActionButton(
                    icon: "sparkles",
                    title: quickActionTitle(.trendInfo)
                ) {
                    Task {
                        await viewModel.sendQuickAction(.trendInfo)
                    }
                }
                
                QuickActionButton(
                    icon: "hanger",
                    title: quickActionTitle(.wardrobeHelp)
                ) {
                    Task {
                        await viewModel.sendQuickAction(.wardrobeHelp)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
    }
    
    // MARK: - Helpers
    
    private func setupViewModel() {
        if let conversation = conversation {
            viewModel.loadConversation(conversation)
        }
        viewModel.setContext(from: appState, modelContext: modelContext)
        showAIStatus = viewModel.aiAvailabilityStatus != .unknown
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        if let lastMessage = viewModel.messages.last {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        } else if viewModel.isLoading {
            proxy.scrollTo("typing", anchor: .bottom)
        }
    }
    
    private var placeholderText: String {
        appState.preferredLanguage == .spanish
            ? "Pregunta sobre moda, colores o estilo..."
            : "Ask about fashion, colors, or style..."
    }
    
    private var aiStatusIcon: String {
        switch viewModel.aiAvailabilityStatus {
        case .foundationModels:
            return "checkmark.shield.fill"
        case .fallback:
            return "exclamationmark.shield.fill"
        case .unavailable, .unknown:
            return "xmark.shield.fill"
        }
    }
    
    private var aiStatusColor: Color {
        switch viewModel.aiAvailabilityStatus {
        case .foundationModels:
            return .green
        case .fallback:
            return .orange
        case .unavailable, .unknown:
            return .red
        }
    }
    
    private var aiStatusText: String {
        switch viewModel.aiAvailabilityStatus {
        case .foundationModels:
            return appState.preferredLanguage == .spanish
                ? "Apple Intelligence activo"
                : "Apple Intelligence active"
        case .fallback:
            return appState.preferredLanguage == .spanish
                ? "Modo fallback (sin Apple Intelligence)"
                : "Fallback mode (no Apple Intelligence)"
        case .unavailable:
            return appState.preferredLanguage == .spanish
                ? "IA no disponible"
                : "AI not available"
        case .unknown:
            return ""
        }
    }
    
    private func quickActionTitle(_ action: QuickChatAction) -> String {
        let isSpanish = appState.preferredLanguage == .spanish
        
        switch action {
        case .colorAnalysis:
            return isSpanish ? "Análisis de color" : "Color Analysis"
        case .outfitSuggestion:
            return isSpanish ? "Sugerir outfit" : "Suggest Outfit"
        case .trendInfo:
            return isSpanish ? "Tendencias" : "Trends"
        case .wardrobeHelp:
            return isSpanish ? "Organizar armario" : "Organize Closet"
        }
    }
}

// MARK: - Chat Bubble View
struct ChatBubbleView: View {
    let message: Message
    var isStreaming: Bool = false
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .padding(Theme.Spacing.sm)
                    .background(message.role == .user ? Theme.Colors.userBubble : Theme.Colors.assistantBubble)
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                
                if isStreaming {
                    HStack(spacing: 4) {
                        Text("typing")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        StreamingDotsView()
                    }
                } else {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicatorView: View {
    @State private var offset: CGFloat = 0
    
    var body: some View {
        HStack {
            Spacer(minLength: 60)
            
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .offset(y: offset)
                
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .offset(y: offset * 0.5)
                
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .offset(y: offset * 0.8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Theme.Colors.assistantBubble)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            
            Spacer(minLength: 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                offset = -6
            }
        }
    }
}

// MARK: - Streaming Dots
struct StreamingDotsView: View {
    @State private var phase = 0
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color(.tertiaryLabel))
                    .frame(width: 3, height: 3)
                    .opacity(phase == index ? 1 : 0.3)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: false)) {
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))
            .foregroundStyle(.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chat History View
struct ChatHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    
    var body: some View {
        List {
            if conversations.isEmpty {
                ContentUnavailableView(
                    "No Conversations",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Start a new conversation with your AI stylist")
                )
            } else {
                ForEach(conversations) { conversation in
                    NavigationLink {
                        ChatView(conversation: conversation)
                    } label: {
                        ConversationRowContent(conversation: conversation)
                    }
                }
                .onDelete(perform: deleteConversations)
            }
        }
        .navigationTitle("Chat History")
    }
    
    private func deleteConversations(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(conversations[index])
        }
    }
}

// MARK: - Conversation Row Content
struct ConversationRowContent: View {
    let conversation: Conversation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(conversation.title)
                .font(.headline)
            
            if let lastMessage = conversation.messages.last {
                Text(lastMessage.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Text(conversation.updatedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ChatView(conversation: nil)
            .environment(AppState())
    }
}
