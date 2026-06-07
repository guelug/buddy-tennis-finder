import Foundation

/// Shared logic for deciding whether a garment sits within the user's personal color palette,
/// reused by the closet filter, the outfit builder and the capsule plan so "on-palette" means the
/// same thing everywhere.
enum PaletteMatching {

    /// Modifier words that shouldn't drive a match on their own (we want the core hue to overlap,
    /// e.g. "azul marino" ~ "azul claro" via "azul", not "claro" ~ "claro").
    private static let modifiers: Set<String> = [
        "claro", "oscuro", "suave", "medio", "pálido", "palido", "vivo", "pastel", "intenso", "apagado",
        "light", "dark", "soft", "bright", "deep", "muted", "warm", "cool", "cálido", "calido", "frío", "frio"
    ]

    /// The set of meaningful (hue) tokens for the palette's flattering colors (best + neutrals +
    /// statements). Diacritic-insensitive and lowercased; modifier-only tokens are dropped.
    static func colorNames(for palette: PersonalPalette?) -> Set<String> {
        guard let palette else { return [] }
        let all = palette.recommendedColors + (palette.neutralColors ?? []) + (palette.statementColors ?? [])
        return Set(all.compactMap(\.name).flatMap(hueTokens(in:)))
    }

    /// True when any of the garment's color tags shares a hue token with the palette.
    static func isOnPalette(_ item: ClothingItem, names paletteTokens: Set<String>) -> Bool {
        guard !paletteTokens.isEmpty else { return false }
        return item.colorTags.contains { tag in
            !hueTokens(in: tag).isDisjoint(with: paletteTokens)
        }
    }

    /// Splits a color name into normalized, meaningful tokens (drops accents, casing, short words and
    /// modifier words).
    private static func hueTokens(in name: String) -> Set<String> {
        let normalized = name
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
        let words = normalized.split { !$0.isLetter }.map(String.init)
        return Set(words.filter { $0.count >= 3 && !modifiers.contains($0) })
    }
}
