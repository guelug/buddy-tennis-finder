import XCTest
@testable import PersonalShooper

final class MonetizationTests: XCTestCase {
    func testFreePolicyEnablesEveryFeature() {
        XCTAssertTrue(FreeAccessPolicy.allowsAppleIntelligence)
        XCTAssertTrue(FreeAccessPolicy.allowsBYOK)
        XCTAssertTrue(FreeAccessPolicy.allowsManagedCloud)
        XCTAssertEqual(FreeAccessPolicy.closetItemLimit, 100)
    }

    func testLegacyTiersCannotRestrictAccess() {
        for tier in SubscriptionTier.allCases {
            XCTAssertTrue(tier.hasBYOK)
            XCTAssertTrue(tier.hasAppleIntelligenceFeatures)
            XCTAssertTrue(tier.isUnlimited)
            XCTAssertFalse(tier.hasTrial)
            XCTAssertEqual(tier.displayName, "Free")
        }
    }

    func testManagedAndLocalTryOnAreFree() {
        XCTAssertTrue(TryOnProvider.google.isFree)
        XCTAssertTrue(TryOnProvider.playground.isFree)
        XCTAssertFalse(TryOnProvider.google.requiresUserAPIKey)
        XCTAssertFalse(TryOnProvider.playground.requiresUserAPIKey)
        XCTAssertTrue(TryOnProvider.chatgpt.requiresUserAPIKey)
        XCTAssertTrue(TryOnProvider.fal.requiresUserAPIKey)
        XCTAssertFalse(TryOnProvider.fal.isFree)
    }

    @MainActor
    func testCurrentImageProvidersAreExposed() {
        XCTAssertTrue(TryOnProvider.google.displayName.contains("Nano Banana 2"))
        XCTAssertTrue(TryOnProvider.chatgpt.displayName.contains("GPT Image 2"))
        XCTAssertTrue(TryOnProvider.allCases.contains(.fal))
        XCTAssertEqual(FalTryOnService.modelID, "fal-ai/image-apps-v2/virtual-try-on")
        XCTAssertTrue(StoreKitManager.byokKeychainKeys.contains("fal_api_key"))
    }

    func testFalQueueURLsCannotRedirectCredentialsOffHost() {
        XCTAssertTrue(FalTryOnService.isTrustedQueueURL(
            URL(string: "https://queue.fal.run/fal-ai/model/requests/id/status")!
        ))
        XCTAssertFalse(FalTryOnService.isTrustedQueueURL(
            URL(string: "https://example.com/fal-ai/model/requests/id/status")!
        ))
        XCTAssertFalse(FalTryOnService.isTrustedQueueURL(
            URL(string: "http://queue.fal.run/fal-ai/model/requests/id/status")!
        ))
    }

    @MainActor
    func testArmoireMuteStateStopsAndPersists() {
        let previous = ArmoireSoundPlayer.isMuted
        defer { ArmoireSoundPlayer.setMuted(previous) }

        ArmoireSoundPlayer.setMuted(true)
        XCTAssertTrue(ArmoireSoundPlayer.isMuted)

        ArmoireSoundPlayer.setMuted(false)
        XCTAssertFalse(ArmoireSoundPlayer.isMuted)
    }

    @MainActor
    func testGrokProviderIsAvailable() {
        XCTAssertTrue(BYOKChatService.BYOKProvider.allCases.contains(.grok))
        let grokParticipatesInBYOKDetection = StoreKitManager.byokKeychainKeys.contains("grok_api_key")
        XCTAssertTrue(grokParticipatesInBYOKDetection)
        XCTAssertEqual(BYOKChatService.BYOKProvider.grok.endpoint.host, "api.x.ai")
        XCTAssertFalse(BYOKChatService.BYOKProvider.grok.chatModel.isEmpty)
    }
}
