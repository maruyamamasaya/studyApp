import Foundation
import Combine

struct ProgressRecord: Codable {
    var title: String
    var completed = false
    var lastViewedAt: Date?
}
struct StudySession: Codable, Identifiable {
    let id: UUID
    let articleId: String
    let startedAt: Date
    let durationSeconds: Double
}
struct StudyBackup: Codable {
    var schemaVersion = 1
    var progress: [String: ProgressRecord] = [:]
    var sessions: [StudySession] = []
    // Optional fields preserve decoding of existing version 1 backups.
    var favorites: [String]?
    var collections: [ArticleCollection]?

    func validated() throws -> StudyBackup {
        guard schemaVersion == 1, Set(sessions.map(\.id)).count == sessions.count,
              progress.keys.allSatisfy({ Catalog.matches($0, "^[0-9]{8}-[0-9]{6}$") }),
              sessions.allSatisfy({ Catalog.matches($0.articleId, "^[0-9]{8}-[0-9]{6}$") &&
                  $0.durationSeconds.isFinite && $0.durationSeconds >= 0 && $0.durationSeconds <= 86400 })
        else { throw ReaderError.message("バックアップの形式が不正です。") }
        let favorites = favorites ?? []
        let collections = collections ?? []
        guard Set(favorites).count == favorites.count,
              favorites.allSatisfy({ Catalog.matches($0, "^[0-9]{8}-[0-9]{6}$") }),
              Set(collections.map(\.id)).count == collections.count,
              collections.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                  $0.name.count <= 80 && Set($0.articleIDs).count == $0.articleIDs.count &&
                  $0.articleIDs.allSatisfy({ Catalog.matches($0, "^[0-9]{8}-[0-9]{6}$") }) })
        else { throw ReaderError.message("お気に入り・コレクションの形式が不正です。") }
        return self
    }
}

@MainActor final class StudyStore: ObservableObject {
    @Published private(set) var data = StudyBackup()
    @Published var error: String?
    private let file: URL
    private var writable = true

    init(file: URL? = nil) {
        self.file = file ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StudyApp/records.v1.json")
        if FileManager.default.fileExists(atPath: self.file.path) {
            do { data = try Self.decode(Data(contentsOf: self.file)) }
            catch { self.error = "記録を読み込めませんでした。元ファイルを保護するため保存を停止しています。\(error.localizedDescription)"; writable = false }
        }
    }
    static func decode(_ bytes: Data) throws -> StudyBackup {
        try JSONDecoder().decode(StudyBackup.self, from: bytes).validated()
    }
    func export() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(data)
    }
    private func persist(_ next: StudyBackup) throws {
        guard writable else { throw ReaderError.message("既存記録の読み込みエラーを解決してから保存してください。") }
        let bytes = try JSONEncoder().encode(next.validated())
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: file, options: .atomic)
        data = next
    }
    func restore(_ bytes: Data) throws {
        let next = try Self.decode(bytes)
        // 明示的な復元操作だけが、破損ファイルによる書き込み停止を解除できる。
        let previous = writable
        writable = true
        do { try persist(next); error = nil } catch { writable = previous; throw error }
    }
    func viewed(_ article: Article) {
        update { next in
            var record = next.progress[article.id] ?? ProgressRecord(title: article.title)
            record.title = article.title
            record.lastViewedAt = Date()
            next.progress[article.id] = record
        }
    }
    func toggle(_ article: Article) {
        update { next in
            var record = next.progress[article.id] ?? ProgressRecord(title: article.title)
            record.completed.toggle()
            next.progress[article.id] = record
        }
    }
    func add(_ session: StudySession) {
        update { next in
            if !next.sessions.contains(where: { $0.id == session.id }) { next.sessions.append(session) }
        }
    }
    private func update(_ mutation: (inout StudyBackup) -> Void) {
        var next = data
        mutation(&next)
        do { try persist(next) } catch { self.error = error.localizedDescription }
    }
    func seconds(for id: String) -> Double {
        data.sessions.filter { $0.articleId == id }.reduce(0) { $0 + $1.durationSeconds }
    }
    func isFavorite(_ id: String) -> Bool { (data.favorites ?? []).contains(id) }
    func toggleFavorite(_ id: String) {
        update { next in
            var ids = next.favorites ?? []
            if ids.contains(id) { ids.removeAll { $0 == id } } else { ids.append(id) }
            next.favorites = ids
        }
    }
    func createCollection(_ name: String) {
        let name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !name.isEmpty else { return }
        update { next in
            var collections = next.collections ?? []
            collections.append(ArticleCollection(id: UUID(), name: name, articleIDs: []))
            next.collections = collections
        }
    }
    func renameCollection(_ id: UUID, name: String) {
        let name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !name.isEmpty else { return }
        update { next in
            guard let index = next.collections?.firstIndex(where: { $0.id == id }) else { return }
            next.collections?[index].name = name
        }
    }
    func deleteCollection(_ id: UUID) {
        update { $0.collections?.removeAll { $0.id == id } }
    }
    func toggleMembership(_ articleID: String, collectionID: UUID) {
        update { next in
            guard let index = next.collections?.firstIndex(where: { $0.id == collectionID }) else { return }
            var ids = next.collections?[index].articleIDs ?? []
            if ids.contains(articleID) { ids.removeAll { $0 == articleID } } else { ids.append(articleID) }
            next.collections?[index].articleIDs = ids
        }
    }
}

struct ArticleCollection: Codable, Identifiable {
    let id: UUID
    var name: String
    var articleIDs: [String]
}

// 30秒ごとに区間を確定。時計変更に影響されないuptimeで経過時間を測る。
@MainActor final class StudyTimer {
    private var started: (date: Date, uptime: Double)?
    func start() {
        if started == nil { started = (Date(), ProcessInfo.processInfo.systemUptime) }
    }
    func flush(articleID: String, store: StudyStore, resume: Bool) {
        if let start = started {
            let duration = max(0, ProcessInfo.processInfo.systemUptime - start.uptime)
            store.add(StudySession(id: UUID(), articleId: articleID, startedAt: start.date, durationSeconds: duration))
        }
        started = nil
        if resume { start() }
    }
}
