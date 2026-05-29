import SwiftUI
import SwiftData
import UIKit
import Vision

struct ClothingCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Query private var items: [ClothingItem]

    @State private var frontImage: UIImage?
    @State private var backImage: UIImage?
    @State private var currentStep: CaptureStep = .front
    @State private var isAnalyzing = false
    @State private var isPreparingImage = false
    @State private var detectedCategory: ClothingCategory?
    @State private var detectedColors: [String] = []
    @State private var detectedStyleTags: [String] = []
    @State private var detectedMaterialTags: [String] = []
    @State private var detectedOccasionTags: [String] = []
    @State private var detectedDetailTags: [String] = []
    @State private var detectedSummary: String = ""
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var photoPickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var itemName = ""
    @State private var brandName = ""
    @State private var itemNotes = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: DetailField?

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

    private enum DetailField: Hashable {
        case name
        case brand
        case notes
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        progressIndicator
                        stepContent
                    }
                    .padding(Theme.Spacing.screenPadding)
                    .padding(.bottom, 120)
                }
                .scrollDismissesKeyboard(.interactively)
                .background {
                    Theme.Colors.groupedBackground
                        .ignoresSafeArea()
                        .onTapGesture {
                            dismissKeyboard()
                        }
                }
                .onChange(of: focusedField) { _, field in
                    guard let field else { return }
                    withAnimation(.snappy(duration: 0.24)) {
                        proxy.scrollTo(field, anchor: .center)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    actionButtons
                        .padding(.horizontal, Theme.Spacing.screenPadding)
                        .padding(.top, Theme.Spacing.sm)
                        .padding(.bottom, Theme.Spacing.sm)
                        .background(.regularMaterial)
                }
            }
            .navigationTitle(text("Añadir prenda", "Add Garment"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(text("Cancelar", "Cancel")) {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button {
                        dismissKeyboard()
                    } label: {
                        Label(text("Ocultar", "Hide"), systemImage: "keyboard.chevron.compact.down")
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
            .alert(text("Error", "Error"), isPresented: .constant(errorMessage != nil)) {
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

                    Text(stepTitle(step))
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
                Text(stepTitle(currentStep))
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(stepDescription(currentStep))
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
                        if isAnalyzing || isPreparingImage {
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                                .fill(.black.opacity(0.5))
                                .overlay {
                                    VStack {
                                        ProgressView()
                                            .tint(.white)
                                        Text(isPreparingImage ? text("Quitando fondo...", "Removing background...") : text("Analizando...", "Analyzing..."))
                                            .font(.caption)
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                    }

                if currentStep == .details, detectedCategory != nil {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(text("Categoría", "Category"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Picker(text("Categoría", "Category"), selection: Binding(
                                get: { detectedCategory ?? .tops },
                                set: { detectedCategory = $0 }
                            )) {
                                ForEach(ClothingCategory.allCases, id: \.self) { category in
                                    Label(Strings.categoryDisplayName(category, lang), systemImage: category.icon)
                                        .tag(category)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(text("Nombre", "Name"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField(text("Ej. Blazer azul marino", "Example: Navy blazer"), text: $itemName)
                                .textInputAutocapitalization(.words)
                                .submitLabel(.next)
                                .focused($focusedField, equals: .name)
                                .onSubmit { focusedField = .brand }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                        }
                        .id(DetailField.name)

                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(text("Marca (opcional)", "Brand (optional)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField(text("Ej. COS, Zara, vintage", "Example: COS, Zara, vintage"), text: $brandName)
                                .textInputAutocapitalization(.words)
                                .submitLabel(.next)
                                .focused($focusedField, equals: .brand)
                                .onSubmit { focusedField = .notes }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                        }
                        .id(DetailField.brand)

                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(text("Notas (opcional)", "Notes (optional)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField(text("Ej. va bien con pantalón negro", "Example: works with black trousers"), text: $itemNotes, axis: .vertical)
                                .lineLimit(2...4)
                                .focused($focusedField, equals: .notes)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                        }
                        .id(DetailField.notes)

                        if !detectedSummary.isEmpty {
                            Text(detectedSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        tagSection(title: text("Colores", "Colors"), tags: detectedColors)
                        tagSection(title: text("Estilo", "Style"), tags: detectedStyleTags)
                        tagSection(title: text("Materiales", "Materials"), tags: detectedMaterialTags)
                        tagSection(title: text("Ocasiones", "Occasions"), tags: detectedOccasionTags)
                        tagSection(title: text("Detalles", "Details"), tags: detectedDetailTags)
                    }
                }
            }
        } else {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                .fill(Color.gray.opacity(0.1))
                .frame(height: 200)
                .overlay {
                    VStack(spacing: Theme.Spacing.sm) {
                        if isPreparingImage {
                            ProgressView()
                            Text(text("Quitando fondo...", "Removing background..."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "photo.badge.plus")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text(text("Sin foto", "No photo"))
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
                photoPickerSource = .camera
                showCamera = true
            } label: {
                Label(text("Tomar foto", "Take Photo"), systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
                    .primaryButtonStyle()
            }

            Button {
                photoPickerSource = .photoLibrary
                showPhotoPicker = true
            } label: {
                Label(text("Elegir de la biblioteca", "Choose from Library"), systemImage: "photo.on.rectangle")
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
                    Text(text("Continuar", "Continue"))
                        .frame(maxWidth: .infinity)
                        .primaryButtonStyle()
                }
            }

            if currentStep == .back {
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        skipBackPhoto()
                    } label: {
                        Text(text("Saltar", "Skip"))
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
                            Text(text("Continuar", "Continue"))
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
                    Text(text("Guardar", "Save"))
                        .frame(maxWidth: .infinity)
                        .primaryButtonStyle()
                }
                .disabled(itemName.isEmpty)
            }
        }
        .disabled(isPreparingImage || isAnalyzing)
    }

    @ViewBuilder
    private func tagSection(title: String, tags: [String]) -> some View {
        if !tags.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                FlexibleTagLayout(tags: tags)
            }
        }
    }

    private func text(_ spanish: String, _ english: String) -> String {
        lang == .spanish ? spanish : english
    }

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func stepTitle(_ step: CaptureStep) -> String {
        switch step {
        case .front:
            return text("Foto frontal", "Front photo")
        case .back:
            return text("Foto trasera (opcional)", "Back photo (optional)")
        case .details:
            return text("Detalles", "Details")
        }
    }

    private func stepDescription(_ step: CaptureStep) -> String {
        switch step {
        case .front:
            return text("Extiende la prenda y toma una foto de frente", "Lay the garment flat and take a front photo")
        case .back:
            return text("Toma una foto de la parte trasera o salta este paso", "Take a photo of the back or skip this step")
        case .details:
            return text("Revisa los detalles detectados", "Review the detected details")
        }
    }

    private func handleImageCapture(_ image: UIImage?) {
        guard let image = image else { return }
        showCamera = false
        let step = currentStep
        let compressed = compressImage(image)
        assignImage(compressed, for: step)
        Task {
            await prepareImage(compressed, for: step)
        }
    }

    private func handleImageSelection(_ image: UIImage?) {
        guard let image = image else { return }
        showPhotoPicker = false
        let step = currentStep
        let compressed = compressImage(image)
        assignImage(compressed, for: step)
        Task {
            await prepareImage(compressed, for: step)
        }
    }

    private func assignImage(_ image: UIImage, for step: CaptureStep? = nil) {
        switch step ?? currentStep {
        case .front:
            frontImage = image
        case .back:
            backImage = image
        case .details:
            break
        }
    }

    private func compressImage(_ image: UIImage) -> UIImage {
        StorageBudgetManager.normalizedClothingImage(image)
            ?? StorageBudgetManager.normalizedImage(image)
            ?? image
    }

    private func prepareImage(_ image: UIImage, for step: CaptureStep) async {
        await MainActor.run {
            isPreparingImage = true
        }

        let preparedImage = await GarmentBackgroundRemovalService.prepareImage(image)

        await MainActor.run {
            assignImage(preparedImage, for: step)
            isPreparingImage = false
        }
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
            let result = try await classificationService.classifyClothing(image: image, prepareForAnalysis: false)

            await MainActor.run {
                detectedCategory = result.category
                detectedColors = result.colors
                detectedStyleTags = result.styleTags
                detectedMaterialTags = result.materialTags
                detectedOccasionTags = result.occasionTags
                detectedDetailTags = result.detailTags
                detectedSummary = result.summary
                if itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    itemName = result.suggestedName
                }
                isAnalyzing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error al analizar la imagen: \(error.localizedDescription)"
                detectedCategory = .tops
                detectedColors = []
                detectedStyleTags = []
                detectedMaterialTags = []
                detectedOccasionTags = []
                detectedDetailTags = []
                detectedSummary = ""
                isAnalyzing = false
            }
        }
    }

    private func saveItem() {
        guard let image = frontImage else { return }

        if appState.hasReachedClosetLimit(currentCount: items.count) {
            errorMessage = lang == .spanish
                ? "Has alcanzado el límite gratuito de \(AppState.freeClosetItemLimit) prendas. Pásate a Premium para guardar prendas ilimitadas."
                : "You've reached the free limit of \(AppState.freeClosetItemLimit) garments. Upgrade to Premium for unlimited closet items."
            return
        }

        let additionalBytes = StorageBudgetManager.incrementalBytesForClothingItem(
            name: itemName.isEmpty ? "Prenda sin nombre" : itemName,
            category: detectedCategory ?? .tops,
            image: image,
            colorTags: detectedColors,
            styleTags: detectedStyleTags,
            materialTags: detectedMaterialTags,
            occasionTags: detectedOccasionTags,
            detailTags: detectedDetailTags,
            brandName: brandName.nilIfBlank,
            notes: itemNotes.nilIfBlank,
            metadataSummary: detectedSummary.nilIfBlank
        )

        guard StorageBudgetManager.canStore(additionalBytes: additionalBytes, modelContext: modelContext) else {
            errorMessage = StorageBudgetManager.overflowMessage(
                language: lang,
                modelContext: modelContext,
                additionalBytes: additionalBytes
            )
            return
        }

        let item = ClothingItem(
            name: itemName.isEmpty ? "Prenda sin nombre" : itemName,
            category: detectedCategory ?? .tops,
            image: image,
            colorTags: detectedColors,
            styleTags: detectedStyleTags,
            materialTags: detectedMaterialTags,
            occasionTags: detectedOccasionTags,
            detailTags: detectedDetailTags,
            brandName: brandName.nilIfBlank,
            notes: itemNotes.nilIfBlank,
            metadataSummary: detectedSummary.nilIfBlank
        )

        modelContext.insert(item)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.delete(item)
            errorMessage = lang == .spanish
                ? "No he podido guardar la prenda: \(error.localizedDescription)"
                : "I couldn't save the garment: \(error.localizedDescription)"
        }
    }
}

private struct FlexibleTagLayout: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
