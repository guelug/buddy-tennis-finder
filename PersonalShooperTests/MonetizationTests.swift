import XCTest
@testable import PersonalShooper

final class MonetizationTests: XCTestCase {

    // MARK: - Tier feature gates

    func testFreeTierHasNoEntitlements() {
        XCTAssertFalse(SubscriptionTier.free.hasBYOK)
        XCTAssertFalse(SubscriptionTier.free.hasAppleIntelligenceFeatures)
    }

    func testByokUnlockGrantsBYOKButNotAI() {
        XCTAssertTrue(SubscriptionTier.byok.hasBYOK)
        XCTAssertFalse(SubscriptionTier.byok.hasAppleIntelligenceFeatures)
    }

    func testAppleIntelligencePlusGrantsAIButNotBYOK() {
        XCTAssertTrue(SubscriptionTier.appleIntelligencePlus.hasAppleIntelligenceFeatures)
        XCTAssertFalse(SubscriptionTier.appleIntelligencePlus.hasBYOK)
    }

    func testSubscriptionsGrantBoth() {
        for tier in [SubscriptionTier.premium, .pro] {
            XCTAssertTrue(tier.hasBYOK, "\(tier) should grant BYOK")
            XCTAssertTrue(tier.hasAppleIntelligenceFeatures, "\(tier) should grant AI features")
        }
    }

    func testLegacyLifetimeMapsToAppleIntelligence() {
        XCTAssertTrue(SubscriptionTier.lifetime.hasAppleIntelligenceFeatures)
        XCTAssertTrue(SubscriptionTier.lifetime.hasBYOK)
    }

    // MARK: - Product → tier mapping

    func testNewProductIDsMapToTiers() {
        XCTAssertEqual(StoreProduct(rawValue: "com.personalshooper.appleintelligenceplus")?.tier, .appleIntelligencePlus)
        XCTAssertEqual(StoreProduct(rawValue: "com.personalshooper.byok")?.tier, .byok)
        XCTAssertEqual(StoreProduct.premiumMonthly.tier, .premium)
        XCTAssertEqual(StoreProduct.proMonthly.tier, .pro)
    }

    func testOneTimeUnlocksClassified() {
        XCTAssertTrue(StoreProduct.appleIntelligencePlus.isOneTimeUnlock)
        XCTAssertTrue(StoreProduct.byokUnlock.isOneTimeUnlock)
        XCTAssertTrue(StoreProduct.lifetime.isOneTimeUnlock)
        XCTAssertFalse(StoreProduct.premiumMonthly.isOneTimeUnlock)
        XCTAssertFalse(StoreProduct.proMonthly.isOneTimeUnlock)
    }

    func testNewUnlocksAreVisibleInUI() {
        XCTAssertTrue(StoreProduct.appleIntelligencePlus.visibleInSubscriptionUI)
        XCTAssertTrue(StoreProduct.byokUnlock.visibleInSubscriptionUI)
        XCTAssertFalse(StoreProduct.free.visibleInSubscriptionUI)
    }

    // MARK: - BYOK providers

    func testGrokProviderIsAvailable() {
        XCTAssertTrue(BYOKChatService.BYOKProvider.allCases.contains(.grok))
        XCTAssertEqual(BYOKChatService.BYOKProvider.grok.endpoint.host, "api.x.ai")
        XCTAssertFalse(BYOKChatService.BYOKProvider.grok.chatModel.isEmpty)
    }
}
