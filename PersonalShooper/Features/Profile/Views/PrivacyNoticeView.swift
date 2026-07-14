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
                            description: isSpanish ? "El análisis de perfil, color y rasgos ocurre en tu dispositivo. Las fotos se guardan localmente con la protección de datos de iOS." : "Profile, color, and feature analysis happens on your device. Photos are stored locally with iOS data protection."
                        )

                        NoticePoint(
                            icon: "eye.slash",
                            title: isSpanish ? "Sin venta de datos" : "No Data Sales",
                            description: isSpanish ? "No vendemos tus fotos ni datos personales. Las funciones externas requieren una elección explícita y puedes revocar el permiso de procesado de imágenes." : "We do not sell your photos or personal data. External features require an explicit choice, and you can revoke image-processing permission."
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
                            title: isSpanish ? "Proveedores externos opcionales" : "Optional External Providers",
                            description: isSpanish ? "Si eliges un try-on externo o permites miniaturas en la nube, se envían las imágenes necesarias para generar el resultado. El procesado local se prioriza cuando está disponible." : "If you choose an external try-on or allow cloud thumbnails, the required images are sent to generate the result. On-device processing is preferred when available."
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
