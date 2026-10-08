import SwiftUI

@MainActor final class SearchNavigation: ObservableObject {
    @Published var tab = 0
    @Published var showingSearch = false
    @Published var query = ""
    @Published var target = "すべて"
    @Published var tag = ""
    @Published var folder = ""
    @Published var favorites = false
    @Published var collection: UUID?
    @Published var state = "すべて"
    @Published var audioOnly = false
    @Published var order = "標準"
    @Published private(set) var preferences = SearchPreferences()
    private let defaults: UserDefaults
    private let key = "study.searchPreferences.v1"
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key), let value = try? JSONDecoder().decode(SearchPreferences.self, from: data) { preferences = value }
    }
    var conditions: SearchConditions {
        SearchConditions(query: query, target: target, tag: tag, folder: folder, favorites: favorites,
                         collection: collection, state: state, audioOnly: audioOnly, order: order)
    }
    func apply(_ value: SearchConditions) {
        query = value.query; target = value.target; tag = value.tag; folder = value.folder
        favorites = value.favorites; collection = value.collection; state = value.state
        audioOnly = value.audioOnly; order = value.order
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: key) }
    }
    func remember() { preferences.remember(conditions); persist() }
    func save(_ name: String) {
        let name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !name.isEmpty else { return }
        preferences.saved.append(SavedSearch(name: name, conditions: conditions)); persist()
    }
    func remove(_ id: UUID) { preferences.saved.removeAll { $0.id == id }; persist() }
    func clearHistory() { preferences.history = []; persist() }
    func open(tag: String = "", folder: String = "", favorites: Bool = false, collection: UUID? = nil) {
        reset()
        self.tag = tag; self.folder = folder; self.favorites = favorites; self.collection = collection
        target = "記事"; tab = 0; showingSearch = true
    }
    func reset() {
        query = ""; target = "すべて"; tag = ""; folder = ""; favorites = false
        collection = nil; state = "すべて"; audioOnly = false; order = "標準"
    }
}

@MainActor struct SearchView: View {
    @EnvironmentObject private var visualResources: VisualResourceModel
    @Environment(\.studyTheme) private var design
    @EnvironmentObject private var search: SearchNavigation
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var audio: AudioLibraryModel
    @EnvironmentObject private var player: TrackPlayer
    @State private var saveName = ""
    @State private var showSaveSearch = false
    @State private var showPlayer = false
    @State private var bodies: [String: String] = [:]
    @State private var bodyTask: Task<Void, Never>?
    @State private var bodyQuery = ""
    @State private var scanning = false
    @State private var scanID = UUID()
    @State private var scanned = 0
    @State private var failures = 0
    private var tags: [String] { Array(Set(library.articles.flatMap(\.tags))).sorted() }
    private var keyword: String { search.query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private func results() -> SearchEngine.Results {
        SearchEngine.results(articles: library.articles, audio: audio.index, records: store.data,
                             search: search.conditions, bodies: bodies, bodyQuery: bodyQuery)
    }
    private var hasArticleFilters: Bool { !search.tag.isEmpty || !search.folder.isEmpty || search.favorites || search.collection != nil || search.audioOnly }
    private var showArticles: Bool { search.target == "すべて" || search.target == "記事" }
    private var showTracks: Bool { search.target == "すべて" || search.target == "音声" }
    private var showPrograms: Bool { search.target == "すべて" || search.target == "番組" }
    private var showResources: Bool { search.target == "すべて" || search.target == "資料" }
    private var resourceResults: [VisualResource] {
        visualResources.resources.filter { resource in
            let linked = library.articles.filter { resource.articleIDs.contains($0.id) }
            let text = ([resource.title, resource.originalName, resource.category] + resource.tags).joined(separator: " ")
            guard keyword.isEmpty || text.localizedCaseInsensitiveContains(keyword) else { return false }
            guard search.tag.isEmpty || resource.tags.contains(search.tag) || linked.contains(where: { $0.tags.contains(search.tag) }) else { return false }
            guard search.folder.isEmpty || linked.contains(where: { $0.folder == search.folder || $0.folder.hasPrefix(search.folder + "/") }) else { return false }
            guard !search.favorites || resource.favorite else { return false }
            if let id = search.collection {
                let ids = store.data.collections?.first(where: { $0.id == id })?.articleIDs ?? []
                guard resource.articleIDs.contains(where: ids.contains) else { return false }
            }
            if search.state != "すべて" {
                guard linked.contains(where: { (store.data.progress[$0.id]?.completed == true) == (search.state == "完了") }) else { return false }
            }
            if search.audioOnly {
                guard audio.index.tracks.contains(where: { resource.articleIDs.contains($0.manifest.articleID) }) else { return false }
            }
            return true
        }
    }
    var body: some View {
        let result = results()
        let articles = result.articles, tracks = result.tracks, programs = result.programs
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    filters
                    savedSearches
                    if let error = library.error {
                        Text(error).foregroundStyle(.red)
                        Button("記事一覧を再取得") { Task { await library.reload() } }
                    }
                    if library.loading { ProgressView("記事一覧を取得中") }
                    if showArticles && !keyword.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            if scanning {
                                ProgressView("本文を検索中 · \(scanned)記事確認")
                                Button("取消") { bodyTask?.cancel() }
                            } else {
                                Button("記事本文も検索") { searchBodies() }
                                Text("保存済み本文は通信なしで検索できます。未保存の本文は取得します。音声は台本も検索します。")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if !bodyQuery.isEmpty && bodyQuery == keyword {
                                Text("本文確認 \(scanned)記事 · 取得失敗 \(failures)記事")
                                    .font(.caption).foregroundStyle(failures > 0 ? .orange : .secondary)
                            }
                        }
                    }
                    let count = (showArticles ? articles.count : 0) + (showTracks ? tracks.count : 0) + (showPrograms ? programs.count : 0) + (showResources ? resourceResults.count : 0)
                    Text("\(count)件").font(.footnote).foregroundStyle(.secondary)
                    if showArticles && !articles.isEmpty {
                        Text("記事 · \(articles.count)").font(.subheadline.bold())
                        LazyVStack(spacing: 12) { ForEach(articles) { ArticleCard(article: $0) } }
                    }
                    if showTracks && !tracks.isEmpty {
                        Text("音声 · \(tracks.count)").font(.subheadline.bold())
                        ForEach(tracks) { track in
                            Button { player.play(track); showPlayer = true } label: {
                                searchRow(track.manifest.title, subtitle: track.isListened ? "聴取済み" : "未聴取", icon: "headphones")
                            }.buttonStyle(.plain)
                        }
                    }
                    if showPrograms && !programs.isEmpty {
                        Text("番組 · \(programs.count)").font(.subheadline.bold())
                        ForEach(programs) { program in
                            NavigationLink { ProgramDetailView(programID: program.id) } label: {
                                searchRow(program.title, subtitle: "\(program.trackIDs.count)本", icon: "play.rectangle")
                            }.buttonStyle(.plain)
                        }
                    }
                    if showResources {
                        NavigationLink("図解・資料を登録・管理") { VisualLibraryView() }
                        ForEach(resourceResults) { resource in
                            NavigationLink { VisualResourceDetail(id: resource.id) } label: {
                                searchRow(resource.title, subtitle: resource.kind.title, icon: "doc.richtext")
                            }
                        }
                    }
                    if count == 0 && !library.loading {
                        ContentUnavailableView("対象がありません", systemImage: "magnifyingglass", description: Text("キーワードや絞り込み条件を変更してください。"))
                    }
                }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
            }.background { StudyBackdrop() }
                .navigationTitle("検索").navigationBarTitleDisplayMode(.inline)
                .searchable(text: $search.query, prompt: "記事・音声・番組・資料を検索")
                .toolbar {
                    Button("条件を保存", systemImage: "bookmark") { saveName = ""; showSaveSearch = true }
                    Button("リセット") { bodyTask?.cancel(); bodyQuery = ""; search.reset() }
                }
                .alert("検索条件を保存", isPresented: $showSaveSearch) {
                    TextField("名前", text: $saveName)
                    Button("保存") { search.save(saveName) }.disabled(saveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("キャンセル", role: .cancel) { }
                }
                .onSubmit(of: .search) { search.remember() }
                .navigationDestination(isPresented: $showPlayer) { AudioPlayerView() }
                .onChange(of: search.conditions) { _, _ in bodyTask?.cancel(); scanID = UUID(); scanning = false; bodyQuery = "" }
                .onDisappear { bodyTask?.cancel() }
        }
    }
    private var filters: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("検索対象", selection: $search.target) {
                ForEach(["すべて", "記事", "音声", "番組", "資料"], id: \.self) { Text($0) }
            }.pickerStyle(.segmented)
            HStack {
                Text("並び順")
                Spacer()
                Picker("並び順", selection: $search.order) {
                    Text("標準").tag("標準")
                    Text("タイトル").tag("タイトル")
                    Text("記事の新しい順").tag("新しい順")
                }.labelsHidden()
            }.font(.footnote)
            Button("この検索条件を保存", systemImage: "bookmark") {
                saveName = ""; showSaveSearch = true
            }.font(.footnote)
            DisclosureGroup("詳細条件") {
                VStack(spacing: 12) {
                    HStack {
                        Text("タグ")
                        Spacer()
                        Picker("タグ", selection: $search.tag) {
                        Text("すべて").tag("")
                        ForEach(tags, id: \.self) { Text($0).tag($0) }
                        }.labelsHidden()
                    }
                    HStack {
                        Text("フォルダ")
                        Spacer()
                        Picker("フォルダ", selection: $search.folder) {
                        Text("すべて").tag("")
                        ForEach(ArticleDiscovery.folders(library.articles), id: \.self) { Text($0).tag($0) }
                        }.labelsHidden()
                    }
                    HStack {
                        Text("コレクション")
                        Spacer()
                        Picker("コレクション", selection: $search.collection) {
                        Text("すべて").tag(nil as UUID?)
                        ForEach(store.data.collections ?? []) { Text($0.name).tag(Optional($0.id)) }
                        }.labelsHidden()
                    }
                    HStack {
                        Text("読了・聴取状態")
                        Spacer()
                        Picker("読了・聴取状態", selection: $search.state) {
                        Text("すべて").tag("すべて")
                        Text("未読了・未聴取").tag("未完了")
                        Text("読了・聴取済み").tag("完了")
                        }.labelsHidden()
                    }
                    Toggle("お気に入りの記事に関連するもの", isOn: $search.favorites)
                    Toggle("音声がある記事に関連するもの", isOn: $search.audioOnly)
                }.font(.footnote).padding(.top, 12)
            }
            if hasArticleFilters || search.state != "すべて" {
                TagFlow {
                    if !search.tag.isEmpty { conditionChip(search.tag) { search.tag = "" } }
                    if !search.folder.isEmpty { conditionChip(search.folder) { search.folder = "" } }
                    if search.favorites { conditionChip("お気に入り") { search.favorites = false } }
                    if let id = search.collection { conditionChip(store.data.collections?.first(where: { $0.id == id })?.name ?? "削除されたコレクション") { search.collection = nil } }
                    if search.audioOnly { conditionChip("音声あり") { search.audioOnly = false } }
                    if search.state != "すべて" { conditionChip(search.state == "完了" ? "読了・聴取済み" : "未読了・未聴取") { search.state = "すべて" } }
                }
            }
        }.padding(16).background { StudyTileSurface() }
    }
    private func conditionChip(_ text: String, clear: @escaping () -> Void) -> some View {
        Button(action: clear) { TagPill(text: text + " ×") }.accessibilityLabel(text + "の条件を解除")
    }
    private var savedSearches: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !search.preferences.saved.isEmpty {
                DisclosureGroup("保存した検索 · \(search.preferences.saved.count)") {
                    ForEach(search.preferences.saved) { saved in
                        HStack {
                            Button(saved.name) { search.apply(saved.conditions) }
                            Spacer()
                            Button { search.remove(saved.id) } label: { Image(systemName: "trash") }.accessibilityLabel(saved.name + "を削除")
                        }.padding(.vertical, 6)
                    }
                }
            }
            if !search.preferences.history.isEmpty {
                DisclosureGroup("検索履歴") {
                    ForEach(Array(search.preferences.history.enumerated()), id: \.offset) { _, conditions in
                        Button(conditions.query + " · " + conditions.target) { search.apply(conditions) }.padding(.vertical, 6)
                    }
                    Button("履歴を消去") { search.clearHistory() }
                }
            }
        }.font(.footnote)
    }
    private func searchRow(_ title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(design.accent)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background { StudyTileSurface() }
    }
    private func searchBodies() {
        bodyTask?.cancel()
        search.remember()
        let query = keyword
        let audioArticles = Set(audio.index.tracks.map { $0.manifest.articleID })
        let collectionIDs = Set(store.data.collections?.first { $0.id == search.collection }?.articleIDs ?? [])
        let candidates = library.articles.filter { article in
            ArticleDiscovery.inFolder(article, search.folder) &&
            (search.tag.isEmpty || article.tags.contains(search.tag)) &&
            (!search.favorites || store.isFavorite(article.id)) &&
            (search.collection == nil || collectionIDs.contains(article.id)) &&
            (!search.audioOnly || audioArticles.contains(article.id))
        }
        let id = UUID(); scanID = id
        bodyQuery = query; scanned = 0; failures = 0; scanning = true
        bodyTask = Task { @MainActor in
            defer { if scanID == id { scanning = false } }
            for article in candidates {
                guard !Task.isCancelled, scanID == id else { return }
                do {
                    let body = try await library.content(article)
                    guard !Task.isCancelled, scanID == id else { return }
                    bodies[Library.cacheKey(article)] = ArticleLinks.body(body)
                } catch {
                    guard !Task.isCancelled, scanID == id else { return }
                    failures += 1
                }
                scanned += 1
            }
        }
    }
}
