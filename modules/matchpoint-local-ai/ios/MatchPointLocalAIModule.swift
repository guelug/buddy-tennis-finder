import ExpoModulesCore
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
