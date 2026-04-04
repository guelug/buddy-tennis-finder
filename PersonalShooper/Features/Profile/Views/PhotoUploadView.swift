import SwiftUI
import UIKit
import PhotosUI

struct PhotoUploadView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep: UploadStep = .faceCloseUp
    @State private var faceCloseUp: UIImage?
    @State private var faceProfile: UIImage?
    @State private var fullBodyFront: UIImage?
    @State private var fullBodyBack: UIImage?
    @State private var showPrivacyNotice = false

    var startStep: UploadStep?

    init(startStep: UploadStep? = nil) {
        self.startStep = startStep
    }
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var isAnalyzing = false
    @State private var analysisProgress = 0.0
    @State private var errorMessage: String?
    @State private var selectedPhotoItem: PhotosPickerItem?

    private let photoAnalysisService = PhotoAnalysisService()

    enum UploadStep: Int, CaseIterable {
        case faceCloseUp = 0
        case faceProfile = 1
        case fullBodyFront = 2
        case fullBodyBack = 3

        var title: String {
            switch self {
            case .faceCloseUp: return "Primer Plano del Rostro"
            case .faceProfile: return "Perfil del Rostro"
            case .fullBodyFront: return "Cuerpo Completo Frontal"
            case .fullBodyBack: return "Cuerpo Completo Posterior"
            }
        }

        var description: String {
            switch self {
            case .faceCloseUp: return "Toma una foto clara de tu rostro de frente"
            case .faceProfile: return "Toma una foto de tu rostro de perfil"
            case .fullBodyFront: return "Toma una foto de cuerpo completo de frente"
            case .fullBodyBack: return "Toma una foto de cuerpo completo de espalda"
            }
        }

        var icon: String {
            switch self {
            case .faceCloseUp: return "face.smiling"
            case .faceProfile: return "face.dashed"
            case .fullBodyFront: return "figure.stand"
            case .fullBodyBack: return "figure.stand.line.dotted.figure.stand"
            }
        }
    }

    var currentImage: Binding<UIImage?> {
        switch currentStep {
        case .faceCloseUp: return $faceCloseUp
        case .faceProfile: return $faceProfile
        case .fullBodyFront: return $fullBodyFront
        case .fullBodyBack: return $fullBodyBack
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.lg) {
                // Progress indicator
                progressIndicator

                // Step content
                stepContent

                Spacer()

                // Action buttons
                actionButtons
            }
            .padding(Theme.Spacing.screenPadding)
            .onAppear {
                if let step = startStep {
                    currentStep = step
                }
            }
            .background(Theme.Colors.groupedBackground)
            .navigationTitle("Subir Fotos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPrivacyNotice) {
                PrivacyNoticeView {
                    showPrivacyNotice = false
                }
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Text("Seleccionar Foto")
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            handleImageSelection(image)
                        }
                        showPhotoPicker = false
                        selectedPhotoItem = nil
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { image in
                    handleImageSelection(image)
                }
            }
            .alert("Analysis Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var progressIndicator: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(UploadStep.allCases, id: \.rawValue) { step in
                VStack(spacing: 4) {
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Theme.Colors.primary : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)

                    Text(step.title)
                        .font(.caption2)
                        .foregroundStyle(step.rawValue <= currentStep.rawValue ? Theme.Colors.primary : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var stepContent: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Icon
            Image(systemName: currentStep.icon)
                .font(.system(size: 60))
                .foregroundStyle(Theme.Colors.primary)

            // Title and description
            VStack(spacing: Theme.Spacing.xs) {
                Text(currentStep.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(currentStep.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Preview or placeholder
            if let image = currentImage.wrappedValue {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
                    .overlay {
                        if isAnalyzing {
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                                .fill(.black.opacity(0.5))
                                .overlay {
                                    VStack {
                                        ProgressView()
                                            .tint(.white)
                                        Text("Analizando...")
                                            .font(.caption)
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                    }
            } else {
                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
                    .overlay {
                        VStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "photo.badge.plus")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Sin foto seleccionada")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                showCamera = true
            } label: {
                Label("Tomar Foto", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
                    .primaryButtonStyle()
            }
            .disabled(isAnalyzing)

            Button {
                showPhotoPicker = true
            } label: {
                Label("Elegir de Biblioteca", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.primary)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            }
            .disabled(isAnalyzing)

            if currentImage.wrappedValue != nil {
                Button {
                    moveToNextStep()
                } label: {
                    Text("Continuar")
                        .frame(maxWidth: .infinity)
                        .primaryButtonStyle()
                }
                .disabled(isAnalyzing)
            }
        }
    }

    private func handleImageSelection(_ image: UIImage?) {
        guard let image = image else { return }
        currentImage.wrappedValue = image
    }

    private func moveToNextStep() {
        if currentStep == .fullBodyBack {
            // All photos taken, run analysis
            Task {
                await analyzePhotos()
            }
        } else if let nextStep = UploadStep(rawValue: currentStep.rawValue + 1) {
            withAnimation {
                currentStep = nextStep
            }
        }
    }

    private func analyzePhotos() async {
        guard let face = faceCloseUp else {
            errorMessage = "Se requiere foto de primer plano del rostro"
            return
        }

        isAnalyzing = true

        do {
            // Extract skin tone from face photo
            let analysisResult = try await photoAnalysisService.extractSkinTone(from: face)

            // Generate palette
            let skinToneExtractor = SkinToneExtractor()
            let palette = skinToneExtractor.generatePalette(
                undertone: analysisResult.undertone,
                skinTone: analysisResult.skinToneCategory
            )

            // Update user profile
            await MainActor.run {
                if let user = appState.currentUser {
                    user.skinAnalysis = analysisResult
                    user.personalPalette = palette
                    user.profilePhotos = ProfilePhotos(
                        faceCloseUp: faceCloseUp,
                        faceProfile: faceProfile,
                        fullBodyFront: fullBodyFront,
                        fullBodyBack: fullBodyBack
                    )
                }

                isAnalyzing = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error en el analisis: \(error.localizedDescription)"
                isAnalyzing = false
            }
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
            parent.onImageCaptured(image)
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onImageCaptured(nil)
            parent.dismiss()
        }
    }
}

