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
            context.todayEvents = appState.todayCalendarEvents
            context.dailyRecommendation = appState.latestDailyRecommendation
        } else {
            context.userPalette = nil
            context.userStylePreferences = []
            context.personalStylingProfile = nil
            context.preferredName = nil
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

        do {
            let aiService = activeAIService(for: appState)
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
        let name = appState.currentUser?.displayName ?? (isSpanish ? "tu perfil" : "your profile")
        let profile = appState.currentUser?.personalStylingProfile ?? PersonalStylingProfile()

        if profile.isCompleteEnough {
            return isSpanish
                ? "Hola \(name). Ya tengo parte de tu contexto de estilo guardado, así que puedo darte recomendaciones más finas. Si cambia tu rutina o tus eventos, dímelo aquí y actualizaré tu perfil."
                : "Hi \(name). I already have part of your style context saved, so I can give you sharper recommendations. If your routine or events change, tell me here and I will update your profile."
        }

        if let nextQuestion = profile.nextQuestion(in: appState.preferredLanguage) {
            return isSpanish
                ? "Hola \(name). Puedo asesorarte ya, pero si quieres respuestas realmente personalizadas, iré guardando algunos detalles opcionales sobre ti. \(nextQuestion)"
                : "Hi \(name). I can help already, but if you want truly personalized advice, I can save a few optional details about you. \(nextQuestion)"
        }

        return isSpanish
            ? "Hola \(name). Cuéntame qué necesitas y también puedo ir completando tu perfil mientras hablamos. Si me mandas una foto de una prenda y me pides añadirla al armario, también la guardaré."
            : "Hi \(name). Tell me what you need, and I can also complete your profile as we chat. If you send me a garment photo and ask me to add it to your closet, I'll save it too."
    }

    private func composeAssistantResponse(base: String, savedFacts: [String], closetSummary: String?, appState: AppState) -> String {
        let isSpanish = appState.preferredLanguage == .spanish
        let profile = appState.currentUser?.personalStylingProfile ?? PersonalStylingProfile()
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

        sections.append(base)

        if let nextQuestion = profile.nextQuestion(in: appState.preferredLanguage) {
            let followUpPrefix = isSpanish ? "Si quieres, seguimos afinando:" : "If you want, we can keep refining:"
            sections.append("\(followUpPrefix) \(nextQuestion)")
        }

        return sections.joined(separator: "\n\n")
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
        if appState.useConnectedChatGPTForChat && appState.isChatGPTConnected {
            return ConnectedChatGPTService()
        }

        return AIChatServiceFactory.createService()
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
                ? "Has llegado al límite gratuito de \(AppState.freeClosetItemLimit) prendas en el armario. Con Premium podrás guardar todas las que quieras."
                : "You've reached the free limit of \(AppState.freeClosetItemLimit) closet garments. Premium lets you save as many as you want."
        }

        let classification = try? await classificationService.classifyClothing(image: compressedImage)
        let category = classification?.category ?? detectCategoryFromText(message) ?? .tops
        let colors = classification?.colors ?? []
        let itemName = extractClothingNameForCloset(from: message, category: category, language: appState.preferredLanguage)

        let additionalBytes = StorageBudgetManager.incrementalBytesForClothingItem(
            name: itemName,
            category: category,
            image: compressedImage,
            colorTags: colors
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
            colorTags: colors
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

    private func extractName(from message: String) -> String? {
        let phrases = ["me llamo ", "mi nombre es ", "my name is ", "call me "]

        for phrase in phrases {
            if let value = extractClause(after: phrase, in: message) {
                return normalizedName(value)
            }
        }

        return nil
    }

    private func extractAge(from message: String) -> Int? {
        let patterns = [
            #"(?:tengo|cumplo|i am|i'm)\s+(\d{1,2})\b"#,
            #"(\d{1,2})\s*(?:años|anos|years?\sold)"#
        ]

        for pattern in patterns {
            if let match = firstCapture(in: message, pattern: pattern),
               let age = Int(match),
               (13...99).contains(age) {
                return age
            }
        }

        return nil
    }

    private func extractOccupation(from message: String) -> String? {
        let phrases = [
            "trabajo como ",
            "trabajo en ",
            "me dedico a ",
            "i work as ",
            "i work in ",
            "my job is "
        ]

        for phrase in phrases {
            if let clause = extractClause(after: phrase, in: message) {
                return normalizedSentence(clause)
            }
        }

        return nil
    }

    private func extractLifestyleSummary(from message: String) -> String? {
        let phrases = [
            "mi dia a dia es ",
            "mi día a día es ",
            "suelo vestir ",
            "normalmente voy ",
            "my day to day is ",
            "my routine is ",
            "i usually dress "
        ]

        for phrase in phrases {
            if let clause = extractClause(after: phrase, in: message) {
                return normalizedSentence(clause)
            }
        }

        return nil
    }

    private func extractStyleGoals(from message: String) -> String? {
        let phrases = [
            "quiero verme ",
            "quiero mejorar ",
            "me gustaria ",
            "me gustaría ",
            "i want to look ",
            "i want to improve ",
            "i'd like to "
        ]

        guard containsStyleIntent(in: message) else { return nil }

        for phrase in phrases {
            if let clause = extractClause(after: phrase, in: message) {
                return normalizedSentence(clause)
            }
        }

        return nil
    }

    private func extractShoppingChallenge(from message: String) -> String? {
        let phrases = [
            "me cuesta ",
            "siempre me pasa ",
            "mi problema es ",
            "i struggle with ",
            "my problem is ",
            "i find it hard to "
        ]

        for phrase in phrases {
            if let clause = extractClause(after: phrase, in: message) {
                return normalizedSentence(clause)
            }
        }

        return nil
    }

    private func detectSocialPlanMatches(in message: String) -> [String] {
        let mappings: [(String, String)] = [
            ("reuniones", "work_meetings"),
            ("meeting", "work_meetings"),
            ("oficina", "office_days"),
            ("office", "office_days"),
            ("clientes", "client_meetings"),
            ("client", "client_meetings"),
            ("networking", "networking"),
            ("cenas", "dinners"),
            ("dinner", "dinners"),
            ("citas", "date_nights"),
            ("date", "date_nights"),
            ("escapadas", "weekend_getaways"),
            ("getaway", "weekend_getaways"),
            ("viajes", "travel"),
            ("travel", "travel"),
            ("bodas", "weddings"),
            ("wedding", "weddings"),
            ("familiares", "family_events"),
            ("family", "family_events"),
            ("fiestas", "parties"),
            ("party", "parties"),
            ("casuales", "casual_weekends"),
            ("weekend", "casual_weekends")
        ]

        return detectedOptionIDs(in: message, mappings: mappings)
    }

    private func detectNegativeSocialPlanMatches(in message: String) -> [String] {
        guard containsAny(
            ["ya no", "no suelo", "no voy", "i no longer", "i don't", "i do not"],
            in: message
        ) else {
            return []
        }

        return detectSocialPlanMatches(in: message)
    }

    private func shouldClearAllEvents(in message: String) -> Bool {
        containsAny(
            [
                "ya no voy a eventos",
                "ya no hago eventos",
                "no voy a eventos",
                "i no longer go to events",
                "i don't go to events"
            ],
            in: message
        )
    }

    private func detectStyleMatches(in message: String) -> [String] {
        let mappings: [(String, String)] = [
            ("minimalista", "minimal"),
            ("minimal", "minimal"),
            ("clasica", "classic"),
            ("clásica", "classic"),
            ("classic", "classic"),
            ("elegante", "elegant"),
            ("elegant", "elegant"),
            ("creativa", "creative"),
            ("creative", "creative"),
            ("casual", "casual"),
            ("relajada", "relaxed"),
            ("relaxed", "relaxed"),
            ("tendencia", "trendy"),
            ("trendy", "trendy"),
            ("romantica", "romantic"),
            ("romántica", "romantic"),
            ("romantic", "romantic"),
            ("sport", "sporty"),
            ("sporty", "sporty"),
            ("personalidad", "statement"),
            ("statement", "statement")
        ]

        return detectedOptionIDs(in: message, mappings: mappings)
    }

    private func detectImpressionMatches(in message: String) -> [String] {
        let mappings: [(String, String)] = [
            ("profesional", "professional"),
            ("professional", "professional"),
            ("cercana", "approachable"),
            ("approachable", "approachable"),
            ("sofisticada", "sophisticated"),
            ("sophisticated", "sophisticated"),
            ("creativa", "creative"),
            ("creative", "creative"),
            ("segura", "powerful"),
            ("powerful", "powerful"),
            ("relajada", "relaxed"),
            ("relaxed", "relaxed"),
            ("actual", "modern"),
            ("modern", "modern"),
            ("atemporal", "timeless"),
            ("timeless", "timeless")
        ]

        return detectedOptionIDs(in: message, mappings: mappings)
    }

    private func detectPriorityMatches(in message: String) -> [String] {
        let mappings: [(String, String)] = [
            ("comodidad", "comfort"),
            ("comfort", "comfort"),
            ("pulida", "polished"),
            ("polished", "polished"),
            ("versatil", "versatility"),
            ("versátil", "versatility"),
            ("versatility", "versatility"),
            ("practicidad", "practicality"),
            ("practical", "practicality"),
            ("impacto", "impact"),
            ("impact", "impact"),
            ("calidad", "quality"),
            ("quality", "quality")
        ]

        return detectedOptionIDs(in: message, mappings: mappings)
    }

    private func applyColorPreferences(
        from message: String,
        profile: PersonalStylingProfile
    ) -> (
        favoriteColors: [String],
        avoidColors: [String],
        addedFavoriteColors: [String],
        addedAvoidColors: [String]
    ) {
        var favoriteColors = profile.favoriteColors
        var avoidColors = profile.avoidColors
        var addedFavoriteColors: [String] = []
        var addedAvoidColors: [String] = []

        let colors = detectedColors(in: message)

        if containsAny(["me gusta", "me gustan", "mi color", "i like", "my favorite"], in: message) {
            for color in colors where !favoriteColors.contains(color) {
                favoriteColors.append(color)
                addedFavoriteColors.append(color)
            }
        }

        if containsAny(["evito", "no me gusta", "odio", "avoid", "don't like"], in: message) {
            for color in colors where !avoidColors.contains(color) {
                avoidColors.append(color)
                addedAvoidColors.append(color)
            }
        }

        return (favoriteColors, avoidColors, addedFavoriteColors, addedAvoidColors)
    }

    private func detectedOptionIDs(in message: String, mappings: [(String, String)]) -> [String] {
        var results: [String] = []

        for (keyword, id) in mappings where message.localizedCaseInsensitiveContains(keyword) && !results.contains(id) {
            results.append(id)
        }

        return results
    }

    private func detectedColors(in message: String) -> [String] {
        let colors = [
            "negro", "blanco", "gris", "azul", "azul marino", "verde", "oliva",
            "burdeos", "rojo", "rosa", "beige", "camel", "crema", "marrón",
            "black", "white", "gray", "blue", "navy", "green", "olive",
            "burgundy", "red", "pink", "beige", "camel", "cream", "brown"
        ]

        var result: [String] = []
        for color in colors where message.localizedCaseInsensitiveContains(color) && !result.contains(color) {
            result.append(color)
        }
        return result
    }

    private func shouldAddAttachedGarmentToCloset(in message: String) -> Bool {
        containsAny(
            [
                "añade al armario",
                "añadela al armario",
                "añádela al armario",
                "añade al closet",
                "añádela al closet",
                "guardar en el armario",
                "guardar en el closet",
                "he comprado",
                "compré",
                "add to closet",
                "add it to my closet",
                "save to closet",
                "i bought",
                "put it in my wardrobe"
            ],
            in: message
        )
    }

    private func detectCategoryFromText(_ message: String) -> ClothingCategory? {
        let mappings: [(String, ClothingCategory)] = [
            ("blazer", .outerwear),
            ("chaqueta", .outerwear),
            ("jacket", .outerwear),
            ("coat", .outerwear),
            ("abrigo", .outerwear),
            ("vestido", .dresses),
            ("dress", .dresses),
            ("falda", .bottoms),
            ("skirt", .bottoms),
            ("pantal", .bottoms),
            ("jean", .bottoms),
            ("trouser", .bottoms),
            ("shirt", .tops),
            ("camisa", .tops),
            ("top", .tops),
            ("blusa", .tops),
            ("shoe", .shoes),
            ("zapato", .shoes),
            ("zapatilla", .shoes),
            ("bolso", .accessories),
            ("bag", .accessories),
            ("hat", .accessories),
            ("gorro", .accessories),
            ("gym", .activewear),
            ("legging", .activewear),
            ("bikini", .swimwear),
            ("swimsuit", .swimwear),
            ("bañador", .swimwear)
        ]

        for (keyword, category) in mappings where message.localizedCaseInsensitiveContains(keyword) {
            return category
        }

        return nil
    }

    private func extractClothingNameForCloset(from message: String, category: ClothingCategory, language: Language) -> String {
        let phrases = [
            "he comprado una ",
            "he comprado un ",
            "compré una ",
            "compre una ",
            "compré un ",
            "compre un ",
            "i bought a ",
            "i bought an ",
            "add this to my closet as ",
            "save this to closet as "
        ]

        for phrase in phrases {
            if let clause = extractClause(after: phrase, in: message) {
                let cleaned = sanitizeClothingNameClause(clause)
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }

        return defaultClothingName(for: category, language: language)
    }

    private func sanitizeClothingNameClause(_ clause: String) -> String {
        let separators = [
            " y añad", " y guard", " para el armario", " para el closet",
            " and add", " and save", " to my closet", " in my wardrobe"
        ]

        var result = clause
        for separator in separators {
            if let range = result.range(of: separator, options: [.caseInsensitive, .diacriticInsensitive]) {
                result = String(result[..<range.lowerBound])
            }
        }

        return normalizedSentence(
            result.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        )
    }

    private func defaultClothingName(for category: ClothingCategory, language: Language) -> String {
        switch (category, language) {
        case (.tops, .spanish): return "Parte de arriba"
        case (.bottoms, .spanish): return "Parte de abajo"
        case (.dresses, .spanish): return "Vestido"
        case (.shoes, .spanish): return "Zapatos"
        case (.accessories, .spanish): return "Accesorio"
        case (.outerwear, .spanish): return "Chaqueta o abrigo"
        case (.activewear, .spanish): return "Ropa deportiva"
        case (.swimwear, .spanish): return "Prenda de baño"
        case (.tops, .english): return "Top"
        case (.bottoms, .english): return "Bottom"
        case (.dresses, .english): return "Dress"
        case (.shoes, .english): return "Shoes"
        case (.accessories, .english): return "Accessory"
        case (.outerwear, .english): return "Outerwear"
        case (.activewear, .english): return "Activewear"
        case (.swimwear, .english): return "Swimwear"
        }
    }

    private func compressAttachedImage(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1024
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func containsStyleIntent(in message: String) -> Bool {
        containsAny(
            [
                "estilo", "vestir", "imagen", "armario", "outfit", "look",
                "style", "dress", "wardrobe"
            ],
            in: message
        )
    }

    private func containsAny(_ phrases: [String], in message: String) -> Bool {
        phrases.contains(where: { message.localizedCaseInsensitiveContains($0) })
    }

    private func extractClause(after phrase: String, in text: String) -> String? {
        guard let range = text.range(of: phrase, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return nil
        }

        let remainder = String(text[range.upperBound...])
        let fragment = remainder
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) ?? ""

        return fragment.isEmpty ? nil : fragment
    }

    private func normalizedName(_ value: String) -> String {
        value
            .split(separator: " ")
            .prefix(2)
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    private func normalizedSentence(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return trimmed }
        return first.uppercased() + trimmed.dropFirst()
    }

    private func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[range])
    }
}
