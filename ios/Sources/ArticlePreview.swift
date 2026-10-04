import SwiftUI
import MarkdownUI

// Extract actual introductory prose, skipping metadata, headings and fenced code.
enum ArticlePreview {
    static func excerpt(_ raw: String) -> String {
        var lines: [String] = []
        var fence: String?
        for line in ArticleLinks.body(raw).components(separatedBy: "\n") {
            let text = line.trimmingCharacters(in: .whitespaces)
            if text.hasPrefix("```") || text.hasPrefix("~~~") {
                let marker = String(text.prefix(3))
                if fence == marker { fence = nil } else if fence == nil { fence = marker }
                continue
            }
            guard fence == nil else { continue }
            if text.isEmpty {
                if !lines.isEmpty { break }
                continue
            }
            if text.range(of: "^#{1,6}\\s|^[-=*]{3,}$|^!\\[|^\\[.*\\]:", options: .regularExpression) != nil { continue }
            lines.append(text)
            if lines.joined().count >= 180 { break }
        }
        let plain = MarkdownContent(lines.joined(separator: " ")).renderPlainText()
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        return String(plain.prefix(140))
    }
}

@MainActor struct ArticleExcerpt: View {
    let article: Article
    var onGradient = false
    var compact = false
    @EnvironmentObject private var library: Library
    private var key: String { Library.cacheKey(article) }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let text = library.excerpts[key], !text.isEmpty {
                Text(text).font(compact ? .caption : .footnote).lineLimit(2).multilineTextAlignment(.leading)
                    .foregroundStyle(onGradient ? Color.white.opacity(0.9) : Color.secondary)
            } else if library.excerptFailures.contains(key) {
                Text("冒頭を取得できません").font(.caption).foregroundStyle(onGradient ? Color.white.opacity(0.9) : Color.secondary)
            }
        }.task(id: key) { await library.loadExcerpt(article) }
    }
}
