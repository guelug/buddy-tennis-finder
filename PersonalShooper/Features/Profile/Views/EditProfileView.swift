import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Profile image section
                    VStack(spacing: Theme.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.primaryGradient)
                                .frame(width: 120, height: 120)

                            if let profileImage = profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                            } else {
                                Text((displayName.isEmpty ? "U" : String(displayName.prefix(2))).uppercased())
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .onTapGesture {
                            // Could open photo picker here
                        }

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Text("Cambiar Foto")
                                .font(.subheadline)
                                .foregroundStyle(Theme.Colors.primary)
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    profileImage = image
                                }
                            }
                        }
                    }
                    .padding(.top, Theme.Spacing.lg)

                    // Name field
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Nombre")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("Tu nombre", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.name)
                    }
                    .padding(.horizontal, Theme.Spacing.md)

                    Spacer()

                    // Save button
                    Button {
                        saveProfile()
                    } label: {
                        Text("Guardar Cambios")
                            .frame(maxWidth: .infinity)
                            .primaryButtonStyle()
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.lg)
                }
            }
            .background(Theme.Colors.groupedBackground.ignoresSafeArea())
            .navigationTitle("Editar Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                displayName = appState.currentUser?.displayName ?? ""
                profileImage = appState.currentUser?.profilePhotos.faceCloseUp
            }
        }
    }

    private func saveProfile() {
        guard !displayName.isEmpty, let user = appState.currentUser else { return }
        user.displayName = displayName
        if let image = profileImage {
            user.profilePhotos = ProfilePhotos(
                faceCloseUp: image,
                faceProfile: user.profilePhotos.faceProfile,
                fullBodyFront: user.profilePhotos.fullBodyFront,
                fullBodyBack: user.profilePhotos.fullBodyBack
            )
        }
        dismiss()
    }
}

#Preview {
    EditProfileView()
        .environment(AppState())
}
