import Foundation

/// Curated, named **clothing-color** palettes used as the rule-based output (and as professional
/// anchors for the on-device AI). Colors are real garment colors — jewel tones, neutrals, denims,
/// knit colors — never skin tones.
///
/// These follow the established 12-season personal-color-analysis system used by image consultants
/// (Sci\ART / 12-tone): each season is positioned on three axes — **temperature** (warm↔cool),
/// **value/depth** (light↔deep) and **chroma/clarity** (bright↔muted) — and its flattering wardrobe
/// colors follow from that position. Every entry is `(hex, English name, Spanish name)`.
enum NamedPaletteLibrary {

    struct PaletteRecipe {
        let best: [(String, String, String)]
        let neutrals: [(String, String, String)]
        let statements: [(String, String, String)]
        let avoid: [(String, String, String)]
        let summaryEn: String
        let summaryEs: String
    }

    /// Maps each of the app's seasonal types onto its precise 12-tone wardrobe recipe.
    static func recipe(for seasonalType: SeasonalType) -> PaletteRecipe {
        switch seasonalType {
        case .brightSpring:            return brightSpring
        case .spring:                  return trueSpring
        case .lightSpring, .softSpring: return lightSpring
        case .lightSummer:             return lightSummer
        case .summer:                  return trueSummer
        case .softSummer:              return softSummer
        case .softAutumn:              return softAutumn
        case .autumn:                  return trueAutumn
        case .darkAutumn:              return deepAutumn
        case .winter, .softWinter:     return trueWinter
        case .brightWinter:            return brightWinter
        case .darkWinter:              return deepWinter
        }
    }

    // MARK: - SPRING (warm)

    /// Bright/Clear Spring — warm-neutral, high clarity, vivid.
    private static let brightSpring = PaletteRecipe(
        best: [
            ("#FF6F61", "Bright Coral", "Coral vivo"),
            ("#FFC400", "Golden Yellow", "Amarillo dorado"),
            ("#13C4A3", "Bright Turquoise", "Turquesa vivo"),
            ("#7CC242", "Apple Green", "Verde manzana"),
            ("#FF8DA1", "Warm Pink", "Rosa cálido"),
            ("#3FA7FF", "Clear Blue", "Azul claro")
        ],
        neutrals: [
            ("#F7EFD9", "Ivory", "Marfil"),
            ("#D8B384", "Warm Beige", "Beige cálido"),
            ("#9C8466", "Warm Stone", "Piedra cálida"),
            ("#2F5B8C", "Bright Navy", "Azul marino vivo")
        ],
        statements: [
            ("#FF3B30", "Warm Red", "Rojo cálido"),
            ("#00C2C7", "Aqua", "Aguamarina"),
            ("#FF9E1B", "Marigold", "Caléndula")
        ],
        avoid: [
            ("#5D4037", "Muddy Brown", "Marrón apagado"),
            ("#9E9E9E", "Smoky Gray", "Gris ahumado"),
            ("#7E6B8F", "Dusty Mauve", "Malva apagado")
        ],
        summaryEn: "Warm and crystal-clear brights are your power colors — vivid coral, golden yellow and bright turquoise. Keep dusty, smoky or muddy tones off your face.",
        summaryEs: "Los cálidos vivos y nítidos son tus colores estrella: coral intenso, amarillo dorado y turquesa vivo. Aleja del rostro los tonos apagados, ahumados o terrosos."
    )

    /// True/Warm Spring — clearly warm, medium-bright.
    private static let trueSpring = PaletteRecipe(
        best: [
            ("#F76D5E", "Coral", "Coral"),
            ("#FFC94D", "Golden Yellow", "Amarillo dorado"),
            ("#5FBFA8", "Turquoise", "Turquesa"),
            ("#9CCC65", "Leaf Green", "Verde hoja"),
            ("#FF8A65", "Peach", "Melocotón"),
            ("#42A5F5", "Warm Blue", "Azul cálido")
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
        summaryEn: "Warm, clear and bright colors light up your complexion — fresh corals, golden yellows and turquoise rather than heavy darks.",
        summaryEs: "Los colores cálidos, limpios y luminosos iluminan tu rostro: corales frescos, amarillos dorados y turquesa en lugar de oscuros pesados."
    )

    /// Light Spring — light, warm-neutral, delicate.
    private static let lightSpring = PaletteRecipe(
        best: [
            ("#FFB59E", "Light Coral", "Coral claro"),
            ("#FFE08A", "Butter Yellow", "Amarillo mantequilla"),
            ("#A6E3D7", "Light Aqua", "Aguamarina claro"),
            ("#BFE3A0", "Light Green", "Verde claro"),
            ("#FFC2B0", "Peach Blossom", "Flor de melocotón"),
            ("#8FC9F2", "Sky Blue", "Azul cielo")
        ],
        neutrals: [
            ("#FBF2E2", "Ivory", "Marfil"),
            ("#E6CFA8", "Light Camel", "Camel claro"),
            ("#CDBBA0", "Warm Sand", "Arena cálida"),
            ("#6E90B4", "Chambray Blue", "Azul chambray")
        ],
        statements: [
            ("#FF7A59", "Warm Coral", "Coral cálido"),
            ("#2FC4C9", "Clear Aqua", "Aguamarina nítido"),
            ("#FFCB3D", "Golden", "Dorado")
        ],
        avoid: [
            ("#1A1A1A", "Black", "Negro"),
            ("#5A1A2B", "Dark Burgundy", "Borgoña oscuro"),
            ("#37474F", "Charcoal", "Gris carbón")
        ],
        summaryEn: "Light, warm and fresh tones flatter you — peach, butter yellow and light aqua. Swap black and heavy darks for ivory and soft navy.",
        summaryEs: "Te favorecen los tonos claros, cálidos y frescos: melocotón, amarillo mantequilla y aguamarina claro. Cambia el negro y los oscuros pesados por marfil y azul marino suave."
    )

    // MARK: - SUMMER (cool)

    /// Light Summer — light, cool-neutral, soft.
    private static let lightSummer = PaletteRecipe(
        best: [
            ("#9DBBE3", "Powder Blue", "Azul polvo"),
            ("#C3B2DD", "Soft Lavender", "Lavanda suave"),
            ("#F0B6C6", "Light Rose", "Rosa claro"),
            ("#A8D5C8", "Soft Aqua", "Aguamarina suave"),
            ("#A9B4DE", "Periwinkle", "Vincapervinca"),
            ("#BFE0D6", "Cool Mint", "Menta fría")
        ],
        neutrals: [
            ("#F2F2F4", "Soft White", "Blanco suave"),
            ("#CDD2DA", "Light Cool Gray", "Gris frío claro"),
            ("#9AA5B5", "Dove Gray", "Gris paloma"),
            ("#43607E", "Soft Navy", "Azul marino suave")
        ],
        statements: [
            ("#C45D86", "Cool Raspberry", "Frambuesa fría"),
            ("#5C7BD0", "Periwinkle Blue", "Azul vincapervinca"),
            ("#B069B0", "Orchid", "Orquídea")
        ],
        avoid: [
            ("#FF6F00", "Orange", "Naranja"),
            ("#1A1A1A", "Black", "Negro"),
            ("#B8860B", "Mustard", "Mostaza")
        ],
        summaryEn: "Light, cool and gently muted shades suit you — powder blue, lavender and soft rose. Keep orange, black and mustard away from your face.",
        summaryEs: "Te sientan los tonos claros, fríos y algo apagados: azul polvo, lavanda y rosa suave. Aleja del rostro el naranja, el negro y la mostaza."
    )

    /// True/Cool Summer — cool, soft-medium.
    private static let trueSummer = PaletteRecipe(
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
        summaryEn: "Soft, cool and muted tones suit you best — dusty blues, lavenders and rose. Skip hot oranges and harsh warm darks.",
        summaryEs: "Los tonos suaves, fríos y apagados te favorecen más: azules empolvados, lavandas y rosa. Evita naranjas intensos y los oscuros cálidos duros."
    )

    /// Soft Summer — muted, cool-neutral, low contrast.
    private static let softSummer = PaletteRecipe(
        best: [
            ("#C39BA6", "Dusty Rose", "Rosa empolvado"),
            ("#6F9C97", "Soft Teal", "Verde azulado suave"),
            ("#A78BA8", "Mauve", "Malva"),
            ("#7E8BA3", "Soft Slate", "Pizarra suave"),
            ("#93A88B", "Sage", "Salvia"),
            ("#8C6F86", "Muted Plum", "Ciruela apagada")
        ],
        neutrals: [
            ("#E6E2DE", "Soft Pearl", "Perla suave"),
            ("#B7B2AE", "Greige", "Greige"),
            ("#7C7E84", "Pewter Gray", "Gris peltre"),
            ("#3C4A5A", "Soft Navy", "Azul marino suave")
        ],
        statements: [
            ("#8E3B5A", "Muted Burgundy", "Borgoña apagado"),
            ("#6E83B7", "Dusty Periwinkle", "Vincapervinca apagado"),
            ("#6F5B7E", "Soft Plum", "Ciruela suave")
        ],
        avoid: [
            ("#FF6F00", "Bright Orange", "Naranja intenso"),
            ("#FFFFFF", "Pure White", "Blanco puro"),
            ("#E91E63", "Vivid Fuchsia", "Fucsia vívido")
        ],
        summaryEn: "Muted, cool and blended tones are most harmonious — dusty rose, soft teal and mauve. High-contrast brights and pure white overpower your softness.",
        summaryEs: "Los tonos apagados, fríos y mezclados son los más armónicos: rosa empolvado, verde azulado suave y malva. Los vivos de alto contraste y el blanco puro te apagan."
    )

    // MARK: - AUTUMN (warm)

    /// Soft Autumn — muted, warm-neutral, low contrast.
    private static let softAutumn = PaletteRecipe(
        best: [
            ("#8FA06A", "Sage Green", "Verde salvia"),
            ("#5E8C84", "Soft Teal", "Verde azulado suave"),
            ("#D98E73", "Salmon", "Salmón"),
            ("#C9A24B", "Golden Tan", "Dorado tostado"),
            ("#7C7A45", "Muted Olive", "Oliva apagado"),
            ("#B7715A", "Dusty Terracotta", "Terracota apagada")
        ],
        neutrals: [
            ("#EFE4CE", "Cream", "Crema"),
            ("#B79B77", "Warm Taupe", "Topo cálido"),
            ("#A9743F", "Camel", "Camel"),
            ("#5E4B3B", "Soft Coffee", "Café suave")
        ],
        statements: [
            ("#C56A3D", "Muted Pumpkin", "Calabaza apagada"),
            ("#3F7E78", "Soft Teal", "Verde azulado"),
            ("#9C4A3C", "Brick", "Teja")
        ],
        avoid: [
            ("#FF69B4", "Hot Pink", "Rosa chicle"),
            ("#00BCD4", "Icy Blue", "Azul gélido"),
            ("#FFFFFF", "Pure White", "Blanco puro")
        ],
        summaryEn: "Warm, muted and earthy tones blend beautifully on you — sage, salmon and golden tan. Cool icy brights and stark white feel harsh.",
        summaryEs: "Los tonos cálidos, apagados y terrosos se mezclan muy bien contigo: salvia, salmón y dorado tostado. Los vivos fríos y el blanco puro resultan duros."
    )

    /// True/Warm Autumn — warm, rich, medium-deep.
    private static let trueAutumn = PaletteRecipe(
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

    /// Dark/Deep Autumn — deep, warm-neutral.
    private static let deepAutumn = PaletteRecipe(
        best: [
            ("#1F5C52", "Dark Teal", "Verde azulado oscuro"),
            ("#9C3B1E", "Rust", "Óxido"),
            ("#4B5320", "Deep Olive", "Oliva profundo"),
            ("#5C2A2A", "Mahogany", "Caoba"),
            ("#A8341F", "Tomato Red", "Rojo tomate"),
            ("#B07A1E", "Deep Gold", "Dorado profundo")
        ],
        neutrals: [
            ("#E4D5B7", "Ecru", "Crudo"),
            ("#5A3C28", "Chocolate", "Chocolate"),
            ("#3A2A20", "Espresso", "Espresso"),
            ("#23331F", "Dark Forest", "Bosque oscuro")
        ],
        statements: [
            ("#C2410C", "Pumpkin", "Calabaza"),
            ("#0F5E59", "Deep Teal", "Verde azulado profundo"),
            ("#7A1F2B", "Garnet", "Granate")
        ],
        avoid: [
            ("#BBE1F2", "Pastel Blue", "Azul pastel"),
            ("#F8BBD0", "Baby Pink", "Rosa bebé"),
            ("#CFCFCF", "Light Gray", "Gris claro")
        ],
        summaryEn: "Deep, warm and spicy tones are striking on you — dark teal, rust, mahogany and deep gold. Light pastels wash out your natural richness.",
        summaryEs: "Los tonos profundos, cálidos y especiados te lucen mucho: verde azulado oscuro, óxido, caoba y dorado profundo. Los pasteles claros apagan tu riqueza natural."
    )

    // MARK: - WINTER (cool)

    /// True/Cool Winter — cool, bright-deep, high contrast.
    private static let trueWinter = PaletteRecipe(
        best: [
            ("#0B3D91", "Royal Blue", "Azul rey"),
            ("#C2185B", "Fuchsia", "Fucsia"),
            ("#00695C", "Pine Green", "Verde pino"),
            ("#6A1B9A", "Purple", "Púrpura"),
            ("#C62828", "True Red", "Rojo puro"),
            ("#00838F", "Deep Teal", "Turquesa profundo")
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

    /// Bright/Clear Winter — cool-neutral, very high clarity and contrast.
    private static let brightWinter = PaletteRecipe(
        best: [
            ("#0050EF", "Bright Blue", "Azul brillante"),
            ("#E50A4E", "True Red", "Rojo puro"),
            ("#E0218A", "Bright Fuchsia", "Fucsia vivo"),
            ("#008E5B", "Emerald", "Esmeralda"),
            ("#7B1FA2", "Bright Violet", "Violeta vivo"),
            ("#00B7D4", "Icy Turquoise", "Turquesa gélido")
        ],
        neutrals: [
            ("#FFFFFF", "Pure White", "Blanco puro"),
            ("#0F0F0F", "Black", "Negro"),
            ("#37474F", "Charcoal", "Gris carbón"),
            ("#0D1B57", "True Navy", "Azul marino puro")
        ],
        statements: [
            ("#1565FF", "Electric Blue", "Azul eléctrico"),
            ("#FF1493", "Magenta", "Magenta"),
            ("#D50032", "Bright Cherry", "Cereza vivo")
        ],
        avoid: [
            ("#D7C4A3", "Beige", "Beige"),
            ("#B0A48F", "Dusty Taupe", "Topo apagado"),
            ("#C98A5E", "Muted Camel", "Camel apagado")
        ],
        summaryEn: "Clear, cool and electric brights against crisp white or black are your signature — bright blue, true red and emerald. Dusty, beige and muted tones dull you.",
        summaryEs: "Los vivos fríos y eléctricos sobre blanco o negro nítidos son tu sello: azul brillante, rojo puro y esmeralda. Los tonos beige, apagados y polvorientos te apagan."
    )

    /// Dark/Deep Winter — deep, cool-neutral.
    private static let deepWinter = PaletteRecipe(
        best: [
            ("#10324F", "Ink Blue", "Azul tinta"),
            ("#7A0B2E", "Deep Crimson", "Carmesí profundo"),
            ("#1B4D3E", "Deep Pine", "Pino profundo"),
            ("#4A148C", "Royal Purple", "Púrpura real"),
            ("#9C1458", "Deep Fuchsia", "Fucsia profundo"),
            ("#005662", "Deep Teal", "Verde azulado profundo")
        ],
        neutrals: [
            ("#FFFFFF", "Pure White", "Blanco puro"),
            ("#121212", "Black", "Negro"),
            ("#263238", "Charcoal", "Gris carbón"),
            ("#0D1333", "Midnight Navy", "Azul medianoche")
        ],
        statements: [
            ("#B0185B", "Magenta", "Magenta"),
            ("#0D47A1", "Sapphire", "Zafiro"),
            ("#8E0E2E", "Cherry", "Cereza")
        ],
        avoid: [
            ("#D2B48C", "Tan", "Tostado"),
            ("#F4A460", "Muted Orange", "Naranja apagado"),
            ("#C9BBA0", "Warm Beige", "Beige cálido")
        ],
        summaryEn: "Deep, cool and jewel-toned colors command attention on you — ink blue, deep crimson and pine, anchored by black and pure white. Warm light earths fade you.",
        summaryEs: "Los tonos profundos, fríos y joya destacan en ti: azul tinta, carmesí profundo y pino, anclados con negro y blanco puro. Los tierras cálidos y claros te difuminan."
    )
}
