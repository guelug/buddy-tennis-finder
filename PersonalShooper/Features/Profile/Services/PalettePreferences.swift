import Foundation

/// A common wearable color the user can pick in the palette questionnaire.
struct PaletteColorChoice: Identifiable, Hashable {
    let id: String
    let hex: String
    let nameEn: String
    let nameEs: String

    func name(in language: Language) -> String {
        language == .spanish ? nameEs : nameEn
    }

    var codableColor: CodableColor? {
        CodableColor(hex: hex, name: nameEn)
    }
}

/// User-reported color preferences captured at photo upload, used to bias palette generation so the
/// result respects colors the person knows look good on them (e.g. "white and black suit me").
struct PalettePreferences: Equatable {
    /// Colors the user says they look great in / get compliments on.
    var lovedColorIDs: [String] = []
    /// Colors the user dislikes or feels washed out in.
    var dislikedColorIDs: [String] = []
    /// Free-text note for anything not covered by the chips.
    var notes: String = ""

    var isEmpty: Bool {
        lovedColorIDs.isEmpty && dislikedColorIDs.isEmpty && notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var lovedChoices: [PaletteColorChoice] {
        lovedColorIDs.compactMap { PaletteColorCatalog.choice(for: $0) }
    }

    var dislikedChoices: [PaletteColorChoice] {
        dislikedColorIDs.compactMap { PaletteColorCatalog.choice(for: $0) }
    }
}

/// Catalog of common garment colors offered in the questionnaire.
enum PaletteColorCatalog {
    static let all: [PaletteColorChoice] = [
        PaletteColorChoice(id: "white", hex: "#FFFFFF", nameEn: "White", nameEs: "Blanco"),
        PaletteColorChoice(id: "black", hex: "#1A1A1A", nameEn: "Black", nameEs: "Negro"),
        PaletteColorChoice(id: "navy", hex: "#1A237E", nameEn: "Navy", nameEs: "Azul marino"),
        PaletteColorChoice(id: "gray", hex: "#9E9E9E", nameEn: "Gray", nameEs: "Gris"),
        PaletteColorChoice(id: "beige", hex: "#D7C4A3", nameEn: "Beige", nameEs: "Beige"),
        PaletteColorChoice(id: "brown", hex: "#6F4E37", nameEn: "Brown", nameEs: "Marrón"),
        PaletteColorChoice(id: "cream", hex: "#F5E9D6", nameEn: "Cream", nameEs: "Crema"),
        PaletteColorChoice(id: "red", hex: "#C62828", nameEn: "Red", nameEs: "Rojo"),
        PaletteColorChoice(id: "burgundy", hex: "#7B1E2B", nameEn: "Burgundy", nameEs: "Burdeos"),
        PaletteColorChoice(id: "pink", hex: "#E8A0B6", nameEn: "Pink", nameEs: "Rosa"),
        PaletteColorChoice(id: "coral", hex: "#FF7F50", nameEn: "Coral", nameEs: "Coral"),
        PaletteColorChoice(id: "orange", hex: "#EF6C00", nameEn: "Orange", nameEs: "Naranja"),
        PaletteColorChoice(id: "yellow", hex: "#FFC94D", nameEn: "Yellow", nameEs: "Amarillo"),
        PaletteColorChoice(id: "mustard", hex: "#B8860B", nameEn: "Mustard", nameEs: "Mostaza"),
        PaletteColorChoice(id: "green", hex: "#2E7D32", nameEn: "Green", nameEs: "Verde"),
        PaletteColorChoice(id: "emerald", hex: "#2E7D5B", nameEn: "Emerald", nameEs: "Esmeralda"),
        PaletteColorChoice(id: "olive", hex: "#556B2F", nameEn: "Olive", nameEs: "Oliva"),
        PaletteColorChoice(id: "teal", hex: "#00838F", nameEn: "Teal", nameEs: "Azul petróleo"),
        PaletteColorChoice(id: "blue", hex: "#1565C0", nameEn: "Blue", nameEs: "Azul"),
        PaletteColorChoice(id: "lightblue", hex: "#7EC8E3", nameEn: "Light Blue", nameEs: "Azul claro"),
        PaletteColorChoice(id: "purple", hex: "#6A1B9A", nameEn: "Purple", nameEs: "Púrpura"),
        PaletteColorChoice(id: "lavender", hex: "#B49AC6", nameEn: "Lavender", nameEs: "Lavanda")
    ]

    static func choice(for id: String) -> PaletteColorChoice? {
        all.first { $0.id == id }
    }
}
