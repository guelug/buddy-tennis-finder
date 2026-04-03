# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Personal Shooper** is a premium iOS application that combines AI-powered fashion advice with virtual clothing try-on capabilities. The app features a clean, Apple-inspired design aesthetic with a personal stylist assistant.

### Key Technologies
- **UI Framework**: SwiftUI with UIKit integration where needed
- **AI Assistant**: Apple Intelligence (Foundation Models) for privacy-first chat interactions
- **Virtual Try-On**: Google Gemini (Nano Banana) for clothing visualization
- **AR Features**: ARKit for augmented reality experiences
- **Payments**: Apple Pay subscriptions via StoreKit
- **On-Device ML**: Apple Foundation Models (iOS 26+), Vision framework for photo analysis

### Design Language
- Premium, clean aesthetic inspired by Apple/Claude Code
- Primary colors: White backgrounds, subtle gradients, accent colors for CTAs
- System semantic colors (`.systemBackground`, `.label`)
- Dark mode support
- Touch targets minimum 44pt
- 8pt spacing grid

---

## Build Commands

```bash
# Build the project
xcodebuild -project PersonalShooper.xcodeproj -scheme PersonalShooper -configuration Debug build

# Build for release
xcodebuild -project PersonalShooper.xcodeproj -scheme PersonalShooper -configuration Release build

# Run on simulator
xcrun simctl list devices available
xcrun simctl boot <device_id>
xcodebuild -project PersonalShooper.xcodeproj -scheme PersonalShooper -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Clean build
xcodebuild -project PersonalShooper.xcodeproj -scheme PersonalShooper clean
```

---

## Architecture

### App Structure
```
PersonalShooper/
├── App/
│   └── PersonalShooperApp.swift          # App entry point
├── Features/
│   ├── Chat/
│   │   ├── Views/                         # Chat UI
│   │   ├── ViewModels/                    # Chat state management
│   │   └── Services/
│   │       ├── AppleIntelligenceService.swift   # Enhanced fallback
│   │       ├── FoundationModelsService.swift    # iOS 26+ native AI
│   │       └── AIRecommendationService.swift    # Fashion recommendations
│   ├── TryOn/
│   │   ├── Views/                         # Camera/AR views
│   │   ├── ViewModels/
│   │   └── Services/
│   │       └── GeminiTryOnService.swift   # Google Gemini integration
│   ├── Profile/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Services/
│   │       ├── PhotoAnalysisService.swift  # Skin tone, features extraction
│   │       ├── SkinToneExtractor.swift     # Color analysis
│   │       └── ProfileStorageService.swift # Local photo storage
│   ├── Closet/
│   │   └── Views/ClosetView.swift         # Virtual wardrobe
│   ├── AR/
│   │   ├── Views/ARWardrobeView.swift
│   │   └── ViewModels/ARViewModel.swift
│   └── Subscription/
│       └── StoreKitManager.swift          # Apple Pay subscriptions
├── Core/
│   ├── Design/
│   │   ├── Theme.swift                    # Colors, typography, spacing
│   │   └── Components/                    # Reusable UI components
│   ├── Extensions/
│   └── Utilities/
└── Resources/
    ├── Assets.xcassets
    └── Localizable.xcstrings              # English/Spanish translations
```

### AI Integration Strategy

| Feature | Provider | Privacy | Status |
|---------|----------|---------|--------|
| Chat Assistant | Apple Intelligence (Foundation Models) | Full local processing | ✅ iOS 26+ |
| Chat Fallback | Enhanced Local AI | Local keyword analysis | ✅ iOS 17.2+ |
| Virtual Try-On | Google Gemini (Nano Banana) | API calls, no local storage | ✅ All versions |
| Skin Tone Analysis | Local (CoreML/Vision) | Photos never leave device | ✅ All versions |
| Color Recommendations | Apple Intelligence | Full local processing | ✅ iOS 26+ |
| Outfit Recommendations | Apple Intelligence | Full local processing | ✅ iOS 26+ |

### Foundation Models Integration

**New in iOS 26+:**

```swift
import FoundationModels

// Create a session
let session = LanguageModelSession()

// Simple prompt
let response = try await session.respond(to: "What colors suit me?")

// Streaming
let stream = session.streamResponse(to: "Suggest an outfit")
for try await text in stream {
    updateUI(text)
}

// Guided generation (structured output)
let outfit = try await session.respond(to: "Create an outfit", 
                                        generating: OutfitRecommendation.self)
```

**Tools Integration:**

```swift
struct ClosetTool: Tool {
    var name: String { "closet_search" }
    var description: String { "Search user's wardrobe" }
    
    @Generable
    struct Arguments {
        let category: String?
        let color: String?
    }
    
    func call(arguments: Arguments) async throws -> ToolOutput {
        // Implementation
    }
}
```

### Profile Photo System

User uploads 4 photos for personalization:
1. **Face close-up** (front) - For skin tone extraction and facial analysis
2. **Face profile** (side) - For facial structure understanding
3. **Full body front** - For proportions and style recommendations
4. **Full body back** - For complete wardrobe suggestions

Photos are stored locally with explicit user consent. A privacy notice explains data usage before any upload.

---

## Features

### 1. AI Chat Assistant

**Foundation Models (iOS 26+):**
- Powered by on-device Apple Foundation Models
- Zero data leaving the device
- Streaming responses for better UX
- Custom tools for closet integration
- Context-aware using user's profile data

**Fallback (older iOS):**
- Enhanced keyword-based responses
- Sentiment analysis
- Multi-language support (EN/ES)
- Response caching

### 2. Virtual Try-On
- Uses Google Gemini (Nano Banana) image generation
- User takes photo of clothing item, then photo of themselves
- AI generates realistic image of user wearing the garment
- Supports multi-turn editing (adjust fit, style, lighting)

### 3. AR Experiences
- ARKit integration for real-time clothing visualization
- AR wardrobe preview in user's actual environment
- (Future) AR shopping experience

### 4. Profile & Personalization
- **Physical Attributes**: Extracted from photos (skin tone, body type hints)
- **Style Preferences**: User-selected style keywords
- **Color Palette**: Personal color recommendations based on skin undertone
- **Size Information**: For accurate sizing suggestions

### 5. Subscription System
- Apple Pay integration via StoreKit 2
- Tiers: Free (limited try-ons), Premium (unlimited)
- Privacy-first: No data sharing with third parties

---

## Configuration

### Required Capabilities
- Camera (for photos and try-on)
- Photo Library (for saving try-on results)
- ARKit (for augmented reality features)
- In-App Purchase (for subscriptions)
- Sign in with Apple (for user accounts)
- **Apple Intelligence** (for on-device AI, iOS 26+)

### Info.plist Keys
```xml
NSCameraUsageDescription - "Take photos to try on clothes virtually"
NSPhotoLibraryUsageDescription - "Save and access your try-on photos"
NSPhotoLibraryAddUsageDescription - "Save your favorite looks"
NSAppleIntelligenceUsageDescription - "Process fashion advice on your device"
```

### Entitlements
```xml
com.apple.developer.on-device-ml - Required for Foundation Models
com.apple.developer.icloud-container-identifiers - For data sync
com.apple.developer.in-app-purchase - For subscriptions
```

### Environment Variables
Create `PersonalShooper/Config.xcconfig`:
```
GEMINI_API_KEY = your_gemini_api_key
```

---

## Development Guidelines

### Code Style
- SwiftUI for all new UI development
- MVVM architecture with `@Observable` (iOS 17+)
- Dependency injection for services
- Protocol-oriented design for testability
- Swift 6 strict concurrency

### Foundation Models Integration
- Use `@Generable` macro for structured output
- Use `LanguageModelSession` for conversation state
- Implement `Tool` protocol for app integrations
- Always check availability with `SystemLanguageModel.default.availability`
- Pre-warm model when user likely to engage: `await session.prewarm()`

### Privacy Requirements
- Never send user photos to external AI
- Use on-device processing for all personal data
- Anonymize any analytics data
- Clear privacy notices for all data collection

### Color Extraction Pipeline
1. User photo → Vision framework → Face detection with landmarks
2. Skin region extraction using face contour and cheeks
3. Grid-based color sampling with skin tone filtering
4. CoreML classification → Undertone analysis (warm/cool/neutral)
5. Seasonal palette generation based on undertone + brightness
6. Palette stored locally, passed as context to AI assistant

### Testing
```bash
# Run unit tests
xcodebuild test -project PersonalShooper.xcodeproj -scheme PersonalShooperTests

# Run UI tests
xcodebuild test -project PersonalShooper.xcodeproj -scheme PersonalShooperUITests
```

---

## Localization

The app supports English and Spanish with automatic language detection.

```
Resources/
├── en.xcloc/
│   └── Contents.json
└── es.xcloc/
    └── Contents.json
```

---

## Migration Notes

### From older versions to Foundation Models:

1. Replace direct `AppleIntelligenceService` calls with `AIChatServiceFactory.createService()`
2. Use streaming API for better UX: `viewModel.sendMessage(useStreaming: true)`
3. Add Tools to `LanguageModelSession` for app integrations
4. Update deployment target to iOS 26.0 for full features

---

## Resources

- [Apple Intelligence Documentation](https://developer.apple.com/apple-intelligence/)
- [Foundation Models Framework Guide](https://developer.apple.com/documentation/foundationmodels)
- [Vision Framework](https://developer.apple.com/documentation/vision)
- [SwiftData](https://developer.apple.com/documentation/swiftdata)
