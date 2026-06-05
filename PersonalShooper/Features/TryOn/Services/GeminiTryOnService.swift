import Foundation
import UIKit

protocol TryOnServiceProtocol {
    func generateTryOnImage(clothingImage: UIImage, userImage: UIImage, editHints: [EditHint]?) async throws -> UIImage
    func refineImage(_ image: UIImage, instructions: String) async throws -> UIImage
}

struct EditHint {
    let instruction: String
}

enum TryOnError: Error, LocalizedError {
    case apiError(String)
    case invalidURL
    case parsingError
    case invalidImageData
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .apiError(let message): return "API request failed: \(message)"
        case .invalidURL: return "Invalid API URL"
        case .parsingError: return "Failed to parse response"
        case .invalidImageData: return "Invalid image data"
        case .noAPIKey: return "Gemini API key not configured"
        }
    }
}

final class GeminiTryOnService: TryOnServiceProtocol {
    private let apiKey: String?
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-image:generateContent"
    private let session: URLSession

    init(apiKey: String? = nil, session: URLSession = .shared) {
        self.apiKey = apiKey ?? AppSecrets.geminiAPIKey ?? ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
        self.session = session
    }

    func generateTryOnImage(
        clothingImage: UIImage,
        userImage: UIImage,
        editHints: [EditHint]?
    ) async throws -> UIImage {
        try await generateTryOnImage(clothingImage: clothingImage, userImage: userImage, editHints: editHints, garmentInstruction: nil)
    }

    func generateTryOnImage(
        clothingImage: UIImage,
        userImage: UIImage,
        editHints: [EditHint]?,
        garmentInstruction: String?
    ) async throws -> UIImage {
        guard let apiKey, !apiKey.isEmpty else {
            return createPlaceholderResult(clothing: clothingImage, user: userImage)
        }

        let request = try buildRequest(
            prompt: try tryOnPrompt(editHints: editHints, garmentInstruction: garmentInstruction),
            images: [
                try makeInlineImagePart(from: clothingImage),
                try makeInlineImagePart(from: userImage)
            ],
            apiKey: apiKey
        )

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try parseResponse(data)
    }

    /// Produces a clean, professional full-body reference of the person: same face, body, clothing
    /// and proportions, but on a plain neutral studio backdrop with the mirror, phone, and surrounding
    /// clutter removed. Used as the try-on reference so results aren't polluted by the original scene.
    func cleanStudioImage(from personImage: UIImage) async throws -> UIImage {
        guard let apiKey, !apiKey.isEmpty else {
            return personImage
        }

        let prompt = """
        Regenerate this photo as a clean, professional full-body studio portrait of the SAME person.
        Keep the person's face, identity, hairstyle, body shape, proportions, skin tone, pose, and the exact clothing they are wearing completely unchanged.
        Remove the mirror, the phone, any reflections, furniture, and all background clutter.
        Place the person on a plain, evenly-lit light neutral studio background (soft grey/white).
        Show the full body, head to feet, centered, well-lit, with natural colors. Do not restyle, recolor, or change the clothing.
        """

        let request = try buildRequest(
            prompt: prompt,
            images: [try makeInlineImagePart(from: personImage)],
            apiKey: apiKey
        )

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try parseResponse(data)
    }

    /// Produces a clean e-commerce / marketing thumbnail of a single garment: the SAME item, on a
    /// pure white studio background, photographed straight-on, fully visible and centered.
    func marketingImage(for garment: UIImage, categoryHint: String) async throws -> UIImage {
        guard let apiKey, !apiKey.isEmpty else {
            return garment
        }

        let request = try buildRequest(
            prompt: MarketingImagePrompt.build(categoryHint: categoryHint),
            images: [try makeInlineImagePart(from: garment)],
            apiKey: apiKey
        )

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try parseResponse(data)
    }

    func refineImage(_ image: UIImage, instructions: String) async throws -> UIImage {
        guard let apiKey, !apiKey.isEmpty else {
            return image
        }

        let prompt = """
        Using the provided image, change only the requested element. \(instructions)
        Keep everything else in the image exactly the same, preserving the original style, lighting, composition, fit, and identity.
        """

        let request = try buildRequest(
            prompt: prompt,
            images: [try makeInlineImagePart(from: image)],
            apiKey: apiKey
        )

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try parseResponse(data)
    }

    private func tryOnPrompt(editHints: [EditHint]?, garmentInstruction: String? = nil) throws -> String {
        var prompt = """
        Create a new image by combining the elements from the provided images.
        Take the garment from image 1 and place it on the person from image 2.
        The final image should be a realistic, professional full-body fashion try-on photo.
        Keep the person's face, identity, body proportions, skin tone, pose, and visible features from image 2 unchanged.
        Preserve the garment's color, pattern, fabric texture, silhouette, seams, hems, logos, and small details from image 1.
        Ensure the change integrates naturally with correct fit, folds, drape, shadows, lighting, perspective, and occlusion.
        Keep the background and scene style from image 2.
        If image 2 includes multiple reference views in one frame, use the additional view only to preserve garment structure and fit accuracy, but generate the final result from the main front-facing person.
        Do not add extra garments, accessories, anatomy changes, or unrelated styling changes.
        """

        if let garmentInstruction, !garmentInstruction.isEmpty {
            prompt += "\nIMPORTANT — garment type: \(garmentInstruction) Do NOT change the type of garment shown in image 1, and do NOT replace any other garment than the one specified."
        }

        if let editHints, !editHints.isEmpty {
            let refinements = editHints.map(\.instruction).joined(separator: " ")
            prompt += "\nAdditional fitting requirements: \(refinements)"
        }

        return prompt
    }

    private func buildRequest(prompt: String, images: [[String: Any]], apiKey: String) throws -> URLRequest {
        guard let url = URL(string: baseURL) else {
            throw TryOnError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let parts: [[String: Any]] = images + [["text": prompt]]
        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": parts
                ]
            ],
            "generationConfig": [
                "temperature": 0.25,
                "topP": 0.9,
                "topK": 32
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }

    private func makeInlineImagePart(from image: UIImage) throws -> [String: Any] {
        guard let prepared = prepareImageData(from: image) else {
            throw TryOnError.invalidImageData
        }

        return [
            "inline_data": [
                "mime_type": prepared.mimeType,
                "data": prepared.data.base64EncodedString()
            ]
        ]
    }

    private func prepareImageData(from image: UIImage) -> (data: Data, mimeType: String)? {
        let resized = resize(image: image, maxDimension: 1536)

        if let pngData = resized.pngData(), pngData.count <= 18_000_000 {
            return (pngData, "image/png")
        }

        if let jpegData = resized.jpegData(compressionQuality: 0.92), jpegData.count <= 18_000_000 {
            return (jpegData, "image/jpeg")
        }

        return nil
    }

    private func resize(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1)
        guard scale < 1 else { return image }

        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TryOnError.apiError("Missing HTTP response")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let apiMessage = (try? JSONDecoder().decode(GeminiErrorEnvelope.self, from: data))?.error.message ?? "HTTP \(httpResponse.statusCode)"
            throw TryOnError.apiError(apiMessage)
        }
    }

    private func parseResponse(_ data: Data) throws -> UIImage {
        let decoded = try JSONDecoder().decode(GeminiGenerateResponse.self, from: data)

        guard let base64 = decoded.candidates
            .first?
            .content
            .parts
            .compactMap({ $0.inlineData?.data ?? $0.inline_data?.data })
            .first,
              let imageData = Data(base64Encoded: base64),
              let image = UIImage(data: imageData) else {
            throw TryOnError.parsingError
        }

        return image
    }

    private func createPlaceholderResult(clothing: UIImage, user: UIImage) -> UIImage {
        let size = CGSize(width: 600, height: 800)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let clothingRect = CGRect(x: 50, y: 50, width: 200, height: 300)
            clothing.draw(in: clothingRect)

            let userRect = CGRect(x: 300, y: 50, width: 250, height: 400)
            user.draw(in: userRect)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: UIColor.darkGray,
                .paragraphStyle: paragraphStyle
            ]

            let text = "Gemini API\nNot Configured"
            let textRect = CGRect(x: 50, y: 650, width: 500, height: 100)
            text.draw(in: textRect, withAttributes: attrs)
        }
    }
}

private struct GeminiGenerateResponse: Decodable {
    let candidates: [Candidate]

    struct Candidate: Decodable {
        let content: Content
    }

    struct Content: Decodable {
        let parts: [Part]
    }

    struct Part: Decodable {
        let text: String?
        let inlineData: InlineData?
        let inline_data: InlineData?
    }

    struct InlineData: Decodable {
        let mimeType: String?
        let mime_type: String?
        let data: String
    }
}

private struct GeminiErrorEnvelope: Decodable {
    let error: GeminiAPIError

    struct GeminiAPIError: Decodable {
        let message: String
    }
}
