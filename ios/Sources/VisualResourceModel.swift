import SwiftUI
import PDFKit

@MainActor final class VisualResourceModel: ObservableObject {
    @Published private(set) var resources: [VisualResource] = []
    @Published var error: String?
    @Published var status: String?
    @Published var busy = false
    @Published var ready = false
    let storage: VisualResourceStore
    init(storage: VisualResourceStore = VisualResourceStore()) { self.storage = storage }
    func reload() async {
        do { resources = try await storage.load(); ready = true }
        catch { ready = false; self.error = "保存資料を読み込めません。原本を上書きせず停止しました: " + error.localizedDescription }
    }
    func resource(_ id: UUID) -> VisualResource? { resources.first { $0.id == id } }
    func save(_ r: VisualResource) async {
        do { try await storage.save(r); await reload() } catch { self.error = error.localizedDescription }
    }
    func importFiles(_ urls: [URL], articleID: String? = nil) async {
        guard ready, !busy, urls.count <= 20 else { error = "資料の読み込み完了後、20件以内で選んでください。"; return }
        busy = true; defer { busy = false }
        var succeeded = 0, failures: [String] = []
        for url in urls {
            do {
                let r = try await storage.importFile(url, articleID: articleID)
                await generateThumbnail(r); succeeded += 1
            } catch { failures.append(url.lastPathComponent + ": " + error.localizedDescription) }
        }
        await reload()
        status = "\(succeeded)件を端末内に登録しました。"
        if !failures.isEmpty { error = failures.joined(separator: "\n") }
    }
    func attachPDF(_ url: URL, id: UUID) async {
        do {
            try await storage.attachPDF(url, to: id); await reload()
            if let r = resource(id) { await generateThumbnail(r); await reload() }
        } catch { self.error = error.localizedDescription }
    }
    func replaceOriginal(_ url: URL, id: UUID) async {
        do {
            try await storage.replaceOriginal(url, id: id); await reload()
            if let r = resource(id) { await generateThumbnail(r); await reload() }
            status = "原本を更新しました。OfficeのPDFプレビューは再登録してください。"
        } catch { self.error = error.localizedDescription }
    }
    func generateThumbnail(_ r: VisualResource) async {
        do {
            let url = try await storage.url(r.id, preview: r.previewHash != nil, safe: r.kind == .svg)
            let data: Data?
            if r.kind == .svg {
                data = try await SVGSnapshot.png(try Data(contentsOf: url), size: CGSize(width: 480, height: 320))
            } else if r.kind == .pdf || r.previewHash != nil {
                data = PDFDocument(url: url)?.page(at: 0)?.thumbnail(of: CGSize(width: 240, height: 320), for: .mediaBox).pngData()
            } else if [.png, .jpeg].contains(r.kind) {
                data = UIImage(contentsOfFile: url.path)?.pngData()
            } else { data = nil }
            if let data { try await storage.saveThumbnail(r.id, data: data) }
        } catch {
            // An unavailable thumbnail must not hide a successfully imported original.
            status = "原本は保存済みです。サムネイルは作成できませんでした: " + error.localizedDescription
        }
    }
    func createDeck(article: Article, markdown: String) async -> UUID? {
        do {
            let r = VisualResource(id: UUID(), kind: .presentation, title: article.title,
                originalName: article.title, originalHash: "", created: Date(), articleIDs: [article.id],
                sourceArticleID: article.id, sourceHash: article.contentHash, sourcePath: article.path,
                slides: SlideBuilder.build(markdown))
            try await storage.createDeck(r); await reload(); return r.id
        } catch { self.error = error.localizedDescription; return nil }
    }
    func remove(_ id: UUID) async {
        do { try await storage.remove(id); await reload() } catch { self.error = error.localizedDescription }
    }
}

// Article-linked assets are restricted to the existing Pages origin and site subtree.
// No redirect, streaming byte cap, and re-validation before any SVG is rendered.
enum VisualAssetLoader {
    static func load(_ url: URL, maxBytes: Int = 2 * 1024 * 1024) async throws -> Data {
        guard url.scheme == "https", url.host == ArticleClient.baseURL.host,
              url.port == nil, url.user == nil, url.password == nil,
              url.path.hasPrefix(ArticleClient.baseURL.path),
              !url.path.contains(".."), !url.path.contains("\\") else { throw VisualError.unsafe }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15; config.timeoutIntervalForResource = 30
        let delegate = NoRedirect()
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(for: URLRequest(url: url))
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              response.expectedContentLength <= maxBytes else { throw VisualError.invalid }
        var data = Data()
        for try await byte in bytes {
            guard data.count < maxBytes else { throw VisualError.size }
            data.append(byte)
        }
        return data
    }
}
