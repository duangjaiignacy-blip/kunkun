import Foundation

protocol SummaryNoteRepository: Sendable {
    func save(_ note: SummaryNote) async throws
    func recent(limit: Int) async throws -> [SummaryNote]
    func delete(id: UUID) async throws
    func clear() async throws
}
