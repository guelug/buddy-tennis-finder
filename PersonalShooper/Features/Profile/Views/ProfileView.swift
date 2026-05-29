import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showingPhotoUpload = false
    @State private var showingLanguagePicker = false
    @State private var editingPhotoStep: PhotoUploadView.UploadStep = .faceCloseUp

    private var lang: Language {
        appState.preferredLanguage
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.sectionSpacing) {
                    HStack {
                        Text(text("Perfil", "Profile"))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Spacer()
                    }

                    profileHeaderSection
                    stylingProfileSection
                    photoUploadSection
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
        }
    }

    private var profileHeaderSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primaryGradient)
                    .frame(width: 100, height: 100)

                if let user = appState.currentUser {
                    Text(user.displayName.prefix(2).uppercased())
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "person.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                }
            }

            Text(appState.currentUser?.displayName ?? text("Invitado", "Guest"))
                .font(.title2)
                .fontWeight(.semibold)

            if let occupation = appState.currentUser?.personalStylingProfile.occupation,
               !occupation.isEmpty {
                Text(occupation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            HStack(spacing: 8) {
                if appState.isPremium {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)
                        Text(text("Premium", "Premium"))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow.opacity(0.1))
                    .clipShape(Capsule())
                }

                HStack(spacing: 4) {
                    Image(systemName: "cabinet.fill")
                    Text(appState.closetItemLimitDescription(language: lang))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.Colors.primary.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.xl))
    }

    private var stylingProfileSection: some View {
        let profile = appState.currentUser?.personalStylingProfile ?? PersonalStylingProfile()

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lang == .spanish ? "Perfil de estilismo" : "Styling Profile")
                        .font(.headline)
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
                }

                Spacer()

                Text("\(Int(profile.completionRatio * 100))%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.primary)
            }

            ProgressView(value: profile.completionRatio)
                .tint(Theme.Colors.primary)

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
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
        .animation(.snappy(duration: 0.24), value: profile.completionRatio)
    }

    private var photoUploadSection: some View {
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(text("Tus fotos", "Your Photos"))
                .font(.headline)

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
                Text(text("Todas las fotos están subidas. Tu paleta personal está lista.", "All photos uploaded! Your personal palette is ready."))
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.top, Theme.Spacing.xs)
            } else {
                Text(text("Sube 4 fotos para analizar tu paleta personal de color.", "Upload 4 photos to analyze your personal color palette"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
    }

    private var settingsSection: some View {
        VStack(spacing: 0) {
            NavigationLink {
                EditProfileView()
            } label: {
                SettingsRowContent(icon: "person.fill", title: text("Editar perfil", "Edit Profile"), color: .blue)
            }
            .buttonStyle(.premiumPressable)

            Divider().padding(.leading, 52)

            if let palette = appState.currentUser?.personalPalette {
                NavigationLink {
                    ColorPaletteDetailView(palette: palette)
                } label: {
                    SettingsRowContent(icon: "paintpalette.fill", title: text("Mi paleta de color", "My Color Palette"), color: .orange)
                }
                .buttonStyle(.premiumPressable)
            } else {
                NavigationLink {
                    Text(text("Todavía no tienes una paleta. Sube fotos para generarla.", "No palette available. Upload photos to generate one."))
                        .navigationTitle(text("Mi paleta", "My Palette"))
                } label: {
                    SettingsRowContent(icon: "paintpalette.fill", title: text("Mi paleta de color", "My Color Palette"), color: .orange)
                }
                .buttonStyle(.premiumPressable)
            }

            Divider().padding(.leading, 52)

            Button {
                showingLanguagePicker = true
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "globe")
                        .font(.body)
                        .foregroundStyle(.green)
                        .frame(width: 24)
                    Text(text("Idioma", "Language"))
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(appState.preferredLanguage.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(Theme.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.premiumPressable)

            Divider().padding(.leading, 52)

            NavigationLink {
                PrivacySettingsView()
            } label: {
                SettingsRowContent(icon: "lock.shield.fill", title: text("Privacidad", "Privacy"), color: .red)
            }
            .buttonStyle(.premiumPressable)
        }
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
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
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(title)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(Theme.Spacing.md)
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
            .background(Theme.Colors.cardBackground)
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
            VStack(spacing: Theme.Spacing.lg) {
                Text(isSpanish ? "Tu paleta personal" : "Your Personal Palette")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                VStack(spacing: Theme.Spacing.md) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text(palette.seasonalType.displayName)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.primary.opacity(0.1))
                            .clipShape(Capsule())

                        Text(palette.undertone.displayName)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.primary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                Text(isSpanish ? "Colores recomendados" : "Recommended Colors")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: Theme.Spacing.sm) {
                    ForEach(palette.recommendedColors) { color in
                        Circle()
                            .fill(color.color)
                            .frame(width: 50, height: 50)
                            .overlay {
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            }
                            .shadow(color: .black.opacity(0.1), radius: 2)
                    }
                }
                .padding()
            }
            .padding()
        }
        .background(Theme.Colors.groupedBackground.ignoresSafeArea())
        .navigationTitle(isSpanish ? "Mi paleta" : "My Palette")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
