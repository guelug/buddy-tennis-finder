# iOS 27 pass — MatchPoint Tennis

Xcode on Pedros-MBP: **Xcode 27.0** (`Xcode-beta.app`, build `27A5194q`) + **iOS 27.0 SDK**. No stable `Xcode.app` is installed, so this branch is a smoke-compile pass. Do **not** archive or upload from the beta toolchain.

Min deployment stays **iOS 16.4**.

## StoreKit / IAP

Client SKUs (unchanged):

| Product ID | Use | Fallback EUR |
|---|---|---|
| `coach_ad_7_days` | Coach promo 7 days | 4,99 € |
| `coach_ad_30_days` | Coach promo 30 days | 12,99 € |
| `private_league_create` | Private league create | 6,99 € |

`expo-iap` 4.7.0 has no iOS 27 offer-code `VerificationResult` API. This pass adds `MatchPointOfferCodeModule` (`AppStore.presentOfferCodeRedeemSheet(from:options:)` on iOS 27, scene sheet on earlier). The native module does **not** finish the transaction; the existing Cloudflare IAP verifier + `finishTransaction` path still delivers the product.

Checkout screens gained an iOS-only “Canjear código promocional” action that stores the same purchase intent as a paid checkout, then presents the system sheet.

## App Store Connect — live query 2026-09-13

App `com.matchpoint.clubs` (ASC `6793740051`, name **MP Tennis League App**).

All three consumables exist and are **`MISSING_METADATA`**:

| Product | State | es-ES localization | Review screenshot |
|---|---|---|---|
| `coach_ad_7_days` | MISSING_METADATA | PREPARE_FOR_SUBMISSION | **missing** |
| `coach_ad_30_days` | MISSING_METADATA | PREPARE_FOR_SUBMISSION | **missing** |
| `private_league_create` | MISSING_METADATA | PREPARE_FOR_SUBMISSION | **missing** |

No `en-US` IAP localization. No subscription group (correct — these are consumables). Offer codes cannot go live until metadata + review screenshot are uploaded and the products leave `MISSING_METADATA`. Attach the IAPs to the next iOS version in ASC.

Xcode Cloud `ciProducts` relationship is absent (404) — still no Cloud workflow for this app.

## Liquid Glass / toolbar

Building with the iOS 27 SDK opts the UIKit/RN chrome into Liquid Glass. `UIDesignRequiresCompatibility` is not set and would be ignored. No tab/toolbar redesign in this pass. Redeem uses the existing `PrimaryButton` `glass` variant. RN screens do not use UIKit menus, so the iPadOS 27 hidden menu-image change is low risk.

## AdMob / UMP

`react-native-google-mobile-ads` 16.4.0 + UMP in `src/lib/ads.native.ts`: gather consent → ATT (iOS, age 16+) → `mobileAds().initialize()`. Code is not broken by the iOS 27 SDK. Retest on iOS 27:

1. Consent form presentation (EEA) and `canRequestAds`.
2. ATT prompt after UMP, skipped under 16 (`tagForUnderAgeOfConsent`).
3. Native ads after consent; privacy-options row still opens the UMP form.
4. No crash if UMP is temporarily unavailable (existing try/catch).

Do not ship an App Store archive from this Xcode-beta until stable Xcode 27 is installed.

## Smoke build

Debug simulator build **succeeded** on Pedros-MBP with Xcode 27.0 / iPhone 17 Pro (iOS 27.0 SDK), `CODE_SIGNING_ALLOWED=NO`. `MatchPointLocalAIModule.swift` compiled into the app. No archive. Do not run `pod update` for this change.

## Cloud note (2026-09-13)
Xcode Cloud currently archives MatchPoint with **Xcode 26.6** (App Store–eligible). The iOS 27 `presentOfferCodeRedeemSheet(from:options:)` VerificationResult path does not compile on that SDK and ExpoModulesJSI scripts fail on Xcode 27 RC with the locked Expo 57.0.11 set, so Cloud ships the StoreKit 16 `in:` redeem sheet (coach/league checkout buttons remain). Revisit VerificationResult when Expo+Cloud Xcode 27 is App Store–eligible.
