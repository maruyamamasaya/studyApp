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
