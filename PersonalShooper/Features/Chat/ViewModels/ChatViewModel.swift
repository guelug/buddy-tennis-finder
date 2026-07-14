import SwiftUI
import SwiftData
import UIKit

@Observable
@MainActor
final class ChatViewModel {
    var inputText: String = ""
    var messages: [Message] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var attachedImage: UIImage?

    private var conversation: Conversation?
    private var context = ChatContext()
    private var hasPrepared = false
    private let classificationService = ClothingClassificationService()
    private let workspaceService = ChatWorkspaceService()

    func prepare(appState: AppState, modelContext: ModelContext) {
        setContext(from: appState)

        guard !hasPrepared else {
            if messages.isEmpty, let conversation {
                messages = conversation.messages.sorted(by: { $0.timestamp < $1.timestamp })
            }
            return
        }

        hasPrepared = true
        prewarmAssistant()

        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        if let existingConversation = try? modelContext.fetch(descriptor).first {
            conversation = existingConversation
            messages = existingConversation.messages.sorted(by: { $0.timestamp < $1.timestamp })
        } else {
            startNewConversation(appState: appState, modelContext: modelContext)
        }

        if messages.isEmpty {
            appendAssistantMessage(welcomeMessage(for: appState), saveToModel: true, modelContext: modelContext)
        }
    }

    func setContext(from appState: AppState) {
        context.language = appState.preferredLanguage

        if let user = appState.currentUser {
            context.userPalette = user.personalPalette
            context.userStylePreferences = user.stylePreferences
            context.personalStylingProfile = user.personalStylingProfile
            context.preferredName = user.displayName
            context.userGender = user.personalStylingProfile.genderIdentity
            context.todayEvents = appState.todayCalendarEvents
            context.dailyRecommendation = appState.latestDailyRecommendation
        } else {
            context.userPalette = nil
            context.userStylePreferences = []
            context.personalStylingProfile = nil
            context.preferredName = nil
            context.userGender = nil
            context.todayEvents = []
            context.dailyRecommendation = nil
        }
    }

    func startNewConversation(appState: AppState, modelContext: ModelContext) {
        let conversation = Conversation(
            title: appState.preferredLanguage == .spanish ? "Nueva conversación" : "New Conversation"
        )
        modelContext.insert(conversation)
        self.conversation = conversation
        self.messages = []
        appendAssistantMessage(welcomeMessage(for: appState), saveToModel: true, modelContext: modelContext)
        do {
            try modelContext.save()
        } catch {
            errorMessage = appState.preferredLanguage == .spanish
                ? "No he podido iniciar la conversación: \(error.localizedDescription)"
                : "I couldn't start the conversation: \(error.localizedDescription)"
        }
    }

    func sendMessage(appState: AppState, modelContext: ModelContext) async {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }
        let attachedImage = self.attachedImage

        prepare(appState: appState, modelContext: modelContext)

        if conversation == nil {
            startNewConversation(appState: appState, modelContext: modelContext)
        }

        let userMessage = Message(
            role: .user,
            content: userFacingMessageContent(from: trimmedInput, hasAttachedImage: attachedImage != nil, language: appState.preferredLanguage),
            image: attachedImage,
            metadata: ChatMessageMetadata(
                assetSource: attachedImage == nil ? .none : .localAttachment,
                toolIdentifier: nil,
                cacheKey: nil
            )
        )
        messages.append(userMessage)
        conversation?.addMessage(userMessage)
        if conversation?.title == "New Conversation" || conversation?.title == "Nueva conversación" {
            conversation?.title = String(trimmedInput.prefix(42))
        }

        inputText = ""
        self.attachedImage = nil
        isLoading = true
        errorMessage = nil

        let savedFacts = applyProfileUpdates(from: trimmedInput, appState: appState)
        let closetSummary = await applyClosetUpdates(
            from: trimmedInput,
            attachedImage: attachedImage,
            modelContext: modelContext,
            appState: appState
        )
        setContext(from: appState)
        context.closetItems = fetchClosetSummaries(modelContext: modelContext)

        let aiService = activeAIService(for: appState)

        if let streamingService = aiService as? FoundationModelsServiceProtocol {
            await streamAssistantResponse(
                using: streamingService,
                prompt: trimmedInput,
                image: attachedImage,
                savedFacts: savedFacts,
                closetSummary: closetSummary,
                appState: appState,
                modelContext: modelContext
            )
            isLoading = false
            return
        }

        do {
            let baseResponse = try await aiService.sendMessage(trimmedInput, context: context)
            let assistantResponse = composeAssistantResponse(
                base: baseResponse,
                savedFacts: savedFacts,
                closetSummary: closetSummary,
                appState: appState
            )
            let toolResult = try await preparedToolResultIfEnabled(
                for: trimmedInput,
                appState: appState,
                modelContext: modelContext
            )
            appendAssistantMessage(
                assistantResponse,
                toolResult: toolResult,
                saveToModel: true,
                modelContext: modelContext
            )
            do {
                try modelContext.save()
            } catch {
                errorMessage = appState.preferredLanguage == .spanish
                    ? "No he podido guardar la conversación: \(error.localizedDescription)"
                    : "I couldn't save the conversation: \(error.localizedDescription)"
            }
        } catch {
            let fallback = fallbackResponse(appState: appState, savedFacts: savedFacts, closetSummary: closetSummary)
            appendAssistantMessage(fallback, saveToModel: true, modelContext: modelContext)
            errorMessage = error.localizedDescription
            do {
                try modelContext.save()
            } catch {
                errorMessage = appState.preferredLanguage == .spanish
                    ? "No he podido guardar la conversación: \(error.localizedDescription)"
                    : "I couldn't save the conversation: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    private func appendAssistantMessage(
        _ content: String,
        toolResult: ChatToolResult? = nil,
        saveToModel: Bool,
        modelContext: ModelContext
    ) {
        let assistantMessage = workspaceService.makeAssistantMessage(baseContent: content, toolResult: toolResult)
        messages.append(assistantMessage)

        if saveToModel {
            conversation?.addMessage(assistantMessage)
            do {
                try modelContext.save()
            } catch {
                errorMessage = context.language == .spanish
                    ? "No he podido guardar el mensaje: \(error.localizedDescription)"
                    : "I couldn't save the message: \(error.localizedDescription)"
            }
        }
    }

    private func preparedToolResultIfEnabled(
        for message: String,
        appState: AppState,
        modelContext: ModelContext
    ) async throws -> ChatToolResult? {
        let features = appState.chatPreparedFeatures
        guard features.toolInvocationEnabled else { return nil }
        guard features.imageGenerationEnabled else { return nil }
        guard isPreparedImageRequest(message, language: appState.preferredLanguage) else { return nil }
        guard let user = appState.currentUser else { return nil }

        if let closetItem = matchedClosetItem(for: message, modelContext: modelContext) {
            return try await workspaceService.generateTryOnAsset(
                for: closetItem,
                user: user,
                provider: appState.tryOnProvider,
                modelContext: modelContext,
                language: appState.preferredLanguage
            )
        }

        return try workspaceService.prepareStandaloneImageGeneration(
            prompt: message,
            language: appState.preferredLanguage
        )
    }

    private func matchedClosetItem(for message: String, modelContext: ModelContext) -> ClothingItem? {
        let descriptor = FetchDescriptor<ClothingItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        guard let items = try? modelContext.fetch(descriptor), !items.isEmpty else {
            return nil
        }

        let normalizedMessage = message.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        return items
            .filter { !$0.name.isEmpty }
            .sorted { $0.name.count > $1.name.count }
            .first { item in
                let normalizedName = item.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                return normalizedMessage.contains(normalizedName)
            }
    }

    private func isPreparedImageRequest(_ message: String, language: Language) -> Bool {
        let normalizedMessage = message.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let keywords: [String]

        if language == .spanish {
            keywords = [
                "genera una imagen",
                "crear una imagen",
                "crea una imagen",
                "haz una imagen",
                "muestrame una imagen",
                "pruebame",
                "try on"
            ]
        } else {
            keywords = [
                "generate an image",
                "create an image",
                "make an image",
                "show me an image",
                "try on",
                "visualize"
            ]
        }

        return keywords.contains { normalizedMessage.contains($0) }
    }

    private func welcomeMessage(for appState: AppState) -> String {
        let isSpanish = appState.preferredLanguage == .spanish
        let name = appState.currentUser?.displayName
        let assistantName = AssistantPersona.name(forUserNamed: name)
        
        if let name = name, !name.isEmpty {
            return isSpanish
                ? "Hola **\(name)**, soy **\(assistantName)** 👋\n\nPuedo asesorarte de moda teniendo en cuenta tu armario y tus preferencias. Cuanto más uses el armario, mejor conoceré tu estilo y más personalizadas serán mis recomendaciones.\n\n¿En qué puedo ayudarte hoy?"
                : "Hi **\(name)**, I'm **\(assistantName)** 👋\n\nI can give you fashion advice based on your closet and preferences. The more you use your closet, the better I'll understand your style and the more personalized my recommendations will be.\n\nWhat can I help you with today?"
        }
        
        return isSpanish
            ? "Hola, soy **\(assistantName)** 👋\n\nPuedo asesorarte de moda teniendo en cuenta tu armario y tus preferencias. Cuanto más uses el armario, mejor conoceré tu estilo.\n\n¿En qué puedo ayudarte hoy?"
            : "Hi, I'm **\(assistantName)** 👋\n\nI can give you fashion advice based on your closet and preferences. The more you use your closet, the better I'll understand your style.\n\nWhat can I help you with today?"
    }

    private func composeAssistantResponse(base: String, savedFacts: [String], closetSummary: String?, appState: AppState) -> String {
        var sections = leadingSections(savedFacts: savedFacts, closetSummary: closetSummary, appState: appState)
        sections.append(base)

        // Note: we intentionally do NOT append a canned "let's keep refining: what's your age?"
        // question. The model already has the full saved context, so asking for known data felt
        // incoherent. The assistant drives any follow-ups itself.

        return sections.joined(separator: "\n\n")
    }

    /// Sections that come before the AI's own answer (saved profile facts, closet updates).
    private func leadingSections(savedFacts: [String], closetSummary: String?, appState: AppState) -> [String] {
        let isSpanish = appState.preferredLanguage == .spanish
        var sections: [String] = []

        if !savedFacts.isEmpty {
            let prefix = isSpanish
                ? "He guardado esto en tu perfil para futuras recomendaciones:"
                : "I've saved this in your profile for future recommendations:"
            sections.append("\(prefix) \(savedFacts.joined(separator: ", ")).")
        }

        if let closetSummary {
            sections.append(closetSummary)
        }

        return sections
    }

    /// Optional follow-up question appended after the AI's answer to keep enriching the profile.
    private func followUpQuestion(appState: AppState) -> String? {
        // Disabled automatic follow-up questions to let the user drive the conversation
        // The assistant will naturally learn about the user through normal chat
        return nil
    }

    /// Streams the assistant reply token-by-token (Apple Intelligence) so it types out live,
    /// then appends the optional follow-up question and any prepared tool output.
    private func streamAssistantResponse(
        using service: FoundationModelsServiceProtocol,
        prompt: String,
        image: UIImage?,
        savedFacts: [String],
        closetSummary: String?,
        appState: AppState,
        modelContext: ModelContext
    ) async {
        let lead = leadingSections(savedFacts: savedFacts, closetSummary: closetSummary, appState: appState)
        let prefix = lead.isEmpty ? "" : lead.joined(separator: "\n\n") + "\n\n"

        var streamingMessage: Message?
        var streamedText = ""

        do {
            for try await delta in service.streamMessage(prompt, image: image, context: context) {
                streamedText += delta

                if let streamingMessage {
                    streamingMessage.content = prefix + streamedText
                } else {
                    let message = Message(role: .assistant, content: prefix + streamedText)
                    streamingMessage = message
                    messages.append(message)
                    conversation?.addMessage(message)
                    isLoading = false
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            if streamingMessage == nil {
                let fallback = fallbackResponse(appState: appState, savedFacts: savedFacts, closetSummary: closetSummary)
                appendAssistantMessage(fallback, saveToModel: true, modelContext: modelContext)
            } else {
                try? modelContext.save()
            }
            return
        }

        // No usable tokens — drop the empty placeholder and use a contextual fallback instead.
        guard let streamingMessage,
              !streamedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if let placeholder = streamingMessage {
                messages.removeAll { $0.id == placeholder.id }
                conversation?.messages.removeAll { $0.id == placeholder.id }
                modelContext.delete(placeholder)
            }
            let fallback = fallbackResponse(appState: appState, savedFacts: savedFacts, closetSummary: closetSummary)
            appendAssistantMessage(fallback, saveToModel: true, modelContext: modelContext)
            return
        }

        var finalContent = prefix + streamedText
        if let followUp = followUpQuestion(appState: appState) {
            finalContent += "\n\n" + followUp
        }
        streamingMessage.content = finalContent

        let toolResult = (try? await preparedToolResultIfEnabled(
            for: prompt,
            appState: appState,
            modelContext: modelContext
        )) ?? nil
        if let toolResult {
            applyToolResult(toolResult, to: streamingMessage)
        }

        do {
            try modelContext.save()
        } catch {
            errorMessage = appState.preferredLanguage == .spanish
                ? "No he podido guardar la conversación: \(error.localizedDescription)"
                : "I couldn't save the conversation: \(error.localizedDescription)"
        }
    }

    private func applyToolResult(_ toolResult: ChatToolResult, to message: Message) {
        let toolText = toolResult.assistantText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !toolText.isEmpty {
            let current = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            message.content = current.isEmpty ? toolResult.assistantText : "\(message.content)\n\n\(toolResult.assistantText)"
        }
        if let image = toolResult.image {
            message.image = image
        }
        message.linkedClosetItemID = toolResult.linkedClosetItemID
        message.linkedTryOnResultID = toolResult.linkedTryOnResultID
        message.metadata = toolResult.metadata
    }

    /// Warms up the on-device model so the first chat reply is fast.
    private func prewarmAssistant() {
        let service = AIChatServiceFactory.createService()
        guard let streamingService = service as? FoundationModelsServiceProtocol else { return }
        Task { await streamingService.prewarm() }
    }

    private func fallbackResponse(appState: AppState, savedFacts: [String], closetSummary: String?) -> String {
        let isSpanish = appState.preferredLanguage == .spanish

        if let closetSummary, !closetSummary.isEmpty {
            return isSpanish
                ? "\(closetSummary) Puedo seguir ayudándote con estilo, color y outfits cuando quieras."
                : "\(closetSummary) I can keep helping with style, color, and outfits whenever you want."
        }

        if savedFacts.isEmpty {
            return isSpanish
                ? "Puedo seguir ayudándote con estilo, color y outfits. Si me cuentas un poco más sobre tu rutina o tus gustos, afinaré mejor mis respuestas."
                : "I can still help with style, color, and outfits. If you tell me a bit more about your routine or preferences, I'll refine my recommendations."
        }

        return isSpanish
            ? "He actualizado tu perfil y lo tendré en cuenta a partir de ahora. Seguimos cuando quieras."
            : "I've updated your profile and will use it from now on. We can keep going whenever you want."
    }

    private func applyProfileUpdates(from message: String, appState: AppState) -> [String] {
        guard let user = appState.currentUser else { return [] }

        let language = appState.preferredLanguage
        var profile = user.personalStylingProfile
        var savedFacts: [String] = []

        if let name = extractName(from: message),
           !name.isEmpty,
           name.caseInsensitiveCompare(user.displayName) != .orderedSame {
            user.displayName = name
            savedFacts.append(language == .spanish ? "nombre \(name)" : "name \(name)")
        }

        if let age = extractAge(from: message),
           profile.age != age {
            profile.age = age
            savedFacts.append(language == .spanish ? "edad \(age)" : "age \(age)")
        }

        if let gender = extractGender(from: message),
           profile.genderIdentity != gender {
            profile.genderIdentity = gender
            savedFacts.append(
                language == .spanish
                    ? "género \(gender.title(in: language).lowercased())"
                    : "gender \(gender.title(in: language).lowercased())"
            )
        }

        if let occupation = extractOccupation(from: message),
           occupation.caseInsensitiveCompare(profile.occupation) != .orderedSame {
            profile.occupation = occupation
            savedFacts.append(language == .spanish ? "trabajo \(occupation)" : "work \(occupation)")
        }

        if let lifestyle = extractLifestyleSummary(from: message),
           lifestyle.caseInsensitiveCompare(profile.lifestyleSummary) != .orderedSame {
            profile.lifestyleSummary = lifestyle
            savedFacts.append(language == .spanish ? "rutina \(lifestyle)" : "routine \(lifestyle)")
        }

        let eventUpdate = updateCollection(
            current: profile.usualSocialPlans,
            positiveMatches: detectSocialPlanMatches(in: message),
            negativeMatches: detectNegativeSocialPlanMatches(in: message),
            clearAll: shouldClearAllEvents(in: message)
        )
        profile.usualSocialPlans = eventUpdate.values
        if !eventUpdate.summary.isEmpty {
            savedFacts.append(contentsOf: eventUpdate.summary.map {
                if $0 == "social_reset" {
                    return language == .spanish ? "sin eventos sociales habituales" : "no regular social events"
                }

                if $0.hasPrefix("removed:") {
                    let id = String($0.dropFirst("removed:".count))
                    return language == .spanish
                        ? "ya no \(StyleProfileCatalog.title(for: id, in: language).lowercased())"
                        : "no longer \(StyleProfileCatalog.title(for: id, in: language).lowercased())"
                }

                return language == .spanish
                    ? "planes \(StyleProfileCatalog.title(for: $0, in: language))"
                    : "plans \(StyleProfileCatalog.title(for: $0, in: language))"
            })
        }

        let styleUpdate = mergeUnique(current: profile.preferredStyles, additions: detectStyleMatches(in: message))
        profile.preferredStyles = styleUpdate.values
        if !styleUpdate.added.isEmpty {
            savedFacts.append(contentsOf: styleUpdate.added.map {
                language == .spanish
                    ? "estilo \(StyleProfileCatalog.title(for: $0, in: language))"
                    : "style \(StyleProfileCatalog.title(for: $0, in: language))"
            })
        }

        let impressionUpdate = mergeUnique(current: profile.desiredImpression, additions: detectImpressionMatches(in: message))
        profile.desiredImpression = impressionUpdate.values
        if !impressionUpdate.added.isEmpty {
            savedFacts.append(contentsOf: impressionUpdate.added.map {
                language == .spanish
                    ? "imagen \(StyleProfileCatalog.title(for: $0, in: language))"
                    : "image \(StyleProfileCatalog.title(for: $0, in: language))"
            })
        }

        let prioritiesUpdate = mergeUnique(current: profile.fitPriorities, additions: detectPriorityMatches(in: message))
        profile.fitPriorities = prioritiesUpdate.values
        if !prioritiesUpdate.added.isEmpty {
            savedFacts.append(contentsOf: prioritiesUpdate.added.map {
                language == .spanish
                    ? "prioridad \(StyleProfileCatalog.title(for: $0, in: language))"
                    : "priority \(StyleProfileCatalog.title(for: $0, in: language))"
            })
        }

        let colorUpdate = applyColorPreferences(from: message, profile: profile)
        profile.favoriteColors = colorUpdate.favoriteColors
        profile.avoidColors = colorUpdate.avoidColors
        if !colorUpdate.addedFavoriteColors.isEmpty {
            savedFacts.append(
                language == .spanish
                    ? "gustos de color \(colorUpdate.addedFavoriteColors.joined(separator: ", "))"
                    : "color likes \(colorUpdate.addedFavoriteColors.joined(separator: ", "))"
            )
        }
        if !colorUpdate.addedAvoidColors.isEmpty {
            savedFacts.append(
                language == .spanish
                    ? "colores a evitar \(colorUpdate.addedAvoidColors.joined(separator: ", "))"
                    : "colors to avoid \(colorUpdate.addedAvoidColors.joined(separator: ", "))"
            )
        }

        if let goals = extractStyleGoals(from: message),
           goals.caseInsensitiveCompare(profile.styleGoals) != .orderedSame {
            profile.styleGoals = goals
            savedFacts.append(language == .spanish ? "objetivo de estilo" : "style goal")
        }

        if let challenge = extractShoppingChallenge(from: message),
           challenge.caseInsensitiveCompare(profile.shoppingChallenges) != .orderedSame {
            profile.shoppingChallenges = challenge
            savedFacts.append(language == .spanish ? "fricción al comprar o combinar" : "shopping friction")
        }

        if !savedFacts.isEmpty {
            profile.lastUpdatedFromChatAt = Date()
            user.updateStylingProfile(profile)
            user.updatedAt = Date()
            appState.updateUser(user)
        }

        return savedFacts
    }

    private func mergeUnique(current: [String], additions: [String]) -> (values: [String], added: [String]) {
        var values = current
        var added: [String] = []

        for addition in additions where !values.contains(addition) {
            values.append(addition)
            added.append(addition)
        }

        return (values, added)
    }

    private func activeAIService(for appState: AppState) -> AIChatServiceProtocol {
        // Apple Foundation Models is the default experience.
        guard appState.aiProviderMode != .appleFoundation else {
            return AIChatServiceFactory.createService()
        }

        // BYOK mode: use the user's own API key.
        if appState.aiProviderMode == .byok, appState.isBYOKEnabled {
            if let preferredProvider = UserDefaults.standard.string(forKey: "byok_preferred_provider"),
               let provider = BYOKChatService.BYOKProvider(rawValue: preferredProvider) {
                // Verify the key exists for this provider
                if hasAPIKey(for: provider) {
                    return BYOKChatService(provider: provider)
                }
            }
            // Fallback to any configured provider
            if let provider = firstAvailableBYOKProvider() {
                return BYOKChatService(provider: provider)
            }
        }

        // Premium external / Vercel fallback.
        if appState.aiProviderMode == .premiumExternal,
           appState.useConnectedChatGPTForChat,
           appState.isChatGPTConnected {
            return ConnectedChatGPTService()
        }

        // Legacy fallback: if Vercel fallback is enabled and connected.
        if appState.isVercelFallbackEnabled,
           appState.useConnectedChatGPTForChat,
           appState.isChatGPTConnected {
            return ConnectedChatGPTService()
        }

        return AIChatServiceFactory.createService()
    }

    private func hasAPIKey(for provider: BYOKChatService.BYOKProvider) -> Bool {
        let key: String?
        switch provider {
        case .gemini: key = KeychainHelper.load(for: "gemini_api_key")
        case .openai: key = KeychainHelper.load(for: "openai_api_key")
        case .grok: key = KeychainHelper.load(for: "grok_api_key")
        case .anthropic: key = KeychainHelper.load(for: "anthropic_api_key")
        case .kimi: key = KeychainHelper.load(for: "kimi_api_key")
        case .openrouter: key = KeychainHelper.load(for: "openrouter_api_key")
        }
        return key?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func firstAvailableBYOKProvider() -> BYOKChatService.BYOKProvider? {
        for provider in BYOKChatService.BYOKProvider.allCases {
            if hasAPIKey(for: provider) {
                return provider
            }
        }
        return nil
    }

    private func fetchClosetSummaries(modelContext: ModelContext) -> [ClothingItemSummary] {
        let descriptor = FetchDescriptor<ClothingItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        return ((try? modelContext.fetch(descriptor)) ?? []).map { item in
            ClothingItemSummary(
                id: item.id,
                name: item.name,
                category: item.category,
                colorTags: item.colorTags,
                styleTags: item.styleTags,
                materialTags: item.materialTags,
                occasionTags: item.occasionTags,
                detailTags: item.detailTags,
                brandName: item.brandName,
                notes: item.notes,
                metadataSummary: item.metadataSummary,
                isFavorite: item.isFavorite,
                timesWorn: item.timesWorn
            )
        }
    }

    private func userFacingMessageContent(from message: String, hasAttachedImage: Bool, language: Language) -> String {
        guard hasAttachedImage else { return message }

        let suffix = language == .spanish ? "[foto adjunta]" : "[photo attached]"
        return "\(message)\n\n\(suffix)"
    }

    private func applyClosetUpdates(
        from message: String,
        attachedImage: UIImage?,
        modelContext: ModelContext,
        appState: AppState
    ) async -> String? {
        guard let attachedImage, shouldAddAttachedGarmentToCloset(in: message) else {
            return nil
        }

        let compressedImage = compressAttachedImage(attachedImage)
        let currentClosetItems = (try? modelContext.fetch(
            FetchDescriptor<ClothingItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )) ?? []

        if appState.hasReachedClosetLimit(currentCount: currentClosetItems.count) {
            return appState.preferredLanguage == .spanish
                ? "Has llegado al límite gratuito de \(AppState.freeClosetItemLimit) prendas en el armario. Cualquier desbloqueo amplía el límite hasta \(AppState.premiumClosetItemLimit)."
                : "You've reached the free limit of \(AppState.freeClosetItemLimit) closet garments. Any paid unlock raises the limit to \(AppState.premiumClosetItemLimit)."
        }

        let classification = try? await classificationService.classifyClothing(image: compressedImage)
        let category = classification?.category ?? detectCategoryFromText(message) ?? .tops
        let colors = classification?.colors ?? []
        let styleTags = classification?.styleTags ?? []
        let materialTags = classification?.materialTags ?? []
        let occasionTags = classification?.occasionTags ?? []
        let detailTags = classification?.detailTags ?? []
        let metadataSummary = classification?.summary
        let itemName = extractClothingNameForCloset(from: message, category: category, language: appState.preferredLanguage)

        let additionalBytes = StorageBudgetManager.incrementalBytesForClothingItem(
            name: itemName,
            category: category,
            image: compressedImage,
            colorTags: colors,
            styleTags: styleTags,
            materialTags: materialTags,
            occasionTags: occasionTags,
            detailTags: detailTags,
            metadataSummary: metadataSummary
        )

        guard StorageBudgetManager.canStore(additionalBytes: additionalBytes, modelContext: modelContext) else {
            return StorageBudgetManager.overflowMessage(
                language: appState.preferredLanguage,
                modelContext: modelContext,
                additionalBytes: additionalBytes
            )
        }

        let item = ClothingItem(
            name: itemName,
            category: category,
            image: compressedImage,
            colorTags: colors,
            styleTags: styleTags,
            materialTags: materialTags,
            occasionTags: occasionTags,
            detailTags: detailTags,
            metadataSummary: metadataSummary
        )

        modelContext.insert(item)
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(item)
            return appState.preferredLanguage == .spanish
                ? "He preparado la prenda, pero no he podido guardarla en tu armario: \(error.localizedDescription)"
                : "I prepared the garment, but I couldn't save it to your closet: \(error.localizedDescription)"
        }

        await appState.refreshStyleCompanionState(closetItems: [item] + currentClosetItems)

        if appState.preferredLanguage == .spanish {
            return "He añadido \(item.name) a tu armario y lo tendré disponible en futuras recomendaciones."
        }

        return "I added \(item.name) to your closet, and I'll use it in future recommendations."
    }

    private func updateCollection(
        current: [String],
        positiveMatches: [String],
        negativeMatches: [String],
        clearAll: Bool
    ) -> (values: [String], summary: [String]) {
        if clearAll {
            return ([], ["social_reset"])
        }

        var values = current
        var summary: [String] = []

        for negative in negativeMatches {
            if let index = values.firstIndex(of: negative) {
                values.remove(at: index)
                summary.append("removed:\(negative)")
            }
        }

        for match in positiveMatches where !values.contains(match) {
            values.append(match)
            summary.append(match)
        }

        return (values, summary)
    }

}
