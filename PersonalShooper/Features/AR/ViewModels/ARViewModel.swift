import SwiftUI
import ARKit
import RealityKit
import SwiftData

enum ARMode {
    case browse      // Show saved tags
    case place       // Place a new tag for selected item
    case find        // Guide the user to a saved garment with a direction arrow
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

    /// Relocalization/mapping guidance shown until the saved space is recognized again.
    var spaceStatusHint: String?
    /// True once ARKit has relocalized into (or freshly mapped) a usable space.
    var isSpaceReady: Bool = false
    /// Set by the view so background callbacks can localize hints.
    var language: Language = .english

    // MARK: - Find guidance state
    var findTarget: ARClothingPlacement?
    /// Distance from the camera to the target garment, in metres.
    var findDistance: Float?
    /// Signed horizontal angle (radians) between camera forward and the target: ~0 = straight ahead,
    /// positive = turn right, negative = turn left. Drives the on-screen arrow rotation.
    var findHeadingAngle: Float = 0
    /// "up" / "down" / "level" hint for vertical position relative to the camera.
    var findVerticalHint: String = "level"

    var isCloseToTarget: Bool {
        guard let distance = findDistance else { return false }
        return distance < 0.6
    }

    func startFinding(_ item: ClothingItem) {
        guard let placement = findPlacement(for: item) else {
            errorMessage = "That garment doesn't have a saved location yet."
            return
        }
        selectedClothingItem = item
        findTarget = placement
        selectedPlacement = placement
        currentMode = .find
    }

    func stopFinding() {
        findTarget = nil
        findDistance = nil
        findHeadingAngle = 0
        findVerticalHint = "level"
        selectedClothingItem = nil
        currentMode = .browse
    }

    /// Recomputes the arrow heading + distance from the current camera transform (called per frame).
    func updateFindGuidance(cameraTransform: simd_float4x4) {
        guard let target = findTarget else { return }

        let cameraPos = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let targetPos = target.simdPosition
        let delta = targetPos - cameraPos

        findDistance = simd_length(delta)

        // Camera forward is -Z in ARKit camera space.
        let forward = -SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)

        // Work on the horizontal (x,z) plane for the heading.
        let forwardH = SIMD2<Float>(forward.x, forward.z)
        let deltaH = SIMD2<Float>(delta.x, delta.z)
        if simd_length(forwardH) > 0.0001 && simd_length(deltaH) > 0.0001 {
            let f = simd_normalize(forwardH)
            let d = simd_normalize(deltaH)
            // Signed angle from forward to target (right-handed around up axis).
            findHeadingAngle = atan2(f.x * d.y - f.y * d.x, f.x * d.x + f.y * d.y)
        }

        if delta.y > 0.35 {
            findVerticalHint = "up"
        } else if delta.y < -0.35 {
            findVerticalHint = "down"
        } else {
            findVerticalHint = "level"
        }
    }

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

        // Listen for a "find this garment" request from closet detail.
        NotificationCenter.default.addObserver(
            forName: .findARItem,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let itemID = notification.object as? UUID {
                self?.pendingFindItemID = itemID
                self?.startFindingPreselected()
            }
        }
    }

    var pendingFindItemID: UUID?

    func startFindingPreselected() {
        guard let itemID = pendingFindItemID,
              let item = clothingItems.first(where: { $0.id == itemID }) else { return }
        pendingFindItemID = nil
        startFinding(item)
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
            // Persist the world map so this location survives leaving/re-entering AR.
            saveWorldMap()
        } catch {
            errorMessage = "Couldn't save the location."
        }
    }

    /// Snapshots and saves the current ARKit world map so saved tags relocalize next session.
    func saveWorldMap() {
        arSession?.getCurrentWorldMap { worldMap, _ in
            guard let worldMap else { return }
            ARWorldMapStore.save(worldMap)
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

        // Restore the saved space so previously-placed tags line up after relocalization.
        if let savedMap = ARWorldMapStore.load() {
            configuration.initialWorldMap = savedMap
            isSpaceReady = false
            spaceStatusHint = nil
        } else {
            isSpaceReady = true
        }

        return configuration
    }

    /// Updates the relocalization hint from the session's mapping status (called per frame).
    func updateSpaceStatus(_ status: ARFrame.WorldMappingStatus) {
        let spanish = language == .spanish
        switch status {
        case .mapped, .extending:
            isSpaceReady = true
            spaceStatusHint = nil
        case .limited:
            isSpaceReady = false
            spaceStatusHint = spanish
                ? "Mueve el dispositivo despacio por tu armario para reconocer el espacio…"
                : "Move the device slowly around your closet to recognize the space…"
        case .notAvailable:
            isSpaceReady = false
            spaceStatusHint = spanish ? "Inicializando AR…" : "Initializing AR…"
        @unknown default:
            break
        }
    }
}
