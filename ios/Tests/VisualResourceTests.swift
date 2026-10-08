import XCTest
import ZIPFoundation
@testable import StudyApp

final class VisualResourceTests: XCTestCase {
    private var svg: Data { Data("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 100\"><rect id=\"box\" width=\"100\" height=\"100\" fill=\"red\"/></svg>".utf8) }
    func testSVGRejectsActiveContentAndExternalReferences() throws {
        for content in [
            "<svg><script>alert(1)</script></svg>",
            "<svg><foreignObject><p>x</p></foreignObject></svg>",
            "<!DOCTYPE svg [<!ENTITY x SYSTEM 'file:///etc/passwd'>]><svg>&x;</svg>",
            "<svg><image href='https://example.com/a.png'/></svg>",
            "<svg><rect fill='url(https://example.com/a)'/></svg>",
            "<svg><style>@import 'https://example.com/x';</style></svg>",
            "<svg><animate attributeName='x'/></svg>",
            "<svg><g id='x'/><g id='x'/></svg>"
        ] { XCTAssertThrowsError(try SafeSVG.parse(Data(content.utf8))) }
        let cleaned = try SafeSVG.parse(Data("<svg><rect onclick='alert(1)'/></svg>".utf8))
        XCTAssertFalse(String(decoding: cleaned.data, as: UTF8.self).contains("onclick"))
        XCTAssertEqual(try SafeSVG.parse(svg).elementIDs, ["box"])
        let linked = try SafeSVG.parse(svg, links: ["box": "20261008-091255"])
        XCTAssertTrue(String(decoding: linked.data, as: UTF8.self).contains("learnleafarticle:20261008-091255"))
        XCTAssertThrowsError(try SafeSVG.parse(svg, links: ["box": "javascript:alert(1)"]))
    }
    func testOfficeRejectsTraversalAndExternalRelationships() throws {
        XCTAssertFalse(ResourceValidation.safePath("../escape.xml"))
        XCTAssertFalse(ResourceValidation.safePath("word/../../a"))
        XCTAssertFalse(ResourceValidation.safePath("word\\a"))
        XCTAssertFalse(ResourceValidation.safePath("C:/a"))
        let xml = Data("<Relationships><Relationship TargetMode='External' Target='https://example.com'/></Relationships>".utf8)
        let archive = try Archive(accessMode: .create)
        try archive.addEntry(with: "[Content_Types].xml", type: .file, uncompressedSize: Int64(xml.count)) { position, size in
            xml.subdata(in: Int(position)..<Int(position) + size)
        }
        try archive.addEntry(with: "word/document.xml", type: .file, uncompressedSize: 4) { _, _ in Data("<w/>".utf8) }
        XCTAssertThrowsError(try ResourceValidation.validateOffice(archive.data!, kind: .docx))
    }
    func testImportRestartHashReplacementAndCorruptIndexProtection() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let input = root.appendingPathComponent("diagram.svg"); try svg.write(to: input)
        let library = root.appendingPathComponent("library")
        let storage = VisualResourceStore(directory: library)
        let imported = try await storage.importFile(input, articleID: "20261008-091255")
        do { _ = try await storage.importFile(input); XCTFail("duplicate accepted") } catch { }
        let restarted = VisualResourceStore(directory: library)
        let list = try await restarted.load()
        XCTAssertEqual(list.first?.id, imported.id)
        let changed = Data("<svg><circle r='10'/></svg>".utf8); try changed.write(to: input)
        try await restarted.replaceOriginal(input, id: imported.id)
        let replaced = try await restarted.load()
        XCTAssertEqual(replaced.first?.id, imported.id)
        XCTAssertNotEqual(replaced.first?.originalHash, imported.originalHash)
        let file = try await restarted.url(imported.id)
        try Data("corrupt".utf8).write(to: file)
        do { _ = try await restarted.url(imported.id); XCTFail("corrupt original accepted") } catch { }
        let index = library.appendingPathComponent("index.v1.json")
        try Data("{broken".utf8).write(to: index)
        let damaged = VisualResourceStore(directory: library)
        do { _ = try await damaged.importFile(input); XCTFail("damaged index overwritten") } catch { }
        XCTAssertEqual(try Data(contentsOf: index), Data("{broken".utf8))
    }
    func testSlideSplittingPreservesFencedCodeAndSource() {
        let ticks = String(repeating: "\u{0060}", count: 3)
        let source = "# One\nhello\n\(ticks)\n# code\n---\n\(ticks)\n## Two\nworld"
        let slides = SlideBuilder.build(source)
        XCTAssertEqual(slides.count, 2)
        XCTAssertTrue(slides[0].body.contains("# code\n---"))
        XCTAssertEqual(slides[1].title, "Two")
        var edited = slides
        edited[0].body = "manual"
        XCTAssertEqual(slides[0].body.contains("hello"), true)
        XCTAssertEqual(edited[0].body, "manual")
    }
}
