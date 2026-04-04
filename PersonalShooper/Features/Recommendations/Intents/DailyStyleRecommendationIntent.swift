import AppIntents

struct DailyStyleRecommendationIntent: AppIntent {
    static var title: LocalizedStringResource {
        "Get Today's Style Recommendation"
    }

    static var description: IntentDescription {
        IntentDescription("Read the latest Personal Shooper outfit recommendation based on your profile and calendar.")
    }

    static var openAppWhenRun: Bool {
        false
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let configuration = SharedStyleCompanionStore.loadConfiguration()

        guard configuration.siriSuggestionsEnabled else {
            return .result(
                dialog: IntentDialog(
                    "Siri style suggestions are disabled. Enable them in Personal Shooper settings."
                )
            )
        }

        guard let recommendation = SharedStyleCompanionStore.loadRecommendation() else {
            return .result(
                dialog: IntentDialog(
                    "I don't have a daily recommendation yet. Open Personal Shooper to refresh today's styling plan."
                )
            )
        }

        return .result(dialog: IntentDialog(stringLiteral: recommendation.spokenSummary))
    }
}

struct PersonalShooperShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
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
        )
    }
}
