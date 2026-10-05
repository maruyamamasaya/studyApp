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
    static func picks(_ articles: [Article], day: String, shuffle: Int = 0) -> [Article] {
        Array(articles.sorted {
            ArticleClient.hash("\(day)/\(shuffle)/\($0.id)") < ArticleClient.hash("\(day)/\(shuffle)/\($1.id)")
        }.prefix(3))
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

@MainActor struct ArticleList: View {
    @EnvironmentObject private var library: Library
    @EnvironmentObject private var store: StudyStore
    @State private var query = ""
    @State private var shuffle = 0
    @State private var day = ArticleDiscovery.dayKey()
    @State private var showCollections = false
    private var recent: Article? {
        library.articles.filter { store.data.progress[$0.id]?.lastViewedAt != nil }
            .max { (store.data.progress[$0.id]?.lastViewedAt ?? .distantPast) < (store.data.progress[$1.id]?.lastViewedAt ?? .distantPast) }
    }
    private var tags: [String] {
        Array(Set(library.articles.flatMap(\.tags))).sorted { a, b in
            let ac = library.articles.filter { $0.tags.contains(a) }.count
            let bc = library.articles.filter { $0.tags.contains(b) }.count
            return ac == bc ? a < b : ac > bc
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if library.loading { ProgressView("記事を更新中").frame(maxWidth: .infinity) }
                    if let error = library.error {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(error).foregroundStyle(.red)
                            Button("再試行") { Task { await library.reload() } }
                        }.padding().background(StudyDesign.surface, in: RoundedRectangle(cornerRadius: 18))
                    }
                    if !query.isEmpty {
                        ArticleResults(query: query)
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("タグから探す").font(.subheadline.weight(.semibold))
                                Spacer()
                                NavigationLink("すべて") { TagBrowser() }.font(.footnote)
                            }
                            TagFlow {
                                ForEach(Array(tags.prefix(10)), id: \.self) { tag in
                                    NavigationLink { ArticleResultsScreen(title: tag, tag: tag) } label: { TagPill(text: tag) }
                                }
                            }
                        }
                        if let recent {
                            Text("前回の記事").font(.subheadline.weight(.semibold))
                            NavigationLink { ArticleReader(article: recent) } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    Label(store.data.progress[recent.id]?.completed == true ? "もう一度読む" : "続きを読む", systemImage: "arrow.turn.down.right").font(.caption.weight(.semibold))
                                    Text(recent.title).font(.subheadline.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
                                    ArticleExcerpt(article: recent, onGradient: true, compact: true)
                                    Text("\(Int(store.seconds(for: recent.id) / 60))分の学習 · \(recent.folder)").font(.caption).opacity(0.85)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
                                    .foregroundStyle(.white).background(StudyDesign.gradient, in: RoundedRectangle(cornerRadius: 18))
                            }.buttonStyle(.plain)
                        }
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("今日のピックアップ").font(.subheadline.weight(.semibold))
                                Spacer()
                                Button { shuffle += 1 } label: { Image(systemName: "shuffle").padding(10) }.accessibilityLabel("別の記事を選ぶ")
                            }
                            ArticleCarousel(articles: ArticleDiscovery.picks(library.articles, day: day, shuffle: shuffle))
                                .id(day + "/" + String(shuffle))
                        }
                        if !library.articles.filter({ store.isFavorite($0.id) }).isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("お気に入り").font(.subheadline.weight(.semibold))
                                    Spacer()
                                    NavigationLink("すべて") { ArticleResultsScreen(title: "お気に入り", favoritesOnly: true) }.font(.footnote)
                                }
                                ArticleCarousel(articles: library.articles.filter { store.isFavorite($0.id) })
                            }
                        }
                        HStack(spacing: 12) {
                            NavigationLink { FolderBrowser() } label: { entry("フォルダ", icon: "folder", subtitle: "階層から探す") }
                            Button { showCollections = true } label: { entry("コレクション", icon: "square.stack", subtitle: "自分の本棚") }
                        }.buttonStyle(.plain)
                        HStack {
                            NavigationLink { ArticleResultsScreen(title: "お気に入り", favoritesOnly: true) } label: { Label("お気に入り", systemImage: "bookmark") }
                            Spacer()
                            NavigationLink { ArticleResultsScreen(title: "すべての記事") } label: { Text("すべての記事 →") }
                        }.font(.footnote.weight(.medium))
                        if library.articles.isEmpty && !library.loading && library.error == nil {
                            ContentUnavailableView("記事がありません", systemImage: "books.vertical", description: Text("下に引っ張って一覧を更新してください。"))
                        }
                    }
                }.padding(20).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity).padding(.bottom, 20)
            }
            .background(StudyDesign.background)
            .navigationTitle("Learnleaf").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "タイトル・タグ・別名を探す")
            .refreshable { await library.reload() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                let next = ArticleDiscovery.dayKey()
                if next != day { day = next; shuffle = 0 }
            }
            .sheet(isPresented: $showCollections) { NavigationStack { CollectionsView() } }
        }
    }
    private func entry(_ title: String, icon: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.title2).foregroundStyle(StudyDesign.accent)
            Text(title).font(.footnote.bold()).foregroundStyle(.primary)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(StudyDesign.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}

@MainActor struct ArticleCard: View {
    let article: Article
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var audio: AudioLibraryModel
    var body: some View {
        NavigationLink { ArticleReader(article: article) } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(article.folder).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    if store.isFavorite(article.id) { Image(systemName: "bookmark.fill").foregroundStyle(StudyDesign.violet).accessibilityLabel("お気に入り") }
                    if audio.index.tracks.contains(where: { $0.manifest.articleID == article.id }) { Image(systemName: "headphones").foregroundStyle(StudyDesign.accent).accessibilityLabel("音声あり") }
                }
                Text(article.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                ArticleExcerpt(article: article)
                HStack {
                    Text(article.tags.prefix(2).map { "#" + $0 }.joined(separator: "  ")).lineLimit(1)
                    Spacer(minLength: 8)
                    if store.data.progress[article.id]?.completed == true { Label("読了", systemImage: "checkmark.circle.fill") }
                    else if store.data.progress[article.id]?.lastViewedAt != nil { Text("途中") }
                }.font(.caption).foregroundStyle(StudyDesign.accent)
            }.padding(16).background(StudyDesign.surface, in: RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain)
        .contextMenu {
            Button(store.isFavorite(article.id) ? "お気に入りを解除" : "お気に入りに保存", systemImage: "bookmark") { store.toggleFavorite(article.id) }
        }
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
    let title: String
    var tag = ""
    var folder = ""
    var favoritesOnly = false
    var collectionID: UUID? = nil
    @State private var query = ""
    var body: some View {
        ScrollView {
            ArticleResults(query: query, tag: tag, folder: folder, favoritesOnly: favoritesOnly, collectionID: collectionID)
                .padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(StudyDesign.background).navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline).searchable(text: $query, prompt: "この中から探す")
    }
}

@MainActor struct TagBrowser: View {
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
        }.background(StudyDesign.background).navigationTitle("タグ").searchable(text: $query, prompt: "タグを探す")
    }
}

@MainActor struct FolderBrowser: View {
    @EnvironmentObject private var library: Library
    var body: some View {
        List {
            ForEach(ArticleDiscovery.folders(library.articles).filter { !$0.contains("/") }, id: \.self) { FolderBranch(path: $0) }
        }.navigationTitle("フォルダ")
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
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var library: Library
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var showName = false
    @State private var editing: UUID?
    @State private var deleting: ArticleCollection?
    var body: some View {
        List {
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
                        Button("名前変更") { editing = collection.id; name = collection.name; showName = true }.tint(StudyDesign.accent)
                    }
                }
                Button("コレクションを作る", systemImage: "plus") { editing = nil; name = ""; showName = true }
                Text("記事画面の保存ボタンから追加できます。記事の原本やフォルダは変更しません。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("自分の本棚")
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
    @State private var adding = false
    private var collection: ArticleCollection? { store.data.collections?.first { $0.id == collectionID } }
    var body: some View {
        ArticleResultsScreen(title: collection?.name ?? "コレクション", collectionID: collectionID)
            .toolbar { Button("記事を追加", systemImage: "plus") { adding = true } }
            .sheet(isPresented: $adding) { NavigationStack { CollectionArticlePicker(collectionID: collectionID) } }
    }
}

@MainActor struct CollectionArticlePicker: View {
    let collectionID: UUID
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var library: Library
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    var body: some View {
        List(library.articles.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }) { article in
            Button { store.toggleMembership(article.id, collectionID: collectionID) } label: {
                HStack {
                    Text(article.title).foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: store.data.collections?.first(where: { $0.id == collectionID })?.articleIDs.contains(article.id) == true ? "checkmark.circle.fill" : "circle")
                }
            }
        }.navigationTitle("記事を追加").searchable(text: $query).toolbar { Button("完了") { dismiss() } }
    }
}

@MainActor struct SaveArticleView: View {
    let article: Article
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    var body: some View {
        NavigationStack {
            List {
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
                        Button("作成") { store.createCollection(name); name = "" }
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }.navigationTitle("記事を保存").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("完了") { dismiss() } }
        }
    }
}
