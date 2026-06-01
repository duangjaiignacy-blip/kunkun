import Foundation

struct PhoneticTranscriber {
    func transcribe(_ text: String, pronunciation: EnglishPronunciation) -> String? {
        let words = Self.englishWords(in: text)
        guard !words.isEmpty, words.count <= 16 else { return nil }

        let phonemes = words.map { word in
            Self.dictionary[pronunciation]?[word]
                ?? Self.dictionary[Self.fallbackPronunciation(for: pronunciation)]?[word]
                ?? Self.approximate(word, pronunciation: pronunciation)
        }
        return "/\(phonemes.joined(separator: " "))/"
    }

    private static func englishWords(in text: String) -> [String] {
        let pattern = #"[A-Za-z]+(?:'[A-Za-z]+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex
            .matches(in: text, range: range)
            .compactMap { Range($0.range, in: text).map { String(text[$0]).lowercased() } }
            .filter { !$0.isEmpty }
    }

    private static func fallbackPronunciation(for pronunciation: EnglishPronunciation) -> EnglishPronunciation {
        switch pronunciation {
        case .american: .british
        case .british: .american
        }
    }

    private static func approximate(_ word: String, pronunciation: EnglishPronunciation) -> String {
        var value = word.lowercased()
        let replacements: [(String, String)] = [
            ("tion", "ʃən"),
            ("sion", "ʒən"),
            ("ough", "oʊ"),
            ("igh", "aɪ"),
            ("air", "eə"),
            ("ear", "ɪə"),
            ("th", "θ"),
            ("sh", "ʃ"),
            ("ch", "tʃ"),
            ("ph", "f"),
            ("ck", "k"),
            ("ee", "iː"),
            ("ea", "iː"),
            ("oo", "uː"),
            ("ou", "aʊ"),
            ("ow", "aʊ"),
            ("ai", "eɪ"),
            ("ay", "eɪ"),
            ("oi", "ɔɪ"),
            ("oy", "ɔɪ"),
            ("er", pronunciation == .american ? "ɚ" : "ə"),
            ("ar", pronunciation == .american ? "ɑr" : "ɑː")
        ]
        for (source, target) in replacements {
            value = value.replacingOccurrences(of: source, with: target)
        }
        if value.hasSuffix("e"), value.count > 2 {
            value.removeLast()
        }
        return value
    }

    private static let dictionary: [EnglishPronunciation: [String: String]] = [
        .american: [
            "a": "ə",
            "about": "əˈbaʊt",
            "again": "əˈɡen",
            "ai": "ˌeɪˈaɪ",
            "american": "əˈmerɪkən",
            "and": "ænd",
            "api": "ˌeɪ piː ˈaɪ",
            "app": "æp",
            "apple": "ˈæpəl",
            "are": "ɑr",
            "assistant": "əˈsɪstənt",
            "audio": "ˈɔdiˌoʊ",
            "be": "biː",
            "british": "ˈbrɪtɪʃ",
            "browser": "ˈbraʊzɚ",
            "chrome": "kroʊm",
            "code": "koʊd",
            "computer": "kəmˈpjuːtɚ",
            "content": "ˈkɑntent",
            "deepseek": "ˈdiːp siːk",
            "english": "ˈɪŋɡlɪʃ",
            "explain": "ɪkˈspleɪn",
            "flash": "flæʃ",
            "for": "fɔr",
            "function": "ˈfʌŋkʃən",
            "hello": "həˈloʊ",
            "history": "ˈhɪstəri",
            "is": "ɪz",
            "key": "kiː",
            "language": "ˈlæŋɡwɪdʒ",
            "macos": "ˈmæk oʊ ˈes",
            "model": "ˈmɑdəl",
            "news": "nuːz",
            "note": "noʊt",
            "openai": "ˌoʊpən eɪ ˈaɪ",
            "podcast": "ˈpɑdˌkæst",
            "podcasts": "ˈpɑdˌkæsts",
            "pro": "proʊ",
            "record": "ˈrekɚd",
            "records": "ˈrekɚdz",
            "rewrite": "ˌriːˈraɪt",
            "safari": "səˈfɑri",
            "setting": "ˈsetɪŋ",
            "settings": "ˈsetɪŋz",
            "speech": "spiːtʃ",
            "summarize": "ˈsʌməˌraɪz",
            "summary": "ˈsʌməri",
            "text": "tekst",
            "the": "ðə",
            "to": "tuː",
            "translation": "trænzˈleɪʃən",
            "translator": "trænzˈleɪtɚ",
            "ui": "ˌjuː ˈaɪ",
            "voice": "vɔɪs",
            "vscode": "ˌviː es ˈkoʊd",
            "window": "ˈwɪndoʊ",
            "word": "wɝd",
            "you": "juː"
        ],
        .british: [
            "a": "ə",
            "about": "əˈbaʊt",
            "again": "əˈɡen",
            "ai": "ˌeɪˈaɪ",
            "american": "əˈmerɪkən",
            "and": "ænd",
            "api": "ˌeɪ piː ˈaɪ",
            "app": "æp",
            "apple": "ˈæpəl",
            "are": "ɑː",
            "assistant": "əˈsɪstənt",
            "audio": "ˈɔːdiəʊ",
            "be": "biː",
            "british": "ˈbrɪtɪʃ",
            "browser": "ˈbraʊzə",
            "chrome": "krəʊm",
            "code": "kəʊd",
            "computer": "kəmˈpjuːtə",
            "content": "ˈkɒntent",
            "deepseek": "ˈdiːp siːk",
            "english": "ˈɪŋɡlɪʃ",
            "explain": "ɪkˈspleɪn",
            "flash": "flæʃ",
            "for": "fɔː",
            "function": "ˈfʌŋkʃən",
            "hello": "həˈləʊ",
            "history": "ˈhɪstəri",
            "is": "ɪz",
            "key": "kiː",
            "language": "ˈlæŋɡwɪdʒ",
            "macos": "ˈmæk əʊ ˈes",
            "model": "ˈmɒdəl",
            "news": "njuːz",
            "note": "nəʊt",
            "openai": "ˌəʊpən eɪ ˈaɪ",
            "podcast": "ˈpɒdˌkɑːst",
            "podcasts": "ˈpɒdˌkɑːsts",
            "pro": "prəʊ",
            "record": "ˈrekɔːd",
            "records": "ˈrekɔːdz",
            "rewrite": "ˌriːˈraɪt",
            "safari": "səˈfɑːri",
            "setting": "ˈsetɪŋ",
            "settings": "ˈsetɪŋz",
            "speech": "spiːtʃ",
            "summarize": "ˈsʌməraɪz",
            "summary": "ˈsʌməri",
            "text": "tekst",
            "the": "ðə",
            "to": "tuː",
            "translation": "trænzˈleɪʃən",
            "translator": "trænzˈleɪtə",
            "ui": "ˌjuː ˈaɪ",
            "voice": "vɔɪs",
            "vscode": "ˌviː es ˈkəʊd",
            "window": "ˈwɪndəʊ",
            "word": "wɜːd",
            "you": "juː"
        ]
    ]
}
