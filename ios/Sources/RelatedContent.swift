import Foundation

struct RelatedArticle: Identifiable {
    let article: Article
    let tags: [String]
    var id: String { article.id }
}
enum RelatedContent {
    static func articles(for current: Article, in articles: [Article], limit: Int = 5) -> [RelatedArticle] {
        let tags = Set(current.tags)
        return Array(articles.filter { $0.id != current.id }.compactMap { article -> RelatedArticle? in
            let shared = tags.intersection(article.tags).sorted()
            return shared.isEmpty ? nil : RelatedArticle(article: article, tags: shared)
        }.sorted {
            $0.tags.count == $1.tags.count ? $0.id < $1.id : $0.tags.count > $1.tags.count
        }.prefix(max(0, limit)))
    }
    static func programs(articleIDs: Set<String>, audio: AudioIndex) -> [PlaylistManifest] {
        let tracks = Set(audio.tracks.filter { articleIDs.contains($0.manifest.articleID) }.map(\.id))
        return (audio.programs ?? []).filter { !tracks.isDisjoint(with: $0.trackIDs) }
    }
}
