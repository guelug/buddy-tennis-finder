import ExpoModulesCore
import StoreKit
import UIKit
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable
private struct MatchPointAssistantReply {
  @Guide(description: "Una respuesta breve y natural en español, sin JSON, sin Markdown y sin bloques de código.")
  var answer: String
}
#endif

public final class MatchPointLocalAIModule: Module {
  public func definition() -> ModuleDefinition {
    Name("MatchPointLocalAI")

    AsyncFunction("getAvailability") { () -> [String: Any] in
      #if canImport(FoundationModels)
      if #available(iOS 26.0, *) {
        switch SystemLanguageModel.default.availability {
        case .available:
          return ["available": true, "provider": "apple-intelligence"]
        case .unavailable(let reason):
          return [
            "available": false,
            "provider": "apple-intelligence",
            "reason": String(describing: reason)
          ]
        @unknown default:
          return ["available": false, "provider": "apple-intelligence", "reason": "Modelo no disponible"]
        }
      }
      #endif
      return ["available": false, "provider": "fallback", "reason": "Requiere Apple Intelligence"]
    }

    AsyncFunction("presentOfferCodeRedeemSheet") { () async throws -> [String: Any] in
      try await OfferCodeRedemption.present()
    }

    AsyncFunction("generate") { (prompt: String) async throws -> String in
      #if canImport(FoundationModels)
      if #available(iOS 26.0, *) {
        guard case .available = SystemLanguageModel.default.availability else {
          throw LocalAIError.unavailable
        }
        let session = LanguageModelSession(
          instructions: """
          Eres MatchPoint Assistant, un compañero de tenis cercano.
          Responde en español con una o dos frases naturales y útiles.
          Usa exclusivamente los datos verificados proporcionados por la app.
          Si un dato no aparece, dilo claramente.
          No inventes partidos, resultados, torneos ni consejos médicos.
          Nunca muestres JSON, claves internas, Markdown ni bloques de código.
          """
        )
        let response = try await session.respond(
          to: prompt,
          generating: MatchPointAssistantReply.self
        )
        return response.content.answer
      }
      #endif
      throw LocalAIError.unavailable
    }
  }
}

private enum LocalAIError: Error {
  case unavailable
}


enum OfferCodeRedemption {
  @MainActor
  static func present() async throws -> [String: Any] {
    guard let scene = activeWindowScene() else {
      throw OfferCodeError.noScene
    }
    if #available(iOS 27.0, *) {
      guard let presenter = topViewController(in: scene) else {
        throw OfferCodeError.noScene
      }
      let result = try await AppStore.presentOfferCodeRedeemSheet(from: presenter, options: [])
      switch result {
      case .verified(let transaction):
        return [
          "verified": true,
          "productId": transaction.productID,
          "transactionId": String(transaction.id)
        ]
      case .unverified(_, let error):
        throw error
      }
    }
    try await AppStore.presentOfferCodeRedeemSheet(in: scene)
    return ["verified": false, "presented": true]
  }

  private static func activeWindowScene() -> UIWindowScene? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
  }

  private static func topViewController(in scene: UIWindowScene) -> UIViewController? {
    let window = scene.windows.first { $0.isKeyWindow } ?? scene.windows.first
    var current = window?.rootViewController
    while let presented = current?.presentedViewController {
      current = presented
    }
    return current
  }
}

private enum OfferCodeError: Error, LocalizedError {
  case noScene
  var errorDescription: String? { "No se pudo presentar el cupón de App Store." }
}
