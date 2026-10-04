import Foundation

struct ArticleHistorySummary: Identifiable {
    let id: String
    let totalSeconds: Double
    let latestAt: Date

    static func summarize(_ sessions: [StudySession]) -> [ArticleHistorySummary] {
        Dictionary(grouping: sessions, by: \.articleId).map { id, entries in
            ArticleHistorySummary(id: id,
                totalSeconds: entries.reduce(0) { $0 + $1.durationSeconds },
                latestAt: entries.map { $0.startedAt.addingTimeInterval($0.durationSeconds) }.max() ?? .distantPast)
        }.sorted { $0.latestAt == $1.latestAt ? $0.id < $1.id : $0.latestAt > $1.latestAt }
    }

    var durationText: String {
        let seconds = Int(totalSeconds)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainder = seconds % 60
        if hours > 0 { return "\(hours)時間\(minutes)分\(remainder)秒" }
        if minutes > 0 { return "\(minutes)分\(remainder)秒" }
        return "\(remainder)秒"
    }
}
