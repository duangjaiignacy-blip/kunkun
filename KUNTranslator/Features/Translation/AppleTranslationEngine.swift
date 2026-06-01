import Foundation

#if HAS_APPLE_TRANSLATION && canImport(Translation)
import Translation
import SwiftUI

@MainActor
final class AppleTranslationEngine: TranslationEngine {
    let kind: TranslationEngineKind = .apple
    private var bridgeStorage: AnyObject?

    func translate(_ request: TranslationRequest) async throws -> TranslationResult {
        guard #available(macOS 15.0, *) else {
            throw KUNError.translationUnavailable("Apple 翻译需要 macOS 15.0 或更高版本。macOS 14 请使用 OpenAI 翻译。")
        }
        return try await runtimeBridge().translate(request)
    }

    @available(macOS 15.0, *)
    func runtimeBridge() -> AppleTranslationBridge {
        if let bridge = bridgeStorage as? AppleTranslationBridge {
            return bridge
        }
        let bridge = AppleTranslationBridge()
        bridgeStorage = bridge
        return bridge
    }
}

@available(macOS 15.0, *)
@MainActor
final class AppleTranslationBridge: ObservableObject {
    @Published var configuration: TranslationSession.Configuration?
    private var activeJob: TranslationJob?
    private let detector = LanguageDetector()

    func translate(_ request: TranslationRequest) async throws -> TranslationResult {
        if activeJob != nil {
            throw KUNError.translationUnavailable("已有翻译任务正在进行。")
        }

        return try await withCheckedThrowingContinuation { continuation in
            activeJob = TranslationJob(request: request, continuation: continuation)
            let source = request.sourceLanguage.map(Locale.Language.init(identifier:))
            let target = Locale.Language(identifier: request.targetLanguage)
            configuration = TranslationSession.Configuration(source: source, target: target)
            configuration?.invalidate()
        }
    }

    func perform(using session: TranslationSession) async {
        guard let job = activeJob else { return }
        do {
            let response = try await session.translate(job.request.text)
            let result = TranslationResult(
                originalText: job.request.text,
                translatedText: response.targetText,
                sourceLanguage: job.request.sourceLanguage ?? detector.detect(job.request.text),
                targetLanguage: job.request.targetLanguage,
                engine: .apple,
                createdAt: Date()
            )
            job.continuation.resume(returning: result)
        } catch {
            job.continuation.resume(throwing: KUNError.underlying(error))
        }
        activeJob = nil
    }
}

@available(macOS 15.0, *)
private struct TranslationJob {
    let request: TranslationRequest
    let continuation: CheckedContinuation<TranslationResult, Error>
}
#else
@MainActor
final class AppleTranslationEngine: TranslationEngine {
    let kind: TranslationEngineKind = .apple

    func translate(_ request: TranslationRequest) async throws -> TranslationResult {
        throw KUNError.translationUnavailable("Apple 翻译需要启用 HAS_APPLE_TRANSLATION，并运行在 macOS 15.0 或更高版本。")
    }
}
#endif
