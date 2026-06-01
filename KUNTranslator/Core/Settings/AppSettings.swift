import Foundation
import Carbon

struct AppSettings: Codable, Equatable, Sendable {
    var targetLanguage: String
    var autoDetectLanguage: Bool
    var aiEnhancementEnabled: Bool
    var selectedEngine: TranslationEngineKind
    var openAIModel: String
    var openAIBaseURL: URL
    var overlayOpacity: Double
    var appearance: AppAppearance
    var speech: SpeechConfig
    var hotkeys: HotkeySettings
    var maxHistoryItems: Int

    static let deepSeekModel = "deepseek-v4-flash"
    static let deepSeekBaseURL = URL(string: "https://api.deepseek.com")!
    static let openAIModel = "gpt-4.1-mini"
    static let openAIBaseURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    static let `default` = AppSettings(
        targetLanguage: "zh-Hans",
        autoDetectLanguage: true,
        aiEnhancementEnabled: true,
        selectedEngine: .openAI,
        openAIModel: Self.deepSeekModel,
        openAIBaseURL: Self.deepSeekBaseURL,
        overlayOpacity: 0.92,
        appearance: .system,
        speech: .default,
        hotkeys: .default,
        maxHistoryItems: 200
    )
}

enum AppAppearance: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }
}

struct HotkeySettings: Codable, Equatable, Sendable {
    var translateSelection: Hotkey
    var translateScreenshot: Hotkey
    var speakSelection: Hotkey

    static let `default` = HotkeySettings(
        translateSelection: Hotkey(keyCode: UInt32(kVK_ANSI_T), modifiers: [.control, .option]),
        translateScreenshot: Hotkey(keyCode: UInt32(kVK_ANSI_Q), modifiers: [.control, .option]),
        speakSelection: Hotkey(keyCode: UInt32(kVK_ANSI_S), modifiers: [.control, .option])
    )

    static let legacyPRDDefault = HotkeySettings(
        translateSelection: Hotkey(keyCode: UInt32(kVK_ANSI_T), modifiers: [.command, .shift]),
        translateScreenshot: Hotkey(keyCode: UInt32(kVK_ANSI_Q), modifiers: [.option]),
        speakSelection: Hotkey(keyCode: UInt32(kVK_ANSI_S), modifiers: [.command, .shift])
    )
}
