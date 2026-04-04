import Foundation
import Vision
import UIKit

protocol ClothingClassifierServiceProtocol {
    func classifyClothing(image: UIImage) async throws -> ClothingCategory
}

final class ClothingClassifierService: ClothingClassifierServiceProtocol {

    func classifyClothing(image: UIImage) async throws -> ClothingCategory {
        guard let cgImage = image.cgImage else {
            return .tops
        }

        // Use Vision framework's built-in image classifier
        let request = VNClassifyImageRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        try handler.perform([request])

        guard let results = request.results else {
            return .tops
        }

        // Map Vision classifications to our clothing categories
        return mapVisionResultsToCategory(results)
    }

    private func mapVisionResultsToCategory(_ results: [VNClassificationObservation]) -> ClothingCategory {
        // Look for keywords in the top results
        let topResults = results.prefix(10)

        let keywordsMapping: [(keywords: [String], category: ClothingCategory)] = [
            (["dress", "gown", "maxi", "mini skirt"], .dresses),
            (["shirt", "blouse", "top", "tee", "t-shirt", "sweater", "cardigan", "jacket"], .tops),
            (["pants", "jeans", "trousers", "shorts", "skirt", "leggings"], .bottoms),
            (["shoe", "sneaker", "boot", "heel", "sandal", "loafer", "footwear"], .shoes),
            (["hat", "cap", "bag", "purse", "watch", "jewelry", "sunglasses", "accessory", "scarf", "belt"], .accessories),
            (["coat", "jacket", "blazer", "parka", "windbreaker", "outerwear"], .outerwear),
            (["swimsuit", "bikini", "swimwear", "swimming"], .swimwear),
            (["gym", "workout", "athletic", "sports", "fitness", "yoga", "running"], .activewear)
        ]

        for (keywords, category) in keywordsMapping {
            for result in topResults {
                let identifier = result.identifier.lowercased()
                for keyword in keywords {
                    if identifier.contains(keyword) {
                        return category
                    }
                }
            }
        }

        // Fallback based on image aspect ratio (dresses are typically taller)
        let aspectRatio = imageAspectRatio
        if aspectRatio > 1.2 {
            return .dresses
        } else if aspectRatio < 0.8 {
            return .tops
        }

        return .tops
    }

    private var imageAspectRatio: CGFloat = 1.0
}

extension ClothingClassifierService {
    func analyzeImageAspectRatio(_ image: UIImage) {
        imageAspectRatio = image.size.height / image.size.width
    }
}

// MARK: - Color Extraction for tagging

final class ClothingColorAnalyzer {

    static func extractDominantColors(from image: UIImage, count: Int = 3) -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        // Simple color detection using bitmap
        let width = 50
        let height = 50
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var colorCounts: [String: Int] = [:]

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = rawData[offset]
                let g = rawData[offset + 1]
                let b = rawData[offset + 2]

                let colorName = categorizeColor(r: r, g: g, b: b)
                colorCounts[colorName, default: 0] += 1
            }
        }

        let sortedColors = colorCounts.sorted { $0.value > $1.value }
        return Array(sortedColors.prefix(count).map { $0.key })
    }

    private static func categorizeColor(r: UInt8, g: UInt8, b: UInt8) -> String {
        // Simple HSL-based color categorization
        let rNorm = CGFloat(r) / 255.0
        let gNorm = CGFloat(g) / 255.0
        let bNorm = CGFloat(b) / 255.0

        let maxVal = max(rNorm, gNorm, bNorm)
        let minVal = min(rNorm, gNorm, bNorm)
        let delta = maxVal - minVal

        // Calculate lightness
        let lightness = (maxVal + minVal) / 2.0

        // Calculate saturation
        let saturation = delta == 0 ? 0 : delta / (1 - abs(2 * lightness - 1))

        // Calculate hue
        var hue: CGFloat = 0
        if delta != 0 {
            if maxVal == rNorm {
                hue = 60 * (((gNorm - bNorm) / delta).truncatingRemainder(dividingBy: 6))
            } else if maxVal == gNorm {
                hue = 60 * (((bNorm - rNorm) / delta) + 2)
            } else {
                hue = 60 * (((rNorm - gNorm) / delta) + 4)
            }
        }

        if hue < 0 { hue += 360 }

        // Categorize based on hue, saturation, and lightness
        if saturation < 0.15 {
            if lightness < 0.2 { return "Black" }
            else if lightness > 0.8 { return "White" }
            else { return "Gray" }
        }

        if saturation > 0.5 {
            // Saturated colors
            if hue < 15 || hue >= 345 { return "Red" }
            if hue < 45 { return "Orange" }
            if hue < 75 { return "Yellow" }
            if hue < 165 { return "Green" }
            if hue < 255 { return "Blue" }
            if hue < 285 { return "Purple" }
            if hue < 345 { return "Pink" }
        }

        // Pastel or muted colors
        if lightness > 0.7 {
            if hue < 15 || hue >= 345 { return "Pink" }
            if hue < 45 { return "Peach" }
            if hue < 75 { return "Cream" }
            if hue < 165 { return "Mint" }
            if hue < 255 { return "Sky Blue" }
            if hue < 285 { return "Lavender" }
            if hue < 345 { return "Rose" }
        }

        return "Neutral"
    }
}
