import Foundation
import UIKit

/// Routes garment image optimization (clean store-style thumbnails) through the Personal Shooper
/// Vercel backend, which runs the request against fal.ai (Nano Banana 2). This keeps the image
/// provider key server-side instead of shipping it inside the app, and meters usage by tier/quota.
///
/// Used as an explicitly enabled no-BYOK path. StoreKit 2 signed values authenticate requests.
enum BackendImageService {

    enum BackendError: LocalizedError {
        case notConfigured
        case network
        case quotaExceeded
        case server(String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Image backend is not configured."
            case .network: return "Network connection failed."
            case .quotaExceeded: return "You've reached your image limit for now. Try again later."
            case .server(let message): return message
            case .invalidResponse: return "The server returned an unexpected response."
            }
        }
    }

    private struct OptimizeResponse: Decodable {
        let success: Bool?
        let imageUrl: String?
        let error: String?
    }

    static var isConfigured: Bool {
        AppSecrets.vercelAPIBaseURL != nil
    }

    @MainActor
    static func optimizeGarment(_ garment: UIImage, categoryHint: String) async throws -> UIImage {
        guard let baseURL = AppSecrets.vercelAPIBaseURL else {
            throw BackendError.notConfigured
        }

        guard let imageData = StorageBudgetManager.normalizedImageData(garment) else {
            throw BackendError.invalidResponse
        }

        guard let authorization = await StoreKitManager.shared.serverAuthorization() else {
            throw BackendError.notConfigured
        }

        let boundary = UUID().uuidString
        var body = Data()

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append(value.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }

        // image part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"garment.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        appendField(name: "categoryHint", value: categoryHint)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: baseURL.appendingPathComponent("api/optimize-image"))
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        authorization.apply(to: &request)
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw BackendError.network
        }

        guard let http = response as? HTTPURLResponse else {
            throw BackendError.network
        }

        if http.statusCode == 429 {
            throw BackendError.quotaExceeded
        }

        let decoded = try? JSONDecoder().decode(OptimizeResponse.self, from: data)

        guard (200...299).contains(http.statusCode) else {
            throw BackendError.server(decoded?.error ?? "Server error \(http.statusCode)")
        }

        guard let decoded, decoded.success == true, let imageString = decoded.imageUrl else {
            throw BackendError.server(decoded?.error ?? "No image returned")
        }

        let cleaned = imageString
            .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
            .replacingOccurrences(of: "data:image/png;base64,", with: "")
            .replacingOccurrences(of: "data:image/webp;base64,", with: "")

        guard let resultData = Data(base64Encoded: cleaned),
              let image = UIImage(data: resultData) else {
            throw BackendError.invalidResponse
        }

        return image
    }
}
