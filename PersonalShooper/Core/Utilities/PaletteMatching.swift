import Foundation

/// Shared logic for deciding whether a garment sits within the user's personal color palette,
/// reused by the closet filter, the outfit builder and the capsule plan so "on-palette" means the
/// same thing everywhere.
enum PaletteMatching {

    /// Lowercased names of every flattering palette color (best + neutrals + statements).
    static func colorNames(for palette: PersonalPalette?) -> Set<String> {
        guard let palette else { return [] }
        let all = palette.recommendedColors + (palette.neutralColors ?? []) + (palette.statementColors ?? [])
        return Set(all.compactMap { $0.name?.lowercased() })
    }

    /// True when any of the garment's color tags matches a palette color.
    static func isOnPalette(_ item: ClothingItem, names: Set<String>) -> Bool {
        guard !names.isEmpty else { return false }
        return item.colorTags.contains { names.contains($0.lowercased()) }
    }
}
