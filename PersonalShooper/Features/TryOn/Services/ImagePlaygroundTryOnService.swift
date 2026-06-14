import Foundation
import ImagePlayground
import UIKit

/// Errors surfaced by the on-device Image Playground integration.
enum ImagePlaygroundTryOnError: Error, LocalizedError {
    case unavailable
    case imagePreparationFailed
    case generationCancelled
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Image Playground is not available on this device."
        case .imagePreparationFailed:
            return "Could not prepare the image for on-device generation."
        case .generationCancelled:
            return "Image generation was cancelled."
        case .generationFailed(let message):
            return "Image generation failed: \(message)"
        }
    }
}

/// Wraps Apple's `ImagePlayground` framework to generate fashion imagery locally.
///
/// Image Playground is not a photorealistic try-on engine, but it excels at stylised
/// outfit inspiration, clean garment thumbnails, and quick style variations. The service
/// keeps a clear fallback path so older devices or unsupported locales continue to work.
@available(iOS 18.4, *)
@MainActor
final class ImagePlaygroundTryOnService {

    /// Whether the device supports programmatic Image Playground generation.
    static var isAvailable: Bool {
        ImagePlaygroundViewController.isAvailable
    }

    private let creator: ImageCreator
    private let temporaryDirectory: URL

    init() async throws {
        guard Self.isAvailable else {
            throw ImagePlaygroundTryOnError.unavailable
        }
        self.creator = try await ImageCreator()
        self.temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.personalshooper.imageplayground", isDirectory: true)
        try? FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public Generation APIs

    /// Generates a stylised outfit inspiration image that places the garment on or near a
    /// person matching the provided reference photo.
    ///
    /// - Parameters:
    ///   - clothingImage: The garment to feature.
    ///   - userImage: A reference photo of the person (face or body, depending on garment).
    ///   - prompt: A short natural-language direction, e.g. "elegant dinner outfit".
    ///   - style: The visual style; defaults to `.illustration` for fashion sketches.
    /// - Returns: The generated UIImage.
    func generateOutfitInspiration(
        clothingImage: UIImage,
        userImage: UIImage,
        prompt: String,
        style: ImagePlaygroundStyle = .illustration
    ) async throws -> UIImage {
        let clothingURL = try await writeTemporaryImage(clothingImage, name: "garment")
        let userURL = try await writeTemporaryImage(userImage, name: "reference")

        var concepts: [ImagePlaygroundConcept] = [
            .text("fashion outfit, garment on the person, same identity, natural lighting"),
            .text(prompt),
            try imageConcept(from: clothingURL),
            try imageConcept(from: userURL)
        ]

        if let extracted = extractGarmentConcept(from: clothingImage) {
            concepts.append(extracted)
        }

        return try await generateSingleImage(concepts: concepts, style: style)
    }

    /// Produces a clean e-commerce style thumbnail of a single garment on a plain background.
    /// This is the local counterpart to the cloud-based marketing image service.
    func generateCleanGarmentImage(
        _ garment: UIImage,
        categoryHint: String? = nil
    ) async throws -> UIImage {
        let garmentURL = try await writeTemporaryImage(garment, name: "garment")

        var prompt = "clean product photo of the garment, white studio background, centered, full garment visible"
        if let categoryHint, !categoryHint.isEmpty {
            prompt += ", \(categoryHint)"
        }

        let concepts: [ImagePlaygroundConcept] = [
            .text(prompt),
            try imageConcept(from: garmentURL)
        ]

        return try await generateSingleImage(concepts: concepts, style: .illustration)
    }

    /// Generates a style variation of an existing garment or outfit image.
    ///
    /// - Parameters:
    ///   - image: The source image.
    ///   - prompt: Direction such as "in a casual streetwear style" or "evening elegance".
    ///   - style: Visual style; `.sketch` works well for quick explorations.
    func generateStyleVariation(
        _ image: UIImage,
        prompt: String,
        style: ImagePlaygroundStyle = .sketch
    ) async throws -> UIImage {
        let imageURL = try await writeTemporaryImage(image, name: "source")

        let concepts: [ImagePlaygroundConcept] = [
            .text("fashion variation, same garment silhouette, \(prompt)"),
            try imageConcept(from: imageURL)
        ]

        return try await generateSingleImage(concepts: concepts, style: style)
    }

    // MARK: - Shared generation helper

    private func generateSingleImage(
        concepts: [ImagePlaygroundConcept],
        style: ImagePlaygroundStyle
    ) async throws -> UIImage {
        let stream = creator.images(for: concepts, style: style, limit: 1)

        do {
            for try await created in stream {
                return UIImage(cgImage: created.cgImage)
            }
        } catch let error as ImageCreator.Error where error == .creationCancelled {
            throw ImagePlaygroundTryOnError.generationCancelled
        } catch {
            throw ImagePlaygroundTryOnError.generationFailed(error.localizedDescription)
        }

        throw ImagePlaygroundTryOnError.generationFailed("No image was produced.")
    }

    // MARK: - Helpers

    private func writeTemporaryImage(_ image: UIImage, name: String) async throws -> URL {
        guard let data = image.jpegData(compressionQuality: 0.92) ?? image.pngData() else {
            throw ImagePlaygroundTryOnError.imagePreparationFailed
        }

        let url = temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString).jpg")

        do {
            try data.write(to: url)
            return url
        } catch {
            throw ImagePlaygroundTryOnError.imagePreparationFailed
        }
    }

    private func imageConcept(from url: URL) throws -> ImagePlaygroundConcept {
        guard let concept = ImagePlaygroundConcept.image(url) else {
            throw ImagePlaygroundTryOnError.imagePreparationFailed
        }
        return concept
    }

    /// Attempts to derive an extracted concept from the image pixels.
    /// This improves Image Playground's understanding without sending data off-device.
    private func extractGarmentConcept(from image: UIImage) -> ImagePlaygroundConcept? {
        guard let cgImage = image.cgImage else { return nil }
        return .image(cgImage)
    }
}
