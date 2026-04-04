import SwiftUI
import UIKit
import Vision

struct ClothingCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var frontImage: UIImage?
    @State private var backImage: UIImage?
    @State private var currentStep: CaptureStep = .front
    @State private var isAnalyzing = false
    @State private var detectedCategory: ClothingCategory?
    @State private var detectedColors: [String] = []
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var photoPickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var itemName = ""
    @State private var errorMessage: String?

    private let classificationService = ClothingClassificationService()

    private var lang: Language {
        appState.preferredLanguage
    }

    enum CaptureStep {
        case front
        case back
        case details

        var title: String {
            switch self {
            case .front: return "Foto frontal"
            case .back: return "Foto trasera (opcional)"
            case .details: return "Detalles"
            }
        }

        var description: String {
            switch self {
            case .front: return "Extiende la prenda y toma una foto de frente"
            case .back: return "Toma una foto de la parte trasera o salta este paso"
            case .details: return "Revisa los detalles detectados"
            }
        }

        var icon: String {
            switch self {
            case .front: return "camera.viewfinder"
            case .back: return "camera.viewfinder"
            case .details: return "checkmark.circle"
            }
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
            .background(Theme.Colors.groupedBackground)
            .navigationTitle("Añadir Prenda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                ClothingCameraView { image in
                    handleImageCapture(image)
                }
            }
            .sheet(isPresented: $showPhotoPicker) {
                ImagePicker(sourceType: photoPickerSource) { image in
                    handleImageSelection(image)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var progressIndicator: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach([CaptureStep.front, .back, .details], id: \.title) { step in
                VStack(spacing: 4) {
                    Circle()
                        .fill(stepOrder(step) <= stepOrder(currentStep) ? Theme.Colors.primary : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)

                    Text(step.title)
                        .font(.caption2)
                        .foregroundStyle(stepOrder(step) <= stepOrder(currentStep) ? Theme.Colors.primary : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func stepOrder(_ step: CaptureStep) -> Int {
        switch step {
        case .front: return 1
        case .back: return 2
        case .details: return 3
        }
    }

    private var stepContent: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: currentStep.icon)
                .font(.system(size: 60))
                .foregroundStyle(Theme.Colors.primary)

            VStack(spacing: Theme.Spacing.xs) {
                Text(currentStep.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(currentStep.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Image preview or placeholder
            imagePreview
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        let currentImage = currentStep == .front ? frontImage : (currentStep == .back ? backImage : frontImage)

        if let image = currentImage {
            VStack(spacing: Theme.Spacing.sm) {
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

                if currentStep == .details, let category = detectedCategory {
                    VStack(spacing: Theme.Spacing.xs) {
                        Text("Categoría detectada:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Image(systemName: category.icon)
                            Text(Strings.categoryDisplayName(category, lang))
                        }
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.Colors.primary.opacity(0.1))
                        .clipShape(Capsule())
                    }

                    if !detectedColors.isEmpty {
                        Text("Colores: \(detectedColors.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                        Text("Sin foto")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                photoPickerSource = .camera
                showCamera = true
            } label: {
                Label("Tomar Foto", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
                    .primaryButtonStyle()
            }

            Button {
                photoPickerSource = .photoLibrary
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

            if currentStep == .front && frontImage != nil {
                Button {
                    moveToNextStep()
                } label: {
                    Text("Continuar")
                        .frame(maxWidth: .infinity)
                        .primaryButtonStyle()
                }
            }

            if currentStep == .back {
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        skipBackPhoto()
                    } label: {
                        Text("Saltar")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                    }

                    if backImage != nil {
                        Button {
                            moveToNextStep()
                        } label: {
                            Text("Continuar")
                                .frame(maxWidth: .infinity)
                                .primaryButtonStyle()
                        }
                    }
                }
            }

            if currentStep == .details {
                Button {
                    saveItem()
                } label: {
                    Text("Guardar")
                        .frame(maxWidth: .infinity)
                        .primaryButtonStyle()
                }
                .disabled(itemName.isEmpty)
            }
        }
    }

    private func handleImageCapture(_ image: UIImage?) {
        guard let image = image else { return }
        let compressed = compressImage(image)
        assignImage(compressed)
        showCamera = false
    }

    private func handleImageSelection(_ image: UIImage?) {
        guard let image = image else { return }
        showPhotoPicker = false
        let compressed = compressImage(image)
        assignImage(compressed)
    }

    private func assignImage(_ image: UIImage) {
        switch currentStep {
        case .front:
            frontImage = image
        case .back:
            backImage = image
        case .details:
            break
        }
    }

    private func compressImage(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 800
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)

        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()

        return resized
    }

    private func moveToNextStep() {
        if currentStep == .front {
            currentStep = .back
        } else if currentStep == .back {
            Task {
                await analyzeClothing()
            }
        }
    }

    private func skipBackPhoto() {
        backImage = nil
        Task {
            await analyzeClothing()
        }
    }

    private func analyzeClothing() async {
        guard let image = frontImage else { return }

        await MainActor.run {
            isAnalyzing = true
            currentStep = .details
        }

        do {
            let result = try await classificationService.classifyClothing(image: image)

            await MainActor.run {
                detectedCategory = result.category
                detectedColors = result.colors
                isAnalyzing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error al analizar la imagen: \(error.localizedDescription)"
                detectedCategory = .tops
                isAnalyzing = false
            }
        }
    }

    private func saveItem() {
        guard let image = frontImage else { return }

        let item = ClothingItem(
            name: itemName.isEmpty ? "Prenda sin nombre" : itemName,
            category: detectedCategory ?? .tops,
            image: image,
            colorTags: detectedColors
        )

        modelContext.insert(item)
        dismiss()
    }
}

struct ClothingCameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ClothingCameraView

        init(_ parent: ClothingCameraView) {
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

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImageSelected: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageSelected: (UIImage?) -> Void

        init(onImageSelected: @escaping (UIImage?) -> Void) {
            self.onImageSelected = onImageSelected
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
            onImageSelected(image)
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImageSelected(nil)
            picker.dismiss(animated: true)
        }
    }
}
