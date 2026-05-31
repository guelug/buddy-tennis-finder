import SwiftUI
import ARKit
import RealityKit
import SwiftData

enum ARMode {
    case browse      // Show saved tags
    case place       // Place a new tag for selected item
}

@Observable
@MainActor
final class ARViewModel {
    var arSession: ARSession?
    var selectedClothingItem: ClothingItem?
    var isARSupported: Bool = ARWorldTrackingConfiguration.isSupported
    var errorMessage: String?
    var clothingItems: [ClothingItem] = []
    var placements: [ARClothingPlacement] = []
    var currentMode: ARMode = .browse
    var selectedPlacement: ARClothingPlacement?

    private var modelContext: ModelContext?

    var pendingTapPosition: SIMD3<Float>?
    var preselectedItemID: UUID?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadClothingItems()
        loadPlacements()

        // Listen for preselection from closet detail
        NotificationCenter.default.addObserver(
            forName: .preselectARItem,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let itemID = notification.object as? UUID {
                self?.preselectedItemID = itemID
                self?.selectPreselectedItem()
            }
        }
    }

    func selectPreselectedItem() {
        guard let itemID = preselectedItemID,
              let item = clothingItems.first(where: { $0.id == itemID }) else { return }
        selectedClothingItem = item
        currentMode = .place
        preselectedItemID = nil
    }

    func loadClothingItems() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<ClothingItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        clothingItems = (try? context.fetch(descriptor)) ?? []
    }

    func loadPlacements() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<ARClothingPlacement>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        placements = (try? context.fetch(descriptor)) ?? []
    }

    func selectClothing(_ item: ClothingItem) {
        selectedClothingItem = item
        currentMode = .place
    }

    func placeTag(at position: SIMD3<Float>, shelfName: String? = nil) {
        guard let item = selectedClothingItem else {
            errorMessage = "No garment selected."
            return
        }

        let placement = ARClothingPlacement(
            clothingItemID: item.id,
            position: position,
            label: item.name,
            shelfName: shelfName
        )

        modelContext?.insert(placement)
        do {
            try modelContext?.save()
            placements.append(placement)
            selectedClothingItem = nil
            currentMode = .browse
        } catch {
            errorMessage = "Couldn't save the location."
        }
    }

    func deletePlacement(_ placement: ARClothingPlacement) {
        modelContext?.delete(placement)
        do {
            try modelContext?.save()
            placements.removeAll { $0.id == placement.id }
        } catch {
            errorMessage = "Couldn't remove the tag."
        }
    }

    func findPlacement(for item: ClothingItem) -> ARClothingPlacement? {
        placements.first { $0.clothingItemID == item.id }
    }

    func createARConfiguration() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }

        return configuration
    }
}
