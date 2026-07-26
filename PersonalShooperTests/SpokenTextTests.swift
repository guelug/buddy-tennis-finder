import XCTest
@testable import PersonalShooper

/// The stylist replies in Markdown. Fed verbatim to `AVSpeechSynthesizer`, the voice pronounces the
/// syntax ("asterisk asterisk bold asterisk asterisk"), which is most of why playback sounded wrong.
@MainActor
final class SpokenTextTests: XCTestCase {

    func testStripsEmphasisMarkers() {
        let spoken = ChatSpeechController.spokenText(from: "Ponte la **blazer negra** y unos _vaqueros_.")
        XCTAssertEqual(spoken, "Ponte la blazer negra y unos vaqueros.")
    }

    func testStripsHeadingsAndBullets() {
        let markdown = """
        ## Tu look de hoy
        - Blazer negra
        - Vaqueros rectos
        """
        let spoken = ChatSpeechController.spokenText(from: markdown)

        XCTAssertFalse(spoken.contains("#"))
        XCTAssertFalse(spoken.contains("-"))
        XCTAssertTrue(spoken.contains("Tu look de hoy"))
        XCTAssertTrue(spoken.contains("Blazer negra"))
        XCTAssertTrue(spoken.contains("Vaqueros rectos"))
    }

    func testDropsTableRowsButKeepsProse() {
        let markdown = """
        Te propongo esto:
        | Prenda | Color |
        | --- | --- |
        | Blazer | Negro |
        Dime si te encaja.
        """
        let spoken = ChatSpeechController.spokenText(from: markdown)

        XCTAssertFalse(spoken.contains("|"))
        XCTAssertTrue(spoken.contains("Te propongo esto"))
        XCTAssertTrue(spoken.contains("Dime si te encaja"))
    }

    func testKeepsLinkLabelDropsURL() {
        let spoken = ChatSpeechController.spokenText(from: "Mira [esta guía](https://example.com/guia).")
        XCTAssertEqual(spoken, "Mira esta guía.")
    }

    func testCollapsesBlankLinesIntoSentencePauses() {
        let spoken = ChatSpeechController.spokenText(from: "Primera idea.\n\nSegunda idea.")
        XCTAssertEqual(spoken, "Primera idea. Segunda idea.")
    }

    func testPlainTextIsUnchanged() {
        let plain = "Con tu paleta de invierno, el azul marino te favorece mucho."
        XCTAssertEqual(ChatSpeechController.spokenText(from: plain), plain)
    }
}
