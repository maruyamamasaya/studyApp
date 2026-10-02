import Foundation
import CryptoKit

struct Article: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let path: String
    let type: String
    let tags: [String]
    let aliases: [String]
    let created: String
    let contentHash: String
    var folder: String { String(path.split(separator: "/").dropLast().joined(separator: "/")) }
}

struct Catalog: Codable {
    let schemaVersion: Int
    let revision: String
    let articles: [Article]

    func validated() throws -> Catalog {
        guard schemaVersion == 1 else { throw ReaderError.message("未対応の記事一覧です。アプリの更新が必要です。") }
        var ids = Set<String>()
        var paths = Set<String>()
        guard Self.matches(revision, "^[0-9a-f]{64}$") else { throw ReaderError.invalid }
        for article in articles {
            guard Self.matches(article.id, "^[0-9]{8}-[0-9]{6}$"),
                  !article.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  ["study", "wiki"].contains(article.type),
                  Self.matches(article.created, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"),
                  Self.matches(article.contentHash, "^[0-9a-f]{64}$"),
                  ids.insert(article.id).inserted,
                  paths.insert(article.path.lowercased()).inserted else { throw ReaderError.invalid }
            try ArticleClient.validatePath(article.path)
        }
        return self
    }
    static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }
}

enum ReaderError: LocalizedError {
    case invalid, mismatch, http(Int), message(String)
    var errorDescription: String? {
        switch self {
        case .invalid: return "記事一覧または取得先の形式が不正です。"
        case .mismatch: return "記事が更新中の可能性があります。一覧を更新して再試行してください。"
        case .http(let code): return "記事を取得できませんでした（HTTP \(code)）。一覧を更新して再試行してください。"
        case .message(let text): return text
        }
    }
}

// 配信先の変更をリダイレクトで許可せず、HTTPSの指定originに限定する。
final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

final class ArticleClient {
    static let baseURL = URL(string: "https://maruyamamasaya.github.io/studyApp/")!
    private let delegate = NoRedirect()
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }()

    static func validatePath(_ path: String) throws {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard ["study", "wiki"].contains(String(parts.first ?? "")), path.hasSuffix(".md"),
              !path.contains("\\"), !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { throw ReaderError.invalid }
    }
    static func url(for path: String) throws -> URL {
        try validatePath(path)
        // appendPathComponentが日本語、#、%を各区間ごとにエンコードする。
        return path.split(separator: "/").reduce(baseURL) { $0.appendingPathComponent(String($1)) }
    }
    static func hash(_ markdown: String) -> String {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        return SHA256.hash(data: Data(normalized.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    func catalog() async throws -> Catalog {
        let data = try await get(Self.baseURL.appendingPathComponent("app-articles.v1.json"))
        return try JSONDecoder().decode(Catalog.self, from: data).validated()
    }
    func content(_ article: Article) async throws -> String {
        let data = try await get(Self.url(for: article.path))
        guard let text = String(data: data, encoding: .utf8) else { throw ReaderError.invalid }
        guard Self.hash(text) == article.contentHash else { throw ReaderError.mismatch }
        return text
    }
    private func get(_ url: URL) async throws -> Data {
        for attempt in 0..<3 {
            try Task.checkCancellation()
            do {
                let (data, response) = try await session.data(for: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
                guard let http = response as? HTTPURLResponse else { throw ReaderError.invalid }
                guard (200..<300).contains(http.statusCode) else { throw ReaderError.http(http.statusCode) }
                return data
            } catch {
                let retry: Bool
                if let network = error as? URLError {
                    retry = [.timedOut, .networkConnectionLost, .cannotConnectToHost].contains(network.code)
                } else if case ReaderError.http(let code) = error {
                    retry = (500..<600).contains(code)
                } else { retry = false }
                guard retry, attempt < 2 else { throw error }
                try await Task.sleep(nanoseconds: UInt64(1 << attempt) * 1_000_000_000)
            }
        }
        throw ReaderError.invalid
    }
}
