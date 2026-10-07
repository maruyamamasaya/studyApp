import SwiftUI
import UniformTypeIdentifiers

@MainActor struct AudioView: View {
    @Environment(\.studyTheme) private var design
    @EnvironmentObject private var audio: AudioLibraryModel
    @EnvironmentObject private var player: TrackPlayer
    @State private var showPlayer = false
    var body: some View {
        List {
            Group {
                if let track = player.track, player.radio?.phase != .completed {
                    Section("続きから聴く") {
                        Button { player.resume(); showPlayer = true } label: {
                            Label(track.manifest.title, systemImage: "play.circle.fill")
                        }
                    }
                } else if let radio = audio.index.radio, radio.phase != .completed {
                    Section("続きから聴く") {
                        Button { player.playProgram(radio.playlist); showPlayer = true } label: {
                            Label(radio.playlist.title, systemImage: "play.circle.fill")
                        }
                    }
                }
                Section("音声一覧") {
                    ForEach(audio.index.tracks) { track in
                        Button { player.play(track); showPlayer = true } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Label(track.manifest.title, systemImage: "play.circle")
                                    .font(.subheadline.weight(.semibold))
                                HStack {
                                    Text(track.manifest.voice)
                                    if track.isListened { Label("聴取済み", systemImage: "checkmark.circle.fill") }
                                    else if track.positionSeconds > 0 { Text("途中") }
                                }.font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                        .contextMenu {
                            Button(track.isListened ? "未聴取に戻す" : "聴取済みにする") {
                                audio.setListened(!track.isListened, id: track.id)
                            }
                        }
                    }
                    if audio.index.tracks.isEmpty {
                        ContentUnavailableView {
                            Label("まだ音声がありません", systemImage: "headphones")
                        } description: {
                            Text("設定の「音声・同期」で制作物フォルダを選んでください。")
                        } actions: {
                            NavigationLink("音声・同期を開く") { AudioSettingsView() }
                        }
                    }
                }
                if audio.syncing { ProgressView("音声を同期中") }
                if let status = audio.syncMessage { Text(status).font(.caption).foregroundStyle(.secondary) }
            }.listRowBackground(design.surface)
        }
        .scrollContentBackground(.hidden)
        .background { StudyBackdrop() }
        .navigationTitle("聴く")
        .navigationDestination(isPresented: $showPlayer) { AudioPlayerView() }
        .toolbar {
            Button { Task { await audio.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                .disabled(audio.folderName == nil || audio.syncing).accessibilityLabel("音声を同期")
        }
    }
}

@MainActor struct ProgramsView: View {
    @Environment(\.studyTheme) private var design
    @EnvironmentObject private var audio: AudioLibraryModel
    @EnvironmentObject private var player: TrackPlayer
    @State private var showPlayer = false
    @State private var creating = false
    @State private var title = ""
    @State private var deleting: PlaylistManifest?
    var body: some View {
        List {
            Group {
                if let radio = audio.index.radio, radio.phase != .completed {
                    Section("続きから聴く") {
                        Button { player.playProgram(radio.playlist); showPlayer = true } label: {
                            Label(radio.playlist.title, systemImage: "play.circle.fill")
                        }
                    }
                }
                Section("番組一覧") {
                    ForEach(audio.index.programs ?? []) { program in
                        NavigationLink { ProgramDetailView(programID: program.id) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(program.title).font(.subheadline.weight(.semibold))
                                Text("\(program.trackIDs.count)本 · \(audio.index.listenedCount(in: program))/\(program.trackIDs.count)本 聴取済み")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                        .swipeActions {
                            Button("削除", role: .destructive) { deleting = program }
                        }
                        .contextMenu {
                            Button("削除", role: .destructive) { deleting = program }
                        }
                    }
                    .onMove { offsets, destination in
                        var ids = (audio.index.programs ?? []).map(\.id)
                        ids.move(fromOffsets: offsets, toOffset: destination)
                        audio.editPrograms { try $0.reorderPrograms(ids) }
                    }
                    if (audio.index.programs ?? []).isEmpty {
                        ContentUnavailableView("まだ番組がありません", systemImage: "play.rectangle",
                            description: Text("右上の＋から番組を作成できます。"))
                    }
                }
            }.listRowBackground(design.surface)
        }
        .scrollContentBackground(.hidden)
        .background { StudyBackdrop() }.navigationTitle("番組")
        .navigationDestination(isPresented: $showPlayer) { AudioPlayerView() }
        .toolbar {
            EditButton()
            Button { title = ""; creating = true } label: { Image(systemName: "plus") }
                .accessibilityLabel("番組を作成")
        }
        .alert("番組を作成", isPresented: $creating) {
            TextField("番組名", text: $title)
            Button("作成") { audio.editPrograms { try $0.createProgram(title: title) } }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("キャンセル", role: .cancel) {}
        }
        .alert("番組を削除", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("削除", role: .destructive) {
                if let deleting { audio.editPrograms { try $0.deleteProgram(deleting.id) } }
                deleting = nil
            }
            Button("キャンセル", role: .cancel) { deleting = nil }
        } message: { Text("番組だけを削除します。音声と現在の再生・途中再開は保持されます。") }
    }
}

@MainActor struct ProgramDetailView: View {
    @Environment(\.studyTheme) private var design
    let programID: UUID
    @EnvironmentObject private var audio: AudioLibraryModel
    @EnvironmentObject private var player: TrackPlayer
    @State private var showPlayer = false
    @State private var renaming = false
    @State private var adding = false
    @State private var title = ""
    private var program: PlaylistManifest? { audio.index.programs?.first(where: { $0.id == programID }) }
    private func update(title: String? = nil, tracks: [UUID]? = nil) {
        guard let program else { return }
        let next = PlaylistManifest(schemaVersion: 1, playlistID: program.id,
            title: title ?? program.title, trackIDs: tracks ?? program.trackIDs, gapSeconds: program.gapSeconds)
        audio.editPrograms { try $0.updateProgram(next) }
    }
    var body: some View {
        List {
            Group {
                if let program {
                    Section {
                        Button("続きから聴く") { player.playProgram(program); showPlayer = true }
                            .disabled(program.trackIDs.isEmpty && !(audio.index.radio?.playlist.id == program.id && audio.index.radio?.phase != .completed))
                        Button("最初から聴く") { player.playProgram(program, restart: true); showPlayer = true }
                            .disabled(program.trackIDs.isEmpty)
                    }
                    Section { Text("\(audio.index.listenedCount(in: program))/\(program.trackIDs.count)本 聴取済み") }
                    Section("番組の設定") {
                        Button("名前を変更") { title = program.title; renaming = true }
                        Stepper("曲間 \(Int(program.gapSeconds))秒", value: Binding(
                            get: { self.program?.gapSeconds ?? program.gapSeconds },
                            set: { audio.setGap($0, programID: programID) }), in: 0...10, step: 1)
                        Text("編集は次に最初から再生するときに反映します。現在の再生と途中再開には保存した再生順・曲間を使います。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Section("再生順") {
                        Button("音声を追加") { adding = true }
                        ForEach(Array(program.trackIDs.enumerated()), id: \.element) { item in
                            HStack {
                                Text("\(item.offset + 1). \(audio.index.tracks.first(where: { $0.id == item.element })?.manifest.title ?? "未取得")")
                                if audio.index.tracks.first(where: { $0.id == item.element })?.isListened == true {
                                    Label("聴取済み", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .contextMenu {
                                Button("番組から外す", role: .destructive) {
                                    update(tracks: self.program?.trackIDs.filter { $0 != item.element })
                                }
                            }
                        }
                        .onDelete { offsets in
                            var ids = self.program?.trackIDs ?? []
                            ids.remove(atOffsets: offsets); update(tracks: ids)
                        }
                        .onMove { offsets, destination in
                            var ids = self.program?.trackIDs ?? []
                            ids.move(fromOffsets: offsets, toOffset: destination); update(tracks: ids)
                        }
                        if program.trackIDs.isEmpty { Text("音声を追加してください。").foregroundStyle(.secondary) }
                    }
                } else { ContentUnavailableView("番組が見つかりません", systemImage: "play.rectangle") }
            }.listRowBackground(design.surface)
        }
        .scrollContentBackground(.hidden)
        .background { StudyBackdrop() }.navigationTitle(program?.title ?? "番組").navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showPlayer) { AudioPlayerView() }
        .toolbar { EditButton() }
        .alert("名前を変更", isPresented: $renaming) {
            TextField("番組名", text: $title)
            Button("保存") { update(title: title) }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("キャンセル", role: .cancel) {}
        }
        .sheet(isPresented: $adding) {
            ProgramTrackPicker(programID: programID)
        }
    }
}

@MainActor private struct ProgramTrackPicker: View {
    @Environment(\.studyTheme) private var design
    let programID: UUID
    @EnvironmentObject private var audio: AudioLibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<UUID> = []
    @State private var query = ""
    private var program: PlaylistManifest? { audio.index.programs?.first { $0.id == programID } }
    private var available: [AudioTrack] {
        audio.index.tracks.filter {
            !(program?.trackIDs.contains($0.id) ?? true) &&
            (query.isEmpty || $0.manifest.title.localizedCaseInsensitiveContains(query))
        }
    }
    var body: some View {
        NavigationStack {
            List {
                Group {
                    ForEach(available) { track in
                        Button {
                            if !selected.insert(track.id).inserted { selected.remove(track.id) }
                        } label: {
                            HStack {
                                Text(track.manifest.title)
                                Spacer()
                                Image(systemName: selected.contains(track.id) ? "checkmark.circle.fill" : "circle")
                            }
                        }.accessibilityLabel(track.manifest.title)
                            .accessibilityValue(selected.contains(track.id) ? "選択済み" : "未選択")
                    }
                    if available.isEmpty { Text("追加できる音声がありません。").foregroundStyle(.secondary) }
                }.listRowBackground(design.surface)
            }
            .scrollContentBackground(.hidden)
            .background { StudyBackdrop() }
            .searchable(text: $query, prompt: "音声を検索")
            .navigationTitle("音声を追加").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        guard let program else { return }
                        let ids = audio.index.tracks.map(\.id).filter { selected.contains($0) && !program.trackIDs.contains($0) }
                        audio.editPrograms {
                            try $0.updateProgram(PlaylistManifest(schemaVersion: 1, playlistID: program.id,
                                title: program.title, trackIDs: program.trackIDs + ids, gapSeconds: program.gapSeconds))
                        }
                        if audio.storage.index.programs?.first(where: { $0.id == programID })?.trackIDs == program.trackIDs + ids {
                            dismiss()
                        }
                    }.disabled(selected.isEmpty || program == nil)
                }
            }
        }
    }
}

@MainActor struct AudioPlayerView: View {
    @Environment(\.studyTheme) private var design
    var article: Article? = nil
    @EnvironmentObject private var audio: AudioLibraryModel
    @EnvironmentObject private var player: TrackPlayer
    @EnvironmentObject private var library: Library
    private var articleTracks: [AudioTrack] {
        audio.index.tracks.filter { $0.manifest.articleID == article?.id }
    }
    var body: some View {
        List {
            Group {
                if let track = player.track {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "headphones").font(.system(size: 56)).foregroundStyle(design.accent)
                                .padding(.top, 20)
                            Text(track.manifest.title).font(.title3.bold()).multilineTextAlignment(.center)
                            Text(track.manifest.voice).font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity).padding(.bottom, 16)
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
                        Text("\(timeText(player.position)) / \(timeText(player.duration))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        HStack {
                            Button { player.skip(-15) } label: { Image(systemName: "gobackward.15").frame(width: 44, height: 44) }.accessibilityLabel("15秒戻す")
                            Button { if player.playing { player.pause() } else { player.resume() } } label: { Image(systemName: player.playing ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 54)).frame(minWidth: 64, minHeight: 64) }.accessibilityLabel(player.playing ? "一時停止" : "再生")
                            Button { player.skip(15) } label: { Image(systemName: "goforward.15").frame(width: 44, height: 44) }.accessibilityLabel("15秒進む")
                        }.frame(maxWidth: .infinity).buttonStyle(.borderless)
                            .disabled(player.radio?.phase == .completed)
                        Picker("速度", selection: $player.speed) {
                            ForEach([Float(0.75), 1, 1.25, 1.5, 2], id: \.self) { Text("\(String(format: "%.2g", $0))倍").tag($0) }
                        }
                        Button(audio.index.tracks.first(where: { $0.id == track.id })?.isListened == true ? "聴取済み · 未聴取に戻す" : "聴取済みにする") {
                            let completed = audio.index.tracks.first(where: { $0.id == track.id })?.isListened == true
                            audio.setListened(!completed, id: track.id)
                        }
                        Toggle("BGM", isOn: $player.bgmEnabled)
                        Slider(value: $player.bgmVolume, in: 0...0.5).accessibilityLabel("BGM音量")
                        if audio.index.bgmFile == nil { Text("BGMは未登録です。") }
                    }
                    if let source = track.manifest.sourceContentHash,
                       let current = library.articles.first(where: { $0.id == track.manifest.articleID }), source != current.contentHash {
                        Text("元記事が更新されています").font(.caption).foregroundStyle(.orange)
                    }
                    if let radio = player.radio {
                        Section("番組") {
                            Button("最初から聴く") { player.playProgram(radio.playlist, restart: true) }
                            if let program = audio.index.programs?.first(where: { $0.id == radio.playlist.id }) {
                                Stepper("曲間 \(Int(program.gapSeconds))秒（最初から再生時）", value: Binding(
                                    get: { audio.index.programs?.first(where: { $0.id == program.id })?.gapSeconds ?? program.gapSeconds },
                                    set: { audio.setGap($0, programID: program.id) }), in: 0...10, step: 1)
                            }
                            DisclosureGroup("再生順") {
                                ForEach(Array(radio.playlist.trackIDs.enumerated()), id: \.element) { item in
                                    HStack {
                                        Text("\(item.offset + 1). \(audio.index.tracks.first(where: { $0.id == item.element })?.manifest.title ?? "未取得")")
                                        if audio.index.tracks.first(where: { $0.id == item.element })?.isListened == true {
                                            Label("聴取済み", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    .foregroundStyle(item.offset == radio.index ? design.accent : .secondary)
                                }
                            }
                        }
                    }
                    if let article = library.articles.first(where: { $0.id == track.manifest.articleID }) {
                        Section("関連記事") {
                            NavigationLink { ArticleReader(article: article) } label: { Label(article.title, systemImage: "doc.text") }
                            ForEach(RelatedContent.programs(articleIDs: [article.id], audio: audio.index)) { program in
                                NavigationLink { ProgramDetailView(programID: program.id) } label: { Label(program.title, systemImage: "play.rectangle") }
                            }
                        }
                    } else {
                        Text("元記事は現在の一覧にありません。音声と台本は引き続き利用できます。").font(.caption).foregroundStyle(.secondary)
                    }
                    if let script = track.script {
                        Section { DisclosureGroup("台本") { Text(script).textSelection(.enabled) } }
                    }
                } else {
                    ContentUnavailableView("再生する音声がありません", systemImage: "headphones")
                }
                if articleTracks.count > 1 {
                    Section("この記事の音声") {
                        ForEach(articleTracks) { track in
                            Button(track.manifest.title) { player.play(track) }
                        }
                    }
                }
            }.listRowBackground(design.surface)
        }
        .scrollContentBackground(.hidden)
        .background { StudyBackdrop() }
        .navigationTitle("再生").navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let article, player.track?.manifest.articleID != article.id, let track = articleTracks.first {
                player.play(track)
            }
        }
    }
}

private func timeText(_ seconds: Double) -> String {
    let value = Int(max(0, seconds))
    return String(format: "%d:%02d", value / 60, value % 60)
}

@MainActor struct AudioMiniPlayer: View {
    @Environment(\.studyTheme) private var design
    @EnvironmentObject private var player: TrackPlayer
    @State private var expanded = false
    var body: some View {
        if let track = player.track {
            VStack(spacing: 0) {
                if player.duration > 0 {
                    ProgressView(value: min(max(0, player.position), player.duration), total: player.duration)
                        .accessibilityLabel("音声の再生進捗")
                }
                HStack(spacing: 16) {
                    Button { expanded = true } label: {
                        HStack {
                            Image(systemName: "headphones")
                            VStack(alignment: .leading, spacing: 3) {
                                Text(track.manifest.title).font(.footnote.weight(.semibold)).lineLimit(1)
                                Text(player.radio?.phase == .interval ? "次の音声までインターバル" : "再生ページを開く")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Button { if player.playing { player.pause() } else { player.resume() } } label: {
                        Image(systemName: player.playing ? "pause.fill" : "play.fill").frame(width: 44, height: 44)
                    }.accessibilityLabel(player.playing ? "一時停止" : "再生")
                }.padding(.horizontal, 16).padding(.vertical, 4)
            }.background(design.surface)
            .sheet(isPresented: $expanded) {
                NavigationStack {
                    AudioPlayerView().toolbar { Button("閉じる") { expanded = false } }
                }
            }
        }
    }
}

@MainActor struct AudioSettingsView: View {
    @Environment(\.studyTheme) private var design
    @EnvironmentObject private var audio: AudioLibraryModel
    @EnvironmentObject private var player: TrackPlayer
    @State private var importing = false
    @State private var choosingFolder = false
    @State private var busy = false
    @State private var message: String?
    var body: some View {
        Form {
            Group {
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
            }.listRowBackground(design.surface)
        }
        .scrollContentBackground(.hidden)
        .background { StudyBackdrop() }
        .navigationTitle("音声・同期")
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
        .alert("音声", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("閉じる") { message = nil }
        } message: { Text(message ?? "") }
    }
}

@MainActor struct ListeningHome: View {
    @Environment(\.studyTheme) private var design
    @EnvironmentObject private var audio: AudioLibraryModel
    @EnvironmentObject private var player: TrackPlayer
    @State private var showPlayer = false
    @ScaledMetric(relativeTo: .body) private var tileScale: CGFloat = 1
    @State private var tileWidth: CGFloat = 350
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("番組").font(.subheadline.bold())
                    Spacer()
                    NavigationLink("管理") { ProgramsView() }.font(.footnote)
                }
                if (audio.index.programs ?? []).isEmpty {
                    NavigationLink { ProgramsView() } label: {
                        Label("番組を作成", systemImage: "plus.circle").frame(maxWidth: .infinity, alignment: .leading).padding(20)
                            .background { StudyTileSurface() }
                    }
                } else {
                    GeometryReader { proxy in
                        let side = min(proxy.size.width, max(120, (proxy.size.width - 20) / 2.5) * max(1, tileScale))
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 10) {
                                ForEach(audio.index.programs ?? []) { program in
                                    NavigationLink { ProgramDetailView(programID: program.id) } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Image(systemName: "play.rectangle").font(.title2).foregroundStyle(design.accent)
                                            Spacer(minLength: 0)
                                            Text(program.title).font(.footnote.bold()).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.leading)
                                            Text("\(program.trackIDs.count)本 · \(audio.index.listenedCount(in: program))本 聴取済み")
                                                .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                                        }.padding(10).frame(width: side, height: side, alignment: .leading)
                                            .background { StudyTileSurface() }
                                    }.buttonStyle(.plain)
                                }
                            }.scrollTargetLayout()
                        }.scrollIndicators(.hidden).scrollTargetBehavior(.viewAligned)
                        .onAppear { tileWidth = proxy.size.width }
                        .onChange(of: proxy.size.width) { _, width in tileWidth = width }
                    }.frame(height: min(tileWidth, max(120, (tileWidth - 20) / 2.5) * max(1, tileScale)))
                }
                HStack {
                    Text("音声").font(.subheadline.bold())
                    Spacer()
                    NavigationLink("すべて") { AudioView() }.font(.footnote)
                }
                ForEach(audio.index.tracks) { track in
                    Button { player.play(track); showPlayer = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(design.accent)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(track.manifest.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).multilineTextAlignment(.leading)
                                Text(track.isListened ? "聴取済み" : "未聴取").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background { StudyTileSurface() }
                    }.buttonStyle(.plain).contextMenu {
                        Button(track.isListened ? "未聴取に戻す" : "聴取済みにする") { audio.setListened(!track.isListened, id: track.id) }
                    }
                }
                if audio.index.tracks.isEmpty {
                    ContentUnavailableView("まだ音声がありません", systemImage: "headphones", description: Text("設定の「音声・同期」で制作物フォルダを選んでください。"))
                    NavigationLink("音声・同期を開く") { AudioSettingsView() }
                }
                if audio.syncing { ProgressView("音声を同期中") }
                if let status = audio.syncMessage { Text(status).font(.caption).foregroundStyle(.secondary) }
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background { StudyBackdrop() }
            .navigationTitle("聴く").navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showPlayer) { AudioPlayerView() }
            .toolbar {
                Button { Task { await audio.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(audio.folderName == nil || audio.syncing).accessibilityLabel("音声を同期")
            }
    }
}

@MainActor struct LinkedAudioPlayer: View {
    let track: AudioTrack
    @EnvironmentObject private var player: TrackPlayer
    var body: some View {
        AudioPlayerView().onAppear {
            if player.track?.id != track.id { player.play(track) }
        }
    }
}
