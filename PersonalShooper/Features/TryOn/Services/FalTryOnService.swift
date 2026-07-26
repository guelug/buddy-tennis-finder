import Foundation
import UIKit

/// Fal.ai BYOK client for the image-apps virtual try-on queue.
///
/// The user-owned key stays in Keychain and is sent only to `queue.fal.run`. Generated media is
/// downloaded in a separate unauthenticated request so credentials cannot follow a CDN redirect.
final class FalTryOnService: @unchecked Sendable {
    static let modelID = "fal-ai/image-apps-v2/virtual-try-on"
    static let submitURL = URL(string: "https://queue.fal.run/\(modelID)")!

    private let session: URLSession
    private let pollInterval: Duration
    private let maximumPolls: Int

    init(
        session: URLSession = .shared,
        pollInterval: Duration = .seconds(1),
        maximumPolls: Int = 180
    ) {
        self.session = session
        self.pollInterval = pollInterval
        self.maximumPolls = maximumPolls
    }

    func generateTryOnImage(
        clothingImage: UIImage,
        userImage: UIImage,
        apiKey: String
    ) async throws -> UIImage {
        let payload = FalTryOnInput(
            personImageURL: try dataURI(for: userImage, prefersPNG: false),
            clothingImageURL: try dataURI(for: clothingImage, prefersPNG: true),
            preservePose: true,
            aspectRatio: .init(ratio: "3:4")
        )

        var request = authorizedRequest(url: Self.submitURL, apiKey: apiKey)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("0", forHTTPHeaderField: "X-Fal-Store-IO")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        if let directResult = try? JSONDecoder().decode(FalTryOnOutput.self, from: data) {
            return try await downloadFirstImage(from: directResult)
        }

        let submission = try JSONDecoder().decode(FalQueueSubmission.self, from: data)
        guard let statusURL = URL(string: submission.statusURL),
              let responseURL = URL(string: submission.responseURL),
              Self.isTrustedQueueURL(statusURL),
              Self.isTrustedQueueURL(responseURL) else {
            throw TryOnProviderError.generationFailed("Fal returned an invalid queue URL")
        }

        for _ in 0..<maximumPolls {
            try Task.checkCancellation()
            try await Task.sleep(for: pollInterval)

            let status = try await queueStatus(at: statusURL, apiKey: apiKey)
            switch status.status {
            case "COMPLETED":
                if let error = status.error, !error.isEmpty {
                    throw TryOnProviderError.generationFailed(error)
                }
                let output = try await queueResult(at: responseURL, apiKey: apiKey)
                return try await downloadFirstImage(from: output)
            case "IN_QUEUE", "IN_PROGRESS":
                continue
            default:
                if let error = status.error, !error.isEmpty {
                    throw TryOnProviderError.generationFailed(error)
                }
            }
        }

        throw TryOnProviderError.generationFailed("Fal generation timed out")
    }

    static func validateAPIKey(_ apiKey: String, session: URLSession = .shared) async throws -> Bool {
        var request = URLRequest(url: submitURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("0", forHTTPHeaderField: "X-Fal-Store-IO")
        request.httpBody = Data("{}".utf8)

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { return false }

        switch http.statusCode {
        case 200..<300, 400, 409, 422, 429:
            // An empty body is intentionally rejected before inference. Validation/rate-limit
            // responses prove the credential passed authentication without spending credits.
            return true
        case 401, 403:
            return false
        default:
            throw TryOnProviderError.generationFailed("Fal key check returned HTTP \(http.statusCode)")
        }
    }

    static func isTrustedQueueURL(_ url: URL) -> Bool {
        url.scheme == "https" && url.host?.lowercased() == "queue.fal.run"
    }

    private func queueStatus(at url: URL, apiKey: String) async throws -> FalQueueStatus {
        let statusURL = url.appending(queryItems: [URLQueryItem(name: "logs", value: "0")])
        var request = authorizedRequest(url: statusURL, apiKey: apiKey)
        request.timeoutInterval = 30
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(FalQueueStatus.self, from: data)
    }

    private func queueResult(at url: URL, apiKey: String) async throws -> FalTryOnOutput {
        var request = authorizedRequest(url: url, apiKey: apiKey)
        request.timeoutInterval = 45
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        if let direct = try? JSONDecoder().decode(FalTryOnOutput.self, from: data) {
            return direct
        }
        return try JSONDecoder().decode(FalResultEnvelope.self, from: data).data
    }

    private func downloadFirstImage(from output: FalTryOnOutput) async throws -> UIImage {
        guard let value = output.images.first?.url,
              let url = URL(string: value),
              url.scheme == "https" else {
            throw TryOnProviderError.generationFailed("Fal returned no image")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 45
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        guard data.count <= 30_000_000, let image = UIImage(data: data) else {
            throw TryOnProviderError.generationFailed("Fal returned an invalid image")
        }
        return image
    }

    private func authorizedRequest(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw TryOnProviderError.generationFailed("Missing HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(FalErrorEnvelope.self, from: data))?.detail
                ?? "HTTP \(http.statusCode)"
            throw TryOnProviderError.generationFailed(message)
        }
    }

    private func dataURI(for image: UIImage, prefersPNG: Bool) throws -> String {
        let resized = resize(image, maxDimension: 1536)
        if prefersPNG, let data = resized.pngData(), data.count <= 18_000_000 {
            return "data:image/png;base64,\(data.base64EncodedString())"
        }
        guard let data = resized.jpegData(compressionQuality: 0.9), data.count <= 18_000_000 else {
            throw TryOnProviderError.generationFailed("Could not prepare image for Fal")
        }
        return "data:image/jpeg;base64,\(data.base64EncodedString())"
    }

    private func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1)
        guard scale < 1 else { return image }
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

private struct FalTryOnInput: Encodable {
    let personImageURL: String
    let clothingImageURL: String
    let preservePose: Bool
    let aspectRatio: FalAspectRatio

    enum CodingKeys: String, CodingKey {
        case personImageURL = "person_image_url"
        case clothingImageURL = "clothing_image_url"
        case preservePose = "preserve_pose"
        case aspectRatio = "aspect_ratio"
    }
}

private struct FalAspectRatio: Encodable {
    let ratio: String
}

private struct FalQueueSubmission: Decodable {
    let responseURL: String
    let statusURL: String

    enum CodingKeys: String, CodingKey {
        case responseURL = "response_url"
        case statusURL = "status_url"
    }
}

private struct FalQueueStatus: Decodable {
    let status: String
    let error: String?
}

private struct FalResultEnvelope: Decodable {
    let data: FalTryOnOutput
}

private struct FalTryOnOutput: Decodable {
    let images: [Image]

    struct Image: Decodable {
        let url: String
    }
}

private struct FalErrorEnvelope: Decodable {
    let detail: String?
}
