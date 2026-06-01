import Foundation
import CoreGraphics

enum TranslationEngineKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case apple
    case openAI
    case mock

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple: "Apple 翻译"
        case .openAI: "OpenAI"
        case .mock: "模拟引擎"
        }
    }
}

struct TranslationRequest: Equatable, Sendable {
    var text: String
    var sourceLanguage: String?
    var targetLanguage: String
}

struct TranslationResult: Identifiable, Equatable, Sendable {
    var id = UUID()
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let engine: TranslationEngineKind
    let createdAt: Date
}

struct OCRBlock: Equatable, Sendable {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
}

enum EnglishPronunciation: String, Codable, CaseIterable, Identifiable, Sendable {
    case american
    case british

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .american: "美式英语"
        case .british: "英式英语"
        }
    }

    var shortName: String {
        switch self {
        case .american: "美式"
        case .british: "英式"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .american: "en-US"
        case .british: "en-GB"
        }
    }
}

struct SpeechConfig: Codable, Equatable, Sendable {
    var rate: Float
    var pitch: Float
    var volume: Float
    var voiceIdentifier: String
    var englishPronunciation: EnglishPronunciation

    static let `default` = SpeechConfig(
        rate: 0.48,
        pitch: 1.0,
        volume: 1.0,
        voiceIdentifier: "",
        englishPronunciation: .american
    )

    init(
        rate: Float,
        pitch: Float,
        volume: Float,
        voiceIdentifier: String,
        englishPronunciation: EnglishPronunciation
    ) {
        self.rate = rate
        self.pitch = pitch
        self.volume = volume
        self.voiceIdentifier = voiceIdentifier
        self.englishPronunciation = englishPronunciation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rate = try container.decode(Float.self, forKey: .rate)
        pitch = try container.decode(Float.self, forKey: .pitch)
        volume = try container.decode(Float.self, forKey: .volume)
        voiceIdentifier = try container.decode(String.self, forKey: .voiceIdentifier)
        englishPronunciation = try container.decodeIfPresent(EnglishPronunciation.self, forKey: .englishPronunciation) ?? .american
    }
}

struct HistoryItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let sourceText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let engine: TranslationEngineKind
    let timestamp: Date

    init(result: TranslationResult) {
        id = result.id
        sourceText = result.originalText
        translatedText = result.translatedText
        sourceLanguage = result.sourceLanguage
        targetLanguage = result.targetLanguage
        engine = result.engine
        timestamp = result.createdAt
    }

    init(
        id: UUID = UUID(),
        sourceText: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String,
        engine: TranslationEngineKind = .apple,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.engine = engine
        self.timestamp = timestamp
    }
}

struct SummaryNote: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var content: String
    var sourceHistoryIDs: [UUID]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        sourceHistoryIDs: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.sourceHistoryIDs = sourceHistoryIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum AIEnhancementMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case polish
    case explain
    case summarize
    case rewrite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .polish: "润色"
        case .explain: "解释"
        case .summarize: "总结"
        case .rewrite: "改写"
        }
    }
}

struct AIEnhancementRequest: Equatable, Sendable {
    let text: String
    let mode: AIEnhancementMode
    let targetLanguage: String
}

struct AIEnhancementResult: Equatable, Sendable {
    let text: String
    let mode: AIEnhancementMode
    let createdAt: Date
}

enum KUNError: LocalizedError {
    case emptySelection
    case accessibilityDenied
    case screenRecordingDenied
    case screenshotCancelled
    case translationUnavailable(String)
    case missingAPIKey
    case invalidResponse
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .emptySelection:
            "没有读取到选中的文本。"
        case .accessibilityDenied:
            "需要开启辅助功能权限，才能读取其他 App 中的选中文本。"
        case .screenRecordingDenied:
            "需要开启屏幕录制权限，才能进行截图 OCR 翻译。"
        case .screenshotCancelled:
            "已取消截图选择。"
        case .translationUnavailable(let reason):
            "翻译暂不可用：\(reason)"
        case .missingAPIKey:
            "还没有配置 API Key。"
        case .invalidResponse:
            "服务返回了无法解析的响应。"
        case .underlying(let error):
            error.localizedDescription
        }
    }
}
