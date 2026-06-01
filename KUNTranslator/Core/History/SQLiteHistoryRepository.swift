import Foundation
import SQLite3

final class SQLiteHistoryRepository: HistoryRepository, @unchecked Sendable {
    private let dbURL: URL
    private let queue = DispatchQueue(label: "kun.history.sqlite")

    init(
        dbURL: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("KUNTranslator", isDirectory: true)
            .appendingPathComponent("History.sqlite")
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
                    CREATE TABLE IF NOT EXISTS history (
                        id TEXT PRIMARY KEY,
                        sourceText TEXT NOT NULL,
                        translatedText TEXT NOT NULL,
                        sourceLanguage TEXT NOT NULL,
                        targetLanguage TEXT NOT NULL,
                        engine TEXT NOT NULL,
                        timestamp REAL NOT NULL
                    );
                    """
                )
            }
        }
    }

    func add(_ item: HistoryItem) async throws {
        try await run { db in
            let sql = """
            INSERT OR REPLACE INTO history
            (id, sourceText, translatedText, sourceLanguage, targetLanguage, engine, timestamp)
            VALUES (?, ?, ?, ?, ?, ?, ?);
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.error(db)
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, item.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, item.sourceText, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, item.translatedText, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 4, item.sourceLanguage, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 5, item.targetLanguage, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 6, item.engine.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(statement, 7, item.timestamp.timeIntervalSince1970)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw Self.error(db)
            }
        }
    }

    func recent(limit: Int) async throws -> [HistoryItem] {
        try await run { db in
            let sql = """
            SELECT id, sourceText, translatedText, sourceLanguage, targetLanguage, engine, timestamp
            FROM history
            ORDER BY timestamp DESC
            LIMIT ?;
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.error(db)
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_int(statement, 1, Int32(limit))
            var items: [HistoryItem] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                guard
                    let id = Self.string(statement, 0).flatMap(UUID.init(uuidString:)),
                    let sourceText = Self.string(statement, 1),
                    let translatedText = Self.string(statement, 2),
                    let sourceLanguage = Self.string(statement, 3),
                    let targetLanguage = Self.string(statement, 4)
                else {
                    continue
                }
                let engine = Self.string(statement, 5).flatMap(TranslationEngineKind.init(rawValue:)) ?? .apple
                let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 6))
                items.append(
                    HistoryItem(
                        id: id,
                        sourceText: sourceText,
                        translatedText: translatedText,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage,
                        engine: engine,
                        timestamp: timestamp
                    )
                )
            }

            return items
        }
    }

    func clear() async throws {
        try await run { db in
            try self.execute(db, "DELETE FROM history;")
        }
    }

    func trim(to limit: Int) async throws {
        try await run { db in
            try self.execute(
                db,
                """
                DELETE FROM history
                WHERE id NOT IN (
                    SELECT id FROM history ORDER BY timestamp DESC LIMIT \(limit)
                );
                """
            )
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

    private static func string(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let value = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: value)
    }

    private static func error(_ db: OpaquePointer) -> Error {
        let message = sqlite3_errmsg(db).map { String(cString: $0) } ?? "SQLite error"
        return KUNError.translationUnavailable(message)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
