import SwiftUI

struct ArticleDiscovery {
    static func dayKey(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    static func pickupCandidates(_ articles: [Article], tag: String) -> [Article] {
        tag.isEmpty ? articles : articles.filter { $0.tags.contains(tag) }
    }
    static func picks(_ articles: [Article], day: String, shuffle: Int = 0) -> [Article] {
        let ranked = articles.map { article in
            (article: article, rank: ArticleClient.hash("\(day)/\(shuffle)/\(article.id)"))
        }
        return Array(ranked.sorted { $0.rank < $1.rank }.prefix(3).map(\.article))
    }
    static func folders(_ articles: [Article]) -> [String] {
        Array(Set(articles.flatMap { article -> [String] in
            let parts = article.folder.split(separator: "/")
            return (1...max(1, parts.count)).compactMap { parts.isEmpty ? nil : parts.prefix($0).joined(separator: "/") }
        })).sorted()
    }
    static func inFolder(_ article: Article, _ folder: String) -> Bool {
        folder.isEmpty || article.folder == folder || article.folder.hasPrefix(folder + "/")
    }
}

private struct ArticlePickRequest: Equatable {
    let articles: [Article]
    let day: String
    let shuffle: Int
}

@MainActor struct ArticleList: View {
    @Environment(\.studyTheme) private var design
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var search: SearchNavigation
    @AppStorage("study.pickupTag.v1") private var pickupTag = ""
    @State private var shuffle = 0
    @State private var day = ArticleDiscovery.dayKey()
    @State private var showCollections = false
    @State private var pickedArticles: [Article] = []
    var body: some View {
        let request = ArticlePickRequest(articles: ArticleDiscovery.pickupCandidates(library.articles, tag: pickupTag), day: day, shuffle: shuffle)
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if library.offlineCatalog { Label("保存した記事一覧", systemImage: "wifi.slash").font(.caption).foregroundStyle(.secondary) }
                    if library.loading { ProgressView("記事を更新中").frame(maxWidth: .infinity) }
                    if let error = library.error {
                        Text(error).foregroundStyle(.red)
                        Button("再試行") { Task { await library.reload() } }
                    }
                    HStack {
                        Text("今日のピックアップ").font(.subheadline.weight(.semibold))
                        Spacer()
                        Button { shuffle += 1 } label: { Image(systemName: "shuffle").frame(width: 44, height: 44) }.accessibilityLabel("別の記事を選ぶ")
                    }
                    Picker("ピックアップ対象", selection: $pickupTag) {
                        Text("すべてのタグ").tag("")
                        ForEach(Array(Set(library.articles.flatMap(\.tags))).sorted(), id: \.self) { Text($0).tag($0) }
                        if !pickupTag.isEmpty && !library.articles.contains(where: { $0.tags.contains(pickupTag) }) {
                            Text(pickupTag + "（現在の記事なし）").tag(pickupTag)
                        }
                    }.font(.footnote)
                    if pickedArticles.isEmpty && !library.loading && !pickupTag.isEmpty {
                        Text("このタグの記事はありません。対象を変更してください。").font(.caption).foregroundStyle(.secondary)
                    }
                    ArticleCarousel(articles: pickedArticles).id(day + "/" + String(shuffle))
                    let favorites = library.articles.filter { store.isFavorite($0.id) }
                    if !favorites.isEmpty {
                        HStack {
                            Text("お気に入り").font(.subheadline.weight(.semibold))
                            Spacer()
                            Button("すべて") { search.open(favorites: true) }.font(.footnote)
                        }
                        ArticleCarousel(articles: favorites)
                    }
                    HStack(spacing: 12) {
                        Button { search.open() } label: { homeEntry("検索", icon: "magnifyingglass", subtitle: "記事・音声・番組") }
                        Button { showCollections = true } label: { homeEntry("コレクション", icon: "square.stack", subtitle: "自分の本棚") }
                    }.buttonStyle(.plain)
                    if library.articles.isEmpty && !library.loading && library.error == nil {
                        ContentUnavailableView("記事がありません", systemImage: "books.vertical", description: Text("下に引っ張って一覧を更新してください。"))
                    }
                }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
            }.background { StudyBackdrop() }
                .navigationTitle("Learnleaf").navigationBarTitleDisplayMode(.inline)
                .refreshable { await library.reload() }
                .task(id: request) {
                    let selected = await Task.detached(priority: .userInitiated) {
                        ArticleDiscovery.picks(request.articles, day: request.day, shuffle: request.shuffle)
                    }.value
                    guard !Task.isCancelled else { return }
                    pickedArticles = selected
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    let next = ArticleDiscovery.dayKey()
                    if next != day { day = next; shuffle = 0 }
                }
                .sheet(isPresented: $showCollections) { NavigationStack { CollectionsView() } }
        }
    }
    private func homeEntry(_ title: String, icon: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(design.accent)
            Spacer(minLength: 8)
            Text(title).font(.footnote.bold()).foregroundStyle(.primary)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading).aspectRatio(1, contentMode: .fit)
            .background { StudyTileSurface() }
    }
}

@MainActor struct ArticleCard: View {
    @Environment(\.studyTheme) private var design
    let article: Article
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var audio: AudioLibraryModel
    @State private var showSave = false
    var body: some View {
        NavigationLink { ArticleReader(article: article) } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(article.folder).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    if store.isFavorite(article.id) { Image(systemName: "bookmark.fill").foregroundStyle(design.violet).accessibilityLabel("お気に入り") }
                    if audio.index.tracks.contains(where: { $0.manifest.articleID == article.id }) { Image(systemName: "headphones").foregroundStyle(design.accent).accessibilityLabel("音声あり") }
                }
                Text(article.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text(article.tags.prefix(2).map { "#" + $0 }.joined(separator: "  ")).lineLimit(1)
                    Spacer(minLength: 8)
                    if store.data.progress[article.id]?.completed == true { Label("読了", systemImage: "checkmark.circle.fill") }
                    else if store.data.progress[article.id]?.lastViewedAt != nil { Text("途中") }
                }.font(.caption).foregroundStyle(design.accent)
            }.padding(16).background { StudyTileSurface() }
        }.buttonStyle(.plain)
        .contextMenu {
            Button(store.isFavorite(article.id) ? "お気に入りを解除" : "お気に入りに保存", systemImage: "bookmark") { store.toggleFavorite(article.id) }
            Button("コレクションに保存", systemImage: "square.stack") { showSave = true }
        }
        .sheet(isPresented: $showSave) { SaveArticleView(article: article) }
    }
}

@MainActor struct ArticleResults: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var store: StudyStore
    var query = ""
    var tag = ""
    var folder = ""
    var favoritesOnly = false
    var collectionID: UUID? = nil
    @State private var unreadOnly = false
    var articles: [Article] {
        library.articles.filter { a in
            ArticleDiscovery.inFolder(a, folder) && (tag.isEmpty || a.tags.contains(tag)) &&
            (!favoritesOnly || store.isFavorite(a.id)) &&
            (collectionID == nil || store.data.collections?.first(where: { $0.id == collectionID })?.articleIDs.contains(a.id) == true) &&
            (!unreadOnly || store.data.progress[a.id]?.completed != true) &&
            (query.isEmpty || ([a.title] + a.tags + a.aliases).contains { $0.localizedCaseInsensitiveContains(query) })
        }
    }
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(articles.count)記事").font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Toggle("未読了のみ", isOn: $unreadOnly).toggleStyle(.button).font(.caption)
            }
            ForEach(articles) { a in
                ArticleCard(article: a)
                    .contextMenu {
                        Button(store.isFavorite(a.id) ? "お気に入りを解除" : "お気に入りに保存") { store.toggleFavorite(a.id) }
                        if let collectionID {
                            Button("このコレクションから外す", role: .destructive) { store.toggleMembership(a.id, collectionID: collectionID) }
                        }
                    }
            }
            if articles.isEmpty { ContentUnavailableView("対象の記事がありません", systemImage: "magnifyingglass", description: Text("検索条件を変えるか、記事を保存してください。")) }
        }
    }
}

@MainActor struct ArticleResultsScreen: View {
    @Environment(\.studyTheme) private var design
    let title: String
    var tag = ""
    var folder = ""
    var favoritesOnly = false
    var collectionID: UUID? = nil
    @EnvironmentObject private var search: SearchNavigation
    var body: some View {
        ScrollView {
            ArticleResults(tag: tag, folder: folder, favoritesOnly: favoritesOnly, collectionID: collectionID)
                .padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background { StudyBackdrop() }.navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline).toolbar { Button { search.open(tag: tag, folder: folder, favorites: favoritesOnly, collection: collectionID) } label: { Image(systemName: "magnifyingglass") }.accessibilityLabel("この条件で検索") }
    }
}

@MainActor struct TagBrowser: View {
    @Environment(\.studyTheme) private var design
    @EnvironmentObject private var library: Library
    @State private var query = ""
    private var tags: [String] { Array(Set(library.articles.flatMap(\.tags))).sorted().filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TagFlow {
                    ForEach(tags, id: \.self) { tag in
                        NavigationLink { ArticleResultsScreen(title: tag, tag: tag) } label: {
                            TagPill(text: "\(tag) · \(library.articles.filter { $0.tags.contains(tag) }.count)")
                        }
                    }
                }
                if tags.isEmpty { ContentUnavailableView.search(text: query) }
            }.padding(20).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
        }.background { StudyBackdrop() }.navigationTitle("タグ").searchable(text: $query, prompt: "タグを探す")
    }
}

@MainActor struct FolderBrowser: View {
    @Environment(\.studyTheme) private var design
    @EnvironmentObject private var library: Library
    var body: some View {
        List {
            Group {
                ForEach(ArticleDiscovery.folders(library.articles).filter { !$0.contains("/") }, id: \.self) { FolderBranch(path: $0) }
            }.listRowBackground(design.surface)
        }
        .scrollContentBackground(.hidden)
        .background { StudyBackdrop() }.navigationTitle("フォルダ")
    }
}

@MainActor struct FolderBranch: View {
    let path: String
    @EnvironmentObject private var library: Library
    private var children: [String] { ArticleDiscovery.folders(library.articles).filter { $0.hasPrefix(path + "/") && $0.split(separator: "/").count == path.split(separator: "/").count + 1 } }
    @AppStorage private var expanded: Bool
    init(path: String) {
        self.path = path
        _expanded = AppStorage(wrappedValue: false, "folder-expanded/" + path)
    }
    var body: some View {
        if children.isEmpty { destination }
        else {
            DisclosureGroup(isExpanded: $expanded) {
                destination
                ForEach(children, id: \.self) { child in FolderBranch(path: child) }
            } label: { Label(path.split(separator: "/").last.map(String.init) ?? path, systemImage: "folder") }
        }
    }
    private var destination: some View {
        NavigationLink { ArticleResultsScreen(title: path, folder: path) } label: {
            HStack {
                Label(children.isEmpty ? (path.split(separator: "/").last.map(String.init) ?? path) : "このフォルダのすべて", systemImage: "folder")
                Spacer()
                Text("\(library.articles.filter { ArticleDiscovery.inFolder($0, path) }.count)").foregroundStyle(.secondary)
            }
        }
    }
}

@MainActor struct CollectionsView: View {
    @Environment(\.studyTheme) private var design
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var library: Library
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var showName = false
    @State private var editing: UUID?
    @State private var deleting: ArticleCollection?
    var body: some View {
        List {
            Group {
                Section {
                    NavigationLink { ArticleResultsScreen(title: "お気に入り", favoritesOnly: true) } label: { Label("お気に入り", systemImage: "bookmark.fill") }
                }
                Section("自分のコレクション") {
                    ForEach(store.data.collections ?? []) { collection in
                        NavigationLink {
                            CollectionDetail(collectionID: collection.id)
                        } label: {
                            HStack {
                                Label(collection.name, systemImage: "square.stack")
                                Spacer()
                                Text("\(library.articles.filter { collection.articleIDs.contains($0.id) }.count)").foregroundStyle(.secondary)
                            }
                        }.swipeActions {
                            Button("削除", role: .destructive) { deleting = collection }
                            Button("名前変更") { editing = collection.id; name = collection.name; showName = true }.tint(design.accent)
                        }
                    }
                    Button("コレクションを作る", systemImage: "plus") { editing = nil; name = ""; showName = true }
                    Text("記事画面の保存ボタンから追加できます。記事の原本やフォルダは変更しません。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.listRowBackground(design.surface)
        }
        .scrollContentBackground(.hidden)
        .background { StudyBackdrop() }.navigationTitle("自分の本棚")
            .toolbar { Button("閉じる") { dismiss() } }
            .alert(editing == nil ? "新しいコレクション" : "名前を変更", isPresented: $showName) {
                TextField("名前", text: $name)
                Button("保存") { if let editing { store.renameCollection(editing, name: name) } else { store.createCollection(name) } }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("キャンセル", role: .cancel) { }
            }
            .confirmationDialog("コレクションを削除しますか？記事と学習記録は残ります。", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("コレクションを削除", role: .destructive) { if let deleting { store.deleteCollection(deleting.id) }; deleting = nil }
            }
    }
}

@MainActor struct CollectionDetail: View {
    let collectionID: UUID
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var audio: AudioLibraryModel
    @State private var adding = false
    private var collection: ArticleCollection? { store.data.collections?.first { $0.id == collectionID } }
    var body: some View {
        ArticleResultsScreen(title: collection?.name ?? "コレクション", collectionID: collectionID)
            .toolbar {
                Button("記事を追加", systemImage: "plus") { adding = true }
                NavigationLink { CollectionListeningView(articleIDs: Set(collection?.articleIDs ?? [])) } label: {
                    Label("関連する音声", systemImage: "headphones")
                }
            }
            .sheet(isPresented: $adding) { NavigationStack { CollectionArticlePicker(collectionID: collectionID) } }
    }
}

@MainActor struct CollectionArticlePicker: View {
    @Environment(\.studyTheme) private var design
    let collectionID: UUID
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var library: Library
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    var body: some View {
        List(library.articles.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }) { article in
            Group {
                Button { store.toggleMembership(article.id, collectionID: collectionID) } label: {
                    HStack {
                        Text(article.title).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: store.data.collections?.first(where: { $0.id == collectionID })?.articleIDs.contains(article.id) == true ? "checkmark.circle.fill" : "circle")
                    }
                }
            }.listRowBackground(design.surface)
        }
        .scrollContentBackground(.hidden)
        .background { StudyBackdrop() }.navigationTitle("記事を追加").searchable(text: $query).toolbar { Button("完了") { dismiss() } }
    }
}

@MainActor struct SaveArticleView: View {
    @Environment(\.studyTheme) private var design
    let article: Article
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    var body: some View {
        NavigationStack {
            List {
                Group {
                    Button { store.toggleFavorite(article.id) } label: {
                        Label(store.isFavorite(article.id) ? "お気に入りに保存済み" : "お気に入りに保存", systemImage: store.isFavorite(article.id) ? "bookmark.fill" : "bookmark")
                    }
                    Section("コレクション") {
                        ForEach(store.data.collections ?? []) { c in
                            Button { store.toggleMembership(article.id, collectionID: c.id) } label: {
                                HStack {
                                    Text(c.name).foregroundStyle(.primary); Spacer()
                                    Image(systemName: c.articleIDs.contains(article.id) ? "checkmark.circle.fill" : "circle")
                                }
                            }
                        }
                        HStack {
                            TextField("新しいコレクション", text: $name)
                            Button("作成して保存") { store.createCollection(name, adding: article.id); name = "" }
                                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }.listRowBackground(design.surface)
            }
            .scrollContentBackground(.hidden)
            .background { StudyBackdrop() }.navigationTitle("記事を保存").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("完了") { dismiss() } }
        }
    }
}

@MainActor struct CollectionListeningView: View {
    let articleIDs: Set<String>
    @EnvironmentObject private var audio: AudioLibraryModel
    var body: some View {
        List {
            Section("番組") {
                ForEach(RelatedContent.programs(articleIDs: articleIDs, audio: audio.index)) { program in
                    NavigationLink { ProgramDetailView(programID: program.id) } label: { Text(program.title) }
                }
            }
            Section("音声") {
                ForEach(audio.index.tracks.filter { articleIDs.contains($0.manifest.articleID) }) { track in
                    NavigationLink { LinkedAudioPlayer(track: track) } label: { Text(track.manifest.title) }
                }
                if !audio.index.tracks.contains(where: { articleIDs.contains($0.manifest.articleID) }) {
                    Text("このコレクションの音声はまだありません。").foregroundStyle(.secondary)
                }
            }
        }.navigationTitle("コレクションを聴く").navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden).background { StudyBackdrop() }
    }
}
