# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Personal Shooper** is a premium iOS application combining AI-powered fashion advice with virtual clothing try-on and AR experiences. The app uses a clean, Apple-inspired design with a personal stylist AI assistant.

### Key Technologies
- **UI Framework**: SwiftUI with UIKit integration (UIViewRepresentable for ARKit)
- **AI**: Apple Foundation Models (iOS 26+) with NaturalLanguage fallback (iOS 17.2+)
- **Virtual Try-On**: Google Gemini API + Apple Image Playground for on-device stylised previews
- **AR**: ARKit + RealityKit for augmented reality wardrobe preview
- **Payments**: StoreKit 2 for subscriptions + one-time unlocks (Apple Intelligence+, BYOK)
- **Data**: SwiftData for local persistence
- **ML**: Vision framework for face detection and skin tone analysis

---

## Build Commands

```bash
# List available simulators
xcrun simctl list devices available

# Build for simulator
xcodebuild -project PersonalShooper.xcodeproj -scheme PersonalShooper -configuration Debug build -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Clean build
xcodebuild -project PersonalShooper.xcodeproj -scheme PersonalShooper clean

# Run tests
xcodebuild test -project PersonalShooper.xcodeproj -scheme PersonalShooperTests
```

**Project Configuration:**
- Deployment target: iOS 26.0
- Swift version: 6.0
- Project generator: XcodeGen (`project.yml`)

---

## Architecture

### App Structure
```
PersonalShooper/
├── App/
│   └── PersonalShooperApp.swift       # Entry point, SwiftData container setup
├── Features/
│   ├── Chat/                          # AI stylist chat
│   │   ├── Views/: HomeView, ChatView, ChatHistoryView
│   │   ├── ViewModels/: ChatViewModel
│   │   └── Services/: AppleIntelligenceService, FoundationModelsService, AIRecommendationService
│   ├── TryOn/                         # Virtual clothing try-on
│   │   ├── Views/: TryOnView
│   │   ├── ViewModels/: TryOnViewModel
│   │   └── Services/: GeminiTryOnService
│   ├── Profile/                       # User profile & photo upload
│   │   ├── Views/: ProfileView, PhotoUploadView, PrivacyNoticeView
│   │   └── Services/: PhotoAnalysisService, SkinToneExtractor, ProfileStorageService
│   ├── Closet/                        # Virtual wardrobe
│   ├── AR/                            # AR wardrobe preview
│   │   ├── Views/: ARWardrobeView
│   │   └── ViewModels/: ARViewModel
│   └── Subscription/
│       └── StoreKitManager.swift      # StoreKit 2 wrapper
├── Core/
│   ├── Design/Theme.swift              # Colors, spacing, shadows
│   ├── Navigation/MainTabView.swift    # Tab-based navigation
│   └── Components/CameraCaptureView.swift
└── Models/
    ├── User.swift                     # SwiftData @Model
    ├── Conversation.swift             # SwiftData @Model
    ├── ClothingItem.swift             # SwiftData @Model
    └── Analysis.swift                # PersonalPalette, SkinTone, CodableColor
```

### AI Service Architecture

The app uses a factory pattern to select AI implementation based on iOS version:

```
AIChatServiceFactory.createService()
├── iOS 26+: FoundationModelsService (native on-device AI)
│   ├── Uses LanguageModelSession from FoundationModels framework
│   ├── Supports streaming responses
│   ├── Tools: ClothingRecommendationTool for closet search
│   └── Guided generation for structured OutfitRecommendation
│
└── iOS 17.2+: EnhancedAppleIntelligenceService (fallback)
    ├── NaturalLanguage framework for sentiment/keyword analysis
    ├── Contextual fallback responses by category
    └── Bilingual EN/ES support
```

Key protocols:
- `AIChatServiceProtocol` - basic sendMessage
- `FoundationModelsServiceProtocol` - streaming + prewarm
- `ClothingDataServiceProtocol` - closet search for AI tools

### Monetization Model

`StoreKitManager` tracks the set of purchased product IDs and derives orthogonal feature gates:

- `hasAppleIntelligenceFeatures` — Siri AI, on-device tools, Image Playground, Visual Intelligence.
- `hasBYOKPurchase` — use your own API keys (OpenAI, Gemini, Grok, etc.).
- `hasExternalProviderCredits` — cloud try-on/image credits (Premium/Pro subscriptions).
- `hasAnyPaidUnlock` — lifts the closet limit from 20 to 100 garments.

Tiers:
- `free` — 20 garments, Apple Foundation chat where supported.
- `appleIntelligencePlus` (one-time) — 100 garments, Siri AI + Vision + Playground.
- `byok` (one-time) — 100 garments, BYOK providers.
- `premium` / `pro` (subscriptions) — cloud credits + all above.
- `lifetime` / `byokLite` — legacy, preserved and mapped to equivalent feature sets.

Product IDs to create in App Store Connect:
- `com.personalshooper.appleintelligenceplus`
- `com.personalshooper.byok`

### Data Model

**SwiftData Models:**
- `User` - profile photos (stored as Data), personalPalette, stylePreferences
- `Conversation` - title, messages (cascade delete), timestamps
- `Message` - role (user/assistant), content, imageURL, timestamp
- `ClothingItem` - category, imageData, colorTags, styleTags, wear tracking
- `TryOnResult` - clothing/user/result images, edit history

**Codable Structs (JSON encoded in User):**
- `PersonalPalette` - seasonalType, undertone, recommendedColors
- `SkinAnalysisResult` - dominantColors, undertone, confidence
- `ProfilePhotos` - UIImage? wrapper (faceCloseUp, faceProfile, fullBodyFront, fullBodyBack)

---

## Key Implementation Details

### AppState
- `@Observable` class holding currentUser, isPremium, preferredLanguage
- Uses `StoreKitManager` for subscription status
- Injected via `.environment(AppState())` to SwiftUI views

### Tab Navigation
- `MainTabView` uses `TabView` with 5 tabs: home, tryOn, ar, closet, profile
- `HomeView` takes optional `selectedTab` binding for quick action navigation
- Each tab is a separate view embedded in NavigationStack

### Photo Upload Flow
1. User taps photo thumbnail in ProfileView
2. PrivacyNoticeView presented first (consent)
3. PhotoUploadView uses PhotosPicker (iOS 17+) for modern UX
4. PhotoAnalysisService extracts skin tone via Vision framework
5. PersonalPalette generated and stored in User.personalPaletteData

### Chat Flow
1. ChatView uses ChatViewModel (@Observable, @MainActor)
2. setContext() configures ChatContext from AppState
3. AIChatServiceFactory.createService() picks implementation
4. Responses append to Conversation.messages via SwiftData
5. HomeView displays recent conversations via @Query

### AR Implementation
- ARWardrobeView uses ARViewContainer (UIViewRepresentable)
- ARViewModel manages clothing selection, placement, removal
- Tap gesture raycasts to horizontal plane for clothing placement
- ClothingPickerSheet presents grid of closet items

### Image Playground & Visual Intelligence
- `ImagePlaygroundTryOnService` wraps `ImageCreator` for local, private outfit inspiration, clean garment thumbnails, and style variations.
- TryOn provider `.playground` now uses real Image Playground generation when available, falling back to the stylised placeholder only when unavailable.
- `StyleImageService` uses Image Playground as a no-key fallback for closet marketing thumbnails.
- `PersonalShooperVisualSearchIntent` adopts the `.visualIntelligence.semanticContentSearch` schema to let users search the closet from system visual lookups (iOS 26+).

---

## Configuration

### Required Capabilities (Info.plist)
- `NSCameraUsageDescription` - Take photos for try-on
- `NSPhotoLibraryUsageDescription` - Access photos for styling
- `NSAppleIntelligenceUsageDescription` - On-device AI fashion advice

### Entitlements
- `com.apple.developer.on-device-ml` - Foundation Models
- `com.apple.developer.in-app-purchase` - Subscriptions

### Environment
```bash
# Create PersonalShooper/Config.xcconfig
GEMINI_API_KEY = your_api_key
```

### SDK Dependencies (weakly linked for graceful fallback)
- `FoundationModels.framework` (iOS 26+)
- `ImagePlayground.framework` (iOS 18.1+, weak)
- `VisualIntelligence.framework` (iOS 26+, weak, device-only link)
- `ARKit.framework`, `RealityKit.framework`, `Vision.framework`
- `CoreML.framework`, `NaturalLanguage.framework`, `StoreKit.framework`

---

## Privacy Requirements

- User photos stored locally only, never sent to external AI
- Skin analysis uses Vision framework on-device
- Chat AI fully local on iOS 26+ (Foundation Models)
- External API calls only for: Gemini Try-On (images only), StoreKit (payments)
- Privacy notice required before any photo upload

---

## Resources

- [Apple Foundation Models](https://developer.apple.com/documentation/foundationmodels)
- [Vision Framework](https://developer.apple.com/documentation/vision)
- [ARKit Documentation](https://developer.apple.com/documentation/arkit)
- [SwiftData](https://developer.apple.com/documentation/swiftdata)
