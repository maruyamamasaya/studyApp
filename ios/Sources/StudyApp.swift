import SwiftUI
import MarkdownUI
import UniformTypeIdentifiers

@MainActor final class Library: ObservableObject {
    @Published var articles: [Article] = []
    @Published var error: String?
    @Published var loading = false
    let client = ArticleClient()
    func reload() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do { articles = try await client.catalog().articles; error = nil }
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
                ArticleList().tabItem { Label("記事", systemImage: "books.vertical") }
                NavigationStack { AudioView() }.tabItem { Label("聴く", systemImage: "headphones") }
                HistoryView().tabItem { Label("履歴", systemImage: "clock") }
                SettingsView().tabItem { Label("設定", systemImage: "gearshape") }
            }
            .environmentObject(library).environmentObject(store)
            .environmentObject(audio).environmentObject(player)
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { player.savePosition() }
                else { Task { await audio.refresh() } }
            }
            .task { await library.reload() }
            .task { await audio.refresh() }
            .alert("記録の保存エラー", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("閉じる") { store.error = nil }
            } message: { Text(store.error ?? "") }
        }
    }
}

@MainActor struct ArticleList: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var store: StudyStore
    @State private var query = ""
    @State private var folder = ""
    @State private var unreadOnly = false
    private var filtered: [Article] {
        library.articles.filter { article in
            (folder.isEmpty || article.folder == folder) &&
            (!unreadOnly || store.data.progress[article.id]?.completed != true) &&
            (query.isEmpty || ([article.title] + article.tags + article.aliases).contains { $0.localizedCaseInsensitiveContains(query) })
        }
    }
    var body: some View {
        NavigationStack {
            List {
                if library.loading { ProgressView("一覧を取得中") }
                if let error = library.error {
                    Text(error).foregroundStyle(.red)
                    Button("再試行") { Task { await library.reload() } }
                }
                Picker("フォルダ", selection: $folder) {
                    Text("すべて").tag("")
                    ForEach(Array(Set(library.articles.map(\.folder))).sorted(), id: \.self) { Text($0).tag($0) }
                }
                Toggle("未読了のみ", isOn: $unreadOnly)
                ForEach(filtered) { article in
                    NavigationLink(value: article) {
                        VStack(alignment: .leading, spacing: 5) {
                            Label(article.title, systemImage: store.data.progress[article.id]?.completed == true ? "checkmark.circle.fill" : "doc.text")
                            Text(article.folder).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if filtered.isEmpty && !library.loading && library.error == nil { Text("対象の記事がありません。") }
            }
            .navigationTitle("学習ノート")
            .searchable(text: $query, prompt: "タイトル・タグ・別名")
            .refreshable { await library.reload() }
            .navigationDestination(for: Article.self) { ArticleReader(article: $0) }
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
    private let pulse = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private var current: Article { library.articles.first(where: { $0.id == article.id }) ?? article }
    private var completed: Bool { store.data.progress[article.id]?.completed == true }
    private var running: Bool { visible && scenePhase == .active && markdown != nil && !completed }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(current.title).font(.title.bold())
                Text(current.tags.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                NavigationLink { AudioView(article: current) } label: { Label("この記事の音声", systemImage: "headphones") }
                Text("学習時間 \(Int(store.seconds(for: article.id) / 60))分")
                Button(completed ? "未読了に戻す" : "読了にする") {
                    timer.flush(articleID: article.id, store: store, resume: false)
                    store.toggle(article)
                    syncTimer()
                }
                if let markdown {
                    Markdown(markdown, baseURL: try? ArticleClient.url(for: current.path))
                        .environment(\.openURL, OpenURLAction { url in open(url) })
                } else if let error {
                    Text(error).foregroundStyle(.red)
                    Button("一覧を更新して再試行") { Task { await library.reload(); await load() } }
                } else { ProgressView("本文を取得中") }
            }.padding()
        }
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
            do { markdown = ArticleLinks.body(try await library.client.content(latest)) }
            catch ReaderError.mismatch {
                await library.reload()
                guard let updated = library.articles.first(where: { $0.id == article.id }) else { throw ReaderError.mismatch }
                markdown = ArticleLinks.body(try await library.client.content(updated))
            }
            try Task.checkCancellation()
            store.viewed(latest); syncTimer()
        } catch is CancellationError { markdown = nil }
        catch { error = error.localizedDescription }
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
    var body: some View {
        NavigationStack {
            List {
                Text("合計 \(Int(store.data.sessions.reduce(0) { $0 + $1.durationSeconds } / 60))分")
                ForEach(store.data.sessions.sorted { $0.startedAt > $1.startedAt }) { session in
                    VStack(alignment: .leading) {
                        Text(store.data.progress[session.articleId]?.title ?? session.articleId)
                        Text("\(session.startedAt.formatted()) · \(Int(session.durationSeconds))秒").font(.caption)
                    }
                }
            }.navigationTitle("学習履歴")
        }
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
                    Button("バックアップを書き出す") {
                        do { document = BackupDocument(data: try store.export()); export = true }
                        catch { message = error.localizedDescription }
                    }
                    Button("バックアップから復元") { importing = true }
                    Text("復元すると現在の記録を置き換えます。Webの記録とは独立しています。")
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
