import Foundation

struct PlaylistManifest: Codable, Equatable, Identifiable {
    var id: UUID { playlistID }
    let schemaVersion: Int
    let playlistID: UUID
    let title: String
    let trackIDs: [UUID]
    let gapSeconds: Double
    func validated(allowEmpty: Bool = false) throws -> PlaylistManifest {
        guard schemaVersion == 1, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (allowEmpty || !trackIDs.isEmpty), Set(trackIDs).count == trackIDs.count,
              gapSeconds.isFinite, (0...10).contains(gapSeconds) else { throw ReaderError.message("番組の管理JSONが不正です。") }
        return self
    }
}

// 再生時点の順番を保持し、途中で制作側が順番を変えても現在の番組を飛ばさない。
struct RadioSession: Codable, Equatable {
    enum Phase: String, Codable { case narration, interval, completed }
    let playlist: PlaylistManifest
    var index = 0
    var phase: Phase = .narration
    var positionSeconds: Double = 0
    var remainingGap: Double = 0
    var trackID: UUID { playlist.trackIDs[index] }
    var hasNext: Bool { index + 1 < playlist.trackIDs.count }

    func validated() throws -> RadioSession {
        _ = try playlist.validated()
        guard playlist.trackIDs.indices.contains(index), positionSeconds.isFinite, positionSeconds >= 0,
              remainingGap.isFinite, (0...10).contains(remainingGap),
              phase != .interval || hasNext else { throw ReaderError.invalid }
        return self
    }
    mutating func finishedNarration() {
        positionSeconds = 0
        guard hasNext else { phase = .completed; remainingGap = 0; return }
        if playlist.gapSeconds == 0 { next() }
        else { phase = .interval; remainingGap = playlist.gapSeconds }
    }
    mutating func next() {
        guard hasNext else { phase = .completed; remainingGap = 0; return }
        index += 1; phase = .narration; positionSeconds = 0; remainingGap = 0
    }
    mutating func previous() {
        index = max(0, index - 1); phase = .narration; positionSeconds = 0; remainingGap = 0
    }
    // 無音の実音声を再生することで、BGMがOFFでもバックグラウンドで区間を進める。
    static func silence(seconds: Double) -> Data {
        let count = UInt32(max(1.0 / 8000, min(10, seconds)) * 8000) * 2
        var data = Data()
        func text(_ value: String) { data.append(contentsOf: value.utf8) }
        func integer(_ value: UInt32, bytes: Int) {
            for offset in 0..<bytes { data.append(UInt8((value >> (offset * 8)) & 255)) }
        }
        text("RIFF"); integer(count + 36, bytes: 4); text("WAVEfmt ")
        integer(16, bytes: 4); integer(1, bytes: 2); integer(1, bytes: 2)
        integer(8000, bytes: 4); integer(16000, bytes: 4); integer(2, bytes: 2); integer(16, bytes: 2)
        text("data"); integer(count, bytes: 4); data.append(Data(repeating: 0, count: Int(count)))
        return data
    }
}
