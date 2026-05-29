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
    @State private var hasAcceptedPrivacy = false
    @State private var pendingPhotoInput: PhotoInputSource?
    @State private var didLoadExisting = false

    var startStep: UploadStep?

    init(startStep: UploadStep? = nil) {
        self.startStep = startStep
    }
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var cropItem: CropItem?
    @State private var pendingCameraImage: UIImage?

    private let photoAnalysisService = PhotoAnalysisService()
    private let paletteService = PaletteGenerationService()

    private var isSpanish: Bool {
        appState.preferredLanguage == .spanish
    }

    enum UploadStep: Int, CaseIterable {
        case faceCloseUp = 0
        case faceProfile = 1
        case fullBodyFront = 2
        case fullBodyBack = 3

        var icon: String {
            switch self {
            case .faceCloseUp: return "face.smiling"
            case .faceProfile: return "face.dashed"
            case .fullBodyFront: return "figure.stand"
            case .fullBodyBack: return "figure.stand.line.dotted.figure.stand"
            }
        }
    }

    private enum PhotoInputSource {
        case camera
        case library
    }

    var currentImage: Binding<UIImage?> {
        switch currentStep {
        case .faceCloseUp: return $faceCloseUp
        case .faceProfile: return $faceProfile
        case .fullBodyFront: return $fullBodyFront
        case .fullBodyBack: return $fullBodyBack
        }
    }

    /// Square crop for face shots, portrait for full-body shots.
    private var cropAspectRatio: CGFloat {
        switch currentStep {
        case .faceCloseUp, .faceProfile: return 1
        case .fullBodyFront, .fullBodyBack: return 3.0 / 4.0
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.lg) {
                progressIndicator
                stepContent
                Spacer()
                actionButtons
            }
            .padding(Theme.Spacing.screenPadding)
            .onAppear(perform: loadExistingIfNeeded)
            .background(Theme.Colors.groupedBackground)
            .navigationTitle(isSpanish ? "Subir fotos" : "Upload Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isSpanish ? "Hecho" : "Done") {
                        dismiss()
                    }
                }
            }
            // Present the picker/camera only after the privacy sheet has fully dismissed to avoid
            // a present-while-dismissing crash.
            .sheet(isPresented: $showPrivacyNotice, onDismiss: openPendingInputIfAccepted) {
                PrivacyNoticeView {
                    hasAcceptedPrivacy = true
                    showPrivacyNotice = false
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .fullScreenCover(isPresented: $showCamera, onDismiss: presentCropForCapturedImage) {
                CameraView { image in
                    pendingCameraImage = image
                }
            }
            .fullScreenCover(item: $cropItem) { item in
                PhotoCropView(image: item.image, aspectRatio: cropAspectRatio, isSpanish: isSpanish) { cropped in
                    applyCrop(cropped)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    let data = try? await newItem.loadTransferable(type: Data.self)
                    await MainActor.run {
                        selectedPhotoItem = nil
                        // By the time the transfer resolves the picker has dismissed, so presenting
                        // the crop cover here is safe.
                        if let data, let image = UIImage(data: data) {
                            cropItem = CropItem(image: image)
                        }
                    }
                }
            }
            .alert(isSpanish ? "Error de análisis" : "Analysis Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .animation(.snappy(duration: 0.25), value: currentStep.rawValue)
            .sensoryFeedback(.success, trigger: currentStep.rawValue)
        }
    }

    private var progressIndicator: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(UploadStep.allCases, id: \.rawValue) { step in
                VStack(spacing: 4) {
                    Circle()
                        .fill(circleColor(for: step))
                        .frame(width: 10, height: 10)
                        .overlay {
                            if image(for: step) != nil {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }

                    Text(title(for: step))
                        .font(.caption2)
                        .foregroundStyle(step.rawValue <= currentStep.rawValue ? Theme.Colors.primary : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func circleColor(for step: UploadStep) -> Color {
        if image(for: step) != nil { return .green }
        return step.rawValue <= currentStep.rawValue ? Theme.Colors.primary : Color.gray.opacity(0.3)
    }

    private var stepContent: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: currentStep.icon)
                .font(.system(size: 60))
                .foregroundStyle(Theme.Colors.primary)
                .symbolEffect(.bounce, value: currentStep.rawValue)

            VStack(spacing: Theme.Spacing.xs) {
                Text(title(for: currentStep))
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(description(for: currentStep))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let image = currentImage.wrappedValue {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
                    .transition(.scale(scale: 0.98).combined(with: .opacity))
                    .overlay {
                        if isAnalyzing {
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                                .fill(.black.opacity(0.5))
                                .overlay {
                                    VStack {
                                        ProgressView()
                                            .tint(.white)
                                        Text(isSpanish ? "Analizando..." : "Analyzing...")
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
                            Text(isSpanish ? "Sin foto seleccionada" : "No photo selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .transition(.opacity)
            }
        }
        .id(currentStep.rawValue)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private var actionButtons: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                startPhotoInput(.camera)
            } label: {
                Label(isSpanish ? "Tomar foto" : "Take Photo", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
                    .primaryButtonStyle()
            }
            .disabled(isAnalyzing)
            .buttonStyle(.premiumPressable)

            Button {
                startPhotoInput(.library)
            } label: {
                Label(isSpanish ? "Elegir de la biblioteca" : "Choose from Library", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.primary)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            }
            .disabled(isAnalyzing)
            .buttonStyle(.premiumPressable)

            if currentImage.wrappedValue != nil {
                Button {
                    moveToNextStep()
                } label: {
                    Text(currentStep == .fullBodyBack
                         ? (isSpanish ? "Finalizar y analizar" : "Finish & analyze")
                         : (isSpanish ? "Continuar" : "Continue"))
                        .frame(maxWidth: .infinity)
                        .primaryButtonStyle()
                }
                .disabled(isAnalyzing)
                .buttonStyle(.premiumPressable)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Photo input

    private func startPhotoInput(_ source: PhotoInputSource) {
        guard hasAcceptedPrivacy else {
            pendingPhotoInput = source
            showPrivacyNotice = true
            return
        }
        openPhotoInput(source)
    }

    private func openPhotoInput(_ source: PhotoInputSource) {
        switch source {
        case .camera:
            showCamera = true
        case .library:
            showPhotoPicker = true
        }
    }

    private func openPendingInputIfAccepted() {
        let source = pendingPhotoInput
        pendingPhotoInput = nil
        if hasAcceptedPrivacy, let source {
            openPhotoInput(source)
        }
    }

    private func presentCropForCapturedImage() {
        if let image = pendingCameraImage {
            pendingCameraImage = nil
            cropItem = CropItem(image: image)
        }
    }

    private func applyCrop(_ image: UIImage) {
        let normalized = StorageBudgetManager.normalizedImage(image) ?? image
        withAnimation(.snappy(duration: 0.22)) {
            currentImage.wrappedValue = normalized
        }
        persistPhotos()
    }

    // MARK: - Persistence

    private func loadExistingIfNeeded() {
        if let step = startStep {
            currentStep = step
        }

        guard !didLoadExisting else { return }
        didLoadExisting = true

        if let photos = appState.currentUser?.profilePhotos {
            faceCloseUp = photos.faceCloseUp
            faceProfile = photos.faceProfile
            fullBodyFront = photos.fullBodyFront
            fullBodyBack = photos.fullBodyBack
        }
    }

    /// Saves whatever photos exist so far, so the user keeps their progress if they exit.
    private func persistPhotos() {
        guard let user = appState.currentUser else { return }
        user.profilePhotos = ProfilePhotos(
            faceCloseUp: faceCloseUp,
            faceProfile: faceProfile,
            fullBodyFront: fullBodyFront,
            fullBodyBack: fullBodyBack
        )
        user.updatedAt = Date()
        try? modelContext.save()
        appState.updateUser(user)
    }

    private func moveToNextStep() {
        if currentStep == .fullBodyBack {
            Task { await analyzePhotos() }
        } else if let nextStep = UploadStep(rawValue: currentStep.rawValue + 1) {
            withAnimation {
                currentStep = nextStep
            }
        }
    }

    private func analyzePhotos() async {
        guard let face = faceCloseUp else {
            errorMessage = isSpanish ? "Se requiere una foto de primer plano del rostro." : "A close-up face photo is required."
            return
        }

        isAnalyzing = true

        // Photos are already persisted progressively during cropping, but make sure the latest
        // state is saved before we attempt the (heavier) palette analysis.
        persistPhotos()

        // Analysis never throws now: it falls back to the central region of the photo when Vision
        // can't find a face, so we always produce a palette instead of failing the whole flow.
        let analysisResult = (try? await photoAnalysisService.extractSkinTone(from: face))
            ?? SkinAnalysisResult(dominantColors: [], undertone: .neutral, undertoneConfidence: 0.5, skinToneCategory: .medium)

        let palette = await paletteService.generatePalette(from: analysisResult, language: appState.preferredLanguage)

        guard let user = appState.currentUser else {
            errorMessage = isSpanish ? "No he encontrado tu perfil de usuario." : "I couldn't find your user profile."
            isAnalyzing = false
            return
        }

        // The palette and skin analysis are tiny JSON blobs — always save them. The photo bytes
        // were already accounted for when persisted, so no storage-budget gate is needed here.
        user.skinAnalysis = analysisResult
        user.personalPalette = palette
        user.updatedAt = Date()

        do {
            try modelContext.save()
            appState.updateUser(user)
            isAnalyzing = false
            dismiss()
        } catch {
            isAnalyzing = false
            errorMessage = isSpanish
                ? "No he podido guardar tu paleta: \(error.localizedDescription)"
                : "I couldn't save your palette: \(error.localizedDescription)"
        }
    }

    private func image(for step: UploadStep) -> UIImage? {
        switch step {
        case .faceCloseUp: return faceCloseUp
        case .faceProfile: return faceProfile
        case .fullBodyFront: return fullBodyFront
        case .fullBodyBack: return fullBodyBack
        }
    }

    private func title(for step: UploadStep) -> String {
        switch (step, isSpanish) {
        case (.faceCloseUp, true): return "Primer plano del rostro"
        case (.faceProfile, true): return "Perfil del rostro"
        case (.fullBodyFront, true): return "Cuerpo completo frontal"
        case (.fullBodyBack, true): return "Cuerpo completo posterior"
        case (.faceCloseUp, false): return "Face Close-Up"
        case (.faceProfile, false): return "Face Profile"
        case (.fullBodyFront, false): return "Full Body Front"
        case (.fullBodyBack, false): return "Full Body Back"
        }
    }

    private func description(for step: UploadStep) -> String {
        switch (step, isSpanish) {
        case (.faceCloseUp, true): return "Toma una foto clara de tu rostro de frente"
        case (.faceProfile, true): return "Toma una foto de tu rostro de perfil"
        case (.fullBodyFront, true): return "Toma una foto de cuerpo completo de frente"
        case (.fullBodyBack, true): return "Toma una foto de cuerpo completo de espalda"
        case (.faceCloseUp, false): return "Take a clear front-facing photo of your face"
        case (.faceProfile, false): return "Take a side profile photo of your face"
        case (.fullBodyFront, false): return "Take a full-body front photo"
        case (.fullBodyBack, false): return "Take a full-body back photo"
        }
    }
}

// MARK: - Crop

/// Wrapper so the crop screen can be presented via `.fullScreenCover(item:)`.
struct CropItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Pinch-to-zoom / pan crop screen. The garment-frame window defines the crop; "Accept" renders
/// exactly what's visible inside the frame to a new image.
struct PhotoCropView: View {
    let image: UIImage
    let aspectRatio: CGFloat   // width / height of the crop window
    let isSpanish: Bool
    let onCrop: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let cropSize = cropSize(in: geo.size)

            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cropSize.width, height: cropSize.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .frame(width: cropSize.width, height: cropSize.height)
                    .clipped()
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.white.opacity(0.9), lineWidth: 2)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in scale = min(max(1, lastScale * value), 6) }
                                .onEnded { _ in lastScale = scale },
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in lastOffset = offset }
                        )
                    )

                VStack {
                    HStack {
                        Text(isSpanish ? "Pellizca y arrastra para encuadrar" : "Pinch and drag to frame")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.top, 60)

                    Spacer()

                    HStack {
                        Button(isSpanish ? "Cancelar" : "Cancel") {
                            dismiss()
                        }
                        .font(.headline)
                        .foregroundStyle(.white)

                        Spacer()

                        Button(isSpanish ? "Aceptar" : "Accept") {
                            onCrop(croppedImage(cropSize: cropSize) ?? image)
                            dismiss()
                        }
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(.white, in: Capsule())
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private func cropSize(in available: CGSize) -> CGSize {
        let maxWidth = available.width - 32
        let maxHeight = available.height - 220
        var width = maxWidth
        var height = width / aspectRatio
        if height > maxHeight {
            height = maxHeight
            width = height * aspectRatio
        }
        return CGSize(width: max(80, width), height: max(80, height))
    }

    private func croppedImage(cropSize: CGSize) -> UIImage? {
        let normalized = image.normalizedUp()
        let imageSize = normalized.size
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }

        // Base fill scale (matches scaledToFill into the crop window), times the user's zoom.
        let fitScale = max(cropSize.width / imageSize.width, cropSize.height / imageSize.height)
        let total = fitScale * scale
        guard total > 0 else { return nil }

        let centerX = imageSize.width / 2
        let centerY = imageSize.height / 2
        let rect = CGRect(
            x: centerX + (-cropSize.width / 2 - offset.width) / total,
            y: centerY + (-cropSize.height / 2 - offset.height) / total,
            width: cropSize.width / total,
            height: cropSize.height / total
        ).intersection(CGRect(origin: .zero, size: imageSize))

        guard !rect.isNull, rect.width > 1, rect.height > 1 else { return nil }
        return normalized.cropped(to: rect)
    }
}

extension UIImage {
    /// Redraws the image with `.up` orientation so pixel cropping math is straightforward.
    func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
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
