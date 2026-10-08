import Foundation
import ZIPFoundation

actor VisualResourceStore {
    let directory: URL
    private var index = VisualIndex()
    private var loaded = false
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StudyApp/visual-resources", isDirectory: true)
    }
    func load() throws -> [VisualResource] {
        if !loaded {
            let url = directory.appendingPathComponent("index.v1.json")
            if FileManager.default.fileExists(atPath: url.path) {
                index = try JSONDecoder().decode(VisualIndex.self, from: Data(contentsOf: url)).validated()
            }
            loaded = true
        }
        return index.resources
    }
    private func commit(_ next: VisualIndex) throws {
        _ = try next.validated()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(next).write(to: directory.appendingPathComponent("index.v1.json"), options: .atomic)
        index = next
    }
    private func folder(_ id: UUID) -> URL { directory.appendingPathComponent(id.uuidString, isDirectory: true) }
    private func original(_ r: VisualResource) -> URL {
        folder(r.id).appendingPathComponent(r.originalHash + "." + r.kind.rawValue)
    }
    func url(_ id: UUID, preview: Bool = false, safe: Bool = false) throws -> URL {
        _ = try load()
        guard let r = index.resources.first(where: { $0.id == id }), r.kind != .presentation else { throw VisualError.unavailable }
        let file: URL
        let hash: String
        if preview {
            guard let value = r.previewHash else { throw VisualError.unavailable }
            file = folder(id).appendingPathComponent(value + ".pdf"); hash = value
        } else if safe, r.kind == .svg {
            let bytes = try Data(contentsOf: original(r))
            guard ResourceDigest.hash(bytes) == r.originalHash else { throw VisualError.invalid }
            let parsed = try SafeSVG.parse(bytes)
            file = folder(id).appendingPathComponent("safe.svg")
            try parsed.data.write(to: file, options: .atomic)
            return file
        } else { file = original(r); hash = r.originalHash }
        guard ResourceDigest.hash(try Data(contentsOf: file)) == hash else { throw VisualError.invalid }
        return file
    }
    func thumbnail(_ id: UUID) throws -> URL? {
        _ = try load()
        guard let r = index.resources.first(where: { $0.id == id }), let hash = r.thumbnailHash else { return nil }
        let url = folder(id).appendingPathComponent(hash + ".png")
        guard ResourceDigest.hash(try Data(contentsOf: url)) == hash else { throw VisualError.invalid }
        return url
    }
    func saveThumbnail(_ id: UUID, data: Data) throws {
        _ = try load()
        guard let pos = index.resources.firstIndex(where: { $0.id == id }) else { throw VisualError.unavailable }
        try ResourceValidation.validate(data, kind: .png)
        guard try diskUsage() + data.count <= 500 * 1024 * 1024 else { throw VisualError.size }
        let hash = ResourceDigest.hash(data)
        try data.write(to: folder(id).appendingPathComponent(hash + ".png"), options: .atomic)
        var next = index; next.resources[pos].thumbnailHash = hash; try commit(next)
    }
    func importFile(_ url: URL, articleID: String? = nil) throws -> VisualResource {
        _ = try load()
        let scope = url.startAccessingSecurityScopedResource()
        defer { if scope { url.stopAccessingSecurityScopedResource() } }
        guard url.isFileURL, (try url.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink != true,
              let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= 100 * 1024 * 1024 else { throw VisualError.size }
        let kind = try ResourceValidation.kind(for: url)
        let data = try Data(contentsOf: url)
        try ResourceValidation.validate(data, kind: kind)
        let hash = ResourceDigest.hash(data)
        if index.resources.contains(where: { $0.kind == kind && $0.originalHash == hash }) { throw VisualError.duplicate }
        // Quota includes originals and derived files; never silently evict originals.
        let usage = try diskUsage()
        guard usage + data.count <= 500 * 1024 * 1024 else { throw VisualError.size }
        let r = VisualResource(id: UUID(), kind: kind, title: String(url.deletingPathExtension().lastPathComponent.prefix(500)),
            originalName: String(url.lastPathComponent.prefix(500)), originalHash: hash, created: Date(),
            articleIDs: articleID.map { [$0] } ?? [])
        try FileManager.default.createDirectory(at: folder(r.id), withIntermediateDirectories: true)
        do {
            try data.write(to: original(r), options: .atomic)
            if kind == .svg { try SafeSVG.parse(data).data.write(to: folder(r.id).appendingPathComponent("safe.svg"), options: .atomic) }
            var next = index; next.resources.insert(r, at: 0); try commit(next)
        } catch {
            try? FileManager.default.removeItem(at: folder(r.id)); throw error
        }
        return r
    }
    func attachPDF(_ url: URL, to id: UUID) throws {
        _ = try load()
        guard let pos = index.resources.firstIndex(where: { $0.id == id }),
              [.pptx, .docx].contains(index.resources[pos].kind) else { throw VisualError.invalid }
        let scope = url.startAccessingSecurityScopedResource(); defer { if scope { url.stopAccessingSecurityScopedResource() } }
        guard url.isFileURL, (try url.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink != true,
              let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= 100 * 1024 * 1024, url.pathExtension.lowercased() == "pdf" else { throw VisualError.size }
        let data = try Data(contentsOf: url); try ResourceValidation.validate(data, kind: .pdf)
        guard try diskUsage() + data.count <= 500 * 1024 * 1024 else { throw VisualError.size }
        let hash = ResourceDigest.hash(data)
        try data.write(to: folder(id).appendingPathComponent(hash + ".pdf"), options: .atomic)
        var next = index; next.resources[pos].previewHash = hash; next.resources[pos].thumbnailHash = nil
        try commit(next)
    }
    func replaceOriginal(_ url: URL, id: UUID) throws {
        _ = try load()
        guard let pos = index.resources.firstIndex(where: { $0.id == id }), index.resources[pos].kind != .presentation else { throw VisualError.invalid }
        let scope = url.startAccessingSecurityScopedResource(); defer { if scope { url.stopAccessingSecurityScopedResource() } }
        guard url.isFileURL, (try url.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink != true,
              let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 100 * 1024 * 1024,
              try ResourceValidation.kind(for: url) == index.resources[pos].kind else { throw VisualError.invalid }
        let data = try Data(contentsOf: url); try ResourceValidation.validate(data, kind: index.resources[pos].kind)
        let hash = ResourceDigest.hash(data)
        guard try diskUsage() + data.count <= 500 * 1024 * 1024 else { throw VisualError.size }
        var next = index
        next.resources[pos].originalHash = hash; next.resources[pos].originalName = String(url.lastPathComponent.prefix(500))
        next.resources[pos].previewHash = nil; next.resources[pos].thumbnailHash = nil; next.resources[pos].savedPage = 0
        if next.resources[pos].kind == .svg {
            let ids = try SafeSVG.parse(data).elementIDs
            next.resources[pos].elementArticles = next.resources[pos].elementArticles.filter { ids.contains($0.key) }
        }
        try data.write(to: original(next.resources[pos]), options: .atomic)
        // Keep old bytes until explicit resource deletion, so a failed index commit never destroys the old version.
        try commit(next)
    }
    func save(_ resource: VisualResource) throws {
        _ = try load()
        guard let pos = index.resources.firstIndex(where: { $0.id == resource.id }) else { throw VisualError.unavailable }
        let old = index.resources[pos]
        guard old.kind == resource.kind, old.originalHash == resource.originalHash,
              old.previewHash == resource.previewHash, old.thumbnailHash == resource.thumbnailHash else { throw VisualError.invalid }
        var next = index; next.resources[pos] = resource; try commit(next)
    }
    func createDeck(_ resource: VisualResource) throws {
        _ = try load()
        guard resource.kind == .presentation, !index.resources.contains(where: { $0.id == resource.id }) else { throw VisualError.invalid }
        try FileManager.default.createDirectory(at: folder(resource.id), withIntermediateDirectories: true)
        var next = index; next.resources.insert(resource, at: 0); try commit(next)
    }
    func remove(_ id: UUID) throws {
        _ = try load()
        // Commit metadata first. Other decks keep the ID and display a missing-asset warning.
        var next = index; next.resources.removeAll { $0.id == id }; try commit(next)
        if FileManager.default.fileExists(atPath: folder(id).path) { try FileManager.default.removeItem(at: folder(id)) }
    }
    func diskUsage() throws -> Int {
        guard let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total = 0
        for case let url as URL in files { total += (try url.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0 }
        return total
    }
    func exportZIP(_ ids: [UUID]) throws -> URL {
        _ = try load()
        let selected = index.resources.filter { ids.contains($0.id) && $0.kind == .svg }
        guard !selected.isEmpty, selected.count <= 100 else { throw VisualError.invalid }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("learnleaf-export-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let files = root.appendingPathComponent("diagrams")
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
        for r in selected {
            let bytes = try Data(contentsOf: original(r))
            guard ResourceDigest.hash(bytes) == r.originalHash else { throw VisualError.invalid }
            let data = try SafeSVG.parse(bytes).data
            try data.write(to: files.appendingPathComponent(r.id.uuidString + ".svg"))
        }
        // Deliberately exclude private article relations/metadata from the share archive.
        let result = root.appendingPathComponent("diagrams.zip")
        try FileManager.default.zipItem(at: files, to: result, compressionMethod: .deflate)
        return result
    }
}
