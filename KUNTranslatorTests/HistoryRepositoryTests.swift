import XCTest

final class HistoryRepositoryTests: XCTestCase {
    func testSQLiteHistoryCRUD() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let repository = SQLiteHistoryRepository(dbURL: url)

        let item = HistoryItem(
            sourceText: "Hello",
            translatedText: "你好",
            sourceLanguage: "en",
            targetLanguage: "zh-Hans",
            timestamp: Date()
        )

        try await repository.add(item)
        let recent = try await repository.recent(limit: 10)

        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.sourceText, "Hello")

        try await repository.clear()
        let empty = try await repository.recent(limit: 10)
        XCTAssertEqual(empty, [])
    }
}
