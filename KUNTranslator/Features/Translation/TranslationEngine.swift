import Foundation

@MainActor
protocol TranslationEngine: AnyObject {
    var kind: TranslationEngineKind { get }
    func translate(_ request: TranslationRequest) async throws -> TranslationResult
}

final class MockTranslationEngine: TranslationEngine {
    let kind: TranslationEngineKind = .mock
    private let detector = LanguageDetector()

    func translate(_ request: TranslationRequest) async throws -> TranslationResult {
        TranslationResult(
            originalText: request.text,
            translatedText: "[Mock \(request.targetLanguage)] \(request.text)",
            sourceLanguage: request.sourceLanguage ?? detector.detect(request.text),
            targetLanguage: request.targetLanguage,
            engine: kind,
            createdAt: Date()
        )
    }
}

final class TranslationCoordinator {
    private let apple: TranslationEngine
    private let openAI: TranslationEngine?
    private let settingsStore: SettingsStore
    private let historyRepository: HistoryRepository
    private let detector = LanguageDetector()

    init(
        apple: TranslationEngine,
        openAI: TranslationEngine?,
        settingsStore: SettingsStore,
        historyRepository: HistoryRepository
    ) {
        self.apple = apple
        self.openAI = openAI
        self.settingsStore = settingsStore
        self.historyRepository = historyRepository
    }

    @MainActor
    func translate(_ text: String) async throws -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw KUNError.emptySelection }

        let settings = settingsStore.settings
        let request = TranslationRequest(
            text: trimmed,
            sourceLanguage: settings.autoDetectLanguage ? nil : detector.detect(trimmed),
            targetLanguage: settings.targetLanguage
        )
        let engine = settings.selectedEngine == .openAI ? (openAI ?? apple) : apple
        let result = try await engine.translate(request)
        try? await historyRepository.add(HistoryItem(result: result))
        if let sqlite = historyRepository as? SQLiteHistoryRepository {
            try? await sqlite.trim(to: settings.maxHistoryItems)
        }
        return result
    }
}
