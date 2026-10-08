import Foundation
import ZIPFoundation
import PDFKit
import UIKit
import ImageIO

enum ResourceValidation {
    static let fileLimit = 50 * 1024 * 1024
    static func kind(for url: URL) throws -> ResourceKind {
        guard let kind = ResourceKind(rawValue: url.pathExtension.lowercased()), kind != .presentation else {
            if url.pathExtension.lowercased() == "jpg" { return .jpeg }
            throw VisualError.invalid
        }
        return kind
    }
    static func validate(_ data: Data, kind: ResourceKind) throws {
        guard !data.isEmpty, data.count <= (kind == .pdf ? 100 * 1024 * 1024 : fileLimit) else { throw VisualError.size }
        switch kind {
        case .svg: _ = try SafeSVG.parse(data)
        case .pdf:
            guard data.starts(with: Data("%PDF-".utf8)),
                  let document = PDFDocument(data: data), !document.isEncrypted,
                  document.pageCount > 0, document.pageCount <= 500 else { throw VisualError.invalid }
            // PDFKit doesn't execute document JavaScript. Refuse visible active objects as well.
            let raw = String(decoding: data, as: UTF8.self)
            guard !["/JavaScript", "/Launch", "/EmbeddedFile", "/RichMedia"].contains(where: raw.contains) else {
                throw VisualError.unsafe
            }
        case .docx, .pptx: try validateOffice(data, kind: kind)
        case .png, .jpeg:
            let validSignature = kind == .png ? data.starts(with: Data([137, 80, 78, 71, 13, 10, 26, 10])) : data.starts(with: Data([255, 216, 255]))
            guard validSignature,
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
                  let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
                  width.doubleValue > 0, height.doubleValue > 0,
                  width.doubleValue * height.doubleValue <= 16000000 else {
                throw VisualError.invalid
            }
        case .presentation: throw VisualError.invalid
        }
    }
    static func validateOffice(_ data: Data, kind: ResourceKind) throws {
        guard data.starts(with: Data([0x50, 0x4b, 0x03, 0x04])) else { throw VisualError.invalid }
        let expected = try centralDirectoryCount(data)
        let archive = try Archive(data: data, accessMode: .read)
        var total: UInt64 = 0
        var paths = Set<String>()
        var count = 0
        for entry in archive {
            count += 1
            guard count <= 10000, entry.type != .symlink,
                  safePath(entry.path), paths.insert(entry.path.lowercased()).inserted else { throw VisualError.unsafe }
            let size = UInt64(entry.uncompressedSize)
            total += size
            guard total <= 200 * 1024 * 1024, size <= 50 * 1024 * 1024,
                  size <= max(UInt64(entry.compressedSize), 1) * 100 else { throw VisualError.size }
            let lower = entry.path.lowercased()
            guard !lower.contains("vbaproject"), !lower.contains("embeddings/"),
                  !lower.hasSuffix(".exe") else { throw VisualError.unsafe }
            // Read every entry with CRC validation before committing the original.
            var xml = Data()
            var extracted = 0
            _ = try archive.extract(entry) { chunk in
                extracted += chunk.count
                guard extracted <= 50 * 1024 * 1024 else { throw VisualError.size }
                if lower.hasSuffix(".rels") || lower.hasSuffix(".xml") { xml.append(chunk) }
            }
            if !xml.isEmpty {
                guard let text = String(data: xml, encoding: .utf8),
                      !text.uppercased().contains("<!DOCTYPE"),
                      !text.uppercased().contains("<!ENTITY") else { throw VisualError.unsafe }
                let check = OfficeXMLPolicy()
                let parser = XMLParser(data: xml); parser.shouldResolveExternalEntities = false; parser.delegate = check
                guard parser.parse(), !check.invalid else { throw VisualError.unsafe }
            }
        }
        let required = kind == .docx ? "word/document.xml" : "ppt/presentation.xml"
        guard count == expected, paths.contains("[content_types].xml"), paths.contains(required) else { throw VisualError.invalid }
    }
    // ZIPFoundation's iterator can stop at an unreadable/encrypted entry. Ensure
    // validation actually visited the declared entry count; refuse ZIP64/multi-disk.
    private static func centralDirectoryCount(_ data: Data) throws -> Int {
        let bytes = [UInt8](data.suffix(65557))
        guard bytes.count >= 22 else { throw VisualError.invalid }
        for i in stride(from: bytes.count - 22, through: 0, by: -1) {
            guard Array(bytes[i..<i + 4]) == [0x50, 0x4b, 0x05, 0x06] else { continue }
            func u16(_ p: Int) -> Int { Int(bytes[i + p]) | Int(bytes[i + p + 1]) << 8 }
            guard i + 22 + u16(20) == bytes.count else { continue }
            guard u16(4) == 0, u16(6) == 0, u16(8) == u16(10),
                  u16(10) > 0, u16(10) <= 10000 else { throw VisualError.unsafe }
            return u16(10)
        }
        throw VisualError.invalid
    }
    static func safePath(_ path: String) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        return !path.hasPrefix("/") && !path.contains("\\") && !path.contains(":")
            && !path.contains("%") && !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
            && parts.filter { !$0.isEmpty }.allSatisfy { $0 != "." && $0 != ".." }
    }
}
private final class OfficeXMLPolicy: NSObject, XMLParserDelegate {
    var invalid = false
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        if attributes.contains(where: { $0.key.lowercased() == "targetmode" && $0.value.lowercased() == "external" }) {
            invalid = true; parser.abortParsing()
        }
    }
}
