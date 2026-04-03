import SwiftUI
import SwiftData

@Observable
final class TryOnViewModel {
    enum State {
        case idle
        case capturingClothing
        case capturingSelf
        case processing
        case result
        case editing
    }

    var state: State = .idle
    var clothingImage: UIImage?
    var userImage: UIImage?
    var resultImage: UIImage?
    var editInstruction: String = ""
    var tryOnCount: Int = 0

    private var editHistory: [ImageEdit] = []
    private let geminiService = GeminiTryOnService()

    func startTryOn() {
        state = .capturingClothing
    }

    func proceedToSelfCapture() {
        guard clothingImage != nil else { return }
        state = .capturingSelf
    }

    @MainActor
    func generateTryOn() async {
        guard let clothing = clothingImage, let user = userImage else { return }

        state = .processing

        do {
            let result = try await geminiService.generateTryOnImage(
                clothingImage: clothing,
                userImage: user,
                editHints: nil
            )
            resultImage = result
            tryOnCount += 1
            state = .result
        } catch {
            state = .result
        }
    }

    func startEditing() {
        state = .editing
        editInstruction = ""
    }

    func cancelEditing() {
        state = .result
        editInstruction = ""
    }

    @MainActor
    func applyEdit() async {
        guard let currentResult = resultImage, !editInstruction.isEmpty else { return }

        state = .processing

        do {
            let newResult = try await geminiService.refineImage(currentResult, instructions: editInstruction)

            let edit = ImageEdit(
                instruction: editInstruction,
                previousImage: currentResult,
                newImage: newResult
            )
            editHistory.append(edit)

            resultImage = newResult
            state = .result
            editInstruction = ""
        } catch {
            state = .result
        }
    }

    func saveToCloset(modelContext: ModelContext) {
        guard let clothing = clothingImage, let user = userImage, let result = resultImage else { return }

        let tryOnResult = TryOnResult(
            clothingImage: clothing,
            userPhoto: user,
            resultImage: result,
            editHistory: editHistory
        )

        modelContext.insert(tryOnResult)
    }

    func reset() {
        state = .idle
        clothingImage = nil
        userImage = nil
        resultImage = nil
        editInstruction = ""
        editHistory = []
    }
}
