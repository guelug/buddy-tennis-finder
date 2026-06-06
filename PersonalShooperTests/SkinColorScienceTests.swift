import XCTest
@testable import PersonalShooper

final class SkinColorScienceTests: XCTestCase {

    // MARK: - Depth (ITA°) boundaries (Chardon 1991 bands)

    func testDepthCategoryBands() {
        XCTAssertEqual(SkinColorScience.depthCategory(ita: 60), .fair)    // very light
        XCTAssertEqual(SkinColorScience.depthCategory(ita: 55), .fair)    // boundary
        XCTAssertEqual(SkinColorScience.depthCategory(ita: 48), .light)
        XCTAssertEqual(SkinColorScience.depthCategory(ita: 41), .light)   // boundary
        XCTAssertEqual(SkinColorScience.depthCategory(ita: 35), .medium)
        XCTAssertEqual(SkinColorScience.depthCategory(ita: 28), .medium)  // boundary
        XCTAssertEqual(SkinColorScience.depthCategory(ita: 18), .tan)
        XCTAssertEqual(SkinColorScience.depthCategory(ita: 10), .tan)     // boundary
        XCTAssertEqual(SkinColorScience.depthCategory(ita: 5), .dark)
        XCTAssertEqual(SkinColorScience.depthCategory(ita: -40), .dark)
    }

    // MARK: - CIELAB conversion sanity

    func testLabOfPureWhite() {
        let lab = SkinColorScience.lab(from: .white)
        XCTAssertNotNil(lab)
        // Pure white is L*≈100, a*≈0, b*≈0.
        XCTAssertEqual(lab!.L, 100, accuracy: 1.0)
        XCTAssertEqual(lab!.a, 0, accuracy: 1.0)
        XCTAssertEqual(lab!.b, 0, accuracy: 1.0)
    }

    func testLabOfPureBlack() {
        let lab = SkinColorScience.lab(from: .black)
        XCTAssertNotNil(lab)
        XCTAssertEqual(lab!.L, 0, accuracy: 1.0)
    }

    // MARK: - Undertone from CIELAB balance

    func testWarmUndertoneWhenYellowDominates() {
        // b* well above a* → warm.
        let lab = SkinColorScience.LabColor(L: 60, a: 12, b: 24)
        XCTAssertEqual(SkinColorScience.undertone(lab: lab).0, .warm)
    }

    func testCoolUndertoneWhenRedDominates() {
        // b* close to / below a* → cool.
        let lab = SkinColorScience.LabColor(L: 60, a: 18, b: 19)
        XCTAssertEqual(SkinColorScience.undertone(lab: lab).0, .cool)
    }

    func testNeutralUndertoneInBetween() {
        let lab = SkinColorScience.LabColor(L: 60, a: 14, b: 20) // warmth = 6 → neutral band
        XCTAssertEqual(SkinColorScience.undertone(lab: lab).0, .neutral)
    }

    // MARK: - Clarity

    func testClarityBrightVsMuted() {
        XCTAssertEqual(SkinColorScience.clarity(chroma: 26, contrast: 0.8), .bright)
        XCTAssertEqual(SkinColorScience.clarity(chroma: 12, contrast: 0.1), .muted)
    }
}
