import SwiftUI
import ARKit
import RealityKit

struct ARWardrobeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ARViewModel()
    @State private var showingClothingPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.groupedBackground.ignoresSafeArea()

                if viewModel.isARSupported {
                    ARViewContainer(viewModel: viewModel)
                        .ignoresSafeArea()

                    // Overlay controls
                    VStack {
                        Spacer()

                        // Selected clothing indicator
                        if let clothing = viewModel.selectedClothingItem {
                            HStack {
                                if let image = clothing.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                Text(clothing.name)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.bottom, 100)
                        }

                        // Bottom toolbar
                        HStack(spacing: Theme.Spacing.lg) {
                            Button {
                                viewModel.removePlacedClothing()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .frame(width: 50, height: 50)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }

                            Button {
                                showingClothingPicker = true
                            } label: {
                                Image(systemName: "tshirt.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .frame(width: 60, height: 60)
                                    .background(Theme.Colors.primary)
                                    .clipShape(Circle())
                            }

                            Button {
                                viewModel.placeClothing()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .frame(width: 50, height: 50)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            .disabled(viewModel.selectedClothingItem == nil)
                        }
                        .padding(.bottom, 30)
                    }
                } else {
                    ContentUnavailableView(
                        "AR Not Supported",
                        systemImage: "arkit",
                        description: Text("This device doesn't support AR experiences")
                    )
                }
            }
            .navigationTitle("AR Wardrobe")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingClothingPicker) {
                ClothingPickerSheet(viewModel: viewModel)
            }
            .onAppear {
                viewModel.configure(modelContext: modelContext)
            }
        }
    }
}

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

        // Tap gesture to place clothing
        arView.addGestureRecognizer(
            UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        )

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        if let anchor = viewModel.placedClothingAnchor {
            if anchor.parent == nil {
                uiView.scene.addAnchor(anchor)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, ARSessionDelegate {
        weak var viewModel: ARViewModel?

        init(viewModel: ARViewModel) {
            self.viewModel = viewModel
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = gesture.view as? ARView else { return }
            let location = gesture.location(in: arView)

            // Raycast to find plane
            if let result = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal).first {
                let position = result.worldTransform.columns.3
                let simdPosition = SIMD3<Float>(position.x, position.y, position.z)
                viewModel?.placeClothing(at: simdPosition)
            }
        }
    }
}

struct ClothingPickerSheet: View {
    let viewModel: ARViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: Theme.Spacing.sm) {
                    ForEach(viewModel.clothingItems) { item in
                        Button {
                            viewModel.selectClothing(item)
                            dismiss()
                        } label: {
                            VStack {
                                if let image = item.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 100, height: 100)
                                        .overlay {
                                            Image(systemName: item.category.icon)
                                                .foregroundStyle(.secondary)
                                        }
                                }

                                Text(item.name)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Select Clothing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
