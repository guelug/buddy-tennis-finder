import SwiftUI
import UIKit

enum Theme {
    // MARK: - Dark Mode Support

    static var isDarkMode: Bool {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return false
        }
        return window.traitCollection.userInterfaceStyle == .dark
    }

    // MARK: - Colors

    enum Colors {
        // Primary palette - Apple/Claude inspired
        static let primary = Color("AccentColor")
        static let secondary = Color.secondary
        static let background = Color(.systemBackground)
        static let groupedBackground = Color(.systemGroupedBackground)

        // Premium neutrals
        static let cardBackground = Color(.secondarySystemGroupedBackground)
        static let cardBorder = Color(.separator)
        static let premiumGold = Color(red: 0.78, green: 0.64, blue: 0.28)
        static let primaryGradient = LinearGradient(
            colors: [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 0.78, green: 0.64, blue: 0.28)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Semantic colors
        static let success = Color.green
        static let error = Color.red
        static let warning = Color.orange

        // Text colors
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color(.tertiaryLabel)

        // Chat colors
        static let userBubble = Color.blue
        static let assistantBubble = Color(.systemGray5)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48

        static let cardPadding: CGFloat = 16
        static let screenPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 24
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 24
        static let pill: CGFloat = 999
    }

    // MARK: - Shadows

    enum Shadows {
        static let small = Shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        static let medium = Shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        static let large = Shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
    }

    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        self
            .padding(Theme.Spacing.cardPadding)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    func premiumButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.primaryGradient)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }

    func primaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.primary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }
}

// MARK: - Typography
// Using SwiftUI's built-in Font types directly throughout the app.
