import CoreImage
import UIKit
import Vision

enum GarmentBackgroundRemovalService {
    private static let ciContext = CIContext()

    static func prepareImage(_ image: UIImage) async -> UIImage {
        await Task.detached(priority: .userInitiated) {
            let normalizedImage = StorageBudgetManager.normalizedClothingImage(image)
                ?? StorageBudgetManager.normalizedImage(image)
                ?? image

            guard let cutoutImage = removeBackground(from: normalizedImage) else {
                return normalizedImage
            }

            return StorageBudgetManager.normalizedClothingImage(cutoutImage) ?? cutoutImage
        }.value
    }

    private static func removeBackground(from image: UIImage) -> UIImage? {
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
                croppedToInstancesExtent: false
            )

            let outputImage = CIImage(cvPixelBuffer: maskedPixelBuffer)
            guard let maskedCGImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
                return nil
            }

            return UIImage(cgImage: maskedCGImage, scale: image.scale, orientation: .up)
        } catch {
            return nil
        }
    }
}
