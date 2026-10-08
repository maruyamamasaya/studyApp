import SwiftUI
import WebKit
import MarkdownUI

enum SVGHTML {
    static func page(_ data: Data, links: [String: String] = [:]) throws -> String {
        let safe = try SafeSVG.parse(data, links: links)
        return """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src 'none'; connect-src 'none'; script-src 'none'; font-src 'none'">
        <style>html,body{margin:0;background:#fff;color:#111}svg{width:100%;height:auto;min-height:200px;max-height:100vh}</style>
        </head><body>\(String(decoding: safe.data, as: UTF8.self))</body></html>
        """
    }
    static func webView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.scrollView.minimumZoomScale = 1; view.scrollView.maximumZoomScale = 8
        view.accessibilityLabel = "SVG図解。ピンチまたは拡大ボタンで操作できます。"
        return view
    }
}
@MainActor final class SVGControls: ObservableObject {
    weak var webView: WKWebView?
    func zoom(_ factor: CGFloat) {
        guard let webView else { return }
        let scroll = webView.scrollView
        scroll.setZoomScale(min(8, max(1, scroll.zoomScale * factor)), animated: true)
    }
}
struct StaticSVGWebView: UIViewRepresentable {
    let data: Data
    let controls: SVGControls
    var links: [String: String] = [:]
    var onArticle: (String) -> Void = { _ in }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> WKWebView {
        let view = SVGHTML.webView(); view.navigationDelegate = context.coordinator; controls.webView = view
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.onArticle = onArticle
        guard context.coordinator.previous != data || context.coordinator.links != links else { return }
        context.coordinator.previous = data
        context.coordinator.links = links
        if let page = try? SVGHTML.page(data, links: links) { view.loadHTMLString(page, baseURL: nil) }
    }
    final class Coordinator: NSObject, WKNavigationDelegate {
        var previous: Data?
        var links: [String: String] = [:]
        var onArticle: (String) -> Void = { _ in }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url, url.scheme == "learnleafarticle" {
                let article = String(url.absoluteString.dropFirst("learnleafarticle:".count))
                if links.values.contains(article) { onArticle(article) }
            }
            decisionHandler(navigationAction.request.url?.absoluteString == "about:blank" ? .allow : .cancel)
        }
    }
}
@MainActor final class SVGSnapshot: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<Data, Error>?
    private var deadline: Task<Void, Never>?
    static func png(_ data: Data, size: CGSize = CGSize(width: 1200, height: 800)) async throws -> Data {
        let renderer = SVGSnapshot()
        return try await renderer.render(data, size: size)
    }
    private func render(_ data: Data, size: CGSize) async throws -> Data {
        let page = try SVGHTML.page(data)
        let view = SVGHTML.webView(); view.frame = CGRect(origin: .zero, size: size)
        view.navigationDelegate = self; webView = view
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            deadline = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                self?.finish(.failure(VisualError.unavailable))
            }
            view.loadHTMLString(page, baseURL: nil)
        }
    }
    private func finish(_ result: Result<Data, Error>) {
        guard let continuation else { return }
        self.continuation = nil; deadline?.cancel(); deadline = nil
        webView?.stopLoading(); webView?.navigationDelegate = nil; webView = nil
        continuation.resume(with: result)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let config = WKSnapshotConfiguration()
        config.rect = webView.bounds; config.snapshotWidth = NSNumber(value: Double(webView.bounds.width))
        webView.takeSnapshot(with: config) { [weak self] image, error in
            if let data = image?.pngData() { self?.finish(.success(data)) }
            else { self?.finish(.failure(error ?? VisualError.unavailable)) }
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(navigationAction.request.url?.absoluteString == "about:blank" ? .allow : .cancel)
    }
}
@MainActor struct SVGViewer: View {
    let data: Data
    var links: [String: String] = [:]
    var onArticle: (String) -> Void = { _ in }
    @StateObject private var controls = SVGControls()
    var body: some View {
        VStack(spacing: 0) {
            StaticSVGWebView(data: data, controls: controls, links: links, onArticle: onArticle).background(.white)
            HStack {
                Button { controls.zoom(0.8) } label: { Label("縮小", systemImage: "minus.magnifyingglass") }
                Button { controls.webView?.scrollView.setZoomScale(1, animated: true) } label: { Text("全体") }
                Button { controls.zoom(1.25) } label: { Label("拡大", systemImage: "plus.magnifyingglass") }
            }.buttonStyle(.bordered).padding(8)
        }
    }
}
struct VisualImageProvider: ImageProvider {
    var articleID: String?
    func makeImage(url: URL?) -> some View { VisualMarkdownImage(url: url, articleID: articleID) }
}
@MainActor struct VisualMarkdownImage: View {
    let url: URL?
    var articleID: String?
    @EnvironmentObject private var resources: VisualResourceModel
    @State private var data: Data?
    @State private var error: String?
    @State private var full = false
    @State private var exportURL: URL?
    var body: some View {
        Group {
            if url?.pathExtension.lowercased() == "svg" {
                if let data {
                    VStack(alignment: .leading) {
                        SVGViewer(data: data).frame(height: 260)
                        Button("図解を全画面で開く") { full = true }
                        Button("図解を端末ライブラリに保存") { Task { await save(data) } }.disabled(resources.busy || !resources.ready)
                        Button("SVGを書き出す") {
                            do { exportURL = try VisualExports.write(data, name: "diagram.svg") }
                            catch { self.error = error.localizedDescription }
                        }
                        if let exportURL { ShareLink("SVGを共有・ファイルに保存", item: exportURL) }
                    }
                    .fullScreenCover(isPresented: $full) {
                        NavigationStack { SVGViewer(data: data).toolbar { Button("閉じる") { full = false } } }
                    }
                } else if let error { Text(error).font(.caption).foregroundStyle(.secondary) }
                else { ProgressView("図解を取得中").frame(height: 160) }
            } else {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFit() }
                    else if phase.error != nil { Label("画像を取得できません", systemImage: "photo") }
                    else { ProgressView() }
                }
            }
        }.task(id: url) {
            guard let url, url.pathExtension.lowercased() == "svg" else { return }
            do { data = try SafeSVG.parse(try await VisualAssetLoader.load(url)).data }
            catch { self.error = "図解を表示できません: " + error.localizedDescription }
        }
    }
    private func save(_ data: Data) async {
        do {
            let name = url?.lastPathComponent ?? "diagram.svg"
            let file = try VisualExports.write(data, name: name.hasSuffix(".svg") ? name : "diagram.svg")
            await resources.importFiles([file], articleID: articleID)
        } catch { resources.error = error.localizedDescription }
    }
}
