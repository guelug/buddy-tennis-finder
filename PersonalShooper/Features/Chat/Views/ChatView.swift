import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    var conversation: Conversation?

    @State private var viewModel = ChatViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(viewModel.messages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

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
            if let conversation = conversation {
                viewModel.loadConversation(conversation)
            }
            viewModel.setContext(from: appState)
        }
    }

    private var chatInputArea: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Ask about fashion, colors, or style...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(Theme.Spacing.sm)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
                .lineLimit(1...5)

            Button {
                Task {
                    await viewModel.sendMessage()
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(viewModel.inputText.isEmpty ? .gray : Theme.Colors.primary)
            }
            .disabled(viewModel.inputText.isEmpty || viewModel.isLoading)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
    }
}

struct ChatBubbleView: View {
    let message: Message

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

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
}

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

#Preview {
    NavigationStack {
        ChatView(conversation: nil)
            .environment(AppState())
    }
}
