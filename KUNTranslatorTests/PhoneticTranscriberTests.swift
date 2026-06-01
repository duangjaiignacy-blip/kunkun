import XCTest

final class PhoneticTranscriberTests: XCTestCase {
    func testTranscriberUsesPronunciationVariant() {
        let transcriber = PhoneticTranscriber()

        XCTAssertEqual(transcriber.transcribe("News", pronunciation: .american), "/nuːz/")
        XCTAssertEqual(transcriber.transcribe("News", pronunciation: .british), "/njuːz/")
    }

    func testSpeechConfigDecodesLegacySettings() throws {
        let legacyJSON = """
        {
          "rate": 0.48,
          "pitch": 1.0,
          "volume": 1.0,
          "voiceIdentifier": ""
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SpeechConfig.self, from: legacyJSON)

        XCTAssertEqual(decoded.englishPronunciation, .american)
    }
}
