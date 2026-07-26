import Foundation
import FoundationModels
import NaturalLanguage
import UIKit

#if canImport(_FoundationModels_UIKit)
import _FoundationModels_UIKit
#endif

#if canImport(_Vision_FoundationModels)
import _Vision_FoundationModels
#endif

#if compiler(>=6.4) && canImport(CoreSpotlight)
import CoreSpotlight
#endif

// MARK: - AI Service Errors
enum AIError: LocalizedError {
    case notSupported
    case promptFailed
    case responseFailed(String)
    case contentFiltered
    case timeout
    case modelNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Apple Intelligence is not available on this device."
        case .promptFailed:
            return "Failed to create the prompt."
        case .responseFailed(let message):
            return "AI response failed: \(message)"
        case .contentFiltered:
            return "Your request was filtered for safety. Please try a different message."
        case .timeout:
            return "The request timed out. Please try again."
        case .modelNotAvailable:
            return "The AI model is not available at the moment."
        }
    }
}

// MARK: - AI Response
struct AIResponse {
    let content: String
    let shouldFilter: Bool
}

// MARK: - AI Chat Service Protocol
@MainActor
protocol AIChatServiceProtocol {
    func sendMessage(_ message: String, context: ChatContext) async throws -> String
}

/// Streaming contract: each yielded value is text to **append** to what was shown so far, unless it
/// starts with `AIStream.replaceMarker`, in which case the remainder replaces the whole reply. The
/// escape hatch exists because Foundation Models emits cumulative snapshots and may revise text it
/// already produced; appending blindly in that case duplicates or garbles the answer.
enum AIStream {
    static let replaceMarker = "\u{0}"
}

// MARK: - Streaming Service Protocol
@MainActor
protocol FoundationModelsServiceProtocol: AIChatServiceProtocol {
    var isStreaming: Bool { get }
    func streamMessage(_ message: String, context: ChatContext) -> AsyncThrowingStream<String, Error>
    func streamMessage(_ message: String, image: UIImage?, context: ChatContext) -> AsyncThrowingStream<String, Error>
    func prewarm() async
}

// MARK: - Clothing Data Service Protocol
protocol ClothingDataServiceProtocol: Sendable {
    func searchItems(
        category: String?,
        occasion: String?,
        colorPreference: String?,
        stylePreference: String?
    ) async -> [ClothingItemSummary]
}

struct ClothingItemSummary: Codable, Sendable {
    let id: UUID
    let name: String
    let category: ClothingCategory
    let colorTags: [String]
    let styleTags: [String]
    let materialTags: [String]
    let occasionTags: [String]
    let detailTags: [String]
    let brandName: String?
    let notes: String?
    let metadataSummary: String?
    let isFavorite: Bool
    let timesWorn: Int
}

// MARK: - Service Factory
enum AIChatServiceFactory {
    @MainActor
    static func createService() -> AIChatServiceProtocol {
        if #available(iOS 26.0, *) {
            let foundationModelsService = FoundationModelsStylistService()
            if foundationModelsService.isAvailable {
                return foundationModelsService
            }
        }

        return EnhancedAppleIntelligenceService()
    }

    @MainActor
    static func createFallbackService() -> AIChatServiceProtocol {
        return BasicFallbackService()
    }
}

// MARK: - Foundation Models Service
@available(iOS 26.0, *)
@MainActor
final class FoundationModelsStylistService: FoundationModelsServiceProtocol {
    private let model: SystemLanguageModel
    private var session: LanguageModelSession?
    /// Identity of the context the cached `session` was built for (language + assistant name). When
    /// it changes the instructions are stale, so the session is rebuilt.
    private var sessionSignature: String?
    /// True once the full user/closet context has been sent on the current session. Foundation
    /// Models keeps the transcript, so re-sending the whole profile + 40-item closet JSON on every
    /// turn just burns the (small) on-device context window and pushes the earlier conversation out.
    private var hasSentFullContext = false
    /// Hash of the closet payload last sent, so mid-conversation closet changes are re-sent.
    private var lastClosetFingerprint: Int?

    var isStreaming: Bool { false }

    var isAvailable: Bool {
        model.isAvailable
    }

    init(model: SystemLanguageModel = .default) {
        self.model = model
    }

    func prewarm() async {
        guard isAvailable else { return }
        // Warm the model without caching a session, so the real session is built once we know the
        // user's name (which decides whether the assistant is "Rebe" or "Peter").
        // Build the throwaway session OFF the main actor — LanguageModelSession init loads the
        // model and can block the UI for over a second (felt as tab-switch lag).
        let instructions = systemInstructions(for: .english, assistantName: AssistantPersona.defaultName)
        await Self.prewarmSession(instructions: instructions)
    }

    nonisolated
    private static func prewarmSession(instructions: String) async {
        let session = LanguageModelSession(model: .default, instructions: instructions)
        session.prewarm()
    }

    func sendMessage(_ message: String, context: ChatContext) async throws -> String {
        try await sendMessage(message, image: nil, context: context)
    }

    func sendMessage(_ message: String, image: UIImage?, context: ChatContext) async throws -> String {
        guard isAvailable else {
            throw AIError.modelNotAvailable
        }

        let response: LanguageModelSession.Response<String>
        do {
            response = try await respond(to: message, image: image, context: context)
        } catch let error where isContextWindowOverflow(error) {
            resetSession()
            response = try await respond(to: message, image: image, context: context)
        }

        let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            throw AIError.responseFailed("Empty Foundation Models response")
        }

        return content
    }

    /// One non-streaming turn against the cached session (with the image attachment when the OS
    /// supports it). Split out so the context-overflow retry can re-run it verbatim.
    private func respond(
        to message: String,
        image: UIImage?,
        context: ChatContext
    ) async throws -> LanguageModelSession.Response<String> {
        let session = activeSession(for: context)

#if canImport(_FoundationModels_UIKit)
        if #available(iOS 27.0, *), let image {
            return try await session.respond(
                options: generationOptions,
                contextOptions: contextOptions(for: message)
            ) {
                userPrompt(for: message, context: context)
                Attachment(image).label("User supplied style image")
            }
        }
#endif

        return try await textResponse(from: session, message: message, context: context)
    }

    func streamMessage(_ message: String, context: ChatContext) -> AsyncThrowingStream<String, Error> {
        streamMessage(message, image: nil, context: context)
    }

    func streamMessage(_ message: String, image: UIImage?, context: ChatContext) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                guard self.isAvailable else {
                    continuation.finish(throwing: AIError.modelNotAvailable)
                    return
                }

                do {
                    do {
                        try await self.drainStream(message: message, image: image, context: context, into: continuation)
                    } catch let error where self.isContextWindowOverflow(error) {
                        // Long styling conversations overflow the on-device window; start a fresh
                        // session (full context is re-sent) and replay this turn once.
                        self.resetSession()
                        try await self.drainStream(message: message, image: image, context: context, into: continuation)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Consumes one response stream, yielding only the newly-appended text.
    ///
    /// Foundation Models emits cumulative snapshots and may *revise* what it already emitted, so the
    /// delta is computed from the common prefix rather than by assuming the snapshot only ever grows
    /// (the old `dropFirst(lastContent.count)` silently corrupted the reply whenever it didn't).
    private func drainStream(
        message: String,
        image: UIImage?,
        context: ChatContext,
        into continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        var emitted = ""
        let stream = responseStream(
            from: activeSession(for: context),
            message: message,
            image: image,
            context: context
        )

        for try await snapshot in stream {
            let current = snapshot.content
            guard current != emitted else { continue }

            if current.hasPrefix(emitted) {
                continuation.yield(String(current.dropFirst(emitted.count)))
            } else {
                // The model rewrote part of the answer — resend the whole snapshot so the UI can
                // replace what it showed.
                continuation.yield(AIStream.replaceMarker + current)
            }
            emitted = current
        }
    }

    private var generationOptions: GenerationOptions {
        GenerationOptions(temperature: 0.35, maximumResponseTokens: 520)
    }

    private func activeSession(for context: ChatContext) -> LanguageModelSession {
        let signature = sessionSignature(for: context)
        if let session, sessionSignature == signature {
            return session
        }

        // Either there's no session yet or the instructions went stale (language switch, the user
        // told us their name). Either way we start clean and must re-send the full context.
        session = nil
        hasSentFullContext = false
        lastClosetFingerprint = nil
        sessionSignature = signature

#if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            let instructions = systemInstructions(
                for: context.language,
                assistantName: AssistantPersona.name(forUserNamed: context.preferredName)
            )
            let tools = iOS27SystemTools()

            if shouldPreferPrivateCloudCompute(for: context),
               let privateCloudModel = privateCloudModelIfAvailable() {
                let session = LanguageModelSession(
                    model: privateCloudModel,
                    tools: tools,
                    instructions: instructions
                )
                self.session = session
                return session
            }

            let session = LanguageModelSession(
                model: model,
                tools: tools,
                instructions: instructions
            )
            self.session = session
            return session
        }
#endif

        let session = LanguageModelSession(
            model: model,
            instructions: systemInstructions(
                for: context.language,
                assistantName: AssistantPersona.name(forUserNamed: context.preferredName)
            )
        )
        self.session = session
        return session
    }

    private func sessionSignature(for context: ChatContext) -> String {
        "\(context.language.rawValue)|\(AssistantPersona.name(forUserNamed: context.preferredName))"
    }

    /// Drops the cached session so the next turn starts from fresh instructions and full context.
    /// Used when the transcript overflows the on-device context window.
    private func resetSession() {
        session = nil
        sessionSignature = nil
        hasSentFullContext = false
        lastClosetFingerprint = nil
    }

    /// The on-device context window is small; a long styling conversation will eventually overflow
    /// it. When that happens we start a fresh session (which re-sends the full profile + closet) and
    /// retry the turn once, instead of surfacing an error the user can't act on.
    private func isContextWindowOverflow(_ error: Error) -> Bool {
        if let generationError = error as? LanguageModelSession.GenerationError,
           case .exceededContextWindowSize = generationError {
            return true
        }
        return false
    }

    private func textResponse(
        from session: LanguageModelSession,
        message: String,
        context: ChatContext
    ) async throws -> LanguageModelSession.Response<String> {
#if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            return try await session.respond(
                to: userPrompt(for: message, context: context),
                options: generationOptions,
                contextOptions: contextOptions(for: message)
            )
        }
#endif

        return try await session.respond(
            to: userPrompt(for: message, context: context),
            options: generationOptions
        )
    }

    private func responseStream(
        from session: LanguageModelSession,
        message: String,
        image: UIImage?,
        context: ChatContext
    ) -> LanguageModelSession.ResponseStream<String> {
#if canImport(_FoundationModels_UIKit)
        if #available(iOS 27.0, *), let image {
            return session.streamResponse(
                options: generationOptions,
                contextOptions: contextOptions(for: message)
            ) {
                userPrompt(for: message, context: context)
                Attachment(image).label("User supplied style image")
            }
        }
#endif

#if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            return session.streamResponse(
                to: userPrompt(for: message, context: context),
                options: generationOptions,
                contextOptions: contextOptions(for: message)
            )
        }
#endif

        return session.streamResponse(
            to: userPrompt(for: message, context: context),
            options: generationOptions
        )
    }

#if compiler(>=6.4)
    @available(iOS 27.0, *)
    private func contextOptions(for message: String) -> ContextOptions {
        ContextOptions(reasoningLevel: reasoningLevel(for: message))
    }

    @available(iOS 27.0, *)
    private func reasoningLevel(for message: String) -> ContextOptions.ReasoningLevel {
        let normalized = message.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let deepSignals = [
            "capsule", "capsula", "travel", "viaje", "wedding", "boda",
            "wardrobe", "armario", "plan", "calendar", "calendario",
            "compare", "compara", "analyze", "analiza", "shopping", "compras"
        ]

        return deepSignals.contains { normalized.contains($0) } ? .moderate : .light
    }

    @available(iOS 27.0, *)
    private func shouldPreferPrivateCloudCompute(for context: ChatContext) -> Bool {
        !context.closetItems.isEmpty || !context.todayEvents.isEmpty || context.personalStylingProfile != nil
    }

    @available(iOS 27.0, *)
    private func privateCloudModelIfAvailable() -> PrivateCloudComputeLanguageModel? {
        let privateCloudModel = PrivateCloudComputeLanguageModel()
        return privateCloudModel.isAvailable ? privateCloudModel : nil
    }

    @available(iOS 27.0, *)
    private func iOS27SystemTools() -> [any Tool] {
        var tools: [any Tool] = []

        tools.append(ClosetSearchTool())
        tools.append(WardrobeStatsTool())

#if canImport(_Vision_FoundationModels)
        tools.append(OCRTool(description: "Read text visible in fashion labels, receipts, garment tags, or screenshots."))
        tools.append(BarcodeReaderTool(description: "Read barcodes or QR codes on garment tags and shopping labels when useful."))
#endif

#if compiler(>=6.4) && canImport(CoreSpotlight)
        tools.append(SpotlightSearchTool())
#endif

        return tools
    }
#endif

    /// Whether `iOS27SystemTools()` actually produces tools on this build/OS.
    private var toolsAvailable: Bool {
#if compiler(>=6.4)
        if #available(iOS 27.0, *) { return true }
#endif
        return false
    }

    private func systemInstructions(for language: Language, assistantName: String) -> String {
        var lines = [
            "You are \(assistantName), the personal stylist inside Personal Shopper, a premium iOS fashion app.",
            "Introduce yourself as \(assistantName) only if the user greets you or asks who you are; otherwise get straight to styling.",
            "The user may share their own name; never assume your name and the user's name are the same person.",
            "Personal Shopper serves both men and women. Tailor garments, fit, and silhouettes to the user's gender when it is known, and never default to womenswear. In Spanish use the correct gendered wording for the user. If gender is unknown, keep advice inclusive.",
            language == .spanish
                ? "Responde siempre en espanol claro, natural y especifico."
                : "Always reply in clear, natural, specific English.",
            "Act like a real expert personal shopper: combine color analysis, silhouette/fit, occasion, lifestyle, and the actual closet inventory.",
            "Use the user's saved style profile, palette, calendar context, and closet inventory when present.",
            "For color advice, distinguish neutrals, accent colors, face-framing colors, colors to avoid, and high/low contrast pairings.",
            "For wardrobe advice, identify gaps, overrepresented colors/categories, underused pieces, and practical next purchases.",
            "Give concrete outfit formulas, color pairings, fit guidance, and wardrobe actions.",
        ]
        lines.append(contentsOf: ImageConsulting.professionalGuidelines(language: language))
        lines.append(contentsOf: [
            "When formatting helps (comparisons, capsule plans, packing lists), use Markdown tables and checklists; otherwise keep prose tight.",
            "Prioritize privacy: do not ask for sensitive personal data unrelated to style, and do not claim external access.",
            "If a closet item is relevant, name it directly and explain why it works.",
            "Treat the closet_context payload as the complete list of garments the user owns: never invent owned items, and if nothing suitable is there, say so and suggest what to add.",
            "Keep responses concise enough for mobile chat."
        ])

        // Only advertise the tools that were actually registered on this OS. Describing
        // `search_closet` unconditionally made the model on older systems promise a lookup it had
        // no way to perform.
        if toolsAvailable {
            lines.append("You have a 'search_closet' tool to find garments by category, occasion, color, style, or free-text query, and a 'wardrobe_stats' tool for closet-wide statistics. Use them whenever you need specific closet items instead of guessing.")
        }

        return lines.joined(separator: "\n")
    }

    /// Builds the turn prompt.
    ///
    /// The full profile + closet payload is sent **once per session**: Foundation Models keeps the
    /// transcript, so repeating it every turn (a) wasted most of the small on-device context window,
    /// (b) evicted the earlier conversation, and (c) previously duplicated every fact — the palette,
    /// profile, daily recommendation and calendar were emitted here *and* again by
    /// `StylistContextFormatter.userFacts`. Follow-up turns send only what actually changed.
    private func userPrompt(for message: String, context: ChatContext) -> String {
        var sections: [String] = []

        if !hasSentFullContext {
            sections.append(contentsOf: StylistContextFormatter.userFacts(for: context))
            sections.append(StylistContextFormatter.closetContextLine(for: context.closetItems))
            if let profile = context.personalStylingProfile {
                sections.append(styleProfileContext(profile, language: context.language))
            } else if !context.userStylePreferences.isEmpty {
                sections.append("Saved style preferences: \(context.userStylePreferences.joined(separator: ", ")).")
            }
            sections.append("Answer as the stylist. Use the saved context above only when it helps, and remember it for the rest of this conversation.")
            hasSentFullContext = true
            lastClosetFingerprint = closetFingerprint(for: context)
        } else if closetFingerprint(for: context) != lastClosetFingerprint {
            // The closet changed mid-conversation (a garment was added/worn/removed) — refresh just
            // the inventory rather than the whole context.
            sections.append("Updated closet inventory (replaces any earlier closet list):")
            sections.append(StylistContextFormatter.closetContextLine(for: context.closetItems))
            lastClosetFingerprint = closetFingerprint(for: context)
        }

        sections.append("User message: \(message)")

        return sections.joined(separator: "\n\n")
    }

    /// Cheap change-detector for the closet payload: count + item ids + wear counts.
    private func closetFingerprint(for context: ChatContext) -> Int {
        var hasher = Hasher()
        hasher.combine(context.closetItems.count)
        for item in context.closetItems {
            hasher.combine(item.id)
            hasher.combine(item.timesWorn)
            hasher.combine(item.isFavorite)
        }
        return hasher.finalize()
    }

    private func styleProfileContext(_ profile: PersonalStylingProfile, language: Language) -> String {
        var values: [String] = []

        if let age = profile.age {
            values.append("Age: \(age)")
        }
        var measurements: [String] = []
        if let height = profile.heightCm { measurements.append("height \(Int(height.rounded())) cm") }
        if let weight = profile.weightKg { measurements.append("weight \(Int(weight.rounded())) kg") }
        if let waist = profile.waistCm { measurements.append("waist \(Int(waist.rounded())) cm") }
        if let hips = profile.hipsCm { measurements.append("hips \(Int(hips.rounded())) cm") }
        if let chest = profile.chestCm { measurements.append("chest \(Int(chest.rounded())) cm") }
        if !measurements.isEmpty {
            values.append("Body measurements (use for sizing/fit, never comment on the user's body negatively): \(measurements.joined(separator: ", "))")
        }
        if let shape = profile.bodyShape ?? ImageConsulting.bodyShape(chestCm: profile.chestCm, waistCm: profile.waistCm, hipsCm: profile.hipsCm) {
            values.append(ImageConsulting.bodyShapeNote(shape, language: language))
        }
        if let face = profile.faceShape {
            values.append(ImageConsulting.faceShapeNote(face, language: language))
        }
        if let contrast = profile.contrastLevel {
            values.append(ImageConsulting.contrastNote(contrast, language: language))
        }
        if !profile.occupation.isEmpty {
            values.append("Occupation: \(profile.occupation)")
        }
        if !profile.lifestyleSummary.isEmpty {
            values.append("Routine: \(profile.lifestyleSummary)")
        }
        appendProfileValues(profile.usualSocialPlans, label: "Usual plans", language: language, into: &values)
        appendProfileValues(profile.preferredStyles, label: "Preferred styles", language: language, into: &values)
        appendProfileValues(profile.desiredImpression, label: "Desired impression", language: language, into: &values)
        appendProfileValues(profile.fitPriorities, label: "Fit priorities", language: language, into: &values)
        appendRawValues(profile.favoriteColors, label: "Favorite colors", into: &values)
        appendRawValues(profile.avoidColors, label: "Colors to avoid", into: &values)
        if !profile.learnedStyleSummary.isEmpty {
            values.append(profile.learnedStyleSummary)
        }

        return "Saved style profile: \(values.joined(separator: "; "))."
    }

    private func appendProfileValues(_ values: [String], label: String, language: Language, into output: inout [String]) {
        guard !values.isEmpty else { return }
        output.append("\(label): \(values.prefix(5).map { StyleProfileCatalog.title(for: $0, in: language) }.joined(separator: ", "))")
    }

    private func appendRawValues(_ values: [String], label: String, into output: inout [String]) {
        guard !values.isEmpty else { return }
        output.append("\(label): \(values.prefix(5).joined(separator: ", "))")
    }

    private func colorName(_ color: CodableColor) -> String {
        if let name = color.name, !name.isEmpty {
            return name
        }
        let red = Int((color.red * 255).rounded())
        let green = Int((color.green * 255).rounded())
        let blue = Int((color.blue * 255).rounded())
        return "rgb(\(red), \(green), \(blue))"
    }
}

// MARK: - Enhanced Apple Intelligence Service (Fallback for older iOS)
/// Enhanced fallback service using keyword analysis and NaturalLanguage framework
@MainActor
final class EnhancedAppleIntelligenceService: AIChatServiceProtocol {

    private let fashionSystemPrompt = """
    You are Rebe, the personal stylist inside Personal Shopper. Your role is to help users with:
    - Color recommendations based on their personal color palette
    - Outfit suggestions for various occasions
    - Style advice matching their preferences
    - Fashion tips and trends

    Important guidelines:
    - Always be helpful, friendly, and professional
    - Respect user privacy - never ask for personal information beyond fashion preferences
    - Provide specific, actionable advice
    - Consider the user's personal color palette and style preferences when giving recommendations
    - If unsure about something, suggest consulting a human stylist
    """

    private let sentimentAnalyzer = NLTagger(tagSchemes: [.sentimentScore])

    func sendMessage(_ message: String, context: ChatContext) async throws -> String {
        return generateContextualResponse(message: message, context: context)
    }

    // MARK: - Response Generation
    private func generateContextualResponse(message: String, context: ChatContext) -> String {
        let lowercasedMessage = message.lowercased()
        let language = detectLanguage(message: message, context: context)

        // Analyze sentiment to adjust tone
        let sentiment = analyzeSentiment(message)

        // Detect intent using more sophisticated pattern matching
        let intent = detectIntent(message: lowercasedMessage)
        
        switch intent {
        case .colorAdvice:
            return generateColorAdvice(language: language, palette: context.userPalette, message: message)
        case .outfitRecommendation:
            return generateOutfitRecommendation(language: language, context: context, message: message)
        case .colorMatching:
            return generateColorMatchingAdvice(language: language, message: message)
        case .styleAdvice:
            return generateStyleAdvice(language: language, context: context)
        case .trends:
            return generateTrendsAdvice(language: language)
        case .wardrobeHelp:
            return generateWardrobeAdvice(language: language, context: context)
        case .occasionHelp:
            return generateOccasionAdvice(language: language, message: message, context: context)
        case .general, .unknown:
            return generateGeneralResponse(language: language, sentiment: sentiment, context: context)
        }
    }
    
    // MARK: - Intent Detection
    private func detectIntent(message: String) -> UserIntent {
        let colorKeywords = ["color", "colores", "tono", "tones", "palette", "paleta", "matches", "combinan"]
        let outfitKeywords = ["outfit", "vestir", "traje", "ropa", "wear", "wearing", "look", "conjunto"]
        let matchingKeywords = ["match", "combinar", "combina", "go with", "pair", "coordinates"]
        let styleKeywords = ["style", "estilo", "fashion", "moda", "elegant", "casual", "formal"]
        let trendKeywords = ["trend", "tendencia", "popular", "in style", "fashionable"]
        let wardrobeKeywords = ["closet", "armario", "wardrobe", "clothes", "tengo", "have"]
        let occasionKeywords = ["occasion", "ocasion", "event", "evento", "wedding", "boda", "party", "fiesta", "work", "trabajo"]
        
        var scores: [UserIntent: Int] = [:]
        
        for keyword in colorKeywords {
            if message.contains(keyword) { scores[.colorAdvice, default: 0] += 1 }
        }
        for keyword in outfitKeywords {
            if message.contains(keyword) { scores[.outfitRecommendation, default: 0] += 1 }
        }
        for keyword in matchingKeywords {
            if message.contains(keyword) { scores[.colorMatching, default: 0] += 1 }
        }
        for keyword in styleKeywords {
            if message.contains(keyword) { scores[.styleAdvice, default: 0] += 1 }
        }
        for keyword in trendKeywords {
            if message.contains(keyword) { scores[.trends, default: 0] += 1 }
        }
        for keyword in wardrobeKeywords {
            if message.contains(keyword) { scores[.wardrobeHelp, default: 0] += 1 }
        }
        for keyword in occasionKeywords {
            if message.contains(keyword) { scores[.occasionHelp, default: 0] += 1 }
        }
        
        return scores.max(by: { $0.value < $1.value })?.key ?? .general
    }
    
    // MARK: - Language Detection
    private func detectLanguage(message: String, context: ChatContext) -> Language {
        // Prioritize context language setting
        if context.language == .spanish {
            return .spanish
        }
        
        let lowercased = message.lowercased()
        let spanishIndicators = ["como", "que", "cual", "cuando", "donde", "por que", "me", "mi", "te", "tu", 
                                "el", "la", "los", "las", "un", "una", "es", "son", "tengo", "quiero"]
        
        let spanishCount = spanishIndicators.filter { lowercased.contains($0) }.count
        return spanishCount >= 2 ? .spanish : .english
    }
    
    // MARK: - Sentiment Analysis
    private func analyzeSentiment(_ message: String) -> Double {
        sentimentAnalyzer.string = message
        let (sentiment, _) = sentimentAnalyzer.tag(at: message.startIndex, unit: .paragraph, scheme: .sentimentScore)
        return Double(sentiment?.rawValue ?? "0") ?? 0
    }
    
    // MARK: - Response Generators
    private func generateColorAdvice(language: Language, palette: PersonalPalette?, message: String) -> String {
        let isSpanish = language == .spanish
        
        // Extract specific color mentions
        let colors = extractColors(from: message)
        
        if isSpanish {
            var response = ""
            if let palette = palette {
                response = "Basándome en tu paleta de \(palette.seasonalType.displayName) con tono \(palette.undertone.displayName.lowercased()), "
                
                if !colors.isEmpty {
                    response += "los colores \(colors.joined(separator: ", ")) pueden funcionar bien para ti. "
                }
                
                response += "Te favorecen los tonos que realzan tu luminosidad natural. "
                response += "Los colores recomendados para tu tipo incluyen: "
                response += palette.recommendedColors.prefix(3).map { colorNameInSpanish(for: $0) }.joined(separator: ", ")
                response += "."
            } else {
                response = "Para darte mejores consejos de color personalizados, te recomiendo completar tu perfil con una foto para analizar tu paleta personal. "
                response += "Mientras tanto, los tonos neutros como el beige, gris y marino suelen ser versátiles para la mayoría de personas."
            }
            return response
        }
        
        var response = ""
        if let palette = palette {
            response = "Based on your \(palette.seasonalType.displayName) palette with \(palette.undertone.displayName.lowercased()) undertones, "
            
            if !colors.isEmpty {
                response += "colors like \(colors.joined(separator: ", ")) can work well for you. "
            }
            
            response += "You look best in tones that enhance your natural glow. "
            response += "Colors recommended for your type include: "
            response += palette.recommendedColors.prefix(3).map { colorName(for: $0) }.joined(separator: ", ")
            response += "."
        } else {
            response = "To give you personalized color advice, I recommend completing your profile with a photo to analyze your personal palette. "
            response += "In the meantime, neutral tones like beige, gray, and navy are versatile choices for most people."
        }
        return response
    }
    
    private func generateOutfitRecommendation(language: Language, context: ChatContext, message: String) -> String {
        let isSpanish = language == .spanish
        
        // Extract occasion
        let occasions = extractOccasions(from: message)
        let profileSnippet = styleProfileSnippet(from: context.personalStylingProfile, language: language)
        let eventSnippet = syncedEventSnippet(from: context, language: language)
        
        if isSpanish {
            var response = "¡Me encantaría ayudarte con un outfit"
            if !occasions.isEmpty {
                response += " para \(occasions.joined(separator: ", "))"
            }
            response += "! "
            
            if let palette = context.userPalette {
                response += "Con tu paleta \(palette.seasonalType.displayName.lowercased()), considera usar "
                response += "prendas en tonos \(palette.recommendedColors.prefix(2).map { colorNameInSpanish(for: $0) }.joined(separator: " o ")) "
                response += "como piezas principales. "
            }

            if !profileSnippet.isEmpty {
                response += profileSnippet + " "
            }

            if !eventSnippet.isEmpty {
                response += eventSnippet + " "
            }
            
            response += "Para un look completo, necesitaría saber más sobre tu estilo preferido y la ocasión específica. "
            response += "¿Prefieres algo casual, formal, o elegante?"
            return response
        }
        
        var response = "I'd love to help you put together an outfit"
        if !occasions.isEmpty {
            response += " for \(occasions.joined(separator: ", "))"
        }
        response += "! "
        
        if let palette = context.userPalette {
            response += "With your \(palette.seasonalType.displayName.lowercased()) palette, consider wearing "
            response += "pieces in \(palette.recommendedColors.prefix(2).map { colorName(for: $0) }.joined(separator: " or ")) "
            response += "as your main items. "
        }

        if !profileSnippet.isEmpty {
            response += profileSnippet + " "
        }

        if !eventSnippet.isEmpty {
            response += eventSnippet + " "
        }
        
        response += "For a complete look, I'd need to know more about your preferred style and the specific occasion. "
        response += "Do you prefer something casual, formal, or chic?"
        return response
    }
    
    private func generateColorMatchingAdvice(language: Language, message: String) -> String {
        let isSpanish = language == .spanish
        let colors = extractColors(from: message)
        
        if isSpanish {
            var response = "¡Gran pregunta sobre combinación de colores! "
            
            if colors.count >= 2 {
                response += "Para combinar \(colors[0]) con \(colors[1]): "
                response += "usa el 60-30-10 rule - 60% color dominante, 30% secundario, 10% acento. "
            } else {
                response += "Para un look cohesivo, intenta usar la regla de colores análogos (vecinos en el círculo cromático) "
                response += "o colores complementarios (opuestos) para contraste. "
            }
            
            response += "¿Hay colores específicos que te gustaría combinar? Puedo darte consejos más detallados."
            return response
        }
        
        var response = "Great question about color matching! "
        
        if colors.count >= 2 {
            response += "To match \(colors[0]) with \(colors[1]): "
            response += "use the 60-30-10 rule - 60% dominant color, 30% secondary, 10% accent. "
        } else {
            response += "For a cohesive look, try using analogous colors (neighbors on the color wheel) "
            response += "or complementary colors (opposites) for contrast. "
        }
        
        response += "Which specific colors would you like to match? I can give you more detailed advice."
        return response
    }
    
    private func generateStyleAdvice(language: Language, context: ChatContext) -> String {
        let isSpanish = language == .spanish
        let profileSnippet = styleProfileSnippet(from: context.personalStylingProfile, language: language)
        
        if isSpanish {
            var response = "El estilo personal es una forma de expresión única. "
            
            if !context.userStylePreferences.isEmpty {
                response += "Veo que te gustan los estilos: \(context.userStylePreferences.joined(separator: ", ")). "
            }

            if !profileSnippet.isEmpty {
                response += profileSnippet + " "
            }
            
            response += "Para definir mejor tu estilo, considera: ¿qué te hace sentir más cómodo y seguro? "
            response += "¿Prefieres piezas atemporales o sigues las últimas tendencias? "
            response += "Un buen armario tiene un equilibrio de ambos."
            return response
        }
        
        var response = "Personal style is a unique form of expression. "
        
        if !context.userStylePreferences.isEmpty {
            response += "I see you like these styles: \(context.userStylePreferences.joined(separator: ", ")). "
        }

        if !profileSnippet.isEmpty {
            response += profileSnippet + " "
        }
        
        response += "To define your style better, consider: what makes you feel most comfortable and confident? "
        response += "Do you prefer timeless pieces or following the latest trends? "
        response += "A great wardrobe has a balance of both."
        return response
    }
    
    private func generateTrendsAdvice(language: Language) -> String {
        let isSpanish = language == .spanish
        
        if isSpanish {
            return """
            Las tendencias actuales de moda incluyen:
            • Siluetas oversize cómodas y relajadas
            • Texturas táctiles como terciopelo, sarga y punto
            • Tonos neutros versátiles con toques de color terracota
            • Accesorios statement que elevan cualquier outfit
            • Moda sostenible y piezas atemporales
            
            Recuerda: las tendencias son guías, no reglas. Adapta lo que resuene contigo.
            ¿Te gustaría consejos específicos sobre alguna tendencia?
            """
        }
        
        return """
        Current fashion trends include:
        • Comfortable, relaxed oversized silhouettes
        • Tactile textures like velvet, twill, and knit
        • Versatile neutral tones with touches of terracotta
        • Statement accessories that elevate any outfit
        • Sustainable fashion and timeless pieces
        
        Remember: trends are guides, not rules. Adapt what resonates with you.
        Would you like specific advice on any trend?
        """
    }
    
    private func generateWardrobeAdvice(language: Language, context: ChatContext) -> String {
        let isSpanish = language == .spanish
        
        if isSpanish {
            var response = "Organizar tu armario es clave para aprovecharlo al máximo. "
            
            if let palette = context.userPalette {
                response += "Con tu paleta \(palette.seasonalType.displayName.lowercased()), enfócate en piezas versátiles en tus colores favorables. "
            }
            
            response += "Te sugiero: una base de neutros de calidad, algunas piezas statement en tus mejores colores, "
            response += "y prendas que se combinen entre sí. ¿Quieres ayuda organizando categorías específicas?"
            return response
        }
        
        var response = "Organizing your wardrobe is key to maximizing it. "
        
        if let palette = context.userPalette {
            response += "With your \(palette.seasonalType.displayName.lowercased()) palette, focus on versatile pieces in your favorable colors. "
        }
        
        response += "I suggest: quality neutral basics, some statement pieces in your best colors, "
        response += "and items that mix and match well. Want help organizing specific categories?"
        return response
    }
    
    private func generateOccasionAdvice(language: Language, message: String, context: ChatContext) -> String {
        let isSpanish = language == .spanish
        let occasions = extractOccasions(from: message)
        let profileSnippet = styleProfileSnippet(from: context.personalStylingProfile, language: language)
        let eventSnippet = syncedEventSnippet(from: context, language: language)
        
        if isSpanish {
            var response = ""
            if !occasions.isEmpty {
                response = "Para \(occasions.joined(separator: ", ")), considera el dress code y tu comodidad. "
            } else {
                response = "Para cualquier ocasión, considera el dress code y tu comodidad. "
            }
            
            if let palette = context.userPalette {
                response += "Con tu tono \(palette.undertone.displayName.lowercased()), los colores \(palette.recommendedColors.prefix(2).map { colorNameInSpanish(for: $0) }.joined(separator: " y ")) te favorecerán especialmente. "
            }

            if !profileSnippet.isEmpty {
                response += profileSnippet + " "
            }

            if !eventSnippet.isEmpty {
                response += eventSnippet + " "
            }
            
            response += "Cuéntame más sobre el evento específico para darte recomendaciones más precisas."
            return response
        }
        
        var response = ""
        if !occasions.isEmpty {
            response = "For \(occasions.joined(separator: ", ")), consider the dress code and your comfort. "
        } else {
            response = "For any occasion, consider the dress code and your comfort. "
        }
        
        if let palette = context.userPalette {
            response += "With your \(palette.undertone.displayName.lowercased()) undertones, colors like \(palette.recommendedColors.prefix(2).map { colorName(for: $0) }.joined(separator: " and ")) will be especially flattering. "
        }

        if !profileSnippet.isEmpty {
            response += profileSnippet + " "
        }

        if !eventSnippet.isEmpty {
            response += eventSnippet + " "
        }
        
        response += "Tell me more about the specific event for more precise recommendations."
        return response
    }
    
    private func generateGeneralResponse(language: Language, sentiment: Double, context: ChatContext) -> String {
        let isSpanish = language == .spanish
        let isPositive = sentiment > 0
        let profile = context.personalStylingProfile
        let eventSnippet = syncedEventSnippet(from: context, language: language)
        
        if isSpanish {
            var response = isPositive 
                ? "¡Me alegra que estés interesado en mejorar tu estilo! "
                : "Entiendo que encontrar tu estilo puede ser desafiante. "
            
            response += "Como tu estilista personal, estoy aquí para ayudarte con consejos de moda, recomendaciones de color y tips de estilo. "
            
            if context.userPalette == nil {
                response += "Para empezar con recomendaciones personalizadas, completa tu perfil con fotos para analizar tu paleta de colores. "
            }

            if profile?.isCompleteEnough == false {
                response += "También puedes contarme tu trabajo, tus eventos habituales o cómo te gusta proyectarte, y lo guardaré para afinar futuras respuestas. "
            }

            if !eventSnippet.isEmpty {
                response += eventSnippet + " "
            }
            
            response += "¿Qué te gustaría explorar hoy? Puedo ayudarte con outfits, combinaciones de colores, o tendencias."
            return response
        }
        
        var response = isPositive
            ? "I'm glad you're interested in elevating your style! "
            : "I understand that finding your style can be challenging. "
        
        response += "As your personal stylist, I'm here to help with fashion advice, color recommendations, and style tips. "
        
        if context.userPalette == nil {
            response += "To start with personalized recommendations, complete your profile with photos to analyze your color palette. "
        }

        if profile?.isCompleteEnough == false {
            response += "You can also tell me about your work, routine, or the image you want to project, and I'll save it to refine future answers. "
        }

        if !eventSnippet.isEmpty {
            response += eventSnippet + " "
        }
        
        response += "What would you like to explore today? I can help with outfits, color combinations, or trends."
        return response
    }

    private func styleProfileSnippet(from profile: PersonalStylingProfile?, language: Language) -> String {
        guard let profile else { return "" }

        if language == .spanish {
            if !profile.fitPriorities.isEmpty {
                let priorities = profile.fitPriorities.prefix(2).map { StyleProfileCatalog.title(for: $0, in: language) }.joined(separator: " y ")
                return "Tendré en cuenta que priorizas \(priorities.lowercased())."
            }

            if !profile.desiredImpression.isEmpty {
                let impression = profile.desiredImpression.prefix(2).map { StyleProfileCatalog.title(for: $0, in: language) }.joined(separator: " y ")
                return "Buscaré que el look proyecte una imagen \(impression.lowercased())."
            }

            if !profile.usualSocialPlans.isEmpty {
                let plans = profile.usualSocialPlans.prefix(2).map { StyleProfileCatalog.title(for: $0, in: language) }.joined(separator: " y ")
                return "Sé que en tu rutina aparecen \(plans.lowercased())."
            }
        } else {
            if !profile.fitPriorities.isEmpty {
                let priorities = profile.fitPriorities.prefix(2).map { StyleProfileCatalog.title(for: $0, in: language) }.joined(separator: " and ")
                return "I'll take into account that you prioritize \(priorities.lowercased())."
            }

            if !profile.desiredImpression.isEmpty {
                let impression = profile.desiredImpression.prefix(2).map { StyleProfileCatalog.title(for: $0, in: language) }.joined(separator: " and ")
                return "I'll aim for a look that feels \(impression.lowercased())."
            }

            if !profile.usualSocialPlans.isEmpty {
                let plans = profile.usualSocialPlans.prefix(2).map { StyleProfileCatalog.title(for: $0, in: language) }.joined(separator: " and ")
                return "I know your routine includes \(plans.lowercased())."
            }
        }

        return ""
    }

    private func syncedEventSnippet(from context: ChatContext, language: Language) -> String {
        if let recommendation = context.dailyRecommendation {
            return language == .spanish
                ? "He tenido en cuenta tu recomendación diaria: \(recommendation.contextLine.lowercased())"
                : "I've taken your daily recommendation into account: \(recommendation.contextLine.lowercased())"
        }

        guard let event = context.todayEvents.first else { return "" }

        return language == .spanish
            ? "Veo en tu calendario \(event.title) para hoy."
            : "I can see \(event.title) in your calendar today."
    }
    
    // MARK: - Helper Methods
    private func extractColors(from message: String) -> [String] {
        let colorPatterns = [
            "red", "blue", "green", "yellow", "orange", "purple", "pink", "black", "white",
            "gray", "grey", "brown", "beige", "navy", "burgundy", "teal", "coral",
            "rojo", "azul", "verde", "amarillo", "naranja", "morado", "rosa", "negro", "blanco",
            "gris", "cafe", "marrón", "beige", "marino", "borgoña", "turquesa", "coral"
        ]
        
        let lowercased = message.lowercased()
        return colorPatterns.filter { lowercased.contains($0) }
    }
    
    private func extractOccasions(from message: String) -> [String] {
        let occasionPatterns = [
            ("wedding", "boda"), ("party", "fiesta"), ("work", "trabajo"), ("interview", "entrevista"),
            ("date", "cita"), ("casual", "casual"), ("formal", "formal"), ("gym", "gimnasio"),
            ("vacation", "vacaciones"), ("beach", "playa"), ("dinner", "cena")
        ]
        
        let lowercased = message.lowercased()
        var found: [String] = []
        
        for (en, es) in occasionPatterns {
            if lowercased.contains(en) || lowercased.contains(es) {
                found.append(en)
            }
        }
        
        return found
    }
    
    private func colorName(for color: CodableColor) -> String {
        let r = color.red
        let g = color.green
        let b = color.blue
        
        if r > 0.7 && g < 0.4 && b < 0.4 { return "red" }
        if r > 0.7 && g > 0.4 && b < 0.4 { return "coral" }
        if r > 0.8 && g > 0.5 && b < 0.2 { return "orange" }
        if r > 0.7 && g > 0.7 && b < 0.3 { return "yellow" }
        if r < 0.4 && g > 0.5 && b < 0.4 { return "green" }
        if r < 0.4 && g < 0.5 && b > 0.7 { return "blue" }
        if r > 0.5 && g < 0.4 && b > 0.5 { return "purple" }
        if r > 0.7 && g > 0.5 && b > 0.6 { return "pink" }
        if r < 0.2 && g < 0.2 && b < 0.2 { return "black" }
        if r > 0.8 && g > 0.8 && b > 0.8 { return "white" }
        if r > 0.5 && g > 0.5 && b > 0.5 { return "gray" }
        if r > 0.5 && g > 0.3 && b < 0.2 { return "brown" }
        if r > 0.7 && g > 0.6 && b > 0.5 { return "beige" }
        if r < 0.4 && g > 0.5 && b > 0.5 { return "teal" }
        if r > 0.6 && g < 0.5 && b > 0.7 { return "lavender" }
        if r > 0.4 && g < 0.3 && b < 0.3 { return "burgundy" }
        
        return "neutral"
    }
    
    private func colorNameInSpanish(for color: CodableColor) -> String {
        let english = colorName(for: color)
        let translations: [String: String] = [
            "red": "rojo", "coral": "coral", "orange": "naranja", "yellow": "amarillo",
            "green": "verde", "blue": "azul", "purple": "morado", "pink": "rosa",
            "black": "negro", "white": "blanco", "gray": "gris", "brown": "marrón",
            "beige": "beige", "teal": "turquesa", "lavender": "lavanda", "burgundy": "bordó",
            "neutral": "neutral"
        ]
        return translations[english] ?? english
    }
}

// MARK: - Foundation Models Tools (iOS 27+)

@available(iOS 27.0, *)
struct ClosetSearchTool: Tool {
    let name = "search_closet"
    let description = "Search the user's wardrobe for garments matching category, occasion, color, style, or a free-text query. Returns matching items with their names and tags."

    @Generable
    struct Arguments {
        @Guide(description: "Clothing category to filter by, e.g. tops, bottoms, dresses, shoes, accessories")
        let category: String?
        @Guide(description: "Occasion to filter by, e.g. work, casual, party, wedding, sport")
        let occasion: String?
        @Guide(description: "Color to filter by, e.g. black, navy, beige")
        let colorPreference: String?
        @Guide(description: "Style to filter by, e.g. casual, formal, minimal, elegant")
        let stylePreference: String?
        @Guide(description: "Free-text query to match against garment name, brand, notes, or tags")
        let query: String?
    }

    func call(arguments: Arguments) async throws -> String {
        let service = ClosetSearchService()
        let results = service.searchItems(
            category: arguments.category,
            occasion: arguments.occasion,
            colorPreference: arguments.colorPreference,
            stylePreference: arguments.stylePreference,
            query: arguments.query,
            limit: 10
        )

        guard !results.isEmpty else {
            return "No matching garments found in the closet."
        }

        let lines = results.map { item in
            let details = (item.colorTags + item.styleTags + item.materialTags + item.occasionTags).prefix(5).joined(separator: ", ")
            return "- \(item.name) (\(item.category.displayName))\(details.isEmpty ? "" : ": \(details)")"
        }

        return "Found \(results.count) garment(s):\n" + lines.joined(separator: "\n")
    }
}

@available(iOS 27.0, *)
struct WardrobeStatsTool: Tool {
    let name = "wardrobe_stats"
    let description = "Get high-level statistics about the user's wardrobe: total items, favorites, most worn, never worn, and breakdown by category."

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        ClosetSearchService().wardrobeStats()
    }
}

// MARK: - User Intent Enum
enum UserIntent {
    case colorAdvice
    case outfitRecommendation
    case colorMatching
    case styleAdvice
    case trends
    case wardrobeHelp
    case occasionHelp
    case general
    case unknown
}

// MARK: - Legacy Fallback (for very old iOS versions)
@MainActor
final class BasicFallbackService: AIChatServiceProtocol {
    func sendMessage(_ message: String, context: ChatContext) async throws -> String {
        let isSpanish = context.language == .spanish ||
            message.lowercased().contains("como") ||
            message.lowercased().contains("que")
        
        return isSpanish
            ? "Necesitas iOS 17.2 o superior para usar el asistente de estilo completo."
            : "You need iOS 17.2 or later to use the full style assistant."
    }
}
