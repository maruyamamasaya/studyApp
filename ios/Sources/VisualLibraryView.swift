import SwiftUI
import UniformTypeIdentifiers

enum VisualImportTypes {
    static var all: [UTType] { [UTType(filenameExtension: "svg"), .pdf,
        UTType(filenameExtension: "docx"), UTType(filenameExtension: "pptx"), .png, .jpeg].compactMap { $0 } }
}
@MainActor struct VisualLibraryView: View {
    var articleID: String?
    @EnvironmentObject private var model: VisualResourceModel
    @State private var query = ""
    @State private var kind = ""
    @State private var category = ""
    @State private var favorites = false
    @State private var importing = false
    @State private var selection = Set<UUID>()
    @State private var exported: URL?
    @State private var removeID: UUID?
    private var filtered: [VisualResource] {
        model.resources.filter {
            (articleID == nil || $0.articleIDs.contains(articleID!))
                && (kind.isEmpty || $0.kind.rawValue == kind)
                && (category.isEmpty || $0.category == category)
                && (!favorites || $0.favorite)
                && (query.isEmpty || ([$0.title, $0.originalName, $0.category] + $0.tags).joined(separator: " ").localizedCaseInsensitiveContains(query))
        }
    }
    var body: some View {
        List {
            Section {
                Text("取り込んだ資料はこの端末だけに保存します。記事・学習記録とは別のライブラリです。").font(.caption).foregroundStyle(.secondary)
                Picker("形式", selection: $kind) {
                    Text("すべて").tag("")
                    ForEach(ResourceKind.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                Picker("カテゴリ", selection: $category) {
                    Text("すべて").tag("")
                    ForEach(Array(Set(model.resources.map(\.category))).filter { !$0.isEmpty }.sorted(), id: \.self) { Text($0).tag($0) }
                }
                Toggle("保存した資料だけ", isOn: $favorites)
                if let status = model.status { Text(status).font(.caption) }
                if let exported { ShareLink("ZIPを共有・ファイルに保存", item: exported) }
                NavigationLink("利用ライブラリとライセンス") { VisualNoticesView() }
            }
            ForEach(filtered) { r in
                HStack {
                    if r.kind == .svg {
                        Button {
                            if selection.contains(r.id) { selection.remove(r.id) } else { selection.insert(r.id) }
                        } label: { Image(systemName: selection.contains(r.id) ? "checkmark.circle.fill" : "circle") }
                            .buttonStyle(.plain).accessibilityLabel("ZIP出力に選択")
                    }
                    NavigationLink { VisualResourceDetail(id: r.id) } label: {
                        HStack {
                            ResourceThumbnail(id: r.id).frame(width: 64, height: 64)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(r.title).font(.subheadline)
                                Text(r.kind.title + (r.category.isEmpty ? "" : " / " + r.category)).font(.caption).foregroundStyle(.secondary)
                                if r.favorite { Image(systemName: "bookmark.fill").font(.caption) }
                            }
                        }
                    }
                }.swipeActions {
                    Button("削除", role: .destructive) { removeID = r.id }
                }
            }
            if filtered.isEmpty { Text("資料はありません。右上からファイルを登録できます。").foregroundStyle(.secondary) }
        }
        .searchable(text: $query, prompt: "ファイル名・タイトル・タグ")
        .navigationTitle(articleID == nil ? "図解・資料" : "この記事の資料")
        .scrollContentBackground(.hidden).background { StudyBackdrop() }
        .toolbar {
            Button { importing = true } label: { Image(systemName: "plus") }.disabled(model.busy || !model.ready)
            if !selection.isEmpty {
                Button("ZIP") { Task {
                    do { exported = try await model.storage.exportZIP(Array(selection)) }
                    catch { model.error = error.localizedDescription }
                } }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: VisualImportTypes.all, allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): Task { await model.importFiles(urls, articleID: articleID) }
            case .failure(let error): model.error = error.localizedDescription
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard !model.busy, model.ready else { return false }
            Task { await model.importFiles(urls, articleID: articleID) }; return true
        }
        .confirmationDialog("資料をこの端末から削除しますか？スライドからの参照は未解決として残ります。", isPresented: Binding(get: { removeID != nil }, set: { if !$0 { removeID = nil } })) {
            Button("原本と派生を削除", role: .destructive) {
                if let removeID { Task { await model.remove(removeID) } }; removeID = nil
            }
        }
    }
}
private struct VisualNoticesView: View {
    var body: some View {
        ScrollView {
            Text(Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "txt")
                .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "ライセンス情報を読み込めません。")
                .font(.footnote).textSelection(.enabled).padding()
        }.navigationTitle("ライセンス")
    }
}
@MainActor struct ResourceThumbnail: View {
    let id: UUID
    @EnvironmentObject private var model: VisualResourceModel
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { Image(systemName: model.resource(id)?.kind == .presentation ? "rectangle.stack" : "doc.richtext").foregroundStyle(.secondary) }
        }.task(id: model.resource(id)?.thumbnailHash) {
            if let url = try? await model.storage.thumbnail(id) { image = UIImage(contentsOfFile: url.path) }
        }
    }
}
@MainActor struct VisualResourceDetail: View {
    let id: UUID
    var initialSlideID: UUID?
    @EnvironmentObject private var model: VisualResourceModel
    @EnvironmentObject private var library: Library
    @State private var url: URL?
    @State private var previewURL: URL?
    @State private var data: Data?
    @State private var showMetadata = false
    @State private var importingPDF = false
    @State private var replacingOriginal = false
    @State private var full = false
    @State private var exporting = false
    @State private var exportURL: URL?
    @State private var selectedArticle: Article?
    @State private var loadError: String?
    private var resource: VisualResource? { model.resource(id) }
    var body: some View {
        Group {
            if let r = resource {
                VStack(spacing: 0) {
                    viewer(r).frame(maxWidth: .infinity, maxHeight: .infinity)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            if r.kind == .presentation {
                                NavigationLink("スライドの順序・本文・ノートを編集") { DeckEditor(id: id) }
                            }
                            if [.pptx, .docx].contains(r.kind) {
                                Button(r.previewHash == nil ? "閲覧用PDFを登録" : "閲覧用PDFを更新") { importingPDF = true }
                                Text("原本を保持し、PDFは別に登録します。アニメーション・動画・特殊フォントの再現は保証しません。").font(.caption).foregroundStyle(.secondary)
                            }
                            HStack {
                                Button("全画面") { full = true }
                                Button("分類・記事リンク") { showMetadata = true }
                                Button(r.favorite ? "保存を解除" : "保存") {
                                    var next = r; next.favorite.toggle(); Task { await model.save(next) }
                                }
                            }.buttonStyle(.bordered)
                            if r.kind != .presentation { Button("原本を更新（IDを維持）") { replacingOriginal = true } }
                            exportButtons(r)
                            if let exportURL { ShareLink("出力ファイルを共有・保存", item: exportURL) }
                            related(r)
                        }.padding(14)
                    }.frame(maxHeight: 220)
                }
                .navigationTitle(r.title).navigationBarTitleDisplayMode(.inline)
                .task(id: r.previewHash ?? r.originalHash) { await load(r) }
                .fullScreenCover(isPresented: $full) {
                    NavigationStack {
                        viewer(r).navigationTitle(r.title).navigationBarTitleDisplayMode(.inline)
                            .toolbar { Button("閉じる") { full = false } }
                    }
                }
                .sheet(isPresented: $showMetadata) { NavigationStack { ResourceMetadataEditor(id: id) } }
                .sheet(item: $selectedArticle) { article in NavigationStack { ArticleReader(article: article).toolbar { Button("閉じる") { selectedArticle = nil } } } }
                .fileImporter(isPresented: $importingPDF, allowedContentTypes: [.pdf]) { result in
                    switch result {
                    case .success(let url): Task { await model.attachPDF(url, id: id) }
                    case .failure(let error): model.error = error.localizedDescription
                    }
                }
                .fileImporter(isPresented: $replacingOriginal, allowedContentTypes: VisualImportTypes.all) { result in
                    switch result {
                    case .success(let url): Task { await model.replaceOriginal(url, id: id) }
                    case .failure(let error): model.error = error.localizedDescription
                    }
                }
            } else { ContentUnavailableView("資料が削除されています", systemImage: "doc.questionmark") }
        }.background { StudyBackdrop() }
    }
    @ViewBuilder private func viewer(_ r: VisualResource) -> some View {
        if let loadError {
            VStack { Text(loadError); Button("再読み込み") { Task { await load(r) } } }.padding()
        } else if r.kind == .presentation { SlidePresentationView(id: id, initialSlideID: initialSlideID) }
        else if let previewURL { DocumentPDFViewer(url: previewURL, startPage: r.savedPage, onPage: { savePage($0) }) }
        else if r.kind == .svg, let data {
            SVGViewer(data: data, links: r.elementArticles, onArticle: { articleID in selectedArticle = library.articles.first { $0.id == articleID } })
        } else if r.kind == .pdf, let url { DocumentPDFViewer(url: url, startPage: r.savedPage, onPage: { savePage($0) }) }
        else if r.kind == .docx, let url { OfficeQuickLook(url: url) }
        else if r.kind == .pptx {
            ContentUnavailableView("閲覧用PDFを登録してください", systemImage: "rectangle.stack",
                description: Text("PowerPointまたはLibreOfficeでPDFを書き出し、下のボタンからこの原本に紐付けます。"))
        } else if let data, let image = UIImage(data: data) { ScrollView { Image(uiImage: image).resizable().scaledToFit().padding() } }
        else { ProgressView("資料を読み込み中") }
    }
    private func savePage(_ page: Int) {
        guard var next = resource, next.savedPage != page else { return }
        next.savedPage = page; Task { await model.save(next) }
    }
    @ViewBuilder private func exportButtons(_ r: VisualResource) -> some View {
        HStack {
            if let url {
                ShareLink(r.kind == .svg ? "SVG保存" : "原本保存", item: url)
            }
            if r.kind == .svg {
                Button("PNG出力") { Task { await output { try await VisualExports.png(r, storage: model.storage) } } }.disabled(exporting)
            }
            if r.kind == .presentation {
                Button("PDF出力") { Task { await output { try await VisualExports.deck(r, model: model, format: "pdf") } } }.disabled(exporting)
                Button("PNG・ZIP出力") { Task { await output { try await VisualExports.deck(r, model: model, format: "png") } } }.disabled(exporting)
            }
            if let previewURL { ShareLink("PDF保存", item: previewURL) }
        }.font(.footnote)
        if exporting { ProgressView("出力中") }
    }
    @ViewBuilder private func related(_ r: VisualResource) -> some View {
        ForEach(r.articleIDs, id: \.self) { articleID in
            if let article = library.articles.first(where: { $0.id == articleID }) {
                NavigationLink { ArticleReader(article: article) } label: { Label(article.title, systemImage: "book") }
            } else { Text("参照先の記事は一覧にありません: " + articleID).font(.caption) }
        }
        if r.kind == .svg, !r.elementArticles.isEmpty {
            Text("図解の要素から記事を開けます。").font(.caption)
            ForEach(r.elementArticles.keys.sorted(), id: \.self) { element in
                if let articleID = r.elementArticles[element],
                   let article = library.articles.first(where: { $0.id == articleID }) {
                    NavigationLink(element + " → " + article.title) { ArticleReader(article: article) }
                } else { Text(element + " の参照先はありません").font(.caption) }
            }
        }
        if r.kind == .presentation {
            ForEach(r.slides) { slide in
                NavigationLink { SlidePresentationView(id: id, initialSlideID: slide.id) } label: { Text("スライド: " + slide.title).font(.caption) }
            }
        }
    }
    private func load(_ r: VisualResource) async {
        url = nil; previewURL = nil; data = nil; loadError = nil
        guard r.kind != .presentation else { return }
        do {
            url = try await model.storage.url(id, safe: r.kind == .svg)
            if let url, [.svg, .png, .jpeg].contains(r.kind) { data = try Data(contentsOf: url) }
            if r.previewHash != nil { previewURL = try await model.storage.url(id, preview: true) }
        } catch { loadError = error.localizedDescription }
    }
    private func output(_ operation: () async throws -> URL) async {
        exporting = true; defer { exporting = false }
        do { exportURL = try await operation() } catch { model.error = error.localizedDescription }
    }
}
@MainActor private struct ResourceMetadataEditor: View {
    let id: UUID
    @EnvironmentObject private var model: VisualResourceModel
    @EnvironmentObject private var library: Library
    @Environment(\.dismiss) private var dismiss
    @State private var draft: VisualResource?
    @State private var tags = ""
    @State private var elements: [String] = []
    var body: some View {
        Form {
            TextField("タイトル", text: Binding(get: { draft?.title ?? "" }, set: { draft?.title = $0 }))
            TextField("カテゴリ", text: Binding(get: { draft?.category ?? "" }, set: { draft?.category = $0 }))
            TextField("タグ（カンマ区切り）", text: $tags)
            Section("関連する記事（複数選択）") {
                ForEach(library.articles) { article in
                    Toggle(article.title, isOn: Binding(get: { draft?.articleIDs.contains(article.id) ?? false }, set: { checked in
                        draft?.articleIDs.removeAll { $0 == article.id }; if checked { draft?.articleIDs.append(article.id) }
                    }))
                }
            }
            if !elements.isEmpty {
                Section("SVG要素から記事へのリンク") {
                    ForEach(elements, id: \.self) { element in
                        Picker(element, selection: Binding(get: { draft?.elementArticles[element] ?? "" }, set: { value in
                            if value.isEmpty { draft?.elementArticles.removeValue(forKey: element) }
                            else { draft?.elementArticles[element] = value }
                        })) {
                            Text("リンクなし").tag("")
                            ForEach(library.articles) { Text($0.title).tag($0.id) }
                        }
                    }
                }
            }
        }
        .navigationTitle("分類・関連付け")
        .toolbar {
            Button("キャンセル") { dismiss() }
            Button("保存") {
                guard var draft else { return }
                draft.tags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                Task { await model.save(draft); if model.error == nil { dismiss() } }
            }
        }
        .task {
            draft = model.resource(id); tags = draft?.tags.joined(separator: ", ") ?? ""
            if draft?.kind == .svg, let url = try? await model.storage.url(id, safe: true),
               let data = try? Data(contentsOf: url), let safe = try? SafeSVG.parse(data) { elements = safe.elementIDs.sorted() }
        }
    }
}
@MainActor struct ArticleVisualResources: View {
    let article: Article
    let markdown: String
    @EnvironmentObject private var model: VisualResourceModel
    @State private var createdDeck: UUID?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("図解・資料・プレゼン").font(.subheadline.bold())
            NavigationLink("この記事に資料を登録・関連付け") { VisualLibraryView(articleID: article.id) }
            ForEach(model.resources.filter { $0.articleIDs.contains(article.id) }) { resource in
                NavigationLink { VisualResourceDetail(id: resource.id) } label: { Label(resource.title, systemImage: resource.kind == .presentation ? "rectangle.stack" : "doc") }
                if resource.kind == .presentation {
                    ForEach(resource.slides) { slide in
                        NavigationLink("スライド: " + slide.title) { VisualResourceDetail(id: resource.id, initialSlideID: slide.id) }.font(.caption)
                    }
                }
            }
            Button("この記事からスライドを作る") {
                Task { createdDeck = await model.createDeck(article: article, markdown: markdown) }
            }.disabled(!model.ready)
            if let createdDeck { NavigationLink("作成したスライドを開く") { VisualResourceDetail(id: createdDeck) } }
        }.font(.footnote).padding(.vertical, 12)
    }
}
