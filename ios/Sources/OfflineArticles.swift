import Foundation

actor OfflineArticles {
    let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("StudyApp/offline")
    }
    private func file(_ article: Article) -> URL { directory.appendingPathComponent(article.contentHash + ".md") }
    func catalog() throws -> Catalog? {
        let url = directory.appendingPathComponent("catalog.v1.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url)).validated()
    }
    func save(_ catalog: Catalog) throws {
        _ = try catalog.validated()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(catalog).write(to: directory.appendingPathComponent("catalog.v1.json"), options: .atomic)
    }
    func content(_ article: Article) throws -> String? {
        guard Catalog.matches(article.contentHash, "^[0-9a-f]{64}$") else { throw ReaderError.invalid }
        let url = file(article)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let text = try String(contentsOf: url, encoding: .utf8)
        guard ArticleClient.hash(text) == article.contentHash else { throw ReaderError.mismatch }
        return text
    }
    func save(_ text: String, for article: Article) throws {
        guard ArticleClient.hash(text) == article.contentHash else { throw ReaderError.mismatch }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try text.data(using: .utf8)!.write(to: file(article), options: .atomic)
    }
    func summary(articles: [Article]) throws -> (ids: Set<String>, bytes: Int64) {
        guard FileManager.default.fileExists(atPath: directory.path) else { return ([], 0) }
        var ids = Set<String>()
        for article in articles { if (try? content(article)) != nil { ids.insert(article.id) } }
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
        let bytes = try urls.reduce(Int64(0)) { $0 + Int64(try $1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) }
        return (ids, bytes)
    }
    func remove() throws {
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }
}
