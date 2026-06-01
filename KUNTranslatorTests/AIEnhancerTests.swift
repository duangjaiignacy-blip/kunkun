import XCTest

final class AIEnhancerTests: XCTestCase {
    func testPromptIncludesModeAndText() {
        let request = AIEnhancementRequest(
            text: "Hello world",
            mode: .summarize,
            targetLanguage: "zh-Hans"
        )

        let prompt = OpenAIEnhancer.prompt(for: request)

        XCTAssertTrue(prompt.contains("Summarize"))
        XCTAssertTrue(prompt.contains("zh-Hans"))
        XCTAssertTrue(prompt.contains("Hello world"))
    }

    func testChatCompletionRequestEncodesMessages() throws {
        let request = ChatCompletionRequest(
            model: "gpt-test",
            messages: [.init(role: "user", content: "Translate")],
            temperature: 0.2
        )

        let data = try JSONEncoder().encode(request)
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertTrue(json.contains("gpt-test"))
        XCTAssertTrue(json.contains("Translate"))
    }

    func testDeepSeekBaseURLNormalizesToChatCompletionsEndpoint() throws {
        let url = OpenAICompatibleClient.chatCompletionsURL(
            from: URL(string: "https://api.deepseek.com")!
        )

        XCTAssertEqual(url.absoluteString, "https://api.deepseek.com/chat/completions")
    }

    func testExplicitChatCompletionsEndpointIsPreserved() throws {
        let url = OpenAICompatibleClient.chatCompletionsURL(
            from: URL(string: "https://api.deepseek.com/chat/completions")!
        )

        XCTAssertEqual(url.absoluteString, "https://api.deepseek.com/chat/completions")
    }
}
