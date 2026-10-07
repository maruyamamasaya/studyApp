import XCTest
@testable import StudyApp

final class OfflineTests: XCTestCase {
    private struct OfflineClient: ArticleProviding {
        func catalog() async throws -> Catalog { throw URLError(.notConnectedToInternet) }
        func content(_ article: Article) async throws -> String { throw URLError(.notConnectedToInternet) }
    }
    @MainActor func testLibraryUsesSavedCatalogAndBodyWithoutNetwork() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let text = "# 保存本文"
        let article = Article(id: "20261001-171535", title: "保存", path: "wiki/a.md", type: "study", tags: [], aliases: [], created: "2026-10-01 17:15:35", contentHash: ArticleClient.hash(text))
        let storage = OfflineArticles(directory: root)
        try await storage.save(Catalog(schemaVersion: 1, revision: String(repeating: "a", count: 64), articles: [article]))
        try await storage.save(text, for: article)
        let library = Library(client: OfflineClient(), offline: storage)
        await library.reload()
        XCTAssertNil(library.error); XCTAssertTrue(library.offlineCatalog)
        XCTAssertEqual(library.articles, [article])
        let body = try await library.content(article)
        XCTAssertEqual(body, text)
        XCTAssertTrue(library.offlineIDs.contains(article.id))
        await library.removeOffline()
        do { _ = try await library.content(article); XCTFail("deleted cache was served") } catch { }
    }
    func testVerifiedOfflineReadRestartMismatchAndRemoval() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let text = "# Offline\n本文"
        let article = Article(id: "20261001-171535", title: "Offline", path: "wiki/a.md", type: "study", tags: [], aliases: [], created: "2026-10-01 17:15:35", contentHash: ArticleClient.hash(text))
        let catalog = Catalog(schemaVersion: 1, revision: String(repeating: "a", count: 64), articles: [article])
        let storage = OfflineArticles(directory: root)
        try await storage.save(catalog); try await storage.save(text, for: article)
        let restarted = OfflineArticles(directory: root)
        let restored = try await restarted.catalog()
        XCTAssertEqual(restored?.articles, [article])
        let body = try await restarted.content(article)
        XCTAssertEqual(body, text)
        let summary = try await restarted.summary(articles: [article])
        XCTAssertEqual(summary.ids, [article.id]); XCTAssertGreaterThan(summary.bytes, 0)
        do { try await restarted.save("違う本文", for: article); XCTFail("hash mismatch accepted") } catch { }
        try "破損".write(to: root.appendingPathComponent(article.contentHash + ".md"), atomically: true, encoding: .utf8)
        do { _ = try await restarted.content(article); XCTFail("corrupt cache accepted") } catch { }
        try await restarted.remove()
        let empty = try await restarted.summary(articles: [article]); XCTAssertEqual(empty.bytes, 0)
    }
    func testRecordMergeIsIdempotentAndRejectsConflictingSessions() throws {
        let id = "20261001-171535", sessionID = UUID(), date = Date(timeIntervalSince1970: 1000)
        var local = StudyBackup()
        local.sessions = [StudySession(id: sessionID, articleId: id, startedAt: date, durationSeconds: 10)]
        local.progress[id] = ProgressRecord(title: "記事", completed: false, lastViewedAt: date)
        var incoming = local; incoming.favorites = [id]
        incoming.progress[id]?.completed = true
        let combined = try StudyRecordMerge.combine(local: local, incoming: incoming)
        let repeated = try StudyRecordMerge.combine(local: combined, incoming: incoming)
        XCTAssertEqual(repeated.sessions.count, 1)
        XCTAssertEqual(repeated.sessions.first?.durationSeconds, 10)
        XCTAssertTrue(repeated.progress[id]?.completed == true)
        XCTAssertEqual(repeated.favorites, [id])
        incoming.sessions = [StudySession(id: sessionID, articleId: id, startedAt: date, durationSeconds: 20)]
        XCTAssertThrowsError(try StudyRecordMerge.combine(local: local, incoming: incoming))
    }
}
