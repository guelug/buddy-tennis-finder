import SwiftUI
import ARKit
import RealityKit
import SwiftData

struct ARWardrobeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ARViewModel()
    @State private var showingClothingPicker = false
    @State private var showingFinder = false
    @State private var showingShelfNameInput = false
    @State private var shelfNameInput = ""
    @State private var pendingTapPosition: SIMD3<Float>?

    private var isSpanish: Bool {
        appState.preferredLanguage == .spanish
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.groupedBackground.ignoresSafeArea()

                if viewModel.isARSupported {
                    ARViewContainer(viewModel: viewModel)
                        .ignoresSafeArea()

                    // Overlay UI
                    VStack {
                        // Top info bar
                        topInfoBar

                        Spacer()

                        // Bottom controls
                        bottomControls
                    }
                } else {
                    ContentUnavailableView(
                        isSpanish ? "AR no disponible" : "AR Not Available",
                        systemImage: "arkit",
                        description: Text(isSpanish ? "Este dispositivo no soporta experiencias de AR" : "This device does not support AR experiences")
                    )
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isSpanish ? "Cerrar" : "Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingClothingPicker) {
                ClothingPickerSheet(viewModel: viewModel, purpose: .locate)
            }
            .sheet(isPresented: $showingFinder) {
                ClothingPickerSheet(viewModel: viewModel, purpose: .find)
            }
            .alert(
                isSpanish ? "Guardar ubicación" : "Save Location",
                isPresented: $showingShelfNameInput
            ) {
                TextField(isSpanish ? "Nombre del estante/cajón (opcional)" : "Shelf/drawer name (optional)", text: $shelfNameInput)
                Button(isSpanish ? "Guardar" : "Save") {
                    if let position = pendingTapPosition {
                        viewModel.placeTag(at: position, shelfName: shelfNameInput.isEmpty ? nil : shelfNameInput)
                        pendingTapPosition = nil
                        shelfNameInput = ""
                    }
                }
                Button(isSpanish ? "Cancelar" : "Cancel", role: .cancel) {
                    pendingTapPosition = nil
                    shelfNameInput = ""
                }
            } message: {
                Text(isSpanish ? "¿Dónde guardaste esta prenda?" : "Where did you store this garment?")
            }
            .alert(
                isSpanish ? "No se pudo guardar" : "Couldn't save",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear {
                viewModel.configure(modelContext: modelContext)
            }
            .onReceive(NotificationCenter.default.publisher(for: .arPlacementTapped)) { notification in
                if let position = notification.object as? SIMD3<Float> {
                    pendingTapPosition = position
                    showingShelfNameInput = true
                }
            }
        }
    }

    private var navigationTitle: String {
        switch viewModel.currentMode {
        case .browse:
            return isSpanish ? "Armario AR" : "AR Closet"
        case .place:
            return isSpanish ? "Coloca: \(viewModel.selectedClothingItem?.name ?? "")" : "Place: \(viewModel.selectedClothingItem?.name ?? "")"
        case .find:
            return isSpanish ? "Buscando: \(viewModel.selectedClothingItem?.name ?? "")" : "Finding: \(viewModel.selectedClothingItem?.name ?? "")"
        }
    }

    private var topInfoBar: some View {
        VStack(spacing: 8) {
            if viewModel.currentMode == .place {
                HStack {
                    Image(systemName: "hand.tap.fill")
                    Text(isSpanish ? "Toca donde guardaste la prenda" : "Tap where you stored the garment")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.8))
                .clipShape(Capsule())
            } else if viewModel.currentMode == .find {
                findGuidanceBanner
            } else if viewModel.placements.isEmpty {
                HStack {
                    Image(systemName: "info.circle.fill")
                    Text(isSpanish ? "Selecciona una prenda para marcar dónde está" : "Select a garment to mark its location")
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text(isSpanish ? "\(viewModel.placements.count) prendas ubicadas" : "\(viewModel.placements.count) garments located")
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
        }
        .padding(.top, 8)
    }

    /// Big directional arrow + distance shown while guiding the user to a garment.
    private var findGuidanceBanner: some View {
        VStack(spacing: 10) {
            if viewModel.isCloseToTarget {
                Label(isSpanish ? "¡Aquí está!" : "It's right here!", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(.white)
                    .rotationEffect(.radians(Double(viewModel.findHeadingAngle)))
                    .animation(.snappy(duration: 0.2), value: viewModel.findHeadingAngle)

                if let distance = viewModel.findDistance {
                    Text(String(format: isSpanish ? "%.1f m" : "%.1f m", distance))
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                }

                Text(verticalHintText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var verticalHintText: String {
        switch viewModel.findVerticalHint {
        case "up": return isSpanish ? "Mira hacia arriba" : "Look up"
        case "down": return isSpanish ? "Mira hacia abajo" : "Look down"
        default: return isSpanish ? "Gira hacia la flecha" : "Turn toward the arrow"
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Find mode: just a Stop button (the banner shows the arrow).
            if viewModel.currentMode == .find {
                Button {
                    viewModel.stopFinding()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                        Text(isSpanish ? "Dejar de buscar" : "Stop finding")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.red.opacity(0.85))
                    .clipShape(Capsule())
                }
                .buttonStyle(.premiumPressable)
                .padding(.bottom, 30)
            }

            // Selected item indicator (place mode)
            if viewModel.currentMode == .place,
               let item = viewModel.selectedClothingItem {
                HStack {
                    if let image = item.displayImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    VStack(alignment: .leading) {
                        Text(item.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(isSpanish ? "Toca en la pantalla para ubicar" : "Tap on screen to place")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    Button {
                        viewModel.selectedClothingItem = nil
                        viewModel.currentMode = .browse
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }

            // Browse mode: show placed items list or select button
            if viewModel.currentMode == .browse {
                if !viewModel.placements.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.placements) { placement in
                                if let item = viewModel.clothingItems.first(where: { $0.id == placement.clothingItemID }) {
                                    PlacedItemChip(
                                        item: item,
                                        shelfName: placement.shelfName,
                                        isSelected: viewModel.selectedPlacement?.id == placement.id
                                    ) {
                                        viewModel.selectedPlacement = placement
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                HStack(spacing: Theme.Spacing.md) {
                    Button {
                        showingClothingPicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text(isSpanish ? "Ubicar" : "Locate")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(Theme.Colors.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.premiumPressable)

                    if !viewModel.placements.isEmpty {
                        Button {
                            showingFinder = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "location.magnifyingglass")
                                Text(isSpanish ? "Encontrar" : "Find")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(.green.opacity(0.85))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.premiumPressable)
                    }

                    if let selected = viewModel.selectedPlacement {
                        Button {
                            viewModel.deletePlacement(selected)
                            viewModel.selectedPlacement = nil
                        } label: {
                            Image(systemName: "trash.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 50, height: 50)
                                .background(.red.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.premiumPressable)
                    }
                }
                .padding(.bottom, 30)
            }
        }
    }
}

// MARK: - AR Container

struct ARViewContainer: UIViewRepresentable {
    let viewModel: ARViewModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session.delegate = context.coordinator

        let configuration = viewModel.createARConfiguration()
        arView.session.run(configuration)

        // Add coaching overlay
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        arView.addSubview(coachingOverlay)

        viewModel.arSession = arView.session

        // Tap gesture
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Update placed tags
        updatePlacedTags(in: uiView)

        // Highlight selected placement
        if let selected = viewModel.selectedPlacement {
            highlightTag(for: selected, in: uiView)
        }
    }

    private func updatePlacedTags(in arView: ARView) {
        // Remove old tag entities that are no longer in placements
        let currentIDs = Set(viewModel.placements.map(\.id.uuidString))
        for entity in arView.scene.anchors {
            let name = entity.name
            if name.hasPrefix("tag_") {
                let id = String(name.dropFirst(4))
                if !currentIDs.contains(id) {
                    entity.removeFromParent()
                }
            }
        }

        // Add new tags
        for placement in viewModel.placements {
            let entityName = "tag_\(placement.id.uuidString)"
            let exists = arView.scene.anchors.contains { $0.name == entityName }
            if exists { continue }

            let anchor = AnchorEntity(world: placement.simdPosition)
            anchor.name = entityName

            // Create tag visualization
            let tagEntity = createTagEntity(for: placement, arView: arView)
            anchor.addChild(tagEntity)
            arView.scene.addAnchor(anchor)
        }
    }

    private func highlightTag(for placement: ARClothingPlacement, in arView: ARView) {
        let entityName = "tag_\(placement.id.uuidString)"
        for entity in arView.scene.anchors {
            if entity.name == entityName {
                // Pulse animation
                let pulse = Transform(scale: SIMD3<Float>(1.3, 1.3, 1.3))
                entity.move(to: pulse, relativeTo: entity.parent, duration: 0.3, timingFunction: .easeInOut)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let normal = Transform(scale: SIMD3<Float>(1, 1, 1))
                    entity.move(to: normal, relativeTo: entity.parent, duration: 0.3, timingFunction: .easeInOut)
                }
            }
        }
    }

    private func createTagEntity(for placement: ARClothingPlacement, arView: ARView) -> Entity {
        let container = Entity()

        // Pin stem
        let stemMesh = MeshResource.generateCylinder(height: 0.15, radius: 0.005)
        let stemMaterial = SimpleMaterial(color: .systemBlue, isMetallic: false)
        let stem = ModelEntity(mesh: stemMesh, materials: [stemMaterial])
        stem.position = SIMD3<Float>(0, 0.075, 0)
        container.addChild(stem)

        // Tag sphere (top)
        let sphereMesh = MeshResource.generateSphere(radius: 0.025)
        let sphereMaterial = SimpleMaterial(color: .systemBlue, isMetallic: false)
        let sphere = ModelEntity(mesh: sphereMesh, materials: [sphereMaterial])
        sphere.position = SIMD3<Float>(0, 0.15, 0)
        container.addChild(sphere)

        // Floating label (if we can find the item)
        if let item = viewModel.clothingItems.first(where: { $0.id == placement.clothingItemID }),
           let image = item.displayImage,
           let cgImage = image.cgImage {
            do {
                let texture = try TextureResource(image: cgImage, options: .init(semantic: .color))
                let planeMesh = MeshResource.generatePlane(width: 0.12, height: 0.12)
                var material = UnlitMaterial(texture: texture)
                material.faceCulling = .none
                let photoPlane = ModelEntity(mesh: planeMesh, materials: [material])
                photoPlane.position = SIMD3<Float>(0, 0.22, 0)
                container.addChild(photoPlane)
            } catch {
                // Fallback: just show the sphere
            }
        }

        return container
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, ARSessionDelegate, @unchecked Sendable {
        var viewModel: ARViewModel?

        init(viewModel: ARViewModel) {
            self.viewModel = viewModel
        }

        /// Per-frame: while finding, refresh the arrow heading/distance from the camera pose.
        nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let transform = frame.camera.transform // simd_float4x4 is Sendable; copy before hopping.
            Task { @MainActor in
                guard self.viewModel?.currentMode == .find else { return }
                self.viewModel?.updateFindGuidance(cameraTransform: transform)
            }
        }

        @MainActor
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = gesture.view as? ARView else { return }
            let location = gesture.location(in: arView)

            // If in place mode, raycast and save position
            if viewModel?.currentMode == .place {
                // Try multiple raycast strategies for better responsiveness
                var result: ARRaycastResult?

                // Strategy 1: Existing plane (most accurate)
                result = arView.raycast(from: location, allowing: .existingPlaneInfinite, alignment: .horizontal).first

                // Strategy 2: Estimated plane (if no existing plane)
                if result == nil {
                    result = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal).first
                }

                // Strategy 3: Any surface (vertical or horizontal)
                if result == nil {
                    result = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .vertical).first
                }

                // Strategy 4: Use camera forward direction at fixed distance as fallback
                if result == nil {
                    result = raycastFromCamera(at: location, in: arView)
                }

                if let finalResult = result {
                    let position = finalResult.worldTransform.columns.3
                    let simdPosition = SIMD3<Float>(position.x, position.y + 0.01, position.z)

                    // Haptic feedback
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()

                    // Show shelf name input via notification
                    NotificationCenter.default.post(name: .arPlacementTapped, object: simdPosition)
                } else {
                    // Still no result - show error
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.error)
                }
            } else {
                // Browse mode: select nearest tag
                selectNearestTag(at: location, in: arView)
            }
        }

        /// Fallback raycast: cast from camera in the direction of the tap at a reasonable distance
        @MainActor
        private func raycastFromCamera(at location: CGPoint, in arView: ARView) -> ARRaycastResult? {
            // Get ray from camera through tap point
            let ray = arView.ray(through: location)
            guard let rayOrigin = ray?.origin, let rayDirection = ray?.direction else { return nil }

            // Place at 1.5 meters from camera in the tap direction
            let distance: Float = 1.5
            let targetPosition = rayOrigin + rayDirection * distance

            // Create a transform at that position
            var translation = matrix_identity_float4x4
            translation.columns.3 = SIMD4<Float>(targetPosition.x, targetPosition.y, targetPosition.z, 1)

            // Use raycast query to get a proper result
            let query = ARRaycastQuery(
                origin: rayOrigin,
                direction: rayDirection,
                allowing: .estimatedPlane,
                alignment: .horizontal
            )
            return arView.session.raycast(query).first
        }

        @MainActor
        private func selectNearestTag(at location: CGPoint, in arView: ARView) {
            // Find which tag is closest to the tap
            var nearestDistance: CGFloat = .greatestFiniteMagnitude
            var nearestPlacement: ARClothingPlacement?

            for placement in viewModel?.placements ?? [] {
                let entityName = "tag_\(placement.id.uuidString)"
                guard let anchor = arView.scene.anchors.first(where: { $0.name == entityName }) else { continue }

                // Project 3D position to 2D screen
                let screenPos = arView.project(anchor.position(relativeTo: nil)) ?? CGPoint.zero
                let distance = hypot(screenPos.x - location.x, screenPos.y - location.y)

                if distance < nearestDistance && distance < 100 {
                    nearestDistance = distance
                    nearestPlacement = placement
                }
            }

            if let placement = nearestPlacement {
                viewModel?.selectedPlacement = placement
            }
        }
    }
}

// MARK: - Clothing Picker

struct ClothingPickerSheet: View {
    enum Purpose { case locate, find }

    let viewModel: ARViewModel
    var purpose: Purpose = .locate
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var isSpanish: Bool {
        appState.preferredLanguage == .spanish
    }

    /// In find mode only show garments that already have a saved location.
    private var visibleItems: [ClothingItem] {
        switch purpose {
        case .locate: return viewModel.clothingItems
        case .find: return viewModel.clothingItems.filter { viewModel.findPlacement(for: $0) != nil }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if visibleItems.isEmpty {
                    ContentUnavailableView(
                        purpose == .find ? (isSpanish ? "Sin prendas ubicadas" : "No located garments") : (isSpanish ? "Armario vacío" : "Empty closet"),
                        systemImage: purpose == .find ? "location.slash" : "cabinet",
                        description: Text(
                            purpose == .find
                                ? (isSpanish ? "Primero marca dónde guardas tus prendas con \"Ubicar\"." : "First mark where you store garments with \"Locate\".")
                                : (isSpanish ? "Guarda prendas en el armario para ubicarlas aquí en AR." : "Save garments in your closet to locate them here in AR.")
                        )
                    )
                } else {
                    List {
                        ForEach(visibleItems) { item in
                            Button {
                                if purpose == .find {
                                    viewModel.startFinding(item)
                                } else {
                                    viewModel.selectClothing(item)
                                }
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    if let image = item.displayImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 50, height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 50, height: 50)
                                            .overlay {
                                                Image(systemName: item.category.icon)
                                                    .foregroundStyle(.secondary)
                                            }
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.headline)
                                        Text(item.category.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        // Show if already placed
                                        if viewModel.findPlacement(for: item) != nil {
                                            HStack(spacing: 4) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.caption2)
                                                    .foregroundStyle(.green)
                                                Text(isSpanish ? "Ya ubicada" : "Already located")
                                                    .font(.caption2)
                                                    .foregroundStyle(.green)
                                            }
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(isSpanish ? "Seleccionar prenda" : "Select garment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSpanish ? "Hecho" : "Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Placed Item Chip

struct PlacedItemChip: View {
    let item: ClothingItem
    let shelfName: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let image = item.displayImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    if let shelf = shelfName {
                        Text(shelf)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Theme.Colors.primary : Color(.systemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let arPlacementTapped = Notification.Name("arPlacementTapped")
    static let preselectARItem = Notification.Name("preselectARItem")
}
