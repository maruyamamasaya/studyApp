import Foundation
import Combine
import AVFoundation
import CryptoKit

// 制作側とアプリ間の受け入れ契約。trackIDは制作物、articleIDは元記事を識別する。
struct TrackManifest: Codable, Equatable {
    let schemaVersion: Int
    let trackID: UUID
    let articleID: String
    let title: String
    let voice: String
    let audioFile: String
    let scriptFile: String?
    let sourceContentHash: String?

    func validated() throws -> TrackManifest {
        guard schemaVersion == 1, Catalog.matches(articleID, "^[0-9]{8}-[0-9]{6}$"),
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              AudioLibrary.safeFilename(audioFile),
              scriptFile.map(AudioLibrary.safeFilename) ?? true,
              sourceContentHash.map({ Catalog.matches($0, "^[0-9a-f]{64}$") }) ?? true
        else { throw ReaderError.message("音声の管理JSONが不正です。") }
        return self
    }
}

struct AudioTrack: Codable, Identifiable {
    var id: UUID { manifest.trackID }
    let manifest: TrackManifest
    let localFile: String
    let script: String?
    var audioHash: String? = nil
    var positionSeconds: Double = 0
    var listened: Bool? = nil
    var isListened: Bool { listened == true }
}
struct AudioIndex: Codable {
    var schemaVersion = 1
    var tracks: [AudioTrack] = []
    var bgmFile: String?
    var programs: [PlaylistManifest]? = nil
    var editedProgramIDs: [UUID]? = nil
    var deletedProgramIDs: [UUID]? = nil
    var radio: RadioSession? = nil
    var gapOverrides: [String: Double]? = nil
    func listenedCount(in program: PlaylistManifest) -> Int {
        let completed = Set(tracks.filter(\.isListened).map(\.id))
        return program.trackIDs.filter { completed.contains($0) }.count
    }
    func validated() throws -> AudioIndex {
        guard schemaVersion == 1, Set(tracks.map(\.id)).count == tracks.count,
              bgmFile.map(AudioLibrary.safeFilename) ?? true else { throw ReaderError.invalid }
        for track in tracks {
            _ = try track.manifest.validated()
            guard AudioLibrary.safeFilename(track.localFile), track.positionSeconds.isFinite,
                  track.positionSeconds >= 0 else { throw ReaderError.invalid }
        }
        let programs = self.programs ?? []
        guard Set(programs.map(\.id)).count == programs.count else { throw ReaderError.invalid }
        for program in programs { _ = try program.validated(allowEmpty: true) }
        let edited = editedProgramIDs ?? []
        let deleted = deletedProgramIDs ?? []
        guard Set(edited).count == edited.count, Set(deleted).count == deleted.count,
              Set(edited).isSubset(of: Set(programs.map(\.id))),
              Set(deleted).isDisjoint(with: Set(programs.map(\.id))) else { throw ReaderError.invalid }
        if let radio { _ = try radio.validated() }
        guard (gapOverrides ?? [:]).allSatisfy({ UUID(uuidString: $0.key) != nil && $0.value.isFinite && (0...10).contains($0.value) }) else { throw ReaderError.invalid }
        return self
    }
}

struct ImportedAudioFile: Sendable {
    let name: String
    let data: Data
}

enum AudioImport {
    static func readFolder(_ folder: URL) throws -> [ImportedAudioFile] {
        let granted = folder.startAccessingSecurityScopedResource()
        defer { if granted { folder.stopAccessingSecurityScopedResource() } }
        let contents = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: .skipsHiddenFiles)
        let jsonURLs = contents.filter { $0.lastPathComponent.lowercased().hasSuffix(".track.json") || $0.lastPathComponent.lowercased().hasSuffix(".playlist.json") }
        if jsonURLs.isEmpty, contents.contains(where: { AudioLibrary.extensions.contains($0.pathExtension.lowercased()) }) {
            throw ReaderError.message("音声と一緒に.track.jsonも制作ツールから出力してください。")
        }
        let root = folder.resolvingSymlinksInPath().standardizedFileURL.path + "/"
        guard jsonURLs.allSatisfy({ $0.resolvingSymlinksInPath().standardizedFileURL.path.hasPrefix(root) }) else { throw ReaderError.invalid }
        guard jsonURLs.count <= 200 else { throw ReaderError.message("管理JSONは200ファイルまでにしてください。") }
        let jsonFiles = try read(jsonURLs, limit: 200)
        var names = Set<String>()
        for file in jsonFiles {
            if file.name.lowercased().hasSuffix(".playlist.json") {
                _ = try JSONDecoder().decode(PlaylistManifest.self, from: file.data).validated()
                continue
            }
            let manifest = try JSONDecoder().decode(TrackManifest.self, from: file.data).validated()
            names.insert(manifest.audioFile)
            if let script = manifest.scriptFile { names.insert(script) }
        }
        // Symlink経由でも許可フォルダ外を読まない。
        let urls = try names.sorted().map { name -> URL in
            let url = folder.appendingPathComponent(name)
            guard url.resolvingSymlinksInPath().standardizedFileURL.path.hasPrefix(root) else { throw ReaderError.invalid }
            return url
        }
        let files = jsonFiles + (try read(urls, limit: 200))
        guard files.reduce(0, { $0 + $1.data.count }) <= 300_000_000 else { throw ReaderError.message("同期するフォルダは合計300MB以下にしてください。") }
        return files
    }
    // File Providerのアクセス権がある間に読み取る。外部URLを永続保存しない。
    static func read(_ urls: [URL], limit: Int = 8) throws -> [ImportedAudioFile] {
        guard urls.count <= limit else { throw ReaderError.message("取り込みファイル数の上限を超えています。") }
        var totalSize = 0
        return try urls.map { url in
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            var coordinationError: NSError?
            var result: Result<ImportedAudioFile, Error>?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
                result = Result {
                    let size = try readable.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 250_000_000 else { throw ReaderError.message("ファイルは250MB以下にしてください。") }
                    let data = try Data(contentsOf: readable)
                    totalSize += data.count
                    guard data.count <= 250_000_000, totalSize <= 300_000_000 else { throw ReaderError.message("取り込み容量の上限を超えました。1件ずつ取り込んでください。") }
                    return ImportedAudioFile(name: url.lastPathComponent, data: data)
                }
            }
            if let coordinationError { throw coordinationError }
            guard let result else { throw ReaderError.invalid }
            return try result.get()
        }
    }
}

// Foundationのみの永続層。ObservableObjectのMainActor側はAudioLibraryModelに分ける。
final class AudioLibrary {
    static let extensions = ["mp3", "m4a", "wav", "aac", "aif", "aiff", "caf"]
    private let directory: URL
    private(set) var index = AudioIndex()
    private var writable = true
    private(set) var loadError: String?
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StudyApp/audio")
        let file = self.directory.appendingPathComponent("index.v1.json")
        if FileManager.default.fileExists(atPath: file.path) {
            do { index = try JSONDecoder().decode(AudioIndex.self, from: Data(contentsOf: file)).validated() }
            catch { writable = false; loadError = "音声一覧が読み込めないため、既存ファイルを保護して取り込みを停止しています。" }
        }
    }
    static func safeFilename(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\\") &&
            !name.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }
    func url(_ filename: String) -> URL { directory.appendingPathComponent(filename) }
    private func save(_ next: AudioIndex) throws {
        guard writable else { throw ReaderError.message(loadError ?? "音声一覧を保存できません。") }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(next.validated()).write(to: url("index.v1.json"), options: .atomic)
        index = next
    }
    private func writeAudio(_ file: ImportedAudioFile, id: UUID) throws -> String {
        guard writable, Self.safeFilename(file.name),
              Self.extensions.contains((file.name as NSString).pathExtension.lowercased()) else { throw ReaderError.invalid }
        let player = try AVAudioPlayer(data: file.data)
        guard player.duration.isFinite && player.duration > 0 else { throw ReaderError.message("再生可能な音声ではありません。") }
        let filename = id.uuidString + "." + (file.name as NSString).pathExtension.lowercased()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard !FileManager.default.fileExists(atPath: url(filename).path) else { throw ReaderError.message("同じtrackIDの音声が既にあります。") }
        try file.data.write(to: url(filename), options: .atomic)
        return filename
    }
    // 全管理JSONを検証してから、一度の一覧保存で追加・差し替えを確定する。
    @discardableResult func importTracks(_ files: [ImportedAudioFile]) throws -> Int {
        guard writable else { throw ReaderError.message(loadError ?? "音声一覧を保存できません。") }
        return try importPrepared(Self.prepareTracks(files))
    }
    struct PreparedTracks {
        fileprivate let tracks: [(TrackManifest, ImportedAudioFile, String?, String)]
        fileprivate let programs: [PlaylistManifest]
    }
    // 保存状態を参照しない検証。同期の読取タスクで実行できる。
    static func prepareTracks(_ files: [ImportedAudioFile]) throws -> PreparedTracks {
        guard Set(files.map(\.name)).count == files.count else { throw ReaderError.message("同じ名前のファイルが複数あります。") }
        let manifests = try files.filter { $0.name.lowercased().hasSuffix(".track.json") }
            .map { try JSONDecoder().decode(TrackManifest.self, from: $0.data).validated() }
        let programs = try files.filter { $0.name.lowercased().hasSuffix(".playlist.json") }
            .map { try JSONDecoder().decode(PlaylistManifest.self, from: $0.data).validated() }
        if manifests.isEmpty && programs.isEmpty {
            guard files.isEmpty else { throw ReaderError.message("管理JSONがありません。") }
            return PreparedTracks(tracks: [], programs: [])
        }
        guard Set(manifests.map(\.trackID)).count == manifests.count else { throw ReaderError.message("フォルダ内に重複したtrackIDがあります。") }
        guard Set(programs.map(\.id)).count == programs.count else { throw ReaderError.message("番組IDが重複しています。") }
        var prepared: [(TrackManifest, ImportedAudioFile, String?, String)] = []
        for manifest in manifests {
            guard let audio = files.first(where: { $0.name == manifest.audioFile }),
                  Self.extensions.contains((audio.name as NSString).pathExtension.lowercased())
            else { throw ReaderError.message("指定された音声が見つかりません: \(manifest.audioFile)") }
            let decoded = try AVAudioPlayer(data: audio.data)
            guard decoded.duration.isFinite && decoded.duration > 0 else { throw ReaderError.invalid }
            var script: String?
            if let name = manifest.scriptFile {
                guard let file = files.first(where: { $0.name == name }), let text = String(data: file.data, encoding: .utf8)
                else { throw ReaderError.message("指定されたUTF-8の台本がありません: \(name)") }
                script = text
            }
            let hash = SHA256.hash(data: audio.data).map { String(format: "%02x", $0) }.joined()
            prepared.append((manifest, audio, script, hash))
        }
        return PreparedTracks(tracks: prepared, programs: programs)
    }
    @discardableResult func importPrepared(_ batch: PreparedTracks) throws -> Int {
        guard writable else { throw ReaderError.message(loadError ?? "音声一覧を保存できません。") }
        let prepared = batch.tracks
        let programs = batch.programs
        let available = Set(index.tracks.map(\.id) + prepared.map { $0.0.trackID })
        guard programs.allSatisfy({ Set($0.trackIDs).isSubset(of: available) }) else { throw ReaderError.message("番組に指定されたトラックがありません。") }
        for (manifest, _, _, _) in prepared {
            if let old = index.tracks.first(where: { $0.id == manifest.trackID }), old.manifest.articleID != manifest.articleID {
                throw ReaderError.message("既存trackIDの記事IDは変更できません。別記事の音声には新しいtrackIDを付けてください。")
            }
        }
        var next = index
        var written: [String] = []
        var changed = 0
        do {
            for (manifest, audio, script, hash) in prepared {
                let oldIndex = next.tracks.firstIndex(where: { $0.id == manifest.trackID })
                let old = oldIndex.map { next.tracks[$0] }
                let sameAudio = old?.audioHash == hash
                if sameAudio, old?.manifest == manifest, old?.script == script { continue }
                let filename: String
                if sameAudio, let old { filename = old.localFile }
                else {
                    // trackIDは維持し、ローカル実体だけ新しいファイルにして失敗時も旧音声を保護する。
                    filename = try writeAudio(audio, id: UUID())
                    written.append(filename)
                }
                let track = AudioTrack(manifest: manifest, localFile: filename, script: script,
                    audioHash: hash, positionSeconds: sameAudio ? (old?.positionSeconds ?? 0) : 0,
                    listened: sameAudio ? old?.listened : nil)
                if let oldIndex { next.tracks[oldIndex] = track } else { next.tracks.append(track) }
                changed += 1
            }
            for incoming in programs {
                if (next.editedProgramIDs ?? []).contains(incoming.id) ||
                    (next.deletedProgramIDs ?? []).contains(incoming.id) { continue }
                let program = PlaylistManifest(schemaVersion: incoming.schemaVersion, playlistID: incoming.id,
                    title: incoming.title, trackIDs: incoming.trackIDs,
                    gapSeconds: next.gapOverrides?[incoming.id.uuidString] ?? incoming.gapSeconds)
                var list = next.programs ?? []
                if let i = list.firstIndex(where: { $0.id == program.id }) {
                    if list[i] == program { continue }
                    list[i] = program
                } else { list.append(program) }
                next.programs = list; changed += 1
            }
            if changed > 0 { try save(next) }
            return changed
        } catch {
            for filename in written { try? FileManager.default.removeItem(at: url(filename)) }
            throw error
        }
    }
    // 個人編集は番組全体を端末側優先にする。再生スナップショットは変更しない。
    @discardableResult func createProgram(title: String) throws -> UUID {
        let id = UUID()
        try updateProgram(PlaylistManifest(schemaVersion: 1, playlistID: id,
            title: title, trackIDs: [], gapSeconds: 3), creating: true)
        return id
    }
    func updateProgram(_ program: PlaylistManifest, creating: Bool = false) throws {
        let title = program.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = PlaylistManifest(schemaVersion: program.schemaVersion, playlistID: program.id,
            title: title, trackIDs: program.trackIDs, gapSeconds: program.gapSeconds)
        _ = try value.validated(allowEmpty: true)
        guard Set(value.trackIDs).isSubset(of: Set(index.tracks.map(\.id))) else { throw ReaderError.invalid }
        var next = index
        var list = next.programs ?? []
        if let i = list.firstIndex(where: { $0.id == value.id }) { list[i] = value }
        else {
            guard creating, !(next.deletedProgramIDs ?? []).contains(value.id) else { throw ReaderError.invalid }
            list.append(value)
        }
        next.programs = list
        var edited = next.editedProgramIDs ?? []
        if !edited.contains(value.id) { edited.append(value.id) }
        next.editedProgramIDs = edited
        try save(next)
    }
    func deleteProgram(_ id: UUID) throws {
        var next = index
        guard (next.programs ?? []).contains(where: { $0.id == id }) else { throw ReaderError.invalid }
        next.programs?.removeAll { $0.id == id }
        next.editedProgramIDs?.removeAll { $0 == id }
        var deleted = next.deletedProgramIDs ?? []
        if !deleted.contains(id) { deleted.append(id) }
        next.deletedProgramIDs = deleted
        next.gapOverrides?.removeValue(forKey: id.uuidString)
        try save(next)
    }
    func reorderPrograms(_ ids: [UUID]) throws {
        let programs = index.programs ?? []
        guard ids.count == programs.count, Set(ids) == Set(programs.map(\.id)) else { throw ReaderError.invalid }
        var next = index
        next.programs = ids.compactMap { id in programs.first { $0.id == id } }
        try save(next)
    }
    func importBGM(_ file: ImportedAudioFile) throws {
        let filename = try writeAudio(file, id: UUID())
        do { var next = index; next.bgmFile = filename; try save(next) }
        catch { try? FileManager.default.removeItem(at: url(filename)); throw error }
        // 前のBGMは取り込み成功後にのみ削除してもよいが、初期版では保持する。
    }
    func position(_ seconds: Double, trackID: UUID) throws {
        var next = index
        guard let i = next.tracks.firstIndex(where: { $0.id == trackID }), seconds.isFinite else { return }
        next.tracks[i].positionSeconds = max(0, seconds)
        try save(next)
    }
    func setListened(_ value: Bool, trackID: UUID, expectedFile: String? = nil) throws {
        var next = index
        guard let i = next.tracks.firstIndex(where: { $0.id == trackID }),
              expectedFile == nil || next.tracks[i].localFile == expectedFile else { return }
        guard next.tracks[i].isListened != value else { return }
        next.tracks[i].listened = value
        try save(next)
    }
    func saveRadio(_ radio: RadioSession?) throws {
        var next = index; next.radio = radio; try save(next)
    }
    func setGap(_ seconds: Double, programID: UUID) throws {
        guard seconds.isFinite, (0...10).contains(seconds) else { throw ReaderError.invalid }
        var next = index
        var programs = next.programs ?? []
        guard let i = programs.firstIndex(where: { $0.id == programID }) else { return }
        let old = programs[i]
        programs[i] = PlaylistManifest(schemaVersion: old.schemaVersion, playlistID: old.id,
            title: old.title, trackIDs: old.trackIDs, gapSeconds: seconds)
        next.programs = programs
        var overrides = next.gapOverrides ?? [:]
        overrides[programID.uuidString] = seconds
        next.gapOverrides = overrides
        try save(next)
    }
}

@MainActor final class AudioLibraryModel: ObservableObject {
    let storage: AudioLibrary
    @Published private(set) var index: AudioIndex
    @Published var error: String?
    @Published private(set) var syncing = false
    @Published private(set) var folderName: String?
    @Published private(set) var syncMessage: String?
    private let defaults: UserDefaults
    private let bookmarkKey = "study.audioFolder.v1"
    init(storage: AudioLibrary = AudioLibrary(), defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.storage = storage; index = storage.index; error = storage.loadError
        if let bookmark = defaults.data(forKey: bookmarkKey) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &stale) {
                folderName = url.lastPathComponent
            }
        }
    }
    func refresh(folder selected: URL? = nil) async {
        guard !syncing else { return }
        guard selected != nil || defaults.data(forKey: bookmarkKey) != nil else { return }
        syncing = true
        defer { syncing = false }
        do {
            let folder: URL
            if let selected { folder = selected }
            else {
                var stale = false
                folder = try URL(resolvingBookmarkData: defaults.data(forKey: bookmarkKey)!, options: .withoutUI,
                    relativeTo: nil, bookmarkDataIsStale: &stale)
            }
            let access = folder.startAccessingSecurityScopedResource()
            defer { if access { folder.stopAccessingSecurityScopedResource() } }
            let bookmark = try folder.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            let batch = try await Task.detached {
                try AudioLibrary.prepareTracks(AudioImport.readFolder(folder))
            }.value
            let changed = try storage.importPrepared(batch)
            index = storage.index
            defaults.set(bookmark, forKey: bookmarkKey)
            folderName = folder.lastPathComponent
            syncMessage = "同期完了: \(changed)件更新"
            error = nil
        } catch { self.error = "音声を同期できませんでした。フォルダのアクセス権とダウンロード状態を確認してください。\(error.localizedDescription)" }
    }
    func importFiles(_ files: [ImportedAudioFile], bgm: Bool) throws {
        if bgm {
            guard files.count == 1 else { throw ReaderError.message("BGMは1ファイルを選んでください。") }
            try storage.importBGM(files[0])
        } else { try storage.importTracks(files) }
        index = storage.index
    }
    func editPrograms(_ operation: (AudioLibrary) throws -> Void) {
        do { try operation(storage); index = storage.index }
        catch { self.error = error.localizedDescription }
    }
    func savePosition(_ seconds: Double, id: UUID) {
        do { try storage.position(seconds, trackID: id); index = storage.index }
        catch { self.error = error.localizedDescription }
    }
    func setListened(_ value: Bool, id: UUID, expectedFile: String? = nil) {
        do { try storage.setListened(value, trackID: id, expectedFile: expectedFile); index = storage.index }
        catch { self.error = error.localizedDescription }
    }
    func saveRadio(_ radio: RadioSession?) {
        do { try storage.saveRadio(radio); index = storage.index }
        catch { self.error = error.localizedDescription }
    }
    func setGap(_ seconds: Double, programID: UUID) {
        do { try storage.setGap(seconds, programID: programID); index = storage.index }
        catch { self.error = error.localizedDescription }
    }
}
