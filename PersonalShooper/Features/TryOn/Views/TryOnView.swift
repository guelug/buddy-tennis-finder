import SwiftUI
import AVFoundation

struct TryOnView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TryOnViewModel()
    @State private var showingSubscription = false

    var body: some View {
        NavigationStack {
            VStack {
                switch viewModel.state {
                case .idle:
                    idleContent
                case .capturingClothing:
                    cameraContainer(for: .capturingClothing)
                case .capturingSelf:
                    cameraContainer(for: .capturingSelf)
                case .processing:
                    processingContent
                case .result:
                    resultContent
                case .editing:
                    editingContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.blue.opacity(0.15).ignoresSafeArea())
            .navigationTitle("Virtual Try-On")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.state != .idle {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            viewModel.reset()
                        }
                    }
                }
            }
            .onChange(of: viewModel.clothingImage) { _, newValue in
                if newValue != nil && viewModel.state == .capturingClothing {
                    viewModel.proceedToSelfCapture()
                }
            }
            .onChange(of: viewModel.userImage) { _, newValue in
                if newValue != nil && viewModel.state == .capturingSelf {
                    Task {
                        await viewModel.generateTryOn()
                    }
                }
            }
        }
        .disabled(appState.isPremium == false && viewModel.tryOnCount >= 3)
        .overlay {
            if appState.isPremium == false && viewModel.tryOnCount >= 3 {
                premiumPromptOverlay
            }
        }
        .sheet(isPresented: $showingSubscription) {
            SubscriptionView()
        }
    }

    @ViewBuilder
    private func cameraContainer(for state: TryOnViewModel.State) -> some View {
        let binding: Binding<UIImage?> = state == .capturingClothing ? $viewModel.clothingImage : $viewModel.userImage
        let instruction = state == .capturingClothing ? "Take a photo of the clothing item you want to try on" : "Now take a photo of yourself"

        CameraCaptureView(
            capturedImage: binding,
            guideAspectRatio: 0.75,
            instruction: instruction
        )
    }

    private var idleContent: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "tshirt.fill")
                .font(.system(size: 80))
                .foregroundStyle(Theme.Colors.primary)

            Text("Virtual Try-On")
                .font(.title)
                .fontWeight(.bold)

            Text("Take a photo of any clothing item, then a selfie, and see how it looks on you!")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)

            if !appState.isPremium {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Free tier: 3 try-ons per day")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, Theme.Spacing.sm)
            }

            Spacer()

            Button {
                viewModel.startTryOn()
            } label: {
                Text("Start Try-On")
                    .frame(maxWidth: .infinity)
                    .primaryButtonStyle()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    private var processingContent: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            ProgressView()
                .scaleEffect(2)

            Text("Generating your look...")
                .font(.title2)
                .fontWeight(.semibold)

            Text("This usually takes a few seconds")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var resultContent: some View {
        VStack(spacing: Theme.Spacing.md) {
            if let resultImage = viewModel.resultImage {
                Image(uiImage: resultImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
                    .padding(.horizontal, Theme.Spacing.md)
            }

            HStack(spacing: Theme.Spacing.md) {
                Button {
                    viewModel.startEditing()
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.saveToCloset(modelContext: modelContext)
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                ShareLink(item: Image(uiImage: viewModel.resultImage ?? UIImage()), preview: SharePreview("My Try-On", image: Image(uiImage: viewModel.resultImage ?? UIImage())))
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, Theme.Spacing.md)

            Button {
                viewModel.reset()
            } label: {
                Text("Try Another Item")
            }
            .padding(.bottom, Theme.Spacing.md)
        }
    }

    private var editingContent: some View {
        VStack(spacing: Theme.Spacing.md) {
            if let resultImage = viewModel.resultImage {
                Image(uiImage: resultImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
                    .padding(.horizontal, Theme.Spacing.md)
            }

            TextField("e.g., Make it fit tighter, change the lighting", text: $viewModel.editInstruction)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, Theme.Spacing.md)

            HStack {
                Button("Cancel") {
                    viewModel.cancelEditing()
                }
                .buttonStyle(.bordered)

                Button("Apply") {
                    Task {
                        await viewModel.applyEdit()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.editInstruction.isEmpty)
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }

    private var premiumPromptOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)

                Text("Daily Limit Reached")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("Upgrade to Premium for unlimited try-ons")
                    .foregroundStyle(.white.opacity(0.8))

                Button("Go Premium") {
                    showingSubscription = true
                }
                .premiumButtonStyle()
            }
            .padding(Theme.Spacing.xl)
        }
    }
}

#Preview {
    TryOnView()
        .environment(AppState())
}
