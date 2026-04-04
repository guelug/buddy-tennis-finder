import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var ageText: String = ""
    @State private var occupation: String = ""
    @State private var lifestyleSummary: String = ""
    @State private var selectedSocialPlans: [String] = []
    @State private var selectedStyles: [String] = []
    @State private var selectedImpressions: [String] = []
    @State private var selectedPriorities: [String] = []
    @State private var favoriteColorsText: String = ""
    @State private var avoidColorsText: String = ""
    @State private var styleGoals: String = ""
    @State private var shoppingChallenges: String = ""
    @State private var additionalNotes: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var errorMessage: String?

    private var lang: Language {
        appState.preferredLanguage
    }

    private var draftProfile: PersonalStylingProfile {
        PersonalStylingProfile(
            age: Int(ageText),
            occupation: occupation.trimmingCharacters(in: .whitespacesAndNewlines),
            lifestyleSummary: lifestyleSummary.trimmingCharacters(in: .whitespacesAndNewlines),
            usualSocialPlans: selectedSocialPlans,
            preferredStyles: selectedStyles,
            desiredImpression: selectedImpressions,
            fitPriorities: selectedPriorities,
            favoriteColors: parseTags(from: favoriteColorsText),
            avoidColors: parseTags(from: avoidColorsText),
            styleGoals: styleGoals.trimmingCharacters(in: .whitespacesAndNewlines),
            shoppingChallenges: shoppingChallenges.trimmingCharacters(in: .whitespacesAndNewlines),
            additionalNotes: additionalNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            lastUpdatedFromChatAt: appState.currentUser?.personalStylingProfile.lastUpdatedFromChatAt
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.sectionSpacing) {
                    profileHeroCard
                    completionCard
                    basicInfoCard
                    socialContextCard
                    styleIdentityCard
                    colorPreferencesCard
                    goalsCard
                    saveButton
                }
                .padding(Theme.Spacing.screenPadding)
            }
            .background(Theme.Colors.groupedBackground.ignoresSafeArea())
            .navigationTitle(text("Editar Perfil", "Edit Profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(text("Cancelar", "Cancel")) {
                        dismiss()
                    }
                }
            }
            .alert(text("No he podido guardar", "I couldn't save"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        profileImage = StorageBudgetManager.normalizedImage(image) ?? image
                    }
                }
            }
            .onAppear {
                loadCurrentUser()
            }
        }
    }

    private var profileHeroCard: some View {
        let changePhotoTitle = text("Cambiar foto", "Change photo")

        return ProfileSectionCard(
            title: text("Perfil personal", "Personal Profile"),
            subtitle: text(
                "Todo es opcional, pero este contexto mejora mucho la precisión del personal shooper.",
                "Everything is optional, but this context improves the stylist's recommendations."
            )
        ) {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.primaryGradient)
                        .frame(width: 88, height: 88)

                    if let profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 88, height: 88)
                            .clipShape(Circle())
                    } else {
                        Text(initials)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(displayName.isEmpty ? text("Tu identidad de estilo", "Your style identity") : displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(text(
                        "Añade señales útiles sobre rutina, eventos, prioridades y gustos personales.",
                        "Add useful signals about routine, events, priorities, and personal taste."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Text(changePhotoTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Colors.primary)
                    }
                }

                Spacer()
            }
        }
    }

    private var completionCard: some View {
        ProfileSectionCard(
            title: text("Contexto para recomendaciones", "Recommendation Context"),
            subtitle: text(
                "Cuanto más completo esté este bloque, más personales serán las respuestas del chat.",
                "The more complete this section is, the more personal the chat responses become."
            )
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ProgressView(value: draftProfile.completionRatio)
                    .tint(Theme.Colors.primary)

                HStack {
                    Text(text("Nivel de perfil", "Profile depth"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(completionLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                if let nextQuestion = draftProfile.nextQuestion(in: lang) {
                    Text(nextQuestion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var basicInfoCard: some View {
        ProfileSectionCard(
            title: text("Datos base", "Basics"),
            subtitle: text(
                "Estos datos orientan tono, referencias y contextos de vestimenta.",
                "These details help calibrate tone, references, and dress contexts."
            )
        ) {
            VStack(spacing: Theme.Spacing.md) {
                ProfileTextField(
                    title: text("Nombre", "Name"),
                    placeholder: text("Cómo quieres que te llamemos", "How you want us to call you"),
                    text: $displayName,
                    textContentType: .name
                )

                HStack(spacing: Theme.Spacing.md) {
                    ProfileTextField(
                        title: text("Edad", "Age"),
                        placeholder: text("Opcional", "Optional"),
                        text: $ageText,
                        keyboardType: .numberPad
                    )

                    ProfileTextField(
                        title: text("Trabajo", "Work"),
                        placeholder: text("Ej. consultora, creativa...", "Example: consultant, creative..."),
                        text: $occupation
                    )
                }
            }
        }
    }

    private var socialContextCard: some View {
        ProfileSectionCard(
            title: text("Rutina y vida social", "Routine and Social Life"),
            subtitle: text(
                "Esto nos ayuda a priorizar outfits útiles para tu realidad, no solo bonitos.",
                "This helps us prioritize outfits that are useful for your real life, not just pretty."
            )
        ) {
            VStack(spacing: Theme.Spacing.md) {
                ProfileEditor(
                    title: text("Tu día a día", "Your day to day"),
                    placeholder: text(
                        "Ej. trabajo entre oficina y calle, necesito looks cómodos pero pulidos.",
                        "Example: I split time between office and city, I need comfortable but polished looks."
                    ),
                    text: $lifestyleSummary,
                    minHeight: 92
                )

                OptionPickerSection(
                    title: text("Eventos o planes habituales", "Usual plans or events"),
                    options: StyleProfileCatalog.socialActivities,
                    selection: $selectedSocialPlans,
                    language: lang
                )
            }
        }
    }

    private var styleIdentityCard: some View {
        ProfileSectionCard(
            title: text("Identidad de estilo", "Style Identity"),
            subtitle: text(
                "Aquí recogemos psicología de imagen: cómo te sientes bien y cómo te gusta proyectarte.",
                "This captures image psychology: how you feel good and how you want to come across."
            )
        ) {
            VStack(spacing: Theme.Spacing.md) {
                OptionPickerSection(
                    title: text("Estilos con los que te identificas", "Styles that feel like you"),
                    options: StyleProfileCatalog.styleIdentities,
                    selection: $selectedStyles,
                    language: lang
                )

                OptionPickerSection(
                    title: text("Cómo te gusta proyectarte", "How you like to come across"),
                    options: StyleProfileCatalog.impressionGoals,
                    selection: $selectedImpressions,
                    language: lang
                )

                OptionPickerSection(
                    title: text("Qué priorizas al vestirte", "What you prioritize when dressing"),
                    options: StyleProfileCatalog.fitPriorities,
                    selection: $selectedPriorities,
                    language: lang
                )
            }
        }
    }

    private var colorPreferencesCard: some View {
        ProfileSectionCard(
            title: text("Gustos y límites", "Preferences and Limits"),
            subtitle: text(
                "El color óptimo lo deduciremos con fotos, pero aquí recogemos gustos personales y vetos útiles.",
                "The best colors will come from photos, but this captures personal taste and useful limits."
            )
        ) {
            VStack(spacing: Theme.Spacing.md) {
                ProfileTextField(
                    title: text("Colores que te apetecen", "Colors you enjoy"),
                    placeholder: text("Ej. azul marino, crema, oliva", "Example: navy, cream, olive"),
                    text: $favoriteColorsText
                )

                ProfileTextField(
                    title: text("Colores que sueles evitar", "Colors you usually avoid"),
                    placeholder: text("Ej. neón, fucsia, amarillo intenso", "Example: neon, fuchsia, strong yellow"),
                    text: $avoidColorsText
                )
            }
        }
    }

    private var goalsCard: some View {
        ProfileSectionCard(
            title: text("Objetivos y fricciones", "Goals and Friction"),
            subtitle: text(
                "Aquí vive lo más estratégico: qué quieres conseguir y qué te está frenando.",
                "This is the strategic layer: what you want to achieve and what is getting in the way."
            )
        ) {
            VStack(spacing: Theme.Spacing.md) {
                ProfileEditor(
                    title: text("Qué quieres mejorar", "What you want to improve"),
                    placeholder: text(
                        "Ej. verme más profesional, construir un armario versátil, vestir mejor en eventos.",
                        "Example: look more professional, build a versatile wardrobe, dress better for events."
                    ),
                    text: $styleGoals
                )

                ProfileEditor(
                    title: text("Qué te cuesta al comprar o combinar", "What feels hard when shopping or combining"),
                    placeholder: text(
                        "Ej. compro impulsivamente, me cuesta repetir prendas, no sé combinar colores.",
                        "Example: I buy impulsively, I struggle to repeat pieces, I don't know how to combine colors."
                    ),
                    text: $shoppingChallenges
                )

                ProfileEditor(
                    title: text("Detalles adicionales", "Additional notes"),
                    placeholder: text(
                        "Tallas, tejidos que evitas, clima habitual o cualquier señal que debamos respetar.",
                        "Sizing, fabrics you avoid, usual climate, or any signal we should respect."
                    ),
                    text: $additionalNotes
                )
            }
        }
    }

    private var saveButton: some View {
        Button {
            saveProfile()
        } label: {
            Text(text("Guardar cambios", "Save changes"))
                .frame(maxWidth: .infinity)
                .primaryButtonStyle()
        }
        .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .padding(.bottom, Theme.Spacing.lg)
    }

    private var completionLabel: String {
        switch draftProfile.completionRatio {
        case 0..<0.3:
            return text("Básico", "Basic")
        case 0.3..<0.7:
            return text("Útil", "Useful")
        default:
            return text("Muy completo", "Very complete")
        }
    }

    private var initials: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "PS"
        }

        let components = trimmed.split(separator: " ")
        let letters = components.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    private func loadCurrentUser() {
        guard let user = appState.currentUser else { return }
        let profile = user.personalStylingProfile

        displayName = user.displayName
        ageText = profile.age.map(String.init) ?? ""
        occupation = profile.occupation
        lifestyleSummary = profile.lifestyleSummary
        selectedSocialPlans = profile.usualSocialPlans
        selectedStyles = profile.preferredStyles
        selectedImpressions = profile.desiredImpression
        selectedPriorities = profile.fitPriorities
        favoriteColorsText = profile.favoriteColors.joined(separator: ", ")
        avoidColorsText = profile.avoidColors.joined(separator: ", ")
        styleGoals = profile.styleGoals
        shoppingChallenges = profile.shoppingChallenges
        additionalNotes = profile.additionalNotes
        profileImage = user.profilePhotos.faceCloseUp
    }

    private func saveProfile() {
        guard let user = appState.currentUser else { return }

        let updatedPhotos = ProfilePhotos(
            faceCloseUp: profileImage ?? user.profilePhotos.faceCloseUp,
            faceProfile: user.profilePhotos.faceProfile,
            fullBodyFront: user.profilePhotos.fullBodyFront,
            fullBodyBack: user.profilePhotos.fullBodyBack
        )

        let additionalBytes = StorageBudgetManager.incrementalBytesForProfileUpdate(
            currentUser: user,
            profilePhotos: updatedPhotos,
            skinAnalysis: user.skinAnalysis,
            personalPalette: user.personalPalette
        )

        guard StorageBudgetManager.canStore(additionalBytes: additionalBytes, modelContext: modelContext) else {
            errorMessage = StorageBudgetManager.overflowMessage(
                language: lang,
                modelContext: modelContext,
                additionalBytes: additionalBytes
            )
            return
        }

        user.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        user.updateStylingProfile(draftProfile)

        if let profileImage {
            user.profilePhotos = updatedPhotos
        }

        user.updatedAt = Date()
        try? modelContext.save()
        appState.updateUser(user)
        dismiss()
    }

    private func parseTags(from rawText: String) -> [String] {
        rawText
            .split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func text(_ spanish: String, _ english: String) -> String {
        lang == .spanish ? spanish : english
    }
}

private struct ProfileSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
    }
}

private struct ProfileTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .textContentType(textContentType)
                .keyboardType(keyboardType)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 14)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        }
    }
}

private struct ProfileEditor: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 108

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .fill(Color(.systemBackground))

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, 14)
                }

                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .frame(minHeight: minHeight)
                    .background(Color.clear)
            }
            .frame(minHeight: minHeight)
        }
    }
}

private struct OptionPickerSection: View {
    let title: String
    let options: [StyleProfileOption]
    @Binding var selection: [String]
    let language: Language

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: Theme.Spacing.xs)], spacing: Theme.Spacing.xs) {
                ForEach(options) { option in
                    Button {
                        toggle(option.id)
                    } label: {
                        Text(option.title(in: language))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(selection.contains(option.id) ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(selection.contains(option.id) ? Theme.Colors.primary : Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggle(_ id: String) {
        if let index = selection.firstIndex(of: id) {
            selection.remove(at: index)
        } else {
            selection.append(id)
        }
    }
}

#Preview {
    EditProfileView()
        .environment(AppState())
}
