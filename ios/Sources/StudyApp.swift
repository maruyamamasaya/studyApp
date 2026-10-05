import SwiftUI
import MarkdownUI
import UniformTypeIdentifiers

@MainActor final class Library: ObservableObject {
    @Published var articles: [Article] = []
    @Published var error: String?
    @Published var loading = false
    let client = ArticleClient()
    @Published private(set) var excerpts: [String: String] = [:]
    @Published private(set) var excerptFailures: Set<String> = []
    private var bodies: [String: String] = [:]
    private var requests: [String: Task<String, Error>] = [:]
    static func cacheKey(_ article: Article) -> String { article.id + "/" + article.contentHash }
    func content(_ article: Article) async throws -> String {
        let key = Self.cacheKey(article)
        if let body = bodies[key] { return body }
        let request: Task<String, Error>
        if let existing = requests[key] { request = existing }
        else {
            request = Task { try await client.content(article) }
            requests[key] = request
        }
        defer { requests[key] = nil }
        let body = try await request.value
        bodies[key] = body
        return body
    }
    func loadExcerpt(_ article: Article) async {
        let key = Self.cacheKey(article)
        guard excerpts[key] == nil else { return }
        do {
            excerpts[key] = ArticlePreview.excerpt(try await content(article))
            excerptFailures.remove(key)
        } catch { excerptFailures.insert(key) }
    }
    func reload() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do { articles = try await client.catalog().articles; error = nil; excerptFailures.removeAll() }
        catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}

@main @MainActor struct StudyApp: App {
    @StateObject private var library = Library()
    @StateObject private var store = StudyStore()
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
            TabView {
                ArticleList().safeAreaInset(edge: .bottom, spacing: 0) { AudioMiniPlayer() }.tabItem { Label("記事", systemImage: "books.vertical") }
                NavigationStack { AudioView() }.safeAreaInset(edge: .bottom, spacing: 0) { AudioMiniPlayer() }.tabItem { Label("聴く", systemImage: "headphones") }
                NavigationStack { ProgramsView() }.safeAreaInset(edge: .bottom, spacing: 0) { AudioMiniPlayer() }.tabItem { Label("番組", systemImage: "play.rectangle") }
                NavigationStack { FolderBrowser() }.safeAreaInset(edge: .bottom, spacing: 0) { AudioMiniPlayer() }.tabItem { Label("フォルダ", systemImage: "folder") }
                SettingsView().safeAreaInset(edge: .bottom, spacing: 0) { AudioMiniPlayer() }.tabItem { Label("設定", systemImage: "gearshape") }
            }
            .font(.callout)
            .tint(StudyDesign.accent)
            .environmentObject(library).environmentObject(store)
            .environmentObject(audio).environmentObject(player)
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { player.savePosition() }
                else { Task { await audio.refresh() } }
            }
            .task { await library.reload() }
            .task { await audio.refresh() }
            .alert("音声", isPresented: Binding(get: { player.error != nil || audio.error != nil }, set: { if !$0 { player.error = nil; audio.error = nil } })) {
                Button("閉じる") { player.error = nil; audio.error = nil }
            } message: { Text(player.error ?? audio.error ?? "") }
            .alert("記録の保存エラー", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("閉じる") { store.error = nil }
            } message: { Text(store.error ?? "") }
        }
    }
}

@MainActor struct ArticleReader: View {
    let article: Article
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var store: StudyStore
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
                            NavigationLink { ArticleResultsScreen(title: tag, tag: tag) } label: { TagPill(text: tag) }
                        }
                    }
                    HStack {
                        Label("学習 \(Int(store.seconds(for: article.id) / 60))分", systemImage: "clock")
                        if completed { Label("読了", systemImage: "checkmark.circle.fill") }
                    }.font(.caption).foregroundStyle(.secondary)
                    if audio.index.tracks.contains(where: { $0.manifest.articleID == article.id }) {
                        NavigationLink { AudioPlayerView(article: current) } label: {
                            Label("この記事を聴く", systemImage: "headphones").font(.footnote.weight(.semibold))
                                .padding(14).frame(maxWidth: .infinity).background(StudyDesign.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                Divider()
                if let markdown {
                    Markdown(markdown, baseURL: try? ArticleClient.url(for: current.path))
                        .markdownTheme(StudyDesign.reader)
                        .textSelection(.enabled)
                        .environment(\.openURL, OpenURLAction { url in open(url) })
                    VStack(spacing: 12) {
                        Button(completed ? "未読了に戻す" : "読了として記録") {
                            timer.flush(articleID: article.id, store: store, resume: false)
                            store.toggle(article)
                            syncTimer()
                        }.buttonStyle(.borderedProminent)
                    }.frame(maxWidth: .infinity).padding(24).background(StudyDesign.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                } else if let error {
                    Text(error).foregroundStyle(.red)
                    Button("一覧を更新して再試行") { Task { await library.reload(); await load() } }
                } else { ProgressView("本文を取得中") }
            }.padding(22).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(StudyDesign.surface)
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
                    NavigationLink(candidate.title) { ArticleReader(article: candidate) }
                }
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
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var library: Library
    private var history: [ArticleHistorySummary] { ArticleHistorySummary.summarize(store.data.sessions) }
    var body: some View {
        List {
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
        }.navigationTitle("学習履歴").navigationBarTitleDisplayMode(.inline)
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
    @EnvironmentObject private var store: StudyStore
    @State private var export = false
    @State private var importing = false
    @State private var confirm = false
    @State private var document = BackupDocument()
    @State private var pending: Data?
    @State private var message: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("学習記録") {
                    NavigationLink { HistoryView() } label: {
                        Label("学習履歴", systemImage: "clock")
                    }
                    Button("バックアップを書き出す") {
                        do { document = BackupDocument(data: try store.export()); export = true }
                        catch { message = error.localizedDescription }
                    }
                    Button("バックアップから復元") { importing = true }
                    Text("復元すると現在の記録を置き換えます。Webの記録とは独立しています。")
                }
                Section("音声") {
                    NavigationLink { AudioSettingsView() } label: { Label("音声・同期", systemImage: "headphones") }
                }
                Section("記事の配信元") { Text(ArticleClient.baseURL.absoluteString).font(.caption) }
            }.navigationTitle("設定")
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
            .confirmationDialog("現在の記録をバックアップで置き換えますか？", isPresented: $confirm, titleVisibility: .visible) {
                Button("置き換えて復元", role: .destructive) {
                    do { if let pending { try store.restore(pending) }; pending = nil }
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
