import SwiftUI
import UIKit

@Observable
@MainActor
final class TryOnViewModel {
    var selectedClothingImage: UIImage?
    var selectedUserImage: UIImage?
    var generatedImage: UIImage?
    var isGenerating = false
    var errorMessage: String?

    func generateTryOn() async {
        guard let clothing = selectedClothingImage, let user = selectedUserImage else {
            errorMessage = "Por favor selecciona una prenda"
            return
        }

        isGenerating = true
        errorMessage = nil

        // Simulate generation delay
        try? await Task.sleep(for: .seconds(2))

        // For demo, use the user image as result
        // Real implementation would call the actual service based on selected provider
        generatedImage = user

        isGenerating = false
    }
}
