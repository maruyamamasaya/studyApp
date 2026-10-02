import SwiftUI
import UniformTypeIdentifiers

@MainActor struct AudioView: View {
    var article: Article? = nil
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var audio: AudioLibraryModel
    @EnvironmentObject private var player: TrackPlayer
    @State private var importing = false
    @State private var choosingFolder = false
    @State private var busy = false
    @State private var message: String?
    private var tracks: [AudioTrack] {
        audio.index.tracks.filter { article == nil || $0.manifest.articleID == article?.id }
    }
    var body: some View {
        List {
            Section("取り込み") {
                if let folder = audio.folderName { Text("同期元: \(folder)") }
                Button(audio.folderName == nil ? "制作物フォルダを設定" : "制作物フォルダを変更") {
                    choosingFolder = true; importing = true
                }.disabled(busy || audio.syncing)
                Button("音声を同期") { Task { await audio.refresh() } }
                    .disabled(audio.folderName == nil || busy || audio.syncing)
                Button("BGMを選択") { choosingFolder = false; importing = true }.disabled(busy || audio.syncing)
                Text("管理JSONのtrackIDと記事IDで自動的に紐付きます。音声の差し替えも同期で反映します。")
                    .font(.caption).foregroundStyle(.secondary)
                if let status = audio.syncMessage { Text(status).font(.caption) }
                if audio.syncing { ProgressView("音声を同期中") }
                if busy { ProgressView("取り込み中") }
            }
            if article == nil {
                Section("番組") {
                    ForEach(audio.index.programs ?? []) { program in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(program.title).font(.headline)
                            Text("\(program.trackIDs.count)本 · 間隔\(Int(program.gapSeconds))秒").font(.caption)
                            Stepper("インターバル", value: Binding(get: {
                                audio.index.programs?.first(where: { $0.id == program.id })?.gapSeconds ?? program.gapSeconds
                            }, set: { audio.setGap($0, programID: program.id) }), in: 0...10, step: 1)
                            HStack {
                                Button("続きから聴く") { player.playProgram(program) }
                                Button("最初から") { player.playProgram(program, restart: true) }
                            }.buttonStyle(.borderless)
                            DisclosureGroup("再生順") {
                                ForEach(Array(program.trackIDs.enumerated()), id: \.element) { item in
                                    Text("\(item.offset + 1). \(audio.index.tracks.first(where: { $0.id == item.element })?.manifest.title ?? "未取得")")
                                }
                            }
                        }
                    }
                    if (audio.index.programs ?? []).isEmpty { Text("制作物フォルダに番組の管理JSONを追加してください。") }
                }
            }
            Section("保存した音声") {
                ForEach(tracks) { track in
                    VStack(alignment: .leading, spacing: 8) {
                        Button { player.play(track) } label: { Label(track.manifest.title, systemImage: "play.circle") }
                        Text(track.manifest.voice).font(.caption)
                        if let source = track.manifest.sourceContentHash,
                           let current = library.articles.first(where: { $0.id == track.manifest.articleID }), source != current.contentHash {
                            Text("元記事が更新されています").font(.caption).foregroundStyle(.orange)
                        }
                        if let script = track.script { DisclosureGroup("台本") { Text(script).textSelection(.enabled) } }
                    }
                }
                if tracks.isEmpty { Text("まだ音声がありません。") }
            }
            if let track = player.track {
                Section("再生中: \(track.manifest.title)") {
                    if let radio = player.radio {
                        Text("\(radio.playlist.title) · \(radio.index + 1)/\(radio.playlist.trackIDs.count)")
                        if radio.phase == .interval { Text("次のトラックまでインターバル") }
                        if radio.phase == .completed { Text("番組の再生が終了しました。") }
                        HStack {
                            Button("前のトラック") { player.previousTrack() }
                            Button("次のトラック") { player.nextTrack() }.disabled(!radio.hasNext)
                        }.buttonStyle(.borderless)
                    }
                    Slider(value: Binding(get: { player.position }, set: { player.seek($0) }), in: 0...max(1, player.duration))
                        .disabled(player.radio?.phase == .interval || player.radio?.phase == .completed)
                        .accessibilityLabel("再生位置")
                    Text("\(Int(player.position)) / \(Int(player.duration))秒")
                    HStack {
                        Button("15秒戻す") { player.skip(-15) }
                        Button(player.playing ? "一時停止" : "再生") { if player.playing { player.pause() } else { player.resume() } }
                        Button("15秒進む") { player.skip(15) }
                    }.buttonStyle(.borderless)
                    Picker("速度", selection: $player.speed) {
                        ForEach([Float(0.75), 1, 1.25, 1.5, 2], id: \.self) { Text("\(String(format: "%.2g", $0))倍").tag($0) }
                    }
                    Toggle("BGM", isOn: $player.bgmEnabled)
                    Slider(value: $player.bgmVolume, in: 0...0.5).accessibilityLabel("BGM音量")
                    if audio.index.bgmFile == nil { Text("BGMは未登録です。") }
                }
            }
        }
        .navigationTitle("聴く")
        .fileImporter(isPresented: $importing, allowedContentTypes: choosingFolder ? [.folder] : [.audio]) { result in
            let folder = choosingFolder
            busy = true
            Task {
                defer { busy = false }
                do {
                    let url = try result.get()
                    if folder { await audio.refresh(folder: url) }
                    else {
                        let files = try await Task.detached { try AudioImport.read([url]) }.value
                        try audio.importFiles(files, bgm: true)
                        message = "BGMを取り込みました。次の音声再生から使用します。"
                    }
                } catch { message = error.localizedDescription }
            }
        }
        .alert("音声", isPresented: Binding(get: { message != nil || player.error != nil || audio.error != nil }, set: { if !$0 { message = nil; player.error = nil; audio.error = nil } })) {
            Button("閉じる") { message = nil; player.error = nil; audio.error = nil }
        } message: { Text(message ?? player.error ?? audio.error ?? "") }
    }
}
