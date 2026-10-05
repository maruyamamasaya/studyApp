import XCTest
@testable import StudyApp

final class ArticlePreviewTests: XCTestCase {
    func testExcerptUsesIntroductoryProseWithoutMetadataOrHeading() {
        let raw = "---\ntitle: 記事\n---\n# タイトル\n\n## はじめに\n\n**RAG**は、[資料](https://example.com)を検索する仕組みです。\n次の説明。\n\n次の段落。"
        XCTAssertEqual(ArticlePreview.excerpt(raw), "RAGは、資料を検索する仕組みです。 次の説明。")
    }
    func testExcerptSkipsCodeAndPreservesWikiLinkLabel() {
        let raw = "```swift\n秘密ではないコード\n```\n\n[[RAG|検索拡張生成]]を使います。"
        XCTAssertEqual(ArticlePreview.excerpt(raw), "検索拡張生成を使います。")
        XCTAssertEqual(ArticlePreview.excerpt("# 見出しだけ\n"), "")
    }
    func testExcerptIsBoundedAndHandlesCRLF() {
        XCTAssertEqual(ArticlePreview.excerpt("# 見出し\r\n\r\n本文"), "本文")
        XCTAssertEqual(ArticlePreview.excerpt(String(repeating: "あ", count: 500)).count, 140)
    }
}
