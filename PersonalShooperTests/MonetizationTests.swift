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
