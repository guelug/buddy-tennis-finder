import SwiftUI
import ARKit
import RealityKit
import SwiftData

@Observable
@MainActor
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
              let image = clothingItem.displayImage ?? clothingItem.image,
              let cgImage = image.cgImage else {
            errorMessage = "No image is available for this garment."
            return
        }

        removePlacedClothing()

        let aspectRatio = max(Float(image.size.width / max(image.size.height, 1)), 0.2)
        let height: Float = 0.75
        let width = min(max(height * aspectRatio, 0.28), 0.95)
        let mesh = MeshResource.generatePlane(width: width, height: height)

        do {
            let texture = try TextureResource(
                image: cgImage,
                withName: clothingItem.id.uuidString,
                options: TextureResource.CreateOptions(semantic: .color)
            )
            var material = UnlitMaterial(texture: texture)
            material.faceCulling = .none

            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.name = clothingItem.name
            // Lift the plane so its base rests on the detected surface and it stands upright.
            entity.position = SIMD3<Float>(0, height / 2, 0)

            let anchor = AnchorEntity()
            let basePosition = position ?? SIMD3<Float>(0, 0, -0.8)
            anchor.position = basePosition

            // Rotate the garment (yaw only) so it faces the user, like it's hanging in front of them.
            if let cameraTransform = arSession?.currentFrame?.camera.transform {
                let cameraPosition = cameraTransform.columns.3
                let dx = cameraPosition.x - basePosition.x
                let dz = cameraPosition.z - basePosition.z
                if abs(dx) > 0.0001 || abs(dz) > 0.0001 {
                    anchor.orientation = simd_quatf(angle: atan2(dx, dz), axis: SIMD3<Float>(0, 1, 0))
                }
            }

            anchor.addChild(entity)
            placedClothingAnchor = anchor
            errorMessage = nil
        } catch {
            errorMessage = "I couldn't prepare the AR preview for this garment."
        }
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
