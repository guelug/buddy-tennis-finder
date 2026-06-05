import Foundation
import UIKit
import Vision

/// Estimates face shape from a close-up photo using Vision face landmarks. We measure face length,
/// forehead width, cheekbone width and jaw width from the face contour and place the result on the
/// classic six-shape model used by image consultants for neckline / collar / eyewear guidance.
enum FaceShapeAnalyzer {

    static func detectFaceShape(from image: UIImage) async -> FaceShape? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let face = request.results?.first,
              let landmarks = face.landmarks,
              let contour = landmarks.faceContour else {
            return nil
        }

        // Face contour points run roughly from one temple, down around the jaw, to the other temple.
        // Points are normalized to the face bounding box. Convert to the box's aspect so vertical
        // and horizontal distances are comparable.
        let boxAspect = face.boundingBox.height == 0 ? 1 : face.boundingBox.width / face.boundingBox.height
        let pts = contour.normalizedPoints.map { CGPoint(x: Double($0.x) * Double(boxAspect), y: Double($0.y)) }
        guard pts.count >= 5 else { return nil }

        return classify(contour: pts)
    }

    private static func classify(contour pts: [CGPoint]) -> FaceShape? {
        // Vertical extent (chin → top of contour) approximates face length.
        let ys = pts.map(\.y)
        let xs = pts.map(\.x)
        guard let minY = ys.min(), let maxY = ys.max(),
              let minX = xs.min(), let maxX = xs.max() else { return nil }

        let length = maxY - minY
        let maxWidth = maxX - minX
        guard length > 0.0001, maxWidth > 0.0001 else { return nil }

        // Sample widths at three vertical bands: forehead (upper), cheekbones (middle), jaw (lower).
        func width(inBand lower: Double, _ upper: Double) -> Double {
            let band = pts.filter { ($0.y - minY) / length >= lower && ($0.y - minY) / length <= upper }
            guard let lo = band.map(\.x).min(), let hi = band.map(\.x).max() else { return 0 }
            return hi - lo
        }

        let foreheadWidth = width(inBand: 0.66, 1.0)
        let cheekWidth = max(width(inBand: 0.33, 0.66), maxWidth)
        let jawWidth = width(inBand: 0.0, 0.33)

        let lengthToWidth = length / cheekWidth

        // Long face → oblong; otherwise classify by where the face is widest and how the jaw reads.
        if lengthToWidth >= 1.5 {
            return .oblong
        }

        let cheekDominant = cheekWidth >= foreheadWidth && cheekWidth >= jawWidth
        let jawNarrow = jawWidth < foreheadWidth * 0.9
        let widthsSimilar = abs(foreheadWidth - jawWidth) / cheekWidth < 0.12

        if cheekDominant && jawNarrow && foreheadWidth >= jawWidth {
            return .diamond
        }
        if foreheadWidth > jawWidth * 1.12 {
            return .heart
        }
        if widthsSimilar && lengthToWidth <= 1.15 {
            // Square if the jaw is angular/wide, round if soft/short. Approximate via length: shorter
            // faces with similar widths read rounder, slightly longer read square.
            return lengthToWidth <= 1.05 ? .round : .square
        }
        // Balanced proportions, gently tapering jaw → oval (the most common, harmonious default).
        return .oval
    }
}
