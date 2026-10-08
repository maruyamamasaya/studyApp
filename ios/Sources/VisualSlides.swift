import SwiftUI
import MarkdownUI
import UIKit

enum SlideBuilder {
    static func build(_ markdown: String) -> [VisualSlide] {
        let body = ArticleLinks.body(markdown).replacingOccurrences(of: "\r\n", with: "\n")
        var slides: [VisualSlide] = []
        var title = "はじめに", lines: [String] = []
        var fence: String?
        func flush() {
            let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty || title != "はじめに" { slides.append(VisualSlide(title: title, body: text)) }
            lines = []
        }
        for line in body.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let backticks = String(repeating: "\u{0060}", count: 3)
            if trimmed.hasPrefix(backticks) || trimmed.hasPrefix("~~~") {
                let marker = trimmed.hasPrefix(backticks) ? backticks : "~~~"
                if fence == marker { fence = nil } else if fence == nil { fence = marker }
                lines.append(line); continue
            }
            if fence == nil, trimmed == "---" { flush(); title = "続き"; continue }
            if fence == nil, let match = trimmed.range(of: "^#{1,6}\\s+", options: .regularExpression) {
                flush(); title = String(trimmed[match.upperBound...]); continue
            }
            lines.append(line)
        }
        flush()
        return slides.isEmpty ? [VisualSlide(title: "スライド", body: body)] : slides
    }
    static func imageURLs(_ text: String, baseURL: URL?) -> [URL] {
        guard let expression = try? NSRegularExpression(pattern: "!\\[[^\\]]*\\]\\(([^\\s)]+)(?:\\s+\"[^\"]*\")?\\)") else { return [] }
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            guard let range = Range($0.range(at: 1), in: text) else { return nil }
            return URL(string: String(text[range]), relativeTo: baseURL)?.absoluteURL
        }
    }
}
@MainActor struct SlideCanvas: View {
    let slide: VisualSlide
    var baseURL: URL?
    @EnvironmentObject private var resources: VisualResourceModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(slide.title).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                Markdown(slide.body, baseURL: baseURL).markdownImageProvider(VisualImageProvider())
                ForEach(slide.resourceIDs, id: \.self) { id in
                    if let r = resources.resource(id) { ResourceInlineAsset(resource: r) }
                    else { Label("図解が削除されています: " + id.uuidString, systemImage: "exclamationmark.triangle").font(.caption) }
                }
            }.padding(24).frame(maxWidth: 960, alignment: .leading).frame(maxWidth: .infinity)
        }
    }
}
@MainActor struct ResourceInlineAsset: View {
    let resource: VisualResource
    @EnvironmentObject private var resources: VisualResourceModel
    @State private var data: Data?
    @State private var error: String?
    var body: some View {
        Group {
            if let data, resource.kind == .svg { SVGViewer(data: data).frame(height: 260) }
            else if let data, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFit() }
            else if let error { Text(error).font(.caption).foregroundStyle(.secondary) }
            else { ProgressView() }
        }.task(id: resource.originalHash) {
            do {
                let url = try await resources.storage.url(resource.id, safe: resource.kind == .svg)
                data = try Data(contentsOf: url)
            } catch { self.error = error.localizedDescription }
        }
    }
}
@MainActor struct SlidePresentationView: View {
    let id: UUID
    var initialSlideID: UUID?
    @EnvironmentObject private var resources: VisualResourceModel
    @State private var page = 0
    @State private var notes = false
    private var deck: VisualResource? { resources.resource(id) }
    var body: some View {
        Group {
            if let deck, !deck.slides.isEmpty {
                VStack(spacing: 0) {
                    TabView(selection: $page) {
                        ForEach(Array(deck.slides.enumerated()), id: \.element.id) { index, slide in
                            SlideCanvas(slide: slide, baseURL: baseURL(deck)).tag(index)
                        }
                    }.tabViewStyle(.page(indexDisplayMode: .never))
                    HStack {
                        Button { page = max(0, page - 1) } label: { Image(systemName: "chevron.left") }.disabled(page == 0)
                        Text("\(page + 1) / \(deck.slides.count)").monospacedDigit()
                        Button { notes = true } label: { Label("ノート", systemImage: "note.text") }
                        Button { page = min(deck.slides.count - 1, page + 1) } label: { Image(systemName: "chevron.right") }.disabled(page + 1 == deck.slides.count)
                    }.padding(12)
                }
                .background { StudyBackdrop() }
                .background(PresentationKeys(previous: { page = max(0, page - 1) },
                    next: { page = min(deck.slides.count - 1, page + 1) }).frame(width: 0, height: 0))
                .onAppear {
                    page = initialSlideID.flatMap { value in deck.slides.firstIndex { $0.id == value } } ?? min(deck.savedPage, deck.slides.count - 1)
                }
                .onChange(of: page) { _, p in
                    var updated = deck; updated.savedPage = p; Task { await resources.save(updated) }
                }
                .sheet(isPresented: $notes) {
                    NavigationStack {
                        ScrollView { Text(deck.slides[min(page, deck.slides.count - 1)].notes.isEmpty ? "ノートはありません。" : deck.slides[min(page, deck.slides.count - 1)].notes).padding() }
                            .navigationTitle("発表者ノート").toolbar { Button("閉じる") { notes = false } }
                    }
                }
            } else { ContentUnavailableView("スライドがありません", systemImage: "rectangle.stack") }
        }
    }
    private func baseURL(_ deck: VisualResource) -> URL? { deck.sourcePath.flatMap { try? ArticleClient.url(for: $0) } }
}
struct PresentationKeys: UIViewControllerRepresentable {
    let previous: () -> Void
    let next: () -> Void
    func makeUIViewController(context: Context) -> Controller { Controller(previous: previous, next: next) }
    func updateUIViewController(_ controller: Controller, context: Context) { controller.previous = previous; controller.next = next }
    final class Controller: UIViewController {
        var previous: () -> Void
        var next: () -> Void
        init(previous: @escaping () -> Void, next: @escaping () -> Void) {
            self.previous = previous; self.next = next; super.init(nibName: nil, bundle: nil)
        }
        required init?(coder: NSCoder) { nil }
        override var canBecomeFirstResponder: Bool { true }
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); becomeFirstResponder() }
        override var keyCommands: [UIKeyCommand]? {
            [UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(back)),
             UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(forward)),
             UIKeyCommand(input: " ", modifierFlags: [], action: #selector(forward))]
        }
        @objc private func back() { previous() }
        @objc private func forward() { next() }
    }
}
@MainActor struct DeckEditor: View {
    let id: UUID
    @EnvironmentObject private var resources: VisualResourceModel
    @EnvironmentObject private var library: Library
    @State private var draft: VisualResource?
    @State private var candidate: [VisualSlide]?
    @State private var updatedHash: String?
    @State private var updatedPath: String?
    @State private var showComparison = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Group {
            if draft != nil {
                List {
                    Section {
                        TextField("タイトル", text: Binding(get: { draft?.title ?? "" }, set: { draft?.title = $0 }))
                        Text("本文とノートは元記事とは別に保存します。保存するまで元のスライドは変更されません。").font(.caption)
                        if let source = draft?.sourceArticleID,
                           let article = library.articles.first(where: { $0.id == source }),
                           article.contentHash != draft?.sourceHash {
                            Button("元記事の更新と比較する") { Task { await compare(article) } }
                        }
                    }
                    ForEach(draft?.slides ?? []) { slide in
                        NavigationLink(slide.title) {
                            SlideEditor(id: slide.id, deck: Binding(get: { draft! }, set: { draft = $0 }))
                        }
                    }.onMove { from, to in draft?.slides.move(fromOffsets: from, toOffset: to) }
                     .onDelete { positions in
                         guard let count = draft?.slides.count, count > positions.count else { return }
                         draft?.slides.remove(atOffsets: positions)
                     }
                    Button("空のスライドを追加") { draft?.slides.append(VisualSlide(title: "スライド", body: "")) }
                }
            } else { ProgressView() }
        }
        .navigationTitle("スライド編集")
        .toolbar {
            EditButton()
            Button("保存") {
                if let draft { Task { await resources.save(draft); if resources.error == nil { dismiss() } } }
            }
        }
        .onAppear { if draft == nil { draft = resources.resource(id) } }
        .sheet(isPresented: $showComparison) {
            NavigationStack {
                List {
                    Section("現在の保存内容（手動編集を含む）") {
                        ForEach(draft?.slides ?? []) { slide in VStack(alignment: .leading) { Text(slide.title).bold(); Text(slide.body) } }
                    }
                    Section("最新記事からの再生成候補") {
                        ForEach(candidate ?? []) { slide in VStack(alignment: .leading) { Text(slide.title).bold(); Text(slide.body) } }
                    }
                    Text("候補で置換すると、保存済みの順序・ノート・手動編集は置き換わります。キャンセルなら保持されます。").foregroundStyle(.secondary)
                    Button("候補を編集草稿へ採用", role: .destructive) {
                        draft?.slides = candidate ?? []; draft?.sourceHash = updatedHash
                        draft?.sourcePath = updatedPath; showComparison = false
                    }
                }.navigationTitle("更新差分を確認").toolbar { Button("キャンセル") { showComparison = false } }
            }
        }
    }
    private func compare(_ article: Article) async {
        do {
            candidate = SlideBuilder.build(try await library.content(article))
            updatedHash = article.contentHash; updatedPath = article.path; showComparison = true
        } catch { resources.error = error.localizedDescription }
    }
}
@MainActor private struct SlideEditor: View {
    let id: UUID
    @Binding var deck: VisualResource
    @EnvironmentObject private var resources: VisualResourceModel
    @Environment(\.dismiss) private var dismiss
    private var index: Int? { deck.slides.firstIndex { $0.id == id } }
    private func text(_ key: WritableKeyPath<VisualSlide, String>) -> Binding<String> {
        Binding(get: { index.map { deck.slides[$0][keyPath: key] } ?? "" },
                set: { value in if let index { deck.slides[index][keyPath: key] = value } })
    }
    var body: some View {
        Form {
            TextField("見出し", text: text(\.title))
            Section("Markdown本文") { TextEditor(text: text(\.body)).frame(minHeight: 220) }
            Section("発表者ノート") { TextEditor(text: text(\.notes)).frame(minHeight: 100) }
            Section("図解・画像を添付") {
                ForEach(resources.resources.filter { [.svg, .png, .jpeg].contains($0.kind) }) { r in
                    Toggle(r.title, isOn: Binding(get: { index.map { deck.slides[$0].resourceIDs.contains(r.id) } ?? false },
                        set: { checked in
                            guard let index else { return }
                            deck.slides[index].resourceIDs.removeAll { $0 == r.id }
                            if checked { deck.slides[index].resourceIDs.append(r.id) }
                        }))
                }
            }
            Button("本文の --- で分割") {
                guard let index else { return }
                let pieces = deck.slides[index].body.components(separatedBy: "\n---\n")
                guard pieces.count > 1 else { return }
                let title = deck.slides[index].title
                deck.slides[index].body = pieces[0]
                deck.slides.insert(contentsOf: pieces.dropFirst().map { VisualSlide(title: title + "（続き）", body: $0) }, at: index + 1)
                dismiss()
            }
            Button("次のスライドと結合") {
                guard let index, index + 1 < deck.slides.count else { return }
                let next = deck.slides.remove(at: index + 1)
                deck.slides[index].body += "\n\n## " + next.title + "\n\n" + next.body
                deck.slides[index].notes += "\n" + next.notes
                deck.slides[index].resourceIDs = Array(Set(deck.slides[index].resourceIDs + next.resourceIDs))
            }
        }.navigationTitle("スライド内容")
    }
}
