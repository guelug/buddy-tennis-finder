import SwiftUI

struct PrivacySettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var shareAnalyticsData = false
    @State private var allowPersonalizedAds = false
    @State private var showClearDataAlert = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Label("Your Data is Private", systemImage: "lock.shield.fill")
                        .font(.headline)
                        .foregroundStyle(.green)

                    Text("Personal Shooper processes all your photos locally on your device. We never upload your photos to external servers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, Theme.Spacing.xs)
            }

            Section("Data Collection") {
                Toggle("Share Analytics", isOn: $shareAnalyticsData)

                Toggle("Personalized Recommendations", isOn: $allowPersonalizedAds)

                Text("These settings affect how we improve our services. Your photos are never shared.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Your Stored Data") {
                if let user = appState.currentUser {
                    HStack {
                        Text("Profile Photos")
                        Spacer()
                        Text("\(user.profilePhotos.uploadedCount)/4")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Color Palette")
                        Spacer()
                        Text(user.personalPalette != nil ? "Generated" : "Not Set")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Conversations")
                        Spacer()
                        Text("Stored Locally")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showClearDataAlert = true
                } label: {
                    Label("Clear All Data", systemImage: "trash")
                }
            } footer: {
                Text("This will delete all your photos, analysis results, and conversation history. This action cannot be undone.")
            }

            Section {
                Link(destination: URL(string: "https://personalshooper.app/privacy")!) {
                    HStack {
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }

                Link(destination: URL(string: "https://personalshooper.app/terms")!) {
                    HStack {
                        Text("Terms of Service")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Privacy Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Clear All Data?", isPresented: $showClearDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will permanently delete all your photos, color palette, and chat history. Premium subscription will remain active.")
        }
    }

    private func clearAllData() {
        if let user = appState.currentUser {
            user.profilePhotos = ProfilePhotos()
            user.skinAnalysis = nil
            user.personalPalette = nil
            user.updateStylingProfile(PersonalStylingProfile())
        }
        // Conversations would be cleared via SwiftData
        dismiss()
    }
}
