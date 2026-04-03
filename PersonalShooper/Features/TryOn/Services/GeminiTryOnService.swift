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
    case apiError
    case invalidURL
    case parsingError
    case invalidImageData
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .apiError: return "API request failed"
        case .invalidURL: return "Invalid API URL"
        case .parsingError: return "Failed to parse response"
        case .invalidImageData: return "Invalid image data"
        case .noAPIKey: return "Gemini API key not configured"
        }
    }
}

final class GeminiTryOnService: TryOnServiceProtocol {

    private let apiKey: String?
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-image-preview:generateContent"

    init(apiKey: String? = nil) {
        // In production, load from secure configuration
        self.apiKey = apiKey ?? ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
    }

    func generateTryOnImage(
        clothingImage: UIImage,
        userImage: UIImage,
        editHints: [EditHint]?
    ) async throws -> UIImage {
        guard let apiKey = apiKey else {
            // Return a placeholder when no API key is configured
            return createPlaceholderResult(clothing: clothingImage, user: userImage)
        }

        // Convert images to base64
        guard let clothingBase64 = clothingImage.jpegData(compressionQuality: 0.8)?.base64EncodedString(),
              let userBase64 = userImage.jpegData(compressionQuality: 0.8)?.base64EncodedString() else {
            throw TryOnError.invalidImageData
        }

        // Build prompt
        var prompt = """
        Create a realistic image showing the person from the second image wearing the clothing item from the first image.
        The result should look natural with proper fit, lighting, and positioning.
        """

        if let hints = editHints {
            let hintStrings = hints.map { $0.instruction }.joined(separator: ", ")
            prompt += " Make the following adjustments: \(hintStrings)"
        }

        // Call Gemini API
        let request = try buildRequest(prompt: prompt, images: [clothingBase64, userBase64], apiKey: apiKey)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TryOnError.apiError
        }

        // Parse response
        return try parseResponse(data)
    }

    func refineImage(_ image: UIImage, instructions: String) async throws -> UIImage {
        guard let apiKey = apiKey else {
            return image
        }

        guard let base64 = image.jpegData(compressionQuality: 0.8)?.base64EncodedString() else {
            throw TryOnError.invalidImageData
        }

        let prompt = """
        Based on the provided image, make the following modifications: \(instructions)
        Maintain the person's identity and the clothing's general appearance.
        """

        let request = try buildRequest(prompt: prompt, images: [base64], apiKey: apiKey)
        let (data, _) = try await URLSession.shared.data(for: request)

        return try parseResponse(data)
    }

    private func buildRequest(prompt: String, images: [String], apiKey: String) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw TryOnError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let payload: [String: Any] = [
            "contents": [
                "parts": [
                    ["text": prompt]
                ] + images.map { ["image": ["data": $0, "mimeType": "image/jpeg"]]
                }
            ],
            "generationConfig": [
                "temperature": 0.4,
                "topK": 32,
                "topP": 0.95
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }

    private func parseResponse(_ data: Data) throws -> UIImage {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let imagePart = parts.first(where: { ($0["image"] as? [String: Any]) != nil }),
              let imageDataDict = imagePart["image"] as? [String: Any],
              let imageDataString = imageDataDict["data"] as? String,
              let imageBytes = Data(base64Encoded: imageDataString) else {
            throw TryOnError.parsingError
        }

        guard let uiImage = UIImage(data: imageBytes) else {
            throw TryOnError.invalidImageData
        }

        return uiImage
    }

    private func createPlaceholderResult(clothing: UIImage, user: UIImage) -> UIImage {
        // Create a placeholder result when API is not available
        let size = CGSize(width: 600, height: 800)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw clothing on left
            let clothingRect = CGRect(x: 50, y: 50, width: 200, height: 300)
            clothing.draw(in: clothingRect)

            // Draw user on right
            let userRect = CGRect(x: 300, y: 50, width: 250, height: 400)
            user.draw(in: userRect)

            // Draw placeholder text
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
