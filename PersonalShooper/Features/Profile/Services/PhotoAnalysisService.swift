import Foundation
import UIKit
import Vision
import CoreML
import CoreImage

/// Protocol for photo analysis operations
protocol PhotoAnalysisServiceProtocol {
    func extractSkinTone(from image: UIImage) async throws -> SkinAnalysisResult
    func detectFaceRect(in image: UIImage) async throws -> CGRect
    func analyzeFaceLandmarks(in image: UIImage) async throws -> [VNFaceLandmarkRegion2D]
}

/// Errors that can occur during photo analysis
enum AnalysisError: Error, LocalizedError {
    case invalidImage
    case noFaceDetected
    case multipleFacesDetected
    case contextCreationFailed
    case pixelDataAccessFailed
    case visionRequestFailed(String)
    case analysisTimeout
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The image could not be processed. Please try a different photo."
        case .noFaceDetected:
            return "No face was detected in the photo. Please ensure your face is clearly visible."
        case .multipleFacesDetected:
            return "Multiple faces detected. Please use a photo with only your face."
        case .contextCreationFailed:
            return "Failed to process image data. Please try again."
        case .pixelDataAccessFailed:
            return "Could not access image colors. Please try a different photo."
        case .visionRequestFailed(let message):
            return "Analysis failed: \(message)"
        case .analysisTimeout:
            return "Analysis took too long. Please try again."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noFaceDetected, .multipleFacesDetected:
            return "Take the photo in good lighting, facing the camera directly, with no other people in frame."
        case .invalidImage, .pixelDataAccessFailed:
            return "Try using a clearer photo with better resolution."
        default:
            return "Please try again."
        }
    }
}

/// Service for analyzing user photos to extract skin tone and other features
@MainActor
final class PhotoAnalysisService: PhotoAnalysisServiceProtocol {
    
    private let skinToneExtractor = SkinToneExtractor()
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    // MARK: - Skin Tone Extraction
    
    func extractSkinTone(from image: UIImage) async throws -> SkinAnalysisResult {
        guard let cgImage = image.cgImage else {
            throw AnalysisError.invalidImage
        }
        
        // Step 1: Face detection with landmarks for better accuracy
        let faceObservations = try await detectFaces(in: cgImage)
        
        guard let faceObservation = faceObservations.first else {
            throw AnalysisError.noFaceDetected
        }
        
        guard faceObservations.count == 1 else {
            throw AnalysisError.multipleFacesDetected
        }
        
        // Step 2: Get precise skin region using face landmarks
        let skinRegion = try await getSkinRegion(from: faceObservation, in: cgImage)
        
        // Step 3: Extract colors from skin region with improved sampling
        let colors = try extractSkinColors(from: image, in: skinRegion)
        
        guard colors.count >= 10 else {
            throw AnalysisError.pixelDataAccessFailed
        }
        
        // Step 4: Analyze undertone with confidence
        let undertone = skinToneExtractor.extractUndertone(from: colors)
        
        // Step 5: Classify skin tone category based on brightness
        let skinToneCategory = classifySkinTone(averageBrightness: averageBrightness(of: colors))
        
        // Step 6: Calculate analysis confidence
        let confidence = calculateAnalysisConfidence(colors: colors)
        
        return SkinAnalysisResult(
            dominantColors: colors.map { CodableColor(uiColor: $0) },
            undertone: undertone,
            undertoneConfidence: confidence,
            skinToneCategory: skinToneCategory
        )
    }
    
    // MARK: - Face Detection
    
    func detectFaceRect(in image: UIImage) async throws -> CGRect {
        guard let cgImage = image.cgImage else {
            throw AnalysisError.invalidImage
        }
        
        let observations = try await detectFaces(in: cgImage)
        
        guard let firstFace = observations.first else {
            throw AnalysisError.noFaceDetected
        }
        
        return convertBoundingBox(firstFace.boundingBox, imageSize: CGSize(
            width: cgImage.width,
            height: cgImage.height
        ))
    }
    
    func analyzeFaceLandmarks(in image: UIImage) async throws -> [VNFaceLandmarkRegion2D] {
        guard let cgImage = image.cgImage else {
            throw AnalysisError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceLandmarksRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: AnalysisError.visionRequestFailed(error.localizedDescription))
                    return
                }
                
                guard let results = request.results as? [VNFaceObservation],
                      let firstFace = results.first,
                      let landmarks = firstFace.landmarks else {
                    continuation.resume(throwing: AnalysisError.noFaceDetected)
                    return
                }
                
                var regions: [VNFaceLandmarkRegion2D] = []
                
                // Collect key landmark regions for skin analysis
                if let faceContour = landmarks.faceContour { regions.append(faceContour) }
                if let nose = landmarks.nose { regions.append(nose) }
                if let noseCrest = landmarks.noseCrest { regions.append(noseCrest) }
                if let medianLine = landmarks.medianLine { regions.append(medianLine) }
                
                continuation.resume(returning: regions)
            }
            
            // Configure for better accuracy
            request.constellation = .constellation76Points
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: AnalysisError.visionRequestFailed(error.localizedDescription))
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func detectFaces(in cgImage: CGImage) async throws -> [VNFaceObservation] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: AnalysisError.visionRequestFailed(error.localizedDescription))
                    return
                }
                
                guard let results = request.results as? [VNFaceObservation] else {
                    continuation.resume(throwing: AnalysisError.noFaceDetected)
                    return
                }
                
                continuation.resume(returning: results)
            }
            
            // Configure for better accuracy
            request.revision = VNDetectFaceRectanglesRequestRevision3
            
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: AnalysisError.visionRequestFailed(error.localizedDescription))
            }
        }
    }
    
    private func getSkinRegion(from observation: VNFaceObservation, in cgImage: CGImage) async throws -> CGRect {
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let faceRect = convertBoundingBox(observation.boundingBox, imageSize: imageSize)
        
        // Expand slightly to include neck and jawline
        let expandedRect = faceRect.insetBy(dx: -faceRect.width * 0.15, dy: -faceRect.height * 0.2)
        
        // Ensure rect stays within image bounds
        return expandedRect.intersection(CGRect(origin: .zero, size: imageSize))
    }
    
    private func convertBoundingBox(_ boundingBox: CGRect, imageSize: CGSize) -> CGRect {
        // Vision returns normalized coordinates (0-1) with origin at bottom-left
        // Convert to image coordinates with origin at top-left
        return CGRect(
            x: boundingBox.origin.x * imageSize.width,
            y: (1 - boundingBox.origin.y - boundingBox.height) * imageSize.height,
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )
    }
    
    private func extractSkinColors(from image: UIImage, in rect: CGRect, sampleCount: Int = 100) throws -> [UIColor] {
        guard let cgImage = image.cgImage else {
            throw AnalysisError.invalidImage
        }
        
        // Crop to region of interest
        let scaledRect = CGRect(
            x: rect.origin.x * image.scale,
            y: rect.origin.y * image.scale,
            width: rect.width * image.scale,
            height: rect.height * image.scale
        )
        
        guard let croppedCGImage = cgImage.cropping(to: scaledRect) else {
            throw AnalysisError.invalidImage
        }
        
        let width = croppedCGImage.width
        let height = croppedCGImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw AnalysisError.contextCreationFailed
        }
        
        context.draw(croppedCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else {
            throw AnalysisError.pixelDataAccessFailed
        }
        
        let pixelBuffer = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)
        
        // Sample pixels with focus on likely skin areas (center and lower face)
        var colors: [UIColor] = []
        var sampledPositions: Set<Int> = []
        
        // Grid-based sampling for better coverage
        let gridSize = Int(Double(sampleCount).squareRoot())
        let xStep = max(1, width / gridSize)
        let yStep = max(1, height / gridSize)
        
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let x = min(col * xStep + xStep / 2, width - 1)
                let y = min(row * yStep + yStep / 2, height - 1)
                let offset = (y * width + x) * bytesPerPixel
                
                guard !sampledPositions.contains(offset) else { continue }
                sampledPositions.insert(offset)
                
                let r = CGFloat(pixelBuffer[offset]) / 255.0
                let g = CGFloat(pixelBuffer[offset + 1]) / 255.0
                let b = CGFloat(pixelBuffer[offset + 2]) / 255.0
                
                // Enhanced skin tone filtering
                if isLikelySkinTone(r: r, g: g, b: b) {
                    colors.append(UIColor(red: r, green: g, blue: b, alpha: 1.0))
                }
            }
        }
        
        return colors
    }
    
    /// Determines if RGB values likely represent skin tone
    private func isLikelySkinTone(r: CGFloat, g: CGFloat, b: CGFloat) -> Bool {
        // Brightness check
        let brightness = 0.299 * r + 0.587 * g + 0.114 * b
        guard brightness > 0.15 && brightness < 0.95 else { return false }
        
        // Skin tone hue check (roughly orange-red to yellow-brown range)
        let hue = hueFromRGB(r: r, g: g, b: b)
        let isSkinHue = (hue >= 0.02 && hue <= 0.15) || (hue >= 0.85 && hue <= 1.0)
        
        // Saturation check (skin is moderately saturated)
        let saturation = saturationFromRGB(r: r, g: g, b: b)
        let isSkinSaturation = saturation > 0.1 && saturation < 0.6
        
        return isSkinHue && isSkinSaturation
    }
    
    private func hueFromRGB(r: CGFloat, g: CGFloat, b: CGFloat) -> CGFloat {
        let minVal = min(r, min(g, b))
        let maxVal = max(r, max(g, b))
        let delta = maxVal - minVal
        
        guard delta > 0 else { return 0 }
        
        var hue: CGFloat = 0
        if maxVal == r {
            hue = (g - b) / delta
        } else if maxVal == g {
            hue = 2 + (b - r) / delta
        } else {
            hue = 4 + (r - g) / delta
        }
        
        hue /= 6
        if hue < 0 { hue += 1 }
        return hue
    }
    
    private func saturationFromRGB(r: CGFloat, g: CGFloat, b: CGFloat) -> CGFloat {
        let minVal = min(r, min(g, b))
        let maxVal = max(r, max(g, b))
        let delta = maxVal - minVal
        
        guard maxVal > 0 else { return 0 }
        return delta / maxVal
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
        
        var rValues: [Double] = []
        var gValues: [Double] = []
        var bValues: [Double] = []
        
        for color in colors {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: nil)
            rValues.append(Double(r))
            gValues.append(Double(g))
            bValues.append(Double(b))
        }
        
        let rVariance = variance(of: rValues)
        let gVariance = variance(of: gValues)
        let bVariance = variance(of: bValues)
        
        let avgVariance = (rVariance + gVariance + bVariance) / 3.0
        
        // Lower variance = higher confidence (more consistent color samples)
        // Map variance (typically 0.001-0.1) to confidence (0.3-0.95)
        let confidence = 1.0 - min(avgVariance * 10, 0.65)
        return max(0.3, min(0.95, confidence))
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

// MARK: - UIImage Extensions

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
        
        return UIImage(
            cgImage: croppedCGImage,
            scale: self.scale,
            orientation: self.imageOrientation
        )
    }
    
    /// Resizes image while maintaining aspect ratio
    func resized(to targetSize: CGSize) -> UIImage? {
        let size = self.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let rect = CGRect(origin: .zero, size: newSize)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        
        draw(in: rect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
