import CoreImage
import UIKit
import Vision

enum GarmentBackgroundRemovalService {
    // Pin the working/output color space to sRGB. Without this, the masked pixel buffer (which can be
    // in a wide-gamut or linear space) gets reinterpreted on conversion and the garment's colors shift
    // (e.g. a light-blue shirt rendering as near-white), which then breaks color tagging/recognition.
    private static let sRGB = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    private static let ciContext = CIContext(options: [
        .workingColorSpace: sRGB,
        .outputColorSpace: sRGB
    ])

    static func prepareImage(_ image: UIImage) async -> UIImage {
        await Task.detached(priority: .userInitiated) {
            let normalizedImage = StorageBudgetManager.normalizedClothingImage(image)
                ?? StorageBudgetManager.normalizedImage(image)
                ?? image

            guard let cutoutImage = removeBackground(from: normalizedImage, cropped: false) else {
                return normalizedImage
            }

            return StorageBudgetManager.normalizedClothingImage(cutoutImage) ?? cutoutImage
        }.value
    }

    static func cutout(from image: UIImage, cropped: Bool = true) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            let normalizedImage = StorageBudgetManager.normalizedClothingImage(image) ?? image
            guard let cutout = removeBackground(from: normalizedImage, cropped: cropped) else {
                return nil
            }
            return StorageBudgetManager.normalizedClothingImage(cutout) ?? cutout
        }.value
    }

    private static func removeBackground(from image: UIImage, cropped: Bool) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])

            guard let observation = request.results?.first else {
                return nil
            }

            let instances = observation.allInstances
            guard !instances.isEmpty else {
                return nil
            }

            let maskedPixelBuffer = try observation.generateMaskedImage(
                ofInstances: instances,
                from: handler,
                croppedToInstancesExtent: cropped
            )

            let outputImage = CIImage(cvPixelBuffer: maskedPixelBuffer)
            guard let maskedCGImage = ciContext.createCGImage(outputImage, from: outputImage.extent, format: .RGBA8, colorSpace: sRGB) else {
                return nil
            }

            return UIImage(cgImage: maskedCGImage, scale: image.scale, orientation: .up)
        } catch {
            return nil
        }
    }
}
