import Foundation
import SwiftData

enum PersonalShooperSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            User.self,
            Conversation.self,
            Message.self,
            ClothingItem.self,
            TryOnResult.self,
            StyleProgressMission.self,
            OutfitCalendarEntry.self,
            ARClothingPlacement.self,
            SavedOutfit.self,
            ShoppingItem.self
        ]
    }
}

enum PersonalShooperMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PersonalShooperSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

@MainActor
@Observable
final class PersistenceController {
    private(set) var container: ModelContainer?
    private(set) var errorMessage: String?

    init() {
        load()
    }

    func load() {
        do {
            let schema = Schema(versionedSchema: PersonalShooperSchemaV1.self)
            let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)
            container = try ModelContainer(
                for: schema,
                migrationPlan: PersonalShooperMigrationPlan.self,
                configurations: [configuration]
            )
            errorMessage = nil
        } catch {
            container = nil
            errorMessage = error.localizedDescription
            AppLog.persistence.error("Unable to open the SwiftData store: \(String(describing: error), privacy: .public)")
        }
    }
}
