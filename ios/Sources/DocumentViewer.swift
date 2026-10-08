import SwiftUI
import PDFKit
import QuickLook

struct OfficeQuickLook: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let view = QLPreviewController(); view.dataSource = context.coordinator; return view
    }
    func updateUIViewController(_ view: QLPreviewController, context: Context) {
        if context.coordinator.url != url { context.coordinator.url = url; view.reloadData() }
    }
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL
        init(_ url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}
@MainActor final class ResourcePDFState: ObservableObject {
    @Published var page = 0
    @Published var count = 0
    @Published var query = ""
    @Published var message: String?
    @Published var thumbnails: [UIImage] = []
    weak var view: PDFView?
    func go(_ number: Int) {
        guard let view, let target = view.document?.page(at: max(0, min(count - 1, number))) else { return }
        view.go(to: target); page = view.document?.index(for: target) ?? 0
    }
    func zoom(_ factor: CGFloat) {
        guard let view else { return }
        view.scaleFactor = min(view.maxScaleFactor, max(view.minScaleFactor, view.scaleFactor * factor))
    }
    func search() {
        guard let view, let doc = view.document, !query.isEmpty else { return }
        let start = view.currentSelection
        let selection = doc.findString(query, fromSelection: start, withOptions: [.caseInsensitive])
            ?? doc.findString(query, fromSelection: nil, withOptions: [.caseInsensitive])
        guard let selection else { message = "一致する文字がありません。スキャンPDFには文字情報がない場合があります。"; return }
        view.setCurrentSelection(selection, animate: true); view.go(to: selection)
    }
}
struct ResourcePDFView: UIViewRepresentable {
    let url: URL
    let state: ResourcePDFState
    let startPage: Int
    func makeCoordinator() -> Coordinator { Coordinator(state: state) }
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView(); view.autoScales = true; view.displayMode = .singlePage
        view.displayDirection = .horizontal; view.usePageViewController(true)
        view.delegate = context.coordinator; state.view = view
        context.coordinator.observer = NotificationCenter.default.addObserver(forName: .PDFViewPageChanged, object: view, queue: .main) { [weak state] _ in
            Task { @MainActor in
                guard let state, let doc = state.view?.document, let page = state.view?.currentPage else { return }
                state.page = doc.index(for: page)
            }
        }
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {
        guard context.coordinator.url != url else { return }
        context.coordinator.url = url
        guard let doc = PDFDocument(url: url), !doc.isEncrypted, doc.pageCount <= 500 else {
            Task { @MainActor in state.message = "PDFを読み込めません。" }; return
        }
        // Prevent interactive actions/forms/links in the view; original bytes remain untouched.
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i) {
                for annotation in page.annotations { page.removeAnnotation(annotation) }
            }
        }
        view.document = doc
        Task { @MainActor in
            guard view.document === doc else { return }
            state.count = doc.pageCount; state.go(startPage)
        }
    }
    final class Coordinator: NSObject, PDFViewDelegate {
        var url: URL?
        weak var state: ResourcePDFState?
        var observer: NSObjectProtocol?
        init(state: ResourcePDFState) { self.state = state }
        deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
        func pdfViewWillClick(onLink sender: PDFView, with url: URL) { }
    }
}
@MainActor struct DocumentPDFViewer: View {
    let url: URL
    var startPage = 0
    var onPage: (Int) -> Void = { _ in }
    @StateObject private var state = ResourcePDFState()
    @State private var pageNumber = ""
    @State private var showPages = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("文字を検索", text: $state.query).textFieldStyle(.roundedBorder).onSubmit { state.search() }
                Button("検索") { state.search() }
            }.padding(8)
            ResourcePDFView(url: url, state: state, startPage: startPage)
            HStack {
                Button { state.go(state.page - 1) } label: { Image(systemName: "chevron.left") }.disabled(state.page == 0)
                Button("\(state.page + 1) / \(state.count)") { showPages = true }
                TextField("ページ", text: $pageNumber).keyboardType(.numberPad).frame(width: 60)
                Button("移動") { if let n = Int(pageNumber) { state.go(n - 1) } }
                Button { state.go(state.page + 1) } label: { Image(systemName: "chevron.right") }.disabled(state.page + 1 >= state.count)
            }.padding(8)
            HStack {
                Button("縮小") { state.zoom(0.8) }
                Button("全体") { state.view?.autoScales = true }
                Button("拡大") { state.zoom(1.25) }
            }.buttonStyle(.bordered).padding(.bottom, 8)
        }
        .onChange(of: state.page) { _, p in onPage(p) }
        .sheet(isPresented: $showPages) {
            NavigationStack {
                List(0..<state.count, id: \.self) { page in
                    Button { state.go(page); showPages = false } label: {
                        HStack {
                            if let image = state.view?.document?.page(at: page)?.thumbnail(of: CGSize(width: 90, height: 120), for: .mediaBox) {
                                Image(uiImage: image).resizable().scaledToFit().frame(width: 60, height: 80)
                            }
                            Text("ページ \(page + 1)")
                        }
                    }
                }.navigationTitle("ページ一覧").toolbar { Button("閉じる") { showPages = false } }
            }
        }
        .alert("PDF", isPresented: Binding(get: { state.message != nil }, set: { if !$0 { state.message = nil } })) {
            Button("閉じる") { state.message = nil }
        } message: { Text(state.message ?? "") }
    }
}
