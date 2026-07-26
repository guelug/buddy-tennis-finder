import SwiftUI

// MARK: - Accent Themes
// Fashion-house accent themes. The whole app re-tints through Theme.Colors.primary,
// which reads from ThemeManager.shared, so changing the accent re-renders every screen.

enum AccentTheme: String, CaseIterable, Identifiable {
    case champagne
    case noir
    case rouge
    case vert
    case azure

    var id: String { rawValue }

    func displayName(_ lang: Language) -> String {
        switch self {
        case .champagne: return "Champagne"
        case .noir: return "Noir"
        case .rouge: return lang == .spanish ? "Burdeos" : "Rouge"
        case .vert: return lang == .spanish ? "Esmeralda" : "Vert"
        case .azure: return lang == .spanish ? "Azul atelier" : "Atelier Blue"
        }
    }

    var color: Color {
        switch self {
        case .champagne: return Color(red: 0.72, green: 0.56, blue: 0.24)
        case .noir: return Color(red: 0.16, green: 0.15, blue: 0.17)
        case .rouge: return Color(red: 0.58, green: 0.10, blue: 0.16)
        case .vert: return Color(red: 0.08, green: 0.42, blue: 0.30)
        case .azure: return Color(red: 0.14, green: 0.32, blue: 0.68)
        }
    }

    var highlightColor: Color {
        switch self {
        case .champagne: return Color(red: 0.94, green: 0.80, blue: 0.45)
        case .noir: return Color(red: 0.45, green: 0.44, blue: 0.48)
        case .rouge: return Color(red: 0.82, green: 0.28, blue: 0.32)
        case .vert: return Color(red: 0.30, green: 0.66, blue: 0.48)
        case .azure: return Color(red: 0.38, green: 0.60, blue: 0.94)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [highlightColor, color],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Accent readable on top of `color` (for chips/selected states).
    var onAccent: Color { .white }
}

// MARK: - Theme Manager

@Observable
@MainActor
final class ThemeManager {
    static let shared = ThemeManager()

    private static let storageKey = "app_accent_theme"

    var accent: AccentTheme {
        didSet { UserDefaults.standard.set(accent.rawValue, forKey: Self.storageKey) }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        accent = AccentTheme(rawValue: raw) ?? .champagne
    }
}

// MARK: - Editorial Typography
// Serif display type gives the app its fashion-editorial voice without bundling fonts.

extension Font {
    /// Big serif display for hero greetings and feature headlines.
    static func fashionDisplay(_ size: CGFloat = 34, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Serif section title.
    static let fashionTitle = Font.system(.title3, design: .serif).weight(.semibold)

    /// Serif card headline.
    static let fashionHeadline = Font.system(.headline, design: .serif).weight(.semibold)

    /// Small caps eyebrow (dates, kickers). Pair with .tracking() and .textCase(.uppercase).
    static let fashionEyebrow = Font.system(.caption2, design: .rounded).weight(.bold)

    /// Rounded stat numeral.
    static func fashionStat(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}

// MARK: - Liquid Glass Helpers (iOS 26+) with material fallbacks

extension View {
    /// Glass (iOS 26+) or card-material (fallback) rounded surface.
    /// Apply AFTER layout modifiers; non-interactive — for buttons use press styles instead.
    @ViewBuilder
    func fashionGlassCard(cornerRadius: CGFloat = Theme.CornerRadius.large) -> some View {
        if #available(iOS 26, *) {
            self
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .background(Theme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        }
    }

    /// Tinted glass capsule chip (selected state) / quiet capsule (fallback).
    @ViewBuilder
    func fashionGlassChip(isSelected: Bool, tint: Color) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(
                isSelected ? .regular.tint(tint).interactive() : .regular.interactive(),
                in: .capsule
            )
        } else {
            self
                .background(isSelected ? tint : Color.gray.opacity(0.1))
                .clipShape(Capsule())
        }
    }

    /// Circular glass button surface for icon buttons.
    @ViewBuilder
    func fashionGlassCircle() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.interactive(), in: .circle)
        } else {
            self
                .background(Theme.Colors.cardBackground)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Small fashion components

/// Overlapping palette swatches — the user's seasonal colors as a runway strip.
struct PaletteSwatchStrip: View {
    let colors: [CodableColor]
    var size: CGFloat = 22
    var maxVisible: Int = 6

    var body: some View {
        HStack(spacing: -(size * 0.35)) {
            ForEach(Array(colors.prefix(maxVisible))) { swatch in
                Circle()
                    .fill(swatch.color)
                    .frame(width: size, height: size)
                    .overlay {
                        Circle().stroke(Color(.systemBackground), lineWidth: 2)
                    }
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
            }
            if colors.count > maxVisible {
                Circle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: size, height: size)
                    .overlay {
                        Text("+\(colors.count - maxVisible)")
                            .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .overlay {
                        Circle().stroke(Color(.systemBackground), lineWidth: 2)
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Palette colors")
    }
}

/// Circular completion ring used for profile/styling progress.
struct CompletionRing: View {
    let progress: Double
    var tint: Color = Theme.Colors.primary
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: size * 0.1)
            Circle()
                .trim(from: 0, to: max(0.02, min(progress, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.6), value: progress)
            Text("\(Int(progress * 100))%")
                .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
        }
        .frame(width: size, height: size)
    }
}
