import ExpoModulesCore
import StoreKit
import UIKit
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable
private struct MatchPointAssistantReply {
  @Guide(description: "Una respuesta breve y natural en el idioma solicitado, sin JSON, sin Markdown y sin bloques de código.")
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
          Eres un compañero de tenis cercano dentro de MatchPoint.
          Usa el nombre del asistente y el idioma indicados por la app en el prompt.
          Responde con una o dos frases naturales y útiles.
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
  /// Present the system offer-code sheet.
  /// Uses the StoreKit 16+ `in:` API so Xcode Cloud (Xcode 26 / App Store–eligible)
  /// can archive. The iOS 27 `from:options:` VerificationResult overload requires
  /// an App Store–eligible Xcode 27 toolchain; re-enable when Cloud ships that.
  @MainActor
  static func present() async throws -> [String: Any] {
    guard let scene = activeWindowScene() else {
      throw OfferCodeError.noScene
    }
    try await AppStore.presentOfferCodeRedeemSheet(in: scene)
    return ["verified": false, "presented": true]
  }

  private static func activeWindowScene() -> UIWindowScene? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    return scenes.first { $0.activationState == .foregroundActive }
  }
}

private enum OfferCodeError: Error, LocalizedError {
  case noScene
  var errorDescription: String? { "No se pudo presentar el cupón de App Store." }
}
