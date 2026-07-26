import SwiftUI
import PhotosUI
import SwiftData

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var showingPhotoUpload = false
    @State private var showingLanguagePicker = false
    @State private var editingPhotoStep: PhotoUploadView.UploadStep = .faceCloseUp
    @State private var isGeneratingPalette = false
    @State private var paletteMessage: String?
    @State private var showPaletteQuestionnaire = false
    @State private var pendingPreferences: PalettePreferences?
    @State private var showGenerationOverlay = false
    @State private var generatedPalette: PersonalPalette?
    private let photoAnalysisService = PhotoAnalysisService()
    private let paletteService = PaletteGenerationService()

    private var lang: Language {
        appState.preferredLanguage
    }

    /// True when there is a face photo we can analyze (whether or not a palette already exists).
    private var hasFacePhoto: Bool {
        appState.currentUser?.profilePhotos.faceCloseUp != nil
    }

    /// True when a palette already exists — the button becomes a "redo with my answers" action.
    private var hasPalette: Bool {
        appState.currentUser?.personalPalette != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.sectionSpacing) {
                    profileHeroSection
                    stylingProfileSection
                    photoUploadSection
                    appearanceSection
                    settingsSection
                }
                .padding(Theme.Spacing.screenPadding)
                .padding(.top, Theme.Spacing.xs)
            }
            .background(Theme.Colors.groupedBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingPhotoUpload) {
                PhotoUploadView(startStep: editingPhotoStep)
            }
            .sheet(isPresented: $showPaletteQuestionnaire, onDismiss: startGenerationIfPending) {
                PaletteQuestionnaireView(language: lang, initial: savedColorPreferences) { preferences in
                    pendingPreferences = preferences
                }
            }
            .fullScreenCover(isPresented: $showGenerationOverlay) {
                if let face = appState.currentUser?.profilePhotos.faceCloseUp {
                    PaletteGenerationOverlay(
                        selfie: face,
                        palette: generatedPalette,
                        language: lang,
                        onContinue: { showGenerationOverlay = false }
                    )
                }
            }
        }
    }

    /// Starts generation after the questionnaire sheet dismisses, presenting the premium overlay.
    private func startGenerationIfPending() {
        guard let preferences = pendingPreferences else { return }
        pendingPreferences = nil
        guard appState.currentUser?.profilePhotos.faceCloseUp != nil else { return }
        generatedPalette = nil
        showGenerationOverlay = true
        Task { await generatePalette(preferences: preferences) }
    }

    /// Pre-fills the questionnaire with any color preferences already saved in the styling profile.
    private var savedColorPreferences: PalettePreferences {
        guard let profile = appState.currentUser?.personalStylingProfile else { return PalettePreferences() }
        func ids(matching names: [String]) -> [String] {
            let lowered = Set(names.map { $0.lowercased() })
            return PaletteColorCatalog.all
                .filter { lowered.contains($0.nameEn.lowercased()) || lowered.contains($0.nameEs.lowercased()) }
                .map { $0.id }
        }
        return PalettePreferences(
            lovedColorIDs: ids(matching: profile.favoriteColors),
            dislikedColorIDs: ids(matching: profile.avoidColors)
        )
    }

    // MARK: - Hero

    private var profileHeroSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .stroke(Theme.Colors.primaryGradient, lineWidth: 3)
                    .frame(width: 108, height: 108)

                if let face = appState.currentUser?.profilePhotos.faceCloseUp {
                    Image(uiImage: face)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Theme.Colors.primaryGradient)
                        .frame(width: 96, height: 96)
                        .overlay {
                            if let user = appState.currentUser {
                                Text(user.displayName.prefix(2).uppercased())
                                    .font(.fashionDisplay(34))
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.white)
                            }
                        }
                }
            }
            .padding(.top, Theme.Spacing.xs)

            VStack(spacing: 4) {
                Text(appState.currentUser?.displayName ?? text("Invitado", "Guest"))
                    .font(.fashionDisplay(28, weight: .semibold))

                if let occupation = appState.currentUser?.personalStylingProfile.occupation,
                   !occupation.isEmpty {
                    Text(occupation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }

            HStack(spacing: 8) {
                heroPill(icon: "cabinet.fill", text: appState.closetItemLimitDescription(language: lang))
                if let palette = appState.currentUser?.personalPalette {
                    heroPill(icon: "paintpalette.fill", text: palette.seasonalType.displayName)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
        .fashionGlassCard(cornerRadius: Theme.CornerRadius.xl)
    }

    private func heroPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.Colors.primary.opacity(0.1))
        .foregroundStyle(Theme.Colors.primary)
        .clipShape(Capsule())
    }

    // MARK: - Styling profile

    private var stylingProfileSection: some View {
        let profile = appState.currentUser?.personalStylingProfile ?? PersonalStylingProfile()

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                CompletionRing(progress: profile.completionRatio, tint: Theme.Colors.primary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(lang == .spanish ? "Perfil de estilismo" : "Styling Profile")
                        .font(.fashionHeadline)
                    Text(
                        profile.isCompleteEnough
                            ? (lang == .spanish
                                ? "El chat ya usa este contexto para personalizar recomendaciones."
                                : "Chat already uses this context to personalize recommendations.")
                            : (lang == .spanish
                                ? "Completa estos datos opcionales para recibir consejos más finos."
                                : "Complete these optional details for sharper advice.")
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if !profile.highlightTags(in: lang).isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Theme.Spacing.xs)], spacing: Theme.Spacing.xs) {
                    ForEach(profile.highlightTags(in: lang), id: \.self) { tag in
                        Text(tag)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemBackground))
                            .clipShape(Capsule())
                            .transition(.scale(scale: 0.96).combined(with: .opacity))
                    }
                }
            } else if let nextQuestion = profile.nextQuestion(in: lang) {
                Text(nextQuestion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding(Theme.Spacing.md)
        .fashionGlassCard()
        .animation(.snappy(duration: 0.24), value: profile.completionRatio)
    }

    // MARK: - Photos

    private var photoUploadSection: some View {
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(text("Tus fotos", "Your Photos"))
                .font(.fashionTitle)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Theme.Spacing.sm) {
                PhotoThumbnail(
                    title: text("Primer plano", "Close-up"),
                    icon: "face.smiling",
                    image: appState.currentUser?.profilePhotos.faceCloseUp,
                    isUploaded: appState.currentUser?.profilePhotos.faceCloseUp != nil
                ) {
                    editingPhotoStep = .faceCloseUp
                    showingPhotoUpload = true
                }

                PhotoThumbnail(
                    title: text("Perfil lateral", "Profile"),
                    icon: "face.dashed",
                    image: appState.currentUser?.profilePhotos.faceProfile,
                    isUploaded: appState.currentUser?.profilePhotos.faceProfile != nil
                ) {
                    editingPhotoStep = .faceProfile
                    showingPhotoUpload = true
                }

                PhotoThumbnail(
                    title: text("Cuerpo frontal", "Body Front"),
                    icon: "figure.stand",
                    image: appState.currentUser?.profilePhotos.fullBodyFront,
                    isUploaded: appState.currentUser?.profilePhotos.fullBodyFront != nil
                ) {
                    editingPhotoStep = .fullBodyFront
                    showingPhotoUpload = true
                }

                PhotoThumbnail(
                    title: text("Cuerpo trasero", "Body Back"),
                    icon: "figure.stand.line.dotted.figure.stand",
                    image: appState.currentUser?.profilePhotos.fullBodyBack,
                    isUploaded: appState.currentUser?.profilePhotos.fullBodyBack != nil
                ) {
                    editingPhotoStep = .fullBodyBack
                    showingPhotoUpload = true
                }
            }

            if appState.currentUser?.profilePhotos.allPhotosUploaded == true {
                Label(
                    text("Todas las fotos están subidas. Tu paleta personal está lista.", "All photos uploaded! Your personal palette is ready."),
                    systemImage: "checkmark.seal.fill"
                )
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.top, Theme.Spacing.xs)
            } else {
                Text(text("Sube 4 fotos para analizar tu paleta personal de color.", "Upload 4 photos to analyze your personal color palette"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, Theme.Spacing.xs)
            }

            if hasFacePhoto {
                Button {
                    showPaletteQuestionnaire = true
                } label: {
                    HStack(spacing: 8) {
                        if isGeneratingPalette {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "paintpalette.fill")
                        }
                        Text(isGeneratingPalette
                             ? text("Analizando...", "Analyzing...")
                             : (hasPalette
                                ? text("Rehacer mi paleta con mis colores", "Redo my palette with my colors")
                                : text("Generar mi paleta de color", "Generate my color palette")))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                    .contentShape(Rectangle())
                }
                .disabled(isGeneratingPalette)
                .buttonStyle(.premiumPressable)
                .padding(.top, Theme.Spacing.xs)
            }

            if let paletteMessage {
                Text(paletteMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.Spacing.md)
        .fashionGlassCard()
    }

    /// Generates the palette from the already-saved face photo, so the user doesn't have to
    /// re-upload if the analysis didn't run during the original upload flow.
    private func generatePalette(preferences: PalettePreferences) async {
        guard let user = appState.currentUser,
              let face = user.profilePhotos.faceCloseUp else { return }

        isGeneratingPalette = true
        defer { isGeneratingPalette = false }

        let analysis = (try? await photoAnalysisService.extractSkinTone(from: face))
            ?? SkinAnalysisResult(dominantColors: [], undertone: .neutral, undertoneConfidence: 0.5, skinToneCategory: .medium)
        let palette = await paletteService.generatePalette(from: analysis, language: lang, preferences: preferences)

        // Save the reported preferences into the styling profile so they persist for chat + reruns.
        var profile = user.personalStylingProfile
        if !preferences.isEmpty {
            profile.favoriteColors = Array(Set(profile.favoriteColors + preferences.lovedChoices.map { $0.name(in: lang) })).sorted()
            profile.avoidColors = Array(Set(profile.avoidColors + preferences.dislikedChoices.map { $0.name(in: lang) })).sorted()
        }

        // Auto-detect face shape, body silhouette and personal contrast from saved photos.
        if let faceShape = await FaceShapeAnalyzer.detectFaceShape(from: face) {
            profile.faceShape = faceShape
        }
        if let body = user.profilePhotos.fullBodyFront, let bodyShape = await BodyShapeAnalyzer.detectBodyShape(from: body) {
            profile.bodyShape = bodyShape
        } else if let measured = ImageConsulting.bodyShape(chestCm: profile.chestCm, waistCm: profile.waistCm, hipsCm: profile.hipsCm) {
            profile.bodyShape = measured
        }
        if let contrast = analysis.contrast {
            profile.contrastLevel = ContrastLevel.from(contrast: contrast)
        }
        user.updateStylingProfile(profile)

        user.skinAnalysis = analysis
        user.personalPalette = palette
        user.updatedAt = Date()

        do {
            try modelContext.save()
            appState.updateUser(user)
            paletteMessage = text("Tu paleta personal está lista.", "Your personal palette is ready.")
            // Trigger the premium reveal in the overlay.
            withAnimation { generatedPalette = palette }
        } catch {
            showGenerationOverlay = false
            paletteMessage = text("No he podido guardar la paleta.", "I couldn't save the palette.")
        }
    }

    // MARK: - Appearance (accent themes)

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(text("Apariencia", "Appearance"))
                .font(.fashionTitle)

            Text(text("Elige el color de tu atelier. Toda la app se tiñe al instante.",
                      "Pick your atelier color. The whole app re-tints instantly."))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: Theme.Spacing.md) {
                ForEach(AccentTheme.allCases) { theme in
                    Button {
                        withAnimation(.smooth(duration: 0.3)) {
                            ThemeManager.shared.accent = theme
                        }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(theme.gradient)
                                    .frame(width: 36, height: 36)
                                    .shadow(color: theme.color.opacity(0.4), radius: 4, y: 2)

                                if ThemeManager.shared.accent == theme {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .overlay {
                                if ThemeManager.shared.accent == theme {
                                    Circle()
                                        .stroke(theme.color, lineWidth: 2)
                                        .frame(width: 44, height: 44)
                                }
                            }

                            Text(theme.displayName(lang))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(ThemeManager.shared.accent == theme ? .primary : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.premiumPressable)
                    .sensoryFeedback(.selection, trigger: ThemeManager.shared.accent)
                }
            }
            .padding(.top, Theme.Spacing.xs)
        }
        .padding(Theme.Spacing.md)
        .fashionGlassCard()
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 0) {
            NavigationLink {
                EditProfileView()
            } label: {
                SettingsRowContent(
                    icon: "person.fill",
                    title: text("Editar perfil", "Edit Profile"),
                    subtitle: text("Nombre, medidas y estilo de vida", "Name, measurements and lifestyle"),
                    color: .blue
                )
            }
            .buttonStyle(.premiumPressable)

            Divider().padding(.leading, 64)

            if let palette = appState.currentUser?.personalPalette {
                NavigationLink {
                    ColorPaletteDetailView(palette: palette)
                } label: {
                    SettingsRowContent(
                        icon: "paintpalette.fill",
                        title: text("Mi paleta de color", "My Color Palette"),
                        subtitle: text("Tu estación y los colores que te favorecen", "Your season and most flattering colors"),
                        color: .orange
                    )
                }
                .buttonStyle(.premiumPressable)
            } else {
                NavigationLink {
                    Text(text("Todavía no tienes una paleta. Sube fotos para generarla.", "No palette available. Upload photos to generate one."))
                        .navigationTitle(text("Mi paleta", "My Palette"))
                } label: {
                    SettingsRowContent(
                        icon: "paintpalette.fill",
                        title: text("Mi paleta de color", "My Color Palette"),
                        subtitle: text("Tu estación y los colores que te favorecen", "Your season and most flattering colors"),
                        color: .orange
                    )
                }
                .buttonStyle(.premiumPressable)
            }

            if let user = appState.currentUser, user.personalPalette != nil {
                Divider().padding(.leading, 64)

                NavigationLink {
                    StyleAnalysisView(user: user)
                } label: {
                    SettingsRowContent(
                        icon: "person.crop.rectangle.badge.magnifyingglass",
                        title: text("Mi análisis de imagen", "My Image Analysis"),
                        subtitle: text("Rostro, silueta y contraste personal", "Face, silhouette and personal contrast"),
                        color: .purple
                    )
                }
                .buttonStyle(.premiumPressable)

                Divider().padding(.leading, 64)

                NavigationLink {
                    CapsuleWardrobeView()
                } label: {
                    SettingsRowContent(
                        icon: "square.stack.3d.up.fill",
                        title: text("Mi armario cápsula", "My Capsule Wardrobe"),
                        subtitle: text("Básicos que combinan entre sí", "Essentials that mix and match"),
                        color: .pink
                    )
                }
                .buttonStyle(.premiumPressable)
            }

            Divider().padding(.leading, 64)

            Button {
                showingLanguagePicker = true
            } label: {
                SettingsRowContent(
                    icon: "globe",
                    title: text("Idioma", "Language"),
                    subtitle: text("La app y tu estilista hablan como tú", "The app and your stylist speak your language"),
                    value: appState.preferredLanguage.displayName,
                    color: .green
                )
            }
            .buttonStyle(.premiumPressable)

            Divider().padding(.leading, 64)

            NavigationLink {
                PrivacySettingsView()
            } label: {
                SettingsRowContent(
                    icon: "lock.shield.fill",
                    title: text("Privacidad", "Privacy"),
                    subtitle: text("Tus fotos nunca salen de tu iPhone", "Your photos never leave your iPhone"),
                    color: .red
                )
            }
            .buttonStyle(.premiumPressable)
        }
        .fashionGlassCard()
        .confirmationDialog(text("Selecciona idioma", "Select Language"), isPresented: $showingLanguagePicker) {
            ForEach(Language.allCases) { language in
                Button(language.displayName) {
                    appState.setLanguage(language)
                }
            }
            Button(text("Cancelar", "Cancel"), role: .cancel) {}
        }
    }

    private func text(_ spanish: String, _ english: String) -> String {
        lang == .spanish ? spanish : english
    }
}

struct SettingsRowContent: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let value, !value.isEmpty {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct PhotoThumbnail: View {
    let title: String
    let icon: String
    let image: UIImage?
    let isUploaded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.xs) {
                ZStack {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundStyle(.gray)
                            }
                    }

                    if isUploaded {
                        Circle()
                            .fill(.green)
                            .frame(width: 20, height: 20)
                            .overlay {
                                Image(systemName: "checkmark")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                            .offset(x: 20, y: 20)
                    }
                }

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.sm)
            .background(Color(.systemBackground).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        }
        .buttonStyle(.premiumPressable)
    }
}

struct ColorPaletteDetailView: View {
    @Environment(AppState.self) private var appState
    let palette: PersonalPalette

    private var isSpanish: Bool {
        appState.preferredLanguage == .spanish
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text(isSpanish ? "Tu paleta personal" : "Your Personal Palette")
                    .font(.fashionDisplay(30))
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: Theme.Spacing.sm) {
                    tag(palette.seasonalType.displayName)
                    tag(isSpanish ? "Subtono \(palette.undertone.displayName)" : "\(palette.undertone.displayName) undertone")
                }

                if let summary = palette.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(Theme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fashionGlassCard(cornerRadius: Theme.CornerRadius.medium)
                }

                swatchSection(
                    title: isSpanish ? "Tus mejores colores" : "Your best colors",
                    subtitle: isSpanish ? "Lúcelos cerca del rostro" : "Wear these near your face",
                    colors: palette.recommendedColors
                )

                if let neutrals = palette.neutralColors, !neutrals.isEmpty {
                    swatchSection(
                        title: isSpanish ? "Neutros versátiles" : "Versatile neutrals",
                        subtitle: isSpanish ? "Base para combinar todo" : "Mix-and-match basics",
                        colors: neutrals
                    )
                }

                if let statements = palette.statementColors, !statements.isEmpty {
                    swatchSection(
                        title: isSpanish ? "Colores statement" : "Statement colors",
                        subtitle: isSpanish ? "Para destacar con intención" : "For a bold, intentional pop",
                        colors: statements
                    )
                }

                if let avoid = palette.colorsToAvoid, !avoid.isEmpty {
                    swatchSection(
                        title: isSpanish ? "Colores a evitar" : "Colors to avoid",
                        subtitle: isSpanish ? "Tienden a apagarte cerca del rostro" : "These tend to wash you out",
                        colors: avoid
                    )
                }
            }
            .padding()
        }
        .background(Theme.Colors.groupedBackground.ignoresSafeArea())
        .navigationTitle(isSpanish ? "Mi paleta" : "My Palette")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.Colors.primary.opacity(0.1))
            .foregroundStyle(Theme.Colors.primary)
            .clipShape(Capsule())
    }

    private func swatchSection(title: String, subtitle: String, colors: [CodableColor]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.fashionHeadline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: Theme.Spacing.sm)], spacing: Theme.Spacing.md) {
                ForEach(colors) { color in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .fill(color.color)
                            .frame(height: 56)
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            }
                            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)

                        if let name = color.name, !name.isEmpty {
                            Text(name)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fashionGlassCard()
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
