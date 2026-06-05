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

    /// Derives a body-shape from measurements when one wasn't auto-detected from a photo.
    /// Uses the standard image-consulting silhouette model from bust/chest, waist and hip balance.
    static func bodyShape(chestCm: Double?, waistCm: Double?, hipsCm: Double?) -> BodyShape? {
        guard let chest = chestCm, let waist = waistCm, let hips = hipsCm,
              chest > 0, waist > 0, hips > 0 else { return nil }

        let topToHip = chest / hips
        let waistDefined = (waist / hips) <= 0.75

        if waist >= chest && waist >= hips { return .oval }
        if topToHip >= 1.05 { return .invertedTriangle }
        if topToHip <= 0.95 { return .triangle }
        return waistDefined ? .hourglass : .rectangle
    }

    /// Body-silhouette prompt line, expressed as a neutral, body-positive styling goal.
    static func bodyShapeNote(_ shape: BodyShape, language: Language) -> String {
        language == .spanish
            ? "Silueta (úsala solo para guiar el corte, nunca para juzgar el cuerpo): \(shape.displayName(language)) — \(shape.stylingGoal(language))"
            : "Silhouette (use only to guide cut, never to judge the body): \(shape.displayName(language)) — \(shape.stylingGoal(language))"
    }

    /// Convenience that derives the body shape from measurements and returns the prompt line.
    static func bodyShapeNote(chestCm: Double?, waistCm: Double?, hipsCm: Double?, language: Language) -> String? {
        guard let shape = bodyShape(chestCm: chestCm, waistCm: waistCm, hipsCm: hipsCm) else { return nil }
        return bodyShapeNote(shape, language: language)
    }

    /// Face-shape prompt line for neckline / collar / accessory guidance.
    static func faceShapeNote(_ shape: FaceShape, language: Language) -> String {
        language == .spanish
            ? "Forma de rostro: \(shape.displayName(language)) — \(shape.stylingGoal(language))"
            : "Face shape: \(shape.displayName(language)) — \(shape.stylingGoal(language))"
    }

    /// Personal-contrast prompt line for value-combination guidance.
    static func contrastNote(_ level: ContrastLevel, language: Language) -> String {
        language == .spanish
            ? "Contraste personal: \(level.displayName(language)) — \(level.stylingGoal(language))"
            : "Personal contrast: \(level.displayName(language)) — \(level.stylingGoal(language))"
    }
}
