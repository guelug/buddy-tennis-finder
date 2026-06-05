import Foundation
import UIKit
import Vision
import CoreImage

/// Removes the background from a garment photo using Vision's on-device subject lifting
/// (`VNGenerateForegroundInstanceMaskRequest`, iOS 17+), returning a transparent PNG-able UIImage.
///
/// Used after generating the white-background marketing thumbnail so the garment can float on any
/// backdrop (light or dark mode) instead of sitting in a white box. Returns nil if no clear subject
/// is found, in which case callers keep the original white-background image.
enum BackgroundRemover {

    private static let ciContext = CIContext()

    static func removeBackground(from image: UIImage, maxDimension: CGFloat = 1024) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let result = request.results?.first else { return nil }

        do {
            let masked = try result.generateMaskedImage(
                ofInstances: result.allInstances,
                from: handler,
                croppedToInstancesExtent: true
            )
            let ciImage = CIImage(cvPixelBuffer: masked)
            guard let outCG = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
            let cutout = UIImage(cgImage: outCG)
            return resize(cutout, maxDimension: maxDimension)
        } catch {
            return nil
        }
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1)
        guard scale < 1 else { return image }
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false // preserve the alpha channel
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
