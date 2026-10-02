import XCTest
@testable import StudyApp

final class RadioSessionTests: XCTestCase {
    private func program(gap: Double = 3) -> PlaylistManifest {
        PlaylistManifest(schemaVersion: 1, playlistID: UUID(), title: "RAG入門", trackIDs: [UUID(), UUID(), UUID()], gapSeconds: gap)
    }
    func testOrderAndIntervalAndFinish() {
        let p = program()
        var state = RadioSession(playlist: p)
        XCTAssertEqual(state.trackID, p.trackIDs[0])
        state.finishedNarration()
        XCTAssertEqual(state.phase, .interval)
        XCTAssertEqual(state.remainingGap, 3)
        state.next()
        XCTAssertEqual(state.trackID, p.trackIDs[1])
        state.finishedNarration(); state.next(); state.finishedNarration()
        XCTAssertEqual(state.phase, .completed)
        XCTAssertFalse(state.hasNext)
    }
    func testZeroIntervalImmediatelyAdvances() {
        var state = RadioSession(playlist: program(gap: 0))
        state.finishedNarration()
        XCTAssertEqual(state.index, 1)
        XCTAssertEqual(state.phase, .narration)
    }
    func testResumePreservesOrderPositionAndRemainingInterval() throws {
        var state = RadioSession(playlist: program())
        state.positionSeconds = 42
        var restored = try JSONDecoder().decode(RadioSession.self, from: JSONEncoder().encode(state)).validated()
        XCTAssertEqual(restored, state)
        restored.finishedNarration(); restored.remainingGap = 1.25
        let interval = try JSONDecoder().decode(RadioSession.self, from: JSONEncoder().encode(restored)).validated()
        XCTAssertEqual(interval.phase, .interval)
        XCTAssertEqual(interval.remainingGap, 1.25)
        XCTAssertEqual(interval.playlist.trackIDs, state.playlist.trackIDs)
    }
    func testPreviousAndNextResetPosition() {
        var state = RadioSession(playlist: program())
        state.positionSeconds = 23; state.next()
        XCTAssertEqual(state.positionSeconds, 0)
        state.previous(); XCTAssertEqual(state.index, 0)
    }
    func testInvalidProgramAndCursorAreRejected() {
        XCTAssertThrowsError(try program(gap: 11).validated())
        var state = RadioSession(playlist: program()); state.index = 99
        XCTAssertThrowsError(try state.validated())
        let id = UUID()
        XCTAssertThrowsError(try PlaylistManifest(schemaVersion: 1, playlistID: UUID(), title: "重複", trackIDs: [id, id], gapSeconds: 3).validated())
    }
    func testSilentAudioContainsExactIntervalFrames() {
        let data = RadioSession.silence(seconds: 0.5)
        XCTAssertEqual(String(data: data.prefix(4), encoding: .utf8), "RIFF")
        XCTAssertEqual(data.count, 44 + 8000)
    }
}
