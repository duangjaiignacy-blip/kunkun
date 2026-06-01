import Foundation
import SQLite3

final class SQLiteSummaryNoteRepository: SummaryNoteRepository, @unchecked Sendable {
    private let dbURL: URL
    private let queue = DispatchQueue(label: "kun.summary-notes.sqlite")

    init(
        dbURL: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("KUNTranslator", isDirectory: true)
            .appendingPathComponent("SummaryNotes.sqlite")
    ) {
        self.dbURL = dbURL
        try? FileManager.default.createDirectory(
            at: dbURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        queue.sync {
            _ = try? withDatabase { db in
                try self.execute(
                    db,
                    """
                    CREATE TABLE IF NOT EXISTS summary_notes (
                        id TEXT PRIMARY KEY,
                        title TEXT NOT NULL,
                        content TEXT NOT NULL,
                        sourceHistoryIDs TEXT NOT NULL,
                        createdAt REAL NOT NULL,
                        updatedAt REAL NOT NULL
                    );
                    """
                )
            }
        }
    }

    func save(_ note: SummaryNote) async throws {
        try await run { db in
            let sql = """
            INSERT OR REPLACE INTO summary_notes
            (id, title, content, sourceHistoryIDs, createdAt, updatedAt)
            VALUES (?, ?, ?, ?, ?, ?);
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.error(db)
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, note.id.uuidString, -1, NOTE_SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, note.title, -1, NOTE_SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, note.content, -1, NOTE_SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 4, Self.encodeIDs(note.sourceHistoryIDs), -1, NOTE_SQLITE_TRANSIENT)
            sqlite3_bind_double(statement, 5, note.createdAt.timeIntervalSince1970)
            sqlite3_bind_double(statement, 6, note.updatedAt.timeIntervalSince1970)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw Self.error(db)
            }
        }
    }

    func recent(limit: Int) async throws -> [SummaryNote] {
        try await run { db in
            let sql = """
            SELECT id, title, content, sourceHistoryIDs, createdAt, updatedAt
            FROM summary_notes
            ORDER BY updatedAt DESC
            LIMIT ?;
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.error(db)
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_int(statement, 1, Int32(limit))
            var notes: [SummaryNote] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                guard
                    let id = Self.string(statement, 0).flatMap(UUID.init(uuidString:)),
                    let title = Self.string(statement, 1),
                    let content = Self.string(statement, 2),
                    let sourceHistoryIDs = Self.string(statement, 3)
                else {
                    continue
                }

                notes.append(
                    SummaryNote(
                        id: id,
                        title: title,
                        content: content,
                        sourceHistoryIDs: Self.decodeIDs(sourceHistoryIDs),
                        createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 4)),
                        updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))
                    )
                )
            }

            return notes
        }
    }

    func delete(id: UUID) async throws {
        try await run { db in
            let sql = "DELETE FROM summary_notes WHERE id = ?;"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.error(db)
            }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, id.uuidString, -1, NOTE_SQLITE_TRANSIENT)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw Self.error(db)
            }
        }
    }

    func clear() async throws {
        try await run { db in
            try self.execute(db, "DELETE FROM summary_notes;")
        }
    }

    private func run<T: Sendable>(_ block: @escaping @Sendable (OpaquePointer) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try self.withDatabase(block))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func withDatabase<T>(_ block: (OpaquePointer) throws -> T) throws -> T {
        var db: OpaquePointer?
        guard sqlite3_open(dbURL.path, &db) == SQLITE_OK, let db else {
            throw KUNError.invalidResponse
        }
        defer { sqlite3_close(db) }
        return try block(db)
    }

    private func execute(_ db: OpaquePointer, _ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw Self.error(db)
        }
    }

    private static func encodeIDs(_ ids: [UUID]) -> String {
        ids.map(\.uuidString).joined(separator: ",")
    }

    private static func decodeIDs(_ value: String) -> [UUID] {
        value
            .split(separator: ",")
            .compactMap { UUID(uuidString: String($0)) }
    }

    private static func string(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let value = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: value)
    }

    private static func error(_ db: OpaquePointer) -> Error {
        let message = sqlite3_errmsg(db).map { String(cString: $0) } ?? "SQLite error"
        return KUNError.translationUnavailable(message)
    }
}

private let NOTE_SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
