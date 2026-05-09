import UIKit
import Vision

struct ClothingClassificationResult {
    let category: ClothingCategory
    let colors: [String]
    let confidence: Float
    let styleTags: [String]
    let materialTags: [String]
    let occasionTags: [String]
    let detailTags: [String]
    let labels: [String]
    let summary: String
    let suggestedName: String
}

struct ClosetPhotoMatch {
    let itemID: UUID
    let score: Double
    let reasons: [String]
}

enum ClassificationError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The selected garment image is invalid."
        }
    }
}

final class ClothingClassificationService: @unchecked Sendable {
    func classifyClothing(image: UIImage) async throws -> ClothingClassificationResult {
        guard let cgImage = image.cgImage else {
            throw ClassificationError.invalidImage
        }

        async let observationsResult = Self.classifyObservations(cgImage: cgImage)
        async let colorsResult = Self.extractColors(from: cgImage)

        let (identifiers, confidence) = await observationsResult
        let colors = await colorsResult

        return Self.buildResult(from: identifiers, colors: colors, imageSize: image.size, confidence: confidence)
    }

    func detectClosetMatches(in image: UIImage, against items: [ClothingItem]) async -> [ClosetPhotoMatch] {
        guard let metadata = try? await classifyClothing(image: image) else {
            return []
        }

        return items.compactMap { item in
            var score = 0.0
            var reasons: [String] = []

            if item.category == metadata.category {
                score += 0.45
                reasons.append("categoria")
            }

            let colorOverlap = Set(item.colorTags).intersection(metadata.colors)
            if !colorOverlap.isEmpty {
                score += min(Double(colorOverlap.count) * 0.18, 0.36)
                reasons.append("color")
            }

            let styleOverlap = Set(item.styleTags).intersection(metadata.styleTags)
            if !styleOverlap.isEmpty {
                score += min(Double(styleOverlap.count) * 0.1, 0.2)
                reasons.append("estilo")
            }

            let detailOverlap = Set(item.detailTags).intersection(metadata.detailTags)
            if !detailOverlap.isEmpty {
                score += min(Double(detailOverlap.count) * 0.06, 0.12)
                reasons.append("detalle")
            }

            guard score >= 0.35 else { return nil }
            return ClosetPhotoMatch(itemID: item.id, score: min(score, 1), reasons: reasons)
        }
        .sorted { $0.score > $1.score }
        .prefix(6)
        .map { $0 }
    }

    private static func classifyObservations(cgImage: CGImage) async -> ([String], Float) {
        await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error {
                    #if DEBUG
                    print("ClothingClassificationService classify callback failed: \(error.localizedDescription)")
                    #endif
                    continuation.resume(returning: ([], 0.4))
                    return
                }

                let observations = request.results as? [VNClassificationObservation] ?? []
                let identifiers = observations.map(\.identifier)
                continuation.resume(returning: (identifiers, observations.first?.confidence ?? 0.4))
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                #if DEBUG
                print("ClothingClassificationService classify perform failed: \(error.localizedDescription)")
                #endif
                continuation.resume(returning: ([], 0.4))
            }
        }
    }

    private static func buildResult(
        from identifiers: [String],
        colors: [String],
        imageSize: CGSize,
        confidence: Float
    ) -> ClothingClassificationResult {
        let normalizedIdentifiers = Array(identifiers.prefix(12).map { $0.lowercased() })
        let category = mapObservationToCategory(normalizedIdentifiers, imageSize: imageSize)

        var styleTags = OrderedTagSet()
        var materialTags = OrderedTagSet()
        var occasionTags = OrderedTagSet()
        var detailTags = OrderedTagSet()

        for identifier in normalizedIdentifiers {
            applyRuleSet(
                for: identifier,
                category: category,
                styleTags: &styleTags,
                materialTags: &materialTags,
                occasionTags: &occasionTags,
                detailTags: &detailTags
            )
        }

        addFallbackTags(
            for: category,
            colors: colors,
            imageSize: imageSize,
            styleTags: &styleTags,
            occasionTags: &occasionTags,
            detailTags: &detailTags
        )

        let labels = OrderedTagSet()
            .adding(contentsOf: colors)
            .adding(contentsOf: styleTags.values)
            .adding(contentsOf: materialTags.values)
            .adding(contentsOf: occasionTags.values)
            .adding(contentsOf: detailTags.values)
            .values

        let garmentLabel = primaryGarmentLabel(for: category, identifiers: normalizedIdentifiers)
        let primaryColor = colors.first ?? fallbackColor(for: category)
        let suggestedName = "\(garmentLabel) \(primaryColor)".trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = buildSummary(
            garmentLabel: garmentLabel,
            primaryColor: primaryColor,
            styleTags: styleTags.values,
            materialTags: materialTags.values,
            occasionTags: occasionTags.values,
            detailTags: detailTags.values
        )

        return ClothingClassificationResult(
            category: category,
            colors: Array(colors.prefix(4)),
            confidence: confidence,
            styleTags: Array(styleTags.values.prefix(6)),
            materialTags: Array(materialTags.values.prefix(4)),
            occasionTags: Array(occasionTags.values.prefix(4)),
            detailTags: Array(detailTags.values.prefix(8)),
            labels: Array(labels.prefix(18)),
            summary: summary,
            suggestedName: suggestedName
        )
    }

    private static func mapObservationToCategory(_ identifiers: [String], imageSize: CGSize) -> ClothingCategory {
        for identifier in identifiers {
            if containsAny(identifier, ["dress", "gown"]) { return .dresses }
            if containsAny(identifier, ["shoe", "sneaker", "boot", "sandal", "heel", "loafer"]) { return .shoes }
            if containsAny(identifier, ["bag", "purse", "hat", "cap", "watch", "jewelry", "belt", "scarf", "tie", "sunglasses"]) { return .accessories }
            if containsAny(identifier, ["coat", "jacket", "blazer", "parka", "trench", "windbreaker", "outerwear"]) { return .outerwear }
            if containsAny(identifier, ["legging", "pant", "trouser", "jean", "short", "skirt"]) { return .bottoms }
            if containsAny(identifier, ["hoodie", "sports bra", "track", "running", "gym", "athletic", "yoga", "workout"]) { return .activewear }
            if containsAny(identifier, ["bikini", "swimsuit", "swimwear", "bathing"]) { return .swimwear }
            if containsAny(identifier, ["shirt", "blouse", "top", "tee", "t-shirt", "polo", "tank", "sweater", "cardigan"]) { return .tops }
        }

        let aspectRatio = imageSize.height / max(imageSize.width, 1)
        if aspectRatio > 1.35 { return .dresses }
        return .tops
    }

    private static func applyRuleSet(
        for identifier: String,
        category: ClothingCategory,
        styleTags: inout OrderedTagSet,
        materialTags: inout OrderedTagSet,
        occasionTags: inout OrderedTagSet,
        detailTags: inout OrderedTagSet
    ) {
        if containsAny(identifier, ["denim", "jean"]) {
            materialTags.append("Denim")
            styleTags.append("Casual")
        }
        if containsAny(identifier, ["leather", "suede"]) {
            materialTags.append("Leather")
            styleTags.append("Statement")
        }
        if containsAny(identifier, ["linen"]) { materialTags.append("Linen") }
        if containsAny(identifier, ["cotton", "tee", "t-shirt"]) { materialTags.append("Cotton") }
        if containsAny(identifier, ["wool", "cashmere", "knit", "sweater", "cardigan"]) {
            materialTags.append("Knit")
            detailTags.append("Textured")
        }
        if containsAny(identifier, ["silk", "satin", "chiffon"]) {
            materialTags.append("Fluid")
            styleTags.append("Elegant")
            occasionTags.append("Noche")
        }

        if containsAny(identifier, ["blazer", "tailored", "suit", "trouser", "loafer"]) {
            styleTags.append("Smart")
            styleTags.append("Office")
            occasionTags.append("Trabajo")
        }
        if containsAny(identifier, ["gown", "heel", "party", "cocktail"]) {
            styleTags.append("Formal")
            occasionTags.append("Evento")
        }
        if containsAny(identifier, ["hoodie", "sneaker", "jogger", "legging", "track"]) {
            styleTags.append("Sport")
            occasionTags.append("Activo")
        }
        if containsAny(identifier, ["street", "cargo", "oversized", "bomber"]) {
            styleTags.append("Streetwear")
        }
        if containsAny(identifier, ["minimal", "clean"]) {
            styleTags.append("Minimal")
        }

        if containsAny(identifier, ["striped", "stripe"]) { detailTags.append("Rayas") }
        if containsAny(identifier, ["floral", "flower"]) { detailTags.append("Floral") }
        if containsAny(identifier, ["plaid", "check", "checked"]) { detailTags.append("Cuadros") }
        if containsAny(identifier, ["print", "graphic"]) { detailTags.append("Estampado") }
        if containsAny(identifier, ["plain", "solid"]) { detailTags.append("Liso") }
        if containsAny(identifier, ["button", "buttoned"]) { detailTags.append("Botones") }
        if containsAny(identifier, ["zip", "zipper"]) { detailTags.append("Cremallera") }
        if containsAny(identifier, ["hood"]) { detailTags.append("Capucha") }
        if containsAny(identifier, ["pleat", "pleated"]) { detailTags.append("Pliegues") }
        if containsAny(identifier, ["ruffle"]) { detailTags.append("Volantes") }
        if containsAny(identifier, ["pocket"]) { detailTags.append("Bolsillos") }
        if containsAny(identifier, ["collar"]) { detailTags.append("Cuello") }
        if containsAny(identifier, ["v-neck"]) { detailTags.append("Escote pico") }
        if containsAny(identifier, ["crew neck", "round neck"]) { detailTags.append("Cuello redondo") }
        if containsAny(identifier, ["long sleeve"]) { detailTags.append("Manga larga") }
        if containsAny(identifier, ["short sleeve"]) { detailTags.append("Manga corta") }
        if containsAny(identifier, ["sleeveless", "tank"]) { detailTags.append("Sin mangas") }
        if containsAny(identifier, ["cropped", "crop"]) { detailTags.append("Cropped") }
        if containsAny(identifier, ["oversized"]) { detailTags.append("Oversized") }
        if containsAny(identifier, ["high waist"]) { detailTags.append("Tiro alto") }
        if containsAny(identifier, ["wide leg"]) { detailTags.append("Pierna ancha") }
        if containsAny(identifier, ["slim", "skinny"]) { detailTags.append("Slim fit") }
        if containsAny(identifier, ["midi"]) { detailTags.append("Midi") }
        if containsAny(identifier, ["maxi"]) { detailTags.append("Maxi") }
        if containsAny(identifier, ["mini"]) { detailTags.append("Mini") }

        if category == .outerwear && !styleTags.contains("Layering") {
            styleTags.append("Layering")
        }
    }

    private static func addFallbackTags(
        for category: ClothingCategory,
        colors: [String],
        imageSize: CGSize,
        styleTags: inout OrderedTagSet,
        occasionTags: inout OrderedTagSet,
        detailTags: inout OrderedTagSet
    ) {
        switch category {
        case .tops:
            detailTags.append("Parte superior")
            styleTags.append("Versatile")
        case .bottoms:
            detailTags.append("Parte inferior")
            styleTags.append("Wardrobe staple")
        case .dresses:
            detailTags.append("One-piece")
            occasionTags.append("Looks completos")
        case .shoes:
            detailTags.append("Calzado")
        case .accessories:
            detailTags.append("Complemento")
        case .outerwear:
            detailTags.append("Capa exterior")
            occasionTags.append("Entretiempo")
        case .activewear:
            styleTags.append("Performance")
            occasionTags.append("Activo")
        case .swimwear:
            styleTags.append("Resort")
            occasionTags.append("Vacaciones")
        }

        let aspectRatio = imageSize.height / max(imageSize.width, 1)
        if aspectRatio > 1.45, category == .bottoms {
            detailTags.append("Largo")
        } else if aspectRatio < 0.9, category == .tops {
            detailTags.append("Recto")
        }

        if colors.contains("Negro") || colors.contains("Blanco") || colors.contains("Gris") {
            styleTags.append("Neutral")
        }
    }

    private static func primaryGarmentLabel(for category: ClothingCategory, identifiers: [String]) -> String {
        for identifier in identifiers {
            if containsAny(identifier, ["blazer"]) { return "Blazer" }
            if containsAny(identifier, ["jacket"]) { return "Chaqueta" }
            if containsAny(identifier, ["coat", "trench"]) { return "Abrigo" }
            if containsAny(identifier, ["shirt", "blouse"]) { return "Camisa" }
            if containsAny(identifier, ["t-shirt", "tee"]) { return "Camiseta" }
            if containsAny(identifier, ["sweater", "cardigan"]) { return "Jersey" }
            if containsAny(identifier, ["hoodie"]) { return "Sudadera" }
            if containsAny(identifier, ["jean"]) { return "Jeans" }
            if containsAny(identifier, ["trouser", "pant"]) { return "Pantalón" }
            if containsAny(identifier, ["skirt"]) { return "Falda" }
            if containsAny(identifier, ["dress", "gown"]) { return "Vestido" }
            if containsAny(identifier, ["sneaker"]) { return "Sneakers" }
            if containsAny(identifier, ["boot"]) { return "Botas" }
            if containsAny(identifier, ["heel"]) { return "Tacones" }
            if containsAny(identifier, ["bag", "purse"]) { return "Bolso" }
            if containsAny(identifier, ["scarf"]) { return "Bufanda" }
        }

        switch category {
        case .tops: return "Top"
        case .bottoms: return "Pantalón"
        case .dresses: return "Vestido"
        case .shoes: return "Zapato"
        case .accessories: return "Accesorio"
        case .outerwear: return "Abrigo"
        case .activewear: return "Prenda deportiva"
        case .swimwear: return "Bañador"
        }
    }

    private static func fallbackColor(for category: ClothingCategory) -> String {
        switch category {
        case .accessories: return "Neutro"
        default: return "Principal"
        }
    }

    private static func buildSummary(
        garmentLabel: String,
        primaryColor: String,
        styleTags: [String],
        materialTags: [String],
        occasionTags: [String],
        detailTags: [String]
    ) -> String {
        var parts = ["\(garmentLabel) en tono \(primaryColor.lowercased())"]

        if let firstStyle = styleTags.first {
            parts.append("estilo \(firstStyle.lowercased())")
        }
        if let firstMaterial = materialTags.first {
            parts.append("acabado \(firstMaterial.lowercased())")
        }
        if let firstOccasion = occasionTags.first {
            parts.append("pensado para \(firstOccasion.lowercased())")
        }
        if !detailTags.isEmpty {
            parts.append("detalles: \(detailTags.prefix(3).joined(separator: ", ").lowercased())")
        }

        return parts.joined(separator: ", ")
    }

    private static func extractColors(from cgImage: CGImage) async -> [String] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let width = min(cgImage.width, 120)
                let height = min(cgImage.height, 120)

                guard let context = CGContext(
                    data: nil,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else {
                    continuation.resume(returning: [])
                    return
                }

                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

                guard let data = context.data else {
                    continuation.resume(returning: [])
                    return
                }

                let pointer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
                var colorCounts: [String: Int] = [:]

                for y in stride(from: 0, to: height, by: 4) {
                    for x in stride(from: 0, to: width, by: 4) {
                        let offset = (y * width + x) * 4
                        let r = Int(pointer[offset])
                        let g = Int(pointer[offset + 1])
                        let b = Int(pointer[offset + 2])
                        let alpha = Int(pointer[offset + 3])

                        guard alpha > 35 else { continue }

                        let colorName = classifyColor(r: r, g: g, b: b)
                        colorCounts[colorName, default: 0] += 1
                    }
                }

                let sorted = colorCounts.sorted { $0.value > $1.value }
                continuation.resume(returning: Array(sorted.prefix(4).map(\.key)))
            }
        }
    }

    private static func classifyColor(r: Int, g: Int, b: Int) -> String {
        let maxComponent = Double(max(r, g, b))
        let minComponent = Double(min(r, g, b))
        let brightness = maxComponent / 255.0
        let saturation = maxComponent == 0 ? 0 : (maxComponent - minComponent) / maxComponent

        if saturation < 0.12 {
            if brightness < 0.18 { return "Negro" }
            if brightness < 0.38 { return "Gris oscuro" }
            if brightness < 0.7 { return "Gris" }
            if brightness < 0.9 { return "Blanco roto" }
            return "Blanco"
        }

        let delta = maxComponent - minComponent
        var hue: Double

        if maxComponent == Double(r) {
            hue = 60 * (((Double(g) - Double(b)) / delta).truncatingRemainder(dividingBy: 6))
        } else if maxComponent == Double(g) {
            hue = 60 * (((Double(b) - Double(r)) / delta) + 2)
        } else {
            hue = 60 * (((Double(r) - Double(g)) / delta) + 4)
        }

        if hue < 0 { hue += 360 }

        if brightness < 0.32 {
            if hue < 25 || hue >= 345 { return "Burdeos" }
            if hue < 55 { return "Marrón" }
            if hue < 170 { return "Verde oscuro" }
            if hue < 265 { return "Azul marino" }
            return "Morado oscuro"
        }

        if brightness > 0.78 && saturation < 0.35 {
            if hue < 55 { return "Beige" }
            if hue < 170 { return "Verde suave" }
            if hue < 265 { return "Azul claro" }
            return "Rosa claro"
        }

        if hue < 15 || hue >= 345 { return "Rojo" }
        if hue < 40 { return "Naranja" }
        if hue < 60 { return "Mostaza" }
        if hue < 85 { return "Amarillo" }
        if hue < 165 { return "Verde" }
        if hue < 200 { return "Turquesa" }
        if hue < 255 { return brightness < 0.55 ? "Azul" : "Azul claro" }
        if hue < 290 { return "Morado" }
        if hue < 330 { return "Rosa" }
        return "Rojo"
    }

    private static func containsAny(_ source: String, _ keywords: [String]) -> Bool {
        keywords.contains { source.contains($0) }
    }
}

private struct OrderedTagSet {
    private(set) var values: [String] = []

    init(_ values: [String] = []) {
        self.values = []
        values.forEach { append($0) }
    }

    mutating func append(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !values.contains(trimmed) else { return }
        values.append(trimmed)
    }

    func contains(_ value: String) -> Bool {
        values.contains(value)
    }

    func adding(contentsOf values: [String]) -> OrderedTagSet {
        var copy = self
        values.forEach { copy.append($0) }
        return copy
    }
}
