import AVFoundation
import Foundation

/// Plays the wardrobe door-opening sound (soft wooden whoosh + warm chime).
/// The user can mute it from the closet lobby; the choice persists.
@MainActor
enum ArmoireSoundPlayer {
    static let mutedKey = "armoire_sound_muted"

    private static let engine = ArmoireAudioEngine()

    static var isMuted: Bool {
        UserDefaults.standard.bool(forKey: mutedKey)
    }

    static func setMuted(_ muted: Bool, previewsWhenEnabled: Bool = false) {
        UserDefaults.standard.set(muted, forKey: mutedKey)

        if muted {
            Task {
                await engine.stop()
            }
        } else if previewsWhenEnabled {
            playOpen()
        }
    }

    static func playOpen() {
        guard !isMuted else { return }
        guard let url = Bundle.main.url(forResource: "armoire_open", withExtension: "wav") else { return }

        Task {
            await engine.play(url: url)
        }
    }
}

private actor ArmoireAudioEngine {
    private var player: AVAudioPlayer?

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func play(url: URL) {
        do {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.ambient, options: .mixWithOthers)
            try? session.setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 0.55
            player?.prepareToPlay()
            player?.play()
        } catch {
            #if DEBUG
            print("ArmoireSoundPlayer failed: \(error.localizedDescription)")
            #endif
        }
    }
}
