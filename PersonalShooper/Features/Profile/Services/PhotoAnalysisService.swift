import Foundation
import UIKit
import Vision
import CoreML

protocol PhotoAnalysisServiceProtocol {
    func extractSkinTone(from image: UIImage) async throws -> SkinAnalysisResult
    func detectFaceRect(in image: UIImage) async throws -> CGRect
}

enum AnalysisError: Error, LocalizedError {
    case invalidImage
    case noFaceDetected
    case contextCreationFailed
    case pixelDataAccessFailed
    case visionRequestFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Invalid image provided"
        case .noFaceDetected: return "No face detected in image"
        case .contextCreationFailed: return "Failed to create graphics context"
        case .pixelDataAccessFailed: return "Failed to access pixel data"
        case .visionRequestFailed(let msg): return "Vision request failed: \(msg)"
        }
    }
}

@MainActor
final class PhotoAnalysisService: PhotoAnalysisServiceProtocol {
    
    private let skinToneExtractor = SkinToneExtractor()
    
    func extractSkinTone(from image: UIImage) async throws -> SkinAnalysisResult {
        guard let cgImage = image.cgImage else {
            throw AnalysisError.invalidImage
        }
        
        let faceRect = try await detectFaceRect(in: image)
        
        guard let faceImage = image.cropped(to: faceRect) else {
            throw AnalysisError.invalidImage
        }
        
        let colors = try extractDominantColors(from: faceImage)
        let undertone = skinToneExtractor.extractUndertone(from: colors)
        let skinToneCategory = classifySkinTone(averageBrightness: averageBrightness(of: colors))
        let confidence = calculateAnalysisConfidence(colors: colors)
        
        return SkinAnalysisResult(
            dominantColors: colors.map { CodableColor(uiColor: $0) },
            undertone: undertone,
            undertoneConfidence: confidence,
            skinToneCategory: skinToneCategory
        )
    }
    
    func detectFaceRect(in image: UIImage) async throws -> CGRect {
        guard let cgImage = image.cgImage else {
            throw AnalysisError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: AnalysisError.visionRequestFailed(error.localizedDescription))
                    return
                }
                
                guard let results = request.results as? [VNFaceObservation],
                      let firstFace = results.first else {
                    continuation.resume(throwing: AnalysisError.noFaceDetected)
                    return
                }
                
                let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
                continuation.resume(returning: self.convertBoundingBox(firstFace.boundingBox, imageSize: imageSize))
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: AnalysisError.visionRequestFailed(error.localizedDescription))
            }
        }
    }
    
    private func convertBoundingBox(_ boundingBox: CGRect, imageSize: CGSize) -> CGRect {
        return CGRect(
            x: boundingBox.origin.x * imageSize.width,
            y: (1 - boundingBox.origin.y - boundingBox.height) * imageSize.height,
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )
    }
    
    private func extractDominantColors(from image: UIImage, sampleCount: Int = 50) throws -> [UIColor] {
        guard let cgImage = image.cgImage else {
            throw AnalysisError.invalidImage
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw AnalysisError.contextCreationFailed
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else {
            throw AnalysisError.pixelDataAccessFailed
        }
        
        let pixelBuffer = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)
        
        var colors: [UIColor] = []
        let step = max(1, (width * height) / sampleCount)
        
        for i in stride(from: 0, to: width * height, by: step) {
            let offset = i * bytesPerPixel
            let r = CGFloat(pixelBuffer[offset]) / 255.0
            let g = CGFloat(pixelBuffer[offset + 1]) / 255.0
            let b = CGFloat(pixelBuffer[offset + 2]) / 255.0
            
            let brightness = 0.299 * r + 0.587 * g + 0.114 * b
            if brightness > 0.15 && brightness < 0.95 {
                colors.append(UIColor(red: r, green: g, blue: b, alpha: 1.0))
            }
        }
        
        return colors
    }
    
    private func averageBrightness(of colors: [UIColor]) -> Double {
        guard !colors.isEmpty else { return 0.5 }
        var totalBrightness: Double = 0
        for color in colors {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: nil)
            totalBrightness += (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b))
        }
        return totalBrightness / Double(colors.count)
    }
    
    private func calculateAnalysisConfidence(colors: [UIColor]) -> Double {
        guard colors.count > 1 else { return 0.5 }
        var rValues: [Double] = [], gValues: [Double] = [], bValues: [Double] = []
        
        for color in colors {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: nil)
            rValues.append(Double(r))
            gValues.append(Double(g))
            bValues.append(Double(b))
        }
        
        let avgVariance = (variance(of: rValues) + variance(of: gValues) + variance(of: bValues)) / 3.0
        return max(0.3, min(0.95, 1.0 - (avgVariance * 10)))
    }
    
    private func variance(of values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Double(values.count - 1)
    }
    
    private func classifySkinTone(averageBrightness: Double) -> SkinToneCategory {
        switch averageBrightness {
        case 0..<0.22: return .dark
        case 0.22..<0.40: return .tan
        case 0.40..<0.58: return .medium
        case 0.58..<0.75: return .light
        default: return .fair
        }
    }
}

extension UIImage {
    func cropped(to rect: CGRect) -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        
        let scaledRect = CGRect(
            x: rect.origin.x * self.scale,
            y: rect.origin.y * self.scale,
            width: rect.width * self.scale,
            height: rect.height * self.scale
        )
        
        guard let croppedCGImage = cgImage.cropping(to: scaledRect) else { return nil }
        return UIImage(cgImage: croppedCGImage, scale: self.scale, orientation: self.imageOrientation)
    }
}
