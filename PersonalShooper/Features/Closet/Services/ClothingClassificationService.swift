import UIKit
import Vision
import CoreML

struct ClothingClassificationResult {
    let category: ClothingCategory
    let colors: [String]
    let confidence: Float
}

final class ClothingClassificationService: @unchecked Sendable {

    func classifyClothing(image: UIImage) async throws -> ClothingClassificationResult {
        guard let cgImage = image.cgImage else {
            throw ClassificationError.invalidImage
        }

        async let categoryResult = Self.classifyCategory(cgImage: cgImage)
        async let colorsResult = Self.extractColors(from: cgImage)

        let (category, confidence) = await categoryResult
        let colors = await colorsResult

        return ClothingClassificationResult(
            category: category,
            colors: colors,
            confidence: confidence
        )
    }

    private static func classifyCategory(cgImage: CGImage) async -> (ClothingCategory, Float) {
        await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    #if DEBUG
                    print("ClothingClassificationService.classifyCategory callback failed: \(error.localizedDescription)")
                    #endif
                    continuation.resume(returning: (.tops, 0.5))
                    return
                }

                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: (.tops, 0.5))
                    return
                }

                let category = self.mapObservationToCategory(observations)
                let topConfidence = observations.first?.confidence ?? 0.5

                continuation.resume(returning: (category, topConfidence))
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                #if DEBUG
                print("ClothingClassificationService.classifyCategory perform failed: \(error.localizedDescription)")
                #endif
                continuation.resume(returning: (.tops, 0.5))
            }
        }
    }

    private static func mapObservationToCategory(_ observations: [VNClassificationObservation]) -> ClothingCategory {
        for observation in observations {
            let identifier = observation.identifier.lowercased()

            // Dresses
            if identifier.contains("dress") || identifier.contains("gown") {
                return .dresses
            }

            // Shoes
            if identifier.contains("shoe") || identifier.contains("sneaker") ||
               identifier.contains("boot") || identifier.contains("sandal") ||
               identifier.contains("heel") || identifier.contains("loafer") {
                return .shoes
            }

            // Outerwear
            if identifier.contains("jacket") || identifier.contains("coat") ||
               identifier.contains("blazer") || identifier.contains("cardigan") ||
               identifier.contains("sweater") || identifier.contains("hoodie") {
                return .outerwear
            }

            // Activewear / Sports
            if identifier.contains("sports") || identifier.contains("athletic") ||
               identifier.contains("gym") || identifier.contains("workout") ||
               identifier.contains("yoga") || identifier.contains("running") {
                return .activewear
            }

            // Swimwear
            if identifier.contains("swimsuit") || identifier.contains("bikini") ||
               identifier.contains("swimwear") || identifier.contains("bathing") {
                return .swimwear
            }

            // Bottoms
            if identifier.contains("pant") || identifier.contains("trouser") ||
               identifier.contains("jean") || identifier.contains("short") ||
               identifier.contains("skirt") || identifier.contains("legging") {
                return .bottoms
            }

            // Tops
            if identifier.contains("shirt") || identifier.contains("blouse") ||
               identifier.contains("top") || identifier.contains("t-shirt") ||
               identifier.contains("polo") || identifier.contains("tank") ||
               identifier.contains("crop") {
                return .tops
            }

            // Accessories
            if identifier.contains("bag") || identifier.contains("purse") ||
               identifier.contains("hat") || identifier.contains("cap") ||
               identifier.contains("watch") || identifier.contains("jewelry") ||
               identifier.contains("sunglasses") || identifier.contains("belt") ||
               identifier.contains("scarf") || identifier.contains("tie") {
                return .accessories
            }
        }

        // Fallback based on top observations
        for observation in observations.prefix(5) {
            let identifier = observation.identifier.lowercased()

            if identifier.contains("clothing") || identifier.contains("apparel") ||
               identifier.contains("fashion") || identifier.contains("wear") {
                return .tops
            }
        }

        return .tops
    }

    private static func extractColors(from cgImage: CGImage) async -> [String] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let width = min(cgImage.width, 100)
                let height = min(cgImage.height, 100)

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

                for y in stride(from: 0, to: height, by: 5) {
                    for x in stride(from: 0, to: width, by: 5) {
                        let offset = (y * width + x) * 4
                        let r = Int(pointer[offset])
                        let g = Int(pointer[offset + 1])
                        let b = Int(pointer[offset + 2])
                        let alpha = Int(pointer[offset + 3])

                        guard alpha > 25 else {
                            continue
                        }

                        let colorName = self.classifyColor(r: r, g: g, b: b)
                        colorCounts[colorName, default: 0] += 1
                    }
                }

                let sortedColors = colorCounts.sorted { $0.value > $1.value }
                let topColors = sortedColors.prefix(3).map { $0.key }

                continuation.resume(returning: Array(topColors))
            }
        }
    }

    private static func classifyColor(r: Int, g: Int, b: Int) -> String {
        // Simple color classification based on RGB values
        let maxComponent = Double(max(r, g, b))
        let minComponent = Double(min(r, g, b))

        // Calculate saturation and brightness
        let saturation: Double = maxComponent == 0 ? 0 : (maxComponent - minComponent) / maxComponent
        let brightness: Double = maxComponent / 255.0

        // Grayscale
        if saturation < 0.1 {
            if brightness < 0.2 { return "Negro" }
            if brightness < 0.4 { return "Gris oscuro" }
            if brightness < 0.6 { return "Gris" }
            if brightness < 0.8 { return "Gris claro" }
            return "Blanco"
        }

        // Calculate hue
        var hue: Double
        let delta = maxComponent - minComponent

        if maxComponent == Double(r) {
            hue = 60 * (((Double(g) - Double(b)) / delta).truncatingRemainder(dividingBy: 6))
        } else if maxComponent == Double(g) {
            hue = 60 * (((Double(b) - Double(r)) / delta) + 2)
        } else {
            hue = 60 * (((Double(r) - Double(g)) / delta) + 4)
        }

        if hue < 0 { hue += 360 }

        // Classify based on hue
        let colorName: String

        if saturation < 0.3 {
            if brightness > 0.7 {
                colorName = "Blanco"
            } else if brightness > 0.4 {
                colorName = "Gris"
            } else {
                colorName = "Negro"
            }
        } else if brightness > 0.7 {
            if hue < 30 || hue > 330 { colorName = "Rojo claro" }
            else if hue < 90 { colorName = "Amarillo" }
            else if hue < 150 { colorName = "Verde claro" }
            else if hue < 210 { colorName = "Cian" }
            else if hue < 270 { colorName = "Azul claro" }
            else if hue < 330 { colorName = "Rosa" }
            else { colorName = "Rojo claro" }
        } else if brightness < 0.3 {
            if hue < 30 || hue > 330 { colorName = "Rojo oscuro" }
            else if hue < 90 { colorName = "Marrón" }
            else if hue < 150 { colorName = "Verde oscuro" }
            else if hue < 210 { colorName = "Azul oscuro" }
            else if hue < 270 { colorName = "Azul oscuro" }
            else if hue < 330 { colorName = "Púrpura" }
            else { colorName = "Rojo oscuro" }
        } else {
            if hue < 15 || hue > 345 { colorName = "Rojo" }
            else if hue < 45 { colorName = "Naranja" }
            else if hue < 75 { colorName = "Amarillo" }
            else if hue < 150 { colorName = "Verde" }
            else if hue < 195 { colorName = "Cian" }
            else if hue < 255 { colorName = "Azul" }
            else if hue < 285 { colorName = "Púrpura" }
            else if hue < 345 { colorName = "Rosa" }
            else { colorName = "Rojo" }
        }

        return colorName
    }

    enum ClassificationError: Error {
        case invalidImage
        case classificationFailed
    }
}
