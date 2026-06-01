import Foundation

final class OpenAITranslationEngine: TranslationEngine {
    let kind: TranslationEngineKind = .openAI
    private let client: OpenAICompatibleClient
    private let detector = LanguageDetector()

    init(client: OpenAICompatibleClient) {
        self.client = client
    }

    func translate(_ request: TranslationRequest) async throws -> TranslationResult {
        let prompt = """
        You are a professional translation assistant.
        Translate the following content to \(request.targetLanguage).
        Requirements:
        1. Keep the translation natural.
        2. Preserve context.
        3. Do not translate mechanically.
        4. Keep professional terms when appropriate.

        Content:
        \(request.text)
        """
        let text = try await client.complete(prompt: prompt)
        return TranslationResult(
            originalText: request.text,
            translatedText: text,
            sourceLanguage: request.sourceLanguage ?? detector.detect(request.text),
            targetLanguage: request.targetLanguage,
            engine: .openAI,
            createdAt: Date()
        )
    }
}

protocol AIEnhancer {
    func enhance(_ request: AIEnhancementRequest) async throws -> AIEnhancementResult
}

final class OpenAIEnhancer: AIEnhancer {
    private let client: OpenAICompatibleClient

    init(client: OpenAICompatibleClient) {
        self.client = client
    }

    func enhance(_ request: AIEnhancementRequest) async throws -> AIEnhancementResult {
        let text = try await client.complete(prompt: Self.prompt(for: request))
        return AIEnhancementResult(text: text, mode: request.mode, createdAt: Date())
    }

    static func prompt(for request: AIEnhancementRequest) -> String {
        switch request.mode {
        case .polish:
            """
            You are a professional translation editor.
            Polish the following translated text in \(request.targetLanguage).
            Keep meaning, terminology, and tone.

            Text:
            \(request.text)
            """
        case .explain:
            """
            Explain the meaning, tone, and important terms of the following text in \(request.targetLanguage).

            Text:
            \(request.text)
            """
        case .summarize:
            """
            Summarize the following text concisely in \(request.targetLanguage).

            Text:
            \(request.text)
            """
        case .rewrite:
            """
            Rewrite the following text in natural \(request.targetLanguage).
            Preserve all key facts.

            Text:
            \(request.text)
            """
        }
    }
}

final class OpenAICompatibleClient {
    private let settingsStore: SettingsStore
    private let keychain: KeychainStore
    private let session: URLSession

    init(
        settingsStore: SettingsStore,
        keychain: KeychainStore = KeychainStore(),
        session: URLSession = .shared
    ) {
        self.settingsStore = settingsStore
        self.keychain = keychain
        self.session = session
    }

    @MainActor
    func complete(prompt: String) async throws -> String {
        guard let apiKey = try keychain.readAPIKey(), !apiKey.isEmpty else {
            throw KUNError.missingAPIKey
        }

        let settings = settingsStore.settings
        let endpoint = Self.chatCompletionsURL(from: settings.openAIBaseURL)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ChatCompletionRequest(
                model: settings.openAIModel,
                messages: [
                    .init(role: "system", content: "You are KUN Translator, a concise and accurate language assistant."),
                    .init(role: "user", content: prompt)
                ],
                temperature: 0.2,
                thinking: Self.thinkingConfig(for: endpoint)
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw KUNError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw KUNError.invalidResponse
        }
        return content
    }

    static func chatCompletionsURL(from configuredURL: URL) -> URL {
        let path = configuredURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasSuffix("chat/completions") {
            return configuredURL
        }
        return configuredURL.appendingPathComponent("chat/completions")
    }

    private static func thinkingConfig(for endpoint: URL) -> ChatCompletionRequest.Thinking? {
        guard endpoint.host?.contains("deepseek.com") == true else { return nil }
        return .init(type: "disabled")
    }
}

struct ChatCompletionRequest: Encodable, Equatable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let thinking: Thinking?

    init(
        model: String,
        messages: [Message],
        temperature: Double,
        thinking: Thinking? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.thinking = thinking
    }

    struct Message: Encodable, Equatable {
        let role: String
        let content: String
    }

    struct Thinking: Encodable, Equatable {
        let type: String
    }
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}
