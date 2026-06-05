import Foundation

/// Builds a personalized capsule-wardrobe plan by crossing the user's color palette, body
/// silhouette and current closet: the timeless essentials, each in a color drawn from their palette,
/// with a fit note for their shape and a flag for whether they already own something in that slot.
enum CapsuleWardrobeService {

    struct CapsulePiece: Identifiable {
        let id = UUID()
        let title: String
        let category: ClothingCategory
        let color: CodableColor?
        let reason: String
        /// True when the closet already has at least one item in this slot's category.
        let alreadyInCloset: Bool
    }

    static func generate(
        gender: StyleGender?,
        palette: PersonalPalette?,
        bodyShape: BodyShape?,
        ownedCategoryCounts: [ClothingCategory: Int],
        language: Language
    ) -> [CapsulePiece] {
        let isSpanish = language == .spanish
        let neutrals = palette?.neutralColors ?? palette?.recommendedColors ?? []
        let bests = palette?.recommendedColors ?? []

        func neutral(_ index: Int) -> CodableColor? {
            neutrals.isEmpty ? nil : neutrals[index % neutrals.count]
        }
        func best(_ index: Int) -> CodableColor? {
            bests.isEmpty ? nil : bests[index % bests.count]
        }

        let pieces = essentials(for: gender, isSpanish: isSpanish)

        // Assign palette colors: base pieces get neutrals, the highlighted pieces get best colors.
        var neutralIndex = 0
        var bestIndex = 0
        return pieces.map { spec -> CapsulePiece in
            let color: CodableColor?
            switch spec.colorRole {
            case .neutral:
                color = neutral(neutralIndex); neutralIndex += 1
            case .best:
                color = best(bestIndex); bestIndex += 1
            case .none:
                color = nil
            }

            var reason = spec.reason
            if let tip = bodyShapeTip(for: spec.slot, shape: bodyShape, isSpanish: isSpanish) {
                reason += " " + tip
            }
            if let color, let name = color.name {
                reason += isSpanish ? " Color sugerido: \(name)." : " Suggested color: \(name)."
            }

            return CapsulePiece(
                title: spec.title,
                category: spec.category,
                color: color,
                reason: reason,
                alreadyInCloset: (ownedCategoryCounts[spec.category] ?? 0) > 0
            )
        }
    }

    // MARK: - Essentials

    private enum ColorRole { case neutral, best, none }
    private enum Slot { case top, shirt, knit, trousers, jeans, dress, blazer, coat, sneakers, shoes, bag, accessory }

    private struct Spec {
        let slot: Slot
        let title: String
        let category: ClothingCategory
        let colorRole: ColorRole
        let reason: String
    }

    private static func essentials(for gender: StyleGender?, isSpanish: Bool) -> [Spec] {
        let isWoman = gender == .female
        var specs: [Spec] = [
            Spec(slot: .shirt,
                 title: isSpanish ? "Camisa blanca / crujiente" : "Crisp white shirt",
                 category: .tops, colorRole: .neutral,
                 reason: isSpanish ? "La base más versátil: vale para oficina, casual y noche." : "The most versatile base: works for office, casual and evening."),
            Spec(slot: .knit,
                 title: isSpanish ? "Jersey de punto neutro" : "Neutral knit sweater",
                 category: .tops, colorRole: .neutral,
                 reason: isSpanish ? "Capa cómoda que combina con todo." : "A comfortable layer that pairs with everything."),
            Spec(slot: .top,
                 title: isSpanish ? "Camiseta en tu mejor color" : "Tee in your best color",
                 category: .tops, colorRole: .best,
                 reason: isSpanish ? "Un color que ilumina tu rostro para el día a día." : "A face-flattering color for everyday wear."),
            Spec(slot: .trousers,
                 title: isSpanish ? "Pantalón sastre" : "Tailored trousers",
                 category: .bottoms, colorRole: .neutral,
                 reason: isSpanish ? "Estructura pulida para looks elevados." : "Polished structure for elevated looks."),
            Spec(slot: .jeans,
                 title: isSpanish ? "Vaqueros oscuros" : "Dark wash jeans",
                 category: .bottoms, colorRole: .none,
                 reason: isSpanish ? "El comodín casual que nunca falla." : "The casual workhorse that never fails."),
            Spec(slot: .blazer,
                 title: isSpanish ? "Blazer" : "Blazer",
                 category: .outerwear, colorRole: .neutral,
                 reason: isSpanish ? "Eleva al instante cualquier conjunto." : "Instantly elevates any outfit."),
            Spec(slot: .coat,
                 title: isSpanish ? "Abrigo neutro" : "Neutral coat",
                 category: .outerwear, colorRole: .neutral,
                 reason: isSpanish ? "Pieza ancla para el invierno que combina con toda la cápsula." : "A winter anchor that ties the whole capsule together."),
            Spec(slot: .sneakers,
                 title: isSpanish ? "Zapatillas blancas" : "White sneakers",
                 category: .shoes, colorRole: .none,
                 reason: isSpanish ? "Comodidad limpia para looks casual." : "Clean comfort for casual looks."),
            Spec(slot: .shoes,
                 title: isSpanish ? "Zapato de vestir" : "Smart leather shoes",
                 category: .shoes, colorRole: .none,
                 reason: isSpanish ? "Para ocasiones que piden más formalidad." : "For occasions that call for more polish."),
            Spec(slot: .bag,
                 title: isSpanish ? "Bolso / cartera versátil" : "Versatile bag",
                 category: .accessories, colorRole: .neutral,
                 reason: isSpanish ? "Un neutro que acompaña casi cualquier look." : "A neutral that carries almost any look.")
        ]

        if isWoman {
            specs.insert(
                Spec(slot: .dress,
                     title: isSpanish ? "Vestido comodín" : "Versatile dress",
                     category: .dresses, colorRole: .best,
                     reason: isSpanish ? "Un vestido en tu paleta resuelve eventos en segundos." : "One on-palette dress solves events in seconds."),
                at: 5
            )
        }

        return specs
    }

    private static func bodyShapeTip(for slot: Slot, shape: BodyShape?, isSpanish: Bool) -> String? {
        guard let shape else { return nil }
        switch (slot, shape) {
        case (.blazer, .triangle), (.top, .triangle), (.shirt, .triangle):
            return isSpanish ? "Busca hombros con algo de estructura para equilibrar las caderas." : "Choose a little shoulder structure to balance the hips."
        case (.blazer, .invertedTriangle), (.top, .invertedTriangle):
            return isSpanish ? "Prefiere hombros limpios y caída suave." : "Prefer clean shoulders and a soft drape."
        case (.trousers, .triangle), (.jeans, .triangle):
            return isSpanish ? "Cortes rectos o de pierna ancha equilibran la silueta." : "Straight or wide-leg cuts balance the silhouette."
        case (.blazer, .rectangle), (.dress, .rectangle), (.shirt, .rectangle):
            return isSpanish ? "Marca la cintura con corte entallado o cinturón." : "Define the waist with a fitted cut or a belt."
        case (.dress, .hourglass), (.blazer, .hourglass):
            return isSpanish ? "Entallado en la cintura para realzar tu equilibrio natural." : "Nipped at the waist to play up your natural balance."
        case (.top, .oval), (.dress, .oval), (.knit, .oval):
            return isSpanish ? "Líneas verticales y caída fluida alargan el torso." : "Vertical lines and fluid drape elongate the torso."
        default:
            return nil
        }
    }
}
