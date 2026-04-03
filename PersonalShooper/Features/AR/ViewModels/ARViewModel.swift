import SwiftUI
import ARKit
import RealityKit
import SwiftData

@Observable
final class ARViewModel {
    var arSession: ARSession?
    var selectedClothingItem: ClothingItem?
    var placedClothingAnchor: AnchorEntity?
    var isARSupported: Bool = ARWorldTrackingConfiguration.isSupported
    var errorMessage: String?
    var clothingItems: [ClothingItem] = []

    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadClothingItems()
    }

    func loadClothingItems() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<ClothingItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        clothingItems = (try? context.fetch(descriptor)) ?? []
    }

    func selectClothing(_ item: ClothingItem) {
        selectedClothingItem = item
    }

    func placeClothing(at position: SIMD3<Float>? = nil) {
        guard let clothingItem = selectedClothingItem,
              let _ = clothingItem.image else { return }

        // Create a simple plane to represent the clothing
        let mesh = MeshResource.generatePlane(width: 0.5, height: 0.7)

        // Create material
        let material = SimpleMaterial()

        let entity = ModelEntity(mesh: mesh, materials: [material])

        // Create anchor
        let anchor = AnchorEntity()
        if let position = position {
            anchor.position = position
        }

        anchor.addChild(entity)
        placedClothingAnchor = anchor
    }

    func removePlacedClothing() {
        placedClothingAnchor?.removeFromParent()
        placedClothingAnchor = nil
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
