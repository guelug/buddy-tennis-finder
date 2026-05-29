# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

**Personal Shooper** is a premium iOS application combining AI-powered fashion advice with virtual clothing try-on and AR experiences. The app uses a clean, Apple-inspired design with a personal stylist AI assistant.

### Key Technologies
- **UI Framework**: SwiftUI with UIKit integration (UIViewRepresentable for ARKit)
- **AI**: Apple Foundation Models (iOS 26+) with NaturalLanguage fallback (iOS 17.2+)
- **Virtual Try-On**: Google Gemini API for clothing visualization
- **AR**: ARKit + RealityKit for augmented reality wardrobe preview
- **Payments**: StoreKit 2 for Apple Pay subscriptions
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

### App Store Connect / TestFlight
Local App Store Connect API configuration is stored in `.env.appstoreconnect` and ignored by git.

```bash
ASC_KEY_ID=Q2FTX4KKUY
ASC_ISSUER_ID=1d27a2f2-265a-4650-a4a7-84929712d622
ASC_KEY_PATH=/Users/guelug/.appstoreconnect/private_keys/AuthKey_Q2FTX4KKUY.p8
```

Current App Store Connect state:
- Bundle ID exists: `com.personalshooper.app`
- App record exists: `Personal Shooper`, App Store Connect ID `6774502051`, primary locale `es-ES`.
- Latest uploaded TestFlight build: version `1.0.0`, build `2`, state `VALID`, uploaded on 2026-05-29.
- Use `scripts/upload-testflight.sh` for the same Xcode archive/export/upload flow used by `girls_calendar`.

### SDK Dependencies (weakly linked for graceful fallback)
- `FoundationModels.framework` (iOS 26+)
- `Playgrounds.framework` (iOS 26+)
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
