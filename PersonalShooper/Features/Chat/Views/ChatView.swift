import SwiftUI
import SwiftData
import AVFoundation

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    var selectedTab: Binding<Int>? = nil
    @State private var viewModel = ChatViewModel()
    @State private var speechController = ChatSpeechController()
    @FocusState private var isInputFocused: Bool
    @State private var showingAttachmentOptions = false
    @State private var showingAttachmentPicker = false
    @State private var attachmentSource: UIImagePickerController.SourceType = .photoLibrary

    private var lang: Language {
        appState.preferredLanguage
    }

    private var preparedFeatures: ChatPreparedFeatures {
        appState.chatPreparedFeatures
    }

    /// The assistant's name shown as the title — "Rebe" or "Peter" depending on the user's name.
    private var assistantName: String {
        AssistantPersona.name(forUserNamed: appState.currentUser?.displayName)
    }

    private var hasDraftText: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            profileContextCard

                            ForEach(viewModel.messages) { message in
                                messageRow(for: message)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: message.role == .user ? .trailing : .leading).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }

                            if viewModel.isLoading {
                                TypingIndicatorView()
                                    .padding(.horizontal)
                                    .id("typing-indicator")
                            }
                        }
                        .padding(.vertical)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .animation(.snappy(duration: 0.28), value: viewModel.messages.count)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let selectedTab {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isInputFocused = false
                            selectedTab.wrappedValue = 0
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                        }
                        .buttonStyle(.premiumPressable)
                        .accessibilityLabel(text("Atrás", "Back"))
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(assistantName)
                        .font(.headline)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isInputFocused = false
                        viewModel.startNewConversation(appState: appState, modelContext: modelContext)
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.Colors.primary)
                            .frame(width: 34, height: 34)
                            .background(Theme.Colors.primary.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.premiumPressable)
                    .accessibilityLabel(text("Nueva conversación", "New conversation"))
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(text("Listo", "Done")) {
                        isInputFocused = false
                    }
                    .fontWeight(.semibold)
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
        .onDisappear {
            speechController.stop()
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
                    .buttonStyle(.premiumPressable)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .background(Color(.systemGroupedBackground))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .center, spacing: 12) {
                Button {
                    showingAttachmentOptions = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(Theme.Colors.primary)
                }
                .buttonStyle(.premiumPressable)

                TextField(Strings.chatAskFashion(lang), text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .submitLabel(.send)
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
                .buttonStyle(.premiumPressable)
                .sensoryFeedback(.success, trigger: viewModel.messages.count)
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

    private func messageRow(for message: Message) -> some View {
        MessageBubbleView(
            message: message,
            features: preparedFeatures,
            language: lang,
            speechController: speechController
        )
        .padding(.horizontal)
        .id(message.id)
    }
}

struct TypingIndicatorView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.secondary.opacity(0.45 + Double(index) * 0.18))
                            .frame(width: 8, height: 8)
                            .scaleEffect(isAnimating ? 1.25 : 0.72)
                            .opacity(isAnimating ? 1 : 0.55)
                            .animation(
                                .easeInOut(duration: 0.58)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.16),
                                value: isAnimating
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .clipShape(ChatBubbleShape(isUser: false))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)

            Spacer(minLength: 60)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct MessageBubbleView: View {
    let message: Message
    let features: ChatPreparedFeatures
    let language: Language
    let speechController: ChatSpeechController

    private var shouldShowInlineImage: Bool {
        features.richMediaMessagesEnabled && (message.image != nil || message.imageURLString != nil)
    }

    var body: some View {
        let isUser = message.role == .user

        HStack {
            if isUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                VStack(alignment: isUser ? .trailing : .leading, spacing: 10) {
                    if shouldShowInlineImage {
                        messageImage
                    }

                    messageText(isUser: isUser)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isUser ? Theme.Colors.primary : Color(.systemBackground))
                .clipShape(ChatBubbleShape(isUser: isUser))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)

                HStack(spacing: 8) {
                    if !isUser {
                        Button {
                            speechController.toggleSpeech(for: message, language: language)
                        } label: {
                            Image(systemName: speechController.speakingMessageID == message.id ? "stop.circle.fill" : "speaker.wave.2.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.premiumPressable)
                    }

                    Text(formattedTime(from: message.timestamp))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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

    @ViewBuilder
    private func messageText(isUser: Bool) -> some View {
        MarkdownMessageView(
            text: message.content,
            isUser: isUser,
            textSelectionEnabled: features.textSelectionEnabled
        )
    }

    @ViewBuilder
    private var messageImage: some View {
        if let image = message.image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: 260, minHeight: 160, maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        } else if let imageURLString = message.imageURLString,
                   let url = URL(string: imageURLString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failure:
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.secondarySystemBackground))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(maxWidth: 260, minHeight: 160, maxHeight: 280)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
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

@Observable
@MainActor
final class ChatSpeechController: NSObject, AVSpeechSynthesizerDelegate {
    var speakingMessageID: UUID?

    @ObservationIgnored
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggleSpeech(for message: Message, language: Language) {
        if speakingMessageID == message.id {
            stop()
            return
        }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        configureAudioSession()

        let utterance = AVSpeechUtterance(string: message.content)
        utterance.voice = Self.naturalVoice(for: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        speakingMessageID = message.id
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        speakingMessageID = nil
        deactivateAudioSession()
    }

    /// Picks the most natural installed voice for the language, preferring Siri/premium/enhanced
    /// voices over the default "compact" voice that sounds robotic. Falls back gracefully when the
    /// user hasn't downloaded a high-quality voice.
    static func naturalVoice(for language: Language) -> AVSpeechSynthesisVoice? {
        let languagePrefix = language == .spanish ? "es" : "en"
        let preferredRegion = language == .spanish ? "es-ES" : "en-US"

        let candidates = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix(languagePrefix)
        }

        guard !candidates.isEmpty else {
            return AVSpeechSynthesisVoice(language: preferredRegion)
        }

        func score(_ voice: AVSpeechSynthesisVoice) -> Int {
            var value = 0
            if voice.identifier.lowercased().contains("siri") { value += 1000 }
            switch voice.quality {
            case .premium: value += 300
            case .enhanced: value += 200
            default: value += 0
            }
            if voice.language == preferredRegion { value += 50 }
            return value
        }

        return candidates.max { score($0) < score($1) }
            ?? AVSpeechSynthesisVoice(language: preferredRegion)
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.speakingMessageID = nil
            self.deactivateAudioSession()
        }
    }
}

#Preview {
    ChatView()
        .environment(AppState())
        .modelContainer(for: [User.self, Conversation.self, Message.self], inMemory: true)
}
