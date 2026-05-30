import PhotosUI
import SwiftData
import SwiftUI

struct TryOnView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var closetItems: [ClothingItem]

    @State private var viewModel = TryOnViewModel()
    @State private var showingSubscription = false
    @State private var showingPrivacyNotice = false
    @State private var hasAcceptedPrivacy = false
    @State private var showingImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .camera
    @State private var pendingImagePickerSource: UIImagePickerController.SourceType?
    @State private var showingDownloadSuccess = false
    @State private var photoSaveErrorMessage: String?
    @State private var showingProviderPicker = false
    @State private var showingClosetPicker = false
    @State private var resultRevealProgress: CGFloat = 1

    private var lang: Language {
        appState.preferredLanguage
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.lg) {
                if let generatedImage = viewModel.generatedImage {
                    resultView(generatedImage)
                        .transition(.scale(scale: 0.98).combined(with: .opacity))
                } else if viewModel.isGenerating {
                    processingView
                        .transition(.opacity)
                } else if viewModel.selectedClothingImage == nil {
                    sourceSelectionView
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    garmentPreviewView
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.bottom, Theme.Spacing.md)
            .background(Theme.Colors.groupedBackground.ignoresSafeArea())
            .animation(.snappy(duration: 0.28), value: viewModel.generatedImage != nil)
            .animation(.snappy(duration: 0.28), value: viewModel.selectedClothingImage != nil)
            .sensoryFeedback(.success, trigger: viewModel.generatedImage != nil)
            .navigationTitle(Strings.tryOnTitle(lang))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingProviderPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.selectedProvider.iconName)
                            Text(viewModel.selectedProvider.displayName)
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.primary.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.premiumPressable)
                }
            }
            .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
            }
            .sheet(isPresented: $showingPrivacyNotice) {
                PrivacyNoticeView {
                    hasAcceptedPrivacy = true
                    showingPrivacyNotice = false
                    if let pendingImagePickerSource {
                        self.pendingImagePickerSource = nil
                        imagePickerSource = pendingImagePickerSource
                        showingImagePicker = true
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(sourceType: imagePickerSource) { image in
                    handleImageSelected(image)
                }
            }
            .sheet(isPresented: $showingProviderPicker) {
                ProviderPickerSheet(viewModel: viewModel, showingSubscription: $showingSubscription)
            }
            .sheet(isPresented: $showingClosetPicker) {
                ClosetPickerSheet(items: closetItems, language: lang) { item in
                    Task {
                        guard let image = item.displayImage else { return }
                        await viewModel.setSelectedClothingImage(image, source: .closet, closetItem: item)
                    }
                }
            }
            .alert(text("Imagen guardada", "Image saved"), isPresented: $showingDownloadSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(text("La imagen se ha guardado en Fotos.", "The image was saved to Photos."))
            }
            .alert(
                text("No se pudo guardar", "Couldn't save"),
                isPresented: Binding(
                    get: { photoSaveErrorMessage != nil },
                    set: { if !$0 { photoSaveErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    photoSaveErrorMessage = nil
                }
            } message: {
                Text(photoSaveErrorMessage ?? "")
            }
            .alert(
                text("No he podido continuar", "I couldn't continue"),
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
            .onChange(of: viewModel.isGenerating) { _, isGenerating in
                if isGenerating {
                    resultRevealProgress = 0.02
                }
            }
            .onChange(of: viewModel.generatedImage != nil) { _, hasImage in
                guard hasImage else {
                    resultRevealProgress = 0.02
                    return
                }

                resultRevealProgress = 0.02
                withAnimation(.easeInOut(duration: 1.1)) {
                    resultRevealProgress = 1
                }
            }
        }
    }

    private var sourceSelectionView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer(minLength: Theme.Spacing.lg)

                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(Theme.Colors.primary)

                    Text(text("Elige la prenda", "Choose the garment"))
                        .font(.title.weight(.bold))

                    Text(
                        text(
                            "Haz una foto de la prenda, selecciónala de la librería o usa una del armario. Tus fotos del perfil se usarán automáticamente como referencia.",
                            "Take a photo of the garment, pick it from your library, or use one from your closet. Your profile photos will be used automatically as the reference."
                        )
                    )
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
                }

                VStack(spacing: Theme.Spacing.sm) {
                    sourceButton(
                        title: text("Haz una foto de la prenda", "Take a garment photo"),
                        subtitle: text("Usa la cámara para capturar solo la prenda.", "Use the camera to capture the garment only."),
                        systemImage: "camera.fill"
                    ) {
                        startSourceSelection(.camera)
                    }

                    sourceButton(
                        title: text("Selecciona de la librería", "Choose from library"),
                        subtitle: text("Importa una prenda desde Fotos.", "Import a garment from Photos."),
                        systemImage: "photo.on.rectangle"
                    ) {
                        startSourceSelection(.photoLibrary)
                    }

                    sourceButton(
                        title: text("Elegir del armario", "Choose from closet"),
                        subtitle: text("Reutiliza una prenda que ya tienes guardada.", "Reuse a garment already saved in your closet."),
                        systemImage: "cabinet.fill"
                    ) {
                        showingClosetPicker = true
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)

                profileReferenceCard
            }
            .padding(.top, Theme.Spacing.md)
        }
    }

    private var garmentPreviewView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if let image = viewModel.selectedClothingImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
                        .padding(.horizontal, Theme.Spacing.lg)
                        .shadow(color: .black.opacity(0.08), radius: 10)
                }

                VStack(spacing: Theme.Spacing.sm) {
                    Text(
                        viewModel.selectedClothingName.isEmpty
                            ? text("Prenda lista", "Garment ready")
                            : viewModel.selectedClothingName
                    )
                    .font(.title2.weight(.semibold))

                    if let category = viewModel.selectedClothingCategory {
                        Text(Strings.categoryDisplayName(category, lang))
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.Colors.primary.opacity(0.1))
                            .foregroundStyle(Theme.Colors.primary)
                            .clipShape(Capsule())
                    }

                    if viewModel.isAnalyzingClothing {
                        ProgressView()
                            .padding(.top, 4)
                    }

                    Text(profileReferenceCopy)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                }

                VStack(spacing: Theme.Spacing.sm) {
                    Button {
                        Task {
                            await viewModel.generateTryOn(
                                for: appState.currentUser,
                                modelContext: modelContext,
                                language: lang,
                                canGenerateCleanReference: appState.isPremium || appState.hasBYOKAccess
                            )
                        }
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text(text("Generar look", "Generate look"))
                        }
                        .frame(maxWidth: .infinity)
                        .primaryButtonStyle()
                    }
                    .disabled(viewModel.isAnalyzingClothing)
                    .buttonStyle(.premiumPressable)

                    Button {
                        viewModel.resetSelection()
                    } label: {
                        Text(text("Cambiar prenda", "Change garment"))
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(Color.gray.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                    }
                    .buttonStyle(.premiumPressable)
                }
                .padding(.horizontal, Theme.Spacing.lg)

                profileReferenceCard
            }
            .padding(.top, Theme.Spacing.md)
        }
    }

    private var processingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            TryOnGenerationPlaceholderCard(language: lang)
                .padding(.horizontal, Theme.Spacing.lg)

            Text(Strings.tryOnProcessing(lang))
                .font(.title2)
                .fontWeight(.bold)

            Text(Strings.tryOnProcessingDesc(lang))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
        }
    }

    private func resultView(_ image: UIImage) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            VStack(spacing: Theme.Spacing.xs) {
                Text(Strings.tryOnResultTitle(lang))
                    .font(.title)
                    .fontWeight(.bold)

                if viewModel.lastResultWasCached {
                    Text(text("Mostrando tu resultado ya guardado para esta prenda.", "Showing your saved result for this garment."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            RevealTryOnResultView(
                image: image,
                progress: resultRevealProgress
            )
            .padding(.horizontal, Theme.Spacing.lg)

            VStack(spacing: Theme.Spacing.sm) {
                if let reference = viewModel.referenceDescription {
                    Label(reference, systemImage: "person.crop.rectangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: Theme.Spacing.md) {
                    Button {
                        saveToPhotos(image)
                    } label: {
                        Label(Strings.downloadToPhotos(lang), systemImage: "square.and.arrow.down.fill")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Theme.Colors.primary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.premiumPressable)

                    Button {
                        viewModel.resetSelection()
                    } label: {
                        Label(text("Nueva prenda", "New garment"), systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.2))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.premiumPressable)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()
        }
    }

    private var profileReferenceCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label(text("Referencia automática del perfil", "Automatic profile reference"), systemImage: "person.crop.rectangle.stack")
                .font(.headline)

            Text(profileReferenceCopy)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let user = appState.currentUser {
                let photos = user.profilePhotos

                HStack(spacing: Theme.Spacing.sm) {
                    referenceStatusChip(
                        title: text("Rostro", "Face"),
                        isReady: photos.faceCloseUp != nil || photos.faceProfile != nil
                    )
                    referenceStatusChip(
                        title: text("Cuerpo frontal", "Body front"),
                        isReady: photos.fullBodyFront != nil
                    )
                    referenceStatusChip(
                        title: text("Cuerpo trasero", "Body back"),
                        isReady: photos.fullBodyBack != nil
                    )
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private func sourceButton(title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(width: 42, height: 42)
                    .background(Theme.Colors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
        }
        .buttonStyle(.premiumPressable)
    }

    private func referenceStatusChip(title: String, isReady: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isReady ? "checkmark.circle.fill" : "minus.circle")
            Text(title)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(isReady ? Color.green : .secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .clipShape(Capsule())
    }

    private var profileReferenceCopy: String {
        if let category = viewModel.selectedClothingCategory, category == .accessories {
            return text(
                "Si la prenda afecta a la zona de la cara, usaré tus fotos de rostro del perfil.",
                "If the garment affects the face area, I'll use your face profile photos."
            )
        }

        return text(
            "Para prendas de cuerpo usaré tu foto frontal del perfil y, si la prenda lo necesita, también la trasera.",
            "For body garments I'll use your front profile photo and, when the garment needs it, the back one too."
        )
    }

    private func startSourceSelection(_ sourceType: UIImagePickerController.SourceType) {
        if !hasAcceptedPrivacy {
            pendingImagePickerSource = sourceType
            showingPrivacyNotice = true
            return
        }

        imagePickerSource = sourceType
        showingImagePicker = true
    }

    private func handleImageSelected(_ image: UIImage?) {
        guard let image else { return }

        Task {
            let source: TryOnSelectionSource = imagePickerSource == .camera ? .camera : .library
            await viewModel.setSelectedClothingImage(image, source: source)
        }
    }

    private func saveToPhotos(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            if status == .authorized || status == .limited {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                DispatchQueue.main.async {
                    showingDownloadSuccess = true
                }
            } else {
                DispatchQueue.main.async {
                    photoSaveErrorMessage = text(
                        "Activa el permiso para añadir fotos en Ajustes para poder guardar el resultado.",
                        "Enable add-only Photos access in Settings to save this result."
                    )
                }
            }
        }
    }

    private func text(_ spanish: String, _ english: String) -> String {
        lang == .spanish ? spanish : english
    }
}

private struct ClosetPickerSheet: View {
    let items: [ClothingItem]
    let language: Language
    let onSelect: (ClothingItem) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        language == .spanish ? "Armario vacío" : "Empty closet",
                        systemImage: "cabinet",
                        description: Text(language == .spanish ? "Guarda prendas en el armario para reutilizarlas en try-on." : "Save garments in your closet to reuse them in try-on.")
                    )
                } else {
                    List(items) { item in
                        Button {
                            onSelect(item)
                            dismiss()
                        } label: {
                            HStack(spacing: Theme.Spacing.md) {
                                if let image = item.displayImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 56, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                } else {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.15))
                                        .frame(width: 56, height: 72)
                                        .overlay {
                                            Image(systemName: item.category.icon)
                                                .foregroundStyle(.secondary)
                                        }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(Strings.categoryDisplayName(item.category, language))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.premiumPressable)
                    }
                }
            }
            .navigationTitle(language == .spanish ? "Elegir del armario" : "Choose from closet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(language == .spanish ? "Cerrar" : "Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct TryOnGenerationPlaceholderCard: View {
    let language: Language
    @State private var animateDots = false
    @State private var animateScan = false
    @State private var animateFloat = false

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.secondarySystemBackground),
                                Theme.Colors.primary.opacity(0.08),
                                Color(.secondarySystemBackground)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.white.opacity(0.55), lineWidth: 1)
                    }

                VStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.white.opacity(0.78))
                            .frame(height: 270)
                            .overlay(alignment: .top) {
                                GeometryReader { proxy in
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    .clear,
                                                    Theme.Colors.primary.opacity(0.20),
                                                    .white.opacity(0.55),
                                                    .clear
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(height: 84)
                                        .blur(radius: 4)
                                        .offset(y: animateScan ? proxy.size.height - 84 : -18)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }

                        VStack(spacing: 18) {
                            HStack(spacing: 10) {
                                ForEach(0..<3, id: \.self) { index in
                                    Circle()
                                        .fill(Theme.Colors.primary.opacity(index == 1 ? 0.95 : 0.45))
                                        .frame(width: 10, height: 10)
                                        .scaleEffect(animateDots ? (index == 1 ? 1.35 : 0.85) : 0.7)
                                        .offset(y: animateDots ? (index == 1 ? -4 : 4) : 0)
                                        .animation(
                                            .easeInOut(duration: 0.7)
                                                .repeatForever()
                                                .delay(Double(index) * 0.12),
                                            value: animateDots
                                        )
                                }
                            }

                            ZStack {
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .fill(Theme.Colors.primary.opacity(0.08))
                                    .frame(width: 160, height: 188)
                                    .overlay {
                                        Image(systemName: "person.crop.rectangle.stack")
                                            .font(.system(size: 48, weight: .medium))
                                            .foregroundStyle(Theme.Colors.primary.opacity(0.35))
                                    }

                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.white.opacity(0.92))
                                    .frame(width: 86, height: 118)
                                    .rotationEffect(.degrees(animateFloat ? 4 : -4))
                                    .offset(x: animateFloat ? 34 : 18, y: animateFloat ? 2 : -6)
                                    .overlay {
                                        Image(systemName: "tshirt.fill")
                                            .font(.system(size: 28, weight: .semibold))
                                            .foregroundStyle(Theme.Colors.primary)
                                    }
                                    .shadow(color: .black.opacity(0.08), radius: 14, y: 10)
                            }

                            HStack(spacing: 10) {
                                capsuleLine(width: 84)
                                capsuleLine(width: 48)
                                capsuleLine(width: 62)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(18)
            }
            .frame(maxWidth: 380)

            Text(
                language == .spanish
                    ? "Componiendo encaje, caída y luz"
                    : "Composing fit, drape, and light"
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .onAppear {
            animateDots = true
            animateFloat = true
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                animateScan = true
            }
        }
    }

    private func capsuleLine(width: CGFloat) -> some View {
        Capsule()
            .fill(Color.black.opacity(0.07))
            .frame(width: width, height: 10)
    }
}

private struct RevealTryOnResultView: View {
    let image: UIImage
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let clampedProgress = min(max(progress, 0.02), 1)

            ZStack(alignment: .top) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
                    .mask(alignment: .top) {
                        Rectangle()
                            .frame(height: proxy.size.height * clampedProgress)
                            .frame(maxHeight: .infinity, alignment: .top)
                    }

                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(0.58),
                                Theme.Colors.primary.opacity(0.18),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 40)
                    .blur(radius: 5)
                    .offset(y: max(proxy.size.height * clampedProgress - 20, 0))
                    .opacity(clampedProgress < 0.995 ? 1 : 0)
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                    .fill(Color.white.opacity(0.55))
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
            .shadow(color: .black.opacity(0.1), radius: 10)
        }
        .frame(height: 420)
    }
}

struct ProviderPickerSheet: View {
    @Bindable var viewModel: TryOnViewModel
    @Binding var showingSubscription: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    private var lang: Language {
        appState.preferredLanguage
    }

    private var availableProviders: [TryOnProvider] {
        TryOnProvider.allCases.filter { appState.isTryOnProviderAvailable($0) }
    }

    private var providerFooterText: String {
        if appState.hasBYOKAccess {
            return lang == .spanish ? "Google Gemini ofrece los resultados más precisos. Vista local es gratis y hace una composición rápida en el dispositivo. BYOK usa tu propia clave de OpenAI." : "Google Gemini provides the most accurate results. Local Preview is free and makes a quick on-device composition. BYOK uses your own OpenAI API key."
        } else {
            return lang == .spanish ? "Google Gemini ofrece los resultados más precisos. Vista local es gratis y hace una composición rápida en el dispositivo." : "Google Gemini provides the most accurate results. Local Preview is free and makes a quick on-device composition."
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(availableProviders) { provider in
                        ProviderRow(
                            provider: provider,
                            isSelected: viewModel.selectedProvider == provider,
                            isPremiumUser: appState.isPremium
                        ) {
                            if provider.requiresPremium && !appState.isPremium {
                                dismiss()
                                showingSubscription = true
                            } else {
                                viewModel.selectProvider(provider)
                                dismiss()
                            }
                        }
                    }
                } header: {
                    Text(lang == .spanish ? "Selecciona proveedor" : "Select Provider")
                } footer: {
                    Text(providerFooterText)
                }
            }
            .navigationTitle(lang == .spanish ? "Proveedor de try-on" : "Try-On Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lang == .spanish ? "Cerrar" : "Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ProviderRow: View {
    let provider: TryOnProvider
    let isSelected: Bool
    let isPremiumUser: Bool
    let action: () -> Void
    @Environment(AppState.self) private var appState

    private var lang: Language {
        appState.preferredLanguage
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: provider.iconName)
                    .font(.title2)
                    .foregroundStyle(providerColor)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(provider.displayName(language: lang))
                            .font(.body)
                            .foregroundStyle(.primary)

                        if provider.isFree {
                            Text(lang == .spanish ? "GRATIS" : "FREE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .clipShape(Capsule())
                        } else if provider.requiresPremium {
                            Text("PREMIUM")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple)
                                .clipShape(Capsule())
                        }
                    }

                    Text(provider.subtitle(language: lang))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.primary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var providerColor: Color {
        switch provider {
        case .google: return .blue
        case .playground: return .black
        case .chatgpt: return .purple
        }
    }
}

#Preview {
    TryOnView()
        .environment(AppState())
        .modelContainer(for: [User.self, ClothingItem.self, TryOnResult.self], inMemory: true)
}
