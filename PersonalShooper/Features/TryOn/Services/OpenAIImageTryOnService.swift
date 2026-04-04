import Foundation
import UIKit

final class OpenAIImageTryOnService {
    private let session: URLSession
    private let endpoint = URL(string: "https://api.openai.com/v1/images/edits")!
    private let model = "gpt-image-1"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func generateTryOnImage(clothingImage: UIImage, userImage: UIImage, apiKey: String) async throws -> UIImage {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = try buildMultipartBody(
            boundary: boundary,
            userImage: userImage,
            clothingImage: clothingImage
        )
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TryOnProviderError.generationFailed("Missing HTTP response")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let apiMessage = (try? JSONDecoder().decode(OpenAIImageErrorEnvelope.self, from: data))?.error.message ?? "HTTP \(httpResponse.statusCode)"
            throw TryOnProviderError.generationFailed(apiMessage)
        }

        let decoded = try JSONDecoder().decode(OpenAIImageEditResponse.self, from: data)
        guard let base64 = decoded.data.first?.b64JSON,
              let imageData = Data(base64Encoded: base64),
              let image = UIImage(data: imageData) else {
            throw TryOnProviderError.generationFailed("OpenAI image response did not include a valid image")
        }

        return image
    }

    private func buildMultipartBody(boundary: String, userImage: UIImage, clothingImage: UIImage) throws -> Data {
        guard let userPNG = preparedPNG(from: userImage),
              let clothingPNG = preparedPNG(from: clothingImage) else {
            throw TryOnProviderError.generationFailed("Could not prepare source images")
        }

        var body = Data()

        appendField("model", value: model, boundary: boundary, to: &body)
        appendField("prompt", value: prompt, boundary: boundary, to: &body)
        appendField("size", value: "1024x1536", boundary: boundary, to: &body)
        appendField("quality", value: "medium", boundary: boundary, to: &body)
        appendField("response_format", value: "b64_json", boundary: boundary, to: &body)
        appendField("input_fidelity", value: "high", boundary: boundary, to: &body)
        appendFileField("image[]", fileName: "person.png", mimeType: "image/png", data: userPNG, boundary: boundary, to: &body)
        appendFileField("image[]", fileName: "garment.png", mimeType: "image/png", data: clothingPNG, boundary: boundary, to: &body)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return body
    }

    private var prompt: String {
        """
        Create a professional e-commerce fashion try-on photo by combining the provided images.
        Take the person from image 1 and keep their face, identity, body proportions, skin tone, pose, and background perspective completely unchanged.
        Take the garment from image 2 and place it naturally on the person from image 1.
        Preserve the garment's color, fabric texture, seams, hems, logos, silhouette, and fine details from image 2.
        The added garment should integrate naturally with accurate fit, folds, drape, shadows, lighting, and occlusion.
        Produce a realistic full-body shot. Do not add extra garments, accessories, or unrelated edits.
        """
    }

    private func preparedPNG(from image: UIImage) -> Data? {
        let resized = resize(image: image, maxDimension: 1536)
        return resized.pngData()
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

    private func appendField(_ name: String, value: String, boundary: String, to data: inout Data) {
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(value)\r\n".data(using: .utf8)!)
    }

    private func appendFileField(
        _ name: String,
        fileName: String,
        mimeType: String,
        data fileData: Data,
        boundary: String,
        to data: inout Data
    ) {
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        data.append(fileData)
        data.append("\r\n".data(using: .utf8)!)
    }
}

private struct OpenAIImageEditResponse: Decodable {
    let data: [ImageData]

    struct ImageData: Decodable {
        let b64JSON: String?

        enum CodingKeys: String, CodingKey {
            case b64JSON = "b64_json"
        }
    }
}

private struct OpenAIImageErrorEnvelope: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
    }
}
