import SwiftUI
import UIKit
import PhotosUI
import SwiftData

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
    @State private var showPaletteQuestionnaire = false
    @State private var pendingPreferences: PalettePreferences?
    @State private var showGenerationOverlay = false
    @State private var generatedPalette: PersonalPalette?

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
            .sheet(isPresented: $showPaletteQuestionnaire, onDismiss: startAnalysisIfPending) {
                PaletteQuestionnaireView(language: appState.preferredLanguage) { preferences in
                    // Defer the heavy analysis until the questionnaire sheet has fully dismissed, then
                    // present the premium generation overlay (avoids a present-while-dismiss clash).
                    pendingPreferences = preferences
                }
            }
            .fullScreenCover(isPresented: $showGenerationOverlay) {
                if let face = faceCloseUp {
                    PaletteGenerationOverlay(
                        selfie: face,
                        palette: generatedPalette,
                        language: appState.preferredLanguage,
                        onContinue: {
                            showGenerationOverlay = false
                            dismiss()
                        }
                    )
                }
            }
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

            // Shown until the photo is taken: once there's an image the checklist has done its job
            // and the preview deserves the space.
            if currentImage.wrappedValue == nil {
                shotChecklist
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

    private var shotChecklist: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label(
                isSpanish ? "Para que salga bien" : "For a good shot",
                systemImage: "checklist"
            )
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.Colors.primary)

            ForEach(tips(for: currentStep), id: \.self) { tip in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.primary.opacity(0.7))
                    Text(tip)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        .accessibilityElement(children: .combine)
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

    /// Merges the questionnaire color answers into the styling profile so chat + future palettes use them.
    private func persistColorPreferences(_ preferences: PalettePreferences) {
        guard !preferences.isEmpty, let user = appState.currentUser else { return }
        let language = appState.preferredLanguage
        var profile = user.personalStylingProfile

        let lovedNames = preferences.lovedChoices.map { $0.name(in: language) }
        let dislikedNames = preferences.dislikedChoices.map { $0.name(in: language) }

        profile.favoriteColors = Array(Set(profile.favoriteColors + lovedNames)).sorted()
        profile.avoidColors = Array(Set(profile.avoidColors + dislikedNames)).sorted()

        user.updateStylingProfile(profile)
    }

    private func moveToNextStep() {
        if currentStep == .fullBodyBack {
            // Ask a couple of quick color questions before analyzing, so the palette respects what
            // the user already knows looks good on them.
            showPaletteQuestionnaire = true
        } else if let nextStep = UploadStep(rawValue: currentStep.rawValue + 1) {
            withAnimation {
                currentStep = nextStep
            }
        }
    }

    /// Kicks off analysis after the questionnaire sheet has dismissed, presenting the premium overlay.
    private func startAnalysisIfPending() {
        guard let preferences = pendingPreferences else { return }
        pendingPreferences = nil

        guard faceCloseUp != nil else {
            errorMessage = isSpanish ? "Se requiere una foto de primer plano del rostro." : "A close-up face photo is required."
            return
        }

        generatedPalette = nil
        showGenerationOverlay = true
        Task { await analyzePhotos(preferences: preferences) }
    }

    private func analyzePhotos(preferences: PalettePreferences) async {
        guard let face = faceCloseUp else { return }

        // Photos are already persisted progressively during cropping, but make sure the latest
        // state is saved before we attempt the (heavier) palette analysis.
        persistPhotos()

        // Analysis never throws now: it falls back to the central region of the photo when Vision
        // can't find a face, so we always produce a palette instead of failing the whole flow.
        let analysisResult = (try? await photoAnalysisService.extractSkinTone(from: face))
            ?? SkinAnalysisResult(dominantColors: [], undertone: .neutral, undertoneConfidence: 0.5, skinToneCategory: .medium)

        let palette = await paletteService.generatePalette(
            from: analysisResult,
            language: appState.preferredLanguage,
            preferences: preferences
        )

        // Persist the reported color preferences into the styling profile so the chat stylist and
        // future palette regenerations keep honoring them.
        persistColorPreferences(preferences)

        guard let user = appState.currentUser else {
            showGenerationOverlay = false
            errorMessage = isSpanish ? "No he encontrado tu perfil de usuario." : "I couldn't find your user profile."
            return
        }

        // Auto-detect body silhouette (full-body photo), face shape (close-up) and personal
        // contrast, and fold them into the styling profile so the stylist tailors fit + necklines.
        await applyImageAnalysis(to: user, analysis: analysisResult)

        // The palette and skin analysis are tiny JSON blobs — always save them. The photo bytes
        // were already accounted for when persisted, so no storage-budget gate is needed here.
        user.skinAnalysis = analysisResult
        user.personalPalette = palette
        user.updatedAt = Date()

        do {
            try modelContext.save()
            appState.updateUser(user)
            // Hand the finished palette to the overlay, which plays the reveal and then dismisses.
            withAnimation { generatedPalette = palette }
        } catch {
            showGenerationOverlay = false
            errorMessage = isSpanish
                ? "No he podido guardar tu paleta: \(error.localizedDescription)"
                : "I couldn't save your palette: \(error.localizedDescription)"
        }
    }

    /// Runs the Vision-based image analyses and stores the results on the user's styling profile.
    private func applyImageAnalysis(to user: User, analysis: SkinAnalysisResult) async {
        var profile = user.personalStylingProfile

        if let face = faceCloseUp, let faceShape = await FaceShapeAnalyzer.detectFaceShape(from: face) {
            profile.faceShape = faceShape
        }

        if let body = fullBodyFront, let bodyShape = await BodyShapeAnalyzer.detectBodyShape(from: body) {
            profile.bodyShape = bodyShape
        } else if let measured = ImageConsulting.bodyShape(chestCm: profile.chestCm, waistCm: profile.waistCm, hipsCm: profile.hipsCm) {
            profile.bodyShape = measured
        }

        if let contrast = analysis.contrast {
            profile.contrastLevel = ContrastLevel.from(contrast: contrast)
        }

        user.updateStylingProfile(profile)
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
        case (.faceCloseUp, true): return "Con luz natural y sin gafas ni filtros: de aquí sale tu paleta de color."
        case (.faceProfile, true): return "Gira la cabeza 90º. Sirve para leer la forma de tu rostro."
        case (.fullBodyFront, true): return "Esta es la foto que usa el probador virtual: cuanto mejor sea, mejor te queda la ropa."
        case (.fullBodyBack, true): return "De espalda, misma pose y mismo sitio que la anterior."
        case (.faceCloseUp, false): return "Natural light, no glasses or filters — this is what your color palette comes from."
        case (.faceProfile, false): return "Turn your head 90°. This is what reads your face shape."
        case (.fullBodyFront, false): return "This is the photo the virtual try-on uses — the better it is, the better clothes look on you."
        case (.fullBodyBack, false): return "Facing away, same pose and same spot as the previous one."
        }
    }

    /// Concrete shot requirements per step.
    ///
    /// The full-body front photo is the input the virtual try-on composites garments onto, so its
    /// quality caps the quality of every try-on result: a cropped, cluttered or baggy-clothing shot
    /// gives the model no reliable silhouette to work with. Spelling the requirements out here is
    /// far cheaper than trying to rescue a bad photo downstream.
    private func tips(for step: UploadStep) -> [String] {
        switch (step, isSpanish) {
        case (.faceCloseUp, true):
            return [
                "Luz de día, de frente — nada de contraluz",
                "Sin maquillaje fuerte, gafas ni filtros",
                "Rostro centrado, hombros visibles",
                "Fondo liso y pelo retirado de la cara"
            ]
        case (.faceProfile, true):
            return [
                "Perfil completo, mirando de lado",
                "Misma luz y mismo fondo que la anterior",
                "Oreja y línea de la mandíbula visibles"
            ]
        case (.fullBodyFront, true):
            return [
                "De la cabeza a los pies, sin recortar (zapatos incluidos)",
                "Ropa ajustada: se tiene que ver tu silueta",
                "Brazos algo separados del cuerpo y de frente a la cámara",
                "Fondo liso y despejado, tú sola/o en la foto",
                "Luz uniforme, sin sombras duras ni contraluz",
                "Móvil en vertical, a la altura del pecho y a 2-3 m"
            ]
        case (.fullBodyBack, true):
            return [
                "Mismo sitio, misma luz y misma distancia que la frontal",
                "De la cabeza a los pies, de espaldas y recta/o",
                "Brazos algo separados del cuerpo"
            ]
        case (.faceCloseUp, false):
            return [
                "Daylight from the front — no backlighting",
                "No heavy makeup, glasses or filters",
                "Face centered, shoulders in frame",
                "Plain background, hair off your face"
            ]
        case (.faceProfile, false):
            return [
                "Full side profile, looking sideways",
                "Same light and background as the previous shot",
                "Ear and jawline visible"
            ]
        case (.fullBodyFront, false):
            return [
                "Head to toe, nothing cropped (shoes included)",
                "Fitted clothing so your silhouette reads clearly",
                "Arms slightly away from your body, facing the camera",
                "Plain, uncluttered background — just you in frame",
                "Even light, no harsh shadows or backlighting",
                "Phone vertical, at chest height, 2-3 m away"
            ]
        case (.fullBodyBack, false):
            return [
                "Same spot, light and distance as the front shot",
                "Head to toe, facing away, standing straight",
                "Arms slightly away from your body"
            ]
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
