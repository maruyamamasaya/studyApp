import XCTest
@testable import StudyApp

final class RelatedContentTests: XCTestCase {
    private func article(_ id: String, tags: [String]) -> Article {
        Article(id: id, title: id, path: "wiki/" + id + ".md", type: "study", tags: tags, aliases: [], created: "2026-10-01 17:15:35", contentHash: String(repeating: "a", count: 64))
    }
    @MainActor func testCreateAndSaveCollectionAtomically() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = StudyStore(file: root.appendingPathComponent("records.json"))
        let a = article("20261001-171535", tags: ["RAG"])
        store.createCollection("仕事", adding: a.id)
        XCTAssertNil(store.error)
        let restored = StudyStore(file: root.appendingPathComponent("records.json"))
        XCTAssertEqual(restored.data.collections?.first?.articleIDs, [a.id])
        XCTAssertEqual(ArticleDiscovery.pickupCandidates([a], tag: "RAG").map(\.id), [a.id])
        XCTAssertTrue(ArticleDiscovery.pickupCandidates([a], tag: "API").isEmpty)
    }
    func testRelatedArticlesExcludeSelfAndRankSharedTags() {
        let a = article("20261001-171535", tags: ["RAG", "API"])
        let b = article("20261001-171536", tags: ["RAG"])
        let c = article("20261001-171537", tags: ["RAG", "API", "API"])
        let d = article("20261001-171538", tags: [])
        let related = RelatedContent.articles(for: a, in: [a,b,c,d])
        XCTAssertEqual(related.map(\.id), [c.id,b.id])
        XCTAssertEqual(related.first?.tags, ["API", "RAG"])
        XCTAssertTrue(RelatedContent.articles(for: d, in: [a,b,c,d]).isEmpty)
        XCTAssertEqual(RelatedContent.articles(for: a, in: [a,b,c,d], limit: 1).count, 1)
    }
}
