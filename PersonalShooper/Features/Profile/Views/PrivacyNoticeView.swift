import SwiftUI

struct PrivacyNoticeView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var isSpanish: Bool {
        appState.preferredLanguage == .spanish
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Icon
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)

                    // Title
                    Text(isSpanish ? "Tu privacidad importa" : "Your Privacy Matters")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)

                    // Content
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        NoticePoint(
                            icon: "iphone",
                            title: isSpanish ? "Procesado local" : "Processed Locally",
                            description: isSpanish ? "Todo el análisis de fotos ocurre en tu dispositivo. Tus fotos no se suben a nuestros servidores." : "All photo analysis happens on your device. Your photos are never uploaded to our servers."
                        )

                        NoticePoint(
                            icon: "eye.slash",
                            title: isSpanish ? "No se comparte" : "Not Shared",
                            description: isSpanish ? "Nunca vendemos, compartimos ni transmitimos tus fotos a terceros." : "We never sell, share, or transmit your photos to third parties."
                        )

                        NoticePoint(
                            icon: "trash",
                            title: isSpanish ? "Tú controlas tus datos" : "You Control Your Data",
                            description: isSpanish ? "Puedes borrar todos tus datos en cualquier momento desde los ajustes de privacidad." : "You can delete all your data at any time from the Privacy Settings."
                        )

                        NoticePoint(
                            icon: "checkmark.shield",
                            title: isSpanish ? "Almacenamiento seguro" : "Secure Storage",
                            description: isSpanish ? "Tus fotos se guardan de forma segura en tu dispositivo usando la protección de datos de iOS." : "Your photos are stored securely on your device using iOS data protection."
                        )

                        NoticePoint(
                            icon: "photo.on.rectangle",
                            title: isSpanish ? "El try-on virtual usa Google" : "Virtual Try-On Uses Google",
                            description: isSpanish ? "Solo para el try-on virtual: la foto de la prenda y las fotos de perfil necesarias como referencia se envían a Gemini de Google para generar el resultado. Google no almacena tus fotos." : "Only for Virtual Try-On: the garment photo and the profile reference photos needed for that garment are sent to Google's Gemini AI to generate the result. Your photos are not stored by Google."
                        )
                    }

                    Spacer(minLength: Theme.Spacing.lg)

                    // Button
                    Button {
                        onContinue()
                        dismiss()
                    } label: {
                        Text(isSpanish ? "Entendido, continuar" : "I Understand, Continue")
                            .frame(maxWidth: .infinity)
                            .primaryButtonStyle()
                    }
                }
                .padding(Theme.Spacing.screenPadding)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct NoticePoint: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }
}
