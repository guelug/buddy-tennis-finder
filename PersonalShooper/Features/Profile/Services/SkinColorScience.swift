import Foundation
import UIKit

/// Science-backed skin-color analysis used to drive seasonal color classification.
///
/// Instead of eyeballing raw RGB, this converts skin samples to the **CIELAB** perceptual color
/// space and derives the two measures the dermatology / color-analysis literature actually uses:
///
/// - **Depth** via the **Individual Typology Angle (ITA°)** — `atan2(L*−50, b*)` in degrees — the
///   standard skin-classification metric (Chardon et al. 1991; Del Bino et al. 2013). Bucketed into
///   the well-established very-light → dark bands.
/// - **Undertone** via the CIELAB hue balance (`b*` yellow vs `a*` red): golden/olive skin pushes
///   `b*` up (warm), rosy/pink skin pushes `a*` up (cool).
/// - **Clarity** (bright vs muted) from skin chroma `C* = √(a*²+b*²)` combined with face contrast
///   (skin lightness vs the darkest features — hair/brows/eyes), which is the third axis of the
///   12-season system (value/chroma/clarity).
///
/// All inputs are robust **medians** of skin-only samples, so a stray eyebrow or background pixel
/// can't swing the result the way a mean would.
enum SkinColorScience {

    // MARK: - Public result

    struct Result {
        let lab: LabColor
        let ita: Double
        let chroma: Double
        let undertone: Undertone
        let undertoneConfidence: Double
        let depth: SkinToneCategory
        let seasonalType: SeasonalType
    }

    struct LabColor {
        let L: Double
        let a: Double
        let b: Double
    }

    // MARK: - Entry point

    /// Analyzes robust skin samples. `contrast` is an optional 0…1 measure of how much darker the
    /// person's features (hair/brows/eyes) are than their skin — when available it sharpens the
    /// bright-vs-muted (clarity) decision; pass `nil` to infer clarity from chroma alone.
    static func analyze(skinSamples: [UIColor], contrast: Double? = nil) -> Result? {
        let labs = skinSamples.compactMap(lab(from:))
        guard labs.count >= 3 else { return nil }

        let lab = LabColor(
            L: median(labs.map(\.L)),
            a: median(labs.map(\.a)),
            b: median(labs.map(\.b))
        )

        let ita = atan2(lab.L - 50.0, lab.b) * 180.0 / .pi
        let chroma = (lab.a * lab.a + lab.b * lab.b).squareRoot()

        let depth = depthCategory(ita: ita)
        let (undertone, undertoneConfidence) = undertone(lab: lab)
        let clarity = clarity(chroma: chroma, contrast: contrast)
        let season = seasonalType(depth: depth, undertone: undertone, clarity: clarity)

        return Result(
            lab: lab,
            ita: ita,
            chroma: chroma,
            undertone: undertone,
            undertoneConfidence: undertoneConfidence,
            depth: depth,
            seasonalType: season
        )
    }

    // MARK: - Depth (ITA°)

    /// ITA° bands (Chardon 1991 / Del Bino 2013) collapsed onto the app's 5 depth categories.
    static func depthCategory(ita: Double) -> SkinToneCategory {
        switch ita {
        case 55...:      return .fair       // very light
        case 41..<55:    return .light      // light
        case 28..<41:    return .medium     // intermediate
        case 10..<28:    return .tan        // tan
        default:         return .dark       // brown + dark
        }
    }

    // MARK: - Undertone (CIELAB hue balance)

    /// Warm skin carries more yellow (`b*`) than red (`a*`); cool skin the reverse. The signed
    /// `warmth = b* − a*` is the interpretable balance; thresholds sit around the population skin
    /// average. Confidence scales with how far from neutral the balance is.
    static func undertone(lab: LabColor) -> (Undertone, Double) {
        let warmth = lab.b - lab.a
        let undertone: Undertone
        if warmth >= 8 {
            undertone = .warm
        } else if warmth <= 3 {
            undertone = .cool
        } else {
            undertone = .neutral
        }
        // Distance from the neutral pivot (~5.5) → confidence.
        let confidence = min(0.95, max(0.45, abs(warmth - 5.5) / 6.0))
        return (undertone, confidence)
    }

    // MARK: - Clarity (bright vs muted)

    enum Clarity { case bright, muted }

    /// Higher skin chroma and/or strong skin-to-feature contrast read as "bright/clear"; low chroma
    /// and low contrast read as "muted/soft".
    static func clarity(chroma: Double, contrast: Double?) -> Clarity {
        // Skin chroma typically spans ~12 (muted) … ~28 (vivid). Normalize to 0…1.
        let chromaScore = min(1.0, max(0.0, (chroma - 12.0) / 16.0))
        let contrastScore = contrast.map { min(1.0, max(0.0, $0)) } ?? chromaScore
        let clarityScore = (chromaScore + contrastScore) / 2.0
        return clarityScore >= 0.5 ? .bright : .muted
    }

    // MARK: - 12-season mapping (depth × undertone × clarity)

    static func seasonalType(depth: SkinToneCategory, undertone: Undertone, clarity: Clarity) -> SeasonalType {
        let bright = clarity == .bright
        let band = depthBand(depth)

        switch undertone {
        case .warm:
            switch band {
            case .light: return bright ? .brightSpring : .lightSpring
            case .medium: return bright ? .spring : .softAutumn
            case .deep: return bright ? .autumn : .darkAutumn
            }
        case .cool:
            switch band {
            case .light: return bright ? .lightSummer : .softSummer
            case .medium: return bright ? .summer : .softSummer
            case .deep: return bright ? .brightWinter : .darkWinter
            }
        case .neutral:
            switch band {
            case .light: return bright ? .lightSpring : .lightSummer
            case .medium: return bright ? .spring : .softSummer
            case .deep: return bright ? .winter : .softAutumn
            }
        }
    }

    private enum DepthBand { case light, medium, deep }

    private static func depthBand(_ category: SkinToneCategory) -> DepthBand {
        switch category {
        case .fair, .light: return .light
        case .medium: return .medium
        case .tan, .dark: return .deep
        }
    }

    // MARK: - sRGB → CIELAB (D65)

    static func lab(from color: UIColor) -> LabColor? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &alpha) else { return nil }

        let rl = linearize(Double(r))
        let gl = linearize(Double(g))
        let bl = linearize(Double(b))

        // sRGB → XYZ (D65)
        let x = rl * 0.4124564 + gl * 0.3575761 + bl * 0.1804375
        let y = rl * 0.2126729 + gl * 0.7151522 + bl * 0.0721750
        let z = rl * 0.0193339 + gl * 0.1191920 + bl * 0.9503041

        // Normalize by D65 reference white.
        let fx = pivot(x / 0.95047)
        let fy = pivot(y / 1.00000)
        let fz = pivot(z / 1.08883)

        return LabColor(
            L: 116.0 * fy - 16.0,
            a: 500.0 * (fx - fy),
            b: 200.0 * (fy - fz)
        )
    }

    private static func linearize(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private static func pivot(_ t: Double) -> Double {
        t > 0.008856 ? Foundation.cbrt(t) : (7.787 * t + 16.0 / 116.0)
    }

    // MARK: - Robust statistics

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2.0
        }
        return sorted[mid]
    }
}
