import Foundation
import NaturalLanguage

struct LanguageDetector {
    func detect(_ text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue ?? "und"
    }

    func speechLanguage(for text: String, englishPronunciation: EnglishPronunciation = .american) -> String {
        switch detect(text) {
        case "zh-Hans", "zh-Hant", "zh":
            "zh-CN"
        case "ja":
            "ja-JP"
        case "en":
            englishPronunciation.localeIdentifier
        default:
            "en-US"
        }
    }
}
