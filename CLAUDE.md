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
│   │       └── AppleIntelligenceService.swift  # Apple Foundation integration
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
│   │       └── StorageService.swift        # Local photo storage
│   └── Subscription/
│       └── StoreKitManager.swift           # Apple Pay subscriptions
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

| Feature | Provider | Privacy |
|---------|----------|---------|
| Chat Assistant | Apple Intelligence (Foundation Models) | Full local processing |
| Virtual Try-On | Google Gemini (Nano Banana) | API calls, no local storage |
| Skin Tone Analysis | Local (CoreML/Vision) | Photos never leave device |
| Color Recommendations | Apple Intelligence | Full local processing |

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
- Powered by Apple Foundation Models for privacy
- Context-aware responses using user's profile data
- Color and style recommendations based on extracted skin tone
- Bilingual support (English/Spanish)
- Conversation history stored locally

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

### Info.plist Keys
```xml
NSCameraUsageDescription - "Take photos to try on clothes virtually"
NSPhotoLibraryUsageDescription - "Save and access your try-on photos"
NSPhotoLibraryAddUsageDescription - "Save your favorite looks"
```

### Environment Variables
Create `PersonalShooper/Config.xcconfig`:
```
GEMINI_API_KEY = your_gemini_api_key
APPLE_INTELLIGENCE_ENABLED = true
```

---

## Localization

The app supports English and Spanish. Use `.xcloc` files for translations.

```
Resources/
├── en.xcloc/
│   └── Contents.json
└── es.xcloc/
    └── Contents.json
```

---

## Development Guidelines

### Code Style
- SwiftUI for all new UI development
- MVVM architecture with `@Observable` (iOS 17+)
- Dependency injection for services
- Protocol-oriented design for testability

### Apple Intelligence Integration
- Use `APrompt` or `MSG prompt` components from Apple frameworks
- Respect privacy: Never send user photos to external AI
- Fallback to local processing if Apple Intelligence unavailable

### Color Extraction Pipeline
1. User photo → Vision framework → Face/Body detection
2. CoreML model → Skin tone classification (warm/cool/neutral)
3. Undertone analysis → Personal color palette generation
4. Palette stored locally, passed as context to AI assistant

### Testing
```bash
# Run unit tests
xcodebuild test -project PersonalShooper.xcodeproj -scheme PersonalShooperTests

# Run UI tests
xcodebuild test -project PersonalShooper.xcodeproj -scheme PersonalShooperUITests
```
