import XCTest
@testable import PersonalShooper

final class StyleLogicTests: XCTestCase {

    // MARK: - Body shape from measurements

    func testHourglass() {
        // Balanced chest/hips, defined waist (waist/hips <= 0.75).
        XCTAssertEqual(ImageConsulting.bodyShape(chestCm: 92, waistCm: 68, hipsCm: 94), .hourglass)
    }

    func testTrianglePear() {
        XCTAssertEqual(ImageConsulting.bodyShape(chestCm: 88, waistCm: 74, hipsCm: 104), .triangle)
    }

    func testInvertedTriangle() {
        XCTAssertEqual(ImageConsulting.bodyShape(chestCm: 108, waistCm: 80, hipsCm: 92), .invertedTriangle)
    }

    func testOvalApple() {
        // Waist is the widest measurement.
        XCTAssertEqual(ImageConsulting.bodyShape(chestCm: 96, waistCm: 102, hipsCm: 98), .oval)
    }

    func testRectangle() {
        // Balanced chest/hips, little waist definition.
        XCTAssertEqual(ImageConsulting.bodyShape(chestCm: 92, waistCm: 86, hipsCm: 94), .rectangle)
    }

    func testNilWhenMeasurementsMissing() {
        XCTAssertNil(ImageConsulting.bodyShape(chestCm: nil, waistCm: 70, hipsCm: 95))
    }

    // MARK: - Contrast level thresholds

    func testContrastLevels() {
        XCTAssertEqual(ContrastLevel.from(contrast: 0.7), .high)
        XCTAssertEqual(ContrastLevel.from(contrast: 0.55), .high)
        XCTAssertEqual(ContrastLevel.from(contrast: 0.4), .medium)
        XCTAssertEqual(ContrastLevel.from(contrast: 0.3), .medium)
        XCTAssertEqual(ContrastLevel.from(contrast: 0.1), .low)
    }

    // MARK: - Marketing prompt framing

    func testShoesPromptForcesFrontFacingPair() {
        let prompt = MarketingImagePrompt.build(categoryHint: "shoes")
        XCTAssertTrue(prompt.contains("PAIR"))
        XCTAssertTrue(prompt.lowercased().contains("toward the viewer"))
    }

    func testEveryPromptUsesWhiteBackgroundAndFront() {
        for hint in ["shoes", "tops", "bottoms", "dresses", "outerwear", "accessories"] {
            let prompt = MarketingImagePrompt.build(categoryHint: hint)
            XCTAssertTrue(prompt.contains("white"), "missing white bg for \(hint)")
            XCTAssertTrue(prompt.contains("FRONT"), "missing front framing for \(hint)")
        }
    }

    // MARK: - Hex color parsing

    func testHexParsing() {
        let red = CodableColor(hex: "#FF0000")
        XCTAssertNotNil(red)
        XCTAssertEqual(red!.red, 1, accuracy: 0.01)
        XCTAssertEqual(red!.green, 0, accuracy: 0.01)
        XCTAssertEqual(red!.blue, 0, accuracy: 0.01)

        XCTAssertNotNil(CodableColor(hex: "00FF00")) // no hash
        XCTAssertNil(CodableColor(hex: "#GG0000"))   // invalid
        XCTAssertNil(CodableColor(hex: "#FFF"))      // wrong length
    }
}
