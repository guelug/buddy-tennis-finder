package com.matchpoint.localai

import android.os.Build
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class MatchPointLocalAIModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("MatchPointLocalAI")

    AsyncFunction("getAvailability") { promise: Promise ->
      if (Build.VERSION.SDK_INT < 26) {
        promise.resolve(mapOf("available" to false, "provider" to "fallback", "reason" to "Requiere Android 8 o posterior"))
      } else {
        GeminiNanoBridge.checkAvailability(object : GeminiNanoBridge.AvailabilityCallback {
          override fun onResult(status: Int) {
            val result = when (status) {
              GeminiNanoBridge.AVAILABLE -> mapOf("available" to true, "provider" to "gemini-nano")
              GeminiNanoBridge.DOWNLOADABLE -> mapOf("available" to false, "downloadable" to true, "provider" to "gemini-nano")
              GeminiNanoBridge.DOWNLOADING -> mapOf("available" to false, "provider" to "gemini-nano", "reason" to "Descargando Gemini Nano")
              else -> mapOf("available" to false, "provider" to "fallback", "reason" to "Gemini Nano no está disponible")
            }
            promise.resolve(result)
          }

          override fun onError(message: String) {
            promise.resolve(mapOf("available" to false, "provider" to "fallback", "reason" to message))
          }
        })
      }
    }

    AsyncFunction("generate") { prompt: String, promise: Promise ->
      if (Build.VERSION.SDK_INT < 26) {
        promise.reject("ERR_UNAVAILABLE", "Requiere Android 8 o posterior", null)
      } else {
        val instruction = """
          Eres un compañero de tenis dentro de MatchPoint. Usa el nombre del
          asistente y el idioma indicados por la app. Responde de forma breve y útil.
          Usa exclusivamente los datos proporcionados. Si un dato no aparece,
          dilo claramente. No inventes partidos, resultados ni torneos.

          $prompt
        """.trimIndent()
        GeminiNanoBridge.generate(instruction, object : GeminiNanoBridge.GenerationCallback {
          override fun onResult(text: String) = promise.resolve(text)
          override fun onError(message: String) = promise.reject("ERR_GENERATION", message, null)
        })
      }
    }
  }
}
