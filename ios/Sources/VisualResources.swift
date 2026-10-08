import Foundation
import CryptoKit

enum ResourceKind: String, Codable, CaseIterable {
    case svg, pdf, docx, pptx, png, jpeg, presentation
    var title: String {
        switch self {
        case .svg: return "図解"
        case .pdf: return "PDF"
        case .docx: return "Word"
        case .pptx: return "PowerPoint"
        case .png, .jpeg: return "画像"
        case .presentation: return "プレゼン"
        }
    }
}
struct VisualSlide: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var body: String
    var notes = ""
    var resourceIDs: [UUID] = []
}
struct VisualResource: Codable, Identifiable, Equatable {
    var id: UUID
    var kind: ResourceKind
    var title: String
    var originalName: String
    var originalHash: String
    var created: Date
    var tags: [String] = []
    var category = ""
    var articleIDs: [String] = []
    // Maps safe SVG element identifiers to stable article IDs, never executable URLs.
    var elementArticles: [String: String] = [:]
    var previewHash: String?
    var thumbnailHash: String?
    var sourceArticleID: String?
    var sourceHash: String?
    var sourcePath: String?
    var slides: [VisualSlide] = []
    var favorite = false
    var savedPage = 0
}
struct VisualIndex: Codable {
    var schemaVersion = 1
    var resources: [VisualResource] = []
    func validated() throws -> VisualIndex {
        guard schemaVersion == 1, resources.count <= 5000,
              Set(resources.map(\.id)).count == resources.count else { throw VisualError.invalid }
        for r in resources {
            guard !r.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  r.title.count <= 500, r.originalName.count <= 500, r.category.count <= 500,
                  r.tags.count <= 100, r.articleIDs.count <= 1000,
                  r.tags.allSatisfy({ $0.count <= 200 }),
                  Set(r.articleIDs).count == r.articleIDs.count,
                  r.sourceArticleID.map({ Catalog.matches($0, "^[0-9]{8}-[0-9]{6}$") }) ?? true,
                  r.sourcePath.map({ $0.count <= 2000 }) ?? true,
                  r.elementArticles.count <= 20000, r.slides.count <= 500,
                  Set(r.slides.map(\.id)).count == r.slides.count,
                  r.articleIDs.allSatisfy({ Catalog.matches($0, "^[0-9]{8}-[0-9]{6}$") }),
                  r.elementArticles.values.allSatisfy({ Catalog.matches($0, "^[0-9]{8}-[0-9]{6}$") }),
                  r.slides.allSatisfy({ $0.title.count <= 500 && $0.body.utf8.count <= 200000 && $0.notes.utf8.count <= 50000 && $0.resourceIDs.count <= 20 }),
                  r.slides.reduce(0, { $0 + $1.body.utf8.count + $1.notes.utf8.count }) <= 2 * 1024 * 1024,
                  r.savedPage >= 0,
                  r.kind == .presentation || Self.hash(r.originalHash),
                  r.previewHash.map(Self.hash) ?? true,
                  r.thumbnailHash.map(Self.hash) ?? true,
                  r.sourceHash.map(Self.hash) ?? true else { throw VisualError.invalid }
        }
        return self
    }
    static func hash(_ value: String) -> Bool { Catalog.matches(value, "^[0-9a-f]{64}$") }
}
enum VisualError: LocalizedError {
    case invalid, size, unsafe, duplicate, unavailable
    var errorDescription: String? {
        switch self {
        case .invalid: return "資料の形式または保存情報が不正です。"
        case .size: return "資料の容量・ページ数・展開サイズの上限を超えています。"
        case .unsafe: return "スクリプト・外部参照・未対応の要素があるため、安全に表示できません。"
        case .duplicate: return "同じ内容の資料は登録済みです。"
        case .unavailable: return "資料ファイルがありません。再登録してください。"
        }
    }
}
enum ResourceDigest {
    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
