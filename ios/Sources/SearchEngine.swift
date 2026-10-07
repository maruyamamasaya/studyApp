import Foundation

enum SearchEngine {
    struct Results {
        var articles: [Article] = []
        var tracks: [AudioTrack] = []
        var programs: [PlaylistManifest] = []
    }
    static func results(articles sourceArticles: [Article], audio: AudioIndex, records: StudyBackup, search: SearchConditions, bodies: [String: String] = [:], bodyQuery: String = "") -> Results {
        let keyword = search.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasArticleFilters = !search.tag.isEmpty || !search.folder.isEmpty || search.favorites || search.collection != nil || search.audioOnly
        let articleByID = Dictionary(uniqueKeysWithValues: sourceArticles.map { ($0.id, $0) })
        let trackByID = Dictionary(uniqueKeysWithValues: audio.tracks.map { ($0.id, $0) })
        let audioArticles = Set(audio.tracks.map { $0.manifest.articleID })
        let favorites = Set(records.favorites ?? [])
        let collection = records.collections?.first { $0.id == search.collection }
        let collectionIDs = Set(collection?.articleIDs ?? [])
        func included(_ article: Article) -> Bool {
            ArticleDiscovery.inFolder(article, search.folder) &&
            (search.tag.isEmpty || article.tags.contains(search.tag)) &&
            (!search.favorites || favorites.contains(article.id)) &&
            (search.collection == nil || collectionIDs.contains(article.id)) &&
            (!search.audioOnly || audioArticles.contains(article.id))
        }
        func matches(_ texts: [String]) -> Bool {
            keyword.isEmpty || texts.contains { $0.localizedCaseInsensitiveContains(keyword) }
        }
        func stateMatches(_ complete: Bool) -> Bool {
            search.state == "すべて" || (search.state == "完了" ? complete : !complete)
        }
        func metadata(_ article: Article?) -> [String] {
            article.map { [$0.title] + $0.tags + $0.aliases } ?? []
        }
        let articles = sourceArticles.filter { article in
            included(article) && stateMatches(records.progress[article.id]?.completed == true) &&
            (matches(metadata(article)) || (!keyword.isEmpty && bodyQuery == keyword &&
             bodies[Library.cacheKey(article)]?.localizedCaseInsensitiveContains(keyword) == true))
        }
        let tracks = audio.tracks.filter { track in
            let article = articleByID[track.manifest.articleID]
            return (!hasArticleFilters || article.map(included) == true) && stateMatches(track.isListened) &&
            matches([track.manifest.title, track.manifest.voice, track.script ?? ""] + metadata(article))
        }
        let programs = (audio.programs ?? []).filter { program in
            let members = program.trackIDs.compactMap { trackByID[$0] }
            let complete = !program.trackIDs.isEmpty && members.filter(\.isListened).count == program.trackIDs.count
            return (!hasArticleFilters || members.contains { articleByID[$0.manifest.articleID].map(included) == true }) &&
            stateMatches(complete) && matches([program.title] + members.flatMap {
                [$0.manifest.title] + metadata(articleByID[$0.manifest.articleID])
            })
        }
        let sortedArticles: [Article]
        if search.order == "タイトル" { sortedArticles = articles.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending } }
        else if search.order == "新しい順" { sortedArticles = articles.sorted { $0.created == $1.created ? $0.id < $1.id : $0.created > $1.created } }
        else { sortedArticles = articles }
        let sortedTracks = search.order == "タイトル" ? tracks.sorted { $0.manifest.title.localizedStandardCompare($1.manifest.title) == .orderedAscending } : tracks
        let sortedPrograms = search.order == "タイトル" ? programs.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending } : programs
        return Results(articles: sortedArticles, tracks: sortedTracks, programs: sortedPrograms)
    }
}
