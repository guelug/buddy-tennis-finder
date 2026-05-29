import Foundation

/// Curated, named clothing-color palettes used as the rule-based fallback when on-device AI is
/// unavailable. Colors are real garment colors (jewel tones, neutrals, denims) — never skin tones.
/// Each entry is (hex, English name, Spanish name).
enum NamedPaletteLibrary {

    struct PaletteRecipe {
        let best: [(String, String, String)]
        let neutrals: [(String, String, String)]
        let statements: [(String, String, String)]
        let avoid: [(String, String, String)]
        let summaryEn: String
        let summaryEs: String
    }

    static func recipe(for seasonalType: SeasonalType) -> PaletteRecipe {
        switch family(of: seasonalType) {
        case .spring: return spring
        case .summer: return summer
        case .autumn: return autumn
        case .winter: return winter
        }
    }

    private enum Family { case spring, summer, autumn, winter }

    private static func family(of type: SeasonalType) -> Family {
        switch type {
        case .spring, .softSpring, .brightSpring, .lightSpring: return .spring
        case .summer, .softSummer, .lightSummer: return .summer
        case .autumn, .softAutumn, .darkAutumn: return .autumn
        case .winter, .softWinter, .brightWinter, .darkWinter: return .winter
        }
    }

    // MARK: - Recipes

    private static let spring = PaletteRecipe(
        best: [
            ("#F76D5E", "Coral", "Coral"),
            ("#FFC94D", "Golden Yellow", "Amarillo dorado"),
            ("#5FBFA8", "Turquoise", "Turquesa"),
            ("#9CCC65", "Apple Green", "Verde manzana"),
            ("#FF8A65", "Peach", "Melocotón"),
            ("#42A5F5", "Clear Blue", "Azul claro")
        ],
        neutrals: [
            ("#F5E9D6", "Ivory", "Marfil"),
            ("#C9A66B", "Camel", "Camel"),
            ("#8D6E63", "Warm Taupe", "Topo cálido"),
            ("#3E5C76", "Soft Navy", "Azul marino suave")
        ],
        statements: [
            ("#FF5252", "Warm Red", "Rojo cálido"),
            ("#26C6DA", "Aqua", "Aguamarina"),
            ("#FFB300", "Marigold", "Caléndula")
        ],
        avoid: [
            ("#2E2E2E", "Black", "Negro"),
            ("#5D4037", "Muddy Brown", "Marrón apagado"),
            ("#9E9E9E", "Cool Gray", "Gris frío")
        ],
        summaryEn: "Warm, clear and bright colors light up your complexion — lean into fresh corals, golden yellows and turquoise rather than heavy darks.",
        summaryEs: "Los colores cálidos, limpios y luminosos iluminan tu rostro: apuesta por corales frescos, amarillos dorados y turquesa en lugar de oscuros pesados."
    )

    private static let summer = PaletteRecipe(
        best: [
            ("#7E9BD0", "Soft Blue", "Azul suave"),
            ("#B49AC6", "Lavender", "Lavanda"),
            ("#E8A0B6", "Rose Pink", "Rosa empolvado"),
            ("#6FAE9E", "Sea Green", "Verde mar"),
            ("#8E9BAE", "Slate Blue", "Azul pizarra"),
            ("#C56E8E", "Raspberry", "Frambuesa")
        ],
        neutrals: [
            ("#EDEDEF", "Soft White", "Blanco suave"),
            ("#B8BCC4", "Cool Gray", "Gris frío"),
            ("#6E7E8F", "Blue Gray", "Gris azulado"),
            ("#324A5E", "Navy", "Azul marino")
        ],
        statements: [
            ("#9C27B0", "Orchid", "Orquídea"),
            ("#0277BD", "Periwinkle Blue", "Azul vincapervinca"),
            ("#AD1457", "Cool Berry", "Baya fría")
        ],
        avoid: [
            ("#FF6F00", "Orange", "Naranja"),
            ("#FFD600", "Bright Gold", "Dorado intenso"),
            ("#3E2723", "Warm Black-Brown", "Marrón muy cálido")
        ],
        summaryEn: "Soft, cool and muted tones suit you best — think dusty blues, lavenders and rose. Skip hot oranges and harsh black.",
        summaryEs: "Los tonos suaves, fríos y apagados te favorecen más: azules empolvados, lavandas y rosa. Evita naranjas intensos y el negro duro."
    )

    private static let autumn = PaletteRecipe(
        best: [
            ("#2E7D5B", "Emerald", "Esmeralda"),
            ("#C75B39", "Terracotta", "Terracota"),
            ("#3F6F8F", "Teal", "Azul petróleo"),
            ("#B8860B", "Mustard", "Mostaza"),
            ("#8E2D2D", "Brick Red", "Rojo teja"),
            ("#556B2F", "Olive", "Oliva")
        ],
        neutrals: [
            ("#EFE2C6", "Cream", "Crema"),
            ("#A9743F", "Caramel", "Caramelo"),
            ("#6F4E37", "Coffee", "Café"),
            ("#2F4030", "Forest", "Verde bosque")
        ],
        statements: [
            ("#C2410C", "Pumpkin", "Calabaza"),
            ("#14746F", "Deep Teal", "Verde azulado profundo"),
            ("#7B341E", "Rust", "Óxido")
        ],
        avoid: [
            ("#FF69B4", "Hot Pink", "Rosa chicle"),
            ("#00BCD4", "Icy Blue", "Azul gélido"),
            ("#F5F5F5", "Pure White", "Blanco puro")
        ],
        summaryEn: "Rich, warm and earthy tones are your power colors — emerald, terracotta, teal and mustard. Trade pure white for cream and skip icy pastels.",
        summaryEs: "Los tonos cálidos, ricos y terrosos son tus colores estrella: esmeralda, terracota, azul petróleo y mostaza. Cambia el blanco puro por crema y evita pasteles fríos."
    )

    private static let winter = PaletteRecipe(
        best: [
            ("#0B3D91", "Royal Blue", "Azul rey"),
            ("#C2185B", "Fuchsia", "Fucsia"),
            ("#00695C", "Pine Green", "Verde pino"),
            ("#6A1B9A", "Purple", "Púrpura"),
            ("#C62828", "True Red", "Rojo puro"),
            ("#00838F", "Teal", "Turquesa profundo")
        ],
        neutrals: [
            ("#FFFFFF", "Pure White", "Blanco puro"),
            ("#212121", "Black", "Negro"),
            ("#37474F", "Charcoal", "Gris carbón"),
            ("#1A237E", "Navy", "Azul marino")
        ],
        statements: [
            ("#D81B60", "Magenta", "Magenta"),
            ("#1565C0", "Electric Blue", "Azul eléctrico"),
            ("#AD1457", "Cherry", "Cereza")
        ],
        avoid: [
            ("#D2B48C", "Tan", "Tostado"),
            ("#F4A460", "Muted Orange", "Naranja apagado"),
            ("#8D6E63", "Beige-Brown", "Beige amarronado")
        ],
        summaryEn: "Crisp, cool and high-contrast colors are striking on you — true red, royal blue, fuchsia and clean black-and-white. Avoid muted earth tones.",
        summaryEs: "Los colores nítidos, fríos y de alto contraste te lucen muchísimo: rojo puro, azul rey, fucsia y el blanco y negro limpio. Evita los tonos tierra apagados."
    )
}
