import Foundation

/// Shared professional image-consulting knowledge injected into every chat backend (on-device,
/// BYOK, connected) so the stylist reasons like a trained image consultant rather than giving
/// generic fashion tips. Centralized here so the persona stays consistent across providers.
enum ImageConsulting {

    /// Compact professional framework appended to the system prompt. Kept tight so it doesn't blow
    /// the on-device token budget while still anchoring the model in real consulting methodology.
    static func professionalGuidelines(language: Language) -> [String] {
        if language == .spanish {
            return [
                "Trabaja como consultor de imagen profesional usando estos marcos:",
                "• Color: viste dentro de la estación del usuario; coloca sus mejores colores cerca del rostro, usa neutros como base y los colores statement como acento; mantén lejos de la cara los colores a evitar.",
                "• Contraste: ajusta el contraste del conjunto al contraste natural de la persona (coloración de alto contraste → combina claro+oscuro; bajo contraste → tonal/monocromo suave).",
                "• Silueta: busca proporciones equilibradas según su forma corporal (define la cintura en reloj de arena; estructura hombros en triángulo; suaviza hombros en triángulo invertido; crea curvas y cintura en rectángulo; alarga y desliza en óvalo).",
                "• Proporción: aplica la regla de los tercios (evita cortar el cuerpo por la mitad), usa líneas verticales para alargar y ajusta la escala de la prenda al tamaño de la persona.",
                "• Ocasión: calibra la formalidad al evento y da una fórmula de outfit clara (parte de arriba + parte de abajo + capa + calzado + un acento).",
                "• Armario: prioriza piezas versátiles que combinen con lo que ya tiene; sugiere adiciones tipo cápsula cuando falte algo.",
            ]
        }
        return [
            "Operate as a professional image consultant using these frameworks:",
            "• Color: dress within the user's season; place their best colors near the face, use neutrals as the base and statement colors as accents; keep avoid-colors away from the face.",
            "• Contrast: match the outfit's value-contrast to the person's natural contrast (high-contrast coloring → pair light+dark; low-contrast → tonal/soft monochrome).",
            "• Silhouette: aim for balanced proportions for their body shape (define the waist for hourglass; add shoulder structure for pear/triangle; soften shoulders for inverted triangle; create waist/curves for rectangle; elongate and skim for apple/oval).",
            "• Proportion: apply the rule of thirds (avoid cutting the body in half), use vertical lines to elongate, and match garment scale to the person's frame.",
            "• Occasion: calibrate formality to the event and give a clear outfit formula (top + bottom + layer + shoes + one accent).",
            "• Wardrobe: favor versatile pieces that mix with what they already own; suggest capsule additions when something is missing.",
        ]
    }

    /// Derives a body-silhouette note from measurements, expressed as a neutral, body-positive
    /// styling goal (never a judgment). Returns nil when there isn't enough data.
    ///
    /// Uses the standard image-consulting silhouette model from bust/chest, waist and hip balance.
    static func bodyShapeNote(chestCm: Double?, waistCm: Double?, hipsCm: Double?, language: Language) -> String? {
        guard let chest = chestCm, let waist = waistCm, let hips = hipsCm,
              chest > 0, waist > 0, hips > 0 else { return nil }

        let isSpanish = language == .spanish
        let shape: Shape

        let topToHip = chest / hips
        let waistToHip = waist / hips
        let waistDefined = waistToHip <= 0.75

        if waist >= chest && waist >= hips {
            shape = .apple
        } else if topToHip >= 1.05 {
            shape = .invertedTriangle
        } else if topToHip <= 0.95 {
            shape = .triangle
        } else if waistDefined {
            shape = .hourglass
        } else {
            shape = .rectangle
        }

        let name = shape.name(isSpanish: isSpanish)
        let goal = shape.stylingGoal(isSpanish: isSpanish)
        return isSpanish
            ? "Silueta (derivada de las medidas, úsala solo para guiar el corte, nunca para juzgar el cuerpo): \(name) — \(goal)"
            : "Silhouette (derived from measurements; use only to guide cut, never to judge the body): \(name) — \(goal)"
    }

    private enum Shape {
        case hourglass, triangle, invertedTriangle, rectangle, apple

        func name(isSpanish: Bool) -> String {
            switch self {
            case .hourglass: return isSpanish ? "reloj de arena" : "hourglass"
            case .triangle: return isSpanish ? "triángulo (pera)" : "triangle (pear)"
            case .invertedTriangle: return isSpanish ? "triángulo invertido" : "inverted triangle"
            case .rectangle: return isSpanish ? "rectángulo" : "rectangle"
            case .apple: return isSpanish ? "óvalo (manzana)" : "oval (apple)"
            }
        }

        func stylingGoal(isSpanish: Bool) -> String {
            switch self {
            case .hourglass:
                return isSpanish
                    ? "realza la cintura y mantén las proporciones equilibradas con prendas entalladas."
                    : "emphasize the waist and keep proportions balanced with fitted shapes."
            case .triangle:
                return isSpanish
                    ? "aporta estructura y volumen a los hombros y mantén la parte inferior limpia para equilibrar las caderas."
                    : "add structure/volume to the shoulders and keep the lower half clean to balance the hips."
            case .invertedTriangle:
                return isSpanish
                    ? "suaviza los hombros y añade volumen o detalle en la parte inferior para equilibrar."
                    : "soften the shoulders and add volume or detail on the lower half to balance."
            case .rectangle:
                return isSpanish
                    ? "crea curvas y define la cintura con capas, cinturones y prendas entalladas."
                    : "create curves and define the waist with layering, belts and fitted pieces."
            case .apple:
                return isSpanish
                    ? "alarga el torso con líneas verticales y prendas que deslizan, llevando la atención a piernas y escote."
                    : "elongate the torso with vertical lines and skimming pieces, drawing attention to legs and neckline."
            }
        }
    }
}
