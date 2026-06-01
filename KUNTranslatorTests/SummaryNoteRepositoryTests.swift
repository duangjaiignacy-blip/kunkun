import XCTest

final class SummaryNoteRepositoryTests: XCTestCase {
    func testSQLiteSummaryNoteCRUD() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let repository = SQLiteSummaryNoteRepository(dbURL: url)
        let sourceID = UUID()
        let note = SummaryNote(
            title: "阅读总结",
            content: "重点内容",
            sourceHistoryIDs: [sourceID]
        )

        try await repository.save(note)

        let recent = try await repository.recent(limit: 10)
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.title, "阅读总结")
        XCTAssertEqual(recent.first?.sourceHistoryIDs, [sourceID])

        try await repository.delete(id: note.id)
        let empty = try await repository.recent(limit: 10)
        XCTAssertEqual(empty, [])
    }
}
