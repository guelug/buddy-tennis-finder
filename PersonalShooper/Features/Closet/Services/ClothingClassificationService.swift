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
    func classifyClothing(image: UIImage, prepareForAnalysis: Bool = true) async throws -> ClothingClassificationResult {
        let analysisImage = prepareForAnalysis
            ? await GarmentBackgroundRemovalService.prepareImage(image)
            : image

        guard let cgImage = analysisImage.cgImage else {
            throw ClassificationError.invalidImage
        }

        async let observationsResult = Self.classifyObservations(cgImage: cgImage)
        async let colorsResult = Self.extractColors(from: cgImage)

        let (identifiers, confidence) = await observationsResult
        let colors = await colorsResult

        return Self.buildResult(from: identifiers, colors: colors, imageSize: analysisImage.size, confidence: confidence)
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
                    AppLog.classification.error("classify callback failed: \(error.localizedDescription, privacy: .public)")
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
                AppLog.classification.error("classify perform failed: \(error.localizedDescription, privacy: .public)")
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
        let weightedKeywords: [(category: ClothingCategory, keywords: [String])] = [
            (.dresses, ["dress", "gown"]),
            (.shoes, ["shoe", "sneaker", "boot", "sandal", "heel", "loafer"]),
            (.accessories, ["bag", "purse", "hat", "cap", "watch", "jewelry", "belt", "scarf", "tie", "sunglasses"]),
            (.tops, ["shirt", "blouse", "top", "tee", "t-shirt", "polo", "tank", "sweater", "cardigan", "jersey", "camisa"]),
            (.outerwear, ["coat", "jacket", "blazer", "parka", "trench", "windbreaker", "outerwear"]),
            (.bottoms, ["legging", "pant", "trouser", "jean", "short", "skirt"]),
            (.activewear, ["hoodie", "sports bra", "track", "running", "gym", "athletic", "yoga", "workout"]),
            (.swimwear, ["bikini", "swimsuit", "swimwear", "bathing"])
        ]

        var scores: [ClothingCategory: Double] = [:]
        for (index, identifier) in identifiers.enumerated() {
            let positionWeight = max(0.25, 1.0 - Double(index) * 0.08)
            for rule in weightedKeywords where containsAny(identifier, rule.keywords) {
                scores[rule.category, default: 0] += positionWeight
            }
        }

        let aspectRatio = imageSize.height / max(imageSize.width, 1)
        if aspectRatio > 1.55 {
            scores[.dresses, default: 0] += 0.35
        } else if aspectRatio < 1.45 {
            scores[.tops, default: 0] += 0.2
        }

        let hasTopSignal = identifiers.contains { containsAny($0, ["shirt", "blouse", "top", "tee", "t-shirt", "polo", "tank", "sweater", "cardigan", "jersey"]) }
        let hasHardOuterwearSignal = identifiers.contains { containsAny($0, ["coat", "parka", "trench", "windbreaker", "outerwear", "blazer"]) }

        // Vision often labels laid-flat shirts as "jacket" because of sleeves/collar shape. Only
        // keep outerwear if there is a stronger coat/blazer signal or no clear top signal.
        if hasTopSignal && !hasHardOuterwearSignal {
            scores[.outerwear, default: 0] *= 0.45
            scores[.tops, default: 0] += 0.45
        }

        return scores.max { lhs, rhs in
            if lhs.value == rhs.value {
                return categoryTiePriority(lhs.key) < categoryTiePriority(rhs.key)
            }
            return lhs.value < rhs.value
        }?.key ?? .tops
    }

    private static func categoryTiePriority(_ category: ClothingCategory) -> Int {
        switch category {
        case .tops: return 8
        case .dresses: return 7
        case .bottoms: return 6
        case .shoes: return 5
        case .accessories: return 4
        case .activewear: return 3
        case .swimwear: return 2
        case .outerwear: return 1
        case .jewelry, .lingerie, .beauty: return 1
        }
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
        case .jewelry:
            detailTags.append("Joyería")
            styleTags.append("Accent")
        case .lingerie:
            detailTags.append("Lencería")
        case .beauty:
            detailTags.append("Belleza")
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
        case .jewelry: return "Joyería"
        case .lingerie: return "Lencería"
        case .beauty: return "Belleza"
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
                let targetLongestSide: CGFloat = 360
                let longestSide = CGFloat(max(cgImage.width, cgImage.height))
                let scale = longestSide > 0 ? targetLongestSide / longestSide : 1
                let width = max(Int(CGFloat(cgImage.width) * scale), 180)
                let height = max(Int(CGFloat(cgImage.height) * scale), 180)

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

                let centerX = Double(width) / 2
                let centerY = Double(height) / 2
                let maxDistance = hypot(centerX, centerY)

                var rawColors: [(r: Int, g: Int, b: Int, weight: Double)] = []

                for y in stride(from: 0, to: height, by: 2) {
                    for x in stride(from: 0, to: width, by: 2) {
                        let offset = (y * width + x) * 4
                        let r = Int(pointer[offset])
                        let g = Int(pointer[offset + 1])
                        let b = Int(pointer[offset + 2])
                        let alpha = Int(pointer[offset + 3])

                        guard alpha > 60 else { continue }
                        guard !isProbableBackgroundPixel(r: r, g: g, b: b, x: x, y: y, width: width, height: height) else { continue }

                        let distanceFromCenter = hypot(Double(x) - centerX, Double(y) - centerY) / max(maxDistance, 1)
                        let centerWeight = 1.0 + max(0, 1.0 - distanceFromCenter) * 1.8
                        let saturationWeight = 1.0 + colorSaturation(r: r, g: g, b: b) * 1.6
                        let edgePenalty = isNearImageEdge(x: x, y: y, width: width, height: height) ? 0.45 : 1.0

                        rawColors.append((r, g, b, centerWeight * saturationWeight * edgePenalty))
                    }
                }

                let clusters = clusterColors(rawColors, maxClusters: 6)

                let colorNames = clusters
                    .sorted { $0.weight > $1.weight }
                    .filter { !isWeakNeutralCluster($0) || clusters.count <= 2 }
                    .prefix(5)
                    .map { classifyColorImproved(r: $0.r, g: $0.g, b: $0.b) }

                var uniqueNames: [String] = []
                for name in colorNames {
                    if !uniqueNames.contains(name) {
                        uniqueNames.append(name)
                    }
                }

                continuation.resume(returning: uniqueNames.isEmpty ? ["Multicolor"] : uniqueNames)
            }
        }
    }

    private static func isProbableBackgroundPixel(r: Int, g: Int, b: Int, x: Int, y: Int, width: Int, height: Int) -> Bool {
        let brightness = Double(max(r, g, b)) / 255.0
        let sat = colorSaturation(r: r, g: g, b: b)

        if brightness > 0.9 && sat < 0.16 { return true }
        if brightness > 0.78 && sat < 0.07 { return true }

        if isNearImageEdge(x: x, y: y, width: width, height: height),
           brightness > 0.62,
           sat < 0.12 {
            return true
        }

        return false
    }

    private static func isNearImageEdge(x: Int, y: Int, width: Int, height: Int) -> Bool {
        let marginX = max(12, Int(Double(width) * 0.08))
        let marginY = max(12, Int(Double(height) * 0.08))
        return x < marginX || x > width - marginX || y < marginY || y > height - marginY
    }

    private static func colorSaturation(r: Int, g: Int, b: Int) -> Double {
        let maxComponent = Double(max(r, g, b))
        let minComponent = Double(min(r, g, b))
        guard maxComponent > 0 else { return 0 }
        return (maxComponent - minComponent) / maxComponent
    }

    private static func isWeakNeutralCluster(_ cluster: (r: Int, g: Int, b: Int, weight: Double)) -> Bool {
        let brightness = Double(max(cluster.r, cluster.g, cluster.b)) / 255.0
        let sat = colorSaturation(r: cluster.r, g: cluster.g, b: cluster.b)
        return brightness > 0.68 && sat < 0.1
    }

    private static func clusterColors(
        _ colors: [(r: Int, g: Int, b: Int, weight: Double)],
        maxClusters: Int
    ) -> [(r: Int, g: Int, b: Int, weight: Double)] {
        guard !colors.isEmpty else { return [] }

        // Inicializar clusters con los colores más frecuentes (k-means++ aproximado)
        var clusters: [(r: Double, g: Double, b: Double, weight: Double)] = []
        var usedIndices = Set<Int>()

        // Primer cluster: color con mayor peso
        if let first = colors.enumerated().max(by: { $0.element.weight < $1.element.weight }) {
            clusters.append((Double(first.element.r), Double(first.element.g), Double(first.element.b), first.element.weight))
            usedIndices.insert(first.offset)
        }

        // Siguientes clusters: color más lejano de los existentes
        while clusters.count < maxClusters && usedIndices.count < colors.count {
            var bestDistance: Double = -1
            var bestIndex: Int = -1

            for (index, color) in colors.enumerated() where !usedIndices.contains(index) {
                let minDistance = clusters.map { cluster in
                    colorDistance(
                        r1: color.r, g1: color.g, b1: color.b,
                        r2: Int(cluster.r), g2: Int(cluster.g), b2: Int(cluster.b)
                    )
                }.min() ?? 0

                if minDistance > bestDistance {
                    bestDistance = minDistance
                    bestIndex = index
                }
            }

            guard bestIndex >= 0, bestDistance > 30 else { break }

            let color = colors[bestIndex]
            clusters.append((Double(color.r), Double(color.g), Double(color.b), color.weight))
            usedIndices.insert(bestIndex)
        }

        // Asignar cada color al cluster más cercano y recalcular centroides
        var assignments: [Int] = Array(repeating: 0, count: colors.count)
        var changed = true
        var iterations = 0

        while changed && iterations < 20 {
            changed = false
            iterations += 1

            // Asignar
            for (index, color) in colors.enumerated() {
                var bestCluster = 0
                var bestDistance = colorDistance(
                    r1: color.r, g1: color.g, b1: color.b,
                    r2: Int(clusters[0].r), g2: Int(clusters[0].g), b2: Int(clusters[0].b)
                )

                for (clusterIndex, cluster) in clusters.enumerated().dropFirst() {
                    let distance = colorDistance(
                        r1: color.r, g1: color.g, b1: color.b,
                        r2: Int(cluster.r), g2: Int(cluster.g), b2: Int(cluster.b)
                    )
                    if distance < bestDistance {
                        bestDistance = distance
                        bestCluster = clusterIndex
                    }
                }

                if assignments[index] != bestCluster {
                    assignments[index] = bestCluster
                    changed = true
                }
            }

            // Recalcular centroides ponderados
            for clusterIndex in clusters.indices {
                var totalR: Double = 0
                var totalG: Double = 0
                var totalB: Double = 0
                var totalWeight: Double = 0

                for (index, color) in colors.enumerated() {
                    if assignments[index] == clusterIndex {
                        totalR += Double(color.r) * color.weight
                        totalG += Double(color.g) * color.weight
                        totalB += Double(color.b) * color.weight
                        totalWeight += color.weight
                    }
                }

                if totalWeight > 0 {
                    clusters[clusterIndex] = (
                        totalR / totalWeight,
                        totalG / totalWeight,
                        totalB / totalWeight,
                        totalWeight
                    )
                }
            }
        }

        return clusters.map { (
            r: Int(round($0.r)),
            g: Int(round($0.g)),
            b: Int(round($0.b)),
            weight: $0.weight
        ) }
    }

    private static func colorDistance(r1: Int, g1: Int, b1: Int, r2: Int, g2: Int, b2: Int) -> Double {
        // Distancia en espacio Lab aproximada (más perceptual que RGB simple)
        let lr1 = linearize(Double(r1) / 255.0)
        let lg1 = linearize(Double(g1) / 255.0)
        let lb1 = linearize(Double(b1) / 255.0)
        let lr2 = linearize(Double(r2) / 255.0)
        let lg2 = linearize(Double(g2) / 255.0)
        let lb2 = linearize(Double(b2) / 255.0)

        let dl = (lr1 - lr2) * 100
        let da = ((lg1 - lb1) - (lg2 - lb2)) * 100
        let db = ((lr1 * 2 - lg1 - lb1) - (lr2 * 2 - lg2 - lb2)) * 50

        return sqrt(dl * dl + da * da + db * db)
    }

    private static func linearize(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private static func classifyColorImproved(r: Int, g: Int, b: Int) -> String {
        let rf = Double(r) / 255.0
        let gf = Double(g) / 255.0
        let bf = Double(b) / 255.0

        let maxC = max(rf, gf, bf)
        let minC = min(rf, gf, bf)
        let brightness = maxC
        let saturation = maxC == 0 ? 0 : (maxC - minC) / maxC
        let chroma = maxC - minC

        // Colores muy poco saturados → grises
        if saturation < 0.08 {
            if brightness < 0.12 { return "Negro" }
            if brightness < 0.30 { return "Gris oscuro" }
            if brightness < 0.55 { return "Gris" }
            if brightness < 0.82 { return "Gris claro" }
            return "Blanco"  // Fondo ya filtrado, esto es blanco real de la prenda
        }

        // Colores pastel / muy claros
        if brightness > 0.85 && saturation < 0.25 {
            if rf > gf && rf > bf && rf - minC > 0.05 { return "Rosa pálido" }
            if gf > rf && gf > bf && gf - minC > 0.05 { return "Verde pálido" }
            if bf > rf && bf > gf && bf - minC > 0.05 { return "Azul pálido" }
            if rf > 0.9 && gf > 0.8 { return "Crema" }
            return "Blanco roto"
        }

        // Calcular hue
        var hue: Double = 0
        if chroma > 0 {
            if maxC == rf {
                hue = ((gf - bf) / chroma).truncatingRemainder(dividingBy: 6)
                if hue < 0 { hue += 6 }
                hue *= 60
            } else if maxC == gf {
                hue = ((bf - rf) / chroma + 2) * 60
            } else {
                hue = ((rf - gf) / chroma + 4) * 60
            }
        }

        // Colores oscuros (brightness < 0.35)
        if brightness < 0.35 {
            if hue >= 340 || hue < 15 { return "Burdeos" }
            if hue < 35 { return "Marrón" }
            if hue < 55 { return "Mostaza oscuro" }
            if hue < 85 { return "Verde oliva" }
            if hue < 165 { return "Verde oscuro" }
            if hue < 200 { return "Verde petróleo" }
            if hue < 255 { return "Azul marino" }
            if hue < 290 { return "Morado oscuro" }
            if hue < 330 { return "Fucsia oscuro" }
            return "Burdeos"
        }

        // Colores medios-claros (brightness >= 0.35)
        // Rojos y naranjas
        if hue >= 340 || hue < 12 {
            if saturation > 0.7 && brightness > 0.6 { return "Rojo" }
            if brightness > 0.7 { return "Rojo coral" }
            return "Rojo ladrillo"
        }
        if hue < 28 {
            if brightness > 0.75 && saturation < 0.6 { return "Salmon" }
            return "Coral"
        }
        if hue < 40 {
            if brightness > 0.8 { return "Naranja claro" }
            return "Naranja"
        }
        if hue < 52 {
            if brightness > 0.8 { return "Amarillo claro" }
            return "Mostaza"
        }

        // Amarillos y verdes
        if hue < 68 { return "Amarillo" }
        if hue < 85 {
            if brightness > 0.7 { return "Verde lima" }
            return "Verde manzana"
        }
        if hue < 105 { return "Verde menta" }
        if hue < 135 {
            if saturation < 0.5 { return "Verde agua" }
            return "Verde esmeralda"
        }
        if hue < 165 { return "Verde" }

        // Turquesas y azules
        if hue < 185 { return "Turquesa" }
        if hue < 210 {
            if brightness > 0.7 { return "Cyan" }
            return "Turquesa oscuro"
        }
        if hue < 240 {
            if brightness > 0.75 { return "Azul cielo" }
            if brightness > 0.55 { return "Azul" }
            return "Azul acero"
        }
        if hue < 265 {
            if brightness > 0.75 { return "Azul claro" }
            if brightness > 0.55 { return "Azul" }
            return "Azul índigo"
        }

        // Morados y rosas
        if hue < 285 {
            if brightness > 0.7 { return "Lavanda" }
            return "Morado"
        }
        if hue < 305 { return "Violeta" }
        if hue < 325 {
            if brightness > 0.75 { return "Rosa" }
            if brightness > 0.55 { return "Rosa viejo" }
            return "Malva"
        }
        if hue < 340 {
            if brightness > 0.75 { return "Rosa" }
            return "Rosa oscuro"
        }

        return "Multicolor"
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
