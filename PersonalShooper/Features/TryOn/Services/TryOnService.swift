import Foundation
import UIKit

@MainActor
final class TryOnService: ObservableObject {
    static let shared = TryOnService()

    @Published var isProcessing: Bool = false
    @Published var remainingCredits: Int = 5
    @Published var currentTier: SubscriptionTier = .free
    @Published var lastError: TryOnError?

    private let vercelBaseURL: String
    private let storeKitManager = StoreKitManager.shared

    enum TryOnError: Error, LocalizedError {
        case noCredits
        case networkError
        case invalidResponse
        case serverError(String)
        case tierNotSupported
        case imageCompressionFailed

        var errorDescription: String? {
            switch self {
            case .noCredits:
                return "No credits remaining. Upgrade to Premium for more try-ons."
            case .networkError:
                return "Network connection failed. Please check your internet."
            case .invalidResponse:
                return "Failed to process server response."
            case .serverError(let message):
                return "Server error: \(message)"
            case .tierNotSupported:
                return "Your subscription tier does not support this feature."
            case .imageCompressionFailed:
                return "Failed to compress images for upload."
            }
        }
    }

    struct TryOnResponse: Codable {
        let success: Bool
        let imageUrl: String?
        let creditsRemaining: Int
        let tier: String
        let error: String?
    }

    init() {
        if let baseURL = AppSecrets.vercelAPIBaseURL {
            self.vercelBaseURL = baseURL.absoluteString
        } else {
            self.vercelBaseURL = ""
        }
    }

    // MARK: - Public Methods

    func generate(
        clothingImage: UIImage,
        personImage: UIImage,
        receiptData: Data
    ) async throws -> UIImage {
        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        // 1. Verify credits
        guard remainingCredits > 0 else {
            let error = TryOnError.noCredits
            lastError = error
            throw error
        }

        // 2. Verify Vercel API is configured
        guard !vercelBaseURL.isEmpty else {
            let error = TryOnError.serverError("Vercel API URL not configured")
            lastError = error
            throw error
        }

        // 3. Compress images (800px max)
        guard let clothingData = compressImage(clothingImage),
              let personData = compressImage(personImage) else {
            let error = TryOnError.imageCompressionFailed
            lastError = error
            throw error
        }

        // 3. Create multipart form data
        let boundary = UUID().uuidString
        var body = Data()

        // clothingImage
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"clothingImage\"; filename=\"clothing.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(clothingData)
        body.append("\r\n".data(using: .utf8)!)

        // personImage
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"personImage\"; filename=\"person.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(personData)
        body.append("\r\n".data(using: .utf8)!)

        // receiptData
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"receiptData\"\r\n\r\n".data(using: .utf8)!)
        body.append(receiptData.base64EncodedString().data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // 4. Build request
        let url = URL(string: "\(vercelBaseURL)/api/try-on")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(receiptData.base64EncodedString(), forHTTPHeaderField: "X-Receipt-Data")
        request.httpBody = body

        // Add test mode header if configured
        #if DEBUG
        if ProcessInfo.processInfo.environment["VERCEL_TEST_MODE"] == "true" {
            request.setValue("true", forHTTPHeaderField: "X-Test-Mode")
        }
        #endif

        // 5. Send request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            lastError = TryOnError.networkError
            throw TryOnError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            lastError = TryOnError.networkError
            throw TryOnError.networkError
        }

        if httpResponse.statusCode == 429 {
            lastError = TryOnError.noCredits
            throw TryOnError.noCredits
        }

        guard httpResponse.statusCode == 200 else {
            let error = TryOnError.serverError("Status: \(httpResponse.statusCode)")
            lastError = error
            throw error
        }

        // 6. Parse response
        let tryOnResponse: TryOnResponse
        do {
            tryOnResponse = try JSONDecoder().decode(TryOnResponse.self, from: data)
        } catch {
            lastError = TryOnError.invalidResponse
            throw TryOnError.invalidResponse
        }

        guard tryOnResponse.success, let imageUrl = tryOnResponse.imageUrl else {
            let error = TryOnError.serverError(tryOnResponse.error ?? "Unknown error")
            lastError = error
            throw error
        }

        // 7. Update local credit count
        remainingCredits = tryOnResponse.creditsRemaining

        // 8. Sync credits with CloudKit (when implemented)
        // try await cloudKitManager.decrementCredits(by: 1)

        // 9. Convert base64 to UIImage
        let cleanBase64 = imageUrl
            .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
            .replacingOccurrences(of: "data:image/png;base64,", with: "")
            .replacingOccurrences(of: "data:image/webp;base64,", with: "")

        guard let imageData = Data(base64Encoded: cleanBase64),
              let image = UIImage(data: imageData) else {
            lastError = TryOnError.invalidResponse
            throw TryOnError.invalidResponse
        }

        return image
    }

    // MARK: - Helpers

    private func compressImage(_ image: UIImage, maxDimension: CGFloat = 800) -> Data? {
        let maxDim = max(image.size.width, image.size.height)
        guard maxDim > maxDimension else {
            return image.jpegData(compressionQuality: 0.8)
        }

        let scale = maxDimension / maxDim
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resizedImage.jpegData(compressionQuality: 0.8)
    }

    func refreshCredits() async {
        currentTier = storeKitManager.currentTier
        remainingCredits = storeKitManager.remainingCredits
    }
}
