import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var showingPhotoUpload = false
    @State private var showingPrivacyNotice = false
    @State private var showingSubscription = false
    @State private var selectedLanguage: Language = .english
    @State private var editingPhotoStep: PhotoUploadView.UploadStep = .faceCloseUp

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.sectionSpacing) {
                    profileHeaderSection

                    photoUploadSection

                    if let palette = appState.currentUser?.personalPalette {
                        colorPaletteSection(palette)
                    }

                    stylePreferencesSection

                    settingsSection
                }
                .padding(Theme.Spacing.screenPadding)
            }
            .background(Theme.Colors.groupedBackground.ignoresSafeArea())
            .navigationTitle("Profile")
            .sheet(isPresented: $showingPhotoUpload) {
                PhotoUploadView(startStep: editingPhotoStep)
            }
            .sheet(isPresented: $showingPrivacyNotice) {
                PrivacyNoticeView(onContinue: {
                    showingPrivacyNotice = false
                    showingPhotoUpload = true
                })
            }
            .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
            }
        }
    }

    private var profileHeaderSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Avatar
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Profile avatar")

            // Name
            Text(appState.currentUser?.displayName ?? "Guest User")
                .font(.title2)
                .fontWeight(.semibold)

            // Subscription badge
            if appState.isPremium {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                    Text("Premium Member")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.yellow.opacity(0.1))
                .clipShape(Capsule())
                .accessibilityLabel("Premium member badge")
            } else {
                Button {
                    showingSubscription = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "crown")
                        Text("Go Premium")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.primaryGradient)
                    .clipShape(Capsule())
                }
                .accessibilityLabel("Go Premium button")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.xl))
    }

    private var photoUploadSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Your Photos")
                    .font(.headline)

                Spacer()

                if let user = appState.currentUser {
                    Text("\(user.profilePhotos.uploadedCount)/4")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Theme.Spacing.sm) {
                PhotoThumbnail(
                    title: "Face Close-up",
                    icon: "face.smiling",
                    image: appState.currentUser?.profilePhotos.faceCloseUp,
                    isUploaded: appState.currentUser?.profilePhotos.faceCloseUp != nil
                ) {
                    editingPhotoStep = .faceCloseUp
                    showingPrivacyNotice = true
                }

                PhotoThumbnail(
                    title: "Face Profile",
                    icon: "face.dashed",
                    image: appState.currentUser?.profilePhotos.faceProfile,
                    isUploaded: appState.currentUser?.profilePhotos.faceProfile != nil
                ) {
                    editingPhotoStep = .faceProfile
                    showingPrivacyNotice = true
                }

                PhotoThumbnail(
                    title: "Body Front",
                    icon: "figure.stand",
                    image: appState.currentUser?.profilePhotos.fullBodyFront,
                    isUploaded: appState.currentUser?.profilePhotos.fullBodyFront != nil
                ) {
                    editingPhotoStep = .fullBodyFront
                    showingPrivacyNotice = true
                }

                PhotoThumbnail(
                    title: "Body Back",
                    icon: "figure.stand.line.dotted.figure.stand",
                    image: appState.currentUser?.profilePhotos.fullBodyBack,
                    isUploaded: appState.currentUser?.profilePhotos.fullBodyBack != nil
                ) {
                    editingPhotoStep = .fullBodyBack
                    showingPrivacyNotice = true
                }
            }

            if appState.currentUser?.profilePhotos.allPhotosUploaded == true {
                Text("All photos uploaded! Your personalized palette is ready.")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
    }

    private func colorPaletteSection(_ palette: PersonalPalette) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Your Color Palette")
                .font(.headline)

            HStack(spacing: Theme.Spacing.xs) {
                Text(palette.seasonalType.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.primary.opacity(0.1))
                    .clipShape(Capsule())

                Text(palette.undertone.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.primary.opacity(0.1))
                    .clipShape(Capsule())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(palette.recommendedColors) { color in
                        Circle()
                            .fill(color.color)
                            .frame(width: 44, height: 44)
                            .overlay {
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            }
                            .shadow(color: .black.opacity(0.1), radius: 2)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
    }

    private var stylePreferencesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Style Preferences")
                    .font(.headline)

                Spacer()

                Button("Edit") {
                    // Edit preferences
                }
                .font(.subheadline)
            }

            if let preferences = appState.currentUser?.stylePreferences, !preferences.isEmpty {
                FlowLayout(spacing: Theme.Spacing.xs) {
                    ForEach(preferences, id: \.self) { pref in
                        Text(pref)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.primary.opacity(0.1))
                            .foregroundStyle(Theme.Colors.primary)
                            .clipShape(Capsule())
                    }
                }
            } else {
                Text("No preferences set yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
    }

    private var settingsSection: some View {
        VStack(spacing: 0) {
            // Language row with Menu
            Button {
                // Language menu handled separately
            } label: {
                HStack {
                    Image(systemName: "globe")
                        .foregroundStyle(.blue)
                        .frame(width: 28)
                    Text("Language")
                    Spacer()
                    Text(selectedLanguage.displayName)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(Theme.Spacing.md)
            }
            .buttonStyle(.plain)
            .contextMenu {
                ForEach(Language.allCases) { lang in
                    Button {
                        selectedLanguage = lang
                        appState.setLanguage(lang)
                    } label: {
                        HStack {
                            Text(lang.flag)
                            Text(lang.displayName)
                        }
                    }
                }
            }

            Divider().padding(.leading, 44)

            // Privacy row
            NavigationLink {
                PrivacySettingsView()
            } label: {
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.green)
                        .frame(width: 28)
                    Text("Privacy Settings")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(Theme.Spacing.md)
            }

            Divider().padding(.leading, 44)

            // Subscription row
            Button {
                showingSubscription = true
            } label: {
                HStack {
                    Image(systemName: "creditcard")
                        .foregroundStyle(.orange)
                        .frame(width: 28)
                    Text("Subscription")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(appState.isPremium ? "Premium" : "Free")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(Theme.Spacing.md)
            }
            .buttonStyle(.plain)
        }
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
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
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) photo\(isUploaded ? ", uploaded" : ", not uploaded")")
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
