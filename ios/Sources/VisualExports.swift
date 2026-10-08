import SwiftUI
import MarkdownUI
import PDFKit
import ZIPFoundation

@MainActor enum VisualExports {
    static func write(_ data: Data, name: String) throws -> URL {
        guard !name.isEmpty, name != ".", name != "..",
              !name.contains("/"), !name.contains("\\"), !name.contains(":"),
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { throw VisualError.invalid }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("learnleaf-export-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name); try data.write(to: url, options: .atomic); return url
    }
    static func png(_ r: VisualResource, storage: VisualResourceStore) async throws -> URL {
        let url = try await storage.url(r.id, safe: r.kind == .svg)
        let data: Data
        if r.kind == .svg { data = try await SVGSnapshot.png(Data(contentsOf: url)) }
        else if let image = UIImage(contentsOfFile: url.path), let value = image.pngData() { data = value }
        else { throw VisualError.invalid }
        return try write(data, name: "diagram.png")
    }
    static func slideImages(_ deck: VisualResource, model: VisualResourceModel) async throws -> (images: [URL: UIImage], assets: [UUID: UIImage]) {
        let base = deck.sourcePath.flatMap { try? ArticleClient.url(for: $0) }
        var images: [URL: UIImage] = [:], assets: [UUID: UIImage] = [:]
        let urls = Set(deck.slides.flatMap { SlideBuilder.imageURLs($0.body, baseURL: base) })
        let assetIDs = Set(deck.slides.flatMap(\.resourceIDs))
        guard urls.count + assetIDs.count <= 20 else { throw VisualError.size }
        var pixels: CGFloat = 0
        for url in urls {
            let bytes = try await VisualAssetLoader.load(url, maxBytes: url.pathExtension.lowercased() == "svg" ? 2 * 1024 * 1024 : 10 * 1024 * 1024)
            let data: Data
            if url.pathExtension.lowercased() == "svg" { data = try await SVGSnapshot.png(bytes) } else { data = bytes }
            guard let image = UIImage(data: data), image.size.width * image.size.height * image.scale * image.scale <= 16000000 else { throw VisualError.invalid }
            pixels += image.size.width * image.size.height * image.scale * image.scale
            guard pixels <= 16000000 else { throw VisualError.size }
            images[url] = image
        }
        for id in assetIDs {
            guard let r = model.resource(id), [.svg, .png, .jpeg].contains(r.kind) else { throw VisualError.unavailable }
            let url = try await model.storage.url(id, safe: r.kind == .svg)
            let bytes = try Data(contentsOf: url)
            let data: Data
            if r.kind == .svg { data = try await SVGSnapshot.png(bytes) } else { data = bytes }
            guard let image = UIImage(data: data) else { throw VisualError.invalid }
            pixels += image.size.width * image.size.height * image.scale * image.scale
            guard pixels <= 16000000 else { throw VisualError.size }
            assets[id] = image
        }
        return (images, assets)
    }
    static func deck(_ deck: VisualResource, model: VisualResourceModel, format: String) async throws -> URL {
        guard !deck.slides.isEmpty, deck.slides.count <= 500 else { throw VisualError.invalid }
        let loaded = try await slideImages(deck, model: model)
        let base = deck.sourcePath.flatMap { try? ArticleClient.url(for: $0) }
        func content(_ slide: VisualSlide) -> some View {
            ExportSlide(slide: slide, baseURL: base, images: loaded.images, assets: loaded.assets)
                .frame(width: 960).fixedSize(horizontal: false, vertical: true)
                .background(.white).environment(\.colorScheme, .light)
        }
        func pageImage(_ slide: VisualSlide) throws -> UIImage {
            let renderer = ImageRenderer(content: content(slide)); renderer.scale = 1
            guard let image = renderer.uiImage, image.size.height > 0,
                  image.size.width * image.size.height <= 16000000 else { throw VisualError.size }
            let scale = min(960 / image.size.width, 540 / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
            return UIGraphicsImageRenderer(size: CGSize(width: 960, height: 540), format: format).image { context in
                UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 960, height: 540))
                image.draw(in: CGRect(x: (960 - size.width) / 2, y: (540 - size.height) / 2, width: size.width, height: size.height))
            }
        }
        if format == "pdf" {
            let output = try write(Data(), name: "presentation.pdf")
            let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 960, height: 540))
            var renderError: Error?
            try renderer.writePDF(to: output) { context in
                for slide in deck.slides {
                    guard renderError == nil else { break }
                    let image: UIImage
                    do { image = try pageImage(slide) }
                    catch { renderError = error; break }
                    context.beginPage()
                    image.draw(in: CGRect(x: 0, y: 0, width: 960, height: 540))
                }
            }
            if let renderError { try? FileManager.default.removeItem(at: output); throw renderError }
            guard PDFDocument(url: output)?.pageCount == deck.slides.count else { throw VisualError.invalid }
            return output
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("learnleaf-export-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let pages = root.appendingPathComponent("slides")
        try FileManager.default.createDirectory(at: pages, withIntermediateDirectories: true)
        for (index, slide) in deck.slides.enumerated() {
            guard let data = try pageImage(slide).pngData() else { throw VisualError.unavailable }
            try data.write(to: pages.appendingPathComponent(String(format: "slide-%03d.png", index + 1)))
        }
        let result = root.appendingPathComponent("slides.zip")
        try FileManager.default.zipItem(at: pages, to: result, compressionMethod: .deflate)
        return result
    }
}
private struct ExportSlide: View {
    let slide: VisualSlide
    let baseURL: URL?
    let images: [URL: UIImage]
    let assets: [UUID: UIImage]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(slide.title).font(.system(size: 28, weight: .bold))
            Markdown(slide.body, baseURL: baseURL).markdownImageProvider(PreparedSlideImages(images: images))
                .font(.system(size: 18))
            HStack {
                ForEach(slide.resourceIDs, id: \.self) { id in
                    if let image = assets[id] { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180) }
                }
            }
        }.foregroundStyle(.black).padding(32).frame(maxWidth: .infinity, alignment: .leading)
    }
}
private struct PreparedSlideImages: ImageProvider {
    let images: [URL: UIImage]
    func makeImage(url: URL?) -> some View {
        Group {
            if let url, let image = images[url.absoluteURL] { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180) }
            else { Text("画像を取得できません") }
        }
    }
}
