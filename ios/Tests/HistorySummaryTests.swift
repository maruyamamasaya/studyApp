import XCTest
@testable import StudyApp

final class HistorySummaryTests: XCTestCase {
    func testGroupsByArticleAndSortsByLatestStudy() {
        let sessions = [
            StudySession(id: UUID(), articleId: "20261002-000001", startedAt: Date(timeIntervalSince1970: 100), durationSeconds: 60),
            StudySession(id: UUID(), articleId: "20261002-000002", startedAt: Date(timeIntervalSince1970: 300), durationSeconds: 90),
            StudySession(id: UUID(), articleId: "20261002-000001", startedAt: Date(timeIntervalSince1970: 500), durationSeconds: 12.5)
        ]
        let result = ArticleHistorySummary.summarize(sessions.reversed())
        XCTAssertEqual(result.map(\.id), ["20261002-000001", "20261002-000002"])
        XCTAssertEqual(result[0].totalSeconds, 72.5)
        XCTAssertEqual(result[0].durationText, "1分12秒")
        XCTAssertEqual(result[1].durationText, "1分30秒")
        XCTAssertEqual(sessions.count, 3)
    }
    func testEmptyHistoryAndDurationFormatting() {
        XCTAssertTrue(ArticleHistorySummary.summarize([]).isEmpty)
        XCTAssertEqual(ArticleHistorySummary(id: "a", totalSeconds: 3665, latestAt: Date()).durationText, "1時間1分5秒")
        XCTAssertEqual(ArticleHistorySummary(id: "a", totalSeconds: 0.5, latestAt: Date()).durationText, "0秒")
    }
}
