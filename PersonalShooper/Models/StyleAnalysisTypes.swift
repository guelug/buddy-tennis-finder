import Foundation

// MARK: - Body Shape

/// Image-consulting body silhouettes. Used for fit/cut guidance — never as a judgment of the body.
enum BodyShape: String, Codable, CaseIterable {
    case hourglass
    case triangle          // "pear": hips wider than shoulders
    case invertedTriangle  // shoulders wider than hips
    case rectangle
    case oval              // "apple": waist is the widest point

    func displayName(_ language: Language) -> String {
        let isSpanish = language == .spanish
        switch self {
        case .hourglass: return isSpanish ? "Reloj de arena" : "Hourglass"
        case .triangle: return isSpanish ? "Triángulo (pera)" : "Triangle (pear)"
        case .invertedTriangle: return isSpanish ? "Triángulo invertido" : "Inverted triangle"
        case .rectangle: return isSpanish ? "Rectángulo" : "Rectangle"
        case .oval: return isSpanish ? "Óvalo (manzana)" : "Oval (apple)"
        }
    }

    /// Neutral, body-positive styling goal — what to emphasize, not what to "fix".
    func stylingGoal(_ language: Language) -> String {
        let isSpanish = language == .spanish
        switch self {
        case .hourglass:
            return isSpanish
                ? "Realza la cintura y mantén las proporciones equilibradas con prendas entalladas."
                : "Emphasize the waist and keep proportions balanced with fitted shapes."
        case .triangle:
            return isSpanish
                ? "Aporta estructura y volumen a los hombros y mantén la parte inferior limpia para equilibrar las caderas."
                : "Add structure and volume to the shoulders and keep the lower half clean to balance the hips."
        case .invertedTriangle:
            return isSpanish
                ? "Suaviza los hombros y añade volumen o detalle en la parte inferior para equilibrar."
                : "Soften the shoulders and add volume or detail on the lower half to balance."
        case .rectangle:
            return isSpanish
                ? "Crea curvas y define la cintura con capas, cinturones y prendas entalladas."
                : "Create curves and define the waist with layering, belts and fitted pieces."
        case .oval:
            return isSpanish
                ? "Alarga el torso con líneas verticales y prendas que deslizan, llevando la atención a piernas y escote."
                : "Elongate the torso with vertical lines and skimming pieces, drawing attention to legs and neckline."
        }
    }
}

// MARK: - Face Shape

/// Face silhouettes used to guide necklines, collars, eyewear, earrings and hair volume.
enum FaceShape: String, Codable, CaseIterable {
    case oval
    case round
    case square
    case heart
    case oblong
    case diamond

    func displayName(_ language: Language) -> String {
        let isSpanish = language == .spanish
        switch self {
        case .oval: return isSpanish ? "Ovalado" : "Oval"
        case .round: return isSpanish ? "Redondo" : "Round"
        case .square: return isSpanish ? "Cuadrado" : "Square"
        case .heart: return isSpanish ? "Corazón" : "Heart"
        case .oblong: return isSpanish ? "Alargado" : "Oblong"
        case .diamond: return isSpanish ? "Diamante" : "Diamond"
        }
    }

    /// Neckline / collar / accessory guidance for this face shape.
    func stylingGoal(_ language: Language) -> String {
        let isSpanish = language == .spanish
        switch self {
        case .oval:
            return isSpanish
                ? "Casi todos los escotes te favorecen; mantén el equilibrio natural sin alargar de más."
                : "Almost every neckline suits you; keep the natural balance without over-elongating."
        case .round:
            return isSpanish
                ? "Alarga con escotes en V, cuellos abiertos y líneas verticales; evita cuellos redondos altos."
                : "Elongate with V-necks, open collars and vertical lines; avoid high round necklines."
        case .square:
            return isSpanish
                ? "Suaviza la mandíbula con escotes redondeados, cuellos barco y curvas; evita cuadrados marcados."
                : "Soften the jaw with rounded necklines, scoop and cowl necks; avoid sharp square shapes."
        case .heart:
            return isSpanish
                ? "Equilibra una frente más ancha con escotes que añaden anchura abajo (barco, halter suave)."
                : "Balance a wider forehead with necklines that add width below (boat, soft halter)."
        case .oblong:
            return isSpanish
                ? "Acorta visualmente con cuellos redondos, barco y altos; evita escotes en V muy profundos."
                : "Visually shorten with round, boat and higher necklines; avoid very deep V-necks."
        case .diamond:
            return isSpanish
                ? "Suaviza los pómulos con escotes que añaden anchura en la mandíbula y la frente."
                : "Soften the cheekbones with necklines that add width at the jaw and forehead."
        }
    }
}

// MARK: - Contrast Level

/// The user's natural value-contrast (skin lightness vs hair/feature darkness). Drives how much
/// light-to-dark contrast their outfits should carry to stay harmonious.
enum ContrastLevel: String, Codable, CaseIterable {
    case high
    case medium
    case low

    func displayName(_ language: Language) -> String {
        let isSpanish = language == .spanish
        switch self {
        case .high: return isSpanish ? "Alto" : "High"
        case .medium: return isSpanish ? "Medio" : "Medium"
        case .low: return isSpanish ? "Bajo" : "Low"
        }
    }

    /// How to combine outfit values for this contrast level.
    func stylingGoal(_ language: Language) -> String {
        let isSpanish = language == .spanish
        switch self {
        case .high:
            return isSpanish
                ? "Te lucen las combinaciones de alto contraste: claro con oscuro y colores nítidos."
                : "High-contrast pairings flatter you: light with dark and crisp, clear colors."
        case .medium:
            return isSpanish
                ? "Te favorece un contraste moderado: combina tonos medios sin saltos extremos."
                : "Moderate contrast suits you: combine mid tones without extreme jumps."
        case .low:
            return isSpanish
                ? "Te favorecen los conjuntos tonales y monocromáticos suaves, sin contrastes fuertes."
                : "Tonal and soft monochrome outfits suit you best, avoiding stark contrast."
        }
    }

    /// Derives the level from a 0…1 contrast measure (skin lightness minus darkest-feature lightness).
    static func from(contrast: Double) -> ContrastLevel {
        switch contrast {
        case 0.55...: return .high
        case 0.30..<0.55: return .medium
        default: return .low
        }
    }
}
