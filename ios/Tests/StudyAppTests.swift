import XCTest
@testable import StudyApp

final class StudyAppTests: XCTestCase {
    private func article(id: String = "20261001-171535", path: String = "wiki/anken001/20261001-171535.md", title: String = "RAG") -> Article {
        Article(id: id, title: title, path: path, type: "study", tags: ["RAG"], aliases: ["検索拡張生成"],
                created: "2026-10-01 17:15:35", contentHash: String(repeating: "0", count: 64))
    }
    func testHashMatchesPublishedAlgorithm() {
        XCTAssertEqual(ArticleClient.hash("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(ArticleClient.hash("日本語\r\n"), ArticleClient.hash("日本語\n"))
        XCTAssertNotEqual(ArticleClient.hash("本文\n"), ArticleClient.hash("本文 \n"))
    }
    func testPathsAndURL() throws {
        for path in ["../secret.md", "wiki/../secret.md", "wiki//x.md", "wiki/./x.md", "https://evil/x.md", "wiki\\x.md"] {
            XCTAssertThrowsError(try ArticleClient.url(for: path))
        }
        let url = try ArticleClient.url(for: "wiki/日本語 #%.md")
        XCTAssertNil(url.fragment)
        XCTAssertNil(url.query)
        XCTAssertEqual(url.path, "/studyApp/wiki/日本語 #%.md")
    }
    func testCatalogRejectsDuplicatesAndSchema() {
        let a = article()
        XCTAssertThrowsError(try Catalog(schemaVersion: 2, revision: String(repeating: "0", count: 64), articles: []).validated())
        XCTAssertThrowsError(try Catalog(schemaVersion: 1, revision: String(repeating: "0", count: 64), articles: [a, a]).validated())
        XCTAssertNoThrow(try Catalog(schemaVersion: 1, revision: String(repeating: "0", count: 64), articles: []).validated())
    }
    func testFrontmatterWikiLinksAndCode() {
        let converted = ArticleLinks.body("---\ntitle: テスト\n---\n[[検索拡張生成|RAG]]\n```python\n[[変更しない]]\n```\n`[[変更しない]]`")
        XCTAssertFalse(converted.contains("title: テスト"))
        XCTAssertTrue(converted.contains("[RAG](studyarticle://link?"))
        XCTAssertTrue(converted.contains("```python\n[[変更しない]]\n```"))
        XCTAssertTrue(converted.contains("`[[変更しない]]`"))
    }
    func testLinksResolveOnlyCatalogEntries() {
        let a = article()
        let b = article(id: "20261001-171536", path: "wiki/anken002/20261001-171536.md", title: "別記事")
        XCTAssertEqual(ArticleLinks.resolve("検索拡張生成", current: b, articles: [a, b]).map(\.id), [a.id, b.id])
        XCTAssertEqual(ArticleLinks.resolve("../anken001/20261001-171535.md#概要", current: b, articles: [a, b]).map(\.id), [a.id])
        XCTAssertTrue(ArticleLinks.resolve("../../secret.md", current: b, articles: [a, b]).isEmpty)
    }
    @MainActor func testRecordsSurviveRestartAndRestoreDoesNotDuplicate() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("records.json")
        let store = StudyStore(file: file)
        let a = article()
        store.viewed(a)
        store.toggle(a)
        let session = StudySession(id: UUID(), articleId: a.id, startedAt: Date(), durationSeconds: 12)
        store.add(session); store.add(session)
        XCTAssertEqual(store.seconds(for: a.id), 12)
        let restarted = StudyStore(file: file)
        XCTAssertTrue(restarted.data.progress[a.id]?.completed == true)
        XCTAssertEqual(restarted.seconds(for: a.id), 12)
        let bytes = try store.export()
        try restarted.restore(bytes); try restarted.restore(bytes)
        XCTAssertEqual(restarted.data.sessions.count, 1)
        XCTAssertThrowsError(try restarted.restore(Data("{}".utf8)))
        XCTAssertEqual(restarted.data.sessions.count, 1)
    }
    @MainActor func testCorruptLocalFileIsProtected() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("records.json")
        let corrupt = Data("broken".utf8)
        try corrupt.write(to: file)
        let store = StudyStore(file: file)
        store.viewed(article())
        XCTAssertNotNil(store.error)
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
    }
}
