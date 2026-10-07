import XCTest
@testable import StudyApp

final class StudyAppTests: XCTestCase {
    private func article(id: String = "20261001-171535", path: String = "wiki/anken001/20261001-171535.md", title: String = "RAG", type: String = "study") -> Article {
        Article(id: id, title: title, path: path, type: type, tags: ["RAG"], aliases: ["検索拡張生成"],
                created: "2026-10-01 17:15:35", contentHash: String(repeating: "0", count: 64))
    }
    func testPickupKeepsExistingRankingAfterPrecomputation() {
        let samples = (0..<16).map { article(id: String(format: "20261001-%06d", $0)) }
        for day in ["2026-10-06", "2026-10-07"] {
            for shuffle in [0, 1, 7] {
                let expected = samples.sorted {
                    ArticleClient.hash("\(day)/\(shuffle)/\($0.id)") < ArticleClient.hash("\(day)/\(shuffle)/\($1.id)")
                }.prefix(3).map(\.id)
                XCTAssertEqual(ArticleDiscovery.picks(samples, day: day, shuffle: shuffle).map(\.id), expected)
                XCTAssertEqual(ArticleDiscovery.picks(Array(samples.reversed()), day: day, shuffle: shuffle).map(\.id), expected)
            }
        }
        XCTAssertTrue(ArticleDiscovery.picks([], day: "2026-10-06").isEmpty)
        XCTAssertEqual(ArticleDiscovery.picks([samples[0]], day: "2026-10-06").map(\.id), [samples[0].id])
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
    func testCatalogAcceptsDevelopmentLogAlongsideExistingArticles() throws {
        let articles = [article(),
                        article(id: "20261001-171536", path: "wiki/anken001/20261001-171536.md", type: "wiki"),
                        article(id: "20261005-093655", path: "wiki/official/20261005-093655.md", type: "development-log")]
        let catalog = Catalog(schemaVersion: 1, revision: String(repeating: "0", count: 64), articles: articles)
        let decoded = try JSONDecoder().decode(Catalog.self, from: JSONEncoder().encode(catalog))
        XCTAssertEqual(try decoded.validated().articles.count, 3)
        for type in ["Applied", "自由な分類", ""] {
            let custom = Catalog(schemaVersion: 1, revision: catalog.revision, articles: [article(type: type)])
            let decodedCustom = try JSONDecoder().decode(Catalog.self, from: JSONEncoder().encode(custom))
            XCTAssertEqual(try decodedCustom.validated().articles.first?.type, type)
        }
        var invalid = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(article())) as? [String: Any])
        for value in [1, false, NSNull(), ["Applied"]] as [Any] {
            invalid["type"] = value
            XCTAssertThrowsError(try JSONDecoder().decode(Article.self, from: JSONSerialization.data(withJSONObject: invalid)))
        }
    }
    func testCatalogAllowsExtendedAndUnclassifiedArticleTypes() throws {
        let a = article()
        for type in ["development-log", "activity-log", "Applied", ""] {
            let entry = Article(id: a.id, title: a.title, path: a.path, type: type,
                tags: a.tags, aliases: a.aliases, created: a.created, contentHash: a.contentHash)
            let data = try JSONEncoder().encode(Catalog(schemaVersion: 1,
                revision: String(repeating: "0", count: 64), articles: [entry]))
            let decoded = try JSONDecoder().decode(Catalog.self, from: data).validated()
            XCTAssertEqual(decoded.articles.first?.type, type)
            let unsafe = Article(id: a.id, title: a.title, path: "wiki/../secret.md", type: type,
                tags: a.tags, aliases: a.aliases, created: a.created, contentHash: a.contentHash)
            XCTAssertThrowsError(try Catalog(schemaVersion: 1,
                revision: String(repeating: "0", count: 64), articles: [unsafe]).validated())
        }
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
