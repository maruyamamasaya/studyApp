import XCTest
@testable import StudyApp

final class DiscoveryTests: XCTestCase {
    private func article(_ number: Int, folder: String = "wiki/topic") -> Article {
        Article(id: String(format: "20261002-%06d", number), title: "記事\(number)", path: "\(folder)/\(number).md", type: "study", tags: ["Swift"], aliases: [], created: "2026-10-02 12:00:00", contentHash: String(repeating: "0", count: 64))
    }
    func testDailyPicksRemainStableAcrossCatalogOrder() {
        let articles = (1...20).map { article($0) }
        let picks = ArticleDiscovery.picks(articles, day: "2026-10-02")
        XCTAssertEqual(picks, ArticleDiscovery.picks(articles.reversed(), day: "2026-10-02"))
        XCTAssertEqual(Set(picks.map(\.id)).count, 3)
        XCTAssertNotEqual(picks, ArticleDiscovery.picks(articles, day: "2026-10-03"))
        XCTAssertNotEqual(picks, ArticleDiscovery.picks(articles, day: "2026-10-02", shuffle: 1))
        XCTAssertEqual(ArticleDiscovery.picks([], day: "2026-10-02"), [])
    }
    func testFolderAncestorsAndPrefixBoundaries() {
        let a = article(1, folder: "wiki/topic/sub")
        XCTAssertEqual(ArticleDiscovery.folders([a]), ["wiki", "wiki/topic", "wiki/topic/sub"])
        XCTAssertTrue(ArticleDiscovery.inFolder(a, "wiki/topic"))
        XCTAssertFalse(ArticleDiscovery.inFolder(article(2, folder: "wiki/topic-other"), "wiki/topic"))
    }
    @MainActor func testOldBackupAndNewOrganizationSurviveRestartAndRestore() throws {
        let old = Data("{\"schemaVersion\":1,\"progress\":{},\"sessions\":[]}".utf8)
        XCTAssertNoThrow(try StudyStore.decode(old))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("records.json")
        let store = StudyStore(file: file)
        try store.restore(old)
        let a = article(1)
        store.viewed(a)
        store.toggleFavorite(a.id)
        store.createCollection("  復習  ")
        let id = try XCTUnwrap(store.data.collections?.first?.id)
        store.toggleMembership(a.id, collectionID: id)
        store.renameCollection(id, name: "週末")
        let restarted = StudyStore(file: file)
        XCTAssertTrue(restarted.isFavorite(a.id))
        XCTAssertEqual(restarted.data.collections?.first?.name, "週末")
        XCTAssertEqual(restarted.data.collections?.first?.articleIDs, [a.id])
        try restarted.restore(store.export())
        restarted.deleteCollection(id)
        XCTAssertTrue(restarted.data.collections?.isEmpty == true)
        XCTAssertTrue(restarted.isFavorite(a.id))
        XCTAssertNotNil(restarted.data.progress[a.id])
        restarted.toggleFavorite(a.id)
        XCTAssertFalse(restarted.isFavorite(a.id))
    }
    func testInvalidOrganizationBackupIsRejected() throws {
        var backup = StudyBackup()
        backup.favorites = ["invalid"]
        XCTAssertThrowsError(try backup.validated())
        backup.favorites = []
        backup.collections = [ArticleCollection(id: UUID(), name: " ", articleIDs: [])]
        XCTAssertThrowsError(try backup.validated())
    }
}
