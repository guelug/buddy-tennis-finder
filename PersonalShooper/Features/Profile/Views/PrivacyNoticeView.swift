import SwiftUI

struct PrivacyNoticeView: View {
    var onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss

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
                    Text("Your Privacy Matters")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)

                    // Content
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        NoticePoint(
                            icon: "iphone",
                            title: "Processed Locally",
                            description: "All photo analysis happens on your device. Your photos are never uploaded to our servers."
                        )

                        NoticePoint(
                            icon: "eye.slash",
                            title: "Not Shared",
                            description: "We never sell, share, or transmit your photos to third parties."
                        )

                        NoticePoint(
                            icon: "trash",
                            title: "You Control Your Data",
                            description: "You can delete all your data at any time from the Privacy Settings."
                        )

                        NoticePoint(
                            icon: "checkmark.shield",
                            title: "Secure Storage",
                            description: "Your photos are stored securely on your device using iOS data protection."
                        )
                    }

                    Spacer(minLength: Theme.Spacing.lg)

                    // Button
                    Button {
                        onContinue()
                        dismiss()
                    } label: {
                        Text("I Understand, Continue")
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
