import SwiftUI

struct NoPaletteView: View {
    @Environment(AppState.self) private var appState
    @State private var showingPhotoUpload = false
    @State private var editingPhotoStep: PhotoUploadView.UploadStep = .faceCloseUp

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "paintpalette.fill")
                .font(.system(size: 80))
                .foregroundStyle(Theme.Colors.primary.opacity(0.5))

            VStack(spacing: Theme.Spacing.md) {
                Text("Tu Paleta de Colores")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Para crear tu paleta personal, necesitamos analizar tus fotos. Sube al menos una foto de tu rostro para comenzar.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Button {
                    editingPhotoStep = .faceCloseUp
                    showingPhotoUpload = true
                } label: {
                    Label("Subir Fotos", systemImage: "photo.badge.plus")
                        .frame(maxWidth: .infinity)
                        .primaryButtonStyle()
                }

                Text("Necesitaras una foto clara de tu rostro")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()

            // Show current upload status
            if let user = appState.currentUser {
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Estado de tus fotos")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: Theme.Spacing.md) {
                        PhotoStatusIndicator(
                            title: "Rostro",
                            isUploaded: user.profilePhotos.faceCloseUp != nil
                        )
                        PhotoStatusIndicator(
                            title: "Perfil",
                            isUploaded: user.profilePhotos.faceProfile != nil
                        )
                        PhotoStatusIndicator(
                            title: "Frente",
                            isUploaded: user.profilePhotos.fullBodyFront != nil
                        )
                        PhotoStatusIndicator(
                            title: "Atras",
                            isUploaded: user.profilePhotos.fullBodyBack != nil
                        )
                    }
                }
                .padding(.bottom, Theme.Spacing.lg)
            }
        }
        .padding(Theme.Spacing.screenPadding)
        .background(Theme.Colors.groupedBackground.ignoresSafeArea())
        .navigationTitle("Mi Paleta")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPhotoUpload) {
            PhotoUploadView(startStep: editingPhotoStep)
        }
    }
}

struct PhotoStatusIndicator: View {
    let title: String
    let isUploaded: Bool

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isUploaded ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 24, height: 24)
                .overlay {
                    if isUploaded {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        NoPaletteView()
            .environment(AppState())
    }
}
