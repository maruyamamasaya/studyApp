import Foundation

// Fail closed: reconstruct an allowlisted static SVG; never inject the input XML.
// No CSS, images, use, animation, foreignObject, scripting or external references.
struct SafeSVG {
    let data: Data
    let elementIDs: Set<String>
    static func parse(_ data: Data, links: [String: String] = [:]) throws -> SafeSVG {
        guard data.count <= 2 * 1024 * 1024,
              let text = String(data: data, encoding: .utf8),
              !text.uppercased().contains("<!DOCTYPE"),
              !text.uppercased().contains("<!ENTITY") else { throw VisualError.unsafe }
        guard links.values.allSatisfy({ Catalog.matches($0, "^[0-9]{8}-[0-9]{6}$") }) else { throw VisualError.invalid }
        let delegate = SVGParser(links: links)
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), !delegate.invalid, delegate.root,
              delegate.depth == 0 else { throw VisualError.unsafe }
        return SafeSVG(data: Data(delegate.output.utf8), elementIDs: delegate.ids)
    }
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
private final class SVGParser: NSObject, XMLParserDelegate {
    private let links: [String: String]
    private var linked: [Bool] = []
    init(links: [String: String]) { self.links = links }
    var output = ""
    var root = false
    var invalid = false
    var depth = 0
    var nodes = 0
    var ids = Set<String>()
    private var stack: [String] = []
    private let elements: Set<String> = ["svg", "g", "path", "rect", "circle", "ellipse", "line",
        "polyline", "polygon", "text", "tspan", "title", "desc", "defs", "linearGradient",
        "radialGradient", "stop", "clipPath"]
    private let attributes: Set<String> = ["id", "viewBox", "width", "height", "x", "y", "x1", "y1",
        "x2", "y2", "cx", "cy", "r", "rx", "ry", "d", "points", "transform", "fill", "stroke",
        "stroke-width", "stroke-linecap", "stroke-linejoin", "stroke-dasharray", "stroke-dashoffset",
        "fill-rule", "clip-rule", "opacity", "fill-opacity", "stroke-opacity", "font-size",
        "font-family", "font-weight", "text-anchor", "dominant-baseline", "dx", "dy", "offset",
        "stop-color", "stop-opacity", "gradientUnits", "gradientTransform", "spreadMethod", "clip-path",
        "preserveAspectRatio", "role", "aria-label"]
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes values: [String: String]) {
        nodes += 1; depth += 1
        guard nodes <= 20000, depth <= 100, elements.contains(name),
              root || name == "svg", !(depth > 1 && name == "svg") else {
            invalid = true; parser.abortParsing(); return
        }
        if depth == 1 { root = true }
        var attrs = ""
        for (key, value) in values.sorted(by: { $0.key < $1.key }) {
            if key == "xmlns", value == "http://www.w3.org/2000/svg" { continue }
            if key == "version", value == "1.1" { continue }
            // Events are discarded. Other unknown markup is refused, not silently trusted.
            if key.lowercased().hasPrefix("on") { continue }
            guard attributes.contains(key), value.count <= 100000,
                  !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                  !value.lowercased().contains("javascript"),
                  !value.lowercased().contains("data:"),
                  !value.contains("://"), !value.contains("@") else {
                invalid = true; parser.abortParsing(); return
            }
            if value.lowercased().contains("url") {
                guard ["fill", "stroke", "clip-path"].contains(key),
                      Catalog.matches(value, "^url\\(#[A-Za-z_][A-Za-z0-9_.-]*\\)$") else {
                    invalid = true; parser.abortParsing(); return
                }
            }
            if key == "id" {
                guard Catalog.matches(value, "^[A-Za-z_][A-Za-z0-9_.-]*$"),
                      ids.insert(value).inserted else {
                    invalid = true; parser.abortParsing(); return
                }
            }
            if key == "font-family" {
                guard ["sans-serif", "serif", "monospace", "system-ui"].contains(value) else {
                    // Avoid font lookup from arbitrary SVG CSS; use a generic family.
                    attrs += " font-family=\"sans-serif\""; continue
                }
            }
            attrs += " \(key)=\"\(SafeSVG.escape(value))\""
        }
        if depth == 1 { attrs += " xmlns=\"http://www.w3.org/2000/svg\"" }
        let linkable: Set<String> = ["g", "path", "rect", "circle", "ellipse", "line", "polyline", "polygon", "text"]
        let article = linkable.contains(name) && !stack.contains("defs") && !stack.contains("clipPath")
            ? values["id"].flatMap { links[$0] } : nil
        if let article { output += "<a href=\"learnleafarticle:\(article)\">" }
        linked.append(article != nil)
        output += "<\(name)\(attrs)>"; stack.append(name)
    }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        guard stack.popLast() == name else { invalid = true; parser.abortParsing(); return }
        output += "</\(name)>"
        if linked.popLast() == true { output += "</a>" }
        depth -= 1
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { output += SafeSVG.escape(string) }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) { invalid = true; parser.abortParsing() }
    func parser(_ parser: XMLParser, foundProcessingInstructionWithTarget target: String, data: String?) {
        invalid = true; parser.abortParsing()
    }
    func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data? {
        invalid = true; parser.abortParsing(); return nil
    }
}
