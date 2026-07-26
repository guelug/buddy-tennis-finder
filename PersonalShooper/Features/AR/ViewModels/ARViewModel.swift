import SwiftUI
import ARKit
import RealityKit
import SwiftData
import os.log

enum ARMode {
    case browse      // Show saved tags
    case place       // Place a new tag for selected item
    case find        // Guide the user to a saved garment with a direction arrow
}

/// Sendable distillation of `ARCamera.TrackingState` so the session delegate can hand the relevant
/// state to the main actor without carrying the non-Sendable ARKit enum across the hop.
enum CameraReadiness: Sendable {
    case normal          // Tracking is solid; if a saved map was provided, relocalization completed.
    case relocalizing    // Matching the live camera against a saved world map.
    case initializing    // Brand-new session still gathering features.
    case limited         // Excessive motion / insufficient features.
    case unavailable
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

    /// True when there's a saved world map on disk that the next session will try to relocalize
    /// into. Drives the "look at the area you scanned" hint.
    var isRelocalizing: Bool = false
    /// Relocalization/mapping guidance shown until the saved space is recognized again.
    var spaceStatusHint: String?
    /// True once ARKit has relocalized into (or freshly mapped) a usable space. While false, the
    /// stored tag positions are not aligned with the camera, so the UI hides them.
    var isSpaceReady: Bool = false
    /// Set by the view so background callbacks can localize hints.
    var language: Language = .english

    // MARK: - World map persistence

    /// Set when the user placed a tag but the world wasn't mapped yet — keeps retrying the
    /// `getCurrentWorldMap` capture until ARKit reports `.mapped`/`.extending`.
    private var pendingWorldMapSave: Bool = false
    /// True while a `getCurrentWorldMap` capture is in flight. Without this guard the per-frame
    /// retry in `updateTracking` fires a full (expensive) map serialization ~60×/second, which
    /// stalls the render loop badly enough that the session looks like it restarts.
    private var isCapturingWorldMap: Bool = false
    /// True once tracking has reached `.normal` at least once in this session — i.e. the world
    /// origin is trustworthy. Saving a map before this would overwrite the good saved map with a
    /// fresh, unaligned one and scatter every stored placement on the next launch.
    private(set) var hasAlignedOnce: Bool = false
    private let log = Logger(subsystem: "com.personalshooper.app", category: "ARViewModel")

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

        // Listen for preselection from closet detail. The observer fires on the main queue, so we
        // `assumeIsolated` to mutate main-actor state without an async hop. Only the Sendable UUID
        // crosses into the isolated closure.
        NotificationCenter.default.addObserver(
            forName: .preselectARItem,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let itemID = notification.object as? UUID
            MainActor.assumeIsolated {
                guard let self, let itemID else { return }
                self.preselectedItemID = itemID
                self.selectPreselectedItem()
            }
        }

        // Listen for a "find this garment" request from closet detail.
        NotificationCenter.default.addObserver(
            forName: .findARItem,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let itemID = notification.object as? UUID
            MainActor.assumeIsolated {
                guard let self, let itemID else { return }
                self.pendingFindItemID = itemID
                self.startFindingPreselected()
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
        log.info("Loaded \(self.placements.count, privacy: .public) AR placements from SwiftData.")
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
            // Mark the world map dirty so we keep retrying the capture until the space is mapped.
            pendingWorldMapSave = true
            // Attempt an immediate save (no-op if the world isn't mapped yet — the next
            // `updateSpaceStatus(.mapped)` will trigger a retry).
            saveWorldMap()
        } catch {
            errorMessage = "Couldn't save the location."
            log.error("placeTag save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Snapshots and saves the current ARKit world map.
    ///
    /// Two guards matter here:
    /// * `hasAlignedOnce` — never persist a map captured before tracking reached `.normal`. If the
    ///   session started from a saved map and never relocalized, ARKit is building a *fresh* map
    ///   with a different origin; writing it would invalidate every stored placement (the classic
    ///   "the world starts over and my tags are gone" symptom).
    /// * `isCapturingWorldMap` — `getCurrentWorldMap` serialises the whole map and is expensive, so
    ///   we never allow two captures at once.
    func saveWorldMap() {
        guard hasAlignedOnce else {
            log.info("Skipping world map save: space not aligned yet.")
            return
        }
        guard !isCapturingWorldMap else { return }
        guard let session = arSession else { return }

        isCapturingWorldMap = true
        session.getCurrentWorldMap { [weak self] worldMap, error in
            // `ARWorldMap` isn't Sendable, so the archiving happens here on ARKit's own queue and
            // only the Bool results cross to the main actor.
            let captureFailureReason = error?.localizedDescription
            let didCapture = worldMap != nil
            if let worldMap {
                ARWorldMapStore.save(worldMap)
            }

            Task { @MainActor in
                guard let self else { return }
                self.isCapturingWorldMap = false
                if let captureFailureReason {
                    self.log.error("getCurrentWorldMap error: \(captureFailureReason, privacy: .public)")
                    return
                }
                // If the world wasn't mapped yet, keep the pending flag so we retry on a later frame.
                if didCapture {
                    self.pendingWorldMapSave = false
                }
            }
        }
    }

    /// Called when the AR view is dismissed: capture the latest world map so the scanned space
    /// (and all existing placements) survive closing/reopening the AR. We DON'T pause the session
    /// ourselves — the AR view tearing down already does that — and we never block dismissal on
    /// the (async) world map completion.
    func persistCurrentSpace() {
        saveWorldMap()
    }

    func deletePlacement(_ placement: ARClothingPlacement) {
        modelContext?.delete(placement)
        do {
            try modelContext?.save()
            placements.removeAll { $0.id == placement.id }
            // If the user just removed the last tag, the world map is still valid for OTHER
            // spaces, so we keep it. (If we ever support per-placement maps, this would clear.)
        } catch {
            errorMessage = "Couldn't remove the tag."
        }
    }

    func findPlacement(for item: ClothingItem) -> ARClothingPlacement? {
        placements.first { $0.clothingItemID == item.id }
    }

    /// True when there's something to reset (a saved map and/or existing placements). Drives whether
    /// the "reset space" escape hatch is offered.
    var canResetSpace: Bool {
        ARWorldMapStore.hasSavedMap || !placements.isEmpty
    }

    /// Escape hatch for when relocalization can't complete (e.g. the user is in a different room, or
    /// the saved map is stale): wipe the saved world map AND the placements — their positions live in
    /// a coordinate space that no longer exists, so keeping them would just scatter tags — then
    /// restart the session fresh so the user can map and re-mark from scratch. Destructive, so the
    /// caller confirms first.
    func resetSpace() {
        ARWorldMapStore.clear()
        for placement in placements {
            modelContext?.delete(placement)
        }
        try? modelContext?.save()
        placements.removeAll()
        selectedPlacement = nil
        selectedClothingItem = nil
        findTarget = nil
        currentMode = .browse
        expectsRelocalization = false
        isRelocalizing = false
        isSpaceReady = false
        pendingWorldMapSave = false
        isCapturingWorldMap = false
        hasAlignedOnce = false
        // No saved map now, so this returns a fresh-mapping configuration.
        let configuration = createARConfiguration()
        beginSession(expectsSavedMap: false)
        arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func createARConfiguration() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }

        // Restore the saved space so previously-placed tags line up after relocalization. Actual
        // readiness is driven per-frame by `updateTracking(readiness:mappingStatus:)`; the flags and
        // hint are seeded separately by `beginSession()` so this stays free of observable writes
        // (it's called from `makeUIView`, i.e. inside a SwiftUI update).
        if let savedMap = ARWorldMapStore.load() {
            configuration.initialWorldMap = savedMap
        }

        return configuration
    }

    /// Seeds the relocalization expectation and the first guidance hint. Call right after handing a
    /// configuration to `ARSession.run`.
    func beginSession(expectsSavedMap: Bool) {
        expectsRelocalization = expectsSavedMap
        isRelocalizing = expectsSavedMap
        isSpaceReady = false
        hasAlignedOnce = false
        spaceStatusHint = expectsSavedMap
            ? (language == .spanish
                ? "Apunta la cámara hacia la zona que escaneaste para reconocer el espacio…"
                : "Point the camera at the area you scanned to recognize the space…")
            : (language == .spanish
                ? "Mueve el dispositivo despacio por tu armario para mapear el espacio antes de guardar ubicaciones."
                : "Slowly move the device around your closet to map the space before saving locations.")
    }

    /// True when the current session was started with a saved world map and therefore must
    /// relocalize before the stored tag positions are trustworthy.
    private var expectsRelocalization = false

    /// Updates space readiness from the camera's *tracking state* (called per frame).
    ///
    /// Readiness is keyed off `trackingState`, NOT `worldMappingStatus`: when a session is started
    /// with a saved `initialWorldMap`, ARKit keeps the camera in `.limited(.relocalizing)` until the
    /// live view matches the saved features, and only then snaps the world origin onto the saved map
    /// and returns to `.normal`. `worldMappingStatus`, by contrast, can report `.mapped`/`.extending`
    /// while ARKit is still building a *fresh, unaligned* map — drawing saved tags then would scatter
    /// them at the wrong spots. Waiting for `.normal` is what makes saved locations line up reliably.
    func updateTracking(readiness: CameraReadiness, mappingStatus: ARFrame.WorldMappingStatus) {
        let spanish = language == .spanish

        // Computed first, then assigned only on change. This runs at 60 fps and every mutation of
        // an `@Observable` property invalidates the SwiftUI body (and therefore re-runs
        // `updateUIView`, which walks the whole scene graph). Writing unconditionally turned a
        // per-frame no-op into a per-frame full UI pass.
        var nextReady = isSpaceReady
        var nextRelocalizing = isRelocalizing
        var nextHint: String?

        switch readiness {
        case .normal:
            nextReady = true
            nextRelocalizing = false
            nextHint = nil
        case .relocalizing:
            nextRelocalizing = true
            nextReady = false
            nextHint = spanish
                ? "Apunta la cámara hacia la zona que escaneaste para reconocer el espacio…"
                : "Point the camera at the area you scanned to recognize the space…"
        case .initializing:
            nextReady = false
            nextHint = expectsRelocalization
                ? (spanish
                    ? "Apunta la cámara hacia la zona que escaneaste para reconocer el espacio…"
                    : "Point the camera at the area you scanned to recognize the space…")
                : (spanish
                    ? "Mueve el dispositivo despacio por tu armario para mapear el espacio…"
                    : "Slowly move the device around your closet to map the space…")
        case .limited:
            // Transient `.limited` (excessive motion, a moment of low texture) happens constantly —
            // including on the very frame the user taps to mark a garment. Once the space has been
            // aligned we keep the tags on screen and only nudge the user, instead of tearing every
            // anchor out of the scene and rebuilding it (which read as "the world restarted").
            nextReady = hasAlignedOnce
            nextRelocalizing = false
            nextHint = hasAlignedOnce
                ? nil
                : (spanish
                    ? "Mueve el dispositivo despacio para estabilizar el seguimiento…"
                    : "Move the device slowly to stabilize tracking…")
        case .unavailable:
            nextReady = false
            nextHint = spanish ? "Inicializando AR…" : "Initializing AR…"
        }

        if isSpaceReady != nextReady { isSpaceReady = nextReady }
        if isRelocalizing != nextRelocalizing { isRelocalizing = nextRelocalizing }
        if spaceStatusHint != nextHint { spaceStatusHint = nextHint }

        if readiness == .normal {
            if !hasAlignedOnce {
                hasAlignedOnce = true
                log.info("AR space aligned; world map saves are now allowed.")
            }
            // Space is aligned — flush any world-map capture queued by a recent placement.
            if pendingWorldMapSave {
                saveWorldMap()
            }
        }
    }

    /// ARKit interrupted the session (app backgrounded, camera taken over, device locked). Reported
    /// so the UI can explain why tracking paused instead of silently showing a frozen scene.
    func sessionWasInterrupted() {
        isSpaceReady = false
        spaceStatusHint = language == .spanish
            ? "Sesión de AR pausada. Vuelve a apuntar a tu armario para retomarla…"
            : "AR session paused. Point back at your closet to resume…"
    }

    /// Surfaces an ARKit session failure instead of leaving a black/frozen camera view.
    func handleSessionFailure(_ message: String) {
        isSpaceReady = false
        errorMessage = message
        log.error("AR session failed: \(message, privacy: .public)")
    }
}
