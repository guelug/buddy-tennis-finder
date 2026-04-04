import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var showingAttachmentOptions = false
    @State private var showingAttachmentPicker = false
    @State private var attachmentSource: UIImagePickerController.SourceType = .photoLibrary

    private var lang: Language {
        appState.preferredLanguage
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            profileContextCard

                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message)
                                    .padding(.horizontal)
                                    .id(message.id)
                            }

                            if viewModel.isLoading {
                                TypingIndicatorView()
                                    .padding(.horizontal)
                                    .id("typing-indicator")
                            }
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        scrollToBottom(using: proxy)
                    }
                    .onChange(of: viewModel.isLoading) { _, _ in
                        scrollToBottom(using: proxy)
                    }
                }

                chatInputBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Strings.chatStyleAssistant(lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Strings.chatNewConversation(lang)) {
                        viewModel.startNewConversation(appState: appState, modelContext: modelContext)
                    }
                    .font(.subheadline)
                }
            }
        }
        .task {
            viewModel.prepare(appState: appState, modelContext: modelContext)
        }
        .onChange(of: appState.currentUser?.updatedAt) { _, _ in
            viewModel.setContext(from: appState)
        }
        .confirmationDialog(
            text("Añadir foto", "Add photo"),
            isPresented: $showingAttachmentOptions,
            titleVisibility: .visible
        ) {
            Button(text("Hacer foto", "Take photo")) {
                attachmentSource = .camera
                showingAttachmentPicker = true
            }
            Button(text("Elegir de la librería", "Choose from library")) {
                attachmentSource = .photoLibrary
                showingAttachmentPicker = true
            }
            Button(text("Cancelar", "Cancel"), role: .cancel) {}
        }
        .sheet(isPresented: $showingAttachmentPicker) {
            ImagePicker(sourceType: attachmentSource) { image in
                viewModel.attachedImage = image
            }
        }
    }

    private var profileContextCard: some View {
        let profile = appState.currentUser?.personalStylingProfile ?? PersonalStylingProfile()

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Image(systemName: profile.isCompleteEnough ? "sparkles.rectangle.stack.fill" : "person.text.rectangle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.primary)

                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.isCompleteEnough
                         ? text("Contexto personal activo", "Personal context active")
                         : text("Afina tus respuestas", "Sharpen your recommendations"))
                        .font(.headline)

                    Text(
                        profile.isCompleteEnough
                            ? text(
                                "El chat ya está teniendo en cuenta tu estilo, prioridades y rutina. Si algo cambia, dímelo aquí y lo actualizaré.",
                                "Chat is already using your style, priorities, and routine. If anything changes, tell me here and I'll update it."
                            )
                            : text(
                                "Puedes contestar aquí cosas como tu trabajo, tus eventos habituales o cómo te gusta proyectarte. También puedes adjuntar una foto de una prenda y pedirme que la añada al armario.",
                                "You can answer here with details like your job, usual events, or how you like to come across. You can also attach a garment photo and ask me to add it to your closet."
                            )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            if profile.isCompleteEnough, !profile.highlightTags(in: lang).isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: Theme.Spacing.xs)], spacing: Theme.Spacing.xs) {
                    ForEach(profile.highlightTags(in: lang), id: \.self) { tag in
                        Text(tag)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemBackground))
                            .clipShape(Capsule())
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Theme.Spacing.xs)], spacing: Theme.Spacing.xs) {
                    ForEach(quickProfilePrompts, id: \.self) { prompt in
                        Button {
                            viewModel.inputText = prompt
                            isInputFocused = true
                        } label: {
                            Text(prompt)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.Colors.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.Colors.primary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
        .padding(.horizontal)
    }

    private var quickProfilePrompts: [String] {
        if lang == .spanish {
            return [
                "Trabajo en oficina y necesito verme profesional pero cercana.",
                "Suelo tener cenas, reuniones y algunos eventos familiares.",
                "Me identifico con un estilo minimalista y priorizo comodidad."
            ]
        }

        return [
            "I work in an office and need to look professional but approachable.",
            "I usually have dinners, meetings, and some family events.",
            "I identify with a minimal style and comfort matters most to me."
        ]
    }

    private var chatInputBar: some View {
        VStack(spacing: 0) {
            Divider()

            if let attachedImage = viewModel.attachedImage {
                HStack(spacing: 12) {
                    Image(uiImage: attachedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(text("Foto lista para enviar", "Photo ready to send"))
                            .font(.subheadline.weight(.semibold))
                        Text(text("Si escribes “añádela al armario”, la guardaré en el closet.", "If you write “add it to my closet”, I'll save it in your closet."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        viewModel.attachedImage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .background(Color(.systemGroupedBackground))
            }

            HStack(alignment: .bottom, spacing: 12) {
                Button {
                    showingAttachmentOptions = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.Colors.primary)
                }

                TextField(Strings.chatAskFashion(lang), text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .lineLimit(1...5)
                    .focused($isInputFocused)

                Button {
                    Task {
                        await viewModel.sendMessage(appState: appState, modelContext: modelContext)
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(
                            viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.gray.opacity(0.5)
                                : Theme.Colors.primary
                        )
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
        }
    }

    private func scrollToBottom(using proxy: ScrollViewProxy) {
        let targetID: AnyHashable
        if viewModel.isLoading {
            targetID = "typing-indicator"
        } else if let lastID = viewModel.messages.last?.id {
            targetID = lastID
        } else {
            targetID = "profile-context"
        }

        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(targetID, anchor: .bottom)
        }
    }

    private func text(_ spanish: String, _ english: String) -> String {
        lang == .spanish ? spanish : english
    }
}

struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        let isUser = message.role == .user

        HStack {
            if isUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(isUser ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isUser ? Theme.Colors.primary : Color(.systemBackground))
                    .clipShape(ChatBubbleShape(isUser: isUser))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)

                Text(formattedTime(from: message.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !isUser {
                Spacer(minLength: 60)
            }
        }
    }

    private func formattedTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct TypingIndicatorView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color.secondary.opacity(0.55))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemBackground))
                .clipShape(ChatBubbleShape(isUser: false))
            }

            Spacer(minLength: 60)
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
                control: CGPoint(x: rect.maxX - tailSize / 2, y: rect.maxY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - tailSize, y: rect.maxY - radius + tailSize),
                control: CGPoint(x: rect.maxX, y: rect.maxY - radius / 2)
            )
        } else {
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: radius, height: radius))
            path.move(to: CGPoint(x: rect.minX + tailSize, y: rect.maxY - radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY),
                control: CGPoint(x: rect.minX + tailSize / 2, y: rect.maxY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + tailSize, y: rect.maxY - radius + tailSize),
                control: CGPoint(x: rect.minX, y: rect.maxY - radius / 2)
            )
        }

        return path
    }
}

#Preview {
    ChatView()
        .environment(AppState())
        .modelContainer(for: [User.self, Conversation.self, Message.self], inMemory: true)
}
