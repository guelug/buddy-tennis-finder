import SwiftUI
import AVFoundation

/// Lets the user pick and preview the voice the stylist speaks with.
///
/// **Why this screen exists:** iOS ships only the low-quality "Compact" voice for each language and
/// provides *no API* for an app to download a better one — `AVSpeechSynthesisVoice` is read-only and
/// the Settings deep links that would land on the voice list (`App-Prefs:…`) are private API. So the
/// best an app can legitimately do is (a) surface every voice that *is* installed, with an audible
/// preview so the difference is obvious, and (b) explain the one-time download in plain language.
struct VoiceSettingsView: View {
    @Environment(AppState.self) private var appState

    @AppStorage(VoicePreferences.storageKey) private var selectedVoiceIdentifier = ""

    @State private var previewer = VoicePreviewer()

    private var lang: Language { appState.preferredLanguage }
    private var isSpanish: Bool { lang == .spanish }

    private var assistantName: String {
        AssistantPersona.name(forUserNamed: appState.currentUser?.displayName)
    }

    /// Installed voices for the current language, best quality first.
    private var voices: [AVSpeechSynthesisVoice] {
        let prefix = isSpanish ? "es" : "en"
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(prefix) }
            .sorted { lhs, rhs in
                if qualityRank(lhs.quality) != qualityRank(rhs.quality) {
                    return qualityRank(lhs.quality) > qualityRank(rhs.quality)
                }
                return lhs.name < rhs.name
            }
    }

    private var hasHighQualityVoice: Bool {
        voices.contains { $0.quality != .default }
    }

    var body: some View {
        List {
            Section {
                Button {
                    selectedVoiceIdentifier = ""
                    preview(ChatSpeechController.naturalVoice(for: lang, assistantName: assistantName))
                } label: {
                    row(
                        title: isSpanish ? "Automática" : "Automatic",
                        subtitle: isSpanish
                            ? "La mejor voz instalada que encaje con \(assistantName)"
                            : "The best installed voice that matches \(assistantName)",
                        isSelected: selectedVoiceIdentifier.isEmpty,
                        badge: nil
                    )
                }
            } footer: {
                Text(isSpanish
                     ? "\(assistantName) usa una voz femenina; si el asistente se llama Peter, usa una masculina."
                     : "\(assistantName) uses a female voice; when the assistant is called Peter it uses a male one.")
            }

            Section {
                ForEach(voices, id: \.identifier) { voice in
                    Button {
                        selectedVoiceIdentifier = voice.identifier
                        preview(voice)
                    } label: {
                        row(
                            title: voice.name,
                            subtitle: voice.language,
                            isSelected: selectedVoiceIdentifier == voice.identifier,
                            badge: qualityBadge(for: voice.quality)
                        )
                    }
                }
            } header: {
                Text(isSpanish ? "Voces instaladas" : "Installed voices")
            } footer: {
                Text(isSpanish
                     ? "Toca una voz para escucharla."
                     : "Tap a voice to hear it.")
            }

            if !hasHighQualityVoice {
                Section {
                    downloadGuide
                } header: {
                    Text(isSpanish ? "Consigue una voz natural" : "Get a natural voice")
                }
            }
        }
        .navigationTitle(isSpanish ? "Voz del asistente" : "Assistant voice")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { previewer.stop() }
    }

    private var downloadGuide: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(isSpanish
                 ? "Tu iPhone solo tiene la voz básica para \(lang.displayName), por eso suena robótica. Descargar una voz Premium es gratis y se hace una sola vez:"
                 : "Your iPhone only has the basic voice for \(lang.displayName), which is why it sounds robotic. Downloading a Premium voice is free and only needs doing once:")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(Array(downloadSteps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.footnote.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.Colors.primary)
                    Text(step)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label(
                    isSpanish ? "Abrir Ajustes" : "Open Settings",
                    systemImage: "arrow.up.forward.app"
                )
                .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .padding(.top, 2)

            Text(isSpanish
                 ? "Al volver, la voz nueva aparecerá en esta lista."
                 : "When you come back, the new voice will show up in this list.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var downloadSteps: [String] {
        if isSpanish {
            return [
                "Ajustes › Accesibilidad",
                "Contenido hablado › Voces",
                "Elige \(lang.displayName)",
                "Toca una voz marcada como Premium o Mejorada y descárgala"
            ]
        }
        return [
            "Settings › Accessibility",
            "Spoken Content › Voices",
            "Pick \(lang.displayName)",
            "Tap a voice marked Premium or Enhanced and download it"
        ]
    }

    private func row(title: String, subtitle: String, isSelected: Bool, badge: String?) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Theme.Colors.primary : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .foregroundStyle(.primary)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.primary.opacity(0.15))
                            .foregroundStyle(Theme.Colors.primary)
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "play.circle")
                .foregroundStyle(.secondary)
        }
    }

    private func preview(_ voice: AVSpeechSynthesisVoice?) {
        previewer.play(text: previewSentence, voice: voice)
    }

    /// A line with real styling vocabulary, so the preview is representative of actual replies.
    private var previewSentence: String {
        isSpanish
            ? "Hola, soy \(assistantName). Con tu paleta, el azul marino y el camel te favorecen mucho."
            : "Hi, I'm \(assistantName). With your palette, navy and camel look great on you."
    }

    private func qualityRank(_ quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium: return 3
        case .enhanced: return 2
        default: return 1
        }
    }

    private func qualityBadge(for quality: AVSpeechSynthesisVoiceQuality) -> String? {
        switch quality {
        case .premium: return "Premium"
        case .enhanced: return isSpanish ? "Mejorada" : "Enhanced"
        default: return nil
        }
    }
}

/// Where the user's voice choice lives. An empty value means "let the app pick".
enum VoicePreferences {
    static let storageKey = "assistant_voice_identifier"

    /// The chosen voice, or nil when set to automatic — or when the stored voice was uninstalled
    /// (voices can be removed in Settings, and a stale identifier would silently mute playback).
    static var selectedVoice: AVSpeechSynthesisVoice? {
        let identifier = UserDefaults.standard.string(forKey: storageKey) ?? ""
        guard !identifier.isEmpty else { return nil }
        return AVSpeechSynthesisVoice(identifier: identifier)
    }
}

@Observable
@MainActor
private final class VoicePreviewer {
    @ObservationIgnored
    private let synthesizer = AVSpeechSynthesizer()

    func play(text: String, voice: AVSpeechSynthesisVoice?) {
        stop()

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.96
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
