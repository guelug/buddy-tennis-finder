# Personal Shooper - Apple Intelligence Upgrade

## Resumen de Cambios

Este documento describe las mejoras implementadas para integrar **Apple Foundation Models** nativamente en la app, maximizando la privacidad del usuario al procesar todo localmente en el dispositivo.

---

## 🚀 Nuevas Características

### 1. Apple Foundation Models Nativo (iOS 26+)

La app ahora detecta automáticamente si el dispositivo soporta Apple Foundation Models y usa el framework nativo `FoundationModels` cuando está disponible.

**Archivos nuevos:**
- `PersonalShooper/Features/Chat/Services/FoundationModelsService.swift`

**Características:**
- ✅ Procesamiento 100% local (sin conexión a internet)
- ✅ Streaming de respuestas en tiempo real
- ✅ Tools personalizadas para consultar el armario del usuario
- ✅ Guided Generation para respuestas estructuradas
- ✅ Pre-warming del modelo para respuestas más rápidas

### 2. Sistema de Streaming

Las respuestas del AI ahora aparecen palabra por palabra en lugar de esperar a que se genere todo el mensaje.

**Mejoras en UI:**
- Indicador de "typing" con animación
- Indicador de streaming con puntos animados
- Scroll automático al recibir nuevos mensajes

### 3. Tools Personalizadas (Closet Tool)

El AI puede ahora consultar el armario virtual del usuario para dar recomendaciones más personalizadas.

**Funcionalidad:**
- Buscar prendas por categoría
- Filtrar por color
- Buscar por ocasión
- Filtrar por estilo

### 4. Servicio de Recomendaciones Mejorado

Nuevo servicio dedicado para generar recomendaciones de moda personalizadas.

**Archivo nuevo:**
- `PersonalShooper/Features/Chat/Services/AIRecommendationService.swift`

**Funcionalidades:**
- Recomendaciones de outfits por ocasión
- Análisis de paleta de colores
- Análisis del armario
- Recomendaciones estacionales

### 5. Fallback Inteligente Mejorado

Para dispositivos sin Foundation Models, el sistema usa `EnhancedAppleIntelligenceService` con:

- Análisis de sentimiento
- Detección de intenciones mejorada
- Respuestas contextualizadas
- Caché de respuestas frecuentes
- Soporte completo de español e inglés

### 6. Apple Image Playground & Visual Intelligence

**Apple Image Playground (iOS 18.4+)**
- Generación local y privada de imágenes de moda estilizadas.
- Proveedor de try-on `.playground` usa `ImageCreator` para crear inspiraciones de look, thumbnails limpios de prendas y variaciones de estilo.
- Fallback automático al placeholder estilizado si Image Playground no está disponible.
- `StyleImageService` usa Image Playground como alternativa local cuando no hay clave externa configurada.

**Visual Intelligence (iOS 26+)**
- `PersonalShooperVisualSearchIntent` adopta el esquema `.visualIntelligence.semanticContentSearch` para permitir búsquedas visuales del armario desde la cámara o fotos del sistema.

---

## 📁 Estructura de Archivos Modificados

```
PersonalShooper/
├── Features/
│   ├── Chat/
│   │   ├── Services/
│   │   │   ├── AppleIntelligenceService.swift (✏️ Mejorado)
│   │   │   ├── FoundationModelsService.swift (🆕 Nuevo)
│   │   │   └── AIRecommendationService.swift (🆕 Nuevo)
│   │   ├── ViewModels/
│   │   │   └── ChatViewModel.swift (✏️ Mejorado con streaming)
│   │   └── Views/
│   │       ├── ChatView.swift (✏️ Mejorado con UI de streaming)
│   │       └── HomeView.swift (✏️ Pulido)
│   ├── TryOn/
│   │   └── Services/
│   │       ├── ImagePlaygroundTryOnService.swift (🆕 Nuevo)
│   │       └── TryOnProviderService.swift (✏️ Mejorado)
│   ├── Profile/
│   │   └── Services/
│   │       ├── PhotoAnalysisService.swift (✏️ Mejorado con Vision framework)
│   │       └── StyleImageService.swift (✏️ Usa Image Playground como fallback)
│   └── Recommendations/
│       └── Intents/
│           └── DailyStyleRecommendationIntent.swift (✏️ Visual Intelligence)
├── Core/
│   └── Navigation/
│       └── MainTabView.swift (✏️ Pulido)
├── Info.plist (✏️ Actualizado con permisos Apple Intelligence)
├── PersonalShooper.entitlements (✏️ Actualizado)
└── project.yml (✏️ Frameworks ImagePlayground y VisualIntelligence)
```

---

## 🔒 Privacidad Mejorada

### Procesamiento Local
- **Todas las conversaciones** se procesan en el dispositivo
- **Las fotos** nunca salen del dispositivo
- **No hay llamadas a APIs externas** para el chat (excepto Try-On con Gemini)

### Permisos Actualizados
```xml
<key>NSAppleIntelligenceUsageDescription</key>
<string>Personal Shooper uses Apple Intelligence to provide personalized fashion advice directly on your device...</string>
```

---

## 🛠️ Requisitos Técnicos

### iOS 26+ (Foundation Models)
- Dispositivo compatible con Apple Intelligence
- Xcode 26+
- Swift 6.0
- Frameworks:
  - `FoundationModels` (weak link)
  - `Playgrounds` (weak link)
  - `NaturalLanguage`
  - `Vision`

### Fallback (iOS 17.2+)
- Funciona en cualquier dispositivo iOS 17.2+
- No requiere Apple Intelligence
- Usa análisis local con `NaturalLanguage`

---

## 📝 Código de Ejemplo

### Usar Foundation Models con Streaming

```swift
@available(iOS 26.0, *)
func chatWithStreaming() async {
    let service = FoundationModelsService()
    
    // Pre-calentar el modelo
    await service.prewarm()
    
    // Streaming de respuesta
    let stream = service.streamMessage("What colors suit me?", context: chatContext)
    
    for try await partialText in stream {
        print(partialText) // Actualizar UI en tiempo real
    }
}
```

### Generar Recomendación Estructurada

```swift
@available(iOS 26.0, *)
func getOutfitRecommendation() async throws {
    let service = FoundationModelsService()
    
    let recommendation = try await service.generateOutfitRecommendation(
        occasion: "Work meeting",
        context: userContext
    )
    
    print(recommendation.name)
    print(recommendation.items)
    print(recommendation.stylingTips)
}
```

### Usar la Tool de Closet

```swift
@available(iOS 26.0, *)
struct MyClothingTool: Tool {
    var name: String { "closet_search" }
    var description: String { "Search user's closet" }
    
    @Generable
    struct Arguments {
        let category: String?
        let color: String?
    }
    
    func call(arguments: Arguments) async throws -> ToolOutput {
        // Buscar en SwiftData
        let items = try await fetchItems(category: arguments.category)
        return ToolOutput("Found: \(items.count) items")
    }
}
```

---

## 🎯 Mejoras en el Backend

### PhotoAnalysisService
- ✅ Detección de landmarks faciales con Vision
- ✅ Filtro mejorado de tonos de piel
- ✅ Muestreo en grid para mejor precisión
- ✅ Manejo de errores más granular
- ✅ Validación de múltiples rostros

### ChatViewModel
- ✅ Soporte para streaming
- ✅ Cancelación de tareas
- ✅ Caché de conversaciones
- ✅ Manejo de estado de disponibilidad de AI
- ✅ Integración con SwiftData para closet

---

## 🔧 Configuración del Proyecto

### project.yml Actualizado
```yaml
deploymentTarget:
  iOS: "26.0"
xcodeVersion: "16.0"
SWIFT_VERSION: "6.0"

dependencies:
  - sdk: FoundationModels.framework (weak)
  - sdk: Playgrounds.framework (weak)
  - sdk: NaturalLanguage.framework
```

### Entitlements Agregados
```xml
<key>com.apple.developer.on-device-ml</key>
<true/>
```

---

## 🌐 Internacionalización

El sistema ahora detecta automáticamente el idioma del usuario:
- Inglés (default)
- Español (detección automática por palabras clave)

Todas las respuestas se generan en el idioma detectado.

---

## 📱 Compatibilidad

| Característica | iOS 26+ | iOS 18.4-25 | iOS 17.2-18.3 | iOS < 17.2 |
|---------------|---------|-------------|---------------|------------|
| Foundation Models | ✅ Nativo | ❌ | ❌ | ❌ |
| Streaming | ✅ | ⚠️ Simulado | ⚠️ Simulado | ❌ |
| Tools (Closet) | ✅ | ❌ | ❌ | ❌ |
| Fallback IA | ✅ | ✅ | ✅ | ✅ Básico |
| Análisis de fotos | ✅ Mejorado | ✅ | ✅ | ⚠️ Básico |
| Image Playground (try-on/thumbnails) | ✅ | ✅ (18.4+) | ❌ | ❌ |
| Visual Intelligence (búsqueda visual) | ✅ | ❌ | ❌ | ❌ |

---

## 🚀 Próximos Pasos Sugeridos

1. **Implementar Siri Intents** para consultas por voz ✅
2. **Añadir Widgets** con recomendaciones diarias ✅
3. **Live Activities** para sesiones de try-on
4. **Image Playground** para generar looks inspirados ✅
5. **Genmoji** para reacciones en el chat

---

## 📚 Recursos

- [Apple Foundation Models Documentation](https://developer.apple.com/apple-intelligence/)
- [Foundation Models Framework Guide](https://azamsharp.com/2025/06/18/the-ultimate-guide-to-the-foundation-models-framework.html)
- [Apple Intelligence Tech Report](https://machinelearning.apple.com/research/apple-foundation-models-tech-report-2025)

---

## ✅ Checklist de Implementación

- [x] Servicio Foundation Models nativo
- [x] Sistema de streaming
- [x] Tools personalizadas (Closet)
- [x] Fallback mejorado
- [x] Servicio de recomendaciones
- [x] UI con indicadores de typing/streaming
- [x] PhotoAnalysisService mejorado
- [x] Apple Image Playground integrado en try-on y thumbnails
- [x] Visual Intelligence intent para búsqueda visual del armario
- [x] project.yml actualizado
- [x] Info.plist con permisos Apple Intelligence
- [x] Entitlements actualizados
- [x] Documentación completa

---

**Nota:** Foundation Models requiere iOS 26+ y dispositivos compatibles con Apple Intelligence (iPhone 15 Pro/Max o posteriores). La app funciona perfectamente con el sistema fallback en dispositivos anteriores.
