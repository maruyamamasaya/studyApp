import SwiftUI
import MarkdownUI
import UniformTypeIdentifiers

@MainActor final class Library: ObservableObject {
    @Published var articles: [Article] = []
    @Published var error: String?
    @Published var loading = false
    let client: ArticleProviding
    let offline: OfflineArticles
    init(client: ArticleProviding = ArticleClient(), offline: OfflineArticles = OfflineArticles()) {
        self.client = client; self.offline = offline
    }
    @Published private(set) var offlineIDs: Set<String> = []
    @Published private(set) var offlineBytes: Int64 = 0
    @Published private(set) var offlineCatalog = false
    @Published private(set) var offlineMessage: String?
    @Published private(set) var downloading = false
    @Published private(set) var downloaded = 0
    @Published private(set) var downloadFailures = 0
    private var downloadTask: Task<Void, Never>?
    private var cacheGeneration = UUID()
    func updateOfflineSummary() async {
        do {
            let summary = try await offline.summary(articles: articles)
            offlineIDs = summary.ids; offlineBytes = summary.bytes
        } catch { offlineMessage = "保存状況を確認できません: " + error.localizedDescription }
    }
    func downloadAll() {
        guard !downloading else { return }
        downloading = true; downloaded = 0; downloadFailures = 0
        let candidates = articles
        downloadTask = Task {
            defer { downloading = false }
            for article in candidates {
                guard !Task.isCancelled else { break }
                do { _ = try await content(article) }
                catch { downloadFailures += 1 }
                downloaded += 1
            }
            await updateOfflineSummary()
        }
    }
    func cancelDownload() { downloadTask?.cancel() }
    func removeOffline() async {
        guard !downloading, requests.isEmpty else { offlineMessage = "取得が終わってから削除してください。"; return }
        cacheGeneration = UUID()
        do {
            try await offline.remove(); bodies = [:]; offlineIDs = []; offlineBytes = 0
            offlineMessage = "端末に保存した記事を削除しました。学習記録と音声は保持されます。"
        } catch { offlineMessage = "保存記事を削除できません: " + error.localizedDescription }
    }
    private var bodies: [String: String] = [:]
    private var requests: [String: Task<String, Error>] = [:]
    nonisolated static func cacheKey(_ article: Article) -> String { article.id + "/" + article.contentHash }
    func content(_ article: Article) async throws -> String {
        let key = Self.cacheKey(article)
        let generation = cacheGeneration
        if let body = bodies[key] { return body }
        do {
            if let text = try await offline.content(article), generation == cacheGeneration { bodies[key] = text; offlineIDs.insert(article.id); return text }
        } catch { offlineMessage = "保存本文を検証できなかったため、配信元から取得します。" }
        let request: Task<String, Error>
        if let existing = requests[key] { request = existing }
        else {
            request = Task { try await client.content(article) }
            requests[key] = request
        }
        defer { requests[key] = nil }
        let body = try await request.value
        if generation == cacheGeneration {
            bodies[key] = body
            do { try await offline.save(body, for: article); offlineIDs.insert(article.id) }
            catch { offlineMessage = "本文は取得できましたが端末保存に失敗しました: " + error.localizedDescription }
        }
        return body
    }
    func reload() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let catalog = try await client.catalog()
            articles = catalog.articles; error = nil; offlineCatalog = false
            let validKeys = Set(articles.map(Self.cacheKey))
            bodies = bodies.filter { validKeys.contains($0.key) }
            do { try await offline.save(catalog) }
            catch { offlineMessage = "記事一覧の端末保存に失敗しました: " + error.localizedDescription }
            await updateOfflineSummary()
        }
        catch is CancellationError { }
        catch {
            self.error = error.localizedDescription
            if articles.isEmpty, error is URLError {
                do {
                    if let catalog = try await offline.catalog() {
                        articles = catalog.articles; offlineCatalog = true
                        self.error = nil
                        await updateOfflineSummary()
                    }
                } catch { self.error = "保存された記事一覧を検証できません: " + error.localizedDescription }
            }
        }
    }
}

@main @MainActor struct StudyApp: App {
    @AppStorage(StudyAppearance.storageKey) private var selectedAppearance = StudyAppearance.system.rawValue
    @AppStorage(StudyTheme.storageKey) private var selectedTheme = StudyTheme.aurora.rawValue
    private var design: StudyTheme { StudyTheme.restored(selectedTheme) }
    @StateObject private var library = Library()
    @StateObject private var store = StudyStore()
    @StateObject private var search = SearchNavigation()
    @StateObject private var visualResources = VisualResourceModel()
    @StateObject private var audio: AudioLibraryModel
    @StateObject private var player: TrackPlayer
    @Environment(\.scenePhase) private var scenePhase
    init() {
        let audio = AudioLibraryModel()
        _audio = StateObject(wrappedValue: audio)
        _player = StateObject(wrappedValue: TrackPlayer(library: audio))
    }
    var body: some Scene {
        WindowGroup {
            TabView(selection: $search.tab) {
                PlayerTabContent { ArticleList() }.tabItem { Label("記事", systemImage: "books.vertical") }.tag(0)
                PlayerTabContent { NavigationStack { ListeningHome() } }.tabItem { Label("聴く", systemImage: "headphones") }.tag(1)
                PlayerTabContent { SearchView() }.tabItem { Label("検索", systemImage: "magnifyingglass") }.tag(2)
                PlayerTabContent { NavigationStack { FolderBrowser() } }.tabItem { Label("フォルダ", systemImage: "folder") }.tag(3)
                PlayerTabContent { SettingsView() }.tabItem { Label("設定", systemImage: "gearshape") }.tag(4)
            }
            .font(.callout)
            .tint(design.accent)
            .environment(\.studyTheme, design)
            .preferredColorScheme(design == .classic ? .light : (StudyAppearance(rawValue: selectedAppearance) ?? .system).colorScheme)
            .environmentObject(library).environmentObject(store).environmentObject(search)
            .environmentObject(audio).environmentObject(player)
            .environmentObject(visualResources)
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { player.savePosition() }
                else { Task { await audio.refresh() } }
            }
            .task { await library.reload() }
            .task { await audio.refresh() }
            .task { await visualResources.reload() }
            .alert("図解・資料", isPresented: Binding(get: { visualResources.error != nil }, set: { if !$0 { visualResources.error = nil } })) {
                Button("閉じる") { visualResources.error = nil }
            } message: { Text(visualResources.error ?? "") }
            .alert("音声", isPresented: Binding(get: { player.error != nil || audio.error != nil }, set: { if !$0 { player.error = nil; audio.error = nil } })) {
                Button("閉じる") { player.error = nil; audio.error = nil }
            } message: { Text(player.error ?? audio.error ?? "") }
            .alert("記録の保存エラー", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("閉じる") { store.error = nil }
            } message: { Text(store.error ?? "") }
        }
    }
}

// Reserve actual layout space outside navigation so pushed readers cannot extend
// beneath the player. Its height follows the content and Dynamic Type.
@MainActor private struct PlayerTabContent<Content: View>: View {
    @Environment(\.studyTheme) private var design
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content().frame(maxWidth: .infinity, maxHeight: .infinity)
                .scrollContentBackground(.hidden)
                .listRowBackground(design.surface)
                .toolbarBackground(design.surface, for: .navigationBar, .tabBar)
                .toolbarBackground(.visible, for: .navigationBar, .tabBar)
            AudioMiniPlayer().fixedSize(horizontal: false, vertical: true)
        }.background { StudyBackdrop() }
    }
}

@MainActor struct ArticleReader: View {
    @Environment(\.studyTheme) private var design
    let article: Article
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var search: SearchNavigation
    @Environment(\.scenePhase) private var scenePhase
    @State private var markdown: String?
    @State private var error: String?
    @State private var visible = false
    @State private var timer = StudyTimer()
    @State private var candidates: [Article] = []
    @State private var showCandidates = false
    @State private var linkNotice = false
    @State private var showSave = false
    @EnvironmentObject private var audio: AudioLibraryModel
    private let pulse = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private var current: Article { library.articles.first(where: { $0.id == article.id }) ?? article }
    private var completed: Bool { store.data.progress[article.id]?.completed == true }
    private var running: Bool { visible && scenePhase == .active && markdown != nil && !completed }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(current.folder).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    Text(current.title).font(.title.bold()).tracking(-0.6).fixedSize(horizontal: false, vertical: true)
                    TagFlow {
                        ForEach(Array(Set(current.tags)).sorted(), id: \.self) { tag in
                            Button { search.open(tag: tag) } label: { TagPill(text: tag) }
                        }
                    }
                    if library.offlineCatalog {
                        Label("保存した記事一覧を使用中。更新は通信復帰後に確認してください。", systemImage: "wifi.slash").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("学習 \(Int(store.seconds(for: article.id) / 60))分", systemImage: "clock")
                        if completed { Label("読了", systemImage: "checkmark.circle.fill") }
                    }.font(.caption).foregroundStyle(.secondary)
                    if audio.index.tracks.contains(where: { $0.manifest.articleID == article.id }) {
                        NavigationLink { AudioPlayerView(article: current) } label: {
                            Label("この記事を聴く", systemImage: "headphones").font(.footnote.weight(.semibold))
                                .padding(14).frame(maxWidth: .infinity).background(design.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: design.radius))
                        }
                    }
                }
                Divider()
                if let markdown {
                    Markdown(markdown, baseURL: try? ArticleClient.url(for: current.path))
                        .markdownImageProvider(VisualImageProvider(articleID: current.id))
                        .markdownTheme(design.reader)
                        .textSelection(.enabled)
                        .environment(\.openURL, OpenURLAction { url in open(url) })
                    relatedContent
                    ArticleVisualResources(article: current, markdown: markdown)
                    VStack(spacing: 12) {
                        Button(completed ? "未読了に戻す" : "読了として記録") {
                            timer.flush(articleID: article.id, store: store, resume: false)
                            store.toggle(article)
                            syncTimer()
                        }.buttonStyle(.borderedProminent)
                    }.frame(maxWidth: .infinity).padding(24).background(design.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: design.radius))
                } else if let error {
                    Text(error).foregroundStyle(.red)
                    Button("一覧を更新して再試行") { Task { await library.reload(); await load() } }
                } else { ProgressView("本文を取得中") }
            }.padding(22).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(design.readerSurface)
        .toolbar {
            Button { showSave = true } label: {
                Image(systemName: store.isFavorite(article.id) ? "bookmark.fill" : "bookmark")
            }.accessibilityLabel("お気に入り・コレクションに保存")
        }
        .sheet(isPresented: $showSave) { SaveArticleView(article: current) }
        .onChange(of: showSave) { _, showing in visible = !showing; syncTimer() }
        .navigationTitle(article.title).navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onAppear { visible = true; syncTimer() }
        .onDisappear { visible = false; syncTimer() }
        .onChange(of: scenePhase) { _, _ in syncTimer() }
        .onReceive(pulse) { _ in timer.flush(articleID: article.id, store: store, resume: running) }
        .sheet(isPresented: $showCandidates) {
            NavigationStack {
                List(candidates) { candidate in
                    Group {
                        NavigationLink(candidate.title) { ArticleReader(article: candidate) }
                    }.listRowBackground(design.surface)
                }
                .scrollContentBackground(.hidden)
                .background { StudyBackdrop() }
                .navigationTitle("リンク先を選択")
                .toolbar { Button("閉じる") { showCandidates = false } }
            }
        }
        .onChange(of: showCandidates) { _, showing in
            visible = !showing
            syncTimer()
        }
        .alert("リンクを開けません", isPresented: $linkNotice) {
            Button("閉じる", role: .cancel) { }
        } message: { Text("記事が見つからないか、未対応のリンクです。見出しリンクは現在、記事の先頭を開きます。") }
    }
    private var relatedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            let tracks = audio.index.tracks.filter { $0.manifest.articleID == current.id }
            if !tracks.isEmpty {
                Text("この記事の音声").font(.subheadline.bold())
                ForEach(tracks) { track in
                    NavigationLink { LinkedAudioPlayer(track: track) } label: {
                        Label(track.manifest.title, systemImage: "headphones").font(.footnote)
                    }
                }
            }
            let programs = RelatedContent.programs(articleIDs: [current.id], audio: audio.index)
            if !programs.isEmpty {
                Text("この記事を含む番組").font(.subheadline.bold())
                ForEach(programs) { program in
                    NavigationLink { ProgramDetailView(programID: program.id) } label: {
                        Label(program.title, systemImage: "play.rectangle").font(.footnote)
                    }
                }
            }
            let related = RelatedContent.articles(for: current, in: library.articles)
            if !related.isEmpty {
                Text("関連する記事").font(.subheadline.bold())
                ForEach(related) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        NavigationLink { ArticleReader(article: item.article) } label: { Text(item.article.title).font(.footnote) }
                        Text("共通タグ: " + item.tags.joined(separator: "・")).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }.padding(.vertical, 12)
    }
    private func syncTimer() {
        if running { timer.start() } else { timer.flush(articleID: article.id, store: store, resume: false) }
    }
    private func load() async {
        markdown = nil; error = nil; syncTimer()
        do {
            if library.articles.isEmpty { await library.reload() }
            guard let latest = library.articles.first(where: { $0.id == article.id }) else { throw ReaderError.message("この記事は現在の一覧にありません。") }
            do { markdown = ArticleLinks.body(try await library.content(latest)) }
            catch ReaderError.mismatch {
                await library.reload()
                guard let updated = library.articles.first(where: { $0.id == article.id }) else { throw ReaderError.mismatch }
                markdown = ArticleLinks.body(try await library.content(updated))
            }
            try Task.checkCancellation()
            store.viewed(latest); syncTimer()
        } catch is CancellationError { markdown = nil }
        catch { self.error = error.localizedDescription }
    }
    private func open(_ url: URL) -> OpenURLAction.Result {
        let target: String
        if url.scheme == "studyarticle" {
            target = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "target" })?.value ?? ""
        } else if url.scheme == nil { target = url.relativeString }
        else if url.scheme == "https" && url.host == ArticleClient.baseURL.host && url.port == nil && url.path.hasPrefix(ArticleClient.baseURL.path) {
            target = String(url.path.dropFirst(ArticleClient.baseURL.path.count))
        } else if ["https", "http"].contains(url.scheme ?? "") { return .systemAction }
        else { linkNotice = true; return .handled }
        candidates = ArticleLinks.resolve(target, current: current, articles: library.articles)
        if candidates.isEmpty { linkNotice = true } else { showCandidates = true }
        return .handled
    }
}

@MainActor struct HistoryView: View {
    @Environment(\.studyTheme) private var design
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var library: Library
    private var history: [ArticleHistorySummary] { ArticleHistorySummary.summarize(store.data.sessions) }
    var body: some View {
        List {
            Group {
                ForEach(history) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(library.articles.first(where: { $0.id == entry.id })?.title ?? store.data.progress[entry.id]?.title ?? entry.id)
                            .font(.subheadline.weight(.semibold))
                        Text("合計 \(entry.durationText)").font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }
                if history.isEmpty {
                    ContentUnavailableView("学習履歴はまだありません", systemImage: "clock")
                }
            }.listRowBackground(design.surface)
        }
        .scrollContentBackground(.hidden)
        .background { StudyBackdrop() }.navigationTitle("学習履歴").navigationBarTitleDisplayMode(.inline)
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

@MainActor struct SettingsView: View {
    @Environment(\.studyTheme) private var design
    @EnvironmentObject private var store: StudyStore
    @State private var merge = false
    @State private var export = false
    @State private var importing = false
    @State private var confirm = false
    @State private var document = BackupDocument()
    @State private var pending: Data?
    @State private var message: String?
    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section("表示") {
                        NavigationLink { ThemeSettingsView() } label: {
                            Label("テーマ", systemImage: "paintpalette")
                        }
                    }
                    Section("記事の保存") {
                        NavigationLink { OfflineSettingsView() } label: { Label("オフライン記事", systemImage: "arrow.down.circle") }
                        NavigationLink { VisualLibraryView() } label: { Label("図解・資料ライブラリ", systemImage: "doc.richtext") }
                    }
                    Section("学習記録") {
                        NavigationLink { HistoryView() } label: {
                            Label("学習履歴", systemImage: "clock")
                        }
                        Button("バックアップを書き出す") {
                            do { document = BackupDocument(data: try store.export()); export = true }
                            catch { message = error.localizedDescription }
                        }
                        Button("バックアップから復元") { merge = false; importing = true }
                        Button("別の端末の記録を統合") { merge = true; importing = true }
                        Text("JSONを書き出し、AirDropやファイルで別の端末へ渡して統合できます。読了・お気に入り・コレクションの記事は両端末の記録を合わせ、同じコレクションの名前はこの端末を優先します。").font(.caption)
                        Text("復元すると現在の記録を置き換えます。Webの記録とは独立しています。")
                    }
                    Section("音声") {
                        NavigationLink { AudioSettingsView() } label: { Label("音声・同期", systemImage: "headphones") }
                    }
                    Section("記事の配信元") { Text(ArticleClient.baseURL.absoluteString).font(.caption) }
                }.listRowBackground(design.surface)
            }
            .scrollContentBackground(.hidden)
            .background { StudyBackdrop() }.navigationTitle("設定")
            .fileExporter(isPresented: $export, document: document, contentType: .json, defaultFilename: "study-records") { result in
                if case .failure(let error) = result { message = error.localizedDescription }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let bytes = try Data(contentsOf: url)
                    _ = try StudyStore.decode(bytes)
                    pending = bytes; confirm = true
                } catch { message = error.localizedDescription }
            }
            .confirmationDialog(merge ? "現在の記録にバックアップを統合しますか？" : "現在の記録をバックアップで置き換えますか？", isPresented: $confirm, titleVisibility: .visible) {
                Button(merge ? "現在の記録へ統合" : "置き換えて復元", role: merge ? nil : .destructive) {
                    do { if let pending { if merge { try store.merge(pending) } else { try store.restore(pending) } }; pending = nil }
                    catch { message = error.localizedDescription }
                }
                Button("キャンセル", role: .cancel) { pending = nil }
            }
            .alert("バックアップ", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("閉じる") { message = nil }
            } message: { Text(message ?? "") }
        }
    }
}
