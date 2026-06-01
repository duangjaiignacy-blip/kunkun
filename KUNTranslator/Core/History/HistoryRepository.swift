import Foundation

protocol HistoryRepository: Sendable {
    func add(_ item: HistoryItem) async throws
    func recent(limit: Int) async throws -> [HistoryItem]
    func clear() async throws
}
