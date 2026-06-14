@preconcurrency import AppIntents
import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

#if canImport(VisualIntelligence)
import VisualIntelligence
#endif

struct ClosetItemEntity: AppEntity, IndexedEntity, Identifiable, Sendable {
    let id: String
    let snapshot: StyleCompanionClosetItemSnapshot

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Closet Item"
    static let defaultQuery = ClosetItemEntityQuery()

    init(snapshot: StyleCompanionClosetItemSnapshot) {
        self.id = snapshot.id
        self.snapshot = snapshot
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(snapshot.name)",
            subtitle: "\(snapshot.categoryDisplayName)"
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.displayName = snapshot.name
        attributes.title = snapshot.name
        attributes.contentDescription = snapshot.spokenSummary
        attributes.keywords = snapshot.searchableTerms
        attributes.userCreated = NSNumber(value: true)
        attributes.userCurated = NSNumber(value: snapshot.isFavorite)
        attributes.metadataModificationDate = snapshot.createdAt
        return attributes
    }
}

struct ClosetItemEntityQuery: EntityStringQuery, EnumerableEntityQuery {
    func entities(for identifiers: [ClosetItemEntity.ID]) async throws -> [ClosetItemEntity] {
        let wanted = Set(identifiers)
        return SharedStyleCompanionStore.loadClosetIndex()
            .filter { wanted.contains($0.id) }
            .map(ClosetItemEntity.init)
    }

    func entities(matching string: String) async throws -> [ClosetItemEntity] {
        ClosetSearch.matches(for: string)
            .map(ClosetItemEntity.init)
    }

    func allEntities() async throws -> [ClosetItemEntity] {
        SharedStyleCompanionStore.loadClosetIndex().map(ClosetItemEntity.init)
    }
}

struct DailyStyleRecommendationIntent: AppIntent {
    static var title: LocalizedStringResource {
        "Get Today's Style Recommendation"
    }

    static var description: IntentDescription {
        IntentDescription("Read the latest Personal Shopper outfit recommendation based on your profile and calendar.")
    }

    static var openAppWhenRun: Bool {
        false
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let configuration = SharedStyleCompanionStore.loadConfiguration()

        guard configuration.siriSuggestionsEnabled else {
            return .result(
                dialog: IntentDialog(
                    "Siri style suggestions are disabled. Enable them in Personal Shopper settings."
                )
            )
        }

        guard let recommendation = SharedStyleCompanionStore.loadRecommendation() else {
            return .result(
                dialog: IntentDialog(
                    "I don't have a daily recommendation yet. Open Personal Shopper to refresh today's styling plan."
                )
            )
        }

        return .result(dialog: IntentDialog(stringLiteral: recommendation.spokenSummary))
    }
}

struct SearchClosetIntent: AppIntent {
    static var title: LocalizedStringResource {
        "Search Closet"
    }

    static var description: IntentDescription {
        IntentDescription("Search your Personal Shopper closet and open matching garments.")
    }

    static var openAppWhenRun: Bool {
        true
    }

    @Parameter(title: "Search")
    var query: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let configuration = SharedStyleCompanionStore.loadConfiguration()

        guard configuration.siriSuggestionsEnabled else {
            return .result(dialog: IntentDialog("Siri style suggestions are disabled. Enable them in Personal Shopper settings."))
        }

        let matches = ClosetSearch.matches(for: query)
        let names = matches.prefix(3).map { $0.name }
        let dialog: String
        if names.isEmpty {
            dialog = "I didn't find any matching items in your closet."
        } else if names.count == 1 {
            dialog = "I found \(names[0]) in your closet."
        } else {
            dialog = "I found: " + names.joined(separator: ", ") + "."
        }

        ClosetSearch.routeToCloset(matching: query)
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

struct StartStyleConsultationIntent: AppIntent {
    static var title: LocalizedStringResource {
        "Ask Style Consultant"
    }

    static var description: IntentDescription {
        IntentDescription("Start a Personal Shopper chat with a styling question.")
    }

    static var openAppWhenRun: Bool {
        true
    }

    @Parameter(
        title: "Question",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var question: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let configuration = SharedStyleCompanionStore.loadConfiguration()

        guard configuration.siriSuggestionsEnabled else {
            return .result(dialog: IntentDialog("Siri style suggestions are disabled. Enable them in Personal Shopper settings."))
        }

        SharedStyleCompanionStore.savePendingChatPrompt(question)
        SharedStyleCompanionStore.savePendingLaunchDestination(.chat)
        return .result(dialog: IntentDialog("Opening your stylist with that question."))
    }
}

struct OpenClosetItemIntent: OpenIntent {
    static var title: LocalizedStringResource {
        "Open Closet Item"
    }

    @Parameter(title: "Closet Item")
    var target: ClosetItemEntity

    func perform() async throws -> some IntentResult {
        SharedStyleCompanionStore.savePendingClosetItemID(target.id)
        SharedStyleCompanionStore.savePendingClosetSearch(target.snapshot.name)
        SharedStyleCompanionStore.savePendingLaunchDestination(.closet)
        return .result()
    }
}

struct OpenProfileIntent: AppIntent {
    static var title: LocalizedStringResource {
        "Open Style Profile"
    }

    static var description: IntentDescription {
        IntentDescription("Open your Personal Shopper style profile and palette.")
    }

    static var openAppWhenRun: Bool {
        true
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let configuration = SharedStyleCompanionStore.loadConfiguration()

        guard configuration.siriSuggestionsEnabled else {
            return .result(dialog: IntentDialog("Siri style suggestions are disabled. Enable them in Personal Shopper settings."))
        }

        SharedStyleCompanionStore.savePendingLaunchDestination(.profile)
        return .result(dialog: IntentDialog("Opening your style profile."))
    }
}

struct OpenChatIntent: AppIntent {
    static var title: LocalizedStringResource {
        "Open Chat"
    }

    static var description: IntentDescription {
        IntentDescription("Open the Personal Shopper style chat.")
    }

    static var openAppWhenRun: Bool {
        true
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let configuration = SharedStyleCompanionStore.loadConfiguration()

        guard configuration.siriSuggestionsEnabled else {
            return .result(dialog: IntentDialog("Siri style suggestions are disabled. Enable them in Personal Shopper settings."))
        }

        SharedStyleCompanionStore.savePendingLaunchDestination(.chat)
        return .result(dialog: IntentDialog("Opening your style chat."))
    }
}

struct OpenClosetIntent: AppIntent {
    static var title: LocalizedStringResource {
        "Open Closet"
    }

    static var description: IntentDescription {
        IntentDescription("Open the Personal Shopper closet.")
    }

    static var openAppWhenRun: Bool {
        true
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let configuration = SharedStyleCompanionStore.loadConfiguration()

        guard configuration.siriSuggestionsEnabled else {
            return .result(dialog: IntentDialog("Siri style suggestions are disabled. Enable them in Personal Shopper settings."))
        }

        SharedStyleCompanionStore.savePendingLaunchDestination(.closet)
        return .result(dialog: IntentDialog("Opening your closet."))
    }
}

struct OpenTryOnIntent: AppIntent {
    static var title: LocalizedStringResource {
        "Open Try On"
    }

    static var description: IntentDescription {
        IntentDescription("Open the Personal Shopper try-on experience.")
    }

    static var openAppWhenRun: Bool {
        true
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let configuration = SharedStyleCompanionStore.loadConfiguration()

        guard configuration.siriSuggestionsEnabled else {
            return .result(dialog: IntentDialog("Siri style suggestions are disabled. Enable them in Personal Shopper settings."))
        }

        SharedStyleCompanionStore.savePendingLaunchDestination(.tryOn)
        return .result(dialog: IntentDialog("Opening try-on."))
    }
}

struct AddToClosetIntent: AppIntent {
    static var title: LocalizedStringResource {
        "Add Garment to Closet"
    }

    static var description: IntentDescription {
        IntentDescription("Open Personal Shopper to add a new garment to your closet.")
    }

    static var openAppWhenRun: Bool {
        true
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let configuration = SharedStyleCompanionStore.loadConfiguration()

        guard configuration.siriSuggestionsEnabled else {
            return .result(dialog: IntentDialog("Siri style suggestions are disabled. Enable them in Personal Shopper settings."))
        }

        SharedStyleCompanionStore.savePendingLaunchDestination(.closet)
        return .result(dialog: IntentDialog("Opening your closet so you can add a new garment."))
    }
}

#if canImport(VisualIntelligence)
@available(iOS 26.0, *)
struct ClosetVisualSearchQuery: IntentValueQuery {
    func values(for input: SemanticContentDescriptor) async throws -> [ClosetItemEntity] {
        ClosetSearch.visualMatches(labels: input.labels)
            .map(ClosetItemEntity.init)
    }
}

@available(iOS 26.0, *)
@AppIntent(schema: .visualIntelligence.semanticContentSearch)
struct PersonalShooperVisualSearchIntent: AppIntent {
    static var title: LocalizedStringResource {
        "Search in Personal Shopper"
    }

    static var openAppWhenRun: Bool {
        true
    }

    var semanticContent: SemanticContentDescriptor

    func perform() async throws -> some IntentResult {
        let labels = semanticContent.labels
        let matches = ClosetSearch.visualMatches(labels: labels)
        let searchQuery = matches.first?.name ?? labels.prefix(4).joined(separator: " ")
        ClosetSearch.routeToCloset(matching: searchQuery)
        return .result()
    }
}
#endif

struct PersonalShooperShortcuts: AppShortcutsProvider {
    static let appShortcuts: [AppShortcut] = [
        AppShortcut(
            intent: DailyStyleRecommendationIntent(),
            phrases: [
                "What should I wear today with \(.applicationName)",
                "Ask \(.applicationName) for my daily style recommendation",
                "Que me recomiende ponerme hoy \(.applicationName)",
                "Dime mi look de hoy con \(.applicationName)"
            ],
            shortTitle: "Daily Style",
            systemImageName: "sparkles"
        ),
        AppShortcut(
            intent: OpenChatIntent(),
            phrases: [
                "Open chat in \(.applicationName)",
                "Open my style chat in \(.applicationName)",
                "Abre el chat de \(.applicationName)",
                "Abre mi chat de estilo en \(.applicationName)"
            ],
            shortTitle: "Open Chat",
            systemImageName: "bubble.left.and.bubble.right.fill"
        ),
        AppShortcut(
            intent: OpenClosetIntent(),
            phrases: [
                "Open closet in \(.applicationName)",
                "Show my closet in \(.applicationName)",
                "Abre el armario de \(.applicationName)",
                "Enséñame mi armario en \(.applicationName)"
            ],
            shortTitle: "Open Closet",
            systemImageName: "hanger"
        ),
        AppShortcut(
            intent: OpenTryOnIntent(),
            phrases: [
                "Open try on in \(.applicationName)",
                "Open the fitting room in \(.applicationName)",
                "Abre el probador de \(.applicationName)",
                "Abre el try on en \(.applicationName)"
            ],
            shortTitle: "Open Try On",
            systemImageName: "camera.fill"
        ),
        AppShortcut(
            intent: SearchClosetIntent(),
            phrases: [
                "Search my closet with \(.applicationName)",
                "Find clothes in \(.applicationName)",
                "Busca en mi armario con \(.applicationName)",
                "Encuentra ropa en \(.applicationName)"
            ],
            shortTitle: "Search Closet",
            systemImageName: "magnifyingglass"
        ),
        AppShortcut(
            intent: AddToClosetIntent(),
            phrases: [
                "Add a garment to \(.applicationName)",
                "Add clothes to my closet in \(.applicationName)",
                "Añade una prenda a \(.applicationName)",
                "Guarda ropa en mi armario de \(.applicationName)"
            ],
            shortTitle: "Add to Closet",
            systemImageName: "plus.circle"
        ),
        AppShortcut(
            intent: StartStyleConsultationIntent(),
            phrases: [
                "Ask \(.applicationName) a style question",
                "Start style advice in \(.applicationName)",
                "Pregunta a \(.applicationName) sobre estilo",
                "Pide consejo de estilo en \(.applicationName)"
            ],
            shortTitle: "Ask Stylist",
            systemImageName: "sparkles.rectangle.stack"
        ),
        AppShortcut(
            intent: OpenProfileIntent(),
            phrases: [
                "Open my style profile in \(.applicationName)",
                "Show my palette in \(.applicationName)",
                "Abre mi perfil de estilo en \(.applicationName)",
                "Muestra mi paleta en \(.applicationName)"
            ],
            shortTitle: "Style Profile",
            systemImageName: "person.text.rectangle"
        )
    ]

    static let shortcutTileColor: ShortcutTileColor = .orange
}
