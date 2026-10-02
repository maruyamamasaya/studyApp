import XCTest
@testable import StudyApp

final class AudioLibraryTests: XCTestCase {
    private func wav() -> Data {
        // 1秒の無音PCM。実ファイルを持たず、デコード可能な音声で保存経路を検証する。
        var data = Data()
        func text(_ value: String) { data.append(contentsOf: value.utf8) }
        func integer(_ value: UInt32, bytes: Int) {
            for shift in 0..<bytes { data.append(UInt8((value >> (shift * 8)) & 255)) }
        }
        text("RIFF"); integer(16036, bytes: 4); text("WAVEfmt ")
        integer(16, bytes: 4); integer(1, bytes: 2); integer(1, bytes: 2)
        integer(8000, bytes: 4); integer(16000, bytes: 4); integer(2, bytes: 2); integer(16, bytes: 2)
        text("data"); integer(16000, bytes: 4); data.append(Data(repeating: 0, count: 16000))
        return data
    }
    private func manifest(id: UUID = UUID(), file: String = "voice.wav", script: String? = "script.txt") -> TrackManifest {
        TrackManifest(schemaVersion: 1, trackID: id, articleID: "20261001-171535", title: "RAG音声版",
            voice: "VOICEVOX:四国めたん", audioFile: file, scriptFile: script, sourceContentHash: String(repeating: "a", count: 64))
    }
    private func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }

    func testManifestRejectsUnsafePaths() {
        for filename in ["../voice.wav", "/voice.wav", "sub/voice.wav", "sub\\voice.wav"] {
            XCTAssertThrowsError(try manifest(file: filename).validated())
        }
        XCTAssertNoThrow(try manifest().validated())
    }
    func testBundlePreservesIDsScriptAndResumePosition() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let library = AudioLibrary(directory: root)
        let m = manifest()
        let files = [ImportedAudioFile(name: "sample.track.json", data: try JSONEncoder().encode(m)),
                     ImportedAudioFile(name: "voice.wav", data: wav()),
                     ImportedAudioFile(name: "script.txt", data: Data("学習用の台本".utf8))]
        try library.importTracks(files)
        let track = try XCTUnwrap(library.index.tracks.first)
        XCTAssertEqual(track.id, m.trackID)
        XCTAssertEqual(track.manifest.articleID, m.articleID)
        XCTAssertEqual(track.script, "学習用の台本")
        XCTAssertEqual(try Data(contentsOf: library.url(track.localFile)), wav())
        try library.position(0.4, trackID: track.id)
        let restarted = AudioLibrary(directory: root)
        XCTAssertEqual(restarted.index.tracks.first?.positionSeconds, 0.4)
        XCTAssertEqual(try restarted.importTracks(files), 0)
        XCTAssertEqual(restarted.index.tracks.count, 1)
        XCTAssertEqual(restarted.index.tracks[0].positionSeconds, 0.4)
    }
    func testReplacementPreservesTrackAndArticleIDs() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let library = AudioLibrary(directory: root)
        let m = manifest(script: nil)
        let json = ImportedAudioFile(name: "sample.track.json", data: try JSONEncoder().encode(m))
        try library.importTracks([json, ImportedAudioFile(name: "voice.wav", data: wav())])
        let original = try XCTUnwrap(library.index.tracks.first)
        try library.position(0.4, trackID: m.trackID)
        var replacement = wav(); replacement[replacement.count - 1] = 1
        XCTAssertEqual(try library.importTracks([json, ImportedAudioFile(name: "voice.wav", data: replacement)]), 1)
        let updated = try XCTUnwrap(library.index.tracks.first)
        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.manifest.articleID, original.manifest.articleID)
        XCTAssertNotEqual(updated.localFile, original.localFile)
        XCTAssertEqual(updated.positionSeconds, 0)
        XCTAssertEqual(try Data(contentsOf: library.url(original.localFile)), wav())
        XCTAssertEqual(try Data(contentsOf: library.url(updated.localFile)), replacement)
    }
    func testExistingTrackCannotBeReassignedToAnotherArticle() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let library = AudioLibrary(directory: root)
        let m = manifest(script: nil)
        let audio = ImportedAudioFile(name: "voice.wav", data: wav())
        try library.importTracks([ImportedAudioFile(name: "sample.track.json", data: try JSONEncoder().encode(m)), audio])
        let changed = TrackManifest(schemaVersion: 1, trackID: m.trackID, articleID: "20261001-171536",
            title: m.title, voice: m.voice, audioFile: m.audioFile, scriptFile: nil, sourceContentHash: nil)
        XCTAssertThrowsError(try library.importTracks([ImportedAudioFile(name: "sample.track.json", data: try JSONEncoder().encode(changed)), audio]))
        XCTAssertEqual(library.index.tracks[0].manifest.articleID, m.articleID)
    }
    func testFolderScanAndBatchFailureAreAtomic() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let a = manifest(script: nil)
        try JSONEncoder().encode(a).write(to: source.appendingPathComponent("a.track.json"))
        try wav().write(to: source.appendingPathComponent("voice.wav"))
        let library = AudioLibrary(directory: root.appendingPathComponent("library"))
        try library.importTracks(AudioImport.readFolder(source))
        let oldFile = library.index.tracks[0].localFile
        let b = manifest(file: "missing.wav", script: nil)
        try JSONEncoder().encode(b).write(to: source.appendingPathComponent("b.track.json"))
        XCTAssertThrowsError(try library.importTracks(AudioImport.readFolder(source)))
        XCTAssertEqual(library.index.tracks.count, 1)
        XCTAssertEqual(library.index.tracks[0].localFile, oldFile)
    }
    func testIncompleteBundleDoesNotChangeIndex() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let library = AudioLibrary(directory: root)
        let json = ImportedAudioFile(name: "sample.track.json", data: try JSONEncoder().encode(manifest()))
        XCTAssertThrowsError(try library.importTracks([json]))
        XCTAssertThrowsError(try library.importTracks([json, ImportedAudioFile(name: "voice.wav", data: wav())]))
        XCTAssertTrue(library.index.tracks.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }
    func testCorruptIndexIsNeverOverwritten() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let index = root.appendingPathComponent("index.v1.json")
        let corrupt = Data("broken".utf8); try corrupt.write(to: index)
        let library = AudioLibrary(directory: root)
        XCTAssertThrowsError(try library.importBGM(ImportedAudioFile(name: "bgm.wav", data: wav())))
        XCTAssertEqual(try Data(contentsOf: index), corrupt)
    }
    func testBGMImportsAndBadAudioDoesNotReplaceIt() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let library = AudioLibrary(directory: root)
        try library.importBGM(ImportedAudioFile(name: "bgm.wav", data: wav()))
        let original = try XCTUnwrap(library.index.bgmFile)
        XCTAssertThrowsError(try library.importBGM(ImportedAudioFile(name: "bad.wav", data: Data("not audio".utf8))))
        XCTAssertEqual(library.index.bgmFile, original)
        XCTAssertEqual(AudioLibrary(directory: root).index.bgmFile, original)
    }
    func testProgramOrderAndRadioStatePersistWithGapOverride() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let library = AudioLibrary(directory: root)
        let a = manifest(script: nil)
        let b = manifest(file: "second.wav", script: nil)
        let p = PlaylistManifest(schemaVersion: 1, playlistID: UUID(), title: "番組", trackIDs: [b.trackID, a.trackID], gapSeconds: 3)
        let files = [ImportedAudioFile(name: "a.track.json", data: try JSONEncoder().encode(a)),
                     ImportedAudioFile(name: "b.track.json", data: try JSONEncoder().encode(b)),
                     ImportedAudioFile(name: "p.playlist.json", data: try JSONEncoder().encode(p)),
                     ImportedAudioFile(name: "voice.wav", data: wav()), ImportedAudioFile(name: "second.wav", data: wav())]
        try library.importTracks(files)
        try library.setGap(2, programID: p.id)
        var state = RadioSession(playlist: p); state.positionSeconds = 0.25
        try library.saveRadio(state)
        try library.importTracks(files)
        let restarted = AudioLibrary(directory: root)
        XCTAssertEqual(restarted.index.programs?.first?.trackIDs, [b.trackID, a.trackID])
        XCTAssertEqual(restarted.index.programs?.first?.gapSeconds, 2)
        XCTAssertEqual(restarted.index.radio, state)
    }
    func testMissingProgramTrackRejectsEntireBatch() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let library = AudioLibrary(directory: root)
        let a = manifest(script: nil)
        let p = PlaylistManifest(schemaVersion: 1, playlistID: UUID(), title: "欠落", trackIDs: [UUID()], gapSeconds: 3)
        let files = [ImportedAudioFile(name: "a.track.json", data: try JSONEncoder().encode(a)),
                     ImportedAudioFile(name: "p.playlist.json", data: try JSONEncoder().encode(p)),
                     ImportedAudioFile(name: "voice.wav", data: wav())]
        XCTAssertThrowsError(try library.importTracks(files))
        XCTAssertTrue(library.index.tracks.isEmpty)
    }
}
