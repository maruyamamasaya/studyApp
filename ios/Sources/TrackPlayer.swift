import Foundation
import Combine
import AVFoundation
import MediaPlayer

@MainActor final class TrackPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var track: AudioTrack?
    @Published private(set) var playing = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var error: String?
    @Published private(set) var radio: RadioSession?
    @Published var speed: Float = 1 { didSet { narration?.rate = speed; updateInfo() } }
    @Published var bgmEnabled = true { didSet { syncBGM() } }
    @Published var bgmVolume: Float = 0.12 { didSet { bgm?.volume = bgmVolume } }
    private let library: AudioLibraryModel
    private var narration: AVAudioPlayer?
    private var bgm: AVAudioPlayer?
    private var interval: AVAudioPlayer?
    private var pulse: Timer?
    private var ticks = 0
    private var observers: [NSObjectProtocol] = []
    private var libraryChanges: AnyCancellable?
    init(library: AudioLibraryModel) {
        self.library = library
        super.init()
        radio = library.index.radio
        libraryChanges = library.$index.dropFirst().sink { [weak self] _ in
            Task { @MainActor in self?.refreshTrack() }
        }
        let remote = MPRemoteCommandCenter.shared()
        remote.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.resume() }; return .success }
        remote.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.pause() }; return .success }
        remote.nextTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.nextTrack() }; return .success }
        remote.previousTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.previousTrack() }; return .success }
        remote.skipForwardCommand.preferredIntervals = [15]
        remote.skipBackwardCommand.preferredIntervals = [15]
        remote.skipForwardCommand.addTarget { [weak self] _ in Task { @MainActor in self?.skip(15) }; return .success }
        remote.skipBackwardCommand.addTarget { [weak self] _ in Task { @MainActor in self?.skip(-15) }; return .success }
        remote.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let time = event.positionTime
            Task { @MainActor in self?.seek(time) }
            return .success
        }
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            if let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
               value == AVAudioSession.InterruptionType.began.rawValue { Task { @MainActor in self?.pause() } }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            if let value = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
               value == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { Task { @MainActor in self?.pause() } }
        })
        pulse = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let narration = self.narration, self.radio?.phase != .interval { self.position = narration.currentTime }
                self.ticks += 1
                if self.playing && self.ticks % 5 == 0 { self.savePosition() }
                self.updateInfo()
            }
        }
    }
    func play(_ selected: AudioTrack) {
        pause()
        radio = nil; interval = nil; bgm = nil
        loadTrack(selected, position: selected.positionSeconds)
    }
    func playProgram(_ program: PlaylistManifest, restart: Bool = false) {
        pause()
        let saved = library.index.radio
        if !restart, let saved, saved.playlist.id == program.id, saved.phase != .completed { radio = saved }
        else { radio = RadioSession(playlist: program) }
        bgm = nil; interval = nil
        loadRadioCurrent()
    }
    private func loadRadioCurrent() {
        guard let radio, radio.phase != .completed,
              let selected = library.index.tracks.first(where: { $0.id == radio.trackID }) else {
            pause(); error = "番組のトラックを再生できません。音声を同期してください。"; return
        }
        if radio.phase == .interval {
            track = selected; narration = nil; position = 0; duration = 0
            resume()
        } else { loadTrack(selected, position: radio.positionSeconds) }
    }
    private func loadTrack(_ selected: AudioTrack, position start: Double) {
        narration?.stop(); interval?.stop(); interval = nil
        narration = nil; track = nil; position = 0; duration = 0
        do {
            let audio = try AVAudioPlayer(contentsOf: library.storage.url(selected.localFile))
            audio.delegate = self
            audio.enableRate = true; audio.rate = speed
            audio.currentTime = min(start, audio.duration)
            narration = audio; track = selected; duration = audio.duration
            try prepareBGM()
            resume()
        } catch { pause(); self.error = error.localizedDescription }
    }
    func resume() {
        if let radio, radio.phase == .completed { return }
        if narration == nil, radio?.phase == .narration { loadRadioCurrent(); return }
        guard narration != nil || radio?.phase == .interval else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            try prepareBGM()
            if radio?.phase == .interval {
                if interval == nil {
                    interval = try AVAudioPlayer(data: RadioSession.silence(seconds: radio?.remainingGap ?? 0))
                    interval?.delegate = self
                }
                guard interval?.play() == true else { throw ReaderError.message("インターバルを再生できませんでした。") }
            } else if let narration {
                if narration.currentTime >= narration.duration { narration.currentTime = 0 }
                guard narration.play() else { throw ReaderError.message("音声を再生できませんでした。") }
                position = narration.currentTime
            }
            playing = true
            syncBGM(); updateInfo()
        } catch { pause(); self.error = error.localizedDescription }
    }
    func pause() {
        narration?.pause(); interval?.pause(); bgm?.pause(); playing = false
        position = narration?.currentTime ?? position
        savePosition(); updateInfo()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func seek(_ seconds: Double) {
        guard radio?.phase != .interval, let narration, seconds.isFinite else { return }
        narration.currentTime = min(max(0, seconds), duration)
        position = narration.currentTime; savePosition(); updateInfo()
    }
    func skip(_ seconds: Double) { seek(position + seconds) }
    func savePosition() {
        if var current = radio {
            if current.phase == .interval, let interval {
                current.remainingGap = max(0, interval.duration - interval.currentTime)
            } else if current.phase == .narration {
                if let track, library.index.tracks.first(where: { $0.id == track.id })?.localFile != track.localFile {
                    current.positionSeconds = 0
                } else { current.positionSeconds = narration?.currentTime ?? current.positionSeconds }
            }
            radio = current
            library.saveRadio(current)
        }
        if let track, library.index.tracks.first(where: { $0.id == track.id })?.localFile == track.localFile {
            library.savePosition(narration?.currentTime ?? position, id: track.id)
        }
    }
    func nextTrack() {
        guard var current = radio else { return }
        pause(); current.next(); radio = current
        interval?.stop(); interval = nil
        if current.phase == .completed { finishProgram() } else { loadRadioCurrent() }
    }
    func previousTrack() {
        guard var current = radio else { return }
        pause(); current.previous(); radio = current
        interval?.stop(); interval = nil; loadRadioCurrent()
    }
    private func finishProgram() {
        pause(); narration?.stop(); interval?.stop(); bgm?.stop(); interval = nil
        savePosition(); updateInfo()
    }
    private func prepareBGM() throws {
        if bgm == nil, let filename = library.index.bgmFile {
            bgm = try AVAudioPlayer(contentsOf: library.storage.url(filename))
            bgm?.numberOfLoops = -1; bgm?.volume = bgmVolume
        }
    }
    private func refreshTrack() {
        guard let track, let updated = library.index.tracks.first(where: { $0.id == track.id }) else { return }
        if updated.localFile != track.localFile {
            pause()
            narration = nil; bgm = nil; self.track = nil; position = 0; duration = 0
            interval?.stop(); interval = nil
            updateInfo()
            error = "音声が更新されました。一覧から新しい音声を再生してください。"
        } else if updated.manifest != track.manifest {
            self.track = updated
            updateInfo()
        }
    }
    private func syncBGM() {
        if playing && bgmEnabled { bgm?.play() } else { bgm?.pause() }
    }
    private func updateInfo() {
        let remote = MPRemoteCommandCenter.shared()
        remote.nextTrackCommand.isEnabled = radio?.hasNext == true
        remote.previousTrackCommand.isEnabled = radio != nil
        guard let track else { MPNowPlayingInfoCenter.default().nowPlayingInfo = nil; return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: track.manifest.title,
            MPMediaItemPropertyArtist: radio?.phase == .interval ? "インターバル" : track.manifest.voice,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: narration?.currentTime ?? position,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? speed : 0
        ]
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.interval === player {
                guard flag, var current = self.radio else {
                    self.pause(); self.error = "インターバルの再生が正常に完了しませんでした。"; return
                }
                self.interval = nil; current.next(); self.radio = current
                self.loadRadioCurrent(); self.savePosition(); return
            }
            guard self.narration === player else { return }
            guard flag else { self.pause(); self.error = "音声の再生が正常に完了しませんでした。"; return }
            if var current = self.radio {
                self.library.savePosition(0, id: current.trackID)
                current.finishedNarration(); self.radio = current
                if current.phase == .completed { self.finishProgram() }
                else if current.phase == .interval { self.resume(); self.savePosition() }
                else { self.loadRadioCurrent(); self.savePosition() }
            } else { self.pause(); self.seek(0) }
        }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let message = error?.localizedDescription ?? "音声の読み込みに失敗しました。"
        Task { @MainActor [weak self] in
            guard let self, self.narration === player || self.interval === player else { return }
            self.pause(); self.error = message
        }
    }
}
