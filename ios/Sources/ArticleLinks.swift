import Foundation

enum ArticleLinks {
    static func body(_ raw: String) -> String {
        var lines = raw.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        if lines.first == "---", let end = lines.dropFirst().firstIndex(of: "---") {
            lines = Array(lines.dropFirst(end + 1))
        }
        // コードフェンス内・インラインコード内のWiki Linkは変更しない。
        var fence: String?
        return lines.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let marker = String(trimmed.prefix(3))
                if fence == marker { fence = nil } else if fence == nil { fence = marker }
                return line
            }
            guard fence == nil else { return line }
            let regex = try! NSRegularExpression(pattern: "`+[^`]*`+|\\[\\[([^\\]\\n]+)\\]\\]")
            var output = line
            for match in regex.matches(in: line, range: NSRange(line.startIndex..., in: line)).reversed() {
                guard let inner = Range(match.range(at: 1), in: line), let range = Range(match.range, in: output) else { continue }
                let parts = line[inner].split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
                let target = String(parts[0])
                let label = String(parts.last ?? parts[0]).replacingOccurrences(of: "[", with: "\\[").replacingOccurrences(of: "]", with: "\\]")
                var components = URLComponents()
                components.scheme = "studyarticle"
                components.host = "link"
                components.queryItems = [URLQueryItem(name: "target", value: target)]
                if let url = components.url { output.replaceSubrange(range, with: "[\(label)](\(url.absoluteString))") }
            }
            return output
        }.joined(separator: "\n")
    }

    static func resolve(_ target: String, current: Article, articles: [Article]) -> [Article] {
        let name = String(target.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0])
            .removingPercentEncoding ?? target
        if name.isEmpty { return [current] }
        let plain = name.hasSuffix(".md") ? String(name.dropLast(3)) : name
        let ids = articles.filter { $0.id == plain }
        if !ids.isEmpty { return ids }
        let relative = current.folder + "/" + name
        func normalized(_ path: String) -> String {
            var pieces: [String] = []
            for piece in path.split(separator: "/") {
                if piece == ".." { if !pieces.isEmpty { pieces.removeLast() } }
                else if piece != "." { pieces.append(String(piece)) }
            }
            let result = pieces.joined(separator: "/")
            return result.hasSuffix(".md") ? String(result.dropLast(3)) : result
        }
        let paths = articles.filter { normalized($0.path) == normalized(name) || normalized($0.path) == normalized(relative) }
        if !paths.isEmpty { return paths }
        return articles.filter { $0.title == name || $0.aliases.contains(name) }
    }
}
