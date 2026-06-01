import AVFoundation
import Foundation

@MainActor
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private let detector = LanguageDetector()
    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let config = settingsStore.settings.speech
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate = config.rate
        utterance.pitchMultiplier = config.pitch
        utterance.volume = config.volume

        if !config.voiceIdentifier.isEmpty {
            utterance.voice = AVSpeechSynthesisVoice(identifier: config.voiceIdentifier)
        } else {
            utterance.voice = AVSpeechSynthesisVoice(
                language: detector.speechLanguage(
                    for: trimmed,
                    englishPronunciation: config.englishPronunciation
                )
            )
        }

        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
