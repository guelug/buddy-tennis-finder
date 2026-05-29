@preconcurrency import AppIntents

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
        )
    ]

    static let shortcutTileColor: ShortcutTileColor = .orange
}
