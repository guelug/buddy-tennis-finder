import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @FocusState private var isInputFocused: Bool

    private var lang: Language {
        appState.preferredLanguage
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { message in
                            MessageBubbleView(message: message)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }

                chatInputBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Strings.chatStyleAssistant(lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !messages.isEmpty {
                        Button(Strings.chatNewConversation(lang)) {
                            messages.removeAll()
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }

    private var chatInputBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                TextField(Strings.chatAskFashion(lang), text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .lineLimit(1...5)
                    .focused($isInputFocused)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.5) : Theme.Colors.primary)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
        }
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let userMessage = ChatMessage(content: messageText, isUser: true)
        messages.append(userMessage)

        messageText = ""
        isInputFocused = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let responses = [
                "¡Buena pregunta! Basándome en las tendencias actuales, te recomiendo considerar tonos que complementen tu paleta personal.",
                "Para esa ocasión, te sugiero un look que combine comodidad y estilo. Las telas fluidas están de moda este año.",
                "Los colores que mejor te favorecen según tu paleta son los tonos cálidos. ¡Pero lo más importante es que te sientas cómodo!",
                "¡Me encanta esa idea! Para accessorizar, considera piezas minimalistas que realcen tu outfit sin sobrecargarlo."
            ]
            let aiResponse = ChatMessage(
                content: responses.randomElement() ?? responses[0],
                isUser: false
            )
            messages.append(aiResponse)
        }
    }
}

struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(message.isUser ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(message.isUser ? Theme.Colors.primary : Color(.systemBackground))
                    .clipShape(ChatBubbleShape(isUser: message.isUser))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)

                Text(message.formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !message.isUser { Spacer(minLength: 60) }
        }
    }
}

struct ChatBubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let tailSize: CGFloat = 6

        var path = Path()

        if isUser {
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: radius, height: radius))
            path.move(to: CGPoint(x: rect.maxX - tailSize, y: rect.maxY - radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY),
                control: CGPoint(x: rect.maxX - tailSize/2, y: rect.maxY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - tailSize, y: rect.maxY - radius + tailSize),
                control: CGPoint(x: rect.maxX, y: rect.maxY - radius/2)
            )
        } else {
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: radius, height: radius))
            path.move(to: CGPoint(x: rect.minX + tailSize, y: rect.maxY - radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY),
                control: CGPoint(x: rect.minX + tailSize/2, y: rect.maxY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + tailSize, y: rect.maxY - radius + tailSize),
                control: CGPoint(x: rect.minX, y: rect.maxY - radius/2)
            )
        }

        return path
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

#Preview {
    ChatView()
        .environment(AppState())
}
