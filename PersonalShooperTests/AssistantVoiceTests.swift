import XCTest
import AVFoundation
@testable import PersonalShooper

@MainActor
final class AssistantVoiceTests: XCTestCase {

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: VoicePreferences.storageKey)
        super.tearDown()
    }

    // MARK: - Voice selection

    func testPicksAVoiceForEachLanguage() {
        for language in Language.allCases {
            let voice = ChatSpeechController.naturalVoice(for: language, assistantName: "Rebe")
            XCTAssertNotNil(voice, "No voice resolved for \(language.rawValue)")

            let expectedPrefix = language == .spanish ? "es" : "en"
            XCTAssertTrue(
                voice?.language.hasPrefix(expectedPrefix) == true,
                "Resolved \(voice?.language ?? "nil") for \(language.rawValue)"
            )
        }
    }

    /// The stylist's persona drives the voice gender: "Rebe" is female, "Peter" male. Skipped when
    /// the host has no voice of that gender installed, which is out of the app's control.
    func testMatchesPersonaGenderWhenAvailable() throws {
        let installed = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }

        try XCTSkipUnless(
            installed.contains { $0.gender == .female } && installed.contains { $0.gender == .male },
            "Host has no male+female English voices installed"
        )

        let rebe = ChatSpeechController.naturalVoice(for: .english, assistantName: AssistantPersona.defaultName)
        let peter = ChatSpeechController.naturalVoice(for: .english, assistantName: AssistantPersona.alternateName)

        XCTAssertEqual(rebe?.gender, .female)
        XCTAssertEqual(peter?.gender, .male)
    }

    func testNoveltyVoicesAreNeverChosen() {
        for language in Language.allCases {
            let voice = ChatSpeechController.naturalVoice(for: language, assistantName: "Rebe")
            XCTAssertFalse(
                voice?.identifier.lowercased().contains("eloquence") == true,
                "Picked a novelty voice for \(language.rawValue)"
            )
        }
    }

    // MARK: - Stored preference

    func testAutomaticWhenNothingStored() {
        UserDefaults.standard.removeObject(forKey: VoicePreferences.storageKey)
        XCTAssertNil(VoicePreferences.selectedVoice)
    }

    /// Voices can be deleted in Settings after being chosen. A stale identifier must fall back to
    /// automatic selection — assigning a nil voice would otherwise leave playback silent.
    func testStaleIdentifierFallsBackToAutomatic() {
        UserDefaults.standard.set("com.apple.voice.that.does.not.exist", forKey: VoicePreferences.storageKey)
        XCTAssertNil(VoicePreferences.selectedVoice)
    }

    func testStoredIdentifierResolvesToThatVoice() throws {
        let installed = try XCTUnwrap(AVSpeechSynthesisVoice.speechVoices().first)
        UserDefaults.standard.set(installed.identifier, forKey: VoicePreferences.storageKey)

        XCTAssertEqual(VoicePreferences.selectedVoice?.identifier, installed.identifier)
    }
}
